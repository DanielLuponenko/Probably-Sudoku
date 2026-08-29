import SwiftUI

/// The one numeral renderer used by the live grid, the hand, return motion,
/// and every SwiftUI shop preview. A cosmetic may dress a glyph with print,
/// light, or flame, but the purchased object is always the digit itself.
struct CosmeticNumberGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cosmeticPulsePhase) private var sharedPulsePhase

    let text: String
    let skin: NumberSkin
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    var intensity: Double = 1

    var body: some View {
        Group {
            if skin.finish.isAnimated && !reduceMotion {
                if let sharedPulsePhase {
                    pulsed(renderedGlyph, active: sharedPulsePhase)
                } else {
                    renderedGlyph
                        .phaseAnimator([false, true]) { content, active in
                            pulsed(content, active: active)
                        } animation: { active in
                            Self.pulseAnimation(for: skin.finish, active: active)
                        }
                    }
            } else {
                renderedGlyph
            }
        }
        .accessibilityHidden(true)
    }

    private func pulsed(_ content: some View, active: Bool) -> some View {
        content
            .scaleEffect(x: 1, y: active && skin.finish == .flame ? 1.035 : 1)
            .brightness(active ? 0.035 : 0)
            .shadow(color: glow.opacity(active ? 0.68 : 0.42),
                    radius: active ? glowRadius * 1.35 : glowRadius)
    }

    fileprivate static func pulseAnimation(for finish: NumberFinish, active: Bool) -> Animation {
        .easeInOut(duration: finish == .flame
                   ? (active ? 0.28 : 0.36)
                   : (active ? 0.82 : 1.05))
    }

    /// A shared container clock needs one symmetric leg. These averages keep
    /// each finish's original complete rise/fall period.
    fileprivate static func pulseCycleAnimation(for finish: NumberFinish) -> Animation {
        let leg = finish == .flame ? 0.32 : 0.935
        return .easeInOut(duration: leg).repeatForever(autoreverses: true)
    }

    @ViewBuilder
    private var renderedGlyph: some View {
        switch skin.finish {
        case .press:
            baseGlyph()
                .shadow(color: .black.opacity(0.24 * intensity), radius: 0.35, x: 0.7, y: 1)

        case .typewriter:
            ZStack {
                baseGlyph().offset(x: 0.55, y: 0.3).opacity(0.22)
                baseGlyph()
            }

        case .graphite:
            ZStack {
                baseGlyph().blur(radius: 0.28).opacity(0.38)
                baseGlyph().opacity(0.88)
            }
            .rotationEffect(.degrees(-0.45))

        case .woodType:
            ZStack {
                baseGlyph(Color.black.opacity(0.28)).offset(x: 0.9, y: 1.1)
                baseGlyph()
            }

        case .stencil:
            baseGlyph()
                .shadow(color: color.opacity(0.32), radius: 0, x: 1, y: 0)
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.42))
                        .frame(height: max(0.7, size * 0.026))
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

        case .neon:
            luminousGlyph(core: Color(hex: 0xFFD9EF), glow: Color(hex: 0xE14B9A))

        case .laser:
            luminousGlyph(core: Color(hex: 0xC7FFF9), glow: Color(hex: 0x59F5E8))
                .overlay {
                    LinearGradient(colors: [.clear, .white.opacity(0.9), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: max(1, size * 0.065))
                        .mask(baseGlyph())
                }

        case .flame:
            ZStack {
                baseGlyph(Color(hex: 0xD8321F).opacity(0.60 * intensity))
                    .blur(radius: max(1.5, size * 0.09))
                    .offset(y: -size * 0.025)
                Text(text)
                    .font(skin.font(size, weight: weight))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: 0xFFF4B0), Color(hex: 0xFF9B36),
                                                Color(hex: 0xD63A1F)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(intensity)
                    .shadow(color: Color(hex: 0xFF6B25).opacity(0.85 * intensity),
                            radius: max(2, size * 0.10))
            }
            .overlay(alignment: .top) {
                FlameCrown(size: size, intensity: intensity)
                    // Sink the flame roots into the printed digit so they read
                    // as a burning numeral, not detached punctuation.
                    .offset(y: size * 0.05)
            }
        }
    }

    private func baseGlyph(_ style: Color? = nil) -> some View {
        Text(text)
            .font(skin.font(size, weight: weight))
            .foregroundStyle(style ?? color.opacity(intensity))
    }

    private func luminousGlyph(core: Color, glow glowColor: Color) -> some View {
        ZStack {
            baseGlyph(glowColor.opacity(0.78 * intensity))
                .blur(radius: max(1.5, size * 0.075))
            baseGlyph(glowColor.opacity(0.92 * intensity))
                .shadow(color: glowColor.opacity(0.86 * intensity),
                        radius: max(2, size * 0.11))
            baseGlyph(core.opacity(0.88 * intensity))
        }
    }

    private var glow: Color {
        skin.finish.glowColor ?? .clear
    }

    private var glowRadius: CGFloat {
        skin.finish.glowColor == nil ? 0 : max(1.5, size * 0.075)
    }
}

// MARK: - Shared pulse clock

extension EnvironmentValues {
    /// `nil` leaves an isolated preview free to run its own small animator.
    @Entry var cosmeticPulsePhase: Bool? = nil
}

private struct CosmeticPulseClock: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let finish: NumberFinish

    /// Flips once; Core Animation owns every later oscillation instead of a
    /// phase animator re-diffing the complete grid tree on each edge.
    @State private var pulse = false
    @State private var generation = 0

    private var isRunning: Bool { !reduceMotion && finish.isAnimated }

    func body(content: Content) -> some View {
        content
            .environment(\.cosmeticPulsePhase, isRunning ? pulse : nil)
            .onAppear(perform: restart)
            .onChange(of: finish) { restart() }
            .onChange(of: reduceMotion) { restart() }
    }

    private func restart() {
        generation += 1
        let token = generation
        withTransaction(Transaction(animation: nil)) {
            pulse = false
        }
        guard isRunning else { return }
        // Make reset and arm distinct transactions so false -> true cannot be
        // coalesced into a same-pass no-op.
        DispatchQueue.main.async {
            guard generation == token, isRunning else { return }
            withAnimation(CosmeticNumberGlyph.pulseCycleAnimation(for: finish)) {
                pulse = true
            }
        }
    }
}

extension View {
    /// Apply once per live number tree instead of once per glyph.
    func cosmeticPulseClock(for finish: NumberFinish) -> some View {
        modifier(CosmeticPulseClock(finish: finish))
    }
}

/// A small burning-tip treatment for the "Hot Type" finish. Built from the
/// system flame glyph rather than custom bezier tongues: at the sizes a
/// digit actually renders — a shop sample or a live grid cell — hand-drawn
/// spikes read as antennae, not fire. The system shape stays unmistakably
/// flame-shaped down to a few points, so two of them (one sharp, one
/// blurred and set behind) share one vertical axis, so they fuse into a
/// single flickering lick instead of reading as separated points.
struct FlameCrown: View {
    let size: CGFloat
    let intensity: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            flame(scale: 0.82, lean: -5, blur: size * 0.035, dim: 0.6)
                .offset(y: size * 0.012)
            flame(scale: 1, lean: 3, blur: 0, dim: 1)
        }
        .frame(width: size * 0.34, alignment: .bottom)
        .blendMode(.plusLighter)
        .opacity(0.92 * intensity)
        .shadow(color: Color(hex: 0xFF6B25).opacity(0.72 * intensity),
                radius: max(1, size * 0.055))
        .allowsHitTesting(false)
    }

    private func flame(scale: CGFloat, lean: Double, blur: CGFloat, dim: Double) -> some View {
        Image(systemName: "flame.fill")
            .font(.system(size: max(6, size * 0.46 * scale), weight: .bold))
            .foregroundStyle(
                LinearGradient(colors: [Color(hex: 0xD83A1F),
                                        Color(hex: 0xFF8A28),
                                        Color(hex: 0xFFF2A0)],
                               startPoint: .top, endPoint: .bottom)
            )
            .rotationEffect(.degrees(lean))
            .blur(radius: blur)
            .opacity(dim)
    }
}

/// Shared rule renderer for gameplay and shop previews. It draws the standard
/// puzzle geometry first, then adds the selected material finish. Laser motion
/// is a slow optical pulse and becomes a static high-contrast rule when Reduce
/// Motion is enabled.
struct CosmeticGridRules: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let skin: BoardSkin
    let side: CGFloat
    let cell: CGFloat
    var includesBorder = true
    /// Used only when baking a SceneKit texture. Live renderers continue to
    /// follow the real accessibility environment value.
    var forcesStaticRendering = false

    var body: some View {
        ZStack {
            rules(colorScale: 1, widthScale: 1)

            if let glow = skin.finish.glowColor {
                rules(colorScale: 0, widthScale: skin.finish == .laser ? 1.9 : 1.35,
                      override: glow.opacity(skin.finish == .laser ? 0.56 : 0.28))
                    .blur(radius: skin.finish == .laser ? 2.2 : 1.1)
                    .blendMode(.plusLighter)
                    .modifier(GridPulse(
                        enabled: skin.finish.isAnimated && !reduceMotion && !forcesStaticRendering
                    ))
            }

            if includesBorder {
                Rectangle()
                    .strokeBorder(skin.bold, lineWidth: skin.boldWidth + 0.8)
                    .shadow(color: (skin.finish.glowColor ?? .clear)
                        .opacity(skin.finish == .laser ? 0.55 : 0.2),
                            radius: skin.finish == .laser ? 2.5 : 0.8)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func rules(colorScale: Double, widthScale: CGFloat,
                       override: Color? = nil) -> some View {
        Canvas { context, _ in
            for step in 1..<9 {
                let position = CGFloat(step) * cell
                var vertical = Path()
                vertical.move(to: CGPoint(x: position, y: 0))
                vertical.addLine(to: CGPoint(x: position, y: side))
                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: position))
                horizontal.addLine(to: CGPoint(x: side, y: position))

                let heavy = step.isMultiple(of: 3)
                let baseColor = heavy ? skin.bold : skin.hair
                let color = override ?? baseColor.opacity(colorScale)
                let width = (heavy ? skin.boldWidth : skin.hairWidth) * widthScale
                let style = StrokeStyle(lineWidth: width,
                                        lineCap: skin.finish == .laser ? .round : .square,
                                        dash: skin.finish.dash)
                context.stroke(vertical, with: .color(color), style: style)
                context.stroke(horizontal, with: .color(color), style: style)
            }
        }
    }
}

private struct GridPulse: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.phaseAnimator([false, true]) { view, active in
                view.opacity(active ? 0.95 : 0.52)
            } animation: { active in
                .easeInOut(duration: active ? 0.9 : 1.25)
            }
        } else {
            content.opacity(0.72)
        }
    }
}
