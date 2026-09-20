import SwiftUI
import UIKit
import ProbablySudokuEngine

/// A fixed HUD allocation: receipts and changing numbers never resize the board.
struct GameplayScorePanel: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var model: GameModel
    var puzzle: PuzzleState
    var compact: Bool
    @State private var showingLedger = false
    @State private var inspectedLedger: ScoreLedger?
    @State private var inspectionIsPreview = true
    @State private var inspectionHidesMarkers = false
    @Namespace private var scoreSpace
    @State private var scoreFrames: [String: CGRect] = [:]
    @State private var lastVisibleGain: ScoreGainOrigin?
    @State private var flight: ScoreGainFlight?
    @State private var flightProgress: CGFloat = 0

    private var tight: Bool { compact || dynamicTypeSize.isAccessibilitySize }
    private var displayedScore: Int { model.presentedScore ?? puzzle.score }
    private var calculation: LiveScoreCalculation { model.liveScoreCalculation }
    private var multiplierText: String { ScorePerformance.number(calculation.multiplier) }
    private var factorsText: String { calculation.compactFactors }
    private var resultText: String { "+\(calculation.total.formatted())" }
    private var frozen: Bool { puzzle.phase == .keepFilling }
    private var hasCalculation: Bool { calculation.points != 0 || calculation.total != 0 }
    private var scoreAccessibilityLabel: String {
        let banked = "Score, \(displayedScore). Target, \(puzzle.target)."
        if frozen { return banked + " Score frozen." }
        guard hasCalculation else { return banked }
        return banked + " \(calculation.total) points this turn, from \(calculation.explanation)\(calculation.scoreLimitApplied ? ", score limit applied" : "")."
    }

    private func printedWidth(_ text: String, size: CGFloat, weight: UIFont.Weight = .medium) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)]).width
    }

    private var previewLedger: ScoreLedger {
        var ledger = puzzle.pendingScoringLedger
        ledger.operations = puzzle.turnScoringOperations + ledger.operations
        return ledger
    }

    var body: some View {
        GeometryReader { proxy in
            if dynamicTypeSize.isAccessibilitySize, hasBossChoice, let boss = puzzle.boss {
                accessibleChoicePanel(boss: boss)
            } else {
            let numberWidth = max(1, proxy.size.width - 10
                - (puzzle.boss == nil ? 0 : 12 + proxy.size.width * 0.40))
            let stackScore = printedWidth(displayedScore.formatted(), size: (tight ? 28 : 38) * 0.45, weight: .bold)
                + printedWidth("/ \(puzzle.target.formatted())", size: tight ? 14 : 16) + 5 > numberWidth
            let calculationLines = !hasCalculation || frozen ? 1
                : printedWidth(factorsText, size: (tight ? 12 : 13) * 0.8) > numberWidth ? 3
                : printedWidth(resultText, size: (tight ? 21 : 25) * 0.9, weight: .bold)
                    + printedWidth(factorsText, size: (tight ? 12 : 13) * 0.9) + 10 > numberWidth ? 2 : 1
            let dense = stackScore || calculationLines > 1
            let extreme = stackScore && calculationLines == 3
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                    sourceFeedback
                }
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 40 : tight ? (hasBossChoice ? 14 : 16) : 18,
                           alignment: .topLeading)
                HStack(alignment: .top, spacing: 12) {
                    Button(action: inspectScore) {
                        VStack(alignment: .leading, spacing: 0) {
                            bankedScore(stacked: stackScore, dense: dense, extreme: extreme)
                                .background { scoreAnchor("bank") }
                            liveCalculation(lines: calculationLines)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(scoreAccessibilityLabel)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(frozen ? "Score is frozen while filling for coins" : "Shows the turn calculation, step by step")
                    .accessibilityIdentifier("score.preview")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let boss = puzzle.boss { bossLabel(boss, width: proxy.size.width * 0.40) }
                }
            }
            .padding(.horizontal, 5)
            }
        }
        .coordinateSpace(name: scoreSpace)
        .onPreferenceChange(ScoreHUDFrames.self) { scoreFrames = $0 }
        .onPreferenceChange(ScoreGainFrame.self) { origin in
            // Banking empties the calculation before this overlay runs.
            // Retain the actual visible gain, never the new invisible +0.
            if let origin, origin.total > 0 { lastVisibleGain = origin }
        }
        .overlay(alignment: .topLeading) {
            if let flight {
                Text("+\(flight.total.formatted())")
                    .font(Print.numeral(flight.fontSize, weight: .bold))
                    .foregroundStyle(GameplaySurface.sage)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(width: flight.width, alignment: .leading)
                    .scaleEffect(1 - flightProgress * 0.12)
                    .opacity(1 - flightProgress)
                    .position(x: flight.from.x + (flight.to.x - flight.from.x) * flightProgress,
                              y: flight.from.y + (flight.to.y - flight.from.y) * flightProgress)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .task(id: model.scoreBeat?.id) {
            // The award is already committed. This task only moves a visual
            // copy, and cancellation can never award or bank another point.
            flight = nil
            guard !reduceMotion, !frozen, model.scoreBeat?.kind == .bank,
                  let performance = model.scorePerformance,
                  let total = performance.bankCalculation?.total, total > 0,
                  let origin = lastVisibleGain, let to = scoreFrames["bank"] else { return }
            let from = origin.frame
            flightProgress = 0
            flight = ScoreGainFlight(total: total, from: CGPoint(x: from.midX, y: from.midY),
                                     to: CGPoint(x: to.minX + from.width / 2, y: to.midY),
                                     width: from.width, fontSize: origin.fontSize)
            await Task.yield()
            guard !Task.isCancelled, model.scorePerformance?.id == performance.id else { return }
            withAnimation(.easeIn(duration: 0.30)) { flightProgress = 1 }
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            flight = nil
        }
        .onChange(of: reduceMotion) { _, enabled in if enabled { flight = nil } }
        .paperPanel(isPresented: $showingLedger) {
            ScoreLedgerSlip(ledger: inspectedLedger ?? previewLedger,
                            isPreview: inspectionIsPreview,
                            hidesMarkerSources: inspectionHidesMarkers || model.markersAreHidden) { showingLedger = false }
        }
    }

    private func inspectScore() {
        let isBanking = model.scorePerformance?.bankedFrom != nil
        inspectedLedger = isBanking ? puzzle.lastScoringLedger : previewLedger
        inspectionIsPreview = !isBanking
        inspectionHidesMarkers = model.markersAreHidden
        model.cancelClueTargeting()
        showingLedger = true
    }

    @ViewBuilder private var sourceFeedback: some View {
        if let beat = model.scoreBeat {
            if let operation = beat.operation,
               BossScoreReceipt.supports(operation, banked: model.scorePerformance?.bankedFrom != nil) {
                BossScoreReceipt(operation: operation, settlement: puzzle.lastScoringLedger?.bossSettlement,
                                 fontSize: dynamicTypeSize.isAccessibilitySize ? 16 : 13,
                                 consumeEvent: { model.consumeBossVisualEvent("score:\(beat.id.uuidString)") })
                    .accessibilityIdentifier("puzzle.scoreBreakdown")
            } else {
            (Text(beat.source + " · ") + Text(beat.compactValue).bold())
                .font(Print.caption(dynamicTypeSize.isAccessibilitySize ? 16 : 13))
                .foregroundStyle(beat.kind == .coins ? Paper.coinRim : GameplaySurface.sage)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.8)
                .accessibilityLabel("\(beat.source), \(beat.compactValue)")
                .accessibilityIdentifier("puzzle.scoreBreakdown")
            }
        }
    }

    private var targetEntranceKey: String? {
        puzzle.boss == .heavyLifter ? model.bossEntranceID.map { "final-draft:\($0)" } : nil
    }

    @ViewBuilder
    private func bankedScore(stacked: Bool, dense: Bool, extreme: Bool) -> some View {
        if stacked {
            VStack(alignment: .leading, spacing: 0) {
                RollingNumber(value: displayedScore, size: tight ? (extreme ? 16 : 19) : (extreme ? 22 : 26),
                              weight: .bold, color: GameplaySurface.ink)
                    .accessibilityLabel("Score, \(displayedScore)")
                BossTargetNumber(target: puzzle.target, boss: puzzle.boss,
                                 fontSize: tight ? (extreme ? 8 : 10) : 11,
                                 entranceKey: targetEntranceKey, consumeEntrance: model.consumeBossVisualEvent)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(height: tight ? (extreme ? 26 : 33) : (extreme ? 36 : 43), alignment: .topLeading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                RollingNumber(value: displayedScore, size: tight ? (dense ? 22 : 25) : (dense ? 28 : 34),
                              weight: .bold, color: GameplaySurface.ink)
                    .accessibilityLabel("Score, \(displayedScore)")
                BossTargetNumber(target: puzzle.target, boss: puzzle.boss,
                                 fontSize: tight ? 14 : 16,
                                 entranceKey: targetEntranceKey, consumeEntrance: model.consumeBossVisualEvent)
            }
            .lineLimit(1).minimumScaleFactor(0.45)
        }
    }

    @ViewBuilder
    private func liveCalculation(lines: Int) -> some View {
        if frozen {
            Text("Score frozen")
                .font(Print.numeral(tight ? 14 : 16, weight: .medium))
                .foregroundStyle(GameplaySurface.softInk)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if lines == 1 {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        gain(size: tight ? 20 : 23)
                        Text(factorsText).font(Print.numeral(tight ? 12 : 13, weight: .medium))
                    }
                } else {
                    gain(size: lines == 3 ? (tight ? 10 : 12) : (tight ? 16 : 20))
                    if lines == 3, let settlement = calculation.settlementFactors {
                        ForEach(settlement, id: \.self) { Text($0) }
                    } else if calculation.factors.count > 1 && calculation.settlementFactors == nil {
                        ForEach(calculation.factors, id: \.self) { Text($0) }
                    } else if lines == 3 {
                        Text(calculation.points.formatted())
                        Text("× \(multiplierText)")
                    } else { Text(factorsText) }
                }
            }
            .font(Print.numeral(lines == 3 ? (tight ? 9.5 : 11) : (tight ? 11 : 12), weight: .medium))
            .foregroundStyle(GameplaySurface.softInk)
            .lineLimit(1).minimumScaleFactor(0.8)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: calculation)
            .opacity(hasCalculation ? 1 : 0)
            .accessibilityHidden(!hasCalculation)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(calculation.total) points this turn, from \(calculation.explanation)\(calculation.scoreLimitApplied ? ", score limit applied" : "")")
            .accessibilityIdentifier("score.live-calculation")
        }
    }

    private func gain(size: CGFloat) -> some View {
        Text(resultText)
            .font(Print.numeral(size, weight: .bold))
            .foregroundStyle(GameplaySurface.sage)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ScoreGainFrame.self,
                        value: ScoreGainOrigin(total: calculation.total,
                            frame: proxy.frame(in: .named(scoreSpace)), fontSize: size))
                }
            }
    }

    private func scoreAnchor(_ key: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ScoreHUDFrames.self, value: [key: proxy.frame(in: .named(scoreSpace))])
        }
    }

    @ViewBuilder private func bossLabel(_ boss: BossModifier, width: CGFloat) -> some View {
        if boss == .tikTak, let seconds = model.secondsLeft {
            TikTakCountdown(value: TikTakCountdownValue(remaining: seconds,
                                isPaused: !model.isClockRunning), compact: tight)
                .frame(width: width, alignment: .topTrailing)
                .accessibilityHint("Tik Tak. Four minutes of active play.")
        } else {
            VStack(alignment: .trailing, spacing: tight && hasBossChoice ? 0 : 3) {
                Text(boss == .accountant ? "Accountant" : hasBossChoice
                     ? boss.name.replacingOccurrences(of: "The ", with: "", options: .anchored) : boss.name)
                    .font(Print.subheading(tight ? (hasBossChoice ? 13 : 15) : 17))
                    .foregroundStyle(GameplaySurface.ink)
                    .lineLimit(hasBossChoice ? 1 : 2).minimumScaleFactor(0.8)
                    .accessibilityLabel(boss.name)
                if hasBossChoice {
                    bossChoice(boss)
                } else if boss == .chainStitcher {
                    if puzzle.phase == .playing {
                        BossChainLegend(hasAnchor: BossChainProjection(puzzle: puzzle).anchor != nil)
                    } else {
                        Text("Score frozen").font(Print.body(12)).foregroundStyle(GameplaySurface.softInk)
                    }
                } else if BossStatusDiagram.supports(boss) {
                    BossStatusDiagram(puzzle: puzzle)
                } else if boss == .dryPress {
                    BossInkPadStatus(ready: puzzle.bossState.scoring.dryPressReady)
                } else if boss == .reviewBoard {
                    BossReviewApprovalStatus(approved: puzzle.bossState.reviewApproved)
                } else {
                    Text(BossLiveStatus.text(puzzle: puzzle) ?? BossBoardDesign(boss: boss).headerRule(censored: puzzle.censoredDigit,
                                                               turns: puzzle.turnsMax))
                        .font(Print.body(tight ? 11 : 12))
                        .foregroundStyle(GameplaySurface.softInk)
                        .lineLimit(3).minimumScaleFactor(0.85)
                }
            }
            .multilineTextAlignment(.trailing)
            .frame(width: width, alignment: .topTrailing)
            .accessibilityElement(children: hasBossChoice ? .contain : .combine)
            .accessibilityHint(boss.text)
        }
    }


    /// The enlarged choice HUD trades the narrow side column for a full-width
    /// row. Its 108pt budget is constant before and after any choice or score.
    private func accessibleChoicePanel(boss: BossModifier) -> some View {
        VStack(spacing: 4) {
            Button(action: inspectScore) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(displayedScore.formatted()) / \(puzzle.target.formatted())")
                            .font(Print.numeral(17, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.89)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background { scoreAnchor("bank") }
                        Text(boss.name.replacingOccurrences(of: "The ", with: "", options: .anchored))
                            .font(Print.subheading(18))
                            .lineLimit(1).minimumScaleFactor(0.9)
                            .layoutPriority(1)
                    }
                    if let beat = model.scoreBeat {
                        Text("\(beat.source) · \(beat.compactValue)")
                            .font(Print.caption(15))
                            .foregroundStyle(GameplaySurface.sage)
                            .lineLimit(1)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if !frozen { gain(size: 18) }
                            Text(frozen ? "Score frozen" : factorsText)
                                .font(Print.numeral(15, weight: .medium))
                                .foregroundStyle(GameplaySurface.softInk)
                                .lineLimit(1)
                        }
                        .opacity(hasCalculation || frozen ? 1 : 0)
                    }
                }
                .foregroundStyle(GameplaySurface.ink)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(boss.name). \(scoreAccessibilityLabel)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows the turn calculation, step by step")
            .accessibilityIdentifier("score.preview")
            bossChoice(boss)
                .frame(height: 60)
        }
        .padding(.horizontal, 5)
    }

    @ViewBuilder private func bossChoice(_ boss: BossModifier) -> some View {
        if boss == .collateral {
            let card = model.selectedHandIndex.flatMap { index in
                puzzle.handCards.indices.contains(index) ? puzzle.handCards[index] : nil
            }
            let context = model.bossChoiceContext
            BossCollateralEnvelope(selectedDigit: card?.digit.rawValue,
                pledgedDigit: puzzle.bossState.encounter.pledgedCard?.digit.rawValue,
                multBonus: Int(BossEncounterRules.collateralMultBonus),
                canPledge: model.acceptsPuzzleInput && card.map {
                    BossEncounterRules.canPledge(cardID: $0.id, run: model.run)
                } == true,
                isPreparationOpen: puzzle.phase == .playing && !puzzle.bossState.encounter.turnCommitted) {
                    if let card, let context { model.pledgeBossCard(card.id, context: context) }
                }
        } else if boss == .splitEdition {
            let context = model.bossChoiceContext
            BossSplitEditionStacks(scores: puzzle.bossState.encounter.editionScores,
                targets: puzzle.bossState.encounter.editionTargets,
                selected: puzzle.bossState.encounter.selectedEdition,
                canSelect: model.acceptsPuzzleInput && BossEncounterRules.canChooseEdition(run: model.run)) { edition in
                    if let context { model.chooseBossEdition(edition, context: context) }
                }
        } else if boss == .lastEdition {
            BossLastEditionPress(banksRemaining: max(0, 1 - puzzle.bossState.encounter.banksUsed),
                pendingScore: puzzle.bossState.encounter.banksUsed > 0
                    ? (puzzle.lastScoringLedger?.total ?? 0) : puzzle.pendingScoringLedger.total,
                bankEventID: model.scorePerformance?.bankedFrom != nil ? model.scorePerformance?.id : nil)
        }
    }

    private var hasBossChoice: Bool {
        [.collateral, .splitEdition, .lastEdition].contains(puzzle.boss)
    }

}

private struct ScoreGainFlight {
    let total: Int
    let from: CGPoint
    let to: CGPoint
    let width: CGFloat
    let fontSize: CGFloat
}

private struct ScoreGainOrigin: Equatable {
    let total: Int
    let frame: CGRect
    let fontSize: CGFloat
}

private struct ScoreGainFrame: PreferenceKey {
    static var defaultValue: ScoreGainOrigin?
    static func reduce(value: inout ScoreGainOrigin?, nextValue: () -> ScoreGainOrigin?) {
        value = nextValue() ?? value
    }
}

private struct ScoreHUDFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}
