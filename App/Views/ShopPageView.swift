import SwiftUI
import ProbablySudokuEngine

/// §9 — the Shop is its own page of the book, reached by turning one. Stock is
/// always two Bookmarks, two Markers and one Buff.
struct ShopPageView: View {
    @Bindable var model: GameModel
    var shop: ShopState
    @State private var claimingMarker: Int?
    @State private var inspectedOffer: ShopOffer?
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    offerSection(title: "Bookmarks", kind: .bookmark)
                    offerSection(title: "Markers", kind: .marker)
                    offerSection(title: "Buffs", kind: .buff)
                }
                .padding(.bottom, 4)
            }

            PaperButton(title: "Continue", subtitle: "Next Puzzle", kind: .primary) {
                Task {
                    await flipper.flip(from: model, reduceMotion: reduceMotion) { model.continueToNextPuzzle() }
                }
            }
        }
        .overlay {
            if let index = claimingMarker {
                MarkerPlacementSlip(model: model, markerIndex: index) {
                    setClaimingMarker(nil)
                }
            }
        }
        .sheet(item: $inspectedOffer) { offer in
            OfferSlip(model: model, offer: offer) { markerIndex in
                setClaimingMarker(markerIndex)
            }
        }
    }

    private func setClaimingMarker(_ markerIndex: Int?) {
        if reduceMotion {
            claimingMarker = markerIndex
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                claimingMarker = markerIndex
            }
        }
    }

    private func hasSlot(for kind: ItemKind) -> Bool {
        switch kind {
        case .bookmark: return model.run.bookmarks.count < kind.capacity
        case .marker: return true
        case .buff: return model.run.buffs.count < kind.capacity
        case .subscription: return true
        }
    }

    @ViewBuilder private func offerSection(title: String, kind: ItemKind) -> some View {
        let offers = shop.offers.filter { $0.def.kind == kind }
        if !offers.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(Print.caption(11))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.inkSoft)
                ForEach(offers) { offer in
                    OfferCard(offer: offer,
                              affordable: model.coins >= offer.price,
                              hasSlot: hasSlot(for: kind)) {
                        inspectedOffer = offer
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 4).fill(Paper.pageWarm.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.rule.opacity(0.75), lineWidth: 1))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Between Puzzles").pageHeading(30)
                    Spacer(minLength: 6)
                    coinCount
                    rerollButton
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Between Puzzles").pageHeading(30)
                        Spacer()
                        coinCount
                    }
                    rerollButton
                }
            }
            Text("Choose an item to take into the next puzzle.")
                .font(Print.body(13))
                .foregroundStyle(Paper.inkSoft)
            Rectangle().fill(Paper.rule).frame(height: 1)
        }
    }

    private var coinCount: some View {
        Label("\(model.coins)", systemImage: "circle.inset.filled")
            .font(Print.numeral(15, weight: .bold))
            .foregroundStyle(Paper.coinRim)
            .accessibilityLabel("\(model.coins) coins on hand")
    }

    /// Rerolling is the Shop's own action, so it lives on the Shop's page.
    private var rerollButton: some View {
        Button { model.reroll() } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                Text(shop.rerollCost == 0 ? "Free reroll" : "Reroll \(shop.rerollCost)")
                    .font(Print.numeral(13, weight: .bold))
            }
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background { RoundedRectangle(cornerRadius: 4).fill(Paper.pageWarm) }
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.rule, lineWidth: 1) }
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(model.coins < shop.rerollCost)
        .opacity(model.coins < shop.rerollCost ? 0.45 : 1)
        .accessibilityLabel(shop.rerollCost == 0 ? "Reroll the shop for free"
                                                   : "Reroll the shop for \(shop.rerollCost) \(shop.rerollCost == 1 ? "coin" : "coins")")
    }

}

// MARK: - Offer

private struct OfferCard: View {
    var offer: ShopOffer
    var affordable: Bool
    var hasSlot: Bool
    var inspect: () -> Void

    private var def: ItemDef { offer.def }
    private var availability: String {
        if offer.sold { return "sold" }
        if !affordable { return "too expensive" }
        if !hasSlot { return "no free \(def.kind.rawValue) slot" }
        return "affordable"
    }

    var body: some View {
        Button(action: inspect) {
            HStack(alignment: .top, spacing: 12) {
                illustration

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(def.name)
                            .font(Print.subheading(15))
                            .foregroundStyle(Paper.ink)
                        RarityImprint(rarity: def.rarity)
                    }
                    Text(def.text)
                        .font(Print.body(12))
                        .foregroundStyle(Paper.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                priceImprint
            }
            .padding(11)
            .background { Rectangle().fill(Paper.pageWarm.opacity(0.72)) }
            .overlay { Rectangle().strokeBorder(Paper.rule, lineWidth: def.rarity == .rare ? 1.8 : 1) }
            .overlay(alignment: .topTrailing) {
                FoldedCorner().fill(Paper.page).frame(width: 16, height: 16)
            }
            .overlay(alignment: .center) { if offer.sold { soldStamp } }
            .opacity(offer.sold ? 0.65 : 1)
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel("\(def.name), \(def.rarity.rawValue), \(offer.price) coins, \(def.text), \(availability)")
        .accessibilityHint("Opens item details")
        .accessibilityAddTraits(.isButton)
    }

    /// A Marker's illustration is the colour itself — it is a mark, not an object.
    private var illustration: some View {
        Group {
            if def.kind == .marker {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Paper.markerColor(def.id).opacity(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Paper.markerColor(def.id), lineWidth: 1.6)
                    }
            } else {
                Image(systemName: ItemIcon.symbol(for: def.id))
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Paper.ink)
            }
        }
        .frame(width: 42, height: 42)
    }

    private var priceImprint: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Circle()
                    .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 16, height: 16)
                Text("\(offer.price)")
                    .font(Print.numeral(15, weight: .bold))
            }
            .foregroundStyle(Paper.ink)
            Text(availability)
                .font(Print.caption(9))
                .foregroundStyle(affordable && hasSlot && !offer.sold ? Paper.sageDeep : Paper.redPencil)
        }
        .frame(minWidth: 48)
    }

    private var soldStamp: some View {
        Text("Sold")
            .font(Print.heading(22))
            .textCase(.uppercase)
            .tracking(3)
            .foregroundStyle(Paper.redPencil.opacity(0.75))
            .padding(.horizontal, 10)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Paper.redPencil.opacity(0.6), lineWidth: 2.5)
            }
            .rotationEffect(.degrees(-9))
    }
}

private struct RarityImprint: View {
    var rarity: Rarity

    var body: some View {
        Text(rarity.rawValue)
            .font(Print.caption(rarity == .common ? 8 : 9))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .fontWeight(rarity == .rare ? .bold : .regular)
            .overlay(alignment: .bottom) { Rectangle().fill(color).frame(height: rarity == .rare ? 2 : 1) }
    }

    private var color: Color {
        switch rarity {
        case .common: return Paper.inkFaint
        case .uncommon: return Paper.sageDeep
        case .rare: return Paper.redPencil
        }
    }
}

private struct FoldedCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Purchase and loadout slips

private struct OfferSlip: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: GameModel
    let offer: ShopOffer
    let markerBought: (Int) -> Void

    private var currentOffer: ShopOffer {
        model.run.shop?.offers.first(where: { $0.slot == offer.slot }) ?? offer
    }

    private var hasSlot: Bool {
        switch currentOffer.def.kind {
        case .bookmark: return model.run.bookmarks.count < ItemKind.bookmark.capacity
        case .marker: return true
        case .buff: return model.run.buffs.count < ItemKind.buff.capacity
        case .subscription: return true
        }
    }

    private var canBuy: Bool {
        !currentOffer.sold && hasSlot && model.coins >= currentOffer.price
    }

    private var availability: String {
        if currentOffer.sold { return "This item has already been purchased." }
        if !hasSlot { return "There is no open \(currentOffer.def.kind.rawValue) slot." }
        if model.coins < currentOffer.price { return "You need \(currentOffer.price - model.coins) more coins." }
        return "You have \(model.coins) coins on hand."
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: ItemIcon.symbol(for: currentOffer.defID))
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Paper.ink)
                        .frame(width: 52, height: 52)
                        .overlay { Rectangle().strokeBorder(Paper.rule, lineWidth: 1) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentOffer.def.name).pageHeading(24)
                        RarityImprint(rarity: currentOffer.def.rarity)
                    }
                }
                Text(currentOffer.def.text)
                    .font(Print.body(16))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Paper.rule).frame(height: 1)
                Label("\(currentOffer.price) coins", systemImage: "circle.inset.filled")
                    .font(Print.numeral(18, weight: .bold))
                    .foregroundStyle(Paper.coinRim)
                Text(availability)
                    .font(Print.body(13))
                    .foregroundStyle(canBuy ? Paper.sageDeep : Paper.redPencil)
                Spacer(minLength: 0)
                PaperButton(title: "Buy this item", subtitle: "For \(currentOffer.price) coins",
                            kind: .primary, isEnabled: canBuy) {
                    let before = model.run.markers.count
                    model.buy(slot: currentOffer.slot)
                    guard model.run.shop?.offers.first(where: { $0.slot == currentOffer.slot })?.sold == true else {
                        return
                    }
                    if model.run.markers.count > before {
                        markerBought(model.run.markers.count - 1)
                    }
                    dismiss()
                }
            }
            .padding(22)
            .background(Paper.page)
            .navigationTitle("Item details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
