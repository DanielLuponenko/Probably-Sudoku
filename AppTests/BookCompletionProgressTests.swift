import XCTest
import Foundation
import ProbablySudokuEngine
@testable import ProbablySudoku

/// All migration checks encode/decode in-memory values. Never call RunStore's
/// disk-backed progress accessors or mutate the player's completion file.
final class BookCompletionProgressTests: XCTestCase {
    func testLegacyTwoBookJSONRetainsCompletedIdentitiesAndObstacleUnlock() throws {
        let progress = try legacyProgress()

        XCTAssertEqual(progress.completedBooks, Set(["probably", "slightlyHarder"]))
        XCTAssertEqual(progress.completedBooks.count, 2)
        XCTAssertEqual(progress.booksCompleted, 2)
        XCTAssertEqual(progress.unlockedObstacle, 3)
    }

    func testOutOfOrderTwelfthBookCountsOnceWithoutInventingTheFirstElevenCompletions() throws {
        var progress = RunStore.Progress()
        let lastBook = try book(volume: 12)

        XCTAssertTrue(progress.recordCompletion(of: lastBook))

        XCTAssertEqual(progress.completedBooks, Set([lastBook.rawValue]))
        XCTAssertEqual(progress.completedBooks.count, 1)
        XCTAssertEqual(progress.booksCompleted, 0, "The legacy field remains a contiguous prefix")
        XCTAssertEqual(progress.unlockedObstacle, 2)
    }

    func testReplayingACompletedBookDoesNotIncreaseCountOrUnlockAgain() throws {
        var progress = RunStore.Progress()
        let lastBook = try book(volume: 12)
        XCTAssertTrue(progress.recordCompletion(of: lastBook))

        for _ in 0..<3 {
            XCTAssertFalse(progress.recordCompletion(of: lastBook))
        }

        XCTAssertEqual(progress.completedBooks, Set([lastBook.rawValue]))
        XCTAssertEqual(progress.booksCompleted, 0)
        XCTAssertEqual(progress.unlockedObstacle, 2)
    }

    func testClosingGapsAdvancesOnlyTheLegacyContiguousPrefix() throws {
        var progress = RunStore.Progress()
        XCTAssertTrue(progress.recordCompletion(of: try book(volume: 12)))
        XCTAssertTrue(progress.recordCompletion(of: .noPressure))
        XCTAssertEqual(progress.booksCompleted, 0)

        XCTAssertTrue(progress.recordCompletion(of: .probably))
        XCTAssertEqual(progress.booksCompleted, 1)
        XCTAssertEqual(progress.completedBooks.count, 3)

        XCTAssertTrue(progress.recordCompletion(of: .slightlyHarder))
        XCTAssertEqual(progress.booksCompleted, 3,
                       "Volume 3 was already completed, so closing Volume 2 fills the prefix")
        XCTAssertEqual(progress.completedBooks.count, 4)
        XCTAssertEqual(progress.unlockedObstacle, 5)
    }

    func testFirstNewCompletionMaterializesLegacyIdentitiesAndRejectsLegacyReplay() throws {
        var progress = try legacyProgress()
        XCTAssertFalse(progress.recordCompletion(of: .probably))
        XCTAssertEqual(progress.unlockedObstacle, 3)

        XCTAssertTrue(progress.recordCompletion(of: .noPressure))
        XCTAssertEqual(progress.completedBooks, Set(["probably", "slightlyHarder", "noPressure"]))
        XCTAssertEqual(progress.booksCompleted, 3)
        XCTAssertEqual(progress.unlockedObstacle, 4)
    }

    func testNewProgressRoundTripKeepsOutOfOrderIdentitiesAndReplayProtection() throws {
        var progress = RunStore.Progress()
        let lastBook = try book(volume: 12)
        XCTAssertTrue(progress.recordCompletion(of: lastBook))
        XCTAssertTrue(progress.recordCompletion(of: .probably))
        let encoded = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(RunStore.Progress.self, from: encoded)

        XCTAssertEqual(restored.completedBooks, progress.completedBooks)
        XCTAssertEqual(restored.booksCompleted, 1)
        XCTAssertEqual(restored.unlockedObstacle, 3)
        XCTAssertFalse(restored.recordCompletion(of: lastBook))
        XCTAssertFalse(restored.recordCompletion(of: .probably))
        XCTAssertEqual(restored.unlockedObstacle, 3)
    }

    func testExplicitNewIdentitySetIsAuthoritativeRatherThanRemigratingLegacyCounter() throws {
        let json = Data(#"{"unlockedObstacle":3,"booksCompleted":2,"completedBookIDs":[]}"#.utf8)
        let progress = try JSONDecoder().decode(RunStore.Progress.self, from: json)

        XCTAssertTrue(progress.completedBooks.isEmpty,
                      "Only a missing identity set should migrate the old contiguous count")
    }

    func testCompletingAllTwelveBooksCapsObstacleUnlockAtNine() {
        var progress = RunStore.Progress()
        for book in Book.allCases.reversed() {
            XCTAssertTrue(progress.recordCompletion(of: book))
            XCTAssertLessThanOrEqual(progress.unlockedObstacle, 9)
        }
        XCTAssertEqual(progress.completedBooks.count, 12)
        XCTAssertEqual(progress.booksCompleted, 12)
        XCTAssertEqual(progress.unlockedObstacle, 9)
        for book in Book.allCases {
            XCTAssertFalse(progress.recordCompletion(of: book))
        }
        XCTAssertEqual(progress.unlockedObstacle, 9)
    }

    private func legacyProgress() throws -> RunStore.Progress {
        let json = Data(#"{"unlockedObstacle":3,"booksCompleted":2}"#.utf8)
        return try JSONDecoder().decode(RunStore.Progress.self, from: json)
    }

    private func book(volume: Int) throws -> Book {
        try XCTUnwrap(Book.allCases.first { $0.volume == volume })
    }
}
