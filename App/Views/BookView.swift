import SwiftUI
import NumberClubEngine

/// The desk the book lies on. Props are decorative and deliberately kept out of
/// the touch areas — the coffee cup sits above the top strip, the pencil and
/// eraser outside the page's right edge.
struct DeskView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Rectangle().fill(Paper.desk).ignoresSafeArea()
            WoodGrain().ignoresSafeArea()
            content
        }
        .background(Paper.deskDark)
    }
}

/// Straight, slightly irregular grain, drawn deterministically so the desk does
/// not shimmer when the view rebuilds.
private struct WoodGrain: View {
    var body: some View {
        Canvas { context, size in
            var state: UInt64 = 99
            func nextUnit() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 11) / Double(UInt64(1) << 53)
            }
            var y = 0.0
            while y < size.height {
                let thickness = 0.6 + nextUnit() * 2.2
                let opacity = 0.03 + nextUnit() * 0.06
                var path = Path()
                path.move(to: CGPoint(x: -20, y: y))
                var x = -20.0
                var cursor = y
                while x < size.width + 20 {
                    x += 60
                    cursor += (nextUnit() - 0.5) * 6
                    path.addLine(to: CGPoint(x: x, y: cursor))
                }
                context.stroke(path, with: .color(.black.opacity(opacity)),
                               lineWidth: thickness)
                y += 6 + nextUnit() * 16
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

/// One open page of the sudoku book, with the rest of the block showing as a
/// stack of edges to the right and below, and the chapter tabs on the fore-edge.
struct BookPageView<Content: View>: View {
    @ViewBuilder var content: Content

    private let stackDepth: CGFloat = 10
    private let corner: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Cover board, just visible past the spine and the foot.
            RoundedRectangle(cornerRadius: corner + 3)
                .fill(Paper.coverBoard)
                .offset(x: -6, y: 6)

            // The block of pages underneath this one.
            ForEach(0..<4, id: \.self) { i in
                let inset = CGFloat(4 - i) * (stackDepth / 4)
                RoundedRectangle(cornerRadius: corner)
                    .fill(i.isMultiple(of: 2) ? Paper.pageStack : Paper.pageEdge)
                    .offset(x: inset, y: inset * 0.6)
            }

            // The page itself.
            RoundedRectangle(cornerRadius: corner)
                .fill(Paper.page)
                .overlay { PaperGrain() }
                .overlay {
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(Paper.pageEdge, lineWidth: 0.5)
                }
                .pageShading()
                .overlay(alignment: .topLeading) { content.padding(16) }
                .clipShape(RoundedRectangle(cornerRadius: corner))
        }
        .shadow(color: .black.opacity(0.5), radius: 24, x: 6, y: 14)
    }
}

/// The next sheet of the block, sitting flat under the one being turned. Without
/// it the flip reveals bare desk, which no book has ever done.
struct PageBacking: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Paper.pageWarm)
            .overlay { PaperGrain(opacity: 0.05) }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Paper.pageEdge, lineWidth: 0.5)
            }
            .pageShading()
            .allowsHitTesting(false)
    }
}
