import XCTest
@testable import ProbablySudokuEngine

final class GeneratorTests: XCTestCase {

    private func makePuzzle(_ difficulty: Difficulty, seed: String = "gen") throws -> GeneratedPuzzle {
        var rng = RandomStream(seed: seed, stream: "board")
        return try Generator.generate(&rng, difficulty: difficulty)
    }

    func testSolutionIsAValidCompleteSudoku() throws {
        let puzzle = try makePuzzle(.easy)
        XCTAssertEqual(puzzle.solution.count, 81)
        for unit in Geometry.allUnits {
            let values = Set(unit.map { puzzle.solution[$0.index] })
            XCTAssertEqual(values.count, 9, "unit is not a permutation of 1–9")
        }
    }

    func testGivensCountMatchesDifficulty() throws {
        for difficulty in Difficulty.allCases {
            let puzzle = try makePuzzle(difficulty)
            let givens = puzzle.isGiven.filter { $0 }.count
            XCTAssertEqual(givens, difficulty.givens, "\(difficulty.rawValue) givens")
            XCTAssertEqual(81 - givens, difficulty.blanks)
        }
    }

    func testPuzzleHasExactlyOneSolution() throws {
        for difficulty in Difficulty.allCases {
            let puzzle = try makePuzzle(difficulty)
            var grid = [UInt8](repeating: 0, count: 81)
            for i in 0..<81 where puzzle.isGiven[i] { grid[i] = UInt8(puzzle.solution[i].rawValue) }
            XCTAssertEqual(Solver.countSolutions(grid, limit: 2), 1, "\(difficulty.rawValue) uniqueness")
            XCTAssertEqual(Solver.solve(grid), puzzle.solution)
        }
    }

    func testDifficultyGateHolds() throws {
        // Easy must fall to singles; a Boss must defeat the whole ladder.
        func grade(_ p: GeneratedPuzzle) -> Solver.Technique {
            var grid = [UInt8](repeating: 0, count: 81)
            for i in 0..<81 where p.isGiven[i] { grid[i] = UInt8(p.solution[i].rawValue) }
            return Solver.grade(grid)
        }
        XCTAssertTrue([.nakedSingle, .hiddenSingle].contains(grade(try makePuzzle(.easy))))
        XCTAssertNotEqual(grade(try makePuzzle(.medium)), .unsolved)
        XCTAssertEqual(grade(try makePuzzle(.boss)), .unsolved)
    }

    func testSameSeedGivesSameBoard() throws {
        let a = try makePuzzle(.medium, seed: "repeat-me")
        let b = try makePuzzle(.medium, seed: "repeat-me")
        XCTAssertEqual(a.solution, b.solution)
        XCTAssertEqual(a.isGiven, b.isGiven)
    }

    func testDifferentSeedsGiveDifferentBoards() throws {
        let a = try makePuzzle(.medium, seed: "seed-a")
        let b = try makePuzzle(.medium, seed: "seed-b")
        XCTAssertNotEqual(a.solution, b.solution)
    }

    func testGeneratesAWholeBookWithoutFailing() throws {
        // 27 Puzzles off one board stream — the real workload, and the case
        // where a too-tight difficulty gate would blow the attempt budget.
        var rng = RandomStream(seed: "full-book", stream: "board")
        for level in 1...9 {
            for slot in PuzzleSlot.allCases {
                let puzzle = try Generator.generate(&rng, difficulty: slot.difficulty)
                XCTAssertEqual(puzzle.isGiven.filter { $0 }.count, slot.difficulty.givens,
                               "level \(level) slot \(slot)")
            }
        }
    }
}

final class BoardAndPoolTests: XCTestCase {

    private func makeBoard(_ difficulty: Difficulty = .medium) throws -> Board {
        var rng = RandomStream(seed: "board-tests", stream: "board")
        return Board(try Generator.generate(&rng, difficulty: difficulty))
    }

    func testBoardStartsWithGivensPlacedAndBlanksEmpty() throws {
        let board = try makeBoard(.easy)
        XCTAssertEqual(board.blanks.count, Difficulty.easy.blanks)
        XCTAssertFalse(board.isFull)
        for square in Square.all {
            if board.isGiven[square.index] {
                XCTAssertEqual(board[square], board.correctDigit(at: square))
                XCTAssertEqual(board.filledBy[square.index], .given)
            } else {
                XCTAssertNil(board[square])
            }
        }
    }

    func testPoolHoldsExactlyWhatTheBlanksNeed() throws {
        let board = try makeBoard()
        let pool = Pool(blanksOf: board)
        XCTAssertEqual(pool.total, board.blanks.count)
        XCTAssertNil(Conservation.check(board: board, pool: pool, hand: []))
    }

    func testPoolIsKnowableFromTheBoardAndHand() throws {
        // §4 — the Pool is never shown, but a player who counts always knows
        // it: pool(d) = 9 − board(d) − hand(d). This asserts the engine keeps
        // that identity true after real play, which is what makes the hidden
        // information fair rather than arbitrary.
        var board = try makeBoard()
        var pool = Pool(blanksOf: board)
        var rng = RandomStream(seed: "board-tests", stream: "pool")
        var hand = pool.draw(&rng, count: 6)

        // Play the first four numbers in hand onto squares that want them.
        for _ in 0..<4 {
            guard let handIndex = hand.indices.first(where: { i in
                board.blanks.contains { board.correctDigit(at: $0) == hand[i] }
            }) else { break }
            let digit = hand.remove(at: handIndex)
            let square = board.blanks.first { board.correctDigit(at: $0) == digit }!
            board.fill(square, with: digit, by: .player)
        }

        for d in Digit.all {
            let onBoard = board.count(of: d)
            let inHand = hand.filter { $0 == d }.count
            XCTAssertEqual(pool[d], 9 - onBoard - inHand, "pool count for \(d.rawValue)")
        }
        XCTAssertNil(Conservation.check(board: board, pool: pool, hand: hand))
    }

    func testDrawingEmptiesThePoolExactlyOnce() throws {
        let board = try makeBoard(.boss)
        var pool = Pool(blanksOf: board)
        var rng = RandomStream(seed: "board-tests", stream: "pool")
        let drawn = pool.draw(&rng, count: 1000)
        XCTAssertEqual(drawn.count, Difficulty.boss.blanks)
        XCTAssertTrue(pool.isEmpty)
        XCTAssertNil(pool.draw(&rng))
    }

    func testUnitsCompletedDetectsRowColumnAndBox() throws {
        var board = try makeBoard()
        var completedSomething = false
        for square in board.blanks {
            board.fill(square, with: board.correctDigit(at: square), by: .player)
            if !board.unitsCompleted(at: square).isEmpty { completedSomething = true }
        }
        XCTAssertTrue(completedSomething)
        XCTAssertTrue(board.isFull)
        XCTAssertTrue(board.conflicts().isEmpty)
        // The last placement always completes its row, column and box.
        let last = Square.all.last!
        XCTAssertEqual(Set(board.unitsCompleted(at: last)), [.row, .col, .box])
    }

    func testTargetsFollowTheDoublingLadder() {
        XCTAssertEqual(Targets.target(level: 1, slot: .easy), 1_000)
        XCTAssertEqual(Targets.target(level: 1, slot: .medium), 1_500)
        XCTAssertEqual(Targets.target(level: 1, slot: .boss), 2_000)
        XCTAssertEqual(Targets.target(level: 5, slot: .medium), 24_000)
        XCTAssertEqual(Targets.target(level: 9, slot: .boss), 512_000)
    }
}
