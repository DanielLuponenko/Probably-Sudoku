import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

final class CompletedBookSelectionTests: XCTestCase {
    func testEveryFinishedVolumeReturnsToItselfWithItsNextEarnedObstacle() {
        for book in Book.allCases {
            for obstacle in Obstacle.allCases {
                let nextRawValue = min(obstacle.rawValue + 1, Obstacle.allCases.count)
                let selection = CompletedBookSelection(
                    book: book, completedObstacle: obstacle,
                    progressByBookID: [book.rawValue: nextRawValue])
                XCTAssertEqual(selection.edition.rule, book)
                XCTAssertEqual(selection.obstacle.rawValue, nextRawValue)
            }
        }
    }

    func testProgressOnAnotherBookCannotUnlockThisBooksNextChallenge() {
        let books = Array(Book.allCases)
        let selection = CompletedBookSelection(
            book: books[0], completedObstacle: .none,
            progressByBookID: [books[1].rawValue: Obstacle.allCases.count])
        XCTAssertEqual(selection.edition.rule, books[0])
        XCTAssertEqual(selection.obstacle, .none)
    }

    func testMissingProgressKeepsTheCompletedVolumeWithoutInventingAnUnlock() {
        for book in Book.allCases {
            let selection = CompletedBookSelection(book: book, completedObstacle: .none,
                                                   progressByBookID: [:])
            XCTAssertEqual(selection.edition.rule, book)
            XCTAssertEqual(selection.obstacle, .none)
        }
    }
}
