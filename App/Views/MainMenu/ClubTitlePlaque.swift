import SwiftUI

/// The sign on the wall.
///
/// Wood, four screws and an ornament — all drawn — with the club's name set
/// live on top of it. The name is the one thing on this screen that a
/// generated image would ruin: baked lettering warps the moment the plaque is
/// a different width, and it cannot be read out loud.
struct ClubTitlePlaque: View {
    var metrics: MainMenuSceneMetrics
    var phase: Double
    var reduceMotion: Bool

    private var scale: CGFloat { metrics.scale }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)

        ZStack {
            // The board.
            WoodFace(light: Color(hex: 0xA97A45), mid: Color(hex: 0x81572F),
                     dark: Color(hex: 0x5A3A1F), seed: 53)
                .clipShape(shape)

            // Lit from the lamp's side, and turning under along the bottom.
            shape.fill(LinearGradient(
                stops: [
                    .init(color: ClubRoomMaterial.lampWarm.opacity(0.26), location: 0),
                    .init(color: .clear, location: 0.42),
                    .init(color: .black.opacity(0.34), location: 1),
                ],
                startPoint: .topLeading, endPoint: .trailing))

            // The routed lettering.
            title
                .padding(.horizontal, 22 * scale)

            // Screws, one at each corner.
            GeometryReader { proxy in
                let inset = 22 * scale
                ForEach(0..<4, id: \.self) { index in
                    Screw(diameter: max(5, 13 * scale))
                        .position(x: index % 2 == 0 ? inset : proxy.size.width - inset,
                                  y: index < 2 ? inset : proxy.size.height - inset)
                }
            }
        }
        .overlay {
            // The moulded edge of the board.
            shape.strokeBorder(.black.opacity(0.45), lineWidth: 1.4 * scale)
            shape.strokeBorder(ClubRoomMaterial.brass.opacity(0.10), lineWidth: 0.6 * scale)
                .padding(1.4 * scale)
        }
        // Varnish catching the light, and nothing else on the screen doing so
        // at the same moment.
        .modifier(MaterialLightTrace(phase: phase, strength: reduceMotion ? 0 : 0.55,
                                     shape: AnyShape(shape)))
        // Screwed to the wall, so the shadow starts at its edges: a dark seam
        // all round, then a weak cast down and right from the lamp.
        .shadow(color: .black.opacity(0.55), radius: 1.2 * scale,
                x: 0.8 * scale, y: 1.2 * scale)
        .shadow(color: .black.opacity(0.22), radius: 4 * scale,
                x: 2.5 * scale, y: 3.5 * scale)
        .frame(width: metrics.titlePlaqueFrame.width, height: metrics.titlePlaqueFrame.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Probably Sudoku")
        .accessibilityAddTraits(.isHeader)
    }

    private var title: some View {
        VStack(spacing: 0) {
            SunOrnament()
                .frame(width: 64 * scale, height: 42 * scale)

            // The rule sits between the ornament and the name, either side of
            // it — never across the letters.
            Flourish()
                .stroke(Color(hex: 0x223A1D).opacity(0.65), lineWidth: max(0.9, 2.6 * scale))
                .frame(height: 12 * scale)
                .padding(.horizontal, 40 * scale)
                .padding(.top, 4 * scale)

            LetterpressText(text: "PROBABLY", size: 44 * scale)
                .padding(.top, 12 * scale)
            LetterpressText(text: "SUDOKU", size: 64 * scale)
                .padding(.top, 2 * scale)
        }
    }
}
/// Live text that reads as cut into the wood: one dark impression below, one
/// warm catch of light above, and the ink itself in the club's green. Three
/// hairline layers, not a bevel filter.
private struct LetterpressText: View {
    var text: String
    var size: CGFloat

    var body: some View {
        Text(text)
            .font(Print.clubTitle(size))
            .tracking(size * 0.012)
            .lineLimit(1)
            // Only as a last resort: the plaque is sized so this never fires
            // on any phone, but a longer word in another language might.
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color(hex: 0x223A1D))
            .background {
                Text(text)
                    .font(Print.clubTitle(size))
                    .tracking(size * 0.012)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.black.opacity(0.45))
                    .offset(y: max(0.5, size * 0.018))
            }
            .background {
                Text(text)
                    .font(Print.clubTitle(size))
                    .tracking(size * 0.012)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(ClubRoomMaterial.lampWarm.opacity(0.30))
                    .offset(y: -max(0.5, size * 0.012))
            }
    }
}

/// A screw, at the depth a screw sits: bright on the lamp's side, dark on the
/// other, with a slot across it.
private struct Screw: View {
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
                    .frame(width: diameter * 0.62, height: max(0.7, diameter * 0.12))
                    .rotationEffect(.degrees(28))
            }
            .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 0.6))
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
    }
}

/// The little sun stamped above the name. Drawn, because a five-pixel face in
/// a generated image is where generators put a sixth eye.
private struct SunOrnament: View {
    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height * 0.62)
            let radius = min(size.width, size.height) * 0.34
            let ink = GraphicsContext.Shading.color(Color(hex: 0x223A1D).opacity(0.9))

            context.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                                  width: radius * 2, height: radius * 2)),
                           with: ink, lineWidth: max(0.6, radius * 0.14))

            // Rays, over the top half only — it is a sun on a sign, not a
            // compass rose.
            for step in 0..<7 {
                let angle = .pi + Double(step) / 6 * .pi
                var ray = Path()
                ray.move(to: CGPoint(x: centre.x + cos(angle) * radius * 1.35,
                                     y: centre.y + sin(angle) * radius * 1.35))
                ray.addLine(to: CGPoint(x: centre.x + cos(angle) * radius * 1.75,
                                        y: centre.y + sin(angle) * radius * 1.75))
                context.stroke(ray, with: ink, lineWidth: max(0.5, radius * 0.12))
            }

            // A face, kept to three marks.
            let eye = radius * 0.16
            for side in [-1.0, 1.0] {
                context.fill(
                    Path(ellipseIn: CGRect(x: centre.x + side * radius * 0.36 - eye,
                                           y: centre.y - radius * 0.22 - eye,
                                           width: eye * 2, height: eye * 2)),
                    with: ink)
            }
            var smile = Path()
            smile.addArc(center: centre, radius: radius * 0.48,
                         startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
            context.stroke(smile, with: ink, lineWidth: max(0.5, radius * 0.12))
        }
        .allowsHitTesting(false)
    }
}

/// The pair of swashes either side of the ornament.
private struct Flourish: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm = rect.width * 0.42

        for side in [0.0, 1.0] {
            let outer = side == 0 ? rect.minX : rect.maxX
            let inner = side == 0 ? rect.minX + arm : rect.maxX - arm
            path.move(to: CGPoint(x: outer, y: rect.midY))
            path.addCurve(
                to: CGPoint(x: inner, y: rect.midY),
                control1: CGPoint(x: outer + (inner - outer) * 0.35, y: rect.minY),
                control2: CGPoint(x: outer + (inner - outer) * 0.65, y: rect.maxY))
        }
        return path
    }
}

// MARK: - Subtitle

/// The strip pinned under the sign. Quieter than the plaque in every way:
/// paper rather than wood, ink rather than routing, and small.
struct ClubSubtitlePlaque: View {
    var metrics: MainMenuSceneMetrics

    private var scale: CGFloat { metrics.scale }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)

        Text("Nine numbers. Several bad decisions.")
            .font(Print.caption(max(9, 20 * scale)))
            .textCase(.uppercase)
            .tracking(max(0.8, 2.2 * scale))
            .foregroundStyle(Paper.ink.opacity(0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 22 * scale)
            .frame(width: metrics.subtitlePlaqueFrame.width,
                   height: metrics.subtitlePlaqueFrame.height)
            .background {
                shape.fill(LinearGradient(colors: [Paper.page, Paper.pageWarm],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay { PaperGrain(opacity: 0.05, seed: 91).clipShape(shape) }
            }
            .overlay { shape.strokeBorder(Paper.pageEdge, lineWidth: 1) }
            .overlay(alignment: .topLeading) { pin.padding(10 * scale) }
            .overlay(alignment: .topTrailing) { pin.padding(10 * scale) }
            .shadow(color: .black.opacity(0.5), radius: 1.0 * scale,
                    x: 0.6 * scale, y: 1.0 * scale)
            .shadow(color: .black.opacity(0.18), radius: 3 * scale,
                    x: 2 * scale, y: 2.6 * scale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Nine numbers. Several bad decisions.")
    }

    private var pin: some View {
        Circle()
            .fill(RadialGradient(colors: [ClubRoomMaterial.brassLit, ClubRoomMaterial.brass],
                                 center: .init(x: 0.35, y: 0.3),
                                 startRadius: 0, endRadius: 6 * scale))
            .frame(width: max(4, 11 * scale), height: max(4, 11 * scale))
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
    }
}
