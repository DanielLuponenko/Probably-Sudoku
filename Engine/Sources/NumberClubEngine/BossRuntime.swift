import Foundation

/// Rules shared by every input path. Hand restrictions inspect public values
/// and exact card identities only; no release decision consults the solution.
public enum BossRuntime {
    public static func puzzleStarted(run: RunState, puzzle: inout PuzzleState) {
        puzzle.bossState = .init()
        puzzle.bossState.royaltyStartingTarget = puzzle.target
        synchronizeHand(puzzle: &puzzle)
        if puzzle.boss == .reviewBoard {
            for (kind, units) in [(BossReviewUnit.row, Geometry.rows), (.col, Geometry.cols), (.box, Geometry.boxes)] {
                if units.allSatisfy({ $0.allSatisfy { !puzzle.board.isBlank($0) } }) {
                    puzzle.bossState.reviewApproved.insert(kind)
                }
            }
        }
        BossScoring.puzzleStarted(run: run, puzzle: &puzzle)
        BossEncounterRules.puzzleStarted(puzzle: &puzzle)
    }

    /// Called by all card append/remove helpers. Existing identities keep
    /// arrival order even when returned by Jade/Return Slip or displayed sorted.
    public static func synchronizeHand(puzzle: inout PuzzleState) {
        guard puzzle.boss != nil else { return }
        // Restored pre-identity saves and legitimate engine fixtures can enter
        // a Turn with digits but no UUID array. Materialize once before any
        // packet, seal or arrival-order indexing; this consumes no RNG.
        puzzle.ensureHandIdentities()
        for id in puzzle.handCardIDs where puzzle.bossState.arrivalSerials[id.uuidString] == nil {
            puzzle.bossState.nextArrivalSerial += 1
            puzzle.bossState.arrivalSerials[id.uuidString] = puzzle.bossState.nextArrivalSerial
        }
        puzzle.bossState.waitingIDs.formIntersection(puzzle.handCardIDs)
        puzzle.bossState.sealedIDs.formIntersection(puzzle.handCardIDs)
        if puzzle.boss == .collator && shouldReleasePacket(puzzle: puzzle) {
            puzzle.bossState.waitingIDs = []
        }
    }

    private static func availableIndices(puzzle: PuzzleState) -> [Int] {
        puzzle.hand.indices.filter {
            !puzzle.isIndependentlyBlocked(handIndex: $0)
                || BuffRuntime.releaseAllows(handIndex: $0, puzzle: puzzle)
        }
    }

    private static func arrivalOrder(_ indices: [Int], puzzle: PuzzleState) -> [Int] {
        indices.sorted {
            let left = puzzle.bossState.arrivalSerials[puzzle.handCardIDs[$0].uuidString] ?? $0
            let right = puzzle.bossState.arrivalSerials[puzzle.handCardIDs[$1].uuidString] ?? $1
            return left == right ? $0 < $1 : left < right
        }
    }

    private static func shouldReleasePacket(puzzle: PuzzleState) -> Bool {
        puzzle.bossState.correctFills >= 2 || !availableIndices(puzzle: puzzle).contains {
            !puzzle.bossState.waitingIDs.contains(puzzle.handCardIDs[$0])
        }
    }

    public static func placementRestricted(handIndex: Int, puzzle: PuzzleState) -> Bool {
        guard puzzle.hand.indices.contains(handIndex) else { return false }
        // Very old saves may not yet have materialized Hand IDs. A local copy
        // repairs them for a read without changing the saved or selected Hand.
        var p = puzzle
        p.ensureHandIdentities()
        let available = availableIndices(puzzle: p)
        guard available.contains(handIndex) else { return false }
        switch p.boss {
        case .galleyQueue:
            return !arrivalOrder(available, puzzle: p).prefix(2).contains(handIndex)
        case .bookends:
            let digits = available.map { p.hand[$0] }
            return p.hand[handIndex] != digits.min() && p.hand[handIndex] != digits.max()
        case .reprintBan:
            return p.bossState.usedDigits.contains(p.hand[handIndex])
                && available.contains { !p.bossState.usedDigits.contains(p.hand[$0]) }
        case .collator:
            return !shouldReleasePacket(puzzle: p)
                && p.bossState.waitingIDs.contains(p.handCardIDs[handIndex])
        default: return false
        }
    }

    /// Clear old-Turn restrictions only at the actual committed boundary.
    public static func boundaryStarted(puzzle: inout PuzzleState) {
        puzzle.bossState.usedDigits = []
        puzzle.bossState.waitingIDs = []
        puzzle.bossState.correctFills = 0
        puzzle.bossState.pendingAutoEnd = false
        puzzle.bossState.sealedIDs = []
        puzzle.bossState.placementStarted = false
        BossScoring.turnStarted(puzzle: &puzzle)
        BossEncounterRules.turnStarted(puzzle: &puzzle)
    }

    /// Runs after ordinary refill and independent restriction selection.
    public static func turnStarted(puzzle: inout PuzzleState) {
        synchronizeHand(puzzle: &puzzle)
        if puzzle.boss == .collator, puzzle.hand.count >= 3 {
            let order = arrivalOrder(Array(puzzle.hand.indices), puzzle: puzzle)
            let firstCount = (order.count + 1) / 2
            puzzle.bossState.waitingIDs = Set(order.dropFirst(firstCount).map { puzzle.handCardIDs[$0] })
            synchronizeHand(puzzle: &puzzle)
        }
    }

    public static func acceptedCorrect(digit: Digit, completedUnits: [Unit], puzzle: inout PuzzleState) {
        puzzle.bossState.usedDigits.insert(digit)
        puzzle.bossState.correctFills += 1
        if puzzle.boss == .pageCutter, puzzle.bossState.correctFills >= 4 {
            puzzle.bossState.pendingAutoEnd = true
        }
        if puzzle.boss == .reviewBoard {
            for unit in completedUnits {
                if let kind = BossReviewUnit(rawValue: unit.rawValue) { puzzle.bossState.reviewApproved.insert(kind) }
            }
            if puzzle.board.isFull { puzzle.bossState.reviewApproved = Set(BossReviewUnit.allCases) }
        }
        synchronizeHand(puzzle: &puzzle)
    }

    public static func reviewQualified(puzzle: PuzzleState) -> Bool {
        puzzle.boss != .reviewBoard || puzzle.board.isFull
            || puzzle.bossState.reviewApproved.count == BossReviewUnit.allCases.count
    }

    @discardableResult
    public static func deferAutomaticDraw(count: Int, sourceID: String, sourceInstanceID: UUID? = nil,
                                           sourceClaimID: String? = nil,
                                           policy: BossAutomaticDrawPolicy = .ordinary,
                                           puzzle: inout PuzzleState) -> Bool {
        guard puzzle.boss == .lateCourier, count > 0,
              puzzle.phase == .playing || puzzle.phase == .keepFilling else { return false }
        puzzle.bossState.deferredDraws.append(.init(count: count, sourceID: sourceID,
                                                  sourceInstanceID: sourceInstanceID,
                                                  sourceClaimID: sourceClaimID, policy: policy))
        return true
    }

    /// The outgoing effects have banked. Deliver exactly once before computing
    /// the normal refill deficit; owed draws never create a second refill.
    @discardableResult
    public static func beforeRefill(run: inout RunState, puzzle: inout PuzzleState) -> Int {
        if puzzle.boss == .rebinder {
            let returned = puzzle.removeAllHandCards()
            BuffRuntime.invalidateCards(Set(returned.map(\.id)), puzzle: &puzzle)
            for card in returned { puzzle.pool.put(card.digit) }
        }
        let requests = puzzle.bossState.deferredDraws
        puzzle.bossState.deferredDraws = []
        var count = 0
        for request in requests {
            for _ in 0..<max(0, request.count) {
                let digit: Digit?
                switch request.policy {
                case .ordinary: digit = puzzle.pool.draw(&run.streams.pool)
                case .absentFromHand:
                    digit = MarkerRuntime.drawFiltered(run: &run, puzzle: &puzzle, excluding: Set(puzzle.hand))
                }
                guard let digit else { continue }
                puzzle.appendHandDigits([digit]); count += 1
            }
        }
        if count > 0 { MarkerRuntime.ordinaryDrawOccurred(puzzle: &puzzle) }
        return count
    }
}
