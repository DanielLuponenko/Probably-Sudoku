import SwiftUI
import ProbablySudokuEngine

/// The failure page owns presentation only. The engine still owns eligibility,
/// and only Google's earned callback can change the saved turn allowance.
struct FailureResultsPage: View {
    let model: GameModel
    let offersRescue: Bool
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let ads = RewardedAdService.shared
    @State private var loadRequest = 0

    var body: some View {
        GeometryReader { geometry in
            // Bound the decision to the actual sheet, not the text's ideal
            // height. Otherwise a large-text page can expand the enclosing book
            // and the scroll view never realizes its contents are offscreen.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView { content(compact: true) }
                } else {
                    ViewThatFits(in: .vertical) {
                        content(compact: false).fixedSize(horizontal: false, vertical: true)
                        content(compact: true).fixedSize(horizontal: false, vertical: true)
                        ScrollView { content(compact: true) }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { FailurePaperTexture(opacity: 0.15).padding(-14) }
        // Declining keeps this page mounted for its terminal design, but must
        // still cancel a pending consent/ad request from the rescue offer.
        .task(id: offersRescue ? loadRequest : -1) {
            guard offersRescue, model.canOfferRewardedRescue, scenePhase == .active else { return }
            await ads.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
            if offersRescue, phase == .active, ads.state == .idle { loadRequest += 1 }
        }
    }

    private func content(compact: Bool) -> some View {
        FailurePageContents(score: model.puzzle?.score ?? 0,
                            target: model.puzzle?.target ?? 0,
                            offersRescue: offersRescue,
                            adState: ads.state,
                            canWatchAd: buttonEnabled,
                            isBusy: model.hasRewardedRescueInFlight,
                            compact: compact,
                            onWatchAd: watchAd,
                            onEndBook: endBook)
    }

    private var buttonEnabled: Bool {
        guard model.canOfferRewardedRescue, !model.hasRewardedRescueInFlight,
              scenePhase == .active else { return false }
        switch ads.state {
        case .idle, .ready, .unavailable: return true
        case .preparing, .presenting: return false
        }
    }

    private func endBook() {
        if offersRescue { model.declineRewardedRescue() }
        else { model.abandonRun() }
    }

    private func watchAd() {
        if ads.isReady { presentAd() }
        else { loadRequest += 1 }
    }

    private func presentAd() {
        guard let ticket = model.beginRewardedRescue() else { return }
        let presented = ads.present(onReward: {
            model.receiveRewardedRescue(ticket)
        }, onDismiss: {
            guard model.hasEarnedRewardedRescue(ticket) else {
                model.finishRewardedRescue(ticket)
                return
            }
            Task { @MainActor in
                await flipper.flip(from: model, reduceMotion: reduceMotion) {
                    model.finishRewardedRescue(ticket)
                }
                // A cancelled/backgrounded curl cannot take away earned turns.
                model.finishRewardedRescue(ticket)
            }
        })
        if !presented { model.finishRewardedRescue(ticket) }
    }
}

/// Pure printed content: previews and render tests never initialize the SDK.
struct FailurePageContents: View {
    let score: Int
    let target: Int
    let offersRescue: Bool
    let adState: RewardedAdService.State
    let canWatchAd: Bool
    let isBusy: Bool
    var compact = false
    var onWatchAd: () -> Void = {}
    var onEndBook: () -> Void = {}
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        VStack(spacing: 0) {
            FailureMedallion(symbol: offersRescue ? "hourglass" : "book.closed",
                             size: compact ? 48 : 62)
                .padding(.bottom, compact ? 6 : 8)

            Text(offersRescue ? "Out of turns" : "Book over")
                .font(Print.heading((compact ? 29 : 33) * textScale))
                .tracking(-0.65)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("failure.heading")
            Text(offersRescue ? "A few more moves?" : "Not every book ends on a win.")
                .font(Print.body((compact ? 16 : 18) * textScale))
                .foregroundStyle(theme.paper.softInk)
                .padding(.top, 6)

            FailureScorePanel(score: score, target: target, compact: compact)
                .padding(.horizontal, 14)
                .padding(.top, compact ? 10 : 14)

            FailurePageRule()
                .padding(.horizontal, 10)
                .padding(.vertical, compact ? 10 : 12)

            if offersRescue {
                RescueCardFan(height: compact ? 80 : 102)
                Text("Keep this puzzle going")
                    .font(Print.subheading((compact ? 21 : 23) * textScale))
                    .tracking(-0.45)
                    .padding(.top, compact ? 10 : 12)
                Text("Watch an ad for 3 extra turns.\nYour board, score and hand stay the same.")
                    .font(Print.body((compact ? 14 : 15) * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .padding(.top, 6)

                FailurePageButton(title: buttonTitle, symbol: "play.rectangle",
                                  primary: true, isEnabled: canWatchAd,
                                  compact: compact, action: onWatchAd)
                    .accessibilityLabel(adState == .ready ? "Watch an ad for three extra turns" : buttonTitle)
                    .accessibilityHint("Only a completed ad earns the extra turns. You can end the book without watching.")
                    .accessibilityIdentifier("failure.watchAd")
                    .padding(.top, compact ? 14 : 18)

                Text("Optional · Once per puzzle")
                    .font(Print.body(12.5 * textScale))
                    .foregroundStyle(FailurePageButton.oliveInk)
                    .padding(.top, 9)
                Text(statusText)
                    .font(Print.body(11 * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .accessibilityIdentifier("failure.adStatus")
                    .padding(.top, 4)

                FailurePageButton(title: "End book", primary: false,
                                  isEnabled: !isBusy, compact: compact, action: onEndBook)
                    .accessibilityIdentifier("failure.endBook")
                    .padding(.top, compact ? 12 : 14)
                Text("Finish this attempt without an ad.")
                    .font(Print.body(12 * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .padding(.top, 7)
            } else {
                FailureLastPageNote()
                    .padding(.vertical, compact ? 4 : 14)
                Text("A fresh page is waiting.")
                    .font(Print.subheading(23 * textScale))
                    .padding(.top, 16)
                Text("This attempt is over.\nChoose a book and try again.")
                    .font(Print.body(15 * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .padding(.top, 8)
                FailurePageButton(title: "New book", primary: true,
                                  isEnabled: !isBusy, compact: compact, action: onEndBook)
                    .accessibilityIdentifier("failure.newBook")
                    .padding(.top, 28)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(theme.paper.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
        .padding(.vertical, compact ? 6 : 4)
    }

    private var buttonTitle: String {
        switch adState {
        case .ready: return "Watch ad · +3 turns"
        case .preparing: return "Loading ad…"
        case .presenting: return "Ad in progress"
        case .idle: return "Load ad · +3 turns"
        case .unavailable: return "Try loading again"
        }
    }

    private var statusText: String {
        switch adState {
        case .unavailable: return "No ad available. Try again or end this book."
        case .preparing: return "Getting your optional test ad ready."
        default: return "Test ad · no purchases or ad clicks required."
        }
    }
}

private struct FailureScorePanel: View {
    let score: Int
    let target: Int
    let compact: Bool
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        HStack(spacing: 0) {
            scoreColumn("YOUR SCORE", value: score)
            Rectangle().fill(theme.paper.ruleInk.opacity(0.8)).frame(width: 0.8)
                .padding(.vertical, 10)
            scoreColumn("TARGET", value: target)
        }
        .frame(height: (compact ? 76 : 88) * textScale)
        .background(theme.paper.warm.opacity(0.4), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.paper.ruleInk, lineWidth: 0.8)
            RoundedRectangle(cornerRadius: 9)
                .inset(by: 1.5).strokeBorder(.white.opacity(0.65), lineWidth: 0.7)
        }
    }

    private func scoreColumn(_ title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(title).font(Print.caption(11 * textScale))
                .foregroundStyle(theme.paper.softInk)
            Text(value, format: .number)
                .font(.system(size: (compact ? 32 : 36) * textScale, weight: .medium, design: .serif))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title == "TARGET" ? "Target" : "Your score")
        .accessibilityValue(value.formatted())
    }
}

private struct FailurePageRule: View {
    @Environment(\.cosmeticTheme) private var theme
    var body: some View {
        HStack(spacing: 5) {
            Rectangle().frame(height: 0.8)
            Rectangle().frame(width: 7, height: 7).rotationEffect(.degrees(45))
            Rectangle().frame(height: 0.8)
        }
        .foregroundStyle(theme.paper.ruleInk)
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

private struct FailurePageButton: View {
    static let oliveInk = Color(hex: 0x4F5D43)
    let title: String
    var symbol: String? = nil
    let primary: Bool
    let isEnabled: Bool
    let compact: Bool
    var action: () -> Void
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 25 * textScale, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(title).font(Print.subheading((compact ? 20 : 22) * textScale))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: compact ? 50 : (primary ? 60 : 52))
            .foregroundStyle(primary ? Paper.page : theme.paper.ink)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(primary ? Self.oliveInk : theme.paper.page.opacity(0.35))
                    .overlay {
                        if primary {
                            LinearGradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.16)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                            FailurePaperTexture(opacity: 0.13)
                        }
                    }
                    .compositingGroup()
                    .clipShape(.rect(cornerRadius: 9))
                    .shadow(color: .black.opacity(primary ? 0.2 : 0), radius: 3, x: 0, y: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(primary ? Self.oliveInk : theme.paper.ruleInk, lineWidth: 1.2)
                RoundedRectangle(cornerRadius: 7).inset(by: 3)
                    .strokeBorder(.white.opacity(primary ? 0.3 : 0.5), lineWidth: 0.65)
            }
            .contentShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

private struct FailureLastPageNote: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("THE END").font(.system(size: 29, weight: .bold, design: .serif))
            Text("(for now)").font(Print.handwritten(19))
        }
        .foregroundStyle(Paper.ink)
        .frame(width: 170, height: 112)
        .background(Paper.page, in: .rect(cornerRadius: 3))
        .overlay { FailurePaperTexture(opacity: 0.22) }
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Paper.rule, lineWidth: 0.7) }
        .shadow(color: Paper.deskDark.opacity(0.2), radius: 3, x: 1, y: 4)
        .rotationEffect(.degrees(-4))
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }
}

private struct FailurePaperTexture: View {
    var opacity: Double
    var body: some View {
        GeometryReader { geometry in
            Image(decorative: "BetweenPuzzlesPaper").resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .opacity(opacity)
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
