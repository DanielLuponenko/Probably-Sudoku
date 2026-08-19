import SwiftUI
import NumberClubEngine

/// The desk the book lies on.
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
                context.stroke(path, with: .color(.black.opacity(opacity)), lineWidth: thickness)
                y += 6 + nextUnit() * 16
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

// MARK: - The book

/// What actually makes something read as a book rather than a card is its
/// thickness: a block of page edges you can count, boards that stand a little
/// proud of the paper, and a binding the page disappears into. All three are
/// here, and the live page sits on top of them.
enum Volume {
    /// How far the page is inset from the book's own rect on each side.
    static let spine: CGFloat = 15        // paper vanishing into the binding
    static let foreEdge: CGFloat = 16     // block of page edges, plus the board
    static let head: CGFloat = 5
    static let tail: CGFloat = 13
    static let corner: CGFloat = 5
}

struct BookVolume: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // The boards, standing a little proud of the paper on every side.
            RoundedRectangle(cornerRadius: Volume.corner + 2)
                .fill(
                    LinearGradient(colors: [Paper.coverBoard, Color(hex: 0x1C1917)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            PageBlock()
                .padding(.leading, Volume.spine - 5)
                .padding(.trailing, 5)
                .padding(.top, 3)
                .padding(.bottom, 5)

            Binding()
                .frame(width: Volume.spine + 6)
        }
        .shadow(color: .black.opacity(0.55), radius: 22, x: 8, y: 16)
        .shadow(color: .black.opacity(0.35), radius: 4, x: 2, y: 3)
    }
}

/// Every other sheet in the book, seen edge-on down the fore-edge and along the
/// tail. Drawn rather than exported, so it stays crisp at any size.
private struct PageBlock: View {
    var body: some View {
        Canvas { context, size in
            let body = Path(roundedRect: CGRect(origin: .zero, size: size),
                            cornerRadius: Volume.corner)
            context.fill(body, with: .color(Paper.pageEdge))
            context.clip(to: body)

            var state: UInt64 = 4231
            func jitter() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 11) / Double(UInt64(1) << 53)
            }

            // Fore-edge: leaves stacked towards the reader's right.
            var x = size.width - 1.0
            while x > size.width - Volume.foreEdge {
                let shade = 0.10 + jitter() * 0.30
                var line = Path()
                // A real block is never perfectly flat; the leaves bow a little.
                let bow = (jitter() - 0.5) * 1.6
                line.move(to: CGPoint(x: x, y: 2 + bow))
                line.addLine(to: CGPoint(x: x + bow * 0.4, y: size.height - 2))
                context.stroke(line, with: .color(.black.opacity(shade)), lineWidth: 0.9)
                x -= 1.15 + jitter() * 0.5
            }

            // Tail: the same leaves seen from below.
            var y = size.height - 1.0
            while y > size.height - Volume.tail {
                let shade = 0.09 + jitter() * 0.26
                var line = Path()
                line.move(to: CGPoint(x: 2, y: y))
                line.addLine(to: CGPoint(x: size.width - 2, y: y + (jitter() - 0.5) * 1.2))
                context.stroke(line, with: .color(.black.opacity(shade)), lineWidth: 0.9)
                y -= 1.15 + jitter() * 0.5
            }

            // The block curves away from the light at both edges.
            context.fill(
                Path(CGRect(x: size.width - Volume.foreEdge, y: 0,
                            width: Volume.foreEdge, height: size.height)),
                with: .linearGradient(
                    Gradient(colors: [.clear, .black.opacity(0.28)]),
                    startPoint: CGPoint(x: size.width - Volume.foreEdge, y: 0),
                    endPoint: CGPoint(x: size.width, y: 0))
            )
            context.fill(
                Path(CGRect(x: 0, y: size.height - Volume.tail,
                            width: size.width, height: Volume.tail)),
                with: .linearGradient(
                    Gradient(colors: [.clear, .black.opacity(0.3)]),
                    startPoint: CGPoint(x: 0, y: size.height - Volume.tail),
                    endPoint: CGPoint(x: 0, y: size.height))
            )
        }
        .allowsHitTesting(false)
    }
}

/// The binding: where the paper stops being flat and turns down into the gutter.
private struct Binding: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x14110F), location: 0),
                .init(color: Color(hex: 0x2B2724), location: 0.35),
                .init(color: .black.opacity(0.45), location: 0.7),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .allowsHitTesting(false)
    }
}

/// The sheet currently being worked on. It is a separate view from the volume
/// because this is the part that lifts when the page turns.
struct PageSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Paper.page)
                .overlay { PaperGrain(opacity: 0.07) }
                .overlay { gutter }
                .overlay { bow }

            content.padding(.init(top: 14, leading: 12, bottom: 12, trailing: 14))
        }
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: Volume.corner,
                                   topTrailingRadius: Volume.corner)
        )
        .shadow(color: .black.opacity(0.3), radius: 3, x: 3, y: 1)
    }

    /// Paper turning down into the binding, and the crease it makes.
    private var gutter: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.38), location: 0),
                .init(color: .black.opacity(0.10), location: 0.045),
                .init(color: .clear, location: 0.13),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }

    /// A sheet lying on a block is never flat: it lifts slightly at the
    /// fore-edge and settles at head and tail.
    private var bow: some View {
        LinearGradient(
            colors: [.black.opacity(0.05), .clear, .clear, .black.opacity(0.07)],
            startPoint: .top, endPoint: .bottom
        )
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

/// The book as one object: boards, block, binding, and the live page on top.
struct BookView<Content: View>: View {
    var flipper: PageFlipper
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            BookVolume()

            ZStack {
                // The next sheet, already lying flat, so turning a page reveals
                // paper rather than the edges of the block.
                PageSurface { Color.clear }
                PageSurface { content }
                    .pageFlip(flipper)
            }
            // A lifting page is foreshortened towards the reader; without this
            // it would paint over the desk and the loadout row above the book.
            .clipped()
            .padding(EdgeInsets(top: Volume.head, leading: Volume.spine,
                                bottom: Volume.tail, trailing: Volume.foreEdge))
        }
    }
}
