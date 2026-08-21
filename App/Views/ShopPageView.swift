import SwiftUI
import NumberClubEngine

/// §9 — the Shop is its own page of the book, reached by turning one. Stock is
/// always two Bookmarks, two Markers and one Buff.
struct ShopPageView: View {
    @Bindable var model: GameModel
    var shop: ShopState
    @State private var claimingMarker: Int?
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(standardOffers) { offer in
                        OfferCard(offer: offer,
                                  affordable: model.coins >= offer.price,
                                  hasSlot: hasSlot(for: offer.def.kind)) {
                            buy(offer)
                        }
                    }
                    if !subscriptionOffers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SUBSCRIPTIONS")
                                .font(Print.caption(11)).tracking(1.4)
                                .foregroundStyle(Paper.redPencil)
                            ForEach(subscriptionOffers) { offer in
                                OfferCard(offer: offer,
                                          affordable: model.coins >= offer.price,
                                          hasSlot: true) { buy(offer) }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Paper.pageWarm))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.redPencil.opacity(0.55), lineWidth: 1))
                    }
                }
                .padding(.bottom, 4)
            }

            if model.run.pendingMarkerSquares() > 0 {
                pendingSquaresNotice
            }

            ownedSummary
            PaperButton(title: "Continue", subtitle: "Next Puzzle", kind: .primary) {
                Task {
                    await flipper.flip(from: model, reduceMotion: reduceMotion) { model.continueToNextPuzzle() }
                }
            }
        }
        .overlay {
            if let index = claimingMarker {
                MarkerPlacementSlip(model: model, markerIndex: index) {
                    withAnimation(.snappy(duration: 0.2)) { claimingMarker = nil }
                }
            }
        }
        .animation(.snappy(duration: 0.22), value: claimingMarker)
    }

    private struct MarkerIndex: Identifiable { let value: Int; var id: Int { value } }

    /// A Marker is useless until it has a square, so it asks for one the moment
    /// it is bought rather than waiting to be noticed further down the page.
    private func buy(_ offer: ShopOffer) {
        let before = model.run.markers.count
        model.buy(slot: offer.slot)
        if offer.def.kind == .marker, model.run.markers.count > before {
            withAnimation(.snappy(duration: 0.2)) {
                claimingMarker = model.run.markers.count - 1
            }
        }
    }

    private func hasSlot(for kind: ItemKind) -> Bool {
        switch kind {
        case .bookmark: return model.run.bookmarks.count < kind.capacity
        case .marker: return model.run.markers.count < model.run.markerCapacity
        case .buff: return model.run.buffs.count < kind.capacity
        case .subscription: return true
        }
    }

    private var standardOffers: [ShopOffer] { shop.offers.filter { $0.def.kind != .subscription } }
    private var subscriptionOffers: [ShopOffer] { shop.offers.filter { $0.def.kind == .subscription } }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Shop Page").pageHeading(30)
                Spacer(minLength: 6)
                rerollButton
            }
            Text("Stock up before the next puzzle.")
                .font(Print.body(13))
                .foregroundStyle(Paper.inkSoft)
            Rectangle().fill(Paper.rule).frame(height: 1)
        }
    }

    /// §9 — rerolling is the Shop's own action, so it lives on the Shop's page.
    private var rerollButton: some View {
        Button { model.reroll() } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                Text(shop.rerollCost == 0 ? "Free" : "\(shop.rerollCost)")
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
        .accessibilityLabel("Reroll the shop for \(shop.rerollCost) coins")
    }

    /// §11 — a Marker gains a square per Level, and the player chooses it here.
    private var pendingSquaresNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Squares to place")
                .font(Print.caption(11)).tracking(1.4).textCase(.uppercase)
                .foregroundStyle(Paper.inkSoft)
            ForEach(Array(model.run.markers.enumerated()), id: \.offset) { index, marker in
                let pending = marker.pendingSquares(atLevel: model.run.level)
                if pending > 0 {
                    Button { claimingMarker = index } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Paper.markerColor(marker.defID)).frame(width: 14, height: 14)
                            Text(marker.def.name)
                                .font(Print.subheading(13))
                                .foregroundStyle(Paper.ink)
                            Spacer()
                            Text("\(pending) to place")
                                .font(Print.caption(11))
                                .foregroundStyle(Paper.redPencil)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Paper.inkFaint)
                        }
                        .padding(9)
                        .background { RoundedRectangle(cornerRadius: 5).fill(Paper.pageWarm) }
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Paper.redPencil.opacity(0.5), lineWidth: 1.2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ownedSummary: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text("Your Buffs")
                    .font(Print.caption(11)).tracking(1.4).textCase(.uppercase)
                    .foregroundStyle(Paper.inkSoft)
                Rectangle().fill(Paper.rule.opacity(0.6)).frame(height: 1)
            }
            HStack(spacing: 14) {
                ForEach(0..<ItemKind.buff.capacity, id: \.self) { index in
                    HStack(spacing: 5) {
                        Image(systemName: index < model.run.buffs.count
                              ? ItemIcon.symbol(for: model.run.buffs[index].defID)
                              : "circle.dashed")
                            .font(.system(size: 15))
                            .foregroundStyle(index < model.run.buffs.count ? Paper.ink : Paper.inkFaint)
                        Text(index < model.run.buffs.count
                             ? model.run.buffs[index].def.name : "Empty")
                            .font(Print.body(11.5))
                            .foregroundStyle(Paper.inkSoft)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Offer

private struct OfferCard: View {
    var offer: ShopOffer
    var affordable: Bool
    var hasSlot: Bool
    var buy: () -> Void

    private var def: ItemDef { offer.def }
    private var isBuyable: Bool { !offer.sold && affordable && hasSlot }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            illustration

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(def.name)
                        .font(Print.subheading(15))
                        .foregroundStyle(Paper.ink)
                    RarityMark(rarity: def.rarity)
                }
                Text(def.text)
                    .font(Print.body(12))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            priceButton
        }
        .padding(11)
        .background { RoundedRectangle(cornerRadius: 6).fill(Paper.pageWarm.opacity(0.6)) }
        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Paper.rule, lineWidth: 1) }
        .overlay(alignment: .center) { if offer.sold { soldStamp } }
        .opacity(offer.sold ? 0.65 : 1)
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

    private var priceButton: some View {
        Button(action: buy) {
            HStack(spacing: 5) {
                Circle()
                    .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 16, height: 16)
                Text("\(offer.price)")
                    .font(Print.numeral(15, weight: .bold))
            }
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background { RoundedRectangle(cornerRadius: 4).fill(Paper.page) }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isBuyable ? Paper.sageDeep : Paper.rule,
                                  lineWidth: isBuyable ? 1.8 : 1)
            }
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(!isBuyable)
        .opacity(isBuyable ? 1 : 0.45)
        .accessibilityLabel("Buy \(def.name) for \(offer.price) coins")
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

private struct RarityMark: View {
    var rarity: Rarity

    var body: some View {
        Text(rarity.rawValue)
            .font(Print.caption(9))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(color.opacity(0.6), lineWidth: 1) }
    }

    private var color: Color {
        switch rarity {
        case .common: return Paper.inkFaint
        case .uncommon: return Paper.sageDeep
        case .rare: return Paper.redPencil
        }
    }
}
