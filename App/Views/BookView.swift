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
    var tabIndex: Int
    var tabLabels: [String]
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
                .overlay(alignment: .topLeading) { content.padding(22) }
                .clipShape(RoundedRectangle(cornerRadius: corner))
        }
        .shadow(color: .black.opacity(0.5), radius: 24, x: 6, y: 14)
        .overlay(alignment: .topTrailing) {
            ChapterTabs(active: tabIndex, labels: tabLabels)
                .offset(x: 26, y: 90)
        }
    }
}

/// The five chapter tabs down the fore-edge. The active one reaches further
/// out, the way a thumbed tab does.
struct ChapterTabs: View {
    var active: Int
    var labels: [String]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let isActive = index == active
                Text(label)
                    .font(Print.caption(13))
                    .foregroundStyle(Paper.ink.opacity(isActive ? 0.85 : 0.55))
                    .frame(width: 44, height: 46, alignment: .leading)
                    .padding(.leading, 8)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 6, topTrailingRadius: 6
                        )
                        .fill(Paper.tabs[index % Paper.tabs.count])
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 2, y: 2)
                    }
                    .offset(x: isActive ? 0 : -10)
            }
        }
        .animation(.snappy(duration: 0.25), value: active)
    }
}
