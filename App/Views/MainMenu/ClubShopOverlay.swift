import SwiftUI

/// The paper controls from the approved counter mockup. The room, cabinet,
/// sign, lamp and samples stay physical SceneKit objects; navigation and
/// purchase affordances stay real SwiftUI buttons.
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
    let onDragItem: (CGFloat?) -> Void

    var body: some View {
        ZStack {
            backButton
                .frame(width: 47, height: 47)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 19)
                .padding(.top, 23)

        }
        .accessibilityElement(children: .contain)
    }

    private var sampleSwipeRegion: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            guard abs(horizontal) > abs(vertical) else {
                                onDragItem(nil)
                                return
                            }
                            onDragItem(max(-72, min(72, horizontal)))
                        }
                        .onEnded { value in
                            onDragItem(nil)
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            let projectedHorizontal = value.predictedEndTranslation.width
                            let projectedVertical = value.predictedEndTranslation.height
                            let actualCandidate = abs(horizontal) > abs(vertical) ? horizontal : nil
                            let projectedCandidate = abs(projectedHorizontal) > abs(projectedVertical)
                                ? projectedHorizontal
                                : nil
                            let decisiveHorizontal: CGFloat?
                            switch (actualCandidate, projectedCandidate) {
                            case let (actual?, projected?):
                                decisiveHorizontal = abs(projected) > abs(actual) ? projected : actual
                            case let (actual?, nil):
                                decisiveHorizontal = actual
                            case let (nil, projected?):
                                decisiveHorizontal = projected
                            case (nil, nil):
                                decisiveHorizontal = nil
                            }
                            guard let decisiveHorizontal, abs(decisiveHorizontal) > 32 else { return }
                            onStepItem(decisiveHorizontal < 0 ? 1 : -1)
                        }
                )
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard !categories.isEmpty, proxy.size.width > 0 else { return }
                            let fraction = max(0, min(0.999, value.location.x / proxy.size.width))
                            let index = min(categories.count - 1, Int(fraction * CGFloat(categories.count)))
                            onSelectCategory(categories[index])
                        }
                )
                .accessibilityHidden(true)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Text("‹")
                .font(.custom("Georgia", fixedSize: 28))
                .foregroundStyle(ShopInk.paper)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Circle().fill(ShopInk.backdrop.opacity(0.90)))
                .overlay(Circle().stroke(ShopInk.backBorder, lineWidth: 2))
                .shadow(color: .black.opacity(0.55), radius: 9, y: 7)
        }
        .buttonStyle(ShopPressedStyle())
        .accessibilityLabel("Back to bookstore")
        .accessibilityHint("Return to the main aisle")
    }

    private var stampBadge: some View {
        HStack(spacing: 7) {
            Text("§")
                .font(.custom("Georgia", fixedSize: 12))
                .foregroundStyle(ShopInk.stampSage)
                .frame(width: 19, height: 19)
                .overlay {
                    Circle()
                        .stroke(ShopInk.stampSage, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
            Text("\(stampBalance) STAMPS")
                .font(.system(size: 12, weight: .regular))
                .tracking(1.2)
        }
        .foregroundStyle(ShopInk.paper.opacity(0.96))
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(ShopInk.brass.opacity(0.62), lineWidth: 1))
        .shadow(color: .black.opacity(0.42), radius: 6, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stampBalance) Stamps")
    }

    private var pageIndicator: some View {
        HStack(spacing: 9) {
            Rectangle().fill(ShopInk.brass.opacity(0.42)).frame(width: 28, height: 1)
            Text("\(currentIndex + 1) OF \(max(itemCount, 1)) · SWIPE THE COUNTER")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.25)
                .foregroundStyle(ShopInk.page)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Rectangle().fill(ShopInk.brass.opacity(0.42)).frame(width: 28, height: 1)
        }
        .shadow(color: .black.opacity(0.85), radius: 4, y: 2)
        .accessibilityHidden(true)
    }

    private var categoryPicker: some View {
        HStack(spacing: 6) {
            ForEach(categories) { category in
                categoryButton(category)
            }
        }
        .frame(height: 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shop categories")
    }

    private func categoryButton(_ category: CosmeticCategory) -> some View {
        let selected = category == selectedCategory
        return Button {
            onSelectCategory(category)
        } label: {
            Text(category.title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(selected ? ShopInk.categorySelectedInk : ShopInk.categoryInactiveInk)
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(selected ? ShopInk.categorySelected : ShopInk.categoryInactive)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(selected ? ShopInk.categorySelectedBorder : ShopInk.categoryInactiveBorder,
                                lineWidth: 1)
                }
                .shadow(color: selected ? .black.opacity(0.42) : .clear, radius: 5, y: 3)
        }
        .buttonStyle(ShopPressedStyle())
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var productTicket: some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(alignment: .leading, spacing: 0) {
                Text(productKind)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(ShopInk.red)

                Text(selectedItem.name)
                    .font(.custom("Georgia", fixedSize: 21))
                    .foregroundStyle(ShopInk.ticketInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 4)

                Text(selectedItem.blurb)
                    .font(.custom("Georgia-Italic", fixedSize: 12))
                    .foregroundStyle(ShopInk.ticketSoftInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
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
            .allowsHitTesting(false)

            Button(action: onBuyOrEquip) {
                Text(actionTitle)
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(ShopInk.paper)
                    .frame(width: 132)
                    .frame(maxHeight: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(actionEnabled ? ShopInk.sage : ShopInk.disabled)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(actionEnabled ? ShopInk.sageDeep : ShopInk.ticketSoftInk.opacity(0.55), lineWidth: 1)
                    }
            }
            .buttonStyle(ShopPressedStyle())
            // An unaffordable item remains tappable so the store can explain
            // the refusal and emit the warning feedback promised by the UI.
            .disabled(equipped)
            .accessibilityHint(actionAccessibilityHint)
        }
        .padding(.top, 13)
        .padding(.leading, 15)
        .padding(.bottom, 12)
        .padding(.trailing, 13)
        .frame(height: 116)
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(ShopInk.ticket)
                .overlay { PaperGrain(opacity: 0.045, seed: 31).clipShape(.rect(cornerRadius: 3)) }
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(ShopInk.ticketEdge, lineWidth: 1.2)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.62), radius: 12, y: 7)
    }

    private func toast(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundStyle(ShopInk.paper)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(ShopInk.toastBackground.opacity(0.90), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(ShopInk.toastBorder.opacity(0.48)))
            .shadow(color: .black.opacity(0.5), radius: 7, y: 4)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var actionTitle: String {
        if equipped { return "EQUIPPED" }
        if owned { return "EQUIP" }
        if affordable { return "BUY · \(selectedItem.price)" }
        return "NEED \(max(0, selectedItem.price - stampBalance)) MORE"
    }

    private var actionEnabled: Bool {
        !equipped && (owned || affordable)
    }

    private var productKind: String {
        switch selectedCategory {
        case .paper: "Paper stock"
        case .board: "Live grid rule"
        case .numbers: "Individual number glyph"
        }
    }

    private var actionAccessibilityHint: String {
        if equipped { return "This sample is currently equipped" }
        if owned { return "Equip this sample" }
        if affordable { return "Purchase and equip this sample" }
        return "Earn \(max(0, selectedItem.price - stampBalance)) more Stamps to purchase"
    }

    private var productAccessibilityLabel: String {
        let ownership: String
        if equipped { ownership = "Owned and equipped" }
        else if owned { ownership = "Owned, available to equip" }
        else { ownership = "Not owned" }

        let affordability: String
        if owned { affordability = "" }
        else if affordable { affordability = "Affordable with your current balance" }
        else { affordability = "Need \(selectedItem.price - stampBalance) more Stamps" }

        return "\(selectedItem.name), \(productKind). \(selectedItem.blurb) "
            + "Costs \(selectedItem.price) Stamps. \(ownership). \(affordability)."
    }
}

private enum ShopInk {
    static let paper = Color(hex: 0xE9E1CF)
    static let page = Color(hex: 0xD9CCB3)
    static let brass = Color(hex: 0xA67A39)
    static let backdrop = Color(hex: 0x0E0E0C)
    static let backBorder = Color(hex: 0xD59B2E)
    static let stampSage = Color(hex: 0xA9B99A)
    static let sage = Color(hex: 0x6F8068)
    static let sageDeep = Color(hex: 0x4E5F48)
    static let categorySelected = Color(hex: 0xE7DECA)
    static let categorySelectedInk = Color(hex: 0x29251F)
    static let categorySelectedBorder = Color(hex: 0xAEBA9F)
    static let categoryInactive = Color(hex: 0x16120E).opacity(0.78)
    static let categoryInactiveInk = Color(hex: 0xC9BCA4)
    static let categoryInactiveBorder = Color(hex: 0xE0D0AE).opacity(0.34)
    static let ticket = Color(hex: 0xE5DCC8)
    static let ticketEdge = Color(hex: 0xB8AA8F)
    static let ticketInk = Color(hex: 0x312C25)
    static let ticketSoftInk = Color(hex: 0x686054)
    static let red = Color(hex: 0x8B4737)
    static let disabled = Color(hex: 0xAEA694)
    static let toastBackground = Color(hex: 0x110F0C)
    static let toastBorder = Color(hex: 0xDDCDAD)
}

private struct ShopPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

private struct CounterPlacementButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ShopInk.paper)
            .background(ShopInk.backdrop.opacity(configuration.isPressed ? 0.72 : 0.92),
                        in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(ShopInk.backBorder, lineWidth: 1.2))
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}
