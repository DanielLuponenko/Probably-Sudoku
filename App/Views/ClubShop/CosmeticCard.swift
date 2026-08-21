import SwiftUI

/// One thing on the counter: what it looks like, what it is called, and the
/// single most useful thing you could do with it next.
///
/// Owned is never a button. Once something is bought the only interesting
/// action is wearing it, so the card stops offering to sell it — a card that
/// says "Purchased" forever is a card that has stopped being useful.
struct CosmeticCard: View {
    var item: CosmeticItem
    var owned: Bool
    var equipped: Bool
    var affordable: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CosmeticPreview(item: item, side: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(Print.subheading(14))
                        .foregroundStyle(Paper.ink)
                    Text(item.blurb)
                        .font(Print.body(11.5))
                        .foregroundStyle(Paper.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                state
            }
            .padding(11)
            .frame(minHeight: 74)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(equipped ? Paper.cellSelected : Paper.page)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(equipped ? Paper.sageDeep : Paper.rule,
                                  lineWidth: equipped ? 1.6 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityValue(spokenState)
        .accessibilityHint(spokenHint)
    }

    @ViewBuilder
    private var state: some View {
        if equipped {
            Text("Equipped")
                .font(Print.caption(10))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Paper.sageDeep)
        } else if owned {
            Text("Equip")
                .font(Print.caption(11))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Paper.ink)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .overlay {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(Paper.rule, lineWidth: 1)
                }
        } else {
            HStack(spacing: 4) {
                Image(systemName: ClubCurrency.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text("\(item.price)")
                    .font(Print.numeral(14, weight: .bold))
            }
            .foregroundStyle(affordable ? Paper.ink : Paper.inkFaint)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background {
                RoundedRectangle(cornerRadius: 3)
                    .fill(affordable ? Paper.pageWarm : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(affordable ? Paper.rule : Paper.rule.opacity(0.5),
                                  lineWidth: 1)
            }
        }
    }

    private var spokenState: String {
        if equipped { return "Equipped" }
        if owned { return "Owned" }
        if affordable { return "\(item.price) \(ClubCurrency.name)" }
        return "\(item.price) \(ClubCurrency.name). Not enough \(ClubCurrency.name)"
    }

    private var spokenHint: String {
        if equipped { return "Already on the desk" }
        if owned { return "Equip this" }
        return affordable ? "Buy this" : "Finish a Book to earn more"
    }
}
