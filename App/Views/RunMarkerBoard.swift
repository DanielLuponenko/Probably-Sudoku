import SwiftUI
import ProbablySudokuEngine

/// Takes only a value snapshot: this surface cannot place a number, spend a
/// Buff, or move a Marker. Its only mutable state is which square is inspected.
struct RunMarkerBoard: View {
    let run: RunState
    @State private var selected: Square?
    @State private var inspecting = false

    private var marked: [Square: OwnedMarker] { run.markedSquares }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap a marked square to inspect it. Positions stay with this Book.")
                .font(Print.body(12))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            board
                .padding(5)
                .background(Paper.pageEdge)
                .overlay { Rectangle().strokeBorder(Paper.gridBold, lineWidth: 1) }
                .shadow(color: .black.opacity(0.18), radius: 3, x: 1, y: 3)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
                .popover(isPresented: $inspecting) {
                    if let selected, let marker = marked[selected] {
                        ScrollView {
                            RunMarkerDetail(marker: marker, square: selected, board: run.puzzle?.board)
                        }
                        .frame(idealWidth: 300, idealHeight: 220)
                        .presentationCompactAdaptation(.popover)
                        .presentationBackground(Paper.pageWarm)
                    }
                }

            if let selected, let marker = marked[selected] {
                RunMarkerDetail(marker: marker, square: selected, board: run.puzzle?.board)
            } else {
                Text(marked.isEmpty ? "No Markers placed yet. Choose a square when you buy a Marker."
                     : "\(marked.count) marked squares. Tap a color or choose a Marker below.")
                    .font(Print.body(12))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Full-width targets are an alternative to the compact grid cells.
            // They also expose the symbol/color pairing before a square is tapped.
            ForEach(Markers.all.filter { def in run.markers.contains { $0.defID == def.id } }, id: \.id) { def in
                let squares = Square.all.filter { marked[$0]?.defID == def.id }
                Button {
                    selected = squares.first
                    inspecting = selected != nil
                } label: {
                    HStack(spacing: 8) {
                        MarkerKey(defID: def.id)
                        Text(def.name).font(Print.subheading(12))
                        Spacer(minLength: 4)
                        Text(squares.isEmpty ? "Unplaced" : "\(squares.count)")
                            .font(Print.numeral(12, weight: .medium))
                    }
                    .foregroundStyle(Paper.ink)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(squares.isEmpty)
                .accessibilityLabel("\(def.name), \(squares.count) marked squares")
                .accessibilityHint("Inspect the first square carrying this Marker")
            }
        }
    }

    private var board: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / 9
            ZStack(alignment: .topLeading) {
                Paper.pageWarm
                ForEach(Square.all, id: \.index) { square in
                    let marker = marked[square]
                    Button {
                        selected = square
                        inspecting = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Rectangle()
                                .fill(marker.map { Paper.markerColor($0.defID).opacity(0.30) } ?? Paper.page)
                            if let digit = run.puzzle?.board[square] {
                                Text("\(digit.rawValue)")
                                    .font(Print.numeral(cell * 0.48, weight: .medium))
                                    .foregroundStyle(Paper.ink.opacity(marker == nil ? 0.45 : 0.9))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            if let marker {
                                Image(systemName: MarkerAppearance.forID(marker.defID).symbol)
                                    .font(.system(size: max(7, cell * 0.24), weight: .bold))
                                    .foregroundStyle(Paper.markerColor(marker.defID))
                                    .padding(2)
                            }
                        }
                        .frame(width: cell, height: cell)
                        .overlay {
                            Rectangle().strokeBorder(selected == square ? Paper.ink : Paper.gridHair,
                                                     lineWidth: selected == square ? 2.5 : 0.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(marker == nil)
                    .position(x: (CGFloat(square.col) + 0.5) * cell,
                              y: (CGFloat(square.row) + 0.5) * cell)
                    .accessibilityLabel("Row \(square.row + 1), column \(square.col + 1), \(marker?.def.name ?? "no Marker")")
                    .accessibilityHint(marker == nil ? "" : "Shows this Marker’s effect. Does not change the board.")
                    .accessibilityAddTraits(selected == square ? .isSelected : [])
                    .accessibilityIdentifier("run-marker-\(square.index)")
                }
                Canvas { context, size in
                    for index in [3, 6] {
                        let p = CGFloat(index) * cell
                        var lines = Path()
                        lines.move(to: .init(x: p, y: 0)); lines.addLine(to: .init(x: p, y: size.height))
                        lines.move(to: .init(x: 0, y: p)); lines.addLine(to: .init(x: size.width, y: p))
                        context.stroke(lines, with: .color(Paper.gridBold), lineWidth: 2)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your Marker board, nine rows and nine columns")
    }
}

struct MarkerKey: View {
    let defID: String
    var body: some View {
        Image(systemName: MarkerAppearance.forID(defID).symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Paper.ink)
            .frame(width: 25, height: 25)
            .background(Paper.markerColor(defID).opacity(0.5), in: .rect(cornerRadius: 3))
            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Paper.markerColor(defID), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

struct RunMarkerDetail: View {
    let marker: OwnedMarker
    let square: Square
    let board: Board?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                MarkerKey(defID: marker.defID)
                Text(marker.def.name).font(Print.subheading(16))
            }
            Text("Row \(square.row + 1), column \(square.col + 1)")
                .font(Print.caption(12))
            Text(marker.def.text)
                .font(Print.body(13))
                .fixedSize(horizontal: false, vertical: true)
            if board?.filledBy[square.index] == .given {
                Text("A printed number occupies this square in this Puzzle, so its Marker cannot trigger here. It remains yours for later Puzzles.")
                    .font(Print.body(12)).foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Paper.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Paper.pageWarm)
        .overlay(alignment: .leading) { Rectangle().fill(Paper.markerColor(marker.defID)).frame(width: 3) }
        .accessibilityElement(children: .combine)
    }
}
