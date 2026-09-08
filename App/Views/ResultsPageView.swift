import SwiftUI
import ProbablySudokuEngine

/// The page between a Puzzle and the Shop: what you scored, what it paid, and
/// where the Book goes next.
struct ResultsPageView: View {
    @Bindable var model: GameModel
    var onBookCompletion: () -> Void
    var onAbandon: () -> Void
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let summary = model.bookCompletionSummary {
            BookVictoryPage(summary: summary, board: model.puzzle?.board,
                            bossName: model.puzzle?.boss?.name ?? "The final boss",
                            obstacle: model.run.obstacle, onClose: onBookCompletion)
        } else if isRescueDecision || model.run.outcome == .failed || model.puzzle?.phase == .failed {
            FailureResultsPage(model: model, offersRescue: isRescueDecision, onAbandon: onAbandon)
        } else {
            GeometryReader { proxy in
                successfulResults(availableSize: proxy.size)
            }
        }
    }

    private func successfulResults(availableSize: CGSize) -> some View {
        let compact = availableSize.width < 500
        return ViewThatFits(in: .vertical) {
            resultsColumn(availableSize: availableSize, compact: compact)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.vertical) {
                resultsColumn(availableSize: availableSize, compact: compact)
            }
        }
    }

    private func resultsColumn(availableSize: CGSize, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 11 : 16) {
            header

            // The receipt stays attached to the score; this bounded gap is
            // deliberate white space, never a flexible hole in the page.
            Color.clear.frame(height: compact ? 6 : 24)

            playedBoardPreview(availableSize: availableSize)

            if let payout = model.lastPayout ?? (didWin ? model.payoutPreview : nil) {
                payoutBlock(payout, compact: compact)
            }

            if model.puzzle?.canKeepFilling == true {
                Text("Keep Filling freezes the score, but every clear banks coins.")
                    .font(Print.body(12))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
        .frame(maxWidth: 560, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.bottom, compact ? 12 : 0)
    }

    /// A real, read-only board makes this a record of the player's win, not
    /// an empty receipt. The enclosing column scrolls only when it needs to.
    @ViewBuilder
    private func playedBoardPreview(availableSize: CGSize) -> some View {
        let compact = availableSize.width < 500
        if let board = model.puzzle?.board {
            let compactHeightCap = dynamicTypeSize.isAccessibilitySize
                ? 160
                : max(180, min(220, availableSize.height * 0.30))
            let side = min(compact ? compactHeightCap : 420,
                           max(120, availableSize.width - 36),
                           max(120, availableSize.height * (compact ? 0.30 : 0.35)))
            VStack(spacing: compact ? 4 : 6) {
                Text(board.isFull ? "FULL CLEAR" : "TARGET MET")
                    .font(Print.caption(compact ? 12 : 16))
                    .tracking(1)
                    .foregroundStyle(bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay {
                        Rectangle().strokeBorder(bookTheme.quietInk(onDarkPaper: theme.paper.isDark),
                                                 lineWidth: 1.5)
                    }
                    .rotationEffect(.degrees(-3))
                    .padding(.bottom, 6)
                    .accessibilityHidden(true)
                VictoryBoardPrint(board: board)
                    .frame(width: side, height: side)
                    .overlay { Rectangle().stroke(theme.paper.ruleInk, lineWidth: 1) }
                Text(board.isFull ? "Board complete" : "Target met · Your board, as played")
                    .font(Print.caption(compact ? 10 : 11))
                    .foregroundStyle(theme.paper.softInk)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(board.isFull
                                ? "Board complete. Read-only board as played."
                                : "Target met. Your board, as played. Read-only board thumbnail.")
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
        if model.run.outcome == .bookCompleted {
            PaperButton(title: "Close the Book", subtitle: "See your finished volume", kind: .primary,
                        action: onBookCompletion)
        } else if model.run.outcome != nil {
            PaperButton(title: "New Book", kind: .primary, action: onAbandon)
        } else if model.puzzle?.phase == .won {
            HStack(spacing: 10) {
                if model.puzzle?.canKeepFilling == true {
                    PaperButton(title: "Keep Filling",
                                subtitle: "\(model.puzzle?.turnsRemaining ?? 0) turns left",
                                kind: .quiet) {
                        Task {
                            await flipper.flip(from: model, reduceMotion: reduceMotion) {
                                model.keepFilling()
                            }
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
            return "All 9 levels cleared. This Book is complete."
        case .failed:
            return "The target was not met. Bookmarks, Markers and Buffs do not carry over."
        case nil:
            guard model.puzzle?.phase == .won else { return "Banked and ready for the next page." }
            if model.puzzle?.board.isFull == true { return "Board complete. Cash out your earned coins." }
            return model.puzzle?.canKeepFilling == true
                ? "Target met. Bank it, or play on with the Turns you have left."
                : "Target met. Cash out your earned coins."
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

    @ViewBuilder
    private func payoutBlock(_ payout: RunState.Payout, compact: Bool) -> some View {
        if compact {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Total")
                        .font(Print.body(13))
                        .foregroundStyle(theme.paper.softInk)
                    Spacer(minLength: 8)
                    Text("+\(payout.total)")
                        .font(Print.numeral(20, weight: .bold))
                        .foregroundStyle(theme.paper.ink)
                    Text("coins")
                        .font(Print.caption(11))
                        .foregroundStyle(theme.paper.softInk)
                }
                let details = payoutDetails(payout)
                if !details.isEmpty {
                    Text(details)
                        .font(Print.caption(10.5))
                        .foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(theme.paper.warm.opacity(0.72), in: .rect(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(theme.paper.ruleInk, lineWidth: 1) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coins earned, \(payout.total). \(payoutDetails(payout))")
        } else {
            payoutLines(payout)
        }
    }

    private func payoutDetails(_ payout: RunState.Payout) -> String {
        var details = ["Base +\(payout.base)"]
        if payout.unusedTurns > 0 { details.append("Unused turns +\(payout.unusedTurns)") }
        if payout.keepFillingBank > 0 { details.append("Kept filling +\(payout.keepFillingBank)") }
        if payout.interest > 0 { details.append("Interest +\(payout.interest)") }
        if payout.paperRoute > 0 { details.append("Paper Route +\(payout.paperRoute)") }
        return details.joined(separator: " · ")
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
