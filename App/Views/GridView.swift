import SwiftUI
import NumberClubEngine

/// The printed grid. Everything here is drawn rather than exported: the rules,
/// the washes, the marks. Only the paper underneath is artwork.
struct GridView: View {
    @Bindable var model: GameModel
    var board: Board

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                cells(cell: cell)
                rules(side: side, cell: cell)
                clears(side: side, cell: cell)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    // MARK: Cells

    private func cells(cell: CGFloat) -> some View {
        ForEach(Square.all, id: \.index) { square in
            CellView(
                square: square,
                digit: board[square],
                provenance: board.filledBy[square.index],
                state: state(for: square),
                marker: model.visibleMarkers[square],
                size: cell
            )
            .position(x: (CGFloat(square.col) + 0.5) * cell,
                      y: (CGFloat(square.row) + 0.5) * cell)
            .onTapGesture { model.tapSquare(square) }
        }
    }

    private func state(for square: Square) -> CellState {
        // The square you tapped is one of the matches, so it is marked the same
        // way. Giving it its own colour made it look like a different kind of
        // thing from the numbers it had just found.
        if let digit = model.highlightedDigit, board[square] == digit { return .sameNumber }
        if model.selectedSquare == square { return .selected }
        return .plain
    }

    /// A completed row, column or box, marked once and then let go. Completing
    /// a unit is worth far more than a placement (§6), so it is worth seeing.
    private func clears(side: CGFloat, cell: CGFloat) -> some View {
        ForEach(model.cleared) { clear in
            ClearedUnitMark(cells: Geometry.cells(of: clear.unit, through: clear.square),
                            cell: cell)
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
                let style = GraphicsContext.Shading.color(heavy ? Paper.gridBold : Paper.gridHair)
                context.stroke(vertical, with: style, lineWidth: heavy ? 2 : 0.75)
                context.stroke(horizontal, with: style, lineWidth: heavy ? 2 : 0.75)
            }
            context.stroke(Path(CGRect(x: 0, y: 0, width: side, height: side)),
                           with: .color(Paper.gridBold), lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }
}

enum CellState {
    case plain, selected, sameNumber
}

/// Washes the cells of a finished unit and rules a heavy line round it — the
/// whole row for a row, and the box's own three-by-three for a box.
private struct ClearedUnitMark: View {
    var cells: [Square]
    var cell: CGFloat
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
                    .fill(Paper.cellCleared)
                    .blendMode(.multiply)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(square.col) * cell, y: CGFloat(square.row) * cell)
            }
            Rectangle()
                .strokeBorder(Paper.sageDeep, lineWidth: 3)
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
    var square: Square
    var digit: Digit?
    var provenance: Provenance?
    var state: CellState
    var marker: OwnedMarker?
    var size: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(background)

            if let marker {
                // A Marker tints the square it owns, so its bonus is visible
                // before you decide what to play there (§11).
                Rectangle()
                    .fill(Paper.markerColor(marker.defID).opacity(0.34))
                Rectangle()
                    .strokeBorder(Paper.markerColor(marker.defID).opacity(0.85), lineWidth: 1.5)
            }

            if state == .sameNumber {
                Rectangle()
                    .strokeBorder(Paper.sageDeep.opacity(0.7), lineWidth: 1.5)
            }

            if let digit {
                Text("\(digit.rawValue)")
                    .font(Print.numeral(size * 0.52, weight: numeralWeight))
                    .foregroundStyle(inkColor)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.2), value: digit)
        .animation(.snappy(duration: 0.16), value: state)
        .accessibilityLabel(accessibilityLabel)
    }

    private var numeralWeight: Font.Weight {
        if state == .sameNumber { return .bold }
        return provenance == .given ? .semibold : .regular
    }

    private var background: Color {
        switch state {
        case .selected: return Paper.cellSelected
        case .sameNumber: return Paper.cellSameNumber
        case .plain: return provenance == .given ? Paper.cellGiven : .clear
        }
    }

    /// A Given is printed; a number you placed is written; a Clue is written by
    /// someone else, so it sits lighter on the page.
    private var inkColor: Color {
        switch provenance {
        case .given: return Paper.ink
        case .clue: return Paper.inkFaint
        default: return Paper.ink.opacity(0.92)
        }
    }

    private var accessibilityLabel: String {
        var parts = [square.description]
        if let digit { parts.append("\(digit.rawValue)") } else { parts.append("empty") }
        if provenance == .given { parts.append("given") }
        if let marker { parts.append(marker.def.name) }
        if state == .sameNumber { parts.append("matches selection") }
        return parts.joined(separator: ", ")
    }
}
