import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class PendingDecisionCallbackTests: XCTestCase {
    func testOldShopCallbacksLeaveSavedChoicePageAndMessageUntouched() throws {
        var run = RunState(seed: "pending-ui-shop")
        run.coins = 100
        run.bookmarks = [Bookmarks.helpWanted, Bookmarks.editorialBoard].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5)
        }
        run.markers = [OwnedMarker(defID: Markers.jade, boughtAtLevel: 1, pricePaid: 5)]
        let reservation = OwnedBuff(defID: Buffs.reservation, pricePaid: 3)
        let edition = OwnedBuff(defID: Buffs.newEdition, pricePaid: 5)
        run.buffs = [reservation, edition]
        Shop.open(&run)
        let offer = try XCTUnwrap(run.shop?.offers.first)
        try BuffRuntime.use(.init(buffID: reservation.id, context: BuffRuntime.context(run), choice: .offer(offer.slot)), run: &run)
        var game = Game(run: run)
        try game.beginBuff(id: edition.id)
        let model = GameModel(resuming: game, savesProgress: false)
        XCTAssertEqual(model.page, .shop)
        let before = try model.game.encoded()
        let message = model.message
        let choice = try XCTUnwrap(model.pendingItemDecision)

        model.buy(slot: offer.slot)
        model.reroll()
        model.sell(kind: .buff, index: 0)
        model.sell(kind: .bookmark, index: 0)
        model.reorderBookmark(id: run.bookmarks[0].id, to: 1)
        XCTAssertFalse(model.claimSquare(markerIndex: 0, square: Square(40)))
        model.cancelReservation()
        model.reopenRecycledChoice(bookmarkID: run.bookmarks[0].id)
        model.continueToNextPuzzle()
        model.openShop()
        model.beginPuzzle()

        XCTAssertEqual(try model.game.encoded(), before)
        XCTAssertEqual(model.page, .shop)
        XCTAssertEqual(model.message, message)
        XCTAssertEqual(model.pendingItemDecision, choice)
        XCTAssertTrue(model.resolveItemDecision(id: choice.id, selected: nil))
        XCTAssertNil(model.pendingItemDecision)
        XCTAssertEqual(model.run.buffs.map(\.id), [reservation.id, edition.id])
    }

    func testDelayedPlayCallbackCannotInterruptPaidBriefingChoice() throws {
        var run = RunState(seed: "pending-ui-detour")
        let detour = OwnedBuff(defID: Buffs.detour, pricePaid: 5)
        run.buffs = [detour]
        var game = Game(run: run)
        try game.beginBuff(id: detour.id)
        let model = GameModel(resuming: game, savesProgress: false)
        let choice = try XCTUnwrap(model.pendingItemDecision)
        let before = try model.game.encoded()
        XCTAssertFalse(choice.allowsCancel)
        model.beginPuzzle()
        model.continueToNextPuzzle()
        XCTAssertEqual(try model.game.encoded(), before)
        XCTAssertEqual(model.page, .briefing)
        XCTAssertNil(model.message)
        XCTAssertTrue(model.resolveItemDecision(id: choice.id, selected: ["original"]))
        model.beginPuzzle()
        XCTAssertEqual(model.page, .puzzle)
        XCTAssertNotNil(model.puzzle)
        XCTAssertTrue(model.run.buffs.isEmpty)
    }
}
