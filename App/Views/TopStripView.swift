import SwiftUI
import NumberClubEngine

/// The paper strip that sits above the book on every page. It carries the coin
/// count, where you are in the Book, and the page's controls. Refresh only ever
/// appears on the Shop page; the Puzzle page shows Clue instead.
/// The band either side of the Dynamic Island is the only part of the screen
/// the book cannot use, so the run's two constants live there: what you have,
/// and the way out. Everything else belongs on the page.
struct IslandBar: View {
    var coins: Int
    var controls: [StripControl]

    var body: some View {
        HStack(spacing: 6) {
            CoinBadge(count: coins)
            Spacer(minLength: 0)
            ForEach(controls) { control in
                RoundIconButton(control: control)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 34)
        // Sits on the Island's own centre line rather than below it.
        .padding(.top, 13)
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

struct RoundIconButton: View {
    var control: StripControl

    var body: some View {
        Button(action: control.action) {
            Image(systemName: control.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.ink.opacity(control.isEnabled ? 0.85 : 0.28))
                .frame(width: 32, height: 32)
                .background { Circle().fill(Paper.page) }
                .overlay {
                    Circle().strokeBorder(Paper.ink.opacity(control.isEnabled ? 0.35 : 0.15),
                                          lineWidth: 1.2)
                }
                // The tap target stays 44pt even though the disc is smaller.
                .contentShape(Circle().inset(by: -6))
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
                Circle().strokeBorder(Paper.coinRim, lineWidth: 1.4)
                Text("N")
                    .font(Print.heading(13))
                    .foregroundStyle(Paper.ink.opacity(0.8))
            }
            .frame(width: 26, height: 26)
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)

            Text("\(count)")
                .font(Print.numeral(19, weight: .bold))
                .foregroundStyle(Paper.page)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
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
                    .frame(width: i == index ? 9 : 7, height: i == index ? 9 : 7)
                if i < count - 1 {
                    Rectangle()
                        .fill(Paper.ink.opacity(0.35))
                        .frame(width: 12, height: 1.2)
                }
            }
        }
        .animation(.snappy, value: index)
        .accessibilityLabel("Puzzle \(index + 1) of \(count)")
    }
}
