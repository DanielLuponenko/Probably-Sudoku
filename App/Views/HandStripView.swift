import SwiftUI
import NumberClubEngine

/// §4 — the numbers that have arrived from the Pool. Flat printed tiles, not
/// balls. Duplicates are possible and meaningful, so slots are addressed by
/// position rather than by the number they hold.
struct HandStripView: View {
    @Bindable var model: GameModel
    var handSize: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Numbers Drawn")
                    .font(Print.caption(12))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.inkSoft)
                Spacer()
            }

            HStack(spacing: 7) {
                ForEach(0..<handSize, id: \.self) { index in
                    if index < model.hand.count {
                        NumberTile(
                            digit: model.hand[index],
                            isSelected: model.selectedHandIndex == index,
                            isBlocked: model.isBlocked(model.hand[index])
                        )
                        .onTapGesture { model.tapHand(index) }
                    } else {
                        EmptySlot()
                    }
                }
            }
        }
    }
}

private struct NumberTile: View {
    var digit: Digit
    var isSelected: Bool
    var isBlocked: Bool

    var body: some View {
        Text("\(digit.rawValue)")
            .font(Print.numeral(27, weight: .medium))
            .foregroundStyle(isBlocked ? Paper.inkFaint : Paper.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Paper.cellSelected : Paper.pageWarm)
            }
            .overlay {
                // Struck through in red pencil: it is still yours and still
                // Tossable, it just cannot be played this Turn.
                if isBlocked {
                    Rectangle()
                        .fill(Paper.redPencil.opacity(0.75))
                        .frame(height: 1.8)
                        .rotationEffect(.degrees(-14))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isBlocked ? Paper.redPencil.opacity(0.55)
                                            : (isSelected ? Paper.sageDeep : Paper.rule),
                                  lineWidth: isSelected ? 2 : 1)
            }
            .offset(y: isSelected ? -4 : 0)
            .animation(.snappy(duration: 0.18), value: isSelected)
            .accessibilityLabel("Number \(digit.rawValue)"
                + (isBlocked ? ", blocked this turn" : "")
                + (isSelected ? ", selected" : ""))
    }

}

private struct EmptySlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(Paper.rule.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .accessibilityLabel("Empty slot")
    }
}
