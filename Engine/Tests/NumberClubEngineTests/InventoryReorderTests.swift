import XCTest
@testable import ProbablySudokuEngine

final class InventoryReorderTests: XCTestCase {
    func testReorderingPreservesSleepingCopyBoardCoinsAndRandomnessAndSurvivesResume() throws {
        var run = RunState(seed: "reorder-editor")
        run.slot = .boss
        run.pendingBoss = .unluckyLucky
        run.bookmarks = ["bm_morning_edition", "bm_evening_edition", Bookmarks.syndication].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5)
        }
        var game = Game(run: run)
        try game.startPuzzle()
        game.run.puzzle?.bossTurn?.disabledBookmark = 1
        let original = game.run.bookmarks.map(\.id)
        let sleeping = original[1]
        let board = game.puzzle?.board.placed
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let streams = try encoder.encode(game.run.streams)
        let coins = game.run.coins
        XCTAssertTrue(game.reorderBookmark(id: original[0], to: 2))
        XCTAssertEqual(game.run.bookmarks.map(\.id), [original[1], original[2], original[0]])
        XCTAssertEqual(game.run.bookmarks[try XCTUnwrap(game.puzzle?.disabledBookmark)].id, sleeping)
        XCTAssertEqual(game.run.coins, coins)
        XCTAssertEqual(game.puzzle?.board.placed, board)
        XCTAssertEqual(try encoder.encode(game.run.streams), streams)
        let bytes = try game.encoded()
        let restored = try Game(decoding: bytes)
        XCTAssertEqual(restored.run.bookmarks.map(\.id), game.run.bookmarks.map(\.id))
        XCTAssertEqual(restored.puzzle?.board.placed, game.puzzle?.board.placed)
        XCTAssertEqual(restored.puzzle?.board.filledBy, game.puzzle?.board.filledBy)
        XCTAssertEqual(restored.puzzle?.disabledBookmark, game.puzzle?.disabledBookmark)
        XCTAssertEqual(restored.run.coins, coins)
        XCTAssertEqual(try encoder.encode(restored.run.streams), streams)
    }

    func testStaleOutOfRangeAndNoOpReorderDoesNotMutateSave() throws {
        var game = Game(seed: "reorder-rejection")
        game.run.bookmarks = [OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 5)]
        let bytes = try game.encoded()
        XCTAssertFalse(game.reorderBookmark(id: UUID(), to: 0))
        XCTAssertFalse(game.reorderBookmark(id: game.run.bookmarks[0].id, to: -1))
        XCTAssertFalse(game.reorderBookmark(id: game.run.bookmarks[0].id, to: 1))
        XCTAssertFalse(game.reorderBookmark(id: game.run.bookmarks[0].id, to: 0))
        XCTAssertEqual(try game.encoded(), bytes)
    }

    func testLegacyBookmarksMigrateDeterministicallyWithSeparateIdentitiesAndNoRewardChange() throws {
        var run = RunState(seed: "legacy-bookmarks")
        run.bookmarks = (0..<2).map { _ in OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 2, pricePaid: 5) }
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(run)) as? [String: Any])
        object["bookmarks"] = try XCTUnwrap(object["bookmarks"] as? [[String: Any]]).map { item in
            var legacy = item
            legacy.removeValue(forKey: "id")
            return legacy
        }
        let bytes = try JSONSerialization.data(withJSONObject: object)
        let first = try Game(decoding: bytes)
        let second = try Game(decoding: bytes)
        XCTAssertEqual(first.run.bookmarks.map(\.id), second.run.bookmarks.map(\.id))
        XCTAssertEqual(Set(first.run.bookmarks.map(\.id)).count, 2)
        XCTAssertEqual(first.run.coins, run.coins)
        XCTAssertEqual(first.run.bookmarks.map(\.pricePaid), [5, 5])
        XCTAssertEqual(first.run.bookmarks.map(\.boughtAtLevel), [2, 2])
        XCTAssertEqual(try Game(decoding: first.encoded()).run.bookmarks.map(\.id), first.run.bookmarks.map(\.id))
    }
}
