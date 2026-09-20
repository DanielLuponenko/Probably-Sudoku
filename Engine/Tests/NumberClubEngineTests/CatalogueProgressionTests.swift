import XCTest
@testable import ProbablySudokuEngine

final class CatalogueProgressionTests: XCTestCase {
    func testAdvanceRejectsBriefingActiveWonAndPendingChoiceWithoutMutation() throws {
        let briefing = Game(seed: "advance-guard")
        var active = briefing
        try active.startPuzzle()
        var won = active
        won.run.puzzle!.score = won.run.puzzle!.target
        won.run.puzzle!.phase = .won
        var choosing = briefing
        choosing.run.pendingItemDecisions = [ItemDecision(id: UUID(), sourceID: Buffs.detour,
            contextKey: choosing.run.itemContextKey, kind: "buff.route", title: "Choose layout",
            options: [.init(id: "first", title: "First")], allowsCancel: false, consumedOnReveal: true)]
        for var game in [briefing, active, won, choosing] {
            let before = try game.encoded()
            XCTAssertFalse(game.advance())
            XCTAssertEqual(try game.encoded(), before)
        }
    }

    func testShopDepartureAdvancesExactlyOnceAndTheNextBoardCanStart() throws {
        var game = Game(seed: "advance-shop-once")
        try game.startPuzzle()
        game.run.puzzle!.score = game.run.puzzle!.target
        game.run.puzzle!.phase = .won
        _ = try game.cashOut()
        game.openShop()
        XCTAssertNotNil(game.shop)
        XCTAssertTrue(game.advance())
        XCTAssertEqual(game.run.slot, .medium)
        XCTAssertNil(game.shop)
        XCTAssertNil(game.puzzle)
        let after = try game.encoded()
        for _ in 0..<5 {
            XCTAssertFalse(game.advance())
            XCTAssertEqual(try game.encoded(), after)
        }
        var resumed = try Game(decoding: after)
        XCTAssertFalse(resumed.advance())
        XCTAssertEqual(try resumed.encoded(), after)
        try resumed.startPuzzle()
        XCTAssertEqual(resumed.puzzle?.slot, .medium)
    }

    func testDirectCashedOutAdvanceRetiresTheFinishedBoardOnce() throws {
        var game = Game(seed: "advance-cashed-out")
        try game.startPuzzle()
        game.run.puzzle!.score = game.run.puzzle!.target
        game.run.puzzle!.phase = .won
        _ = try game.cashOut()
        XCTAssertTrue(game.advance())
        XCTAssertEqual(game.run.slot, .medium)
        XCTAssertNil(game.puzzle)
        let after = try game.encoded()
        XCTAssertFalse(game.advance())
        XCTAssertEqual(try game.encoded(), after)
        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.slot, .medium)
    }
}
