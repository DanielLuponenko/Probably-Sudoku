import SwiftUI

/// Minimal navigation and accessibility laid over the physical counter.
/// Product copy, browse state, category labels and purchase state are printed
/// on SceneKit objects so the shop reads as one room rather than a room with a
/// second interface pasted across its lower third.
struct ClubShopOverlay: View {
    let categories: [CosmeticCategory]
    let selectedCategory: CosmeticCategory
    let selectedItem: CosmeticItem
    let currentIndex: Int
    let itemCount: Int
    let stampBalance: Int
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    let message: String?
    let onBack: () -> Void
    let onSelectCategory: (CosmeticCategory) -> Void
    let onBuyOrEquip: () -> Void
    let onStepItem: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .allowsHitTesting(false)
                .overlay(alignment: .top) {
                    header
                        .padding(.horizontal, max(14, proxy.size.width * 0.045))
                        .padding(.top, 18)
                }
                .overlay {
                    accessibleProductSummary
                        .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.52)
                }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(ShopInk.paper)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.black.opacity(0.58)))
                    .overlay(Circle().stroke(ShopInk.brass.opacity(0.82), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.44), radius: 6, y: 4)
            }
            .buttonStyle(ShopPressedStyle())
            .accessibilityLabel("Back to bookstore")
            .accessibilityHint("Return to the main aisle")

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(stampBalance)")
                    .font(Print.numeral(15, weight: .bold))
                Text("STAMPS")
                    .font(Print.caption(7.5))
                    .tracking(1.1)
            }
            .foregroundStyle(ShopInk.paper.opacity(0.92))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(ShopInk.brass.opacity(0.55), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(stampBalance) Stamps")
        }
    }

    private var accessibleProductSummary: some View {
        Color.clear
            .frame(width: 2, height: 2)
            .id("\(selectedCategory.rawValue)-\(selectedItem.id)-\(owned)-\(equipped)-\(stampBalance)")
            .accessibilityElement()
            .accessibilityLabel(productAccessibilityLabel)
            .accessibilityValue("Item \(currentIndex + 1) of \(max(itemCount, 1))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onStepItem(1)
                case .decrement: onStepItem(-1)
                @unknown default: break
                }
            }
            .accessibilityAction(named: "Previous item") { onStepItem(-1) }
            .accessibilityAction(named: "Next item") { onStepItem(1) }
            .accessibilityAction(named: "Buy or equip selected sample") {
                guard !equipped, owned || affordable else { return }
                onBuyOrEquip()
            }
            .accessibilityAction(named: "Desk samples") { onSelectCategory(.desk) }
            .accessibilityAction(named: "Paper samples") { onSelectCategory(.paper) }
            .accessibilityAction(named: "Grid samples") { onSelectCategory(.board) }
            .accessibilityAction(named: "Numbers samples") { onSelectCategory(.numbers) }
    }

    private var productAccessibilityLabel: String {
        let state: String
        if equipped { state = "Equipped" }
        else if owned { state = "Owned, available to equip" }
        else if affordable { state = "Costs \(selectedItem.price) Stamps, affordable" }
        else { state = "Costs \(selectedItem.price) Stamps, need \(selectedItem.price - stampBalance) more" }
        return "\(selectedItem.name), \(selectedCategory.title) sample. \(selectedItem.blurb) \(state)."
    }
}

private enum ShopInk {
    static let paper = Color(hex: 0xE9E1CF)
    static let brass = Color(hex: 0xA67A39)
}

private struct ShopPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
    }
}
