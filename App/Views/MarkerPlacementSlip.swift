import SwiftUI
import ProbablySudokuEngine

/// §11 — a Marker marks a square, and the square is chosen the moment the
/// Marker is gained. Asked on a blank grid, because the board is regenerated
/// every Puzzle and the position is what persists, not the numbers.
struct MarkerPlacementSlip: View {
    @Bindable var model: GameModel
    var markerIndex: Int
    var onDone: () -> Void

    private var marker: OwnedMarker? {
        model.run.markers.indices.contains(markerIndex) ? model.run.markers[markerIndex] : nil
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
            closeLabel: pending > 0 ? "Skip for now" : "Done",
            dismissesOnBackground: false,
            onClose: onDone
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let marker {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Paper.markerColor(marker.defID))
                            .frame(width: 16, height: 16)
                    }
                    Text(pending > 0
                         ? "\(pending) square\(pending == 1 ? "" : "s") to place"
                         : "All placed")
                        .font(Print.caption(11))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(pending > 0 ? Paper.redPencil : Paper.sageDeep)
                }

                BlankGridPicker(model: model, markerIndex: markerIndex)

                Text("Tap any square. An occupied square is replaced by this Marker.")
                    .font(Print.body(11.5))
                    .foregroundStyle(Paper.inkSoft)

                Text("Marked squares are worth more on harder Puzzles: the fewer numbers "
                     + "are already printed, the more of your marks come into play.")
                    .font(Print.body(11.5))
                    .foregroundStyle(Paper.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The grid as positions rather than as a puzzle: no numbers, because a Marker
/// outlives every board it sits on.
private struct BlankGridPicker: View {
    @Bindable var model: GameModel
    var markerIndex: Int

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                ForEach(Square.all, id: \.index) { square in
                    let owner = model.run.markedSquares[square]
                    Button {
                        model.claimSquare(markerIndex: markerIndex, square: square)
                    } label: {
                        Rectangle()
                            .fill(owner.map { Paper.markerColor($0.defID).opacity(0.55) }
                                  ?? Paper.pageWarm)
                            .overlay {
                                Rectangle().strokeBorder(owner == nil ? Paper.gridHair : Paper.redPencil,
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
                        context.stroke(v, with: .color(Paper.gridBold), lineWidth: 2)
                        context.stroke(h, with: .color(Paper.gridBold), lineWidth: 2)
                    }
                    context.stroke(Path(CGRect(x: 0, y: 0, width: side, height: side)),
                                   with: .color(Paper.gridBold), lineWidth: 2.5)
                }
                .frame(width: side, height: side)
                .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
