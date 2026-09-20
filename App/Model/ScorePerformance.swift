import Foundation
import ProbablySudokuEngine

/// One coherent engine calculation for the live HUD. A placement receipt may
/// still be printing, but it must never pair an old Points value with a new
/// Mult or independently round the displayed product.
struct LiveScoreCalculation: Equatable {
    let points: Int
    let multiplier: Double
    let total: Int
    let scoreLimitApplied: Bool
    var eligiblePoints: Int? = nil
    var eligibleMultiplier: Double? = nil
    var ineligibleMultiplier: Double? = nil
    var bossSettlement: BossBankSettlement? = nil

    var factors: [String] {
        if let eligiblePoints, let eligibleMultiplier, let ineligibleMultiplier,
           eligiblePoints > 0, eligiblePoints < points, eligibleMultiplier != ineligibleMultiplier {
            return ["\(eligiblePoints.formatted()) × \(ScorePerformance.number(eligibleMultiplier))",
                    "\((points - eligiblePoints).formatted()) × \(ScorePerformance.number(ineligibleMultiplier))"]
        }
        return ["\(points.formatted()) × \(ScorePerformance.number(multiplier))"]
    }
    /// A post-Mult settlement can differ from the ordinary product. Keep the
    /// compact HUD arithmetic truthful while the complete receipt retains
    /// every item multiplier and carried-score source.
    var settlementFactors: [String]? {
        guard let settlement = bossSettlement else { return nil }
        if settlement.bossID == BossModifier.serialPublisher.rawValue,
           settlement.carryBefore > 0 || settlement.carryAfter > 0 {
            return [ScoreMath.add(settlement.gross, settlement.carryBefore).formatted(),
                    "−\(settlement.carryAfter.formatted()) held"]
        }
        if settlement.gross > settlement.paid {
            return [settlement.gross.formatted(), "−\((settlement.gross - settlement.paid).formatted()) fee"]
        }
        return nil
    }
    var compactFactors: String { settlementFactors?.joined(separator: " ") ?? factors.joined(separator: " + ") }
    var explanation: String {
        let product = factors.joined(separator: " plus ")
        guard let settlement = bossSettlement else { return product }
        if settlement.bossID == BossModifier.serialPublisher.rawValue {
            return product + ". \(settlement.carryBefore) carried in; bank \(settlement.paid), carry \(settlement.carryAfter)."
        }
        return product + ". Rival Column deduction \(settlement.gross - settlement.paid); bank \(settlement.paid)."
    }

    static let empty = Self(points: 0, multiplier: 1, total: 0, scoreLimitApplied: false)
}

extension LiveScoreCalculation {
    init(ledger: ScoreLedger) {
        self.init(points: ledger.points, multiplier: ledger.multiplier, total: ledger.total,
                  scoreLimitApplied: ledger.scoreLimitApplied == true, eligiblePoints: ledger.eligiblePoints,
                  eligibleMultiplier: ledger.eligibleMultiplier, ineligibleMultiplier: ledger.ineligibleMultiplier,
                  bossSettlement: ledger.bossSettlement)
    }

    /// A completed ledger also includes unmultiplied direct bonuses. Keep
    /// those in their named receipts; the HUD's product is the bank operation.
    static func banking(_ ledger: ScoreLedger) -> Self {
        guard let bank = ledger.operations.first(where: { $0.kind == .bank }) else {
            return Self(ledger: ledger)
        }
        let total = ScoreMath.integer(bank.amount)
        return Self(points: ledger.points, multiplier: ledger.multiplier, total: total,
                    scoreLimitApplied: ledger.scoreLimitApplied == true,
                    eligiblePoints: ledger.eligiblePoints, eligibleMultiplier: ledger.eligibleMultiplier,
                    ineligibleMultiplier: ledger.ineligibleMultiplier, bossSettlement: ledger.bossSettlement)
    }
}

/// Ephemeral receipts, never a second scoring system or part of a saved run.
struct ScorePerformance: Identifiable {
    struct Beat: Identifiable {
        enum Kind { case points, multiplier, coins, queued, bank }
        let id = UUID()
        var source: String
        var value: String
        var kind: Kind
        var sourceID: String? = nil
        var sourceInstanceID: String? = nil
        var square: Square? = nil
        var queuedBase: Int? = nil
        var multiplier: Double? = nil
        var bankedScore: Int? = nil
        var operation: ScoreOperation? = nil
        /// The consumed Buff's last visible slot, retained only for its
        /// activation receipt. It is never an inventory item or saved state.
        var sourceInventorySlot: Int? = nil

        var compactValue: String {
            guard let operation else { return value }
            let amount = ScorePerformance.number(operation.amount)
            switch operation.kind {
            case .addPoints: return "+\(amount) Points"
            case .subtractPoints: return "−\(amount) Points"
            case .setBase: return "\(amount) base Points"
            case .settleBank: return "\(ScorePerformance.number(operation.before.points)) → \(ScorePerformance.number(operation.after.points)) score"
            case .multiplyPoints:
                return "×\(amount) \(operation.trigger == .place ? "placement" : "clear") Points"
            case .addMult: return "+\(amount) Mult"
            case .multiplyMult: return "×\(amount) Mult"
            case .zero: return "0 Points"
            case .queue: return "+\(amount) Turn Points"
            case .penalty: return "−\(amount) Turn Points first"
            case .coins: return "\(ScorePerformance.signed(Int(operation.amount))) coins"
            case .directScore: return "+\(amount) score"
            case .bank: return ScorePerformance.signed(Int(operation.amount))
            }
        }
    }

    let id = UUID()
    var beats: [Beat]
    var bankedFrom: Int? = nil
    var finalScore: Int? = nil
    var queuedFrom: Int? = nil
    var multiplierFrom: Double? = nil
    var bankCalculation: LiveScoreCalculation? = nil
    var hidesMarkerSources = false
    var summary: String { feedbackBeats.map { "\($0.source), \($0.compactValue)" }.joined(separator: ". ") }
    /// The live product already reflects base/queue arithmetic. Brief source
    /// feedback highlights actual modifiers and awards without replaying those
    /// internal steps as if they were separate committed totals.
    var feedbackBeats: [Beat] {
        beats.filter { beat in
            if beat.kind == .bank { return true }
            guard let source = beat.sourceID else { return beat.kind == .multiplier }
            if hidesMarkerSources, Catalog.item(source)?.kind == .marker { return false }
            return source != "queue" && !source.hasPrefix("base.")
        }
    }

    static func placement(_ outcome: PlacementOutcome, square: Square,
                          previousScore: Int, finalScore: Int, previousQueue: Int = 0,
                          pendingLedger: ScoreLedger? = nil, committedLedger: ScoreLedger? = nil,
                          hidesMarkerSources: Bool = false) -> Self {
        var beats: [Beat] = []
        var queue = previousQueue
        for receipt in outcome.scoreReceipts {
            if !receipt.operations.isEmpty {
                beats += receipt.operations.map { beat(for: $0, square: square) }
                continue
            }
            let label = receipt.event == .place ? "Number placed"
                : receipt.event == .lineClear ? "Line complete" : "Full board"
            beats.append(Beat(source: label, value: signed(receipt.base), kind: .points,
                              square: receipt.event == .place ? square : nil))
            beats += contributionBeats(receipt.contributions)
            // The resolver's result includes square multipliers, rounding and
            // one-shots. Never invent a running sum from raw hook deltas.
            queue += receipt.points
            beats.append(Beat(source: "Turn points", value: signed(receipt.points), kind: .queued,
                              queuedBase: queue))
        }
        if let turn = outcome.automaticTurn {
            let bank = banking(turn, previousScore: previousScore, finalScore: finalScore,
                               hidesMarkerSources: hidesMarkerSources)
            beats += bank.beats
            return Self(beats: beats, bankedFrom: previousScore, finalScore: finalScore,
                        queuedFrom: previousQueue, multiplierFrom: 1,
                        bankCalculation: bank.bankCalculation, hidesMarkerSources: hidesMarkerSources)
        }
        if let committedLedger,
           let bank = outcome.scoreReceipts.flatMap(\.operations).first(where: { $0.kind == .bank }),
           committedLedger.operations.contains(where: { $0.id == bank.id }) {
            // A Keep Filling Full Clear can settle already-earned Serial
            // carry without ending a Turn or earning new placement Points.
            return Self(beats: beats, bankedFrom: previousScore, finalScore: finalScore,
                        queuedFrom: previousQueue, multiplierFrom: 1,
                        bankCalculation: .banking(committedLedger), hidesMarkerSources: hidesMarkerSources)
        }
        if let pendingLedger, !outcome.scoreReceipts.isEmpty {
            // These are read-only operations from the current exact preview.
            // Standing modifiers are explained once after the placement's
            // local effects; they are not applied again to the saved game.
            beats += multiplierBeats(pendingLedger)
        }
        return Self(beats: beats, queuedFrom: previousQueue, hidesMarkerSources: hidesMarkerSources)
    }

    static func buffActivation(_ buff: OwnedBuff, formerSlot: Int,
                               before: ScoreLedger?, after: ScoreLedger?, hidesMarkerSources: Bool = false) -> Self {
        guard let after else { return Self(beats: []) }
        let beforeSources = Set((before?.operations ?? []).map(\.sourceInstanceID))
        guard !beforeSources.contains(buff.id.uuidString),
              let index = after.operations.firstIndex(where: { $0.sourceInstanceID == buff.id.uuidString }) else {
            // A future placement effect (such as Paper Crane) has no current
            // multiplier operation. Its numeric receipt belongs to that later
            // event; do not invent a multiplier or a current score award here.
            return Self(beats: [])
        }
        var beats = after.operations[index...]
            .filter { $0.kind == .addMult || $0.kind == .multiplyMult }
            .map { beat(for: $0) }
        if let activation = beats.firstIndex(where: { $0.sourceInstanceID == buff.id.uuidString }) {
            beats[activation].sourceInventorySlot = formerSlot
        }
        return Self(beats: beats, hidesMarkerSources: hidesMarkerSources)
    }

    private static func multiplierBeats(_ ledger: ScoreLedger) -> [Beat] {
        ledger.operations.filter { $0.kind == .addMult || $0.kind == .multiplyMult }.map { beat(for: $0) }
    }

    static func banking(_ turn: Actions.TurnResult, previousScore: Int, finalScore: Int,
                        hidesMarkerSources: Bool = false) -> Self {
        guard turn.pointsGained != 0 || turn.scoringLedger?.operations.contains(where: {
            $0.kind == .subtractPoints || $0.kind == .settleBank
        }) == true else { return Self(beats: []) }
        var beats = [Beat(source: "Turn points", value: turn.queuedBase.formatted(), kind: .points, queuedBase: turn.queuedBase, multiplier: 1)]
        if let ledger = turn.scoringLedger {
            beats += ledger.operations.filter {
                $0.trigger == .turnEnd && ($0.kind == .addMult || $0.kind == .multiplyMult || $0.kind == .subtractPoints || $0.kind == .settleBank || $0.kind == .bank || $0.kind == .directScore || $0.kind == .coins)
            }.map { beat(for: $0) }
        } else {
            if turn.multiplier != 1 {
                beats.append(Beat(source: "Turn multiplier", value: "×\(number(turn.multiplier))", kind: .multiplier, multiplier: turn.multiplier))
            }
            beats += contributionBeats(turn.contributions)
            beats.append(Beat(source: "BANKED", value: signed(turn.pointsGained), kind: .bank,
                              queuedBase: 0, multiplier: 1, bankedScore: finalScore))
        }
        return Self(beats: beats, bankedFrom: previousScore, finalScore: finalScore,
                    queuedFrom: turn.queuedBase, multiplierFrom: 1,
                    bankCalculation: turn.scoringLedger.map(LiveScoreCalculation.banking),
                    hidesMarkerSources: hidesMarkerSources)
    }

    /// Some authoritative actions (Toss and resolving a saved choice) expose
    /// their automatic bank as a persisted ledger instead of a TurnResult.
    static func banking(_ ledger: ScoreLedger, previousScore: Int, finalScore: Int,
                        hidesMarkerSources: Bool = false) -> Self {
        let operations = ledger.operations.filter {
            ($0.trigger == .turnEnd || ($0.trigger == .fullClear && [.settleBank, .bank].contains($0.kind)))
                && [.addMult, .multiplyMult, .subtractPoints, .settleBank, .bank, .directScore, .coins].contains($0.kind)
        }
        return Self(beats: operations.map { beat(for: $0) }, bankedFrom: previousScore,
                    finalScore: finalScore, queuedFrom: ledger.points, multiplierFrom: 1,
                    bankCalculation: .banking(ledger), hidesMarkerSources: hidesMarkerSources)
    }

    private static func contributionBeats(_ contributions: [ScoreContribution]) -> [Beat] {
        contributions.flatMap { contribution -> [Beat] in
            var result: [Beat] = []
            func append(_ value: String, _ kind: Beat.Kind) {
                result.append(Beat(source: contribution.name, value: value, kind: kind,
                                   sourceID: contribution.sourceID, sourceInstanceID: contribution.instanceID))
            }
            if contribution.flat != 0 { append(signed(contribution.flat), .points) }
            if contribution.multAdd != 0 { append("+\(number(contribution.multAdd)) mult", .multiplier) }
            if contribution.multX != 1 { append("×\(number(contribution.multX))", .multiplier) }
            if contribution.directScore != 0 { append(signed(contribution.directScore), .points) }
            if contribution.coins != 0 { append("\(signed(contribution.coins)) coins", .coins) }
            return result
        }
    }

    struct ExplanationLine: Identifiable {
        let id: String
        let source: String
        let operation: String
        let runningTotal: String
    }

    /// Presentation of the saved ledger, never another calculation.
    static func explanation(for ledger: ScoreLedger, hidesMarkerSources: Bool = false) -> [ExplanationLine] {
        ledger.operations.compactMap { op in
            guard !hidesMarkerSources || Catalog.item(op.sourceID)?.kind != .marker else { return nil }
            return ExplanationLine(id: op.id, source: op.sourceName, operation: beat(for: op).value,
                            runningTotal: runningTotal(for: op))
        }
    }

    private static func runningTotal(for op: ScoreOperation) -> String {
        switch op.kind {
        case .addMult, .multiplyMult:
            return "Mult \(number(op.before.mult)) → \(number(op.after.mult))"
        case .bank, .directScore:
            return "Banked \(op.before.score.formatted()) → \(op.after.score.formatted())"
        case .settleBank:
            return "Ordinary bank \(number(op.before.points)) → \(number(op.after.points))"
        case .coins:
            return "Coins \(op.before.coins.formatted()) → \(op.after.coins.formatted())"
        case .penalty:
            return "Queued Points \(number(op.before.points)) → \(number(op.after.points)); banked \(op.before.score.formatted()) → \(op.after.score.formatted())"
        default:
            return "\(op.scope == .event ? "Event" : "Queued") Points \(number(op.before.points)) → \(number(op.after.points))"
        }
    }

    private static func beat(for op: ScoreOperation, square: Square? = nil) -> Beat {
        let value: String
        let kind: Beat.Kind
        switch op.kind {
        case .addPoints: value = "+\(number(op.amount)) → \(number(op.after.points))"; kind = .points
        case .subtractPoints: value = "−\(number(op.amount)) → \(number(op.after.points)) Points"; kind = .points
        case .setBase: value = "Base \(number(op.before.points)) → \(number(op.after.points)) Points"; kind = .points
        case .settleBank: value = "\(number(op.before.points)) → \(number(op.after.points)) score"; kind = .points
        case .multiplyPoints: value = "×\(number(op.amount)) → \(number(op.after.points)) Points"; kind = .points
        case .addMult: value = "+\(number(op.amount)) → ×\(number(op.after.mult))"; kind = .multiplier
        case .multiplyMult: value = "×\(number(op.amount)) → ×\(number(op.after.mult))"; kind = .multiplier
        case .zero: value = "0 Points"; kind = .points
        case .queue: value = "+\(number(op.amount)) → \(number(op.after.points)) Points"; kind = .queued
        case .penalty: value = "−\(number(op.amount)) Turn Points first"; kind = .points
        case .coins: value = "\(signed(Int(op.amount))) coins"; kind = .coins
        case .directScore: value = "+\(number(op.amount)) → \(op.after.score.formatted())"; kind = .points
        case .bank: value = signed(Int(op.amount)); kind = .bank
        }
        return Beat(source: op.kind == .queue ? "Turn points" : op.sourceName, value: value, kind: kind, sourceID: op.sourceID,
                    sourceInstanceID: op.sourceInstanceID,
                    square: op.sourceID == "base.place" || Catalog.item(op.sourceID)?.kind == .marker ? square : nil,
                    queuedBase: op.kind == .queue ? ScoreMath.integer(op.after.points)
                        : op.kind == .bank || op.kind == .directScore ? 0 : nil,
                    multiplier: op.kind == .addMult || op.kind == .multiplyMult ? op.after.mult
                        : op.kind == .bank || op.kind == .directScore ? 1 : nil,
                    bankedScore: op.kind == .bank || op.kind == .directScore ? op.after.score : nil,
                    operation: op)
    }

    private static func signed(_ value: Int) -> String { value >= 0 ? "+\(value.formatted())" : value.formatted() }
    /// Retained duplicate builds with five quarter-step Bookmark factors and
    /// the boss's half factor can produce eleven fractional digits. Preserve them so the printed
    /// multiplication agrees with the engine's final, once-only rounding.
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...11)))
    }
}
