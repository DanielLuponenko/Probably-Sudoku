import SwiftUI
import ProbablySudokuEngine

/// §9 — the Shop is its own page of the book, reached by turning one. Stock is
/// always two Bookmarks, two Markers and one Buff.
struct ShopPageView: View {
    @Bindable var model: GameModel
    var shop: ShopState
    var onClaimMarker: (Int) -> Void
    var onOfferPresentationChange: (Bool) -> Void = { _ in }
    @State private var markerPurchase = PendingMarkerPurchase()
    @State private var inspectedOffer: ShopOffer?
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.cosmeticTheme) private var theme

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
        .sheet(item: $inspectedOffer, onDismiss: {
            onOfferPresentationChange(false)
            // UIKit has removed the offer sheet and its dimmer. Only now lay
            // the placement slip on the desk, never behind a departing sheet.
            if let index = markerPurchase.takeAfterOfferDismissal() {
                onClaimMarker(index)
            }
        }) { offer in
            OfferSlip(model: model, offer: offer) { markerIndex in
                markerPurchase.record(markerIndex: markerIndex)
            }
        }
        .onChange(of: inspectedOffer?.id) { _, offerID in
            // Stay paused throughout dismissal, until UIKit removes the sheet.
            if offerID != nil { onOfferPresentationChange(true) }
        }
        .onDisappear { onOfferPresentationChange(false) }
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
                .foregroundStyle(theme.paper.softInk)
        }
    }

    private func sectionRule(_ title: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(Print.caption(13))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundStyle(theme.paper.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(bookTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            Rectangle()
                .fill(theme.paper.ruleInk.opacity(0.72))
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
            .foregroundStyle(bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background { RoundedRectangle(cornerRadius: 4).fill(theme.paper.warm) }
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(bookTheme.accent.opacity(0.7), lineWidth: 1) }
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
            Rectangle().fill(theme.paper.ruleInk.opacity(0.7)).frame(height: 1)
            Circle().fill(theme.paper.faintInk.opacity(0.66)).frame(width: 7, height: 7)
            Rectangle().fill(theme.paper.ruleInk.opacity(0.7)).frame(height: 1)
        }
        .padding(.vertical, 2)
    }

}

/// A purchase has committed, but its native detail sheet still owns the screen.
/// Keep the placement request until that sheet's actual dismissal callback.
struct PendingMarkerPurchase {
    private(set) var markerIndex: Int?

    mutating func record(markerIndex: Int) {
        guard self.markerIndex == nil else { return }
        self.markerIndex = markerIndex
    }

    mutating func takeAfterOfferDismissal() -> Int? {
        defer { markerIndex = nil }
        return markerIndex
    }
}

// MARK: - Offer

struct OfferCard: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.levelPalette) private var palette
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

    /// The printed face owns the original card geometry. Its minimum height
    /// can grow with the copy; inspection treatment must not add to it.
    @ViewBuilder var ticketFace: some View {
        switch layout {
        case .column: columnContent
        case .wide: wideContent
        }
    }

    var body: some View {
        Button(action: inspect) {
            ticketFace
            // The whole paper ticket is one inspection target, including
            // description, illustration and unprinted space. Keeping the
            // treatment inside the label prevents its overlays from sitting
            // above a smaller, text-only Button hit region.
            .ticketTreatment(accent: accentColor, sold: offer.sold,
                             paper: theme.paper, danger: palette.resolved(for: theme.paper).danger)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedPaperStyle())
        // Label the native Button itself. Wrapping it in another accessible
        // element exposes two nested offer buttons to assistive technology.
        .accessibilityLabel("\(def.name), \(def.rarity.rawValue), \(offer.price) coins, \(def.text), \(availability)")
        .accessibilityHint("Opens item details")
        .accessibilityIdentifier("shop.offer.\(offer.slot)")
    }

    private var columnContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                illustration(size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(def.name)
                        .font(Print.subheading(15))
                        .foregroundStyle(theme.paper.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    RarityImprint(rarity: def.rarity)
                }
                priceImprint(compact: true)
            }
            Rectangle().fill(theme.paper.ruleInk.opacity(0.65)).frame(maxWidth: .infinity).frame(height: 1)
            OfferDescription(text: def.text, layout: .column)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
    }

    private var wideContent: some View {
        HStack(alignment: .top, spacing: 16) {
            illustration(size: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text(def.name)
                    .font(Print.subheading(22))
                    .foregroundStyle(theme.paper.ink)
                RarityImprint(rarity: def.rarity)
                Rectangle().fill(theme.paper.ruleInk.opacity(0.65)).frame(maxWidth: 180).frame(height: 1)
                OfferDescription(text: def.text, layout: .wide)
            }
            Spacer(minLength: 0)
            priceImprint(compact: false)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    }

    /// A Marker's illustration is the colour itself — it is a mark, not an object.
    private func illustration(size: CGFloat) -> some View {
        PrintedItemIllustration(size: size) {
            if def.kind == .marker {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Paper.markerColor(def.id).opacity(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Paper.markerColor(def.id), lineWidth: 2)
                    }
                    .frame(width: size * 0.55, height: size * 0.55)
            } else {
                Image(systemName: ItemIcon.symbol(for: def.id))
                    .font(.system(size: size * 0.58, weight: .light))
                    .foregroundStyle(bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
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
            .foregroundStyle(theme.paper.ink)
            Text(availability)
                .font(Print.caption(compact ? 8 : 10))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(affordable && hasSlot && !offer.sold
                                 ? bookTheme.quietInk(onDarkPaper: theme.paper.isDark)
                                 : palette.resolved(for: theme.paper).danger)
        }
        .frame(width: compact ? 40 : 64, alignment: .trailing)
    }

    private var accentColor: Color? {
        def.kind == .marker ? Paper.markerColor(def.id) : nil
    }

}

/// Keep the catalogue's composed page height while making abbreviated copy
/// explicit. The card's button always opens the complete item description.
struct OfferDescription: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    let text: String
    let layout: OfferCard.Layout

    var body: some View {
        ViewThatFits(in: .vertical) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .lineLimit(layout == .column ? 2 : 1)
                    .truncationMode(.tail)
                Text("Details")
                    .font(Print.caption(10))
                    .foregroundStyle(bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
                    .underline()
            }
        }
        .font(Print.body(layout == .column ? 13 : 14))
        .foregroundStyle(theme.paper.softInk)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: layout == .column ? 50 : 36, alignment: .topLeading)
    }
}

private extension View {
    func ticketTreatment(accent: Color?, sold: Bool, paper: PaperSkin, danger: Color) -> some View {
        clipShape(OfferTicketShape())
            // Offers are cut from the same vellum as the page. Their outline,
            // clipped corner, and a small lift separate them; a grey fill makes
            // them read as unrelated UI cards.
            .background {
                OfferTicketShape().fill(paper.page.opacity(0.34))
                    .allowsHitTesting(false)
            }
            .overlay {
                OfferTicketShape().strokeBorder(paper.ruleInk.opacity(0.62), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .leading) {
                if let accent {
                    Rectangle().fill(accent.opacity(0.88)).frame(width: 4)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .center) {
                if sold {
                    Text("Sold")
                        .font(Print.heading(22))
                        .textCase(.uppercase)
                        .tracking(3)
                        .foregroundStyle(danger.opacity(0.75))
                        .padding(.horizontal, 10)
                        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(danger.opacity(0.6), lineWidth: 2.5) }
                        .rotationEffect(.degrees(-9))
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
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

struct RarityImprint: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.levelPalette) private var palette
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
        case .common: return theme.paper.faintInk
        case .uncommon: return bookTheme.quietInk(onDarkPaper: theme.paper.isDark)
        case .rare: return palette.resolved(for: theme.paper).danger
        }
    }
}

// MARK: - Purchase and loadout slips

struct OfferSlip: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.levelPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    @Bindable var model: GameModel
    let offer: ShopOffer
    let markerBought: (Int) -> Void
    @State private var purchaseSubmitted = false
    @State private var contentHeight: CGFloat = 360

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
        !purchaseSubmitted && !currentOffer.sold && hasSlot && model.coins >= currentOffer.price
    }

    private var availability: String {
        if currentOffer.sold { return "This item has already been purchased." }
        if !hasSlot { return "There is no open \(currentOffer.def.kind.rawValue) slot." }
        if model.coins < currentOffer.price { return "You need \(currentOffer.price - model.coins) more coins." }
        return "You have \(model.coins) coins on hand."
    }

    var body: some View {
        offerPaper
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                // Measure the complete paper at its natural height. Measuring
                // the visible copy would trap a short offer in the initial
                // detent once its article had selected the scrolling fallback.
                // The visible copy still receives the sheet's capped height,
                // so long copy scrolls while Close remains outside the article.
                offerPaper
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height.rounded(.up)
                    } action: { height in
                        if height > 0 && height != contentHeight { contentHeight = height }
                    }
            }
            .presentationDetents([.height(contentHeight)])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
    }

    private var offerPaper: some View {
        PaperSlip(title: currentOffer.def.name, subtitle: nil,
                  dismissesOnBackground: false, dimsBackground: false,
                  closeAccessibilityID: "shop.offer.close",
                  maximumWidth: 440, fitsContent: true,
                  onClose: { dismiss() }) {
            offerContent
        }
    }

    private var offerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PrintedItemIllustration {
                    if currentOffer.def.kind == .marker {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Paper.markerColor(currentOffer.defID))
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: ItemIcon.symbol(for: currentOffer.defID))
                            .font(.system(size: 23, weight: .light))
                            .foregroundStyle(bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentOffer.def.text)
                        .font(Print.body(15 * textScale))
                        .foregroundStyle(theme.paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    RarityImprint(rarity: currentOffer.def.rarity)
                }
            }
            Rectangle().fill(theme.paper.ruleInk.opacity(0.65)).frame(height: 1)
                .accessibilityHidden(true)
            Label("\(currentOffer.price) coins", systemImage: "circle.inset.filled")
                .font(Print.numeral(16 * textScale, weight: .semibold))
                .foregroundStyle(theme.paper.ink)
            Text(availability)
                .font(Print.body(12 * textScale))
                .foregroundStyle(canBuy
                                 ? bookTheme.quietInk(onDarkPaper: theme.paper.isDark)
                                 : palette.resolved(for: theme.paper).danger)
                .fixedSize(horizontal: false, vertical: true)
            PaperButton(title: "Buy this item", subtitle: "For \(currentOffer.price) coins",
                        kind: .primary, isEnabled: canBuy) {
                guard canBuy else { return }
                purchaseSubmitted = true
                let before = model.run.markers.count
                model.buy(slot: currentOffer.slot)
                guard model.run.shop?.offers.first(where: { $0.slot == currentOffer.slot })?.sold == true else {
                    purchaseSubmitted = false
                    return
                }
                if model.run.markers.count > before {
                    markerBought(model.run.markers.count - 1)
                }
                dismiss()
            }
            .accessibilityIdentifier("shop.offer.buy")
        }
    }
}
