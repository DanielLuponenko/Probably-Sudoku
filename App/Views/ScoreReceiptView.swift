import SwiftUI

/// One plain line of attribution beside the score. The queue line already
/// reserves its height, so score beats never add a banner or move the board.
struct ScoreReceiptView: View {
    @Environment(\.levelPalette) private var palette
    var beat: ScorePerformance.Beat
    var summary: String

    private var ink: Color {
        switch beat.kind {
        case .multiplier: palette.danger
        case .coins: Paper.coinRim
        case .bank: palette.accent
        default: palette.ink
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(beat.source)
                .font(Print.caption(11))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 2)
            Text(beat.value)
                .font(Print.numeral(12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score breakdown")
        .accessibilityValue(summary)
        .accessibilityIdentifier("puzzle.scoreBreakdown")
    }
}
