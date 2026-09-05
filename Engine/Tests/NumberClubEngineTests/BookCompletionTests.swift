import XCTest
@testable import ProbablySudokuEngine

final class BookCompletionTests: XCTestCase {
    func testCashOutRecordsTheHighestPuzzleScore() throws {
        var game = Game(seed: "book-record")
        try game.startPuzzle()
        game.qaMeetTarget()
        let firstScore = try XCTUnwrap(game.puzzle?.score)
        _ = try game.cashOut()
        XCTAssertEqual(game.run.bestPuzzleScore, firstScore)

        game.openShop()
        XCTAssertTrue(game.advance())
        try game.startPuzzle()
        game.qaMeetTarget()
        let secondScore = try XCTUnwrap(game.puzzle?.score)
        _ = try game.cashOut()

        XCTAssertEqual(game.run.bestPuzzleScore, max(firstScore, secondScore))
    }

    func testQACompletionUsesTheNormalTerminalAdvance() {
        var game = Game(seed: "book-complete")
        game.qaCompleteBook()

        XCTAssertEqual(game.run.outcome, .bookCompleted)
        XCTAssertEqual(game.run.level, 9)
        XCTAssertEqual(game.run.slot, .boss)
        XCTAssertGreaterThan(game.run.bestPuzzleScore, 0)
        XCTAssertNil(game.puzzle)
    }

    func testPreCompletionRecordSaveDefaultsBestScoreToZero() throws {
        let run = RunState(seed: "legacy-book")
        let encoded = try JSONEncoder().encode(run)
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded)
            as? [String: Any])
        object.removeValue(forKey: "bestPuzzleScore")
        let legacyData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertEqual(try JSONDecoder().decode(RunState.self, from: legacyData).bestPuzzleScore, 0)
    }
}
