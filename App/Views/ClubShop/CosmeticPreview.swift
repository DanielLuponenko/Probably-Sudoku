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
        .environment(\.cosmeticTheme, previewTheme)
        .overlay {
            RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.rule, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch item.category {
        case .paper:
            let skin = previewTheme.paper
            Rectangle().fill(skin.page)
                .overlay { PaperGrain(opacity: skin.grain, seed: 5) }
                .overlay { PaperStockOverlay(treatment: skin.treatment) }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(skin.edge).frame(height: side * 0.12)
                }

        case .board:
            let inset = side * 0.10
            let gridSide = side - inset * 2
            CosmeticGridRules(skin: previewTheme.board, side: gridSide, cell: gridSide / 9)

        case .numbers:
            ZStack {
                let gridSide = side * 0.82
                CosmeticGridRules(skin: previewTheme.board, side: gridSide, cell: gridSide / 9)
                    .opacity(0.48)
                HStack(spacing: side * 0.08) {
                    ForEach([2, 7, 9], id: \.self) { digit in
                        CosmeticNumberGlyph(text: "\(digit)", skin: previewTheme.numbers,
                                            size: side * 0.28, weight: .semibold,
                                            color: previewTheme.numbers.ink)
                    }
                }
            }
        }
    }

    private var previewTheme: CosmeticTheme {
        var loadout = EquippedCosmetics.starting
        loadout[item.category] = item.id
        return CosmeticCatalog.theme(for: loadout)
    }
}
