import Foundation

/// The facade the app talks to. Everything below it is value types, so the UI
/// can hold a `Game`, observe it, and never worry about aliasing.
public struct Game: Sendable {
    public internal(set) var run: RunState

    public init(seed: String, startingBoard: StartingBoard, obstacle: Obstacle = .none) {
        run = RunState(seed: seed, startingBoard: startingBoard, obstacle: obstacle)
    }
    public init(run: RunState) { self.run = run }

    public var puzzle: PuzzleState? { run.puzzle }
    public var shop: ShopState? { run.shop }
    public var isOver: Bool { run.outcome != nil }

    /// Deals the current Level and slot's board.
    public mutating func startPuzzle() throws {
        run.shop = nil
        run.puzzle = try PuzzleState.create(run: &run)
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
        run.advance()
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
    }

    /// Places exactly one selected Marker on a known blank square. Replacing a
    /// marker already on that square keeps every Marker individually testable.
    mutating func qaSetMarker(_ defID: String, at square: Square) {
        guard Catalog.item(defID)?.kind == .marker else { return }
        run.markers.removeAll { $0.covers(square) }
        run.markers.append(OwnedMarker(defID: defID, boughtAtLevel: run.level,
                                       pricePaid: 0, squares: [square]))
    }

    mutating func qaSetBuff(_ defID: String) {
        guard Catalog.item(defID)?.kind == .buff else { return }
        run.buffs = [OwnedBuff(defID: defID, pricePaid: 0)]
    }

    /// Applies a selected Boss to the current Puzzle, including its standing
    /// limits, while preserving the board's number-conservation invariant.
    mutating func qaSetBoss(_ boss: BossModifier) {
        guard var puzzle = run.puzzle else { return }

        puzzle.boss = boss
        puzzle.censoredDigit = boss.censorsARandomDigit
            ? BossModifier.rollCensoredDigit(&run.streams.boss)
            : nil
        puzzle.turnsMax = run.effectiveTurns(boss: boss)
        puzzle.turnNumber = min(puzzle.turnNumber, puzzle.turnsMax)
        puzzle.tossAllowance = run.effectiveTossAllowance(boss: boss)
        puzzle.cluesRemaining = run.effectiveClues(boss: boss)

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
