import SwiftUI
import ProbablySudokuEngine

/// The printed grid. Everything here is drawn rather than exported: the rules,
/// the washes, the marks. Only the paper underneath is artwork.
struct GridView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    @Bindable var model: GameModel
    var board: Board

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                Rectangle().fill(theme.paper.page)
                BossBoardUnderprint(boss: model.puzzle?.boss,
                                    fouled: model.fouledSquares,
                                    greyed: model.greyedSquares)
                cells(cell: cell)
                rules(side: side, cell: cell)
                clears(side: side, cell: cell)
            }
            .frame(width: side, height: side)
            .background {
                Rectangle()
                    .fill(theme.paper.page)
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 4)
            }
            .overlay { Rectangle().strokeBorder(theme.board.bold, lineWidth: theme.board.boldWidth + 0.8) }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .numberReturnMotionFrame(NumberReturnMotionAnchor.grid)
    }

    // MARK: Cells

    private func cells(cell: CGFloat) -> some View {
        let fouledSquares = model.fouledSquares
        let greyedSquares = model.greyedSquares

        return ForEach(Square.all, id: \.index) { square in
            let digit = board[square]
            let provenance = board.filledBy[square.index]
            let cellState = state(for: square)
            let marker = model.visibleMarkers[square]
            Button {
                model.tapSquare(square)
            } label: {
                CellView(
                    square: square,
                    digit: digit,
                    provenance: provenance,
                    state: cellState,
                    marker: marker,
                    fouled: fouledSquares.contains(square),
                    greyed: greyedSquares.contains(square),
                    theme: theme,
                    palette: palette,
                    size: cell
                )
            }
            .buttonStyle(.plain)
            .disabled(cellState == .barred)
            .accessibilityLabel(accessibilityLabel(for: square, digit: digit,
                                                    provenance: provenance,
                                                    marker: marker))
            .accessibilityValue(accessibilityValue(for: square, digit: digit,
                                                    provenance: provenance,
                                                    state: cellState))
            .accessibilityHint(accessibilityHint(for: square, digit: digit,
                                                  state: cellState))
            .accessibilityAddTraits(model.selectedSquare == square ? .isSelected : [])
            .position(x: (CGFloat(square.col) + 0.5) * cell,
                      y: (CGFloat(square.row) + 0.5) * cell)
        }
    }

    private func accessibilityLabel(for square: Square, digit: Digit?,
                                    provenance: Provenance?, marker: OwnedMarker?) -> String {
        var parts = ["Row \(square.row + 1), column \(square.col + 1)"]
        if let digit { parts.append("number \(digit.rawValue)") } else { parts.append("empty") }
        switch provenance {
        case .given: parts.append("given")
        case .player: parts.append("placed")
        case .clue: parts.append("clue")
        case nil: break
        }
        if let marker { parts.append(marker.def.name) }
        return parts.joined(separator: ", ")
    }

    private func accessibilityValue(for square: Square, digit: Digit?,
                                    provenance: Provenance?, state: CellState) -> String {
        if state == .barred { return "Unavailable this turn" }
        if model.selectedSquare == square { return "Selected" }
        if state == .rightHere { return "Litmus match" }
        if state == .wrongHere { return "Litmus mismatch" }
        if state == .sameNumber { return "Matches selected number" }
        if digit == nil { return "Available" }
        switch provenance {
        case .given: return "Given number"
        case .player: return "Placed number"
        case .clue: return "Clue number"
        case nil: return "Number"
        }
    }

    private func accessibilityHint(for square: Square, digit: Digit?, state: CellState) -> String {
        if state == .barred { return "This square cannot be used this turn." }
        if let selected = model.selectedDigit, digit == nil {
            let warning = model.wouldConflict(square, with: selected)
                ? " This placement conflicts with the row, column, or box."
                : ""
            return "Places number \(selected.rawValue).\(warning)"
        }
        if let digit { return "Select to inspect number \(digit.rawValue)." }
        return "Select a number from the hand, then activate to place it here."
    }

    private func state(for square: Square) -> CellState {
        // The square you tapped is one of the matches, so it is marked the same
        // way. Giving it its own colour made it look like a different kind of
        // thing from the numbers it had just found.
        if model.isBarred(square) { return .barred }
        if let belongs = model.litmusReading(at: square) {
            return belongs ? .rightHere : .wrongHere
        }
        if let digit = model.highlightedDigit, board[square] == digit { return .sameNumber }
        if model.selectedSquare == square { return .selected }
        return .plain
    }

    /// A completed row, column or box, marked once and then let go. Completing
    /// a unit is worth far more than a placement (§6), so it is worth seeing.
    private func clears(side: CGFloat, cell: CGFloat) -> some View {
        ForEach(model.cleared) { clear in
            ClearedUnitMark(cells: Geometry.cells(of: clear.unit, through: clear.square),
                            cell: cell,
                            palette: palette)
        }
        .allowsHitTesting(false)
    }

    // MARK: Rules
    // Hairlines between cells, heavy lines between the nine boxes, and a heavy
    // border — the way a puzzle book prints it.

    private func rules(side: CGFloat, cell: CGFloat) -> some View {
        Canvas { context, _ in
            for i in 1..<9 {
                let offset = CGFloat(i) * cell
                var vertical = Path()
                vertical.move(to: .init(x: offset, y: 0))
                vertical.addLine(to: .init(x: offset, y: side))
                var horizontal = Path()
                horizontal.move(to: .init(x: 0, y: offset))
                horizontal.addLine(to: .init(x: side, y: offset))

                let heavy = i % 3 == 0
                let style = GraphicsContext.Shading.color(heavy ? theme.board.bold : theme.board.hair)
                context.stroke(vertical, with: style,
                               lineWidth: heavy ? theme.board.boldWidth : theme.board.hairWidth)
                context.stroke(horizontal, with: style,
                               lineWidth: heavy ? theme.board.boldWidth : theme.board.hairWidth)
            }
        }
        .allowsHitTesting(false)
    }
}

enum CellState {
    case plain, selected, sameNumber, barred, rightHere, wrongHere
}

/// Pencil hatching across a square that cannot be used this Turn.
private struct Hatching: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += rect.width / 3.5
        }
        return path
    }
}

/// Washes the cells of a finished unit and rules a heavy line round it — the
/// whole row for a row, and the box's own three-by-three for a box.
private struct ClearedUnitMark: View {
    var cells: [Square]
    var cell: CGFloat
    var palette: LevelPalette
    @State private var shown = false

    private var bounds: CGRect {
        let rows = cells.map(\.row), cols = cells.map(\.col)
        let minRow = rows.min() ?? 0, maxRow = rows.max() ?? 0
        let minCol = cols.min() ?? 0, maxCol = cols.max() ?? 0
        return CGRect(x: CGFloat(minCol) * cell,
                      y: CGFloat(minRow) * cell,
                      width: CGFloat(maxCol - minCol + 1) * cell,
                      height: CGFloat(maxRow - minRow + 1) * cell)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Multiplied rather than painted over: the numbers in the unit are
            // the point of it, and an opaque wash hides them.
            ForEach(cells, id: \.index) { square in
                Rectangle()
                    .fill(palette.target.opacity(0.22))
                    .blendMode(.multiply)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(square.col) * cell, y: CGFloat(square.row) * cell)
            }
            Rectangle()
                .strokeBorder(palette.target, lineWidth: 3)
                .frame(width: bounds.width, height: bounds.height)
                .offset(x: bounds.minX, y: bounds.minY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) { shown = true }
            withAnimation(.easeIn(duration: 0.55).delay(0.5)) { shown = false }
        }
    }
}

private struct CellView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var square: Square
    var digit: Digit?
    var provenance: Provenance?
    var state: CellState
    var marker: OwnedMarker?
    var fouled: Bool
    var greyed: Bool
    var theme: CosmeticTheme
    var palette: LevelPalette
    var size: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(background)

            if let marker {
                // A Marker tints the square it owns, so its bonus is visible
                // before you decide what to play there (§11).
                Rectangle()
                    .fill(Paper.markerColor(marker.defID).opacity(0.28))
                Rectangle()
                    .strokeBorder(palette.marked.opacity(0.9), lineWidth: 1.5)
            }

            if state == .sameNumber {
                Rectangle()
                    .strokeBorder(palette.accent.opacity(0.8), lineWidth: 1.5)
            }

            if state == .barred {
                Hatching()
                    .stroke(palette.ink.opacity(0.30), lineWidth: 1)
                    .clipShape(Rectangle())
            }

            if fouled {
                // Over Pusher's restriction is wet black ink, rather than the
                // printing fault used by the Garrys. The shape is inset so a
                // barred square remains readable as a square.
                Circle()
                    .fill(palette.ink.opacity(0.18))
                    .frame(width: size * 0.72, height: size * 0.46)
                    .rotationEffect(.degrees(-17))
            }

            if greyed {
                Rectangle()
                    .fill(palette.rule.opacity(0.14))
                    .overlay {
                        Rectangle()
                            .strokeBorder(palette.rule.opacity(0.38), lineWidth: 1)
                    }
            }

            if let digit {
                Text("\(digit.rawValue)")
                    .font(theme.numbers.font(size * 0.52, weight: numeralWeight))
                    .foregroundStyle(inkColor)
                    .shadow(color: theme.numbers.motion.glow?.opacity(0.75) ?? .clear,
                            radius: theme.numbers.motion.glow == nil ? 0 : 3)
                    .transition(reduceMotion ? .identity : placementTransition)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : theme.numbers.motion.arrivalAnimation, value: digit)
        .animation(.snappy(duration: 0.16), value: state)
    }

    private var numeralWeight: Font.Weight {
        if state == .sameNumber { return .bold }
        return provenance == .given ? .semibold : .regular
    }

    private var background: Color {
        switch state {
        case .selected: return theme.board.selected
        case .sameNumber: return palette.accent.opacity(0.28)
        case .barred: return theme.board.hair.opacity(0.45)
        case .rightHere: return palette.accent.opacity(0.28)
        case .wrongHere: return palette.danger.opacity(0.24)
        case .plain: return provenance == .given ? palette.given : .clear
        }
    }

    /// A Given is printed; a number you placed is written; a Clue is written by
    /// someone else, so it sits lighter on the page.
    private var inkColor: Color {
        switch provenance {
        case .given: return theme.numbers.givenInk.opacity(0.88)
        case .clue: return theme.numbers.ink.opacity(0.64)
        default: return theme.numbers.ink.opacity(0.94)
        }
    }

    private var placementTransition: AnyTransition {
        switch theme.numbers.motion {
        case .press: return .scale(scale: 0.72).combined(with: .opacity)
        case .typewriter: return .scale(scale: 1.14).combined(with: .opacity)
        case .pencil: return .opacity.combined(with: .scale(scale: 0.90, anchor: .leading))
        case .stencil: return .opacity.combined(with: .scale(scale: 1.05))
        case .neon: return .scale(scale: 0.60).combined(with: .opacity)
        case .handset: return .scale(scale: 0.78).combined(with: .opacity)
        }
    }

}
