import XCTest
import SwiftUI
import UIKit
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

    func testClueActivationRequiresANewCardChoiceRatherThanUsingTheOldSelection() throws {
        let model = try model()
        model.tapHand(0)
        let before = try model.game.encoded()
        model.chooseClue()
        XCTAssertNil(model.selectedHandIndex)
        XCTAssertTrue(model.isChoosingClue)
        XCTAssertEqual(try model.game.encoded(), before)
        model.tapHand(1)
        XCTAssertEqual(model.selectedHandIndex, 1)
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
        model.chooseClue()
        model.tapHand(0)
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
        let before = try model.game.encoded()
        XCTAssertTrue(model.useBuff(at: 0))
        XCTAssertTrue(model.isChoosingClue)
        XCTAssertEqual(try model.game.encoded(), before, "Opening targeting must not spend the Peek")
        model.tapHand(0)
        XCTAssertEqual(model.puzzle?.clueReveals.count, 1)
        XCTAssertTrue(model.run.buffs.isEmpty)
        model.qaSetBoss(.buffborger)
        model.qaSetBuff(Buffs.redraw)
        let beforeRejectedBuff = model.run.buffs.map(\.defID)
        XCTAssertFalse(model.useBuff(at: 0))
        XCTAssertEqual(model.run.buffs.map(\.defID), beforeRejectedBuff)
        XCTAssertNotNil(model.message)
    }

    func testPeekCancellationAndResumeBeforeRevealKeepTheExactInventoryCopy() throws {
        let model = try model()
        model.qaSetBuff(Buffs.peek)
        model.tapHand(0)
        let before = try model.game.encoded()
        XCTAssertTrue(model.useBuff(at: 0))
        XCTAssertNil(model.selectedHandIndex)
        XCTAssertEqual(try model.game.encoded(), before)
        let resumed = GameModel(resuming: try Game(decoding: model.game.encoded()), savesProgress: false)
        XCTAssertEqual(try resumed.game.encoded(), before)
        XCTAssertFalse(resumed.isChoosingClue)
        model.cancelClueTargeting()
        XCTAssertFalse(model.isChoosingClue)
        XCTAssertNil(model.pendingPeekID)
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testPeekCommitsExactlyOneSelectedDuplicateAndHintInTheSameSnapshot() throws {
        let model = try duplicatePeekModel()
        let buffIDs = model.run.buffs.map(\.id)
        let selectedCard = model.handCards[1]
        let handIDs = model.handCards.map(\.id)
        let charges = model.puzzle?.cluesRemaining
        XCTAssertTrue(model.useBuff(at: 1))
        XCTAssertTrue(model.useBuff(at: 1), "A repeated activation can only rearm the same copy")
        model.arrangeHand(.descending)
        model.tapHandCard(selectedCard.id)
        XCTAssertEqual(model.run.buffs.map(\.id), [buffIDs[0]])
        XCTAssertEqual(model.handCards.map(\.id), handIDs)
        XCTAssertEqual(model.puzzle?.cluesRemaining, charges)
        let destination = try XCTUnwrap(model.puzzle?.clueReveals.first)
        XCTAssertTrue(model.isClueDestination(destination))
        let committed = try model.game.encoded()
        model.tapHandCard(selectedCard.id)
        model.tapHandCard(selectedCard.id)
        XCTAssertEqual(try model.game.encoded(), committed, "Repeated taps must not claim the spare Peek")
        let resumed = GameModel(resuming: try Game(decoding: committed), savesProgress: false)
        XCTAssertEqual(resumed.run.buffs.map(\.id), [buffIDs[0]])
        XCTAssertEqual(resumed.puzzle?.clueReveals, [destination])
        model.tapSquare(destination)
        XCTAssertFalse(model.handCards.contains { $0.id == selectedCard.id })
        XCTAssertTrue(model.handCards.contains { $0.id == handIDs[0] })
    }

    func testBlockedCardKeepsPeekAndTargetingThenAnAllowedDuplicateCanReveal() throws {
        var game = try duplicatePeekModel().game
        var run = game.run
        run.puzzle?.boss = .handyDandy
        var restrictions = BossTurnState()
        restrictions.blockedHandIndices = [0]
        run.puzzle?.bossTurn = restrictions
        game = Game(run: run)
        let model = GameModel(frozen: game, page: .puzzle)
        let before = try model.game.encoded()
        XCTAssertTrue(model.useBuff(at: 1))
        model.tapHandCard(model.handCards[0].id)
        XCTAssertEqual(try model.game.encoded(), before)
        XCTAssertTrue(model.isChoosingClue)
        XCTAssertNil(model.selectedHandIndex)
        model.tapHandCard(model.handCards[1].id)
        XCTAssertEqual(model.run.buffs.count, 1)
        XCTAssertEqual(model.puzzle?.clueReveals.count, 1)
        XCTAssertFalse(model.isChoosingClue)
    }

    func testMissingDestinationKeepsPeekAndCharge() throws {
        let base = try duplicatePeekModel()
        var run = base.run
        var restriction = BossTurnState()
        restriction.greyed = Set(try XCTUnwrap(run.puzzle).board.blanks)
        run.puzzle?.boss = .garryTheGray
        run.puzzle?.bossTurn = restriction
        let model = GameModel(frozen: Game(run: run), page: .puzzle)
        let before = try model.game.encoded()
        XCTAssertTrue(model.useBuff(at: 0))
        model.tapHandCard(model.handCards[0].id)
        XCTAssertEqual(try model.game.encoded(), before)
        XCTAssertTrue(model.isChoosingClue)
        XCTAssertTrue(model.message?.contains("Clue kept") == true)
    }

    func testPeekCannotArmUnderPaywallOrBuffborger() throws {
        for boss in [BossModifier.paywall, .buffborger] {
            let model = try model(boss: boss)
            model.qaSetBuff(Buffs.peek)
            let before = try model.game.encoded()
            XCTAssertFalse(model.useBuff(at: 0), boss.rawValue)
            XCTAssertFalse(model.isChoosingClue)
            XCTAssertEqual(try model.game.encoded(), before)
        }
    }

    func testAlreadyPaidDestinationKeepsTheNewPeek() throws {
        let model = try model()
        model.chooseClue()
        model.tapHand(0)
        model.qaSetBuff(Buffs.peek)
        let before = try model.game.encoded()
        XCTAssertTrue(model.useBuff(at: 0))
        model.tapHand(0)
        XCTAssertEqual(try model.game.encoded(), before)
        XCTAssertTrue(model.isClueDestination(try XCTUnwrap(model.puzzle?.clueReveals.first)))
        XCTAssertFalse(model.isChoosingClue)
    }

    func testPendingPeekFollowsItsIdentityWhenAnEarlierInventorySlotIsSold() throws {
        let model = try duplicatePeekModel()
        let selected = model.run.buffs[1].id
        XCTAssertTrue(model.useBuff(at: 1))
        model.sell(kind: .buff, index: 0)
        XCTAssertEqual(model.run.buffs.map(\.id), [selected])
        model.tapHandCard(model.handCards[1].id)
        XCTAssertTrue(model.run.buffs.isEmpty)
        XCTAssertEqual(model.puzzle?.clueReveals.count, 1)
    }

    func testRemovedPendingPeekNeverUsesTheIdenticalSpare() throws {
        let model = try duplicatePeekModel()
        let spare = model.run.buffs[0].id
        XCTAssertTrue(model.useBuff(at: 1))
        model.sell(kind: .buff, index: 1)
        let afterSale = try model.game.encoded()
        model.tapHandCard(model.handCards[0].id)
        XCTAssertEqual(model.run.buffs.map(\.id), [spare])
        XCTAssertEqual(try model.game.encoded(), afterSale)
        XCTAssertFalse(model.isChoosingClue)
        XCTAssertNil(model.pendingPeekID)
    }

    func testBookBookmarkAndSavedChargesRemainUsableWithFullBuffInventory() throws {
        for source in ["book", "bookmark", "saved"] {
            var run = RunState(seed: "clue-resource-\(source)", book: source == "book" ? .noPressure : .probably)
            run.buffs = [OwnedBuff(defID: Buffs.redraw, pricePaid: 0),
                         OwnedBuff(defID: Buffs.freshInk, pricePaid: 0)]
            if source == "bookmark" {
                run.bookmarks = [OwnedBookmark(defID: Bookmarks.puzzleCorner, boughtAtLevel: 1, pricePaid: 0)]
            }
            var game = Game(run: run)
            try game.startPuzzle()
            if source == "saved" {
                var saved = game.run
                saved.puzzle?.cluesRemaining = 3
                game = try Game(decoding: Game(run: saved).encoded())
            }
            let model = GameModel(frozen: game, page: .puzzle)
            let buffIDs = model.run.buffs.map(\.id)
            let charges = try XCTUnwrap(model.puzzle?.cluesRemaining)
            XCTAssertGreaterThan(charges, 0, source)
            model.chooseClue()
            model.tapHandCard(model.handCards[0].id)
            XCTAssertEqual(model.puzzle?.cluesRemaining, charges - 1, source)
            XCTAssertEqual(model.puzzle?.clueReveals.count, 1, source)
            XCTAssertEqual(model.run.buffs.map(\.id), buffIDs, source)
        }
    }

    private func duplicatePeekModel() throws -> GameModel {
        var game = Game(seed: "peek-identity", book: .probably)
        try game.startPuzzle()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        let duplicate = try XCTUnwrap(Digit.all.first { puzzle.pool[$0] >= 2 })
        puzzle.hand = [duplicate, duplicate]
        XCTAssertTrue(puzzle.pool.take(duplicate))
        XCTAssertTrue(puzzle.pool.take(duplicate))
        run.puzzle = puzzle
        run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 0),
                     OwnedBuff(defID: Buffs.peek, pricePaid: 0)]
        return GameModel(resuming: Game(run: run), savesProgress: false)
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

    func testCoinChargeExpiresAndAnOlderCompletionCannotClearTheNextReceipt() async throws {
        let model = try model(boss: .accountant)
        let firstSquare = try XCTUnwrap(model.puzzle?.board.blanks.first {
            model.puzzle?.board.correctDigit(at: $0) == model.hand.first
        })
        model.place(handIndex: 0, at: firstSquare)
        let first = try XCTUnwrap(model.lastCoinCharge)
        let secondSquare = try XCTUnwrap(model.puzzle?.board.blanks.first {
            model.puzzle?.board.correctDigit(at: $0) == model.hand.first
        })
        model.place(handIndex: 0, at: secondSquare)
        let second = try XCTUnwrap(model.lastCoinCharge)
        XCTAssertNotEqual(first.id, second.id)
        model.finishCoinCharge(id: first.id)
        XCTAssertEqual(model.lastCoinCharge?.id, second.id)
        try await ContinuousClock().sleep(until: second.expiresAt.advanced(by: .milliseconds(100)))
        XCTAssertNil(model.lastCoinCharge, "A charge must clear even when its HUD is no longer mounted")
    }

    func testRemountingCoinReceiptUsesTheOriginalDeadlineAndNeverReplaysExpiredCharge() throws {
        let now = ContinuousClock.now
        let fresh = GameModel.CoinCharge(amount: 1, createdAt: now)
        XCTAssertTrue(fresh.isVisible(at: now.advanced(by: .milliseconds(949))))
        XCTAssertFalse(fresh.isVisible(at: fresh.fadesAt))
        XCTAssertFalse(fresh.isVisible(at: fresh.expiresAt))
        let expired = GameModel.CoinCharge(amount: 1, createdAt: now.advanced(by: .seconds(-2)))
        // Each call constructs a fresh SwiftUI receipt, just as navigation
        // between the gameplay and Book HUDs does. No task has to run before
        // an already-expired charge is invisible on that very first frame.
        XCTAssertGreaterThan(try coinReceiptInkPixels(fresh), 0)
        XCTAssertEqual(try coinReceiptInkPixels(expired), 0)
        XCTAssertEqual(try coinReceiptInkPixels(expired), 0)
    }

    private func coinReceiptInkPixels(_ charge: GameModel.CoinCharge) throws -> Int {
        let renderer = ImageRenderer(content: CoinChargeReceipt(charge: charge)
            .frame(width: 140, height: 28))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(
                data: storage.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 0 }.count
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
