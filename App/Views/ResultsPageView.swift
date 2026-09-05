import SwiftUI
import ProbablySudokuEngine

/// The page between a Puzzle and the Shop: what you scored, what it paid, and
/// where the Book goes next.
struct ResultsPageView: View {
    @Bindable var model: GameModel
    var onBookCompletion: () -> Void
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cosmeticTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Spacer(minLength: 0)

            if let payout = model.lastPayout ?? (didWin ? model.payoutPreview : nil) {
                payoutLines(payout)
            }
            if model.puzzle?.phase == .won {
                Text("Keep Filling freezes the score, but every clear banks coins.")
                    .font(Print.body(12))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isRescueDecision {
                RewardedRescuePanel(model: model)
            }

            Spacer(minLength: 0)

            actions
        }
    }

    private var didWin: Bool {
        guard let phase = model.puzzle?.phase else { return model.lastPayout != nil }
        return phase == .won || phase == .keepFilling || phase == .cashedOut
    }

    private var isRescueDecision: Bool {
        model.puzzle?.phase == .outOfTurns || model.hasRewardedRescueInFlight
    }

    /// §7 — target met means a choice: bank it, or play on for coins.
    @ViewBuilder
    private var actions: some View {
        if isRescueDecision {
            PaperButton(title: "End Book", subtitle: "No ad. Finish this attempt.", kind: .quiet,
                        isEnabled: !model.hasRewardedRescueInFlight) {
                model.declineRewardedRescue()
            }
        } else if model.run.outcome == .bookCompleted {
            PaperButton(title: "Close the Book", subtitle: "See your finished volume", kind: .primary,
                        action: onBookCompletion)
        } else if model.run.outcome != nil {
            PaperButton(title: "New Book", kind: .primary) { model.abandonRun() }
        } else if model.puzzle?.phase == .won {
            HStack(spacing: 10) {
                PaperButton(title: "Keep Filling",
                            subtitle: "\(model.puzzle?.turnsRemaining ?? 0) turns left",
                            kind: .quiet,
                            isEnabled: (model.puzzle?.turnsRemaining ?? 0) > 0) {
                    Task {
                        await flipper.flip(from: model, reduceMotion: reduceMotion) {
                            model.keepFilling()
                        }
                    }
                }
                PaperButton(title: "Cash Out", kind: .primary) {
                    Task {
                        await flipper.flip(from: model, reduceMotion: reduceMotion) {
                            model.cashOut()
                            model.openShop()
                        }
                    }
                }
            }
        } else {
            PaperButton(title: "Continue", subtitle: "To the Shop", kind: .primary) {
                Task {
                    await flipper.flip(from: model, reduceMotion: reduceMotion) { model.openShop() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).pageHeading(34)
            Text(subtitle)
                .font(Print.body(13.5))
                .foregroundStyle(theme.paper.softInk)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(theme.paper.ruleInk).frame(height: 1)

            if let puzzle = model.puzzle {
                HStack {
                    RollingNumber(value: puzzle.score, size: 38, weight: .black,
                                  color: didWin ? theme.paper.ink : Paper.redPencil)
                    Text("/ \(puzzle.target.formatted())")
                        .font(Print.numeral(17, weight: .semibold))
                        .foregroundStyle(theme.paper.faintInk)
                    Spacer()
                }
            }
        }
    }

    private var title: String {
        if isRescueDecision { return "Out of Turns" }
        switch model.run.outcome {
        case .bookCompleted: return "Book Complete"
        case .failed: return "Book Over"
        case nil: return model.puzzle?.phase == .failed ? "Puzzle Failed" : "Puzzle Complete"
        }
    }

    private var subtitle: String {
        if isRescueDecision {
            return "The target is still ahead. Your board and numbers are saved."
        }
        switch model.run.outcome {
        case .bookCompleted:
            return "You finished all 27 Puzzles. Choose a harder Book to begin."
        case .failed:
            return "The target was not met. Bookmarks, Markers and Buffs do not carry over."
        case nil:
            return model.puzzle?.phase == .won
                ? "Target met. Bank it, or play on with the Turns you have left."
                : "Banked and ready for the next page."
        }
    }

    private func payoutLines(_ payout: RunState.Payout) -> some View {
        VStack(spacing: 7) {
            line("Base", payout.base)
            if payout.unusedTurns > 0 { line("Unused Turns", payout.unusedTurns) }
            if payout.keepFillingBank > 0 { line("Kept filling", payout.keepFillingBank) }
            if payout.interest > 0 { line("Interest", payout.interest) }
            if payout.paperRoute > 0 { line("Paper Route", payout.paperRoute) }
            Rectangle().fill(theme.paper.ruleInk).frame(height: 1).padding(.vertical, 2)
            line("Total", payout.total, bold: true)
        }
    }

    private func line(_ label: String, _ amount: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? Print.subheading(14) : Print.body(13))
                .foregroundStyle(bold ? theme.paper.ink : theme.paper.softInk)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 13, height: 13)
                Text("\(amount)")
                    .font(Print.numeral(bold ? 17 : 14, weight: bold ? .bold : .medium))
                    .foregroundStyle(theme.paper.ink)
            }
        }
    }
}

/// An optional second chance, printed on the existing results page. Loading
/// and network failures never prevent the player from ending their Book.
private struct RewardedRescuePanel: View {
    let model: GameModel
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cosmeticTheme) private var theme
    private let ads = RewardedAdService.shared
    @State private var loadRequest = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("A little more time", systemImage: "play.rectangle")
                .font(Print.heading(23))
                .foregroundStyle(theme.paper.ink)
            Text("Watch an ad for 3 extra turns on this Puzzle. Your board, score and Hand stay the same.")
                .font(Print.body(14))
                .foregroundStyle(theme.paper.softInk)
                .fixedSize(horizontal: false, vertical: true)
            PaperButton(title: buttonTitle, subtitle: "Optional · once per Puzzle",
                        kind: .primary, isEnabled: buttonEnabled) {
                if ads.isReady { presentAd() }
                else { loadRequest += 1 }
            }
            .accessibilityLabel(ads.isReady ? "Watch an ad for three extra turns" : buttonTitle)
            .accessibilityHint("Only a completed ad earns the extra turns. You can end the Book without watching.")

            Text(statusText)
                .font(Print.body(12))
                .foregroundStyle(theme.paper.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(theme.paper.warm, in: .rect(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(theme.paper.ruleInk, lineWidth: 1)
        }
        .task(id: loadRequest) {
            guard model.canOfferRewardedRescue, scenePhase == .active else { return }
            await ads.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
            // The first render can precede foreground activation. Retry then,
            // but do not restart a consent decision or an existing load.
            if phase == .active, ads.state == .idle { loadRequest += 1 }
        }
    }

    private var buttonEnabled: Bool {
        guard model.canOfferRewardedRescue, !model.hasRewardedRescueInFlight,
              scenePhase == .active else { return false }
        switch ads.state {
        case .idle, .ready, .unavailable: return true
        case .preparing, .presenting: return false
        }
    }

    private var buttonTitle: String {
        switch ads.state {
        case .ready: return "Watch Ad → +3 Turns"
        case .preparing: return "Loading Ad…"
        case .presenting: return "Ad in Progress"
        case .idle: return "Load Ad"
        case .unavailable: return "Try Loading Again"
        }
    }

    private var statusText: String {
        switch ads.state {
        case .unavailable:
            return "No ad is available right now. You can try again or end this Book."
        case .preparing:
            return "Getting your optional ad ready."
        default:
            return "Test ad · no purchases or ad clicks required."
        }
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
                // If backgrounding cancelled the curl before its first
                // frame, the earned turns still belong to the player.
                model.finishRewardedRescue(ticket)
            }
        })
        if !presented { model.finishRewardedRescue(ticket) }
    }
}
