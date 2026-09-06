import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ScorePerformanceTests: XCTestCase {
    private func startedGame() throws -> Game {
        var game = Game(seed: "APPSTORE7")
        try game.startPuzzle()
        var run = game.run
        run.bookmarks = ["bm_local_gossip", "bm_morning_edition"].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0)
        }
        return Game(run: run)
    }

    func testReceiptHasPlacementThenNamedBonusThenQueue() throws {
        var game = try startedGame()
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first {
            game.puzzle!.hand.contains(game.puzzle!.board.correctDigit(at: $0))
        })
        let index = try XCTUnwrap(game.puzzle?.hand.firstIndex(of: game.puzzle!.board.correctDigit(at: square)))
        let outcome = try game.place(handIndex: index, at: square)
        let receipt = ScorePerformance.placement(outcome, square: square, previousScore: 0, finalScore: 0)
        XCTAssertEqual(receipt.beats.map(\.source), ["Number placed", "Local Gossip", "Added to queue"])
        XCTAssertEqual(receipt.beats[1].value, "+30")
        XCTAssertEqual(receipt.beats.last?.queuedBase, outcome.points)
    }

    func testPresentationCannotChangeSavedRulesAndOldTaskCannotClearNewReceipt() throws {
        var game = try startedGame()
        let turn = try game.endTurn()
        let model = GameModel(resuming: game, savesProgress: false)
        let saved = try model.game.encoded()
        let receipt = ScorePerformance.banking(turn, previousScore: 0, finalScore: 100)
        model.presentScore(receipt)
        XCTAssertEqual(model.presentedScore, 0)
        XCTAssertTrue(model.isPresentingScore)
        XCTAssertEqual(receipt.beats.map(\.source), ["Turn points", "Morning Edition", "BANKED"])
        model.advanceScore(receipt.beats[1], performanceID: receipt.id)
        XCTAssertEqual(model.bookmarkScoreLabel("bm_morning_edition"), "+100")
        model.advanceScore(try XCTUnwrap(receipt.beats.last), performanceID: receipt.id)
        XCTAssertEqual(model.presentedScore, 100)
        let next = ScorePerformance.banking(turn, previousScore: 100, finalScore: 200)
        model.presentScore(next)
        model.finishScorePresentation(id: receipt.id)
        XCTAssertEqual(model.scorePerformance?.id, next.id)
        model.finishScorePresentation()
        XCTAssertFalse(model.isPresentingScore)
        XCTAssertNil(model.presentedScore)
        XCTAssertEqual(try model.game.encoded(), saved)
    }

    func testFrozenPageNeverPlaysScoringAndResumeDoesNotReplayAwards() throws {
        var game = try startedGame()
        let turn = try game.endTurn()
        let receipt = ScorePerformance.banking(turn, previousScore: 0, finalScore: 100)
        let frozen = GameModel(frozen: game, page: .puzzle)
        frozen.presentScore(receipt)
        XCTAssertFalse(frozen.isPresentingScore)
        let restored = GameModel(resuming: try Game(decoding: game.encoded()), savesProgress: false)
        XCTAssertFalse(restored.isPresentingScore)
        XCTAssertEqual(restored.puzzle?.score, 100)
    }
}
