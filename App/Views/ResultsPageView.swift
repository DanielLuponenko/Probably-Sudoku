import SwiftUI
import ProbablySudokuEngine

/// Allocate a complete square after measuring the receipt and decisions. There
/// is no minimum that can push the ninth row behind the footer.
struct ResultsBoardLayout {
    var available: CGSize
    var headerHeight: CGFloat = 150
    var footerHeight: CGFloat = 80
    var spacing: CGFloat = 8
    var side: CGFloat {
        min(max(0, available.width - 8),
            max(0, available.height - headerHeight - footerHeight - spacing * 2))
    }
}

private struct ResultsScreenLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let column = ProposedViewSize(width: bounds.width, height: nil)
        let header = subviews[0].sizeThatFits(column)
        let footer = subviews[2].sizeThatFits(column)
        let side = ResultsBoardLayout(available: bounds.size, headerHeight: header.height,
                                      footerHeight: footer.height, spacing: spacing).side
        subviews[0].place(at: bounds.origin, proposal: column)
        // Extra space balances the board, rather than creating a large empty
        // gap between the receipt and the player's next decision on iPad.
        let middle = bounds.height - header.height - footer.height
        subviews[1].place(at: CGPoint(x: bounds.midX - side / 2,
                                     y: bounds.minY + header.height + (middle - side) / 2),
                          proposal: ProposedViewSize(width: side, height: side))
        subviews[2].place(at: CGPoint(x: bounds.minX, y: bounds.maxY - footer.height), proposal: column)
    }
}

/// The page between a Puzzle and the Shop: what you scored, what it paid, and
/// where the Book goes next.
struct ResultsPageView: View {
    @Bindable var model: GameModel
    var onBookCompletion: () -> Void
    var onAbandon: () -> Void
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @ScaledMetric(relativeTo: .headline) private var actionLabelSize: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var actionDetailSize: CGFloat = 11
    @State private var showingScoreBreakdown = false

    // Keep the receipt and its decisions readable before allocating the
    // remaining space to the board. The preview can shrink; earned coins and
    // the meaning of Keep Filling must not stay at tiny fixed caption sizes.
    private var detailScale: CGFloat { min(textScale, 1.7) }

    var body: some View {
        if let summary = model.bookCompletionSummary {
            BookVictoryPage(summary: summary, board: model.puzzle?.board,
                            bossName: model.puzzle?.boss?.name ?? "The final boss",
                            obstacle: model.run.obstacle, onClose: onBookCompletion,
                            markers: model.visibleMarkers, puzzle: model.puzzle)
        } else if isRescueDecision || model.run.outcome == .failed || model.puzzle?.phase == .failed {
            FailureResultsPage(model: model, offersRescue: isRescueDecision, onAbandon: onAbandon)
        } else {
            GeometryReader { proxy in
                successfulResults(availableSize: proxy.size)
            }
            .paperPanel(isPresented: $showingScoreBreakdown) {
                if let ledger = model.puzzle?.lastScoringLedger {
                    ScoreLedgerSlip(ledger: ledger) { showingScoreBreakdown = false }
                }
            }
        }
    }

    private func successfulResults(availableSize: CGSize) -> some View {
        let compact = availableSize.width < 500
        return ResultsScreenLayout(spacing: compact ? 8 : 12) {
            header(compact: compact)
            playedBoardPreview
            VStack(spacing: compact ? 7 : 10) {
                Text(model.puzzle?.board.isFull == true ? "Board complete" : "Your board, as played")
                    .font(Print.caption((compact ? 11 : 13) * detailScale))
                    .foregroundStyle(theme.paper.softInk)
                if model.puzzle?.canKeepFilling == true {
                    Text("Keep Filling: frozen score, clears earn coins.")
                        .font(Print.body(12 * detailScale))
                        .foregroundStyle(theme.paper.softInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actions
                    .inventorySaleActionArea()
            }
        }
        .padding(.bottom, compact ? 8 : 0)
        .accessibilityIdentifier("results.single-screen")
    }

    /// The same 81 wells and actual placements as gameplay, sized as one unit
    /// from the space left after the receipt and choices have been measured.
    @ViewBuilder
    private var playedBoardPreview: some View {
        if let board = model.puzzle?.board {
            GameplayBoardSnapshot(board: board, markers: model.visibleMarkers, puzzle: model.puzzle)
        } else {
            Color.clear
        }
    }

    private var resultPayout: RunState.Payout? { model.lastPayout ?? (didWin ? model.payoutPreview : nil) }

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
            decision("Close the Book", subtitle: "See your finished volume", action: onBookCompletion)
        } else if model.run.outcome != nil {
            decision("New Book", action: onAbandon)
        } else if model.puzzle?.phase == .won {
            HStack(spacing: 10) {
                if model.puzzle?.canKeepFilling == true {
                    decision("Keep Filling", subtitle: "\(model.puzzle?.turnsRemaining ?? 0) turns left",
                             primary: false) {
                        Task {
                            await flipper.flip(from: model, reduceMotion: reduceMotion) {
                                model.keepFilling()
                            }
                        }
                    }
                }
                decision("Cash Out") {
                    Task {
                        await flipper.flip(from: model, reduceMotion: reduceMotion) {
                            model.cashOut()
                            model.openShop()
                        }
                    }
                }
            }
        } else {
            decision("Continue", subtitle: "To the Shop") {
                Task {
                    await flipper.flip(from: model, reduceMotion: reduceMotion) { model.openShop() }
                }
            }
        }
    }

    /// These remain full-word, generous touch targets even when the result
    /// shares a short screen with all nine board rows. Only the compact HUD
    /// labels cap their text growth; VoiceOver receives their complete titles.
    private func decision(_ title: String, subtitle: String? = nil, primary: Bool = true,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title.uppercased())
                    .font(Print.subheading(min(actionLabelSize, 24)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let subtitle {
                    Text(subtitle)
                        .font(Print.caption(min(actionDetailSize, 18)))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(primary ? bookTheme.buttonForeground
                             : bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
            .frame(maxWidth: .infinity)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 70 : 56)
            .padding(.horizontal, 8)
            .background(primary ? bookTheme.buttonFill : theme.paper.warm.opacity(0.9),
                        in: .rect(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(bookTheme.accent.opacity(primary ? 0 : 0.7), lineWidth: 1.4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).pageHeading(min((compact ? 28 : 36) * detailScale, compact ? 36 : 44))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !dynamicTypeSize.isAccessibilitySize {
                Text(subtitle)
                    .font(Print.body((compact ? 13 : 16) * detailScale))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(theme.paper.ruleInk).frame(height: 1)

            if let puzzle = model.puzzle {
                HStack {
                    RollingNumber(value: puzzle.score, size: compact ? 32 : 42, weight: .black,
                                  color: didWin ? theme.paper.ink : Paper.redPencil)
                    Text("/ \(puzzle.target.formatted())")
                        .font(Print.numeral(17 * min(detailScale, 1.3), weight: .semibold))
                        .foregroundStyle(theme.paper.faintInk)
                    Spacer()
                    if puzzle.lastScoringLedger != nil {
                        Button { showingScoreBreakdown = true } label: {
                            Image(systemName: "list.number")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(GameplaySurface.sage)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Score breakdown")
                        .accessibilityIdentifier("results.score-breakdown")
                    }
                }
            }
            if let payout = resultPayout {
                payoutBlock(payout, compact: true)
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
            return "\(BossFailureExplanation.text(for: model.puzzle) ?? "The target is still ahead.") Your board and numbers are saved."
        }
        switch model.run.outcome {
        case .bookCompleted:
            return "All 9 levels cleared. This Book is complete."
        case .failed:
            return "\(BossFailureExplanation.text(for: model.puzzle) ?? "The puzzle was not completed.") Bookmarks, Markers and Buffs do not carry over."
        case nil:
            guard model.puzzle?.phase == .won else { return "Banked and ready for the next page." }
            if model.puzzle?.board.isFull == true { return "Board complete. Cash out your earned coins." }
            return model.puzzle?.canKeepFilling == true
                ? "Target met. Bank it, or play on."
                : "Target met. Cash out your earned coins."
        }
    }

    private func payoutLines(_ payout: RunState.Payout) -> some View {
        VStack(spacing: 7) {
            line("Base", payout.base)
            if payout.unusedTurns > 0 { line("Unused Turns", payout.unusedTurns) }
            if payout.keepFillingBank > 0 { line("Kept filling", payout.keepFillingBank) }
            if payout.interest > 0 { line("Interest", payout.interest) }
            if payout.suppressedInterest > 0 {
                CollectorPayoutPrint(details: "", suppressed: payout.suppressedInterest,
                    eventKey: model.bossEntranceID.map { "collector-payout:\($0)" },
                    consume: model.consumeBossVisualEvent)
                    .font(Print.body(13))
            }
            if payout.paperRoute > 0 { line("Paper Route", payout.paperRoute) }
            if payout.earlyDeadline > 0 { line("Early Deadline", payout.earlyDeadline) }
            if payout.stipend > 0 { line("Stipend", payout.stipend) }
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
                        .font(Print.body(13 * detailScale))
                        .foregroundStyle(theme.paper.softInk)
                    Spacer(minLength: 8)
                    Text("+\(payout.total)")
                        .font(Print.numeral(20 * detailScale, weight: .bold))
                        .foregroundStyle(theme.paper.ink)
                    Text("coins")
                        .font(Print.caption(11 * detailScale))
                        .foregroundStyle(theme.paper.softInk)
                }
                let details = payoutDetails(payout)
                if !details.isEmpty {
                    Group {
                        if payout.suppressedInterest > 0 {
                            CollectorPayoutPrint(details: details, suppressed: payout.suppressedInterest,
                                eventKey: model.bossEntranceID.map { "collector-payout:\($0)" },
                                consume: model.consumeBossVisualEvent)
                        } else { Text(details) }
                    }
                        .font(Print.caption(10.5 * detailScale))
                        .foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(theme.paper.warm.opacity(0.72), in: .rect(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(theme.paper.ruleInk, lineWidth: 1) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coins earned, \(payout.total). \(payoutDetails(payout))"
                + (payout.suppressedInterest > 0 ? ". The Collector cancels \(payout.suppressedInterest) interest coins." : ""))
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
        if payout.earlyDeadline > 0 { details.append("Early Deadline +\(payout.earlyDeadline)") }
        if payout.stipend > 0 { details.append("Stipend +\(payout.stipend)") }
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
