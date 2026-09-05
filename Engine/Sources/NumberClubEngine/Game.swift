import Foundation

/// The facade the app talks to. Everything below it is value types, so the UI
/// can hold a `Game`, observe it, and never worry about aliasing.
public struct Game: Sendable {
    public internal(set) var run: RunState

    public init(seed: String, book: Book = .probably, obstacle: Obstacle = .none) {
        run = RunState(seed: seed, book: book, obstacle: obstacle)
    }
    public init(run: RunState) { self.run = run }

    public var puzzle: PuzzleState? { run.puzzle }
    public var shop: ShopState? { run.shop }
    public var isOver: Bool { run.outcome != nil }

    /// Deals the current Level and slot's board.
    public mutating func startPuzzle() throws {
        run.shop = nil
        var puzzle = try PuzzleState.create(run: &run)
        if let overprint = run.runItemState.removeValue(forKey: "clipping.overprint"), overprint > 0 {
            puzzle.pendingMult += overprint
        }
        run.puzzle = puzzle
    }

    /// §9 — a Shop opens after every Puzzle.
    public mutating func openShop() {
        run.puzzle = nil
        Shop.open(&run)
    }

    /// Moves to the next Puzzle in the Book. Returns false when the Book is
    /// finished — beating the Level 9 Boss (§2).
    @discardableResult
    public mutating func advance() -> Bool {
        // Leaving the Shop is part of moving to the next briefing. Keeping its
        // stale state made `currentClipping` think the next normal Puzzle was
        // still in a Shop, so its skip offer disappeared.
        run.shop = nil
        return run.advance()
    }
    @discardableResult
    public mutating func skipPuzzle() throws -> Clipping {
        let clipping = try run.takeCurrentClipping()
        _ = run.advance()
        return clipping
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
    public mutating func useBuff(at index: Int, digit: Digit? = nil) throws -> Bool {
        try Actions.useBuff(&run, index: index, digit: digit)
    }
    public mutating func endTurn() throws -> Actions.TurnResult {
        try Actions.endTurn(&run)
    }
    public mutating func failPuzzle() {
        Actions.failPuzzle(&run)
    }
    public mutating func cashOut() throws -> RunState.Payout {
        try Actions.cashOut(&run)
    }
    public mutating func keepFilling() throws {
        try Actions.keepFilling(&run)
    }
    public mutating func buy(slot: Int) throws {
        try Shop.buy(&run, slot: slot)
    }
    public mutating func reroll() throws {
        try Shop.reroll(&run)
    }
    @discardableResult
    public mutating func sell(kind: ItemKind, index: Int) throws -> Int {
        try Shop.sell(&run, kind: kind, index: index)
    }
    public mutating func claimSquare(markerIndex: Int, square: Square) throws {
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
        run = try JSONDecoder().decode(RunState.self, from: data)
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
        puzzle.score = max(0, puzzle.score + points)
        Actions.updatePhase(&puzzle)
        run.puzzle = puzzle
    }

    mutating func qaAward(coins: Int) {
        run.coins = max(0, run.coins + coins)
    }

    /// Puts the score exactly on target, which is the fastest way to reach the
    /// Cash Out / Keep Filling choice and everything downstream of it.
    mutating func qaMeetTarget() {
        guard let puzzle = run.puzzle else { return }
        qaAward(points: puzzle.target - puzzle.score)
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

    /// Reaches the exact terminal Book state through the same cash-out and
    /// advance rules as live play. It exists solely to inspect the closing
    /// sequence without playing twenty-seven Puzzles.
    mutating func qaCompleteBook() {
        guard run.outcome == nil else { return }
        run.level = 9
        run.slot = .boss
        run.puzzle = nil
        run.shop = nil
        do {
            try startPuzzle()
        } catch {
            return
        }
        qaMeetTarget()
        guard (try? cashOut()) != nil else { return }
        openShop()
        _ = advance()
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
        guard Catalog.item(defID) != nil, run.buffs.count < ItemKind.buff.capacity else { return }
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

        puzzle.boss = boss
        puzzle.censoredDigit = boss.censorsARandomDigit
            ? BossModifier.rollCensoredDigit(&run.streams.boss)
            : nil
        // A QA selection represents a fresh encounter. Dynamic effects from
        // the previously selected Boss (fouls, sleeping Bookmark, barred
        // digits) must not bleed into the one being inspected next.
        puzzle.bossTurn = nil
        run.puzzle = puzzle
        qaRefreshActivePuzzleLimits()
        guard var active = run.puzzle else { return }
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
        puzzle.target = run.book.target(level: puzzle.level, slot: puzzle.slot)
            * (boss?.targetMultiplier ?? 1)

        let targetHandSize = run.effectiveHandSize(boss: boss)
        while puzzle.hand.count > targetHandSize {
            puzzle.pool.put(puzzle.hand.removeLast())
        }
        puzzle.hand.append(contentsOf: puzzle.pool.draw(&run.streams.pool,
                                                        count: targetHandSize - puzzle.hand.count))
        puzzle.handSize = puzzle.hand.count
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
            puzzle.hand.remove(at: index)
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
        puzzle.hand.append(digit)
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
                puzzle.hand.remove(at: index)
            } else {
                continue
            }
            puzzle.board.fill(square, with: digit, by: .player)
        }
        Actions.updatePhase(&puzzle)
        run.puzzle = puzzle
        puzzle.assertConservation()
    }
}
#endif
