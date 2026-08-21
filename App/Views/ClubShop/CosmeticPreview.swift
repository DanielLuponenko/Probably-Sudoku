import SwiftUI

/// What a skin looks like, shown as the thing it changes rather than as a
/// swatch. A colour chip tells you nothing about a grid; a corner of a grid
/// ruled in that skin tells you everything.
struct CosmeticPreview: View {
    var item: CosmeticItem
    var side: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Paper.pageWarm)
            content
        }
        .frame(width: side, height: side)
        .overlay {
            RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.rule, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch item.category {
        case .desk:
            let skin = CosmeticCatalog.desk(item.id)
            Rectangle().fill(skin.surface)
                .overlay {
                    // The corner of a Book, so the wood is seen with paper on it.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Paper.page)
                        .frame(width: side * 0.42, height: side * 0.54)
                        .rotationEffect(.degrees(-6))
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                }

        case .paper:
            let skin = CosmeticCatalog.paper(item.id)
            Rectangle().fill(skin.page)
                .overlay { PaperGrain(opacity: skin.grain, seed: 5) }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(skin.edge).frame(height: side * 0.12)
                }

        case .board:
            let skin = CosmeticCatalog.board(item.id)
            Canvas { context, size in
                let cell = size.width / 3
                for step in 1..<3 {
                    let offset = cell * CGFloat(step)
                    var vertical = Path()
                    vertical.move(to: .init(x: offset, y: 0))
                    vertical.addLine(to: .init(x: offset, y: size.height))
                    var horizontal = Path()
                    horizontal.move(to: .init(x: 0, y: offset))
                    horizontal.addLine(to: .init(x: size.width, y: offset))
                    context.stroke(vertical, with: .color(skin.hair), lineWidth: skin.hairWidth)
                    context.stroke(horizontal, with: .color(skin.hair), lineWidth: skin.hairWidth)
                }
                context.stroke(Path(CGRect(origin: .zero, size: size)),
                               with: .color(skin.bold), lineWidth: skin.boldWidth)
            }
            .padding(side * 0.10)

        case .numbers:
            let skin = CosmeticCatalog.numbers(item.id)
            HStack(spacing: side * 0.06) {
                ForEach([4, 7], id: \.self) { digit in
                    Text("\(digit)")
                        .font(skin.font(side * 0.42, weight: .semibold))
                        .foregroundStyle(skin.ink)
                }
            }

        case .marker:
            let skin = CosmeticCatalog.marker(item.id)
            ZStack {
                Capsule()
                    .fill(skin.tint)
                    .frame(width: side * 0.16, height: side * 0.66)
                    .rotationEffect(.degrees(24))
                Text("7")
                    .font(Print.handwritten(side * 0.34))
                    .foregroundStyle(skin.tint)
                    .offset(x: side * 0.22, y: side * 0.16)
            }
        }
    }
}
