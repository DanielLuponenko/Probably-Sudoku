import SwiftUI
import ProbablySudokuEngine

/// The same engine ledger used by the live receipt, retained after banking.
struct ScoreLedgerSlip: View {
    @ScaledMetric(relativeTo: .headline) private var calculationSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var explanationSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var sourceSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var operationSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var detailSize: CGFloat = 12
    let ledger: ScoreLedger
    var isPreview = false
    var hidesMarkerSources = false
    var onClose: () -> Void

    var body: some View {
        PaperSlip(title: "Turn \(ledger.turnNumber) \(isPreview ? "preview" : "score")", subtitle: "Every step, in order",
                  closeLabel: "Close", maximumWidth: 560, onClose: onClose) {
            VStack(alignment: .leading, spacing: 16) {
                if ledger.version < 2 {
                    Text("This saved Turn uses the previous scoring rules. Ordered scoring starts on the next Turn.")
                        .font(Print.body(explanationSize))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(LiveScoreCalculation(ledger: ledger).factors.joined(separator: " + "))
                    .font(Print.numeral(calculationSize, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(isPreview ? "\(ledger.total.formatted()) points this turn. End-turn bonuses are added when you bank." : "\(ledger.total.formatted()) total points, including direct bonuses")
                    .font(Print.body(explanationSize))
                    .fixedSize(horizontal: false, vertical: true)
                if let settlement = ledger.bossSettlement {
                    Text(settlement.bossID == BossModifier.serialPublisher.rawValue
                         ? "\(settlement.gross.formatted()) ordinary score + \(settlement.carryBefore.formatted()) carried. Bank \(settlement.paid.formatted()); \(settlement.carryAfter.formatted()) carries forward. Full Clear releases it all."
                         : "Ordinary bank \(settlement.gross.formatted()). Previous benchmark \((settlement.benchmark ?? 0).formatted()). Rival Column deducts \((settlement.gross - settlement.paid).formatted()).")
                        .font(Print.body(explanationSize))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("score.boss-settlement")
                }
                if ledger.scoreLimitApplied == true {
                    Text(isPreview
                         ? "Score limit reached. Only \(ledger.total.formatted()) points can be added at End Turn."
                         : "Score limit reached. This receipt shows the points actually added; your saved score is preserved.")
                        .font(Print.body(explanationSize))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("score.limit-explanation")
                }
                ForEach(ScorePerformance.explanation(for: ledger, hidesMarkerSources: hidesMarkerSources)) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline) {
                                source(line).fixedSize()
                                Spacer(minLength: 8)
                                operation(line).fixedSize()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                source(line)
                                operation(line)
                            }
                        }
                        Text(line.runningTotal).font(Print.body(detailSize))
                            .foregroundStyle(GameplaySurface.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    Divider().overlay(GameplaySurface.sage.opacity(0.3))
                }
                Text("Points queue during the Turn. Mult resolves in the locked Bookmark order. Coins stay separate.")
                    .font(Print.body(detailSize))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(GameplaySurface.ink)
            .accessibilityIdentifier("score.ledger")
        }
    }

    private func source(_ line: ScorePerformance.ExplanationLine) -> some View {
        Text(line.source)
            .font(Print.caption(sourceSize))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func operation(_ line: ScorePerformance.ExplanationLine) -> some View {
        Text(line.operation)
            .font(Print.numeral(operationSize, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
    }
}
