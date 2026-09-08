import XCTest
@testable import ProbablySudokuEngine

/// The playful route labels describe an actual challenge ladder, not three
/// differently tinted copies of one board. Book sidegrades preserve that order.
final class RouteDifficultyTests: XCTestCase {
    func testEveryBookAndLevelProgressesFromEasyToHarderToBoss() {
        XCTAssertEqual(PuzzleSlot.allCases.map(\.difficulty), [.easy, .medium, .boss])
        XCTAssertEqual(Difficulty.allCases.map(\.givens), [41, 35, 29])
        XCTAssertEqual(Difficulty.allCases.map(\.targetMultiplier), [1, 1.5, 2])

        for book in Book.allCases {
            let givens = Difficulty.allCases.map { book.givens(for: $0) }
            XCTAssertGreaterThan(givens[0], givens[1], book.rawValue)
            XCTAssertGreaterThan(givens[1], givens[2], book.rawValue)
            XCTAssertEqual(givens[0] - givens[1], 6)
            XCTAssertEqual(givens[1] - givens[2], 6)

            for level in 1...9 {
                let targets = PuzzleSlot.allCases.map { book.target(level: level, slot: $0) }
                XCTAssertLessThan(targets[0], targets[1], "\(book.rawValue), Level \(level)")
                XCTAssertLessThan(targets[1], targets[2], "\(book.rawValue), Level \(level)")
                for boss in BossModifier.allCases {
                    XCTAssertGreaterThan(targets[2] * boss.targetMultiplier, targets[1])
                }
            }
        }
    }

    func testRealRouteBoardsUseTheirSlotDifficultyAndHaveUniqueSolutions() throws {
        for slot in PuzzleSlot.allCases {
            var run = RunState(seed: "route-challenge-\(slot.rawValue)")
            run.slot = slot
            if slot == .boss { run.pendingBoss = .editor }
            let puzzle = try PuzzleState.create(run: &run)
            XCTAssertEqual(puzzle.difficulty, slot.difficulty)
            XCTAssertEqual(puzzle.board.isGiven.filter { $0 }.count, slot.difficulty.givens)
            XCTAssertEqual(puzzle.target, Targets.target(level: 1, slot: slot))
            XCTAssertEqual(puzzle.boss, slot == .boss ? .editor : nil)

            let grid = Square.all.map { square -> UInt8 in
                puzzle.board.isGiven[square.index]
                    ? UInt8(puzzle.board.correctDigit(at: square).rawValue) : 0
            }
            XCTAssertEqual(Solver.countSolutions(grid, limit: 2), 1)
            let grade = Solver.grade(grid)
            switch slot {
            case .easy: XCTAssertLessThanOrEqual(grade, .hiddenSingle)
            case .medium: XCTAssertLessThan(grade, .unsolved)
            case .boss: XCTAssertEqual(grade, .unsolved)
            }

            // Existing active boards and their deterministic stream positions
            // survive a save/load verbatim; relabeling must never redeal them.
            run.puzzle = puzzle
            let saved = try Game(run: run).encoded()
            XCTAssertEqual(try Game(decoding: saved).encoded(), saved)
        }
    }
}
