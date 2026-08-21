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

/// The moving part of an extended Boss. Optional storage lets Books saved
/// before this roster existed decode without a migration failure.
public struct BossTurnState: Codable, Sendable {
    public var blockedDigits: Set<Digit> = []
    /// Square -> first Turn on which the foul no longer applies.
    public var fouled: [Square: Int] = [:]
    public var greyed: Set<Square> = []
    public var disabledBookmark: Int?

    public init() {}
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
    /// How many numbers have gone back to the Pool this Puzzle (§5.1).
    public var tossedThisPuzzle: Int
    /// Per Puzzle, not per Turn.
    public var tossAllowance: Int

    public var score: Int
    public var target: Int
    public var cluesRemaining: Int
    /// Correct-play points held until the Turn closes.
    public var pendingBase: Int = 0
    /// The best held-item multiplier earned this Turn. Square-local
    /// multipliers are folded into the queued base score instead.
    public var pendingMult: Double = 1

    public var boss: BossModifier?
    public var censoredDigit: Digit?
    /// Obstacle III — the number that cannot be played this Turn. A digit
    /// rather than a Hand position, because positions shift as the Hand is
    /// played and a moving block is unreadable.
    public var blockedDigit: Digit?
    /// State for Bosses whose restrictions change from one Turn to the next.
    public var bossTurn: BossTurnState?

    public var phase: PuzzlePhase
    public var keepFillingCoins: Int

    /// Puzzle-scoped scaling state — Rolling Presses' clear count, the Rose
    /// Marker's accumulated mult, Fresh Ink, Paper Crane. Cleared every Puzzle.
    public var itemState: [String: Double] = [:]
    public var armedFlags: Set<OneShotFlag> = []

    private enum CodingKeys: String, CodingKey {
        case level, slot, difficulty, board, pool, hand, handSize, turnNumber,
             turnsMax, tossedThisPuzzle, tossAllowance, score, target,
             cluesRemaining, pendingBase, pendingMult, boss,
             censoredDigit, blockedDigit, bossTurn, phase, keepFillingCoins,
             itemState, armedFlags
    }

    init(level: Int, slot: PuzzleSlot, difficulty: Difficulty, board: Board,
         pool: Pool, hand: [Digit], handSize: Int, turnNumber: Int,
         turnsMax: Int, tossedThisPuzzle: Int, tossAllowance: Int, score: Int,
         target: Int, cluesRemaining: Int, boss: BossModifier?,
         censoredDigit: Digit?, blockedDigit: Digit?, bossTurn: BossTurnState?,
         phase: PuzzlePhase, keepFillingCoins: Int) {
        self.level = level
        self.slot = slot
        self.difficulty = difficulty
        self.board = board
        self.pool = pool
        self.hand = hand
        self.handSize = handSize
        self.turnNumber = turnNumber
        self.turnsMax = turnsMax
        self.tossedThisPuzzle = tossedThisPuzzle
        self.tossAllowance = tossAllowance
        self.score = score
        self.target = target
        self.cluesRemaining = cluesRemaining
        self.boss = boss
        self.censoredDigit = censoredDigit
        self.blockedDigit = blockedDigit
        self.bossTurn = bossTurn
        self.phase = phase
        self.keepFillingCoins = keepFillingCoins
    }

    /// Books saved before KAN-47 have no queued-score fields. They represent
    /// completed app state, so restore them with an empty queue.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = try c.decode(Int.self, forKey: .level)
        slot = try c.decode(PuzzleSlot.self, forKey: .slot)
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        board = try c.decode(Board.self, forKey: .board)
        pool = try c.decode(Pool.self, forKey: .pool)
        hand = try c.decode([Digit].self, forKey: .hand)
        handSize = try c.decode(Int.self, forKey: .handSize)
        turnNumber = try c.decode(Int.self, forKey: .turnNumber)
        turnsMax = try c.decode(Int.self, forKey: .turnsMax)
        tossedThisPuzzle = try c.decode(Int.self, forKey: .tossedThisPuzzle)
        tossAllowance = try c.decode(Int.self, forKey: .tossAllowance)
        score = try c.decode(Int.self, forKey: .score)
        target = try c.decode(Int.self, forKey: .target)
        cluesRemaining = try c.decode(Int.self, forKey: .cluesRemaining)
        pendingBase = try c.decodeIfPresent(Int.self, forKey: .pendingBase) ?? 0
        pendingMult = try c.decodeIfPresent(Double.self, forKey: .pendingMult) ?? 1
        boss = try c.decodeIfPresent(BossModifier.self, forKey: .boss)
        censoredDigit = try c.decodeIfPresent(Digit.self, forKey: .censoredDigit)
        blockedDigit = try c.decodeIfPresent(Digit.self, forKey: .blockedDigit)
        bossTurn = try c.decodeIfPresent(BossTurnState.self, forKey: .bossTurn)
        phase = try c.decode(PuzzlePhase.self, forKey: .phase)
        keepFillingCoins = try c.decode(Int.self, forKey: .keepFillingCoins)
        itemState = try c.decodeIfPresent([String: Double].self, forKey: .itemState) ?? [:]
        armedFlags = try c.decodeIfPresent(Set<OneShotFlag>.self, forKey: .armedFlags) ?? []
    }

    public var isBoss: Bool { slot == .boss }
    public var pendingMultiplier: Double {
        let puzzleAdditive = Resolver.globalAdditive(self)
        let bossMultiplier = boss?.halvesScoreMultiplier == true ? 0.5 : 1
        return (pendingMult + puzzleAdditive) * bossMultiplier
    }
    public var pendingScore: Int {
        Int((Double(pendingBase) * pendingMultiplier).rounded(.down))
    }
    mutating func bankPending() {
        score += pendingScore
        pendingBase = 0
        pendingMult = 1
    }
    public var turnsRemaining: Int { max(0, turnsMax - turnNumber + 1) }
    public var tossesRemaining: Int { max(0, tossAllowance - tossedThisPuzzle) }
    public var canUseClue: Bool { cluesRemaining > 0 && boss?.disablesClues != true }
    public var blockedDigits: Set<Digit> {
        var digits = bossTurn?.blockedDigits ?? []
        if let blockedDigit { digits.insert(blockedDigit) }
        return digits
    }
    public func isBlocked(_ digit: Digit) -> Bool { blockedDigits.contains(digit) }
    public var disabledBookmark: Int? { bossTurn?.disabledBookmark }
    public var barredSquares: Set<Square> {
        let fouled = bossTurn.map { Set($0.fouled.keys) } ?? []
        return fouled.union(bossTurn?.greyed ?? [])
    }
    public func isBarred(_ square: Square) -> Bool { barredSquares.contains(square) }
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

        let generated = try Generator.generate(&run.streams.board, difficulty: difficulty,
                                               givens: run.book.givens(for: difficulty))
        let board = Board(generated)
        var pool = Pool(blanksOf: board)

        let handSize = run.effectiveHandSize(boss: boss)
        let hand = pool.draw(&run.streams.pool, count: handSize)

        var puzzle = PuzzleState(
            level: run.level,
            slot: slot,
            difficulty: difficulty,
            board: board,
            pool: pool,
            hand: hand,
            handSize: handSize,
            turnNumber: 1,
            turnsMax: run.effectiveTurns(boss: boss),
            tossedThisPuzzle: 0,
            tossAllowance: run.effectiveTossAllowance(boss: boss),
            score: 0,
            target: run.book.target(level: run.level, slot: slot)
                * (boss?.targetMultiplier ?? 1),
            cluesRemaining: run.effectiveClues(boss: boss),
            boss: boss,
            censoredDigit: censored,
            blockedDigit: nil,
            bossTurn: nil,
            phase: .playing,
            keepFillingCoins: 0
        )
        if run.obstacle.blocksANumberEachTurn {
            puzzle.blockedDigit = Self.pickBlocked(from: puzzle.hand, rng: &run.streams.pool)
        }
        puzzle.startBossTurn(&run)

        puzzle.assertConservation()
        return puzzle
    }

    /// Chosen from what is actually in hand, so the block always costs
    /// something — barring a number the player does not hold is no obstacle.
    static func pickBlocked(from hand: [Digit], rng: inout RandomStream) -> Digit? {
        pickBlocked(from: hand, barring: [], rng: &rng)
    }

    static func pickBlocked(from hand: [Digit], barring taken: Set<Digit>,
                            rng: inout RandomStream) -> Digit? {
        let held = Array(Set(hand).subtracting(taken)).sorted()
        guard !held.isEmpty else { return nil }
        return held[rng.int(held.count)]
    }

    /// Everything an extended Boss does when a new Turn begins. This happens
    /// after refill, so a barred number always exists in the Hand.
    mutating func startBossTurn(_ run: inout RunState) {
        guard let boss else {
            bossTurn = nil
            return
        }

        var state = bossTurn ?? BossTurnState()
        state.blockedDigits = []
        state.greyed = []
        state.fouled = state.fouled.filter { $0.value > turnNumber }

        for _ in 0..<boss.barsNumbersEachTurn {
            guard let digit = Self.pickBlocked(from: hand, barring: state.blockedDigits,
                                                rng: &run.streams.boss) else { break }
            state.blockedDigits.insert(digit)
        }

        if boss.foulsSquaresEachTurn {
            let count = board.blanks.count < 6 ? 1 : 3
            for _ in 0..<count {
                let unavailable = Set(state.fouled.keys).union(state.greyed)
                let open = board.blanks.filter { !unavailable.contains($0) }
                guard !open.isEmpty else { break }
                state.fouled[open[run.streams.boss.int(open.count)]] = turnNumber + 2
            }
        }

        if boss.greysARowEachTurn {
            let candidates = Geometry.rows.map { $0.filter(board.isBlank) }.filter { !$0.isEmpty }
            if !candidates.isEmpty {
                state.greyed = Set(candidates[run.streams.boss.int(candidates.count)])
            }
        }

        if boss.greysABoxEachTurn {
            let candidates = Geometry.boxes.map { $0.filter(board.isBlank) }.filter { !$0.isEmpty }
            if !candidates.isEmpty {
                state.greyed = Set(candidates[run.streams.boss.int(candidates.count)])
            }
        }

        state.disabledBookmark = boss.disablesABookmarkEachTurn && !run.bookmarks.isEmpty
            ? run.streams.boss.int(run.bookmarks.count) : nil
        bossTurn = state
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
    case numberBlocked
    case squareBarred
    case buffsDisabled
    case puzzleNotPlayable
}
