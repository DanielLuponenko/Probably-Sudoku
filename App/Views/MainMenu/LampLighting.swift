import SwiftUI

/// The light the lamp casts, in four parts: the bulb, its halo, the cone of
/// air under it, and the places that light lands.
///
/// Split into a still half and a moving half on purpose. The cone is the one
/// blurred thing on the screen, so it is drawn once and never touched again;
/// only the halo, the dust and the varnish trace are sampled per frame, and
/// none of those three is blurred over any real area.
struct LampLighting: View {
    var metrics: MainMenuSceneMetrics

    private var bulb: CGPoint { metrics.bulbCentre }

    var body: some View {
        cone
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Light in a dusty room, not a spotlight. It has to be barely there: the
    /// moment the edges are findable it reads as a yellow triangle drawn on
    /// the wall.
    private var cone: some View {
        LightCone(apex: bulb, reach: metrics.boardFrame.maxY - bulb.y + metrics.height * 0.06,
                  spread: metrics.width * 0.62)
            .fill(LinearGradient(
                stops: [
                    .init(color: ClubRoomMaterial.lampWarm.opacity(0.30), location: 0),
                    .init(color: ClubRoomMaterial.lampWarm.opacity(0.13), location: 0.35),
                    .init(color: ClubRoomMaterial.lampWarm.opacity(0.04), location: 0.72),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom))
            .blur(radius: 26)
            .opacity(0.42)
            .blendMode(.plusLighter)
            // Rasterised once. Without this the blur is a full-width filter
            // recomputed behind every frame of the room.
            .drawingGroup()
    }

    /// Where the light actually lands: the wall under the shade, the left edge
    /// of the plaque, the top of the board, and the near corner of Play.
    fileprivate var bounce: some View {
        ZStack(alignment: .topLeading) {
            patch(at: CGPoint(x: bulb.x + metrics.width * 0.10, y: bulb.y + metrics.height * 0.05),
                  radius: metrics.width * 0.34, opacity: 0.12)
            patch(at: CGPoint(x: metrics.titlePlaqueFrame.minX + metrics.width * 0.04,
                              y: metrics.titlePlaqueFrame.midY),
                  radius: metrics.width * 0.30, opacity: 0.10)
            patch(at: CGPoint(x: metrics.boardFrame.midX - metrics.width * 0.06,
                              y: metrics.boardFrame.minY),
                  radius: metrics.width * 0.34, opacity: 0.09)
            patch(at: CGPoint(x: metrics.playFrame.minX + metrics.width * 0.05,
                              y: metrics.playFrame.minY),
                  radius: metrics.width * 0.26, opacity: 0.06)
        }
        .blendMode(.plusLighter)
    }

    fileprivate func patch(at centre: CGPoint, radius: CGFloat, opacity: Double) -> some View {
        RadialGradient(colors: [ClubRoomMaterial.lampWarm.opacity(opacity), .clear],
                       center: .center, startRadius: 0, endRadius: radius)
            .frame(width: radius * 2, height: radius * 2)
            .position(centre)
    }
}
/// The same lamp, falling *across* the objects rather than behind them.
///
/// Drawn after the plaque, the board and the controls, because that is the
/// difference between a room that is lit and a room with a lit picture behind
/// it. The bounce patches used to be painted before those objects existed, so
/// they never reached them — every physical thing on the screen was correctly
/// shaded for a lamp whose light stopped at the wallpaper, which is a large
/// part of why they read as pasted in from another scene.
///
/// Weak on purpose. It is a unifying wash, not a second light.
struct LampSurfaceLight: View {
    var metrics: MainMenuSceneMetrics

    var body: some View {
        LampLighting(metrics: metrics).bounce
            .opacity(0.85)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The bulb and the air immediately around it. The only part of the lighting
/// that moves, and it moves by two per cent.
struct BulbGlow: View, Animatable {
    var phase: Double
    var centre: CGPoint
    var scale: CGFloat

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    /// A filament does not pulse. This is the room breathing, and if it is
    /// ever visible as an animation it is too strong.
    private var swell: Double { 1 + 0.02 * sin(phase * 2 * .pi) }
    private var swayX: CGFloat { CGFloat(sin(phase * 2 * .pi)) * 5 * scale }

    var body: some View {
        let halo = max(56, 150 * scale)

        ZStack {
            RadialGradient(
                colors: [ClubRoomMaterial.bulb.opacity(0.58 * swell),
                         ClubRoomMaterial.bulb.opacity(0.14 * swell),
                         .clear],
                center: .center, startRadius: 3, endRadius: halo)
                .frame(width: halo * 2, height: halo * 2)

            // The filament itself. Bright, and small enough that the shade in
            // front of it still reads as a shade.
            Circle()
                .fill(ClubRoomMaterial.bulbCore.opacity(0.92))
                .frame(width: max(8, 26 * scale), height: max(8, 26 * scale))
                .blur(radius: max(2, 4 * scale))
        }
        .position(x: centre.x + swayX, y: centre.y)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The shape of the light under a shade: narrow at the bulb, spreading, and
/// cut off before it reaches the controls.
private struct LightCone: Shape {
    var apex: CGPoint
    var reach: CGFloat
    var spread: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mouth = spread * 0.22
        let bottom = apex.y + reach
        path.move(to: CGPoint(x: apex.x - mouth, y: apex.y))
        path.addLine(to: CGPoint(x: apex.x + mouth, y: apex.y))
        // The near edge falls a little short of the far one: the shade is off
        // to the left, so the light leans across the room.
        path.addQuadCurve(to: CGPoint(x: apex.x + spread, y: bottom),
                          control: CGPoint(x: apex.x + spread * 0.6, y: apex.y + reach * 0.5))
        path.addLine(to: CGPoint(x: apex.x - spread * 0.72, y: bottom))
        path.addQuadCurve(to: CGPoint(x: apex.x - mouth, y: apex.y),
                          control: CGPoint(x: apex.x - spread * 0.45, y: apex.y + reach * 0.5))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dust

/// Motes in the beam. Ten of them, in one Canvas, on fixed paths — this is the
/// cheapest possible way to say the air in the room has something in it, and
/// the moment it becomes findable as an animation it has failed.
struct DustMotes: View, Animatable {
    var phase: Double
    var bulb: CGPoint
    var reach: CGFloat
    var spread: CGFloat

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    private static let count = 10

    var body: some View {
        Canvas { context, _ in
            for index in 0..<Self.count {
                let seeded = Self.seed(index)
                // Each falls at its own rate, and each is somewhere different
                // in its fall to begin with.
                let drop = (phase * (0.35 + seeded.speed) + seeded.offset)
                    .truncatingRemainder(dividingBy: 1)
                let y = bulb.y + reach * drop
                let widthHere = spread * (0.2 + drop * 0.8)
                let x = bulb.x + (seeded.lateral - 0.5) * widthHere * 2
                    + sin(phase * 2 * .pi + seeded.offset * 6) * 6

                // Out before the light does, so nothing drifts across a button.
                let fade = min(1, drop * 5) * max(0, 1 - drop * 1.25)
                let size = 1.1 + seeded.size * 1.6
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size)),
                    with: .color(ClubRoomMaterial.bulbCore.opacity(0.34 * fade)))
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func seed(_ index: Int) -> (speed: Double, offset: Double,
                                               lateral: Double, size: Double) {
        var state = UInt64(index &* 6151 &+ 7) &* 2654435761 &+ 11
        func unit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        return (unit() * 0.5, unit(), unit(), unit())
    }
}

// MARK: - Light traces

/// Light catching varnish. A narrow warm band crossing one surface, masked to
/// that surface, and invisible for most of the cycle.
///
/// Deliberately not a screen-wide sweep: the difference between "the lamp is
/// on" and "a neon strip just went past" is entirely whether the highlight is
/// bounded by an object.
struct MaterialLightTrace: ViewModifier, Animatable {
    var phase: Double
    var strength: Double
    var shape: AnyShape

    /// When in the room's cycle the pass happens. One pass per cycle, and the
    /// cycle is eighteen seconds.
    private static let start = 0.55
    private static let end = 0.72

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { proxy in
                let through = (phase - Self.start) / (Self.end - Self.start)
                if strength > 0, through > 0, through < 1 {
                    // Feathered at both ends of the pass, so it arrives and
                    // leaves rather than switching on.
                    let visible = sin(through * .pi)
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.10 * strength * visible),
                                  location: 0.24),
                            .init(color: .white.opacity(0.38 * strength * visible),
                                  location: 0.5),
                            .init(color: .white.opacity(0.10 * strength * visible),
                                  location: 0.76),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.42)
                        .rotationEffect(.degrees(16))
                        .offset(x: (through * 1.6 - 0.4) * proxy.size.width)
                        .frame(width: proxy.size.width, height: proxy.size.height,
                               alignment: .leading)
                        .blendMode(.screen)
                }
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        }
    }
}

/// The fixture moves as one inexpensive transform. The room's wall, grain,
/// desk and props never enter this animated subtree.
struct LampSway: ViewModifier, Animatable {
    var phase: Double
    var amount: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    private var swing: Double { sin(phase * 2 * .pi) * amount }

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(swing), anchor: .top)
            .offset(x: CGFloat(swing) * 0.7)
    }
}

/// The only continuously animated front-door layer. Its local state keeps
/// the room, its paper grain and all controls out of the display-link update.
struct SwayingLampFixture: View {
    var ceilingDrop: CGFloat
    var isEnabled: Bool

    @State private var phase = 0.0

    var body: some View {
        LampFixture(glow: 1, ceilingDrop: ceilingDrop)
            .modifier(LampSway(phase: phase, amount: isEnabled ? 2.1 : 0))
            .task(id: isEnabled) {
                guard isEnabled else {
                    phase = 0
                    return
                }
                phase = 0
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Ambient drift

/// A point or two of movement, applied as a transform.
///
/// A modifier rather than an offset computed in a parent's body, and that
/// distinction is the whole performance story of this screen: a plain `Double`
/// read in a body is only sampled when state changes, so a room built that way
/// would not move at all — and a body re-run every frame would redraw the
/// plaster, the wood grain and every leaf sixty times a second. This
/// interpolates on its own, and only ever moves what is already drawn.
struct AmbientDrift: ViewModifier, Animatable {
    var phase: Double
    var amount: CGFloat
    /// Different things in a room do not sway in step.
    var offsetBy: Double = 0

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(y: CGFloat(sin(phase * 2 * .pi + offsetBy)) * amount)
    }
}
