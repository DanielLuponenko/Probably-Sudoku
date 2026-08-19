import SwiftUI

/// A number that rolls to its new value, one column per digit, the way a
/// mechanical counter does.
///
/// Each column is a strip of 0–9 clipped to a single digit's height and offset
/// to the digit it is showing; changing the offset rolls it. The columns are
/// staggered from the right, so a carry ripples leftwards instead of every
/// digit snapping at once — which is what makes it read as a wheel rather than
/// as text being replaced.
struct RollingNumber: View {
    var value: Int
    var size: CGFloat
    var weight: Font.Weight = .bold
    var color: Color = Paper.ink
    /// Grouped by thousands, since scores get long fast.
    var grouped: Bool = true

    private var text: String {
        grouped ? value.formatted(.number.grouping(.automatic)) : String(value)
    }

    /// Tall enough for the glyphs plus their descenders, which a bare font size
    /// is not — too tight and the digits are clipped mid-roll.
    private var lineHeight: CGFloat { size * 1.18 }

    var body: some View {
        let characters = Array(text)
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                if let digit = character.wholeNumberValue, character.isNumber {
                    RollingColumn(
                        digit: digit,
                        height: lineHeight,
                        size: size,
                        weight: weight,
                        color: color,
                        // Distance from the right: the units column moves
                        // first, and the carry travels up the number.
                        delay: Double(characters.count - 1 - index) * 0.035
                    )
                } else {
                    Text(String(character))
                        .font(.system(size: size, weight: weight))
                        .foregroundStyle(color)
                        .frame(height: lineHeight)
                }
            }
        }
        .frame(height: lineHeight)
        .accessibilityLabel(text)
    }
}

private struct RollingColumn: View {
    var digit: Int
    var height: CGFloat
    var size: CGFloat
    var weight: Font.Weight
    var color: Color
    var delay: Double

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0...9, id: \.self) { number in
                Text("\(number)")
                    .font(.system(size: size, weight: weight).monospacedDigit())
                    .foregroundStyle(color)
                    .frame(height: height)
            }
        }
        .offset(y: -CGFloat(digit) * height)
        .frame(height: height, alignment: .top)
        .clipped()
        // Enough spring to overshoot slightly and settle, like a wheel with
        // some weight to it.
        .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(delay), value: digit)
    }
}
