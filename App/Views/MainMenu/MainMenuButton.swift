import SwiftUI

/// A panel screwed to the front of the cabinet.
///
/// Two layers, always: a base that stays where it is and a front that sits
/// three points above it. Pressing does not tint the button — it pushes the
/// front down onto the base, which is the only way a physical control can
/// answer. Everything on it is live: the word, the symbol, the border.
struct MainMenuButton: View {
    enum Kind {
        /// The one the room is arranged around.
        case play
        /// Quieter, and cream rather than green.
        case shop
    }

    var kind: Kind
    var title: String
    var symbol: String
    var metrics: MainMenuSceneMetrics
    var phase: Double
    var reduceMotion: Bool
    var accessibilityHint: String
    /// Held down by the caller while the menu is leaving, so Play cannot be
    /// pressed twice on its way out.
    var isEnabled: Bool = true
    /// Driven by the transition: Play stays depressed as the room fades.
    var isHeld: Bool = false
    var action: () -> Void

    @State private var isPressing = false

    private var scale: CGFloat { metrics.scale }
    private var travel: CGFloat { max(2, 3 * scale * 1.6) }
    private var down: Bool { isPressing || isHeld }

    var body: some View {
        let corner = 18 * scale
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack(alignment: .bottom) {
            // The floor of the recess. Fixed, and visible round the face as a
            // dark line — this is what the face is pressed down onto.
            shape
                .fill(Color(hex: 0x1B1109))
                .padding(-max(1.5, 4 * scale))

            // The only thing that moves. Three points of travel and a hair of
            // scale, both on the face alone.
            front(shape: shape)
                .scaleEffect(down ? 0.995 : 1, anchor: .bottom)
                .offset(y: down ? 0 : -travel)
        }
        // The plate the whole control is screwed to. In the background rather
        // than inside the frame, and never moved: a control that carries its
        // own mount around with it is a card, not a fitting.
        .background {
            MountingPlate(scale: scale, corner: corner + 5 * scale)
                .padding(EdgeInsets(top: -22 * scale, leading: -24 * scale,
                                    bottom: -24 * scale, trailing: -24 * scale))
        }
        .animation(.snappy(duration: 0.12), value: down)
        .contentShape(shape)
        // A drag gesture rather than a Button: the press has to show while the
        // finger is still down, and it has to survive the finger sliding a
        // little, which is what a real panel does.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled, !isPressing else { return }
                    isPressing = true
                }
                .onEnded { value in
                    isPressing = false
                    guard isEnabled else { return }
                    let inside = abs(value.translation.width) < 44
                        && abs(value.translation.height) < 44
                    guard inside else { return }
                    Haptics.menuPress()
                    action()
                }
        )
        .opacity(isEnabled ? 1 : 0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }

    private var accessibilityLabel: String {
        kind == .play ? "Play" : "Cosmetic Shop"
    }

    private func front(shape: RoundedRectangle) -> some View {
        ZStack {
            shape.fill(faceGradient)
                // Bookcloth on Play, paper on Shop. The weave is what stops a
                // green rectangle reading as plastic: the light breaks up
                // across the threads instead of sliding over it.
                .overlay {
                    Group {
                        if kind == .play {
                            FabricWeave()
                        } else {
                            PaperGrain(opacity: 0.05, seed: 44)
                        }
                    }
                    .clipShape(shape)
                }
                // Along the top edge, where the lamp reaches it.
                .overlay(alignment: .top) {
                    shape.fill(LinearGradient(
                        colors: [.white.opacity(kind == .play ? 0.22 : 0.35), .clear],
                        startPoint: .top, endPoint: .center))
                }
                // The inset keyline, printed inside the panel.
                .overlay {
                    RoundedRectangle(cornerRadius: corner(shape: shape), style: .continuous)
                        .strokeBorder(keyline, lineWidth: max(1.2, 3.2 * scale))
                        .padding(max(5, 16 * scale))
                }
                .overlay { shape.strokeBorder(.black.opacity(0.35), lineWidth: 1) }

            label
        }
        // Varnish catching the light along the top border, once a cycle.
        .modifier(MaterialLightTrace(phase: phase,
                                     strength: reduceMotion ? 0 : (kind == .play ? 0.5 : 0.25),
                                     shape: AnyShape(shape)))
        .brightness(down ? -0.035 : 0)
        // Sitting in a recess, so the seam round it is tight and the cast is
        // short — it is three points off the plate, not thirty.
        .shadow(color: .black.opacity(0.62), radius: max(0.6, 1.2 * scale),
                x: max(0.3, 0.8 * scale), y: down ? max(0.3, 0.6 * scale)
                                                : max(0.6, 1.6 * scale))
        .shadow(color: .black.opacity(0.20), radius: max(1.5, down ? 2.4 * scale : 4 * scale),
                x: max(1, 2.5 * scale), y: down ? max(1, 1.8 * scale) : max(1.4, 3.5 * scale))
    }

    private func corner(shape: RoundedRectangle) -> CGFloat { 12 * scale }

    private var label: some View {
        VStack(spacing: 2 * scale) {
            if kind == .shop {
                ShopBasketGlyph(color: inkColor)
                    .frame(width: max(20, 52 * scale), height: max(18, 44 * scale))
            } else {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .black))
                    .foregroundStyle(inkColor)
            }
            Text(title)
                .font(Print.menuAction(max(16, kind == .play ? 72 * scale : 62 * scale)))
                .textCase(.uppercase)
                .tracking(max(0.5, 3 * scale))
                .foregroundStyle(inkColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        // The words are cut into the panel too, in the same key as the plaque.
        .shadow(color: .black.opacity(kind == .play ? 0.30 : 0.16),
                radius: 0, y: max(0.5, 1.2 * scale))
    }

    private var faceGradient: LinearGradient {
        switch kind {
        case .play:
            return LinearGradient(colors: [Paper.sage.mixed(with: .white, by: 0.04),
                                           Paper.sageDeep,
                                           Paper.sageDeep.mixed(with: .black, by: 0.30)],
                                  startPoint: .top, endPoint: .bottom)
        case .shop:
            return LinearGradient(colors: [Paper.page, Paper.pageWarm,
                                           Paper.pageWarm.mixed(with: Paper.deskMid, by: 0.30)],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    private var baseColor: Color {
        switch kind {
        case .play: return Paper.sageDeep.mixed(with: .black, by: 0.55)
        case .shop: return Paper.pageEdge.mixed(with: .black, by: 0.62)
        }
    }

    private var keyline: Color {
        kind == .play ? Paper.page.opacity(0.85) : Paper.inkSoft.opacity(0.55)
    }

    private var inkColor: Color {
        kind == .play ? Paper.page : Paper.ink
    }

    private var symbolSize: CGFloat {
        max(18, (kind == .play ? 78 : 42) * scale)
    }
}

/// A deliberately drawn shop mark. The SF Symbol's straight handle terminals
/// read as clipped at this scale; these two curved strokes visibly meet the
/// rim, so the basket remains legible without enlarging its button.
private struct ShopBasketGlyph: View {
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                BasketBody()
                    .fill(color)

                HStack(spacing: size.width * 0.095) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Paper.pageWarm)
                            .frame(width: max(1, size.width * 0.075),
                                   height: size.height * 0.26)
                    }
                }
                .frame(width: size.width * 0.46, height: size.height * 0.26)
                .offset(y: size.height * 0.22)

                BasketHandle(side: .left)
                    .stroke(color, style: StrokeStyle(lineWidth: max(1.3, size.width * 0.105),
                                                       lineCap: .round))
                BasketHandle(side: .right)
                    .stroke(color, style: StrokeStyle(lineWidth: max(1.3, size.width * 0.105),
                                                       lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }

    private struct BasketBody: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.48))
            path.addLine(to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.48))
            path.addLine(to: CGPoint(x: rect.width * 0.77, y: rect.height * 0.91))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.23, y: rect.height * 0.91),
                              control: CGPoint(x: rect.width * 0.50, y: rect.height * 1.03))
            path.closeSubpath()
            return path
        }
    }

    private enum HandleSide { case left, right }

    private struct BasketHandle: Shape {
        var side: HandleSide

        func path(in rect: CGRect) -> Path {
            var path = Path()
            switch side {
            case .left:
                path.move(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.50))
                path.addCurve(to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.18),
                              control1: CGPoint(x: rect.width * 0.24, y: rect.height * 0.28),
                              control2: CGPoint(x: rect.width * 0.35, y: rect.height * 0.12))
            case .right:
                path.move(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.50))
                path.addCurve(to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.18),
                              control1: CGPoint(x: rect.width * 0.76, y: rect.height * 0.28),
                              control2: CGPoint(x: rect.width * 0.65, y: rect.height * 0.12))
            }
            return path
        }
    }
}

/// The gear, in a cream square screwed to the wall. Same two-layer press as
/// the panels, at a quarter of the size.
struct SettingsButton: View {
    var metrics: MainMenuSceneMetrics
    var action: () -> Void

    @State private var isPressing = false

    private var scale: CGFloat { metrics.scale }

    var body: some View {
        let side = metrics.settingsFrame.width
        let shape = RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)

        Button {
            Haptics.menuOpen()
            action()
        } label: {
            ZStack {
                shape.fill(LinearGradient(colors: [Paper.page, Paper.pageWarm],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay { PaperGrain(opacity: 0.05, seed: 12).clipShape(shape) }
                    .overlay { shape.strokeBorder(Paper.pageEdge, lineWidth: 1) }

                Image(systemName: "gearshape.fill")
                    .font(.system(size: side * 0.52, weight: .semibold))
                    .foregroundStyle(Paper.ink)
                    .rotationEffect(.degrees(isPressing ? 8 : 0))
            }
            .frame(width: side, height: side)
            .offset(y: isPressing ? 1.5 : 0)
            .scaleEffect(isPressing ? 0.97 : 1)
            .shadow(color: .black.opacity(0.45),
                    radius: (isPressing ? 3 : 7) * scale,
                    y: (isPressing ? 2 : 5) * scale)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressing = true }
                .onEnded { _ in isPressing = false }
        )
        .animation(.snappy(duration: 0.14), value: isPressing)
        .accessibilityLabel("Settings")
        .accessibilityHint("Haptics, room settings, paper themes and how to play")
    }
}

/// Bookbinder's cloth: a warp and a weft, drawn once. Almost invisible on its
/// own and the whole difference between cloth and paint when the lamp crosses
/// it.
private struct FabricWeave: View {
    var body: some View {
        Canvas { context, size in
            let width = Double(size.width)
            let height = Double(size.height)
            let step: Double = 2.6

            var x: Double = 0
            while x < width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: height))
                context.stroke(line, with: .color(.black.opacity(0.07)), lineWidth: 0.8)
                x += step
            }
            var y: Double = 0
            while y < height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: width, y: y))
                context.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 0.8)
                y += step
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

/// The fixed plate a control is bolted to: a routed recess in the drawer front
/// with four screws in it.
///
/// This is the part that answers "what is holding you there". Without it a
/// panel is a rounded rectangle with a shadow — which is to say, a card. It
/// never moves; only the face inside it travels, and only by three points.
private struct MountingPlate: View {
    var scale: CGFloat
    var corner: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack {
            // The plate itself: a piece of the same walnut, screwed on flat.
            WoodFace(light: Color(hex: 0x6A4728), mid: Color(hex: 0x452C16),
                     dark: Color(hex: 0x281809), seed: 23)
                .clipShape(shape)
                .overlay {
                    // Routed: dark at the top of the recess where the light
                    // cannot reach, lit along the bottom lip.
                    shape.strokeBorder(
                        LinearGradient(colors: [.black.opacity(0.75), .clear,
                                                .white.opacity(0.16)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: max(1, 3 * scale))
                }

            // Four screws, at the corners of the plate.
            GeometryReader { proxy in
                let inset = max(5, 13 * scale)
                ForEach(0..<4, id: \.self) { index in
                    PlateScrew(diameter: max(4, 11 * scale))
                        .position(x: index % 2 == 0 ? inset : proxy.size.width - inset,
                                  y: index < 2 ? inset : proxy.size.height - inset)
                }
            }
        }
        // Screwed flat to the drawer: a seam, and almost no cast.
        .shadow(color: .black.opacity(0.55), radius: max(0.6, 1.2 * scale),
                x: max(0.3, 0.8 * scale), y: max(0.6, 1.2 * scale))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The same screw as the one in the wall sign, at the size a fitting uses.
private struct PlateScrew: View {
    var diameter: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [ClubRoomMaterial.brassLit, ClubRoomMaterial.brass,
                                          Color(hex: 0x4A3413)],
                                 center: .init(x: 0.34, y: 0.30),
                                 startRadius: 0, endRadius: diameter * 0.75))
            .overlay {
                Capsule()
                    .fill(.black.opacity(0.5))
                    .frame(width: diameter * 0.60, height: max(0.6, diameter * 0.13))
                    .rotationEffect(.degrees(-34))
            }
            .overlay(Circle().strokeBorder(.black.opacity(0.40), lineWidth: 0.6))
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.45), radius: 1, y: 0.8)
    }
}
