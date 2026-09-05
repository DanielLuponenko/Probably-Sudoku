import Foundation
import XCTest
@testable import ProbablySudokuEngine

final class BookTests: XCTestCase {
    func testBookTwoHasThreeFewerGivensAtEverySlot() throws {
        for slot in PuzzleSlot.allCases {
            var run = RunState(seed: "book-two-\(slot.rawValue)", book: .slightlyHarder)
            run.slot = slot
            let puzzle = try PuzzleState.create(run: &run)
            let givenCount = puzzle.board.isGiven.filter { $0 }.count
            XCTAssertEqual(givenCount, Book.slightlyHarder.givens(for: slot.difficulty))
            XCTAssertEqual(givenCount, slot.difficulty.givens - 3)
            XCTAssertEqual(puzzle.target, Targets.target(level: 1, slot: slot))
        }
    }

    func testBookThreeHasBookTwoGivensAndOnePointTwoFiveTargets() throws {
        for slot in PuzzleSlot.allCases {
            var run = RunState(seed: "book-three-\(slot.rawValue)", book: .noPressure)
            run.slot = slot
            let puzzle = try PuzzleState.create(run: &run)
            XCTAssertEqual(puzzle.board.isGiven.filter { $0 }.count, slot.difficulty.givens - 3)
            XCTAssertEqual(puzzle.target, Int(Double(Targets.target(level: 1, slot: slot)) * 1.25))
        }
    }

    func testBookFourHasSixFewerGivensOnePointFiveTargetsAndThreeCoins() throws {
        for slot in PuzzleSlot.allCases {
            var run = RunState(seed: "book-four-\(slot.rawValue)", book: .bites)
            run.slot = slot
            let puzzle = try PuzzleState.create(run: &run)
            XCTAssertEqual(puzzle.board.isGiven.filter { $0 }.count, slot.difficulty.givens - 6)
            XCTAssertEqual(puzzle.target, Int(Double(Targets.target(level: 1, slot: slot)) * 1.5))
        }
        XCTAssertEqual(RunState(seed: "book-four-coins", book: .bites).coins, 3)
    }

    func testBookPersistsAndOldSaveDefaultsToBookOne() throws {
        let bookTwo = Game(seed: "book-save", book: .slightlyHarder)
        XCTAssertEqual(try Game(decoding: bookTwo.encoded()).run.book, .slightlyHarder)
        let bookThree = Game(seed: "book-three-save", book: .noPressure)
        XCTAssertEqual(try Game(decoding: bookThree.encoded()).run.book, .noPressure)
        let bookFour = Game(seed: "book-four-save", book: .bites)
        XCTAssertEqual(try Game(decoding: bookFour.encoded()).run.book, .bites)

        let bookOne = Game(seed: "old-book-save")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bookOne.encoded()) as? [String: Any])
        object.removeValue(forKey: "book")
        let oldData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertEqual(try Game(decoding: oldData).run.book, .probably)
    }

    func testEveryBookStillContainsTwentySevenPuzzles() {
        var run = RunState(seed: "book-two-length", book: .slightlyHarder)
        var puzzles = 0
        while run.advance() { puzzles += 1 }
        XCTAssertEqual(puzzles + 1, 27)
        XCTAssertEqual(run.outcome, .bookCompleted)
    }
}
