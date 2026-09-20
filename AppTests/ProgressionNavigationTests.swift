import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Exercise real player callbacks, including the synchronous Reduce Motion
/// path. Games are non-saving except the explicitly injected deletion failure.
@MainActor
final class ProgressionNavigationTests: XCTestCase {
    func testRepeatedReduceMotionContinueAdvancesExactlyOnePuzzleAndKeepsItsOfferOnResume() async throws {
        let model = GameModel(resuming: try paidShop(), savesProgress: false)
        let flipper = PageFlipper()

        await flipper.flip(from: model, reduceMotion: true) { model.continueToNextPuzzle() }
        XCTAssertEqual(model.page, .briefing)
        XCTAssertEqual(model.run.slot, .medium)
        let committed = try model.game.encoded()
        let offer = try XCTUnwrap(model.currentSkipClaim?.offer)

        for _ in 0..<3 {
            await flipper.flip(from: model, reduceMotion: true) { model.continueToNextPuzzle() }
            model.openShop() // Delayed callback from the preceding results.
        }

        XCTAssertEqual(try model.game.encoded(), committed)
        XCTAssertEqual(model.page, .briefing)
        XCTAssertEqual(model.currentSkipClaim?.offer, offer)
        let resumed = GameModel(resuming: try Game(decoding: committed), savesProgress: false)
        XCTAssertEqual(resumed.page, .briefing)
        XCTAssertEqual(resumed.currentSkipClaim?.offer, offer)
        XCTAssertEqual(try resumed.game.encoded(), committed)
        XCTAssertNil(model.message)
    }

    func testDuplicateDealKeepsTheBoardInventoryAndAllRandomStreams() throws {
        let model = GameModel(resuming: Game(seed: "navigation-deal"), savesProgress: false)
        model.beginPuzzle()
        model.tapHand(0)
        let selected = model.selectedHandIndex
        let committed = try model.game.encoded()
        let cards = model.handCards.map(\.id)

        for _ in 0..<3 { model.beginPuzzle() }

        XCTAssertEqual(model.page, .puzzle)
        XCTAssertEqual(try model.game.encoded(), committed)
        XCTAssertEqual(model.handCards.map(\.id), cards)
        XCTAssertEqual(model.selectedHandIndex, selected)
        XCTAssertNil(model.message)
    }

    func testPlayingUnpaidAndRescuePuzzlesCannotBeDiscardedByNavigation() throws {
        for phase in [PuzzlePhase.playing, .won, .keepFilling, .outOfTurns] {
            var game = try dealtGame(seed: "navigation-phase-\(phase)")
            var run = game.run
            run.puzzle?.phase = phase
            game = Game(run: run)
            let model = GameModel(resuming: game, savesProgress: false)
            let expectedPage = model.page
            let original = try model.game.encoded()

            model.openShop()
            model.continueToNextPuzzle()
            model.beginPuzzle()

            XCTAssertEqual(model.page, expectedPage, "\(phase)")
            XCTAssertEqual(try model.game.encoded(), original, "\(phase)")
            XCTAssertNil(model.shop)
            XCTAssertNil(model.message)
        }
    }

    func testCashOutAndShopOpeningAreIdempotentWithoutRerollingOrRepaying() throws {
        var won = try dealtGame(seed: "navigation-payout")
        won.qaMeetTarget()
        let model = GameModel(resuming: won, savesProgress: false)
        let expected = try XCTUnwrap(model.payoutPreview)
        let coins = model.coins

        model.cashOut()
        let paid = try model.game.encoded()
        for _ in 0..<3 { model.cashOut() }
        XCTAssertEqual(try model.game.encoded(), paid)
        XCTAssertEqual(model.coins, coins + expected.total)
        XCTAssertEqual(model.puzzle?.bankedPayout, expected)
        model.openShop()
        let stocked = try model.game.encoded()
        let visit = model.shop?.visitID
        for _ in 0..<3 { model.cashOut(); model.openShop() }

        XCTAssertEqual(try model.game.encoded(), stocked)
        XCTAssertEqual(model.shop?.visitID, visit)
        XCTAssertEqual(model.page, .shop)
        XCTAssertNil(model.message)
        let resumed = GameModel(resuming: try Game(decoding: stocked), savesProgress: false)
        resumed.openShop()
        XCTAssertEqual(try resumed.game.encoded(), stocked)
        XCTAssertEqual(resumed.page, .shop)
    }

    func testKeepFillingResumesTheSamePuzzleAndFreezesScoreUntilOnePayout() throws {
        var won = try dealtGame(seed: "navigation-keep-filling")
        won.qaMeetTarget()
        let model = GameModel(resuming: won, savesProgress: false)
        let score = model.puzzle?.score
        let board = model.puzzle?.board.placed
        model.keepFilling()
        let entered = try model.game.encoded()
        model.keepFilling()
        XCTAssertEqual(try model.game.encoded(), entered)
        XCTAssertEqual(model.page, .puzzle)
        XCTAssertEqual(model.puzzle?.board.placed, board)

        let resumed = GameModel(resuming: try Game(decoding: entered), savesProgress: false)
        XCTAssertEqual(resumed.page, .puzzle)
        XCTAssertEqual(resumed.puzzle?.phase, .keepFilling)
        XCTAssertEqual(try resumed.game.encoded(), entered)
        resumed.endTurn()
        XCTAssertEqual(resumed.puzzle?.score, score)
        XCTAssertEqual(resumed.puzzle?.phase, .keepFilling)
        resumed.cashOut()
        let paid = try resumed.game.encoded()
        resumed.cashOut()
        resumed.keepFilling()
        XCTAssertEqual(try resumed.game.encoded(), paid)
        XCTAssertNil(resumed.message)
    }

    func testTerminalAndAbandonedModelsRejectDelayedActions() throws {
        var failed = try dealtGame(seed: "navigation-failed")
        failed.failPuzzle()
        var completed = Game(seed: "navigation-complete")
        completed.qaCompleteBook()
        let abandoned = GameModel(resuming: try paidShop(), savesProgress: false)
        XCTAssertTrue(abandoned.abandonRun())
        let liveAbandoned = GameModel(resuming: try dealtGame(seed: "navigation-abandoned-live"),
                                     savesProgress: false)
        liveAbandoned.tapHand(0)
        XCTAssertTrue(liveAbandoned.abandonRun())

        for model in [GameModel(resuming: failed, savesProgress: false),
                      GameModel(resuming: completed, savesProgress: false), abandoned, liveAbandoned] {
            let original = try model.game.encoded()
            let page = model.page
            let selected = model.selectedHandIndex
            model.beginPuzzle()
            model.keepFilling()
            model.cashOut()
            model.openShop()
            model.continueToNextPuzzle()
            model.endTurn()
            model.tapHand(0)
            model.tapSquare(Square(0))
            model.place(handIndex: 0, at: Square(0))
            model.useClue(at: Square(0))
            model.tossSelected()
            XCTAssertFalse(model.useBuff(at: 0))
            model.buy(slot: 0)
            model.reroll()
            model.sell(kind: .bookmark, index: 0)
            XCTAssertFalse(model.claimSquare(markerIndex: 0, square: Square(0)))
            XCTAssertEqual(try model.game.encoded(), original)
            XCTAssertEqual(model.page, page)
            XCTAssertEqual(model.selectedHandIndex, selected)
            XCTAssertNil(model.message)
        }
    }

    func testFailedInitialSaveDoesNotExposeAnUnsavedBook() {
        var attempts = 0
        let model = GameModel.startingBook(seed: "navigation-save-failure") { game in
            attempts += 1
            XCTAssertNil(game.puzzle)
            XCTAssertNil(game.shop)
            XCTAssertNotNil(game.run.currentSkipOffer)
            return false
        }
        XCTAssertNil(model)
        XCTAssertEqual(attempts, 1)
    }

    func testFailedAbandonRetainsLiveClockAndAllowsRetryWithoutWritingRealStorage() throws {
        var run = RunState(seed: "navigation-clear-failure")
        run.slot = .boss
        run.pendingBoss = .tikTak
        var game = Game(run: run)
        try game.startPuzzle()
        // Construction and starting the clock only read persisted presentation.
        // Inject both deletion attempts so this test never touches run storage.
        let model = GameModel(resuming: game, savesProgress: true)
        model.setClockRunning(true)
        let snapshot = try model.gameForPersistence.encoded()
        let remaining = model.secondsLeft
        var attempts = 0

        XCTAssertFalse(model.abandonRun(clearingSave: { attempts += 1; return false }))

        XCTAssertEqual(attempts, 1)
        XCTAssertFalse(model.wantsMenu)
        XCTAssertTrue(model.acceptsPuzzleInput)
        XCTAssertTrue(model.isClockRunning)
        XCTAssertEqual(model.secondsLeft, remaining)
        XCTAssertEqual(try model.gameForPersistence.encoded(), snapshot)
        XCTAssertNotNil(model.message)
        XCTAssertTrue(model.abandonRun(clearingSave: { attempts += 1; return true }))
        XCTAssertEqual(attempts, 2)
        XCTAssertTrue(model.wantsMenu)
        XCTAssertFalse(model.isClockRunning)
        XCTAssertEqual(try model.gameForPersistence.encoded(), snapshot)
    }

    private func dealtGame(seed: String) throws -> Game {
        var game = Game(seed: seed)
        try game.startPuzzle()
        return game
    }

    private func paidShop() throws -> Game {
        var game = try dealtGame(seed: "navigation-shop")
        game.qaMeetTarget()
        _ = try game.cashOut()
        game.openShop()
        return game
    }
}
