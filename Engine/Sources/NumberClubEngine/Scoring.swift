import Foundation

/// Versioned, engine-owned arithmetic. Receipts are values, never commands.
public enum ScoreMath {
    public static let ceiling = 9_000_000_000_000_000
    public static func bounded(_ value: Double) -> Double {
        if value.isNaN || value < 0 { return 0 }
        return min(Double(ceiling), value)
    }
    public static func integer(_ value: Double) -> Int { Int(bounded(value).rounded(.down)) }
    public static func add(_ lhs: Int, _ rhs: Int) -> Int {
        // Preserve old high scores instead of narrowing historical saved data.
        guard lhs <= ceiling else { return lhs }
        return integer(Double(lhs) + Double(rhs))
    }
}

public struct ScoreValues: Codable, Sendable, Equatable {
    public var points: Double = 0
    public var mult: Double = 1
    public var score: Int = 0
    public var coins: Int = 0
}

public struct ScoreOperation: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case addPoints, multiplyPoints, addMult, multiplyMult, zero, queue, penalty, directScore, coins, bank
        case subtractPoints, setBase, settleBank
    }
    public enum Scope: String, Codable, Sendable { case event, turn, economy }
    public var id: String
    public var sourceID: String
    public var sourceInstanceID: String
    public var sourceName: String
    public var trigger: GameEvent
    public var scope: Scope
    public var kind: Kind
    public var amount: Double
    public var before: ScoreValues
    public var after: ScoreValues
}

public struct ScoreLedger: Codable, Sendable, Equatable {
    public var version: Int
    public var turnNumber: Int
    public var operations: [ScoreOperation]
    public var points: Int
    public var multiplier: Double
    public var total: Int
    /// Nil for historical and uncapped receipts. The requested product or a
    /// direct award exceeded the score that could be added to this saved run.
    public var scoreLimitApplied: Bool? = nil
    /// Selective +Mult cannot apply to Clue/other ineligible Points. These
    /// optional values expose both real products rather than claiming one
    /// source's extra Mult applies to the whole queue.
    public var eligiblePoints: Int? = nil
    public var eligibleMultiplier: Double? = nil
    public var ineligibleMultiplier: Double? = nil
    public var bossSettlement: BossBankSettlement? = nil
}

/// Held effects lock at the first correct placement, including their UUID and
/// sleeping identity. Growth samples are saved, so preview never reruns hooks.
public struct TurnScoringState: Codable, Sendable {
    public var bookmarks: [OwnedBookmark]
    public var disabledBookmarkID: UUID?
    public var runState: [String: Double]
    public var observedItemState: [String: Double]
    @StableOptionalMap public var bookmarkCopies: [UUID: BookmarkRunCopyState]? = nil
}

extension PuzzleState {
    public var scoringOrderLocked: Bool { scoringVersion >= 2 && turnScoringState != nil }
    public var scoringBookmarkOrder: [UUID] { turnScoringState?.bookmarks.map(\.id) ?? [] }

    mutating func lockScoringOrder(run: RunState) {
        guard scoringVersion >= 2, turnScoringState == nil else { return }
        turnScoringState = TurnScoringState(bookmarks: BossScoring.physicalOrder(run.bookmarks, puzzle: self),
            disabledBookmarkID: disabledBookmark.flatMap { run.bookmarks.indices.contains($0) ? run.bookmarks[$0].id : nil },
            runState: run.runItemState, observedItemState: itemState,
            bookmarkCopies: run.bookmarkState.copies)
    }

    mutating func observeScoringEvent(_ result: EffectResult) {
        guard scoringVersion >= 2, !result.zeroed else { return }
        turnScoringState?.observedItemState = itemState
    }

    /// This pure preview is also the exact bank calculation. No effects fire.
    public var pendingScoringLedger: ScoreLedger {
        if BossScoring.orphanDebit(self) > 0 {
            var copy = self
            let count = copy.turnScoringOperations.count
            BossScoring.prepareBank(puzzle: &copy)
            var ledger = copy.pendingScoringLedger
            ledger.operations = Array(copy.turnScoringOperations.dropFirst(count)) + ledger.operations
            return ledger
        }
        var values = ScoreValues(points: Double(pendingBase), mult: 1)
        var unqualifiedMult = 1.0
        let qualifiedPoints = BuffRuntime.eligibleQueuedPoints(self)
        var selectiveMult = false
        var operations: [ScoreOperation] = []
        func step(_ source: String, _ instance: String? = nil, _ name: String,
                  _ kind: ScoreOperation.Kind, _ amount: Double, eligibleOnly: Bool = false) {
            let before = values
            switch kind {
            case .addMult:
                values.mult = ScoreMath.bounded(values.mult + amount)
                if !eligibleOnly { unqualifiedMult = ScoreMath.bounded(unqualifiedMult + amount) }
            case .multiplyMult:
                values.mult = ScoreMath.bounded(values.mult * amount)
                if !eligibleOnly { unqualifiedMult = ScoreMath.bounded(unqualifiedMult * amount) }
            default: break
            }
            operations.append(ScoreOperation(id: "t\(turnNumber).mult.\(operations.count)",
                sourceID: source, sourceInstanceID: instance ?? source, sourceName: name,
                trigger: .turnEnd, scope: .turn, kind: kind, amount: amount, before: before, after: values))
        }
        if scoringVersion < 2 {
            step("legacy", nil, "Saved Turn multiplier", .multiplyMult, pendingMult)
            let additive = Resolver.globalAdditive(self)
            if additive != 0 { step("legacy-global", nil, "Saved additive bonus", .addMult, additive) }
        } else {
            if pendingMult != 1 { step("clipping.overprint", nil, "Overprint", .addMult, pendingMult - 1) }
            if let rose = itemState[Markers.rose], rose != 0 { step(Markers.rose, nil, "Rose Marker", .addMult, rose) }
            if let ink = itemState[Buffs.freshInk], ink != 0 {
                let sources = scoringBuffSources[Buffs.freshInk] ?? []
                let prior = max(0, ink - Double(sources.count) * 2)
                if prior > 0 { step(Buffs.freshInk, "legacy.ink", "Fresh Ink", .addMult, prior) }
                for id in sources { step(Buffs.freshInk, id.uuidString, "Fresh Ink", .addMult, 2) }
            }
            if qualifiedPoints > 0 {
                for effect in buffState.turnMult where effect.turn == turnNumber && effect.amount != 0 {
                    selectiveMult = true
                    step(effect.definition, effect.source.uuidString,
                        "\(Catalog.item(effect.definition)?.name ?? "Buff") · eligible Points",
                        .addMult, effect.amount, eligibleOnly: true)
                }
            }
            if boss == .collateral, let card = bossState.encounter.pledgedCard {
                step("boss.collateral", card.id.uuidString, "The Collateral", .addMult, BossEncounterRules.collateralMult)
            }
            if let locked = turnScoringState {
                let context = EffectContext(event: .place, digit: nil, square: nil, unit: nil,
                    isClue: false, level: level, slot: slot, difficulty: difficulty,
                    bookmarkCount: locked.bookmarks.count, boardCountBefore: 0,
                    completesLine: false, completedUnitCount: 0,
                    puzzleState: bookmarkState.legacyTurn ? locked.observedItemState : itemState,
                    runState: locked.runState)
                let activeIDs = Set(locked.bookmarks.filter {
                    $0.id != locked.disabledBookmarkID && !bookmarkState.suspended.contains($0.id)
                }.map(\.id))
                for index in BossScoring.evaluationIndices(count: locked.bookmarks.count, puzzle: self) {
                    let bookmark = locked.bookmarks[index]
                    guard activeIDs.contains(bookmark.id) else { continue }
                    let effect = BookmarkMechanics.heldEffect(bookmark,
                        previous: BossScoring.physicalPrevious(of: bookmark, in: locked.bookmarks, puzzle: self),
                        context: context, puzzle: self, copies: locked.bookmarkCopies ?? [:], activeIDs: activeIDs)
                    if effect.multAdd != 0 {
                        step(bookmark.defID, bookmark.id.uuidString, bookmark.def.name, .addMult, effect.multAdd)
                    }
                    if effect.multX != 1 {
                        step(bookmark.defID, bookmark.id.uuidString, bookmark.def.name, .multiplyMult, effect.multX)
                    }
                }
            }
        }
        if boss?.halvesScoreMultiplier == true {
            step("boss.sashimi", nil, boss!.name, .multiplyMult, 0.5)
        }
        let qualified = selectiveMult ? qualifiedPoints : pendingBase
        let unqualified = pendingBase - qualified
        let product = Double(qualified) * values.mult + Double(unqualified) * unqualifiedMult
        let requested = ScoreMath.integer(product)
        let settlement = BossScoring.settlement(gross: requested, puzzle: self)
        let payable = settlement?.paid ?? requested
        let bankable = ScoreMath.add(score, payable) - score
        if let settlement, let boss {
            operations.append(ScoreOperation(id: "t\(turnNumber).boss-settlement", sourceID: "boss.\(boss.rawValue)",
                sourceInstanceID: "boss.\(boss.rawValue)", sourceName: boss.name, trigger: .turnEnd, scope: .turn,
                kind: .settleBank, amount: Double(settlement.paid - settlement.gross),
                before: ScoreValues(points: Double(settlement.gross)),
                after: ScoreValues(points: Double(settlement.paid))))
        }
        // Ordinary fractional rounding is part of banking, not a score cap.
        // Compare the integral requested product before saturation so a large
        // multiplier also reports the ceiling when the starting score is zero.
        let limited = payable > bankable || (settlement == nil && product.rounded(.down) > Double(bankable))
        let mixed = selectiveMult && unqualified > 0
        return ScoreLedger(version: scoringVersion, turnNumber: turnNumber,
            operations: operations, points: pendingBase,
            multiplier: mixed && pendingBase > 0 ? product / Double(pendingBase) : values.mult,
            total: bankable, scoreLimitApplied: limited ? true : nil,
            eligiblePoints: mixed ? qualified : nil, eligibleMultiplier: mixed ? values.mult : nil,
            ineligibleMultiplier: mixed ? unqualifiedMult : nil, bossSettlement: settlement)
    }
}

extension Resolver {
    /// Per-event Points keep square effects local. Ordered held Mult lives in
    /// the batch, not in these points. This emits the arithmetic it performs.
    static func scoredEvent(base: Int, originalBase: Int? = nil, result: EffectResult,
                            square: EffectResult, puzzle: PuzzleState, event: GameEvent, digit: Digit?,
                            isClueZero: Bool, doubler: String?, sequence: Int, coinsBefore: Int) -> ScoreEventReceipt {
        let result = BossScoring.publicistGated(result, event: event, puzzle: puzzle)
        var values = ScoreValues(coins: coinsBefore)
        var operations: [ScoreOperation] = []
        func step(_ source: String, _ instance: String? = nil, _ name: String,
                  _ kind: ScoreOperation.Kind, _ amount: Double, scope: ScoreOperation.Scope = .event) {
            let before = values
            switch kind {
            case .addPoints: values.points = ScoreMath.bounded(values.points + amount)
            case .multiplyPoints: values.points = ScoreMath.bounded(values.points * amount)
            case .setBase: values.points = ScoreMath.bounded(amount)
            case .zero: values.points = 0
            case .coins: values.coins += Int(amount)
            default: break
            }
            operations.append(ScoreOperation(id: "t\(puzzle.turnNumber).e\(sequence).\(operations.count)",
                sourceID: source, sourceInstanceID: instance ?? source, sourceName: name,
                trigger: event, scope: scope, kind: kind, amount: amount, before: before, after: values))
        }
        let label = event == .place ? "Number placed" : event == .lineClear ? "Line complete" : "Full board"
        let natural = event == .place ? digit.map { BossScoring.naturalBase(digit: $0, puzzle: puzzle) } : nil
        let initial = event == .place && puzzle.boss == .backPage ? (digit.map { $0.rawValue * 10 } ?? base) : (originalBase ?? base)
        step("base.\(event.rawValue)", nil, label, .addPoints, Double(initial))
        if puzzle.boss == .backPage, let natural {
            step("boss.\(BossModifier.backPage.rawValue)", nil, BossModifier.backPage.name, .setBase, Double(natural))
        }
        let beforeOverride = natural ?? originalBase ?? base
        if base != beforeOverride {
            step("mk_violet", nil, "Violet Marker", .addPoints, Double(base - beforeOverride))
        }
        for c in result.contributions where c.flat != 0 {
            step(c.sourceID, c.instanceID, c.name, .addPoints, Double(c.flat))
        }
        // Paper Crane is an activated digit-specific state, not a live held hook.
        let attributedFlat = result.contributions.reduce(0) { $0 + $1.flat }
        if result.flat != attributedFlat {
            let sources = digit.flatMap { puzzle.scoringBuffSources[Buffs.paperCraneKey($0)] } ?? []
            let old = result.flat - attributedFlat - sources.count * 50
            if old != 0 { step(Buffs.paperCrane, "legacy.crane", "Paper Crane", .addPoints, Double(old)) }
            for id in sources { step(Buffs.paperCrane, id.uuidString, "Paper Crane", .addPoints, 50) }
        }
        for c in result.contributions where c.localMultX != 1 {
            step(c.sourceID, c.instanceID, c.name, .multiplyPoints, c.localMultX)
        }
        if let doubler {
            step(doubler, puzzle.scoringBuffSources[doubler]?.last?.uuidString, Catalog.item(doubler)?.name ?? "Score doubled", .multiplyPoints, 2)
        }
        if result.zeroed || isClueZero {
            let source = isClueZero ? "clue" : (result.zeroSourceID ?? "boss.\(puzzle.boss?.rawValue ?? "restriction")")
            step(source, nil, isClueZero ? "Clue: no score" : (Catalog.item(source)?.name ?? puzzle.boss?.name ?? "No score"), .zero, 0)
        }
        for c in result.contributions where c.coins != 0 {
            step(c.sourceID, c.instanceID, c.name, .coins, Double(c.coins), scope: .economy)
        }
        let points = ScoreMath.integer(values.points)
        return ScoreEventReceipt(event: event, base: base, points: points,
                                 contributions: result.contributions, operations: operations)
    }
}
