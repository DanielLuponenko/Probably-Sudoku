import XCTest
import SwiftUI
import UIKit
import SceneKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Reference lifetime is the assertion here, not process RSS. SceneKit, Metal
/// and UIKit can legitimately keep bounded shared caches after a view closes.
/// Every game is in memory and cannot touch the player's run or profile.
@MainActor
final class MemoryLifecycleTests: XCTestCase {
    func testAbandonedWrongPlacementDoesNotWaitForReturnAnimationToReleaseGame() throws {
        var run = try QAScoringFixture.penalty.makeGame().run
        run.bookmarks = []
        for _ in 0..<6 {
            weak var released: GameModel?
            autoreleasepool {
                let model = GameModel(frozen: Game(run: run), page: .puzzle)
                model.place(handIndex: 1, at: Square(1))
                XCTAssertEqual(model.lastOutcome?.correct, false)
                XCTAssertEqual(model.numberReturns.count, 1)
                XCTAssertTrue(model.abandonRun())
                released = model
            }
            XCTAssertNil(released, "A decorative return timer must not own the retired Game")
        }
    }

    func testAbandonedMarkerPlacementDoesNotWaitForReceiptToReleaseGame() throws {
        let game = try QAScoringFixture.modifierPreview.makeGame()
        for _ in 0..<6 {
            weak var released: GameModel?
            autoreleasepool {
                let model = GameModel(frozen: game, page: .puzzle)
                model.place(handIndex: 0, at: Square(3))
                XCTAssertEqual(model.lastOutcome?.correct, true)
                XCTAssertNotNil(model.effectActivation)
                XCTAssertEqual(model.liveScoreCalculation.total, 960)
                XCTAssertTrue(model.abandonRun())
                released = model
            }
            XCTAssertNil(released, "Reading time for a marker receipt cannot own a departed Book")
        }
    }

    func testAbandonedLineClearDoesNotWaitForBoardFlashToReleaseGame() throws {
        var run = try QAScoringFixture.simultaneousClears.makeGame().run
        run.bookmarks = []
        for _ in 0..<6 {
            weak var released: GameModel?
            autoreleasepool {
                let model = GameModel(frozen: Game(run: run), page: .puzzle)
                model.place(handIndex: 0, at: Square(4))
                XCTAssertEqual(model.lastOutcome?.lineClears.count, 2)
                XCTAssertEqual(model.cleared.count, 2)
                XCTAssertNil(model.effectActivation)
                XCTAssertTrue(model.abandonRun())
                released = model
            }
            XCTAssertNil(released, "A line-clear timer must not own the retired Game")
        }
    }

    func testPresentationCleanupsStillExpireForLiveModelsWithoutChangingTheirGames() async throws {
        let wrong = GameModel(frozen: try QAScoringFixture.penalty.makeGame(), page: .puzzle)
        wrong.place(handIndex: 1, at: Square(1))
        let marker = GameModel(frozen: try QAScoringFixture.modifierPreview.makeGame(), page: .puzzle)
        marker.place(handIndex: 0, at: Square(3))
        let clear = GameModel(frozen: try QAScoringFixture.simultaneousClears.makeGame(), page: .puzzle)
        clear.place(handIndex: 0, at: Square(4))
        XCTAssertFalse(wrong.numberReturns.isEmpty)
        XCTAssertNotNil(marker.effectActivation)
        XCTAssertFalse(clear.cleared.isEmpty)
        let models = [wrong, marker, clear]
        let games = try models.map { try $0.game.encoded() }

        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline,
              !wrong.numberReturns.isEmpty || marker.effectActivation != nil || !clear.cleared.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(wrong.numberReturns.isEmpty)
        XCTAssertNil(marker.effectActivation)
        XCTAssertTrue(clear.cleared.isEmpty)
        XCTAssertEqual(try models.map { try $0.game.encoded() }, games,
                       "Releasing temporary presentation must not change gameplay or persistence")
    }
}
