import SwiftUI

/// The club's own counter, where cosmetics are kept.
///
/// Nothing to do with `ShopPageView`. That one is a page inside an open Book:
/// it spends the coins of a run, sells Bookmarks, Markers and Buffs, and
/// changes how the next Puzzle plays. This one exists whether or not a Book is
/// open, spends currency that outlives every run, and sells nothing that can
/// touch the rules. Wiring the menu's Shop button to the other one would let
/// the front door edit a run that may not exist.
struct ClubShopView: View {
    var onBack: () -> Void

    @Environment(PlayerProfileStore.self) private var profile
    @State private var category: CosmeticCategory = .desk
    @State private var refused: String?
    @State private var justBought: String?
    @State private var successfulChoice = false
    @State private var refusedChoice = false
    @State private var previewedItem: CosmeticItem?

    var body: some View {
        ZStack {
            counter

            VStack(spacing: 0) {
                header
                tabs
                shelf
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            if let item = previewedItem {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .onTapGesture { previewedItem = nil }
                    .accessibilityHidden(true)

                CosmeticInPlayPreview(item: item,
                                      theme: previewTheme(for: item),
                                      owned: profile.owns(item),
                                      equipped: profile.isEquipped(item),
                                      stamps: profile.currency,
                                      onClose: { previewedItem = nil },
                                      onPurchase: { buyFromPreview(item) })
                    .padding(18)
            }
        }
        .background(Paper.deskDark)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .sensoryFeedback(.success, trigger: successfulChoice)
        .sensoryFeedback(.warning, trigger: refusedChoice)
    }

    /// A drawer pulled out of the cabinet, with the samples laid in it.
    private var counter: some View {
        ZStack {
            Rectangle().fill(CosmeticCatalog.desk(profile.profile.equipped.deskID).surface)
            LinearGradient(colors: [.black.opacity(0.30), .clear, .black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Back")
                        .font(Print.caption(11))
                        .tracking(1.2)
                        .textCase(.uppercase)
                }
                .foregroundStyle(Paper.page)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressedPaperStyle())
            .accessibilityLabel("Back to the main menu")

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text("Club Shop")
                    .font(Print.subheading(17))
                    .foregroundStyle(Paper.page)
                Text("Kept between Books")
                    .font(Print.caption(9.5))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.page.opacity(0.55))
            }
        }
        .padding(.top, 6)
        .overlay(alignment: .bottom) {
            CosmeticCurrencyBadge(amount: profile.currency)
                .offset(y: 30)
                .animation(.snappy(duration: 0.25), value: profile.currency)
        }
        .padding(.bottom, 42)
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Markers are part of the game, not a Club Shop cosmetic. Keep
                // them out of this player-facing catalogue until they have a
                // real use here.
                ForEach(CosmeticCategory.allCases.filter { $0 != .marker }) { option in
                    let selected = option == category
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { category = option }
                    } label: {
                        Text(option.title)
                            .font(Print.caption(11))
                            .tracking(1.3)
                            .textCase(.uppercase)
                            .foregroundStyle(selected ? Paper.ink : Paper.page.opacity(0.75))
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(selected ? Paper.page : Color.white.opacity(0.06))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(selected ? Paper.pageEdge
                                                           : Paper.page.opacity(0.22),
                                                  lineWidth: 1)
                            }
                    }
                    .buttonStyle(PressedPaperStyle())
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 10)
    }

    private var shelf: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 9) {
                Text(category.note)
                    .font(Print.body(12))
                    .foregroundStyle(Paper.page.opacity(0.6))
                    .padding(.bottom, 2)

                ForEach(CosmeticCatalog.items(in: category)) { item in
                    CosmeticCard(item: item,
                                 owned: profile.owns(item),
                                 equipped: profile.isEquipped(item),
                                 affordable: profile.currency >= item.price,
                                 refusalVisible: refused == item.id) {
                        choose(item)
                    } onPreview: {
                        previewedItem = item
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .animation(.snappy(duration: 0.22), value: refused)
        .animation(.snappy(duration: 0.22), value: justBought)
    }

    /// One tap, and the card decides what that means: buy it if it is not
    /// owned, wear it if it is, and nothing at all if it is already on.
    private func choose(_ item: CosmeticItem) {
        _ = buyOrEquip(item)
    }

    /// Returns whether the item became equipped. Previewing never calls this,
    /// which keeps the real loadout unchanged until the player asks to buy or
    /// equip from the slip itself.
    @discardableResult
    private func buyOrEquip(_ item: CosmeticItem) -> Bool {
        if profile.isEquipped(item) { return false }

        if profile.owns(item) {
            profile.equip(item)
            successfulChoice.toggle()
            return true
        }

        do {
            try profile.purchase(item)
            profile.equip(item)
            justBought = item.id
            successfulChoice.toggle()
            return true
        } catch {
            refused = item.id
            refusedChoice.toggle()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                if refused == item.id { refused = nil }
            }
            return false
        }
    }

    private func buyFromPreview(_ item: CosmeticItem) {
        if buyOrEquip(item) { previewedItem = nil }
    }

    private func previewTheme(for item: CosmeticItem) -> CosmeticTheme {
        var loadout = profile.profile.equipped
        loadout[item.category] = item.id
        return CosmeticCatalog.theme(for: loadout)
    }
}

#Preview("Club Shop") {
    ClubShopView(onBack: {})
        .environment(PlayerProfileStore(profile: PlayerProfile()))
}
