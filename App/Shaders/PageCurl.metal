#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>

using namespace metal;

constexpr constant float kPi = 3.14159265358979;

// A page does not rotate. It wraps.
//
// The sheet is bent around a cylinder of radius R lying tangent to the page
// along a fold line, and that fold sweeps across the paper. Material at arc
// length s from the fold sits at height R(1 - cos(s/R)) and projects back down
// at R·sin(s/R), so the far half of the cylinder — everything past a quarter
// turn — is seen from behind, and past a half turn the sheet lies flat again
// above the page it came from.
//
// This runs per output pixel, so it asks the inverse question: given a point,
// which piece of paper is above it? Nearest to the reader wins, which for a
// curl is always the material that has travelled furthest.

/// Paper seen from behind: the stock itself, with the printing barely showing
/// through, and shaded by how far round the curve it has come.
static half4 reverseOfSheet(half4 front, float theta) {
    const half3 stock = half3(0.878h, 0.855h, 0.800h);

    // Ink coverage, roughly. Print bleeds through a sheet; it does not read.
    half ink = 1.0h - min(front.r, min(front.g, front.b));
    half3 colour = stock - ink * 0.07h;

    // The desk lamp is up and to the left, so the crest of the curl catches
    // the light and the underside falls away into shadow.
    float lit = 0.60 + 0.30 * sin(clamp(theta, 0.0, float(kPi)));
    colour *= half(lit);

    // A thin dark line right at the fold, where the paper leaves the flat.
    float crease = smoothstep(0.0, 0.30, theta);
    colour *= half(0.55 + 0.45 * crease);

    return half4(colour, front.a);
}

/// Paper still facing the reader but already curving up off the page.
static half4 frontOfSheet(half4 front, float theta) {
    float lit = 1.0 + 0.06 * sin(theta);        // the rise catches the lamp
    return half4(front.rgb * half(lit), front.a);
}

/// Sampling outside the layer has to be rejected explicitly rather than by
/// testing alpha, because the sampler clamps beyond the declared offset and
/// would otherwise hand back a wrong pixel from the far edge.
static bool onPage(float2 p, float2 size) {
    return p.x >= 0.0 && p.y >= 0.0 && p.x <= size.x && p.y <= size.y;
}

[[ stitchable ]]
half4 pageCurl(float2 pos, SwiftUI::Layer layer,
               float2 size, float progress, float radius) {
    if (progress <= 0.0) {
        return layer.sample(pos);
    }

    const float R = max(radius, 1.0);

    // The fold runs across the page tilted off vertical, so the top corner
    // leaves the flat before the foot does — the way a hand takes a page.
    const float2 n = normalize(float2(1.0, -0.42));

    // Sweep the fold from clear of the leading corner to past the far one.
    float dTopLeft     = dot(float2(0.0, 0.0), n);
    float dTopRight    = dot(float2(size.x, 0.0), n);
    float dBottomLeft  = dot(float2(0.0, size.y), n);
    float dBottomRight = dot(size, n);
    float furthest = max(max(dTopLeft, dTopRight), max(dBottomLeft, dBottomRight));
    float nearest  = min(min(dTopLeft, dTopRight), min(dBottomLeft, dBottomRight));
    float fold = mix(furthest, nearest - kPi * R, progress);

    // Signed distance from the fold, positive on the side the page has left.
    float u = dot(pos, n) - fold;

    // Past the cylinder's own width there is no paper left to see here.
    if (u > R) {
        return half4(0.0h);
    }

    if (u >= 0.0) {
        float ratio = clamp(u / R, 0.0, 1.0);

        // The far side of the cylinder is higher than the near side, so it is
        // what the reader sees. Try it first.
        float thetaBack = kPi - asin(ratio);
        float2 back = pos + n * (R * thetaBack - u);
        if (onPage(back, size)) {
            half4 sampled = layer.sample(back);
            if (sampled.a > 0.02h) {
                return reverseOfSheet(sampled, thetaBack);
            }
        }

        // Nothing has wrapped that far yet: the near side, still face up.
        float thetaFront = asin(ratio);
        float2 front = pos + n * (R * thetaFront - u);
        if (onPage(front, size)) {
            half4 sampled = layer.sample(front);
            if (sampled.a > 0.02h) {
                return frontOfSheet(sampled, thetaFront);
            }
        }
        return half4(0.0h);
    }

    // Behind the fold the paper has not moved yet, so it is still flat on the
    // block. The part that has already gone over the top is not drawn here: in
    // a book it comes to rest on the facing page, which is past the spine and
    // out of this view. Draping it back over the page it came from is what a
    // single sheet of paper folded in half would do, not a page being turned.
    return layer.sample(pos);
}
