import SwiftUI

/// A single fitted number with a rolling numeric transition. Keeping the glyphs
/// in one Text matters: separate clipped digit strips compress independently
/// when the score grows, cutting the sides off otherwise valid numbers.
struct RollingNumber: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var value: Int
    var size: CGFloat
    var weight: Font.Weight = .bold
    var color: Color = Paper.ink
    /// Grouped by thousands, since scores get long fast.
    var grouped: Bool = true

    private var text: String {
        grouped ? value.formatted(.number.grouping(.automatic)) : String(value)
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.35)
            // Keep the page geometry steady through carries and smaller values.
            .frame(height: size * 1.18)
            .contentTransition(.numericText(value: Double(value)))
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: value)
            .transaction { if reduceMotion { $0.animation = nil } }
            .accessibilityLabel(text)
    }
}
