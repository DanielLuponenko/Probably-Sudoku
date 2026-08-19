import SwiftUI
import NumberClubEngine

/// The page between a Puzzle and the Shop: what you scored, what it paid, and
/// where the Book goes next.
struct ResultsPageView: View {
    @Bindable var model: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let payout = model.lastPayout {
                payoutLines(payout)
            }

            Spacer(minLength: 0)

            if model.run.outcome == nil {
                PaperButton(title: "Continue", subtitle: "To the Shop", kind: .primary) {
                    model.openShop()
                }
            } else {
                PaperButton(title: "New Book", kind: .primary) { model.startNewBook() }
            }
        }
    }

    private var didWin: Bool {
        model.puzzle?.phase == .cashedOut || model.lastPayout != nil
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
                    Text(puzzle.score.formatted())
                        .font(Print.numeral(38, weight: .black))
                        .foregroundStyle(didWin ? Paper.ink : Paper.redPencil)
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
        case nil: return "Puzzle Complete"
        }
    }

    private var subtitle: String {
        switch model.run.outcome {
        case .bookCompleted:
            return "You finished all 27 Puzzles. Choose a harder Book to begin."
        case .failed:
            return "The target was not met. Ads, Markers and Buffs do not carry over."
        case nil:
            return "Banked and on to the Shop."
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

/// §7 — the choice the moment the target is met.
struct WonOverlay: View {
    @Bindable var model: GameModel
    var puzzle: PuzzleState

    var body: some View {
        VStack(spacing: 14) {
            Text("Target Met").pageHeading(26)
            Text("Cash out now, or keep filling with your \(puzzle.turnsRemaining) remaining Turns. "
                 + "Score stops, but every clear banks coins.")
                .font(Print.body(13))
                .foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                PaperButton(title: "Keep Filling", kind: .quiet,
                            isEnabled: puzzle.turnsRemaining > 0) { model.keepFilling() }
                PaperButton(title: "Cash Out", kind: .primary) { model.cashOut() }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Paper.page)
                .overlay { PaperGrain(opacity: 0.05) }
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        }
        .padding(24)
    }
}
