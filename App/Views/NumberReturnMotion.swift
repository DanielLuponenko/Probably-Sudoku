import SwiftUI
import ProbablySudokuEngine

/// Named frames keep this visual layer independent of the rules and the
/// layout. A number can travel between the board, Hand, and Pool label without
/// turning any of those views into a drag-and-drop controller.
enum NumberReturnMotionAnchor {
    static let space = "number-return-motion"
    static let grid = "grid"
    static let hand = "hand"
    static let pool = "pool"
    static func cell(_ square: Square) -> String { "cell-\(square.index)" }
    static func card(_ id: UUID) -> String { "card-\(id.uuidString)" }
}

/// Layout observations are the only source of coordinates. A reordered Hand,
/// a wide overflow Hand, and an inset board frame all use the same resolver.
/// A clipped card travels from/to the visible edge of its actual scroll view.
struct NumberReturnGeometry {
    let frames: [String: CGRect]

    func cell(_ square: Square) -> CGRect? {
        validFrame(NumberReturnMotionAnchor.cell(square))
    }

    func cardPoint(_ id: UUID) -> CGPoint? {
        guard let card = validFrame(NumberReturnMotionAnchor.card(id)) else { return nil }
        let center = CGPoint(x: card.midX, y: card.midY)
        guard let viewport = validFrame(NumberReturnMotionAnchor.hand) else { return center }
        let halfWidth = min(card.width / 2, viewport.width / 2)
        return CGPoint(x: min(viewport.maxX - halfWidth, max(viewport.minX + halfWidth, center.x)),
                       y: center.y)
    }

    var poolPoint: CGPoint? {
        guard let frame = validFrame(NumberReturnMotionAnchor.pool) else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func validFrame(_ name: String) -> CGRect? {
        guard let frame = frames[name], !frame.isEmpty, !frame.isNull, !frame.isInfinite,
              frame.origin.x.isFinite, frame.origin.y.isFinite else { return nil }
        return frame
    }
}

struct NumberReturnMotionFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func numberReturnMotionFrame(_ name: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NumberReturnMotionFrames.self,
                    value: [name: proxy.frame(in: .named(NumberReturnMotionAnchor.space))]
                )
            }
        }
    }
}

/// A small paper trail for numbers that were rejected, tossed, or replaced.
/// Events stay in `GameModel` only briefly, so this never controls input or
/// accumulates view state after a turn has finished.
struct NumberReturnMotionOverlay: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.cosmeticTheme) private var theme
    let events: [GameModel.NumberReturn]
    let frames: [String: CGRect]

    var body: some View {
        GeometryReader { _ in
            ForEach(events) { event in
                NumberReturnMotion(event: event, frames: frames,
                                   reduceMotion: reduceMotion)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .cosmeticPulseClock(for: theme.numbers.finish)
    }
}

private struct NumberReturnMotion: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette

    let event: GameModel.NumberReturn
    let frames: [String: CGRect]
    let reduceMotion: Bool
    @State private var arrived = false

    var body: some View {
        Group {
            switch event.kind {
            case .fouled:
                EmptyView() // The committed impact now lands in BossInkLandingOverlay.
            case .barred:
                barredNumbers
            case .pool, .hand, .redraw:
                travellingNumbers
            }
        }
        .onAppear {
            guard !reduceMotion else {
                arrived = true
                return
            }
            withAnimation(theme.numbers.motion.arrivalAnimation) {
                arrived = true
            }
        }
    }

    private var travellingNumbers: some View {
        ForEach(Array(event.digits.enumerated()), id: \.offset) { index, digit in
            if let start = source(for: event, index: index),
               let end = destination(for: event, index: index) {
                ReturnNumberTile(digit: digit, theme: theme, palette: palette,
                                 penalty: index == 0 ? event.penalty : nil)
                    .scaleEffect(reduceMotion ? 0.9 : (arrived ? theme.numbers.motion.returnScale : 1))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (arrived ? theme.numbers.motion.returnRotation : 0)))
                    .opacity(reduceMotion ? 0.95 : (arrived ? 0 : 1))
                    .position(reduceMotion ? end : (arrived ? end : start))
            }
        }
    }

    private var barredNumbers: some View {
        ForEach(Array(event.digits.enumerated()), id: \.offset) { index, digit in
            if let point = handPoint(index: index) {
                ZStack {
                    ReturnNumberTile(digit: digit, theme: theme, palette: palette, penalty: nil)
                    Rectangle()
                        .fill(palette.danger.opacity(0.85))
                        .frame(width: 37, height: 2)
                        .rotationEffect(.degrees(-16))
                }
                .scaleEffect(reduceMotion ? 1 : (arrived ? 1 : 0.55))
                .opacity(reduceMotion ? 1 : (arrived ? 1 : 0))
                .position(point)
            }
        }
    }

    private var fouledMarks: some View {
        ForEach(event.fouledSquares, id: \.index) { square in
            if let frame = geometry.cell(square) {
                Circle()
                    .fill(palette.ink.opacity(0.22))
                    .frame(width: frame.width * 0.72, height: frame.height * 0.45)
                    .rotationEffect(.degrees(-17))
                    .scaleEffect(reduceMotion ? 1 : (arrived ? 1 : 0.35))
                    .opacity(reduceMotion ? 0.8 : (arrived ? 0.8 : 0))
                    .position(x: frame.midX, y: frame.midY)
            }
        }
    }

    private var geometry: NumberReturnGeometry { NumberReturnGeometry(frames: frames) }

    private func source(for event: GameModel.NumberReturn, index: Int) -> CGPoint? {
        if let square = event.square { return gridPoint(for: square) }
        return handPoint(index: index)
    }

    private func destination(for event: GameModel.NumberReturn, index: Int) -> CGPoint? {
        switch event.kind {
        case .hand:
            return handPoint(index: index)
        case .pool, .redraw:
            return geometry.poolPoint
        case .barred, .fouled:
            return handPoint(index: index)
        }
    }

    private func handPoint(index: Int) -> CGPoint? {
        guard event.handCardIDs.indices.contains(index) else { return nil }
        return geometry.cardPoint(event.handCardIDs[index])
    }

    private func gridPoint(for square: Square) -> CGPoint? {
        guard let frame = geometry.cell(square) else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

private struct ReturnNumberTile: View {
    let digit: Digit
    let theme: CosmeticTheme
    let palette: LevelPalette
    let penalty: Int?

    var body: some View {
        ZStack(alignment: .bottom) {
            CosmeticNumberGlyph(text: "\(digit.rawValue)", skin: theme.numbers,
                                size: 27, weight: .medium, color: theme.numbers.ink,
                                showsPressShadow: false)
                .frame(width: 46, height: 52)
                .background(GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(GameplaySurface.sage.opacity(0.4), lineWidth: 1)
                }
            if let penalty, penalty > 0 {
                Text("−\(penalty)")
                    .font(Print.caption(10))
                    .foregroundStyle(palette.danger)
                    .offset(y: 16)
            }
        }
    }
}
