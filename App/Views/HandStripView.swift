import SwiftUI
import ProbablySudokuEngine

/// §4 — the numbers that have arrived from the Pool. Flat printed tiles, not
/// balls. Duplicates are possible and meaningful, so each dealt card carries
/// a presentation identity separate from the number it shows.
struct HandStripView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Bindable var model: GameModel
    var handSize: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.isReadingLitmus ? "Litmus: select a number to inspect blanks" : "Numbers Drawn")
                    .font(Print.caption(12))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(model.isReadingLitmus ? Paper.sageDeep : Paper.inkSoft)
                Spacer()
                if model.isReadingLitmus {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 12))
                        .foregroundStyle(Paper.sageDeep)
                }
            }

            HStack(spacing: 7) {
                ForEach(model.handCards) { card in
                    if let index = model.handCards.firstIndex(where: { $0.id == card.id }) {
                        Button {
                            model.tapHand(index)
                        } label: {
                            NumberTile(
                                digit: card.digit,
                                isSelected: model.selectedHandIndex == index,
                                isBlocked: model.isBlocked(card.digit),
                                arrivalOrder: card.arrivalOrder,
                                shouldAnimateArrival: model.animatesHandArrival,
                                theme: theme
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Number \(card.digit.rawValue)"
                            + (model.isBlocked(card.digit) ? ", blocked this turn" : "")
                            + (model.selectedHandIndex == index ? ", selected" : ""))
                    }
                }

                ForEach(0..<max(0, handSize - model.handCards.count), id: \.self) { _ in
                    EmptySlot()
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: model.isReadingLitmus)
    }
}

private struct NumberTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var digit: Digit
    var isSelected: Bool
    var isBlocked: Bool
    var arrivalOrder: Int
    var shouldAnimateArrival: Bool
    var theme: CosmeticTheme

    @State private var hasArrived = false

    var body: some View {
        Text("\(digit.rawValue)")
            .font(theme.numbers.font(27, weight: .medium))
            .foregroundStyle(isBlocked ? Paper.inkFaint : theme.numbers.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? theme.board.selected : theme.paper.warm)
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
                                            : (isSelected ? Paper.sageDeep : theme.board.hair),
                                  lineWidth: isSelected ? 2 : 1)
            }
            .animation(.snappy(duration: 0.18), value: isSelected)
            .scaleEffect(hasArrived || reduceMotion || !shouldAnimateArrival ? 1 : 0.78)
            .offset(y: hasArrived || reduceMotion || !shouldAnimateArrival
                    ? (isSelected ? -4 : 0) : 10)
            .opacity(hasArrived || reduceMotion || !shouldAnimateArrival ? 1 : 0)
            .onAppear {
                guard shouldAnimateArrival && !reduceMotion else {
                    hasArrived = true
                    return
                }
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.16)
                    .delay(Double(arrivalOrder) * 0.035)) {
                    hasArrived = true
                }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced { hasArrived = true }
            }
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
