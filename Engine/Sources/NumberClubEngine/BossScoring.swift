import Foundation

/// Saved facts only. Previewing a receipt never advances these counters.
public struct BossScoringState: Codable, Sendable, Equatable {
    public var chainAnchor: Square?
    public var orphanDebitedTurn: Int?
    public var serialStartingTarget: Int?
    public var serialCarry = 0
    public var binderyOrder: [UUID] = []
    public var binderyPinned = false
    public var dryPressReady = true
    public var rivalBenchmark: Int?
    @StableSet public var publicistPaid: Set<UUID> = []
    @StableSet public var committedReceipts: Set<String> = []
    public var wordCountSpent = 0
    public var lastSettledTurn: Int?
    public init() {}

    enum CodingKeys: String, CodingKey {
        case chainAnchor, orphanDebitedTurn, serialStartingTarget, serialCarry, binderyOrder,
             binderyPinned, dryPressReady, rivalBenchmark, publicistPaid, committedReceipts, wordCountSpent, lastSettledTurn
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chainAnchor = try c.decodeIfPresent(Square.self, forKey: .chainAnchor)
        orphanDebitedTurn = try c.decodeIfPresent(Int.self, forKey: .orphanDebitedTurn)
        serialStartingTarget = try c.decodeIfPresent(Int.self, forKey: .serialStartingTarget)
        serialCarry = try c.decodeIfPresent(Int.self, forKey: .serialCarry) ?? 0
        binderyOrder = try c.decodeIfPresent([UUID].self, forKey: .binderyOrder) ?? []
        binderyPinned = try c.decodeIfPresent(Bool.self, forKey: .binderyPinned) ?? !binderyOrder.isEmpty
        dryPressReady = try c.decodeIfPresent(Bool.self, forKey: .dryPressReady) ?? true
        rivalBenchmark = try c.decodeIfPresent(Int.self, forKey: .rivalBenchmark)
        _publicistPaid = try c.decodeIfPresent(StableSet<UUID>.self, forKey: .publicistPaid) ?? .init()
        _committedReceipts = try c.decodeIfPresent(StableSet<String>.self, forKey: .committedReceipts) ?? .init()
        wordCountSpent = try c.decodeIfPresent(Int.self, forKey: .wordCountSpent) ?? 0
        lastSettledTurn = try c.decodeIfPresent(Int.self, forKey: .lastSettledTurn)
    }
}

/// Ordinary post-Mult score, separate from direct awards and queued lots.
public struct BossBankSettlement: Codable, Sendable, Equatable {
    public var bossID: String
    public var gross: Int
    public var paid: Int
    public var carryBefore: Int = 0
    public var carryAfter: Int = 0
    public var limit: Int? = nil
    public var benchmark: Int? = nil
}

public enum BossScoring {
    /// Explicit immediate-score capabilities; follow-up contracts and held
    /// Mult are deliberately absent because Dry Press does not suppress them.
    public static let positiveImmediateMarkerIDs: Set<String> = [
        Markers.crimson, Markers.golden, Markers.silver, Markers.violet,
        Markers.hearth, Markers.constellation, Markers.rhythm, Markers.bridge,
        Markers.crossroads, Markers.finale, Markers.carbon, Markers.patina, Markers.pledge
    ]

    public static func positiveImmediateMarkerSquares(run: RunState, board: Board) -> [Square] {
        let puzzle = run.puzzle.flatMap { $0.board.placed == board.placed && $0.phase == .playing ? $0 : nil }
        var pledgeUses = max(0, min(3 - (puzzle?.markerState.count(Markers.pledge) ?? 0), run.coins / 2))
        var crossroadsUses = max(0, 1 - (puzzle?.markerState.count(Markers.crossroads) ?? 0))
        var finaleDigits = Set(puzzle?.markerState.finaleDigits ?? [])
        let otherConstellationType = board.blanks.contains { square in
            run.markers(covering: square).contains {
                $0.defID != Markers.constellation && (Catalog.item($0.defID)?.hooks[.place] != nil || $0.defID == Markers.patina)
            }
        }
        func visibleCandidates(_ square: Square) -> [Digit] {
            let peers = Set([Unit.row, .col, .box].flatMap { Geometry.cells(of: $0, through: square) })
            let blocked = Set(peers.compactMap { board[$0] })
            return Digit.all.filter { !blocked.contains($0) && board.count(of: $0) < 9 }
        }
        return board.blanks.filter { square in
            guard let marker = run.markers(covering: square).first,
                  positiveImmediateMarkerIDs.contains(marker.defID) else { return false }
            switch marker.defID {
            case Markers.crimson, Markers.golden: return true
            case Markers.silver: return visibleCandidates(square).contains { board.count(of: $0) > 0 }
            case Markers.violet: return visibleCandidates(square).contains { $0.rawValue < 9 }
            case Markers.hearth:
                return Square.all.contains { abs($0.row - square.row) + abs($0.col - square.col) == 1 && board.isBlank($0) }
            case Markers.constellation: return otherConstellationType
            case Markers.rhythm, Markers.carbon: return board.blanks.count > 1
            case Markers.bridge:
                let horizontal = square.col > 0 && square.col < 8
                    && !board.isGiven[square.index - 1] && !board.isGiven[square.index + 1]
                let vertical = square.row > 0 && square.row < 8
                    && !board.isGiven[square.index - 9] && !board.isGiven[square.index + 9]
                return horizontal || vertical
            case Markers.crossroads:
                guard crossroadsUses > 0 else { return false }
                crossroadsUses -= 1; return true
            case Markers.finale:
                guard finaleDigits.count < 2,
                      let digit = visibleCandidates(square).first(where: { !finaleDigits.contains($0) }) else { return false }
                finaleDigits.insert(digit); return true
            case Markers.patina:
                return (run.markerState.claims.first { $0.markerID == marker.defID && $0.square == square }?.patinaSuccesses ?? 0) > 0
            case Markers.pledge:
                guard pledgeUses > 0 else { return false }
                pledgeUses -= 1; return true
            default: return false
            }
        }
    }

    public static func hasOrderSensitiveLoadout(run: RunState) -> Bool {
        let active = BookmarkMechanics.activeOwned(run: run, puzzle: run.puzzle)
        let hasAdd = active.contains { item in
            item.defID == Bookmarks.opEd || item.defID == Bookmarks.frontPageSplash
                || (item.defID == Bookmarks.numberIndex && (run.bookmarkState.copies[item.id]?.numberIndexMult ?? 0) > 0)
        }
        let hasMultiply = active.contains { item in
            item.defID == Bookmarks.theSundaySupplement
                || (item.defID == Bookmarks.syndication && (run.runItemState[Bookmarks.syndication] ?? 0) > 0)
                || (item.defID == Bookmarks.rollingPresses && (run.puzzle?.itemState[Bookmarks.rollingPresses] ?? 0) > 0)
                || (item.defID == Bookmarks.advancePayment && run.puzzle?.bookmarkState.copies[item.id]?.advancePaid == true)
        }
        return hasAdd && hasMultiply
    }

    /// Conservative numeric proof, not a name-based difficulty guess. It uses
    /// immediately available placement operators, finite uses and real blank
    /// coordinates, then limits opportunities to a possible current Hand.
    /// More speculative future contracts need not make a run eligible.
    public static func hasWordCountLoadout(run: RunState, board: Board) -> Bool {
        let puzzle = run.puzzle.flatMap { $0.board.placed == board.placed ? $0 : nil }
        let handCapacity = max(run.effectiveHandSize(boss: .wordCount), puzzle?.hand.count ?? 0)
        let bookmarks = BookmarkMechanics.activeOwned(run: run, puzzle: puzzle)
        let remaining = Digit.all.filter { board.count(of: $0) < 9 }
        guard let minimum = remaining.first, let maximum = remaining.last else { return false }
        var extras: [Int] = []
        var finiteUses: [String: Int] = [:]
        for square in board.blanks {
            // A lower bound over the public remaining multiset proves a real
            // opportunity without consulting this blank's hidden solution.
            let natural = minimum.rawValue * 10
            var base = natural, flat = 0, factor = 1.0
            for item in bookmarks {
                switch item.defID {
                case Bookmarks.localGossip: flat += 30
                case Bookmarks.marginNotes:
                    if square.row == 0 || square.row == 8 || square.col == 0 || square.col == 8 { flat += 50 }
                case Bookmarks.neighbourhoodNews:
                    let neighbours = Square.all.filter {
                        abs($0.row - square.row) + abs($0.col - square.col) == 1 && board.filledBy[$0.index] == .player
                    }.count
                    if neighbours >= 2 { flat += 45 }
                default: break
                }
            }
            for marker in run.markers(covering: square) {
                let id = marker.defID
                switch id {
                case Markers.crimson: factor *= 4
                case Markers.golden: flat += 100
                case Markers.violet: flat += 90 - maximum.rawValue * 10
                case Markers.silver: flat += 20 * (remaining.map { board.count(of: $0) }.min() ?? 0)
                case Markers.hearth:
                    flat += 20 * Square.all.filter {
                        abs($0.row - square.row) + abs($0.col - square.col) == 1 && board.isBlank($0)
                    }.count
                case Markers.bridge:
                    if square.col > 0 && square.col < 8,
                       board.filledBy[square.index - 1] == .player && board.filledBy[square.index + 1] == .player { flat += 60 }
                    if square.row > 0 && square.row < 8,
                       board.filledBy[square.index - 9] == .player && board.filledBy[square.index + 9] == .player { flat += 60 }
                case Markers.patina:
                    let successes = run.markerState.claims.first { $0.markerID == id && $0.square == square }?.patinaSuccesses ?? 0
                    flat += min(8, successes) * 25
                case Markers.pledge:
                    let remaining = max(0, min(3 - (puzzle?.markerState.count(id) ?? 0), run.coins / 2))
                    if finiteUses[id, default: 0] < remaining { flat += 100; finiteUses[id, default: 0] += 1 }
                default: break
                }
            }
            flat += remaining.map { ScoreMath.integer(puzzle?.itemState[Buffs.paperCraneKey($0)] ?? 0) }.min() ?? 0
            extras.append(max(0, ScoreMath.integer(Double(base + flat) * factor) - natural))
        }
        return extras.sorted(by: >).prefix(handCapacity).reduce(0, +) > 150
    }

    public static func puzzleStarted(run: RunState, puzzle: inout PuzzleState) {
        if puzzle.boss == .serialPublisher, puzzle.bossState.scoring.serialStartingTarget == nil {
            puzzle.bossState.scoring.serialStartingTarget = puzzle.target
        }
    }

    public static func pinBookmarkOrder(run: RunState, puzzle: inout PuzzleState) {
        guard puzzle.boss == .bindery, !puzzle.bossState.scoring.binderyPinned else { return }
        puzzle.bossState.scoring.binderyOrder = run.bookmarks.map(\.id)
        puzzle.bossState.scoring.binderyPinned = true
    }

    public static func physicalOrder(_ bookmarks: [OwnedBookmark], puzzle: PuzzleState) -> [OwnedBookmark] {
        guard puzzle.boss == .bindery, puzzle.bossState.scoring.binderyPinned else { return bookmarks }
        let pinned = puzzle.bossState.scoring.binderyOrder.compactMap { id in bookmarks.first { $0.id == id } }
        let ids = Set(pinned.map(\.id))
        return pinned + bookmarks.filter { !ids.contains($0.id) }
    }

    public static func evaluationIndices(count: Int, puzzle: PuzzleState) -> [Int] {
        let indices = Array(0..<count)
        return puzzle.boss == .bindery && puzzle.turnNumber.isMultiple(of: 2) ? Array(indices.reversed()) : indices
    }

    public static func physicalPrevious(of item: OwnedBookmark, in bookmarks: [OwnedBookmark],
                                         puzzle: PuzzleState) -> OwnedBookmark? {
        if puzzle.boss == .bindery, puzzle.bossState.scoring.binderyPinned,
           let index = puzzle.bossState.scoring.binderyOrder.firstIndex(of: item.id) {
            guard index > 0 else { return nil }
            let id = puzzle.bossState.scoring.binderyOrder[index - 1]
            return bookmarks.first { $0.id == id }
        }
        guard let index = bookmarks.firstIndex(where: { $0.id == item.id }), index > 0 else { return nil }
        return bookmarks[index - 1]
    }

    public static func naturalBase(digit: Digit, puzzle: PuzzleState) -> Int {
        10 * (puzzle.boss == .backPage ? 10 - digit.rawValue : digit.rawValue)
    }

    public static func placementBase(digit: Digit, override: Digit?, puzzle: PuzzleState) -> Int {
        override.map { 10 * $0.rawValue } ?? naturalBase(digit: digit, puzzle: puzzle)
    }

    public static func suppressesImmediateMarker(square: Square, isClue: Bool = false,
                                                  run: RunState, puzzle: PuzzleState) -> Bool {
        puzzle.boss == .dryPress && puzzle.phase == .playing && !isClue
            && !puzzle.bossState.scoring.dryPressReady && !run.markers(covering: square).isEmpty
            && puzzle.board.blanks.contains { run.markers(covering: $0).isEmpty }
    }

    public static func refreshDryState(run: RunState, puzzle: inout PuzzleState) {
        guard puzzle.boss == .dryPress else { return }
        if !puzzle.board.blanks.contains(where: { run.markers(covering: $0).isEmpty }) {
            puzzle.bossState.scoring.dryPressReady = true
        }
    }

    public static func beforeCorrectFill(square: Square, run: RunState, puzzle: inout PuzzleState) {
        if puzzle.boss == .dryPress, run.markers(covering: square).isEmpty {
            puzzle.bossState.scoring.dryPressReady = true
        }
    }

    public static func afterCorrectFill(square: Square, isClue: Bool, run: RunState,
                                        puzzle: inout PuzzleState) {
        if puzzle.boss == .chainStitcher, !isClue { puzzle.bossState.scoring.chainAnchor = square }
        if puzzle.boss == .dryPress {
            puzzle.bossState.scoring.dryPressReady = run.markers(covering: square).isEmpty
            refreshDryState(run: run, puzzle: &puzzle)
        }
    }

    public static func turnStarted(puzzle: inout PuzzleState) {
        puzzle.bossState.scoring.chainAnchor = nil
        puzzle.bossState.scoring.publicistPaid = []
        puzzle.bossState.scoring.committedReceipts = []
        puzzle.bossState.scoring.wordCountSpent = 0
    }

    /// Source-local flat gating runs after all real hooks; resources, growth,
    /// multipliers and promised awards are never removed with the flat bonus.
    static func publicistGated(_ input: EffectResult, event: GameEvent, puzzle: PuzzleState) -> EffectResult {
        guard puzzle.boss == .publicist, puzzle.phase == .playing,
              event == .place || event == .lineClear else { return input }
        var result = input
        for i in result.contributions.indices {
            let c = result.contributions[i]
            guard c.flat > 0, c.sourceID.hasPrefix("bm_"), let raw = c.instanceID,
                  let id = UUID(uuidString: raw), puzzle.bossState.scoring.publicistPaid.contains(id) else { continue }
            result.flat -= c.flat
            result.contributions[i].flat = 0
        }
        return result
    }

    public static func adjustedPlacementReceipt(_ original: ScoreEventReceipt, digit: Digit,
        square: Square, isClue: Bool, puzzle: PuzzleState) -> ScoreEventReceipt {
        guard original.event == .place, !isClue, puzzle.phase == .playing, original.points > 0 else { return original }
        var receipt = original
        let before = ScoreValues(points: Double(original.points))
        var kind: ScoreOperation.Kind = .subtractPoints
        var amount = 0.0
        if puzzle.boss == .chainStitcher, let anchor = puzzle.bossState.scoring.chainAnchor,
           anchor.row != square.row && anchor.col != square.col && anchor.box != square.box {
            receipt.points /= 2; kind = .multiplyPoints; amount = 0.5
        } else if puzzle.boss == .wordCount {
            let natural = naturalBase(digit: digit, puzzle: puzzle)
            let extra = max(0, receipt.points - natural)
            let allowed = min(extra, max(0, 150 - puzzle.bossState.scoring.wordCountSpent))
            receipt.points = min(receipt.points, natural) + allowed
            amount = Double(original.points - receipt.points)
            // Keep an explicit operation even before clipping, so the actual
            // committed entitlement can be derived from this exact receipt.
        } else { return receipt }
        let boss = puzzle.boss!
        receipt.operations.append(ScoreOperation(id: "t\(puzzle.turnNumber).boss.\(square.index)",
            sourceID: "boss.\(boss.rawValue)", sourceInstanceID: "boss.\(boss.rawValue)", sourceName: boss.name,
            trigger: .place, scope: .event, kind: kind, amount: amount,
            before: before, after: ScoreValues(points: Double(receipt.points))))
        return receipt
    }

    public static func commitReceipt(_ receipt: ScoreEventReceipt, isClue: Bool, puzzle: inout PuzzleState) {
        guard puzzle.phase == .playing, receipt.points > 0 else { return }
        if puzzle.boss == .publicist, receipt.event == .place || receipt.event == .lineClear {
            for contribution in receipt.contributions where contribution.flat > 0 && contribution.sourceID.hasPrefix("bm_") {
                if let raw = contribution.instanceID, let id = UUID(uuidString: raw) {
                    puzzle.bossState.scoring.publicistPaid.insert(id)
                }
            }
        }
        if puzzle.boss == .wordCount, !isClue, receipt.event == .place,
           let op = receipt.operations.last(where: { $0.sourceID == "boss.\(BossModifier.wordCount.rawValue)" }) {
            guard puzzle.bossState.scoring.committedReceipts.insert(op.id).inserted else { return }
            let natural = receipt.operations.first { $0.sourceID == "base.place" }.map { ScoreMath.integer($0.amount) } ?? receipt.base
            let spent = max(0, receipt.points - min(ScoreMath.integer(op.before.points), natural))
            puzzle.bossState.scoring.wordCountSpent = min(150, puzzle.bossState.scoring.wordCountSpent + spent)
        }
    }

    public static func orphanDebit(_ puzzle: PuzzleState) -> Int {
        guard puzzle.boss == .orphanLine, puzzle.phase == .playing,
              puzzle.bossState.scoring.orphanDebitedTurn != puzzle.turnNumber else { return 0 }
        return min(puzzle.pendingBase, min(100, 20 * puzzle.hand.count))
    }

    /// Uses the same oldest-lot-first allocation as wrong-placement debits.
    /// A pure preview calls this on a value copy; only an actual bank commits it.
    public static func prepareBank(puzzle: inout PuzzleState) {
        guard puzzle.boss == .orphanLine, puzzle.phase == .playing,
              puzzle.bossState.scoring.orphanDebitedTurn != puzzle.turnNumber else { return }
        let debit = orphanDebit(puzzle)
        let before = ScoreValues(points: Double(puzzle.pendingBase))
        puzzle.pendingBase -= debit
        BuffRuntime.debitQueuedPoints(debit, puzzle: &puzzle)
        puzzle.bossState.scoring.orphanDebitedTurn = puzzle.turnNumber
        if debit > 0 {
            puzzle.turnScoringOperations.append(ScoreOperation(id: "t\(puzzle.turnNumber).orphan-debit",
                sourceID: "boss.\(BossModifier.orphanLine.rawValue)", sourceInstanceID: "boss.\(BossModifier.orphanLine.rawValue)",
                sourceName: BossModifier.orphanLine.name, trigger: .turnEnd, scope: .turn,
                kind: .subtractPoints, amount: Double(debit), before: before,
                after: ScoreValues(points: Double(puzzle.pendingBase))))
        }
    }

    public static func settlement(gross: Int, puzzle: PuzzleState) -> BossBankSettlement? {
        guard puzzle.phase == .playing, let boss = puzzle.boss else { return nil }
        switch boss {
        case .serialPublisher:
            let target = max(1, puzzle.bossState.scoring.serialStartingTarget ?? puzzle.target)
            let limit = target / 3 + (target % 3 == 0 ? 0 : 1)
            let carried = max(0, puzzle.bossState.scoring.serialCarry)
            let available = ScoreMath.add(carried, gross)
            let paid = puzzle.board.isFull ? available : min(limit, available)
            return BossBankSettlement(bossID: boss.rawValue, gross: gross, paid: paid,
                carryBefore: carried, carryAfter: available - paid, limit: limit)
        case .rivalColumn:
            let benchmark = puzzle.bossState.scoring.rivalBenchmark
            let deduction = gross > 0 && benchmark.map({ gross <= $0 }) == true ? min(100, gross / 5) : 0
            return BossBankSettlement(bossID: boss.rawValue, gross: gross, paid: gross - deduction, benchmark: benchmark)
        default: return nil
        }
    }

    public static func didBank(preview: ScoreLedger, puzzle: inout PuzzleState) {
        guard puzzle.phase == .playing, puzzle.bossState.scoring.lastSettledTurn != puzzle.turnNumber,
              let settlement = preview.bossSettlement else { return }
        if puzzle.boss == .serialPublisher { puzzle.bossState.scoring.serialCarry = settlement.carryAfter }
        if puzzle.boss == .rivalColumn, settlement.gross > 0 { puzzle.bossState.scoring.rivalBenchmark = settlement.gross }
        puzzle.bossState.scoring.lastSettledTurn = puzzle.turnNumber
    }

    /// A Full Clear pays score already earned before Keep Filling began. New
    /// placement and clear Points remain frozen, and this is not another Turn.
    /// Clearing the saved carry makes repeated delivery/resume a no-op.
    public static func releaseCarryOnFullClear(puzzle: inout PuzzleState) -> ScoreEventReceipt? {
        guard puzzle.boss == .serialPublisher, puzzle.phase == .keepFilling,
              puzzle.board.isFull, puzzle.bossState.scoring.serialCarry > 0 else { return nil }
        let carry = puzzle.bossState.scoring.serialCarry
        let before = puzzle.score
        puzzle.score = ScoreMath.add(before, carry)
        puzzle.bossState.scoring.serialCarry = 0
        let paid = puzzle.score - before
        let boss = BossModifier.serialPublisher
        let source = "boss.\(boss.rawValue)"
        let prefix = "t\(puzzle.turnNumber).serial-full-clear-carry"
        let operations = [
            ScoreOperation(id: prefix + ".settle", sourceID: source, sourceInstanceID: source,
                sourceName: boss.name, trigger: .fullClear, scope: .turn, kind: .settleBank,
                amount: Double(carry), before: ScoreValues(points: 0),
                after: ScoreValues(points: Double(carry))),
            ScoreOperation(id: prefix + ".bank", sourceID: source, sourceInstanceID: source,
                sourceName: boss.name, trigger: .fullClear, scope: .turn, kind: .bank,
                amount: Double(paid), before: ScoreValues(score: before),
                after: ScoreValues(score: puzzle.score))
        ]
        puzzle.lastScoringLedger = ScoreLedger(version: puzzle.scoringVersion, turnNumber: puzzle.turnNumber,
            operations: operations, points: 0, multiplier: 1, total: paid,
            scoreLimitApplied: paid < carry ? true : nil,
            bossSettlement: BossBankSettlement(bossID: boss.rawValue, gross: 0, paid: carry,
                carryBefore: carry, carryAfter: 0))
        return ScoreEventReceipt(event: .fullClear, base: 0, points: 0,
            contributions: [ScoreContribution(sourceID: source, instanceID: source,
                name: boss.name, directScore: paid)], operations: operations)
    }
}
