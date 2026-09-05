import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class HandCluePresentationTests: XCTestCase {
    private func model(boss: BossModifier? = nil) throws -> GameModel {
        var game = Game(seed: "clue-presentation", book: .noPressure)
        try game.startPuzzle()
        if let boss { game.qaSetBoss(boss) }
        return GameModel(frozen: game, page: .puzzle)
    }

    func testClueThenHandRevealsWithoutMovingTheCard() throws {
        let model = try model()
        let hand = model.hand
        let board = model.puzzle!.board.placed
        model.chooseClue()
        XCTAssertTrue(model.isChoosingClue)
        model.tapHand(0)
        XCTAssertFalse(model.isChoosingClue)
        XCTAssertEqual(model.hand, hand)
        XCTAssertEqual(model.puzzle?.board.placed, board)
        XCTAssertEqual(model.selectedHandIndex, 0)
        XCTAssertNil(model.selectedSquare)
        let target = try XCTUnwrap(model.puzzle?.clueReveals.first)
        XCTAssertTrue(model.isClueDestination(target))
        XCTAssertEqual(model.puzzle?.cluesRemaining, 0)
        model.tapSquare(target)
        XCTAssertEqual(model.puzzle?.board.filledBy[target.index], .clue)
        XCTAssertNil(model.selectedHandIndex)
        XCTAssertFalse(model.isClueDestination(target))
    }

    func testHandThenClueHasTheSameResult() throws {
        let model = try model()
        model.tapHand(0)
        model.chooseClue()
        XCTAssertEqual(model.selectedHandIndex, 0)
        XCTAssertEqual(model.puzzle?.clueReveals.count, 1)
        XCTAssertTrue(model.isClueDestination(try XCTUnwrap(model.puzzle?.clueReveals.first)))
    }

    func testCancellingBeforeChoosingNeverSpendsClue() throws {
        let model = try model()
        let before = try model.game.encoded()
        model.chooseClue()
        model.chooseClue()
        XCTAssertFalse(model.isChoosingClue)
        XCTAssertEqual(try model.game.encoded(), before)
        model.chooseClue()
        model.dismissSelection()
        XCTAssertFalse(model.isChoosingClue)
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testReSelectingCardRestoresItsPaidHintWithoutAnotherCharge() throws {
        let model = try model()
        model.tapHand(0)
        model.chooseClue()
        let square = try XCTUnwrap(model.puzzle?.clueReveals.first)
        model.tapHand(0)
        XCTAssertFalse(model.isClueDestination(square))
        model.tapHand(0)
        XCTAssertTrue(model.isClueDestination(square))
        XCTAssertEqual(model.puzzle?.cluesRemaining, 0)
    }

    func testPeekOpensHandTargetingAndFailedBuffKeepsItsInventory() throws {
        let model = try model()
        model.qaSetBuff(Buffs.peek)
        XCTAssertTrue(model.useBuff(at: 0))
        XCTAssertTrue(model.isChoosingClue)
        model.tapHand(0)
        XCTAssertEqual(model.puzzle?.clueReveals.count, 1)
        model.qaSetBoss(.buffborger)
        model.qaSetBuff(Buffs.redraw)
        let before = model.run.buffs.map(\.defID)
        XCTAssertFalse(model.useBuff(at: 0))
        XCTAssertEqual(model.run.buffs.map(\.defID), before)
        XCTAssertNotNil(model.message)
    }

    func testAccountantPublishesImmediateChargeAndRejectedTapHasNoNewCharge() throws {
        let model = try model(boss: .accountant)
        let square = try XCTUnwrap(model.puzzle?.board.blanks.first)
        let balance = model.coins
        model.place(handIndex: 0, at: square)
        XCTAssertEqual(model.coins, balance - 1)
        XCTAssertEqual(model.lastCoinCharge?.amount, 1)
        let id = model.lastCoinCharge?.id
        let occupied = try XCTUnwrap(Square.all.first { model.puzzle!.board[$0] != nil })
        model.place(handIndex: 0, at: occupied)
        XCTAssertEqual(model.lastCoinCharge?.id, id)
        XCTAssertEqual(model.coins, balance - 1)
    }

    func testFogNeverPublishesMarkerLocationReceipt() throws {
        var game = Game(seed: "fog-receipt")
        try game.startPuzzle()
        game.qaSetBoss(.fog)
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first {
            game.puzzle!.board.correctDigit(at: $0) == game.puzzle!.hand[0]
        })
        game.qaSetMarker("mk_azure", at: square)
        let model = GameModel(frozen: game, page: .puzzle)
        XCTAssertTrue(model.visibleMarkers.isEmpty)
        let coins = model.coins
        XCTAssertNil(model.markerEffect(at: square))
        model.place(handIndex: 0, at: square)
        XCTAssertEqual(model.coins, coins + 1, "Hidden Marker still works; its receipt stays hidden.")
        XCTAssertNil(model.markerEffect(at: square))
        XCTAssertTrue(model.visibleMarkers.isEmpty)
    }
}
