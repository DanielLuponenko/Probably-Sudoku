import Foundation

/// The facade the app talks to. Everything below it is value types, so the UI
/// can hold a `Game`, observe it, and never worry about aliasing.
public struct Game: Sendable {
    public internal(set) var run: RunState

    public init(seed: String, startingBoard: StartingBoard) {
        run = RunState(seed: seed, startingBoard: startingBoard)
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
    public mutating func toss(_ handIndices: [Int]) throws -> Int {
        try Actions.toss(&run, handIndices: handIndices)
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
