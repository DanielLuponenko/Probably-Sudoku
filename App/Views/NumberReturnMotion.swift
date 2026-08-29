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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cosmeticTheme) private var theme
    let events: [GameModel.NumberReturn]
    let frames: [String: CGRect]

    var body: some View {
        GeometryReader { proxy in
            ForEach(events) { event in
                NumberReturnMotion(event: event, frames: frames, canvas: proxy.size,
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
    let canvas: CGSize
    let reduceMotion: Bool
    @State private var arrived = false

    var body: some View {
        Group {
            switch event.kind {
            case .fouled:
                fouledMarks
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
        ForEach(Array(event.digits.prefix(6).enumerated()), id: \.offset) { index, digit in
            let start = source(for: event, index: index)
            let end = destination(for: event, index: index)
            ReturnNumberTile(digit: digit, theme: theme, palette: palette,
                             penalty: index == 0 ? event.penalty : nil)
                .scaleEffect(reduceMotion ? 0.9 : (arrived ? theme.numbers.motion.returnScale : 1))
                .rotationEffect(.degrees(reduceMotion ? 0 : (arrived ? theme.numbers.motion.returnRotation : 0)))
                .opacity(reduceMotion ? 0.95 : (arrived ? 0 : 1))
                .position(reduceMotion ? end : (arrived ? end : start))
        }
    }

    private var barredNumbers: some View {
        ForEach(Array(event.digits.prefix(4).enumerated()), id: \.offset) { index, digit in
            let point = handPoint(index: index)
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

    private var fouledMarks: some View {
        ForEach(event.fouledSquares, id: \.index) { square in
            Circle()
                .fill(palette.ink.opacity(0.22))
                .frame(width: cellSize * 0.72, height: cellSize * 0.45)
                .rotationEffect(.degrees(-17))
                .scaleEffect(reduceMotion ? 1 : (arrived ? 1 : 0.35))
                .opacity(reduceMotion ? 0.8 : (arrived ? 0.8 : 0))
                .position(gridPoint(for: square))
        }
    }

    private var gridFrame: CGRect { frames[NumberReturnMotionAnchor.grid] ?? .zero }
    private var handFrame: CGRect { frames[NumberReturnMotionAnchor.hand] ?? .zero }
    private var poolFrame: CGRect { frames[NumberReturnMotionAnchor.pool] ?? .zero }
    private var cellSize: CGFloat { gridFrame.width > 0 ? gridFrame.width / 9 : 34 }

    private func source(for event: GameModel.NumberReturn, index: Int) -> CGPoint {
        if let square = event.square { return gridPoint(for: square) }
        return handPoint(index: index)
    }

    private func destination(for event: GameModel.NumberReturn, index: Int) -> CGPoint {
        switch event.kind {
        case .hand:
            return handPoint(index: index)
        case .pool, .redraw:
            let target = poolFrame == .zero
                ? CGPoint(x: canvas.width * 0.84, y: canvas.height * 0.77)
                : CGPoint(x: poolFrame.midX, y: poolFrame.midY)
            return CGPoint(x: target.x + CGFloat(index % 3 - 1) * 10,
                           y: target.y + CGFloat(index / 3) * 7)
        case .barred, .fouled:
            return handPoint(index: index)
        }
    }

    private func handPoint(index: Int) -> CGPoint {
        guard handFrame != .zero else {
            return CGPoint(x: canvas.width * 0.5 + CGFloat(index - 2) * 42,
                           y: canvas.height * 0.82)
        }
        let columns = max(1, min(7, event.digits.count))
        let fraction = (CGFloat(index) + 0.5) / CGFloat(columns)
        return CGPoint(x: handFrame.minX + handFrame.width * fraction, y: handFrame.midY)
    }

    private func gridPoint(for square: Square) -> CGPoint {
        guard gridFrame != .zero else {
            return CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.48)
        }
        return CGPoint(x: gridFrame.minX + (CGFloat(square.col) + 0.5) * cellSize,
                       y: gridFrame.minY + (CGFloat(square.row) + 0.5) * cellSize)
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
                                size: 27, weight: .medium, color: theme.numbers.ink)
                .frame(width: 46, height: 52)
                .background(theme.paper.warm, in: RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(theme.board.hair, lineWidth: 1)
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
