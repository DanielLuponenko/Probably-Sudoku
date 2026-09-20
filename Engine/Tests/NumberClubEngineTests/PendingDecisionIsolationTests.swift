import XCTest
@testable import ProbablySudokuEngine

final class PendingDecisionIsolationTests: XCTestCase {
    func testSavedBuffChoiceRejectsStaleShopInventoryAndNavigationCallbacks() throws {
        for accept in [false, true] {
            var game = try choosingEditionWithReservation()
            let choice = try XCTUnwrap(game.run.pendingItemDecisions.first)
            let source = try XCTUnwrap(choice.sourceInstanceID)
            let reservationSource = try XCTUnwrap(game.run.buffState.reservationIntent?.sourceBuff)
            let firstBookmark = try XCTUnwrap(game.run.bookmarks.first)
            let before = try game.encoded()
            let slot = try XCTUnwrap(game.shop?.offers.first(where: { !$0.sold })?.slot)

            XCTAssertThrowsError(try game.buy(slot: slot)) { XCTAssertEqual($0 as? BuffUseError, .pendingChoice) }
            XCTAssertEqual(try game.encoded(), before)
            XCTAssertThrowsError(try game.reroll()) { XCTAssertEqual($0 as? BuffUseError, .pendingChoice) }
            XCTAssertEqual(try game.encoded(), before)
            XCTAssertThrowsError(try game.sell(kind: .buff, index: 0)) { XCTAssertEqual($0 as? BuffUseError, .pendingChoice) }
            XCTAssertEqual(try game.encoded(), before)
            XCTAssertThrowsError(try game.sell(kind: .bookmark, index: 0)) { XCTAssertEqual($0 as? BuffUseError, .pendingChoice) }
            XCTAssertEqual(try game.encoded(), before)
            XCTAssertThrowsError(try game.claimSquare(markerIndex: 0, square: Square(40))) {
                XCTAssertEqual($0 as? BuffUseError, .pendingChoice)
            }
            XCTAssertEqual(try game.encoded(), before)
            XCTAssertFalse(game.reorderBookmark(id: firstBookmark.id, to: 1))
            XCTAssertEqual(try game.encoded(), before)
            game.cancelReservation()
            XCTAssertEqual(try game.encoded(), before)
            XCTAssertFalse(game.advance())
            XCTAssertEqual(try game.encoded(), before)

            game = try Game(decoding: before)
            XCTAssertEqual(try game.encoded(), before)
            let selected = accept ? [firstBookmark.id.uuidString] : nil
            XCTAssertTrue(try game.resolveItemDecision(id: choice.id, selected: selected))
            XCTAssertTrue(game.run.pendingItemDecisions.isEmpty)
            XCTAssertEqual(game.run.buffState.reservationIntent?.sourceBuff, reservationSource)
            XCTAssertEqual(game.run.buffs.contains { $0.id == source }, !accept)
            XCTAssertEqual(game.run.bookmarks.contains { $0.id == firstBookmark.id }, !accept)
            let settled = try game.encoded()
            XCTAssertFalse(try game.resolveItemDecision(id: choice.id, selected: selected))
            XCTAssertEqual(try game.encoded(), settled)
            game.cancelReservation()
            XCTAssertNil(game.run.buffState.reservationIntent)
            XCTAssertTrue(game.run.buffs.contains { $0.id == reservationSource })
        }
    }

    func testCapacitySaleStillResolvesBothSalesAtomicallyThroughItsDecision() throws {
        var run = RunState(seed: "pending-capacity-sale")
        let pocket = OwnedBookmark(defID: Bookmarks.pocketInsert, boughtAtLevel: 1, pricePaid: 8)
        run.bookmarks = [pocket]
        run.buffs = (0..<3).map { _ in OwnedBuff(defID: Buffs.peek, pricePaid: 4) }
        var game = Game(run: run)
        let chosen = run.buffs[1]
        let retained = [run.buffs[0].id, run.buffs[2].id]
        let coins = run.coins
        try game.requestCapacitySale(bookmarkID: pocket.id)
        let choice = try XCTUnwrap(game.run.pendingItemDecisions.first)
        let waiting = try game.encoded()
        XCTAssertThrowsError(try game.sell(kind: .buff, index: 1))
        XCTAssertThrowsError(try game.sell(kind: .bookmark, index: 0))
        XCTAssertEqual(try game.encoded(), waiting)
        game = try Game(decoding: waiting)
        XCTAssertTrue(try game.resolveItemDecision(id: choice.id, selected: [chosen.id.uuidString]))
        XCTAssertEqual(game.run.buffs.map(\.id), retained)
        XCTAssertTrue(game.run.bookmarks.isEmpty)
        XCTAssertTrue(game.run.pendingItemDecisions.isEmpty)
        XCTAssertEqual(game.run.coins, coins + Shop.sellPrice(8) + Shop.sellPrice(4))
        let committed = try game.encoded()
        XCTAssertFalse(try game.resolveItemDecision(id: choice.id, selected: [chosen.id.uuidString]))
        XCTAssertEqual(try game.encoded(), committed)
    }

    private func choosingEditionWithReservation() throws -> Game {
        var run = RunState(seed: "pending-shop-choice")
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
        return game
    }
}
