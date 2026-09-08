import SwiftUI
import ProbablySudokuEngine

/// §11 — a Marker marks a square, and the square is chosen the moment the
/// Marker is gained. Asked on a blank grid, because the board is regenerated
/// every Puzzle and the position is what persists, not the numbers.
struct MarkerPlacementSlip: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.levelPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    @Bindable var model: GameModel
    var markerIndex: Int
    var onPlaced: () -> Void
    @State private var marker: OwnedMarker?

    init(model: GameModel, markerIndex: Int, onPlaced: @escaping () -> Void) {
        self.model = model
        self.markerIndex = markerIndex
        self.onPlaced = onPlaced
        // Replacing an older Marker can shift the inventory index before
        // this slip's closing fade ends. Keep its original printed identity.
        self._marker = State(initialValue: model.run.markers.indices.contains(markerIndex)
                             ? model.run.markers[markerIndex] : nil)
    }
    private var pending: Int {
        marker?.pendingSquares(atLevel: model.run.level) ?? 0
    }

    var body: some View {
        PaperSlip(
            title: "Where does it go?",
            subtitle: marker.map {
                "\($0.def.name). \($0.def.text). It keeps this square for the rest of the Book. Tap an occupied square to replace its Marker."
            },
            showsCloseButton: false,
            dismissesOnBackground: false,
            onClose: onPlaced
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let marker {
                        PrintedItemIllustration(size: 28) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Paper.markerColor(marker.defID))
                                .frame(width: 16, height: 16)
                        }
                        .accessibilityHidden(true)
                    }
                    Text(pending > 0
                         ? "\(pending) square\(pending == 1 ? "" : "s") to place"
                         : "All placed")
                        .font(Print.caption(11 * textScale))
                        .foregroundStyle(pending > 0
                                         ? palette.resolved(for: theme.paper).danger
                                         : bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
                }

                BlankGridPicker(model: model, markerIndex: markerIndex, onPlaced: onPlaced)
                    // Reserve room for the complete two-line footer inside
                    // the 620-point slip. Phones still use their available
                    // width; tablets keep all nine rows and the footer visible.
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)

                Text("Tap any square. An occupied square is replaced by this Marker.")
                    .font(Print.body(11.5 * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Marked squares are worth more on harder Puzzles: the fewer numbers "
                     + "are already printed, the more of your marks come into play.")
                    .font(Print.body(11.5 * textScale))
                    .foregroundStyle(theme.paper.faintInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The grid as positions rather than as a puzzle: no numbers, because a Marker
/// outlives every board it sits on.
private struct BlankGridPicker: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    @Bindable var model: GameModel
    var markerIndex: Int
    var onPlaced: () -> Void
    @State private var didPlace = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                ForEach(Square.all, id: \.index) { square in
                    let owner = model.run.markedSquares[square]
                    Button {
                        guard !didPlace else { return }
                        didPlace = true
                        if model.claimSquare(markerIndex: markerIndex, square: square) {
                            onPlaced()
                        } else {
                            didPlace = false
                        }
                    } label: {
                        Rectangle()
                            .fill(owner.map { Paper.markerColor($0.defID).opacity(0.55) }
                                  ?? theme.paper.warm)
                            .overlay {
                                Rectangle().strokeBorder(owner == nil ? theme.board.hair
                                                                         : palette.resolved(for: theme.paper).danger,
                                                          lineWidth: owner == nil ? 0.5 : 1.5)
                            }
                            .frame(width: cell, height: cell)
                    }
                    .buttonStyle(.plain)
                    .offset(x: CGFloat(square.col) * cell, y: CGFloat(square.row) * cell)
                    .accessibilityLabel("\(square.description)\(owner.map { ", occupied by \($0.def.name)" } ?? ", empty")")
                    .accessibilityHint(owner == nil ? "Places this Marker" : "Replaces the Marker on this square")
                }

                Canvas { context, _ in
                    for i in stride(from: 3, to: 9, by: 3) {
                        let at = CGFloat(i) * cell
                        var v = Path(); v.move(to: .init(x: at, y: 0)); v.addLine(to: .init(x: at, y: side))
                        var h = Path(); h.move(to: .init(x: 0, y: at)); h.addLine(to: .init(x: side, y: at))
                        context.stroke(v, with: .color(theme.board.bold), lineWidth: 2)
                        context.stroke(h, with: .color(theme.board.bold), lineWidth: 2)
                    }
                    context.stroke(Path(CGRect(x: 0, y: 0, width: side, height: side)),
                                   with: .color(theme.board.bold), lineWidth: 2.5)
                }
                .frame(width: side, height: side)
                .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(!didPlace)
    }
}
