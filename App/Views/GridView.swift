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
        if let digit = model.highlightedDigit, board[square] == digit {
            return model.selectedSquare == square ? .selected : .sameNumber
        }
        if model.selectedSquare == square { return .selected }
        if model.peerSquares.contains(square) { return .peer }
        return .plain
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
    case plain, peer, selected, sameNumber
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
        case .peer: return Paper.cellPeer
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
