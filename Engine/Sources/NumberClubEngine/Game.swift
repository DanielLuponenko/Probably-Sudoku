import Foundation

/// The facade the app talks to. Everything below it is value types, so the UI
/// can hold a `Game`, observe it, and never worry about aliasing.
public struct Game: Sendable {
    public internal(set) var run: RunState

    public init(seed: String, book: Book = .probably, obstacle: Obstacle = .none) {
        run = RunState(seed: seed, book: book, obstacle: obstacle)
    }
    public init(run: RunState) {
        self.run = run
        self.run.finishBookIfCashedOut()
        self.run.puzzle?.ensureHandIdentities(seed: run.seed)
        BuffRuntime.prepareLegacyLitmus(&self.run)
    }

    public var puzzle: PuzzleState? { run.puzzle }
    public var shop: ShopState? { run.shop }
    public var isOver: Bool { run.outcome != nil }
    public var canClaimRewardedRescue: Bool { Actions.canClaimRewardedRescue(run) }

    /// Deals the current Level and slot's board.
    public mutating func startPuzzle() throws {
        guard !isOver, run.puzzle == nil, run.shop == nil, run.pendingItemDecisions.isEmpty else {
            throw PlacementError.puzzleNotPlayable
        }
        var next = run
        var puzzle = try PuzzleState.create(run: &next)
        if let overprint = next.runItemState.removeValue(forKey: "clipping.overprint"), overprint > 0 {
            puzzle.pendingMult += overprint
        }
        next.puzzle = puzzle
        BuffRoutes.didStartPuzzle(&next)
        MarkerRuntime.synchronizeOwnership(run: &next)
        BookmarkMechanics.enqueueChoices(run: &next)
        run = next
    }

    /// §9 — a Shop opens between Puzzles, never after the final victory.
    public mutating func openShop() {
        run.finishBookIfCashedOut()
        guard !isOver, !run.isFinalPuzzle, run.pendingItemDecisions.isEmpty,
              run.shop == nil, run.puzzle?.phase == .cashedOut else { return }
        run.puzzle = nil
        Shop.open(&run)
    }

    /// Moves to the next Puzzle in the Book. Returns false when the Book is
    /// finished — beating the Level 9 Boss (§2).
    @discardableResult
    public mutating func advance() -> Bool {
        run.finishBookIfCashedOut()
        // Final completion belongs to the successful cash-out, not navigation.
        guard !isOver, !run.isFinalPuzzle, run.pendingItemDecisions.isEmpty,
              run.shop != nil || run.puzzle?.phase == .cashedOut else { return false }
        // Leaving the Shop is part of moving to the next briefing. Keeping its
        // stale state made `currentSkipOffer` think the next normal Puzzle was
        // still in a Shop, so its skip offer disappeared.
        var next = run
        if next.shop != nil {
            Shop.close(&next)
        }
        next.shop = nil
        next.puzzle = nil
        let advanced = next.advance()
        run = next
        return advanced
    }
    @discardableResult
    public mutating func skipPuzzle(ifCurrent offer: SkipOffer,
                                    replacingBuffID: UUID? = nil) throws -> SkipRecord {
        guard run.pendingItemDecisions.isEmpty, let current = run.currentSkipOffer else { throw SkipError.cannotSkip }
        guard current == offer else { throw SkipError.staleOffer }
        let replacementIndex: Int?
        if let replacingBuffID {
            guard run.buffs.count == BookmarkMechanics.capacity(run: run),
                  let index = run.buffs.firstIndex(where: { $0.id == replacingBuffID }) else {
                throw SkipError.invalidReplacement
            }
            replacementIndex = index
        } else {
            guard run.buffs.count < BookmarkMechanics.capacity(run: run) else { throw SkipError.inventoryFull }
            replacementIndex = nil
        }

        // Validate everything first, then publish one complete value. UI
        // cancellation never calls this, and stale animation callbacks cannot
        // claim a new position using the previous offer.
        var next = run
        if let replacementIndex { next.buffs.remove(at: replacementIndex) }
        next.buffs.append(OwnedBuff(defID: offer.buffID, pricePaid: 0, id: offer.id))
        let record = SkipRecord(offer: offer, replacedBuffID: replacingBuffID)
        next.skipHistory.append(record)
        _ = next.advance()
        run = next
        return record
    }

    // Pass-throughs, so callers never have to reach for `Actions` and `Shop`
    // and remember which one owns what.
    public mutating func place(handIndex: Int, at square: Square) throws -> PlacementOutcome {
        try Actions.place(&run, handIndex: handIndex, square: square)
    }
    @discardableResult
    public mutating func toss(handIndex: Int) throws -> Digit {
        try Actions.toss(&run, handIndex: handIndex)
    }
    public mutating func useClue(at square: Square) throws -> PlacementOutcome {
        try Actions.useClue(&run, square: square)
    }
    public mutating func revealClue(handIndex: Int) throws -> Square {
        try Actions.revealClue(&run, handIndex: handIndex)
    }
    public mutating func useBuff(at index: Int, digit: Digit? = nil) throws -> Bool {
        try Actions.useBuff(&run, index: index, digit: digit)
    }
    @discardableResult
    public mutating func beginBuff(id: UUID) throws -> BuffUseOutcome {
        var next = run
        let result = try BuffRuntime.begin(buffID: id, run: &next)
        if result.consumedID != nil || next.puzzle?.bossState.pendingAutoEnd == true {
            _ = try Actions.finishAutomaticTurnIfNeeded(&next)
        }
        run = next
        return result
    }
    /// One saved transaction includes the resolved choice, its reward and any
    /// automatic empty-Hand bank. Repeated or stale decision IDs cannot claim.
    @discardableResult
    public mutating func resolveItemDecision(id: UUID, selected: [String]?) throws -> Bool {
        guard let decision = run.pendingItemDecisions.first, decision.id == id else { return false }
        var next = run
        let outgoingTurn = next.puzzle?.turnNumber
        if decision.sourceID.hasPrefix("bf_") {
            if let selected {
                _ = try BuffRuntime.commit(decisionID: id, selected: selected, run: &next)
            } else {
                guard BuffRuntime.cancel(decisionID: id, run: &next) else { return false }
            }
        } else if decision.sourceID.hasPrefix("mk_") {
            guard try MarkerRuntime.resolveDecision(run: &next, id: id, selected: selected) else { return false }
        } else {
            _ = try BookmarkMechanics.resolveDecision(id: id, selected: selected, run: &next)
        }
        if next.puzzle?.turnNumber == outgoingTurn,
           selected != nil || decision.sourceID.hasPrefix("mk_") || next.puzzle?.bossState.pendingAutoEnd == true {
            _ = try Actions.finishAutomaticTurnIfNeeded(&next)
        }
        run = next
        return true
    }
    public mutating func endTurn() throws -> Actions.TurnResult {
        try Actions.endTurn(&run)
    }
    public mutating func failPuzzle() {
        Actions.failPuzzle(&run)
    }
    /// Applied only after the app confirms the reward for this pending Puzzle.
    @discardableResult
    public mutating func claimRewardedRescue() -> Bool {
        Actions.claimRewardedRescue(&run)
    }
    @discardableResult
    public mutating func declineRewardedRescue() -> Bool {
        Actions.declineRewardedRescue(&run)
    }
    public mutating func cashOut() throws -> RunState.Payout {
        guard !isOver else { throw PlacementError.puzzleNotPlayable }
        let payout = try Actions.cashOut(&run)
        run.finishBookIfCashedOut()
        return payout
    }
    public mutating func keepFilling() throws {
        try Actions.keepFilling(&run)
    }
    public mutating func buy(slot: Int) throws {
        guard run.pendingItemDecisions.isEmpty else { throw BuffUseError.pendingChoice }
        try Shop.buy(&run, slot: slot)
    }
    public mutating func reroll() throws {
        guard run.pendingItemDecisions.isEmpty else { throw BuffUseError.pendingChoice }
        try Shop.reroll(&run)
    }
    @discardableResult
    public mutating func sell(kind: ItemKind, index: Int) throws -> Int {
        guard run.pendingItemDecisions.isEmpty else { throw BuffUseError.pendingChoice }
        return try Shop.sell(&run, kind: kind, index: index)
    }
    public mutating func requestCapacitySale(bookmarkID: UUID) throws {
        guard run.pendingItemDecisions.isEmpty else { throw BookmarkChoiceError.staleChoice }
        var next = run
        try BookmarkMechanics.requestCapacitySale(bookmarkID: bookmarkID, run: &next)
        run = next
    }
    public mutating func cancelReservation() {
        guard run.pendingItemDecisions.isEmpty else { return }
        BuffShop.cancelReservation(&run)
    }
    public mutating func reopenRecycledChoice(bookmarkID: UUID) {
        guard run.pendingItemDecisions.isEmpty else { return }
        BookmarkMechanics.reopenRecycledChoice(bookmarkID: bookmarkID, run: &run)
    }
    public mutating func claimSquare(markerIndex: Int, square: Square) throws {
        guard run.pendingItemDecisions.isEmpty else { throw BuffUseError.pendingChoice }
        try Shop.claimSquare(&run, markerIndex: markerIndex, square: square)
    }
}

// MARK: - Persistence

public extension Game {
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(run)
    }
    init(decoding data: Data) throws {
        self.init(run: try JSONDecoder().decode(RunState.self, from: data))
    }
}

// MARK: - QA

#if DEBUG
/// Shortcuts for exercising the game by hand. Compiled out of release builds,
/// so these can never reach a player. They deliberately go through the same
/// phase check as a real action, otherwise a QA win would not behave like one.
public extension Game {

    mutating func qaAward(points: Int) {
        guard var puzzle = run.puzzle else { return }
        BossEncounterRules.addScore(points, puzzle: &puzzle)
        Actions.updatePhase(&puzzle)
        run.puzzle = puzzle
    }

    mutating func qaAward(coins: Int) {
        run.coins = max(0, run.coins + coins)
    }

    /// Puts the score exactly on target, which is the fastest way to reach the
    /// Cash Out / Keep Filling choice and everything downstream of it.
    mutating func qaMeetTarget() {
        guard var puzzle = run.puzzle else { return }
        if puzzle.boss == .splitEdition {
            let selected = puzzle.bossState.encounter.selectedEdition
            let targets = BossEncounterRules.editionTargets(puzzle: puzzle)
            for index in 0..<2 {
                puzzle.bossState.encounter.selectedEdition = index
                BossEncounterRules.addScore(max(0, targets[index] - puzzle.bossState.encounter.editionScores[index]), puzzle: &puzzle)
            }
            puzzle.bossState.encounter.selectedEdition = selected
            Actions.updatePhase(&puzzle)
            run.puzzle = puzzle
        } else {
            qaAward(points: max(0, puzzle.target - puzzle.score))
            // Even QA takes Last Edition through its one authoritative bank.
            if puzzle.boss == .lastEdition, puzzle.bossState.encounter.banksUsed == 0,
               run.pendingItemDecisions.isEmpty { _ = try? endTurn() }
        }
    }

    mutating func qaFailPuzzle() {
        guard var puzzle = run.puzzle else { return }
        puzzle.phase = .failed
        run.puzzle = puzzle
        run.outcome = .failed
    }

    /// Moves a debug Book to a specific reached level, then fails it. The
    /// puzzle state is intentionally left alone because the failure reward is
    /// based on cleared levels and Bosses, not a synthetic board result.
    mutating func qaFailBook(atLevel level: Int) {
        run.level = min(max(1, level), 9)
        qaFailPuzzle()
    }

    /// Reaches the exact terminal Book state through the same cash-out
    /// rules as live play. It exists solely to inspect the closing
    /// sequence without playing twenty-seven Puzzles.
    mutating func qaCompleteBook() {
        guard run.outcome == nil else { return }
        run.level = 9
        run.slot = .boss
        if run.pendingBoss?.isFinalBoss != true { run.pendingBoss = nil }
        run.puzzle = nil
        run.shop = nil
        do {
            try startPuzzle()
        } catch {
            return
        }
        qaMeetTarget()
        // Review Board also requires completed units. Use the existing
        // conserved QA fill instead of bypassing its live qualification rule.
        if run.puzzle?.boss == .reviewBoard { qaFillBoard() }
        guard (try? cashOut()) != nil else { return }
    }

    /// Fills every Blank with its solution digit, taking each number from the
    /// Pool or the Hand so the conservation rule still holds. Nothing is
    /// scored — this is for reaching the Full Clear and the results page, not
    /// for checking what they are worth.
    /// Hands over a Bookmark, for looking at a populated loadout.
    mutating func qaGrantAd(_ defID: String) {
        guard Catalog.item(defID) != nil, run.bookmarks.count < ItemKind.bookmark.capacity,
              !run.owns(bookmark: defID) else { return }
        run.bookmarks.append(OwnedBookmark(defID: defID, boughtAtLevel: run.level, pricePaid: 0))
    }

    /// Hands over a Buff, for exercising the ones that ask a question.
    mutating func qaGrantBuff(_ defID: String) {
        guard Catalog.item(defID) != nil, run.buffs.count < BookmarkMechanics.capacity(run: run) else { return }
        run.buffs.append(OwnedBuff(defID: defID, pricePaid: 0))
    }

    /// Replaces the corresponding QA loadout slot. This makes every catalogue
    /// entry reachable in a fresh, repeatable state without filling capacity.
    mutating func qaSetBookmark(_ defID: String) {
        guard Catalog.item(defID)?.kind == .bookmark else { return }
        run.bookmarks = [OwnedBookmark(defID: defID, boughtAtLevel: run.level, pricePaid: 0)]
        qaRefreshActivePuzzleLimits()
    }

    /// Places exactly one selected Marker on a known blank square. Replacing
    /// the QA marker loadout keeps every Marker individually testable.
    mutating func qaSetMarker(_ defID: String, at square: Square) {
        guard Catalog.item(defID)?.kind == .marker else { return }
        run.markers = [OwnedMarker(defID: defID, boughtAtLevel: run.level,
                                   pricePaid: 0, squares: [square])]
    }

    mutating func qaSetBuff(_ defID: String) {
        guard Catalog.item(defID)?.kind == .buff else { return }
        run.buffs = [OwnedBuff(defID: defID, pricePaid: 0)]
    }

    mutating func qaSetSubscription(_ defID: String) {
        guard Catalog.item(defID)?.kind == .subscription else { return }
        run.subscriptions = [OwnedSubscription(defID: defID, pricePaid: 0)]
        qaRefreshActivePuzzleLimits()
    }

    /// Applies a selected Boss to the current Puzzle, including its standing
    /// limits, while preserving the board's number-conservation invariant.
    mutating func qaSetBoss(_ boss: BossModifier) {
        guard var puzzle = run.puzzle else { return }

        if let card = puzzle.bossState.encounter.pledgedCard {
            puzzle.bossState.encounter.pledgedCard = nil
            puzzle.appendHandCard(card)
        }
        puzzle.boss = boss
        puzzle.clockSecondsRemaining = boss.secondsAllowed
        puzzle.censoredDigit = boss.censorsARandomDigit
            ? BossModifier.rollCensoredDigit(&run.streams.boss)
            : nil
        // A QA selection represents a fresh encounter. Dynamic effects from
        // the previously selected Boss (fouls, sleeping Bookmark, barred
        // digits) must not bleed into the one being inspected next.
        puzzle.bossTurn = nil
        puzzle.bossState = .init()
        run.puzzle = puzzle
        qaRefreshActivePuzzleLimits()
        guard var active = run.puzzle else { return }
        BossRuntime.puzzleStarted(run: run, puzzle: &active)
        active.startBossTurn(&run)
        run.puzzle = active
    }

    /// Reapply standing limits after a QA selection changes the active run or
    /// Boss. Returning excess hand cards to the Pool preserves conservation.
    private mutating func qaRefreshActivePuzzleLimits() {
        guard var puzzle = run.puzzle else { return }
        let boss = puzzle.boss

        puzzle.turnsMax = run.effectiveTurns(boss: boss)
        puzzle.turnNumber = min(puzzle.turnNumber, puzzle.turnsMax)
        puzzle.tossAllowance = run.effectiveTossAllowance(boss: boss)
        puzzle.cluesRemaining = run.effectiveClues(boss: boss)
        puzzle.target = BossEncounterRules.startingTarget(
            base: run.book.target(level: puzzle.level, slot: puzzle.slot), boss: boss)
        if boss == .splitEdition {
            puzzle.bossState.encounter.editionTargets = [puzzle.target / 2 + puzzle.target % 2, puzzle.target / 2]
        }

        let targetHandSize = run.effectiveHandSize(boss: boss)
        let drawable = max(0, targetHandSize - puzzle.reservedBossCards.count)
        while puzzle.hand.count > drawable {
            puzzle.pool.put(puzzle.removeHandCard(at: puzzle.hand.count - 1).digit)
        }
        puzzle.appendHandDigits(puzzle.pool.draw(&run.streams.pool,
                                                        count: max(0, drawable - puzzle.hand.count)))
        puzzle.handSize = targetHandSize
        run.puzzle = puzzle
        puzzle.assertConservation()
    }

    /// Fills one square without scoring, for setting a board up by hand.
    mutating func qaPlace(digit: Digit, at square: Square) -> Bool {
        guard var puzzle = run.puzzle, puzzle.board.isBlank(square),
              puzzle.board.correctDigit(at: square) == digit else { return false }
        if puzzle.pool.take(digit) {
            // taken from the Pool
        } else if let index = puzzle.hand.firstIndex(of: digit) {
            _ = puzzle.removeHandCard(at: index)
        } else {
            return false
        }
        puzzle.board.fill(square, with: digit, by: .player)
        run.puzzle = puzzle
        return true
    }

    /// Moves one number from the Pool into the Hand.
    mutating func qaTakeFromPool(_ digit: Digit) -> Bool {
        guard var puzzle = run.puzzle, puzzle.pool.take(digit) else { return false }
        puzzle.appendHandDigits([digit])
        run.puzzle = puzzle
        return true
    }

    mutating func qaFillBoard() {
        guard var puzzle = run.puzzle else { return }
        for square in puzzle.board.blanks {
            let digit = puzzle.board.correctDigit(at: square)
            if puzzle.pool.take(digit) {
                // taken from the Pool
            } else if let index = puzzle.hand.firstIndex(of: digit) {
                _ = puzzle.removeHandCard(at: index)
            } else if puzzle.bossState.encounter.pledgedCard?.digit == digit {
                puzzle.bossState.encounter.pledgedCard = nil
            } else {
                continue
            }
            puzzle.board.fill(square, with: digit, by: .player)
        }
        Actions.updatePhase(&puzzle)
        run.puzzle = puzzle
        puzzle.assertConservation()
        if puzzle.boss == .lastEdition, puzzle.bossState.encounter.banksUsed == 0,
           puzzle.phase == .playing, run.pendingItemDecisions.isEmpty { _ = try? endTurn() }
    }
}
#endif
