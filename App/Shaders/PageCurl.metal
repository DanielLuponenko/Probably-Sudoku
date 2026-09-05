#include <metal_stdlib>
using namespace metal;

struct PageUniforms {
    float4 size;
    float4 motion;
    float4 shadow;
    float4 stock;
};

struct PageVertex {
    float4 position [[position]];
    float2 uv;
    float3 world;
    float3 normal;
    float2 receiver;
};

static float bendRadius(float p, constant PageUniforms &u) {
    return max(0.0001f, u.size.x * (0.016f + 0.125f * sin(M_PI_F * p))
               * (1.0f - smoothstep(0.82f, 1.0f, p)));
}

// Work in the material's actual oblique fold frame. The bottom-right corner
// leads the lift, then the angle relaxes as the complete leaf crosses the spine.
static float3 leafPosition(float2 uv, constant PageUniforms &u) {
    float width = u.size.x, height = u.size.y;
    float p = clamp(u.motion.x, 0.0f, 1.0f);
    float wave = sin(M_PI_F * p);
    float radius = bendRadius(p, u);
    float angle = wave * (0.06f + 0.20f * (1.0f - smoothstep(0.24f, 0.68f, p)));
    float2 across = float2(cos(angle), sin(angle));
    float2 along = float2(-across.y, across.x);
    float x = uv.x * width, y = uv.y * height;
    float2 material = float2(x, y - height * 0.5f);
    float materialU = dot(material, across);
    float materialV = dot(material, along);
    // Every point on x=0 stays on the unbent side until the final frame.
    float fold = max(width * (1.0f - p) * across.x, height * 0.5f * across.y);
    float distance = max(0.0f, materialU - fold);
    if (distance <= 0.0f) { return float3(x, y, 0); }

    float arc = M_PI_F * radius;
    float theta = min(distance / radius, M_PI_F);
    float returned = max(0.0f, distance - arc);
    // The returned section has a second, gentle bend instead of becoming a
    // rigid flat panel. Integrating that bend preserves its material length.
    float sag = wave * 0.68f / width;
    float sagAngle = returned * sag;
    float travelled = sag > 0.00001f ? sin(sagAngle) / sag : returned;
    float drop = sag > 0.00001f ? (1.0f - cos(sagAngle)) / sag : 0.0f;
    float bentU = fold + radius * sin(theta) - travelled;
    float z = radius * (1.0f - cos(theta));
    z -= drop;
    // At the finish the returned leaf relaxes behind the binding.
    z -= 2.0f * smoothstep(0.9f, 1.0f, p) * min(returned / width, 1.0f);
    float2 bent = across * bentU + along * materialV;
    return float3(bent.x, bent.y + height * 0.5f, z);
}

static float4 projected(float3 world, constant PageUniforms &u) {
    if (u.motion.z > 0.5f) {
        float2 ndc = (world.xy + u.motion.y) / u.size.zw * 2.0f - 1.0f;
        return float4(ndc.x, -ndc.y, 0.5f, 1.0f);
    }
    // Both the oblique corner movement and perspective consume the canvas
    // margin. Reserve room for each, so a raised edge is never cut flat.
    float p = clamp(u.motion.x, 0.0f, 1.0f);
    float topTravel = max(0.0f, -leafPosition(float2(1, 0), u).y);
    float budget = max(2.0f, u.motion.y * 0.9f - topTravel);
    float maxHeight = bendRadius(p, u) * 2.0f;
    float camera = max(u.size.x * 3.4f, maxHeight * (1.0f + u.size.y / (2.0f * budget)));
    float w = camera - world.z;
    float2 centre = u.size.xy * float2(0.46f, 0.5f);
    float2 pixel = centre + (world.xy - centre) * camera / w + u.motion.y;
    float2 ndc = pixel / u.size.zw * 2.0f - 1.0f;
    ndc.y = -ndc.y;
    return float4(ndc * w, (0.5f - world.z / (u.size.x * 4.0f)) * w, w);
}

vertex PageVertex pageLeafVertex(uint id [[vertex_id]],
                                constant float2 *points [[buffer(0)]],
                                constant PageUniforms &u [[buffer(1)]]) {
    PageVertex out;
    out.uv = points[id];
    out.world = leafPosition(out.uv, u);
    out.receiver = out.world.xy;
    if (u.motion.z > 0.5f) {
        float height = max(0.0f, out.world.z);
        float spread = 0.5f + height / max(u.size.x, 1.0f) * 3.0f;
        out.receiver += float2(0.14f, 0.09f) * height + u.shadow.xy * spread;
        out.position = projected(float3(out.receiver, 0), u);
        out.normal = float3(0, 0, 1);
    } else {
        const float e = 0.0005f;
        float2 loX = float2(max(0.0f, out.uv.x - e), out.uv.y);
        float2 hiX = float2(min(1.0f, out.uv.x + e), out.uv.y);
        float2 loY = float2(out.uv.x, max(0.0f, out.uv.y - e));
        float2 hiY = float2(out.uv.x, min(1.0f, out.uv.y + e));
        float3 tangentX = leafPosition(hiX, u) - leafPosition(loX, u);
        float3 tangentY = leafPosition(hiY, u) - leafPosition(loY, u);
        out.normal = normalize(cross(tangentX, tangentY));
        out.position = projected(out.world, u);
    }
    return out;
}

static void trimCorners(float2 uv, constant PageUniforms &u) {
    float2 paper = uv * u.size.xy;
    float radius = 5.0f;
    if (paper.x > u.size.x - radius) {
        float cornerY = paper.y < radius ? radius : u.size.y - radius;
        if ((paper.y < radius || paper.y > u.size.y - radius)
            && length(paper - float2(u.size.x - radius, cornerY)) > radius) {
            discard_fragment();
        }
    }
}

fragment half4 pageLeafFragment(PageVertex in [[stage_in]],
                               bool facing [[front_facing]],
                               texture2d<half> front [[texture(0)]],
                               constant PageUniforms &u [[buffer(1)]]) {
    trimCorners(in.uv, u);
    if (in.world.x < 0 && in.world.z < 0.1f) { discard_fragment(); }
    float3 normal = normalize(in.normal);
    half3 colour;
    if (facing) {
        constexpr sampler ink(filter::linear, address::clamp_to_edge);
        colour = front.sample(ink, in.uv).rgb;
        float light = 0.63f + 0.37f * abs(normal.z) + 0.03f * max(normal.x, 0.0f);
        colour *= half(light);
    } else {
        // Independent blank, opaque reverse. Never sample or blend front ink.
        colour = half3(pow(u.stock.rgb, float3(2.2f)));
        float light = 0.60f + 0.40f * abs(normal.z) - 0.02f * normal.x;
        colour *= half(light);
    }
    return half4(colour, 1.0h);
}

fragment half4 pageShadowFragment(PageVertex in [[stage_in]],
                                 constant PageUniforms &u [[buffer(1)]]) {
    trimCorners(in.uv, u);
    if (in.receiver.x < 0 || in.receiver.y < 0
        || in.receiver.x > u.size.x || in.receiver.y > u.size.y) { discard_fragment(); }
    float height = max(0.0f, in.world.z);
    float lifted = smoothstep(0.2f, 3.0f, height);
    half alpha = half(u.shadow.z * lifted * (1.0f - 0.45f * height / u.size.x));
    return half4(half3(0.08h, 0.06h, 0.045h) * alpha, alpha);
}
