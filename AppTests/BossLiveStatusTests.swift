import XCTest
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

final class BossLiveStatusTests: XCTestCase {
    private func fixture(_ boss: BossModifier, hand: [Digit]) -> Game {
        let solution = (0..<81).map { Digit(($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1)! }
        let board = Board(GeneratedPuzzle(solution: solution, isGiven: Array(repeating: false, count: 81)))
        var pool = Pool(blanksOf: board)
        for digit in hand { XCTAssertTrue(pool.take(digit)) }
        var run = RunState(seed: "boss-clarity-status", book: .noPressure)
        run.slot = .boss
        var puzzle = PuzzleState(level: 1, slot: .boss, difficulty: .boss, board: board,
            pool: pool, hand: hand, handSize: hand.count, turnNumber: 1, turnsMax: 10,
            tossedThisPuzzle: 0, tossAllowance: 4, score: 0, target: 1_000_000,
            cluesRemaining: 4, boss: boss, censoredDigit: nil, blockedDigit: nil,
            bossTurn: nil, phase: .playing, keepFillingCoins: 0)
        puzzle.ensureHandIdentities(seed: run.seed)
        BossRuntime.puzzleStarted(run: run, puzzle: &puzzle)
        run.puzzle = puzzle
        return Game(run: run)
    }

    func testReprintStatusFollowsActualReleaseAndReclosure() throws {
        var game = fixture(.reprintBan, hand: [.one, .one, .two])
        XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(game.puzzle)), "Play a new number")
        _ = try game.place(handIndex: 0, at: Square(0))
        XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(game.puzzle)),
                       "1 already played · choose a new number")
        _ = try game.place(handIndex: 1, at: Square(1))
        var puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertEqual(BossLiveStatus.text(puzzle: puzzle), "Repeats are open")

        XCTAssertTrue(puzzle.pool.take(.three))
        puzzle.appendHandDigits([.three])
        XCTAssertEqual(BossLiveStatus.text(puzzle: puzzle), "1 already played · choose a new number")
        puzzle.obstacleBlockedDigits = [.three]
        XCTAssertEqual(BossLiveStatus.text(puzzle: puzzle), "Repeats are open",
                       "An independently barred new digit must not make repeats appear closed")
        BossRuntime.boundaryStarted(puzzle: &puzzle)
        XCTAssertEqual(BossLiveStatus.text(puzzle: puzzle), "Play a new number")
    }

    func testReprintStatusDoesNotTreatWrongAttemptsAsUsedButIncludesClues() throws {
        var game = fixture(.reprintBan, hand: [.one, .two, .two, .three])
        XCTAssertFalse(try game.place(handIndex: 0, at: Square(1)).correct)
        XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(game.puzzle)), "Play a new number")
        _ = try game.useClue(at: Square(1))
        XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(game.puzzle)),
                       "2 already played · choose a new number")
    }

    func testReprintStatusReflectsReleasedCopyWithoutMutatingSavedState() throws {
        var game = fixture(.reprintBan, hand: [.one, .one, .two])
        _ = try game.place(handIndex: 0, at: Square(0))
        var puzzle = try XCTUnwrap(game.puzzle)
        puzzle.buffState.releasedCard = puzzle.handCards[0].id
        puzzle.buffState.releaseTurn = puzzle.turnNumber
        var run = game.run
        run.puzzle = puzzle
        let restored = try Game(decoding: Game(run: run).encoded())
        let bytes = try restored.encoded()
        for _ in 0..<5 {
            XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(restored.puzzle)), "Repeats are open")
        }
        XCTAssertEqual(try restored.encoded(), bytes)
    }

    func testChainStatusUsesPlainGeometryAndResetsOnNextTurn() throws {
        var game = fixture(.chainStitcher, hand: [.one, .two, .three])
        XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(game.puzzle)),
                       "Place a number to start the chain")
        _ = try game.place(handIndex: 0, at: Square(0))
        XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(game.puzzle)),
                       "Follow the lit row, column or box")
        _ = try game.useClue(at: Square(1))
        XCTAssertEqual(game.puzzle?.bossState.scoring.chainAnchor, Square(0))
        _ = try game.endTurn()
        XCTAssertEqual(BossLiveStatus.text(puzzle: try XCTUnwrap(game.puzzle)),
                       "Place a number to start the chain")
    }
}
