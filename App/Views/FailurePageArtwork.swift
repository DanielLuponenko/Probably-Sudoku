import SwiftUI

/// A small pressed-brass emblem. Its meaning is supplied by the adjacent
/// heading, so the metalwork itself stays outside the accessibility tree.
struct FailureMedallion: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x9B773C))
                .offset(y: size * 0.025)

            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: 0xE9D298), Color(hex: 0xC8A565)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay {
                    FailureArtworkGrain(width: size, height: size, opacity: 0.12)
                }
                .compositingGroup()
                .clipShape(.circle)
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: 0xFFF0C9).opacity(0.85),
                                     Color(hex: 0xA17D40).opacity(0.65)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: size * 0.022
                    )
                }

            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: 0xC4A061), Color(hex: 0xE2C789)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay {
                    Circle().strokeBorder(Color(hex: 0x9C783D).opacity(0.45),
                                          lineWidth: size * 0.014)
                }
                .overlay {
                    Circle().strokeBorder(Color(hex: 0xFFF0C9).opacity(0.55),
                                          lineWidth: size * 0.012)
                        .padding(size * 0.026)
                }
                .padding(size * 0.115)

            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: size * 0.41, weight: .medium))
                .foregroundStyle(Color(hex: 0x8B6934))
                .shadow(color: Color(hex: 0xFFF0C9).opacity(0.85),
                        radius: 0, x: 0, y: size * 0.016)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .shadow(color: Paper.ink.opacity(0.13), radius: size * 0.075,
                x: 0, y: size * 0.055)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Three printed number cards, with a quiet upright reward card in front.
/// The supplied height defines the entire composition (width = height × 1.8).
struct RescueCardFan: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            FailureNumberCard(number: "7", width: height * 0.55,
                              height: height * 0.77, isReward: false)
                .rotationEffect(.degrees(-14))
                .offset(x: -height * 0.43, y: height * 0.04)

            FailureNumberCard(number: "4", width: height * 0.55,
                              height: height * 0.77, isReward: false)
                .rotationEffect(.degrees(14))
                .offset(x: height * 0.43, y: height * 0.04)

            FailureNumberCard(number: "+3", width: height * 0.63,
                              height: height * 0.86, isReward: true)
                .offset(y: -height * 0.04)
        }
        .frame(width: height * 1.8, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct FailureNumberCard: View {
    let number: String
    let width: CGFloat
    let height: CGFloat
    let isReward: Bool

    private var corner: CGFloat { width * 0.07 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Paper.pageStack)
                .offset(y: height * 0.026)
            RoundedRectangle(cornerRadius: corner)
                .fill(Paper.pageEdge)
                .offset(y: height * 0.013)

            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(
                    colors: [Color(hex: 0xF8F4E8), Paper.page],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay {
                    FailureArtworkGrain(width: width, height: height, opacity: 0.08)
                }
                .compositingGroup()
                .clipShape(.rect(cornerRadius: corner))
                .overlay {
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(Paper.rule.opacity(0.65), lineWidth: 0.7)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: corner * 0.6)
                        .strokeBorder(Paper.rule.opacity(0.28), lineWidth: 0.6)
                        .padding(width * 0.085)
                }

            Text(verbatim: number)
                .font(.custom("Georgia-Bold", fixedSize: height * (isReward ? 0.50 : 0.45)))
                .foregroundStyle(isReward ? Paper.ink : Paper.sageDeep)
                .tracking(isReward ? -height * 0.025 : 0)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, width * 0.08)
                .shadow(color: .white.opacity(0.5), radius: 0, x: 0, y: 0.6)
                .accessibilityHidden(true)
        }
        .frame(width: width, height: height)
        .shadow(color: Paper.ink.opacity(isReward ? 0.17 : 0.11),
                radius: height * 0.04, x: 0, y: height * 0.045)
    }
}

private struct FailureArtworkGrain: View {
    let width: CGFloat
    let height: CGFloat
    let opacity: Double

    var body: some View {
        Image(decorative: "BetweenPuzzlesPaper")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .opacity(opacity)
            .blendMode(.multiply)
    }
}
