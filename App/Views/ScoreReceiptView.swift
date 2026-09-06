import SwiftUI

/// A small printed receipt in the existing margin, never an input-blocking overlay.
struct ScoreReceiptView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var beat: ScorePerformance.Beat
    var summary: String

    private var ink: Color {
        switch beat.kind {
        case .multiplier: Paper.redPencil
        case .coins: Paper.coinRim
        case .bank: Paper.sageDeep
        default: Paper.ink
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: beat.kind == .bank ? "checkmark.seal" : "pencil.tip")
                .font(.system(size: 12, weight: .semibold))
                .accessibilityHidden(true)
            Text(beat.source)
                .font(Print.caption(12))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 2)
            Text(beat.value)
                .font(Print.numeral(19, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .monospacedDigit()
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Paper.pageWarm.opacity(0.94), in: .rect(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(ink.opacity(beat.kind == .bank ? 0.7 : 0.25), lineWidth: 1)
        }
        .rotationEffect(.degrees(reduceMotion ? 0 : (beat.kind == .bank ? -1 : 0)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scoring receipt")
        .accessibilityValue(summary)
    }
}
