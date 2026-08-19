import SwiftUI
import NumberClubEngine

/// The page between a Puzzle and the Shop: what you scored, what it paid, and
/// where the Book goes next.
struct ResultsPageView: View {
    @Bindable var model: GameModel
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            actions
        }
    }

    private var didWin: Bool {
        guard let phase = model.puzzle?.phase else { return model.lastPayout != nil }
        return phase != .failed
    }

    /// §7 — target met means a choice: bank it, or play on for coins.
    @ViewBuilder
    private var actions: some View {
        if model.run.outcome != nil {
            PaperButton(title: "New Book", kind: .primary) { model.exitToMenu() }
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
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Paper.rule).frame(height: 1)

            if let puzzle = model.puzzle {
                HStack {
                    RollingNumber(value: puzzle.score, size: 38, weight: .black,
                                  color: didWin ? Paper.ink : Paper.redPencil)
                    Text("/ \(puzzle.target.formatted())")
                        .font(Print.numeral(17, weight: .semibold))
                        .foregroundStyle(Paper.inkFaint)
                    Spacer()
                }
            }
        }
    }

    private var title: String {
        switch model.run.outcome {
        case .bookCompleted: return "Book Complete"
        case .failed: return "Book Over"
        case nil: return model.puzzle?.phase == .failed ? "Puzzle Failed" : "Puzzle Complete"
        }
    }

    private var subtitle: String {
        switch model.run.outcome {
        case .bookCompleted:
            return "You finished all 27 Puzzles. Choose a harder Book to begin."
        case .failed:
            return "The target was not met. Bookmarks, Markers and Buffs do not carry over."
        case nil:
            return model.puzzle?.phase == .won
                ? "Target met. Bank it, or play on with the Turns you have left."
                : "Banked and on to the Shop."
        }
    }

    private func payoutLines(_ payout: RunState.Payout) -> some View {
        VStack(spacing: 7) {
            line("Base", payout.base)
            if payout.unusedTurns > 0 { line("Unused Turns", payout.unusedTurns) }
            if payout.keepFillingBank > 0 { line("Kept filling", payout.keepFillingBank) }
            if payout.interest > 0 { line("Interest", payout.interest) }
            if payout.paperRoute > 0 { line("Paper Route", payout.paperRoute) }
            Rectangle().fill(Paper.rule).frame(height: 1).padding(.vertical, 2)
            line("Total", payout.total, bold: true)
        }
    }

    private func line(_ label: String, _ amount: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? Print.subheading(14) : Print.body(13))
                .foregroundStyle(bold ? Paper.ink : Paper.inkSoft)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 13, height: 13)
                Text("\(amount)")
                    .font(Print.numeral(bold ? 17 : 14, weight: bold ? .bold : .medium))
                    .foregroundStyle(Paper.ink)
            }
        }
    }
}
