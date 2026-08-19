import SwiftUI
import NumberClubEngine

/// The paper strip that sits above the book on every page. It carries the coin
/// count, where you are in the Book, and the page's controls. Refresh only ever
/// appears on the Shop page; the Puzzle page shows Clue instead.
struct TopStripView: View {
    var coins: Int
    var levelLabel: String
    var slotIndex: Int
    var slotCount: Int
    var trailing: [StripControl]

    var body: some View {
        HStack(spacing: 12) {
            CoinBadge(count: coins)

            Spacer(minLength: 4)

            VStack(spacing: 5) {
                Text(levelLabel)
                    .font(Print.subheading(15))
                    .foregroundStyle(Paper.ink)
                ProgressDots(index: slotIndex, count: slotCount)
            }

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                ForEach(trailing) { control in
                    RoundIconButton(control: control)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(Paper.page)
                .overlay { Capsule().fill(.clear).overlay(PaperGrain(opacity: 0.04)) }
                .overlay { Capsule().strokeBorder(Paper.pageEdge, lineWidth: 1) }
                .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 6)
        }
    }
}

struct StripControl: Identifiable {
    let id = UUID()
    var systemImage: String
    var label: String
    var badge: String?
    var isEnabled: Bool = true
    var action: () -> Void
}

private struct RoundIconButton: View {
    var control: StripControl

    var body: some View {
        Button(action: control.action) {
            Image(systemName: control.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Paper.ink.opacity(control.isEnabled ? 0.85 : 0.28))
                .frame(width: 44, height: 44)
                .background {
                    Circle().strokeBorder(Paper.ink.opacity(control.isEnabled ? 0.7 : 0.22),
                                          lineWidth: 1.6)
                }
                .overlay(alignment: .topTrailing) {
                    if let badge = control.badge {
                        Text(badge)
                            .font(Print.caption(10))
                            .foregroundStyle(Paper.page)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Paper.ink))
                            .offset(x: 4, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!control.isEnabled)
        .accessibilityLabel(control.label)
    }
}

/// The brass token the game counts in.
struct CoinBadge: View {
    var count: Int

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(Paper.coinRim, lineWidth: 1.5)
                Text("N")
                    .font(Print.heading(15))
                    .foregroundStyle(Paper.ink.opacity(0.8))
            }
            .frame(width: 30, height: 30)
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)

            Text("\(count)")
                .font(Print.numeral(22, weight: .bold))
                .foregroundStyle(Paper.ink)
                .contentTransition(.numericText())
        }
        .animation(.snappy, value: count)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) coins")
    }
}

/// Where this Puzzle sits in the Level: three dots, one per slot.
struct ProgressDots: View {
    var index: Int
    var count: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i <= index ? Paper.ink : Color.clear)
                    .overlay { Circle().strokeBorder(Paper.ink.opacity(0.55), lineWidth: 1.4) }
                    .frame(width: i == index ? 11 : 9, height: i == index ? 11 : 9)
                if i < count - 1 {
                    Rectangle()
                        .fill(Paper.ink.opacity(0.35))
                        .frame(width: 22, height: 1.4)
                }
            }
        }
        .animation(.snappy, value: index)
        .accessibilityLabel("Puzzle \(index + 1) of \(count)")
    }
}
