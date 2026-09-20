import SwiftUI
import ProbablySudokuEngine

/// The catalogue is a single sheet. It divides the viewport left by the shared
/// inventory into three rows, including a second Buff in historical Shops.
struct ShopPageView: View {
    @Bindable var model: GameModel
    var shop: ShopState
    var onClaimMarker: (Int) -> Void
    var onOfferPresentationChange: (Bool) -> Void = { _ in }
    var isPresentationCovered = false
    var canStartPresentation: @MainActor () -> Bool = { true }
    #if DEBUG
    /// Hosted lifecycle tests invoke the exact production Button action.
    var onContinueReady: ((@escaping @MainActor () -> Void) -> Void)? = nil
    #endif
    @State private var markerPurchase = PendingMarkerPurchase()
    @State private var inspectedOffer: ShopOffer?
    @State private var continueTask: Task<Void, Never>?
    @State private var continueRequestID: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        GeometryReader { proxy in
            let layout = ShopPageLayout(available: proxy.size, textScale: textScale,
                                        hasReservation: model.run.buffState.reservationIntent != nil)
            VStack(spacing: layout.spacing) {
                header(layout: layout)
                if shop.offers.count > 5 {
                    expandedStock(layout: layout, height: max(60, (proxy.size.height - layout.headerHeight - layout.footerHeight - 6 * layout.spacing - layout.bottomPadding) / 3))
                } else {
                    offerSection(title: "Bookmarks", kind: .bookmark, layout: layout)
                    offerSection(title: "Markers", kind: .marker, layout: layout)
                    offerSection(title: "Buffs", kind: .buff, layout: layout)
                }
                Spacer(minLength: 0)
                continueButton(layout: layout)
                    .inventorySaleActionArea()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, layout.bottomPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .paperPanel(item: $inspectedOffer, onDismiss: {
            onOfferPresentationChange(false)
            // The custom panel and its dimmer have finished closing. Now lay
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
            if offerID != nil { onOfferPresentationChange(true) }
        }
        .task(id: "\(model.puzzlePreparationRevision)-\(scenePhase == .active)") {
            guard scenePhase == .active else { model.cancelShopExitPreparation(); return }
            _ = await model.prepareShopExit()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelContinue(); model.cancelShopExitPreparation() }
        }
        .onChange(of: isPresentationCovered) { _, covered in
            if covered { cancelContinue() }
        }
        #if DEBUG
        .onAppear { onContinueReady?(requestContinue) }
        #endif
        .onDisappear {
            // The first printed frame commits the next briefing. Its curl
            // outlives this outgoing Shop; other departures cancel the wait.
            if model.page != .briefing || !flipper.isFlipping { cancelContinue() }
            model.cancelShopExitPreparation()
            onOfferPresentationChange(false)
        }
    }

    private func hasSlot(for kind: ItemKind) -> Bool {
        switch kind {
        case .bookmark: return model.run.bookmarks.count < kind.capacity
        case .marker: return true
        case .buff: return model.run.buffs.count < model.buffCapacity
        case .subscription: return true
        }
    }

    @ViewBuilder private func offerSection(title: String, kind: ItemKind, layout: ShopPageLayout) -> some View {
        let offers = shop.offers.filter { $0.def.kind == kind }
        if !offers.isEmpty {
            VStack(alignment: .leading, spacing: layout.labelSpacing) {
                sectionRule(title, layout: layout)
                HStack(spacing: layout.spacing) {
                    ForEach(offers) { offer in
                        OfferCard(offer: quoted(offer),
                                  affordable: model.coins >= quoted(offer).price,
                                  hasSlot: hasSlot(for: kind),
                                  layout: offers.count == 1 ? .wide : .column,
                                  fittedHeight: layout.cardHeight,
                                  textScale: layout.cardTextScale) {
                            inspectedOffer = offer
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: layout.cardHeight)
            }
        }
    }

    private func quoted(_ offer: ShopOffer) -> ShopOffer {
        ShopOffer(slot: offer.slot, defID: offer.defID,
                  price: Shop.purchasePrice(model.run, slot: offer.slot) ?? offer.price, sold: offer.sold)
    }

    private func expandedStock(layout: ShopPageLayout, height: CGFloat) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: layout.spacing) {
            ForEach(shop.offers) { offer in
                OfferCard(offer: quoted(offer), affordable: model.coins >= quoted(offer).price,
                          hasSlot: hasSlot(for: offer.def.kind), layout: .column,
                          fittedHeight: height, textScale: layout.cardTextScale) { inspectedOffer = offer }
                    .frame(height: height)
            }
        }
    }

    private func header(layout: ShopPageLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Shop")
                    .font(.system(size: layout.compact ? 32 : 36, weight: .bold, design: .serif))
                    .foregroundStyle(theme.paper.ink)
                Spacer(minLength: 8)
                rerollButton(layout: layout)
            }
            .frame(height: 44)
            if layout.hasReservation {
                Button { model.cancelReservation() } label: {
                    Label("Cancel reservation", systemImage: "xmark")
                        .font(Print.caption(12 * layout.actionTextScale))
                        .foregroundStyle(Paper.redPencil)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shop.cancel-reservation")
            }
        }
        .frame(height: layout.headerHeight)
    }

    private func sectionRule(_ title: String, layout: ShopPageLayout) -> some View {
        HStack(spacing: 9) {
            Text(title)
                .font(Print.caption(10 * layout.cardTextScale))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.paper.softInk)
            Rectangle()
                .fill(theme.paper.ruleInk.opacity(0.72))
                .frame(height: 1)
        }
        .frame(height: layout.labelHeight)
        .accessibilityAddTraits(.isHeader)
    }

    private func rerollButton(layout: ShopPageLayout) -> some View {
        Button { model.reroll() } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Reroll")
                Circle()
                    .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim], startPoint: .top, endPoint: .bottom))
                    .frame(width: 15, height: 15)
                Text(Shop.rerollPrice(model.run) == 0 ? "Free" : "\(Shop.rerollPrice(model.run))")
                    .monospacedDigit()
            }
            .font(Print.subheading(15 * layout.actionTextScale))
            .foregroundStyle(bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background { RoundedRectangle(cornerRadius: 4).fill(theme.paper.warm) }
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(bookTheme.accent.opacity(0.7), lineWidth: 1) }
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(model.coins < Shop.rerollPrice(model.run))
        .opacity(model.coins < Shop.rerollPrice(model.run) ? 0.45 : 1)
        .accessibilityLabel(Shop.rerollPrice(model.run) == 0 ? "Reroll the shop for free"
                                                   : "Reroll the shop for \(Shop.rerollPrice(model.run)) \(Shop.rerollPrice(model.run) == 1 ? "coin" : "coins")")
        .accessibilityIdentifier("shop.reroll")
    }

    private func continueButton(layout: ShopPageLayout) -> some View {
        Button(action: requestContinue) {
            HStack(spacing: 8) {
                Text(continueRequestID == nil ? "Continue" : "Preparing…")
                Image(systemName: "arrow.right")
            }
            .font(Print.subheading(18 * layout.actionTextScale))
            .foregroundStyle(bookTheme.buttonForeground)
            .frame(maxWidth: .infinity)
            .frame(height: layout.footerHeight)
            .background(bookTheme.buttonFill, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(continueRequestID != nil)
        .accessibilityLabel("Continue to next puzzle")
        .accessibilityIdentifier("shop.continue")
    }

    private func requestContinue() {
        guard continueRequestID == nil, scenePhase == .active, !flipper.isFlipping,
              !isPresentationCovered, canStartPresentation() else { return }
        let requestID = UUID()
        continueRequestID = requestID
        continueTask = Task { @MainActor in
            defer {
                if continueRequestID == requestID { continueRequestID = nil; continueTask = nil }
            }
            guard let ready = await model.prepareShopExit(), !Task.isCancelled,
                  continueRequestID == requestID, scenePhase == .active,
                  !isPresentationCovered, canStartPresentation() else { return }
            await flipper.flip(from: model, reduceMotion: reduceMotion) {
                guard continueRequestID == requestID, scenePhase == .active,
                      !isPresentationCovered, canStartPresentation() else { return }
                model.leavePreparedShop(ready)
            }
        }
    }

    private func cancelContinue() {
        continueRequestID = nil
        continueTask?.cancel()
        continueTask = nil
    }
}

/// Give every offer a real share of the screen before choosing its typography.
/// Large accessibility copy remains available in the custom detail panel and
/// in each offer's complete spoken label; the overview never clips off a row.
struct ShopPageLayout {
    var available: CGSize
    var textScale: CGFloat = 1
    var hasReservation = false
    var compact: Bool { available.height < 610 }
    var spacing: CGFloat { compact ? 6 : 10 }
    var labelSpacing: CGFloat { 4 }
    var labelHeight: CGFloat { 16 }
    var headerHeight: CGFloat { hasReservation ? 88 : 44 }
    var footerHeight: CGFloat { textScale > 1.3 ? 60 : 52 }
    var bottomPadding: CGFloat { 6 }
    var actionTextScale: CGFloat { min(textScale, 1.25) }
    var cardTextScale: CGFloat { min(textScale, compact ? 1.08 : 1.2) }
    var cardHeight: CGFloat {
        let fixed = headerHeight + footerHeight + bottomPadding + spacing * 5
            + (labelHeight + labelSpacing) * 3
        return max(44, min(220, (available.height - fixed) / 3))
    }
}

/// A purchase has committed, but its detail panel still owns the screen.
/// Keep the placement request until that panel's actual dismissal callback.
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
    var fittedHeight: CGFloat? = nil
    var textScale: CGFloat = 1
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
        if let fittedHeight {
            fittedContent(height: fittedHeight)
        } else {
            switch layout {
            case .column: columnContent
            case .wide: wideContent
            }
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

    private func fittedContent(height: CGFloat) -> some View {
        let generous = height >= 150
        return VStack(alignment: .leading, spacing: generous ? 8 : 2) {
            HStack(alignment: .center, spacing: 6) {
                illustration(size: generous ? 30 : 24)
                Text(def.name)
                    .font(Print.subheading((generous ? 16 : 14) * textScale))
                    .foregroundStyle(theme.paper.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(ShopOfferSummary.text(for: def))
                .font(Print.body((generous ? 14 : 12) * textScale))
                .foregroundStyle(theme.paper.softInk)
                .lineLimit(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 12, height: 12)
                    Text("\(offer.price)")
                        .font(Print.numeral(14 * textScale, weight: .bold))
                        .foregroundStyle(theme.paper.ink)
                }
                Spacer(minLength: 0)
                Text(offer.sold ? "Sold" : (!hasSlot ? "Slots full · Details" : (!affordable ? "Need coins · Details" : "Details ↗")))
                    .font(Print.caption(10))
                    .foregroundStyle(affordable && hasSlot && !offer.sold
                                     ? bookTheme.quietInk(onDarkPaper: theme.paper.isDark)
                                     : palette.resolved(for: theme.paper).danger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(generous ? 10 : 6)
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .topLeading)
    }

    private var columnContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                illustration(size: 30)
                Text(def.name)
                    .font(Print.subheading(15))
                    .foregroundStyle(theme.paper.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom) {
                RarityImprint(rarity: def.rarity)
                Spacer(minLength: 4)
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
        ItemArtwork(id: def.id, size: size)
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
            Text(compact ? compactAvailability : availability)
                .font(Print.caption(10))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(affordable && hasSlot && !offer.sold
                                 ? bookTheme.quietInk(onDarkPaper: theme.paper.isDark)
                                 : palette.resolved(for: theme.paper).danger)
        }
        .frame(width: compact ? 66 : 100, alignment: .trailing)
    }

    private var compactAvailability: String {
        if offer.sold { return "Sold" }
        if !hasSlot { return "Slots full" }
        if !affordable { return "Need coins" }
        return "Affordable"
    }

    private var accentColor: Color? {
        def.kind == .marker ? Paper.markerColor(def.id) : nil
    }

}

/// Catalogue summaries keep the decision readable at a glance. The complete
/// rule, including rarity and exceptions, stays in the same custom purchase
/// panel and in the offer's VoiceOver label.
enum ShopOfferSummary {
    static func text(for def: ItemDef) -> String {
        compact[def.id] ?? CatalogueDetails.item(def.id)?.shortEffect ?? def.text
    }

    /// Only the catalogue's longer summaries need editorial shortening for
    /// the small offer tickets. Purchase details retain the full source rule.
    private static let compact: [String: String] = [
        "bm_crossword_daily": "Draw 1 Pool card per clear, even Clues and Keep Filling.",
        "bm_overflow_column": "Eligible: +25 per card over refill size; max +100.",
        "bm_type_case": "Hold a digit: first 3 eligible others gain +50 Points.",
        "bm_correction_ledger": "3 eligible fills refund half first paid penalty; max 150.",
        "bm_personal_column": "Pick a digit: first 2 eligible fills draw its Pool copy.",
        "bm_archive_room": "Win: +50/unused Clue next Puzzle’s first fill; max +150.",
        "mk_patina": "Past eligible Puzzle fills here: +25 each, max +200.",
        "mk_harvest": "Exchange up to 3 remaining copies for other Pool digits.",
        "bf_peek": "+1 Clue. Zero Points; only Onyx restores placement Points.",
        "bf_insurance": "Cancel the next wrong-placement score penalty.",
        "bf_redraw": "Redraw the whole Hand from the Pool; no Toss spent.",
        "bf_litmus": "Reveal a digit’s matching blanks until your next placement.",
        "bf_careful_cut": "Return 1–3 cards. No Toss spent; no immediate refill.",
        "bf_eraser_shavings": "Restore up to 2 spent Tosses, within the starting allowance.",
        "bf_collation": "Reorder up to 3 future Pool draws; draw nothing now.",
        "bf_proof_sheet": "Show visible-rule candidates in one unit for this Turn.",
        "bf_rebind": "Move an untriggered blank Marker claim to an unmarked blank.",
        "bf_transposition": "Swap untriggered blank claims of two different Marker types.",
        "bf_supplement": "Add an extra paid offer of your chosen kind next Shop.",
        "bf_detour": "Choose one of two equal-difficulty non-boss layouts.",
        "bf_boss_draft": "Choose the announced boss or a revealed alternative.",
        "bf_collateral": "Suspend 1 Bookmark this Puzzle: +2 Hand on future refills.",
        "bf_return_receipt": "Recover an unused Insurance, Double Down or Second Print.",
        "bf_clean_finish": "Cleanly place your whole Hand (3+ cards) this Turn: +150.",
        "bf_cross_cut": "Eligible double/triple clear: +120/+180 Points, once.",
        "bf_open_bracket": "Fill 2 chosen blanks in different boxes: +200 if eligible.",
        "bf_new_edition": "Shop: swap a Bookmark for a random one of the same rarity.",
        "bf_carbon_receipt": "Repeat your last eligible basic Buff effect; no new item.",
        "bf_rain_check": "Defer 20–100 placement Points; eligible fill next Turn: ×2."
    ]
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
    @Environment(\.paperPanelDismiss) private var dismiss
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.levelPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    @Bindable var model: GameModel
    let offer: ShopOffer
    let markerBought: (Int) -> Void
    @State private var purchaseSubmitted = false

    private var currentOffer: ShopOffer {
        let current = model.run.shop?.offers.first(where: { $0.slot == offer.slot }) ?? offer
        return ShopOffer(slot: current.slot, defID: current.defID,
                         price: Shop.purchasePrice(model.run, slot: current.slot) ?? current.price, sold: current.sold)
    }

    private var hasSlot: Bool {
        switch currentOffer.def.kind {
        case .bookmark: return model.run.bookmarks.count < ItemKind.bookmark.capacity
        case .marker: return true
        case .buff: return model.run.buffs.count < model.buffCapacity
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

    var body: some View { offerPaper }

    private var offerPaper: some View {
        PaperSlip(title: currentOffer.def.name, subtitle: nil,
                  dismissesOnBackground: false,
                  closeAccessibilityID: "shop.offer.close",
                  maximumWidth: 440, fitsContent: true,
                  onClose: { dismiss() }) {
            offerContent
        }
    }

    private var offerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ItemArtwork(id: currentOffer.defID, size: 56)
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
