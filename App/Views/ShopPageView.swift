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
        GeometryReader { proxy in
            // This is a composed page, not a feed. Scale the fixed editorial
            // composition to the available sheet so all five offers and the
            // action are visible together on every phone.
            let designHeight: CGFloat = 860
            let scale = min(1, proxy.size.height / designHeight)

            catalogue
                .frame(width: proxy.size.width / scale, height: designHeight, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .background {
                    Image("BetweenPuzzlesPaper")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.24)
                        .blendMode(.multiply)
                        .padding(-16)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
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

    private var catalogue: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            offerSection(title: "Bookmarks", kind: .bookmark)
            offerSection(title: "Markers", kind: .marker)
            offerSection(title: "Buffs", kind: .buff)
            pageDivider
            PaperButton(title: "Continue", subtitle: "Next Puzzle", kind: .primary) {
                Task {
                    await flipper.flip(from: model, reduceMotion: reduceMotion) { model.continueToNextPuzzle() }
                }
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
            VStack(alignment: .leading, spacing: 10) {
                sectionRule(title)

                if kind == .buff {
                    ForEach(offers) { offer in
                        OfferCard(offer: offer,
                                  affordable: model.coins >= offer.price,
                                  hasSlot: hasSlot(for: kind),
                                  layout: .wide) {
                            inspectedOffer = offer
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                         GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(offers) { offer in
                            OfferCard(offer: offer,
                                      affordable: model.coins >= offer.price,
                                      hasSlot: hasSlot(for: kind),
                                      layout: .column) {
                                inspectedOffer = offer
                            }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shop")
                .pageHeading(62)
                .fixedSize(horizontal: false, vertical: true)

            rerollButton

            Text("Choose an item to take into the next puzzle.")
                .font(Print.body(18))
                .foregroundStyle(Paper.inkSoft)
        }
    }

    private func sectionRule(_ title: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(Print.caption(13))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundStyle(Paper.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Paper.sage.opacity(0.24), in: RoundedRectangle(cornerRadius: 5))
            Rectangle()
                .fill(Paper.rule.opacity(0.72))
                .frame(height: 1)
        }
    }

    /// Rerolling is the Shop's own action, so it lives on the Shop's page.
    private var rerollButton: some View {
        Button { model.reroll() } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                Text("Reroll")
                    .font(Print.subheading(20))
                coinMark
                Text(shop.rerollCost == 0 ? "Free" : "\(shop.rerollCost)")
                    .font(Print.numeral(20, weight: .bold))
            }
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background { RoundedRectangle(cornerRadius: 6).fill(Paper.pageWarm) }
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Paper.rule, lineWidth: 1.2) }
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(model.coins < shop.rerollCost)
        .opacity(model.coins < shop.rerollCost ? 0.45 : 1)
        .accessibilityLabel(shop.rerollCost == 0 ? "Reroll the shop for free"
                                                   : "Reroll the shop for \(shop.rerollCost) \(shop.rerollCost == 1 ? "coin" : "coins")")
    }

    private var coinMark: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Paper.coin, Paper.coinRim], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(Paper.coinRim.opacity(0.85), lineWidth: 1)
            Text("N").font(Print.caption(10)).foregroundStyle(Paper.ink.opacity(0.76))
        }
        .frame(width: 26, height: 26)
    }

    private var pageDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Paper.rule.opacity(0.7)).frame(height: 1)
            Circle().fill(Paper.inkFaint.opacity(0.66)).frame(width: 7, height: 7)
            Rectangle().fill(Paper.rule.opacity(0.7)).frame(height: 1)
        }
        .padding(.vertical, 2)
    }

}

// MARK: - Offer

private struct OfferCard: View {
    enum Layout { case column, wide }

    var offer: ShopOffer
    var affordable: Bool
    var hasSlot: Bool
    var layout: Layout
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
            Group {
                switch layout {
                case .column: columnContent
                case .wide: wideContent
                }
            }
        }
        .ticketTreatment(accent: accentColor, sold: offer.sold)
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel("\(def.name), \(def.rarity.rawValue), \(offer.price) coins, \(def.text), \(availability)")
        .accessibilityHint("Opens item details")
        .accessibilityAddTraits(.isButton)
    }

    private var columnContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                illustration.frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(def.name)
                        .font(Print.subheading(15))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    RarityImprint(rarity: def.rarity)
                }
                priceImprint(compact: true)
            }
            Rectangle().fill(Paper.rule.opacity(0.65)).frame(maxWidth: .infinity).frame(height: 1)
            Text(def.text)
                .font(Print.body(13))
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
    }

    private var wideContent: some View {
        HStack(alignment: .top, spacing: 16) {
            illustration.frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 6) {
                Text(def.name)
                    .font(Print.subheading(22))
                    .foregroundStyle(Paper.ink)
                RarityImprint(rarity: def.rarity)
                Rectangle().fill(Paper.rule.opacity(0.65)).frame(maxWidth: 180).frame(height: 1)
                Text(def.text)
                    .font(Print.body(14))
                    .foregroundStyle(Paper.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            priceImprint(compact: false)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    }

    /// A Marker's illustration is the colour itself — it is a mark, not an object.
    private var illustration: some View {
        Group {
            if def.kind == .marker {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Paper.markerColor(def.id).opacity(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Paper.markerColor(def.id), lineWidth: 2)
                    }
            } else {
                Image(systemName: ItemIcon.symbol(for: def.id))
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Paper.ink)
            }
        }
    }

    private func priceImprint(compact: Bool) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: compact ? 3 : 5) {
                Circle()
                    .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: compact ? 14 : 19, height: compact ? 14 : 19)
                Text("\(offer.price)")
                    .font(Print.numeral(compact ? 15 : 18, weight: .bold))
            }
            .foregroundStyle(Paper.ink)
            Text(availability)
                .font(Print.caption(compact ? 8 : 10))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(affordable && hasSlot && !offer.sold ? Paper.sageDeep : Paper.redPencil)
        }
        .frame(width: compact ? 40 : 64, alignment: .trailing)
    }

    private var accentColor: Color? {
        def.kind == .marker ? Paper.markerColor(def.id) : nil
    }

}

private extension View {
    func ticketTreatment(accent: Color?, sold: Bool) -> some View {
        clipShape(OfferTicketShape())
            // Offers are cut from the same vellum as the page. Their outline,
            // clipped corner, and a small lift separate them; a grey fill makes
            // them read as unrelated UI cards.
            .background(OfferTicketShape().fill(Paper.page.opacity(0.34)))
            .overlay { OfferTicketShape().strokeBorder(Paper.rule.opacity(0.62), lineWidth: 1) }
            .overlay(alignment: .leading) {
                if let accent {
                    Rectangle().fill(accent.opacity(0.88)).frame(width: 4)
                }
            }
            .overlay(alignment: .center) {
                if sold {
                    Text("Sold")
                        .font(Print.heading(22))
                        .textCase(.uppercase)
                        .tracking(3)
                        .foregroundStyle(Paper.redPencil.opacity(0.75))
                        .padding(.horizontal, 10)
                        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.redPencil.opacity(0.6), lineWidth: 2.5) }
                        .rotationEffect(.degrees(-9))
                }
            }
            .opacity(sold ? 0.65 : 1)
            .shadow(color: .black.opacity(0.09), radius: 1.5, y: 1.5)
    }
}

private struct OfferTicketShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let corner = min(16, r.width * 0.12)
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - corner, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + corner))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> OfferTicketShape {
        var shape = self
        shape.insetAmount += amount
        return shape
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
