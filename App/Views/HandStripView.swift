import SwiftUI
import ProbablySudokuEngine

/// §4 — the numbers that have arrived from the Pool. Flat printed tiles, not
/// balls. Duplicates are possible and meaningful, so each dealt card carries
/// a presentation identity separate from the number it shows.
struct HandStripView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    @Bindable var model: GameModel
    var handSize: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.isChoosingClue ? "Clue: choose a number" :
                     model.isReadingLitmus ? "Litmus: select a number to inspect blanks" : "Numbers Drawn")
                    .font(Print.caption(12))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(model.isReadingLitmus || model.isChoosingClue ? palette.accent : palette.ink.opacity(0.7))
                Spacer()
                // Keep the animation destination without introducing a
                // visible control that is absent from the paper-board design.
                Color.clear
                    .frame(width: 1, height: 1)
                    .numberReturnMotionFrame(NumberReturnMotionAnchor.pool)
                if model.isReadingLitmus {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.accent)
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
                                isBlocked: model.isBlocked(handIndex: index),
                                arrivalOrder: card.arrivalOrder,
                                shouldAnimateArrival: model.animatesHandArrival,
                                theme: theme,
                                palette: palette
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Number \(card.digit.rawValue)"
                            + (model.isBlocked(handIndex: index) ? ", blocked this turn" : "")
                            + (model.selectedHandIndex == index ? ", selected" : ""))
                    }
                }

                ForEach(0..<max(0, handSize - model.handCards.count), id: \.self) { _ in
                    EmptySlot()
                }
            }
            .numberReturnMotionFrame(NumberReturnMotionAnchor.hand)
        }
        .animation(.snappy(duration: 0.2), value: model.isReadingLitmus)
        .cosmeticPulseClock(for: theme.numbers.finish)
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
    var palette: LevelPalette

    @State private var hasArrived = false

    var body: some View {
        CosmeticNumberGlyph(text: "\(digit.rawValue)", skin: theme.numbers,
                            size: 27, weight: .medium,
                            color: isBlocked ? palette.ink.opacity(0.48) : theme.numbers.ink,
                            intensity: isBlocked ? 0.54 : 1)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? theme.board.selected : theme.paper.warm)
                    .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 2)
            }
            .overlay {
                // Struck through in red pencil: it is still yours and still
                // Tossable, it just cannot be played this Turn.
                if isBlocked {
                    Rectangle()
                        .fill(palette.danger.opacity(0.75))
                        .frame(height: 1.8)
                        .rotationEffect(.degrees(-14))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isBlocked ? palette.danger.opacity(0.55)
                                            : (isSelected ? palette.accent : theme.board.hair),
                                  lineWidth: isSelected ? 2 : 1)
            }
            .scaleEffect(hasArrived || reduceMotion || !shouldAnimateArrival
                         ? 1 : theme.numbers.motion.arrivalScale)
            .offset(y: reduceMotion ? 0 : (hasArrived || !shouldAnimateArrival
                    ? (isSelected ? -4 : 0) : theme.numbers.motion.arrivalOffset))
            .opacity(hasArrived || reduceMotion || !shouldAnimateArrival ? 1 : 0)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isSelected)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isBlocked)
            .onAppear {
                guard shouldAnimateArrival && !reduceMotion else {
                    hasArrived = true
                    return
                }
                withAnimation(theme.numbers.motion.arrivalAnimation
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
    @Environment(\.levelPalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(palette.rule.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .accessibilityLabel("Empty slot")
    }
}
