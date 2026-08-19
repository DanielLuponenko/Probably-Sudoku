import Foundation

public enum PuzzlePhase: String, Codable, Sendable {
    case playing
    /// Target met — the player picks Cash Out or Keep Filling (§7).
    case won
    /// Playing on past the target: score is frozen, clears bank coins instead.
    case keepFilling
    case failed
    case cashedOut
}

/// One sudoku board with one score target.
public struct PuzzleState: Codable, Sendable {
    public let level: Int
    public let slot: PuzzleSlot
    public let difficulty: Difficulty

    public var board: Board
    public var pool: Pool
    public var hand: [Digit]

    public var handSize: Int
    public var turnNumber: Int
    public var turnsMax: Int
    /// How many numbers have gone back to the Pool this Turn (§5.1).
    public var tossedThisTurn: Int
    public var tossAllowance: Int

    public var score: Int
    public let target: Int
    public var cluesRemaining: Int

    public var boss: BossModifier?
    public var censoredDigit: Digit?

    public var phase: PuzzlePhase
    public var keepFillingCoins: Int

    /// Puzzle-scoped scaling state — Rolling Presses' clear count, the Rose
    /// Marker's accumulated mult, Fresh Ink, Paper Crane. Cleared every Puzzle.
    public var itemState: [String: Double] = [:]
    public var armedFlags: Set<OneShotFlag> = []

    public var isBoss: Bool { slot == .boss }
    public var turnsRemaining: Int { max(0, turnsMax - turnNumber + 1) }
    public var tossesRemaining: Int { max(0, tossAllowance - tossedThisTurn) }
    public var canUseClue: Bool { cluesRemaining > 0 && boss?.disablesClues != true }
    /// §4 — what the player could work out for themselves. The UI must never
    /// show this; it exists for tests and for the tutorial.
    public func poolCount(of digit: Digit) -> Int { pool[digit] }
}

// MARK: - Creating a Puzzle

public extension PuzzleState {

    static func create(run: inout RunState) throws -> PuzzleState {
        let slot = run.slot
        let difficulty = slot.difficulty

        // A Boss Modifier is rolled and applied *before* the Hand is drawn (§4),
        // because The Editor changes how many numbers that first Hand holds.
        var boss: BossModifier?
        var censored: Digit?
        if slot == .boss {
            boss = BossModifier.roll(&run.streams.boss)
            if boss?.censorsARandomDigit == true {
                censored = BossModifier.rollCensoredDigit(&run.streams.boss)
            }
        }

        let generated = try Generator.generate(&run.streams.board, difficulty: difficulty)
        let board = Board(generated)
        var pool = Pool(blanksOf: board)

        let handSize = run.effectiveHandSize(boss: boss)
        let hand = pool.draw(&run.streams.pool, count: handSize)

        let puzzle = PuzzleState(
            level: run.level,
            slot: slot,
            difficulty: difficulty,
            board: board,
            pool: pool,
            hand: hand,
            handSize: handSize,
            turnNumber: 1,
            turnsMax: run.effectiveTurns(boss: boss),
            tossedThisTurn: 0,
            tossAllowance: run.effectiveTossAllowance(boss: boss),
            score: 0,
            target: Targets.target(level: run.level, slot: slot),
            cluesRemaining: run.effectiveClues(boss: boss),
            boss: boss,
            censoredDigit: censored,
            phase: .playing,
            keepFillingCoins: 0
        )
        puzzle.assertConservation()
        return puzzle
    }

    func assertConservation() {
        assert(Conservation.check(board: board, pool: pool, hand: hand) == nil,
               Conservation.check(board: board, pool: pool, hand: hand) ?? "")
    }
}

// MARK: - Outcomes reported back to the UI

public struct PlacementOutcome: Sendable, Equatable {
    public var correct = false
    public var points = 0
    public var penalty = 0
    public var lineClears: [Unit] = []
    public var lineClearPoints: [Int] = []
    public var fullClear = false
    public var fullClearPoints = 0
    public var coinsEarned = 0
    public var numbersDrawn = 0
    public var returnedToHand = false
    /// Set when this event was cancelled outright by The Censor or The Mirror.
    public var censored = false

    public var totalPoints: Int { points + lineClearPoints.reduce(0, +) + fullClearPoints }
}

public enum PlacementError: Error, Equatable, Sendable {
    case squareNotBlank
    case numberNotInHand
    case noCluesLeft
    case cluesDisabled
    case tossAllowanceSpent
    case puzzleNotPlayable
}
