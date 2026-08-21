import SwiftUI

/// What the player has to spend. Live text, always — a balance drawn into an
/// image is a balance that is wrong the moment anything is bought.
struct CosmeticCurrencyBadge: View {
    var amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ClubCurrency.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Paper.sageDeep)
            Text("\(amount)")
                .font(Print.numeral(15, weight: .bold))
                .foregroundStyle(Paper.ink)
                .contentTransition(.numericText())
            Text(ClubCurrency.name)
                .font(Print.caption(10))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Paper.inkFaint)
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background {
            RoundedRectangle(cornerRadius: 3).fill(Paper.pageWarm)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3).strokeBorder(Paper.rule, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) \(ClubCurrency.name)")
    }
}
