import Foundation
import Observation
import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Explicit monotonic instants and in-memory save snapshots only. No sleeps,
/// RunStore writes, cloud publishes, achievements or rendered timer tasks.
@MainActor
final class TikTakClockTests: XCTestCase {
    func testFreshClockWaitsForVisibleActivePuzzleBeforeCounting() throws {
        let model = try makeModel()
        let now = ContinuousClock().now
        XCTAssertEqual(model.secondsLeft, 180)
        XCTAssertFalse(model.isClockRunning)

        model.tickClock(at: now.advanced(by: .seconds(60)))

        XCTAssertEqual(model.secondsLeft, 180)
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(1)))
        XCTAssertEqual(model.secondsLeft, 179)
    }

    func testDelayedTickChargesActualMonotonicTimeInsteadOfOneSecond() throws {
        let model = try makeModel()
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)

        model.tickClock(at: now.advanced(by: .milliseconds(3250)))

        XCTAssertEqual(model.secondsLeft, 177, "The label rounds up; the saved budget does not")
        XCTAssertEqual(try remaining(model), 176.75, accuracy: 0.000_001)
    }

    func testPauseSavesPartialSecondAndResumeDoesNotChargeTimeAway() throws {
        let model = try makeModel()
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(1)))
        model.setClockRunning(false, at: now.advanced(by: .milliseconds(1500)))
        XCTAssertFalse(model.isClockRunning)
        XCTAssertEqual(try remaining(model), 178.5, accuracy: 0.000_001)

        // The same gate is driven by inactive/background, Settings, run info,
        // Buff slips, page flips and leaving the puzzle for achievements.
        model.tickClock(at: now.advanced(by: .seconds(90)))
        model.setClockRunning(false, at: now.advanced(by: .seconds(100)))
        XCTAssertEqual(try remaining(model), 178.5, accuracy: 0.000_001)

        model.setClockRunning(true, at: now.advanced(by: .seconds(100)))
        model.tickClock(at: now.advanced(by: .milliseconds(100750)))
        XCTAssertEqual(try remaining(model), 177.75, accuracy: 0.000_001)
    }

    func testRepeatedResumeDoesNotResetTheSamplingOriginOrBudget() throws {
        let model = try makeModel()
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        model.setClockRunning(true, at: now.advanced(by: .seconds(2)))
        model.tickClock(at: now.advanced(by: .seconds(3)))
        XCTAssertEqual(try remaining(model), 177)
    }

    func testNegativeOrRepeatedInstantCannotAddTime() throws {
        let model = try makeModel()
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(-10)))
        model.tickClock(at: now)
        XCTAssertEqual(try remaining(model), 180)
        model.tickClock(at: now.advanced(by: .seconds(2)))
        model.tickClock(at: now.advanced(by: .seconds(2)))
        XCTAssertEqual(try remaining(model), 178)
    }

    func testSaveAndRelaunchPreserveFractionalBudgetAndBoardExactly() throws {
        let model = try makeModel()
        let now = ContinuousClock().now
        let original = try model.game.encoded()
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .milliseconds(37250)))
        let saved = model.gameForPersistence
        XCTAssertEqual(saved.puzzle?.clockSecondsRemaining, 142.75)
        XCTAssertEqual(try model.game.encoded(), original,
                       "Timer-only ticks must not replace the observed board Game")

        let restoredGame = try Game(decoding: saved.encoded())
        let restored = GameModel(resuming: restoredGame, savesProgress: false)
        XCTAssertEqual(restored.secondsLeft, 143)
        XCTAssertEqual(try remaining(restored), 142.75)
        XCTAssertFalse(restored.isClockRunning)
        XCTAssertEqual(restored.puzzle?.board.placed, model.puzzle?.board.placed)
        XCTAssertEqual(restored.puzzle?.hand, model.puzzle?.hand)
        XCTAssertEqual(restored.run.streams.pool.state, model.run.streams.pool.state)
        restored.setClockRunning(true, at: now.advanced(by: .seconds(1000)))
        restored.tickClock(at: now.advanced(by: .seconds(1001)))
        XCTAssertEqual(try remaining(restored), 141.75)
    }

    func testLegacySaveWithoutClockFieldStartsOneCompatibleBudget() throws {
        let game = try makeGame()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(json["puzzle"] as? [String: Any])
        puzzle.removeValue(forKey: "clockSecondsRemaining")
        json["puzzle"] = puzzle
        let data = try JSONSerialization.data(withJSONObject: json)
        let restoredGame = try Game(decoding: data)
        XCTAssertNil(restoredGame.puzzle?.clockSecondsRemaining)
        let model = GameModel(resuming: restoredGame, savesProgress: false)
        XCTAssertEqual(model.secondsLeft, 180)
        XCTAssertEqual(try remaining(model), 180)
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(7)))
        let nextLaunch = GameModel(resuming: try Game(decoding: model.gameForPersistence.encoded()),
                                   savesProgress: false)
        XCTAssertEqual(nextLaunch.secondsLeft, 173)
    }

    func testExpiryFailsNormalPlayAndKeepFillingThroughEngineFailure() throws {
        for phase in [PuzzlePhase.playing, .keepFilling] {
            let model = try makeModel(remaining: 2.5, phase: phase)
            let now = ContinuousClock().now
            model.setClockRunning(true, at: now)
            model.tickClock(at: now.advanced(by: .seconds(3)))

            XCTAssertEqual(model.secondsLeft, 0)
            XCTAssertEqual(try remaining(model), 0)
            XCTAssertEqual(model.puzzle?.phase, .failed)
            XCTAssertEqual(model.run.outcome, .failed)
            XCTAssertEqual(model.page, .results)
            XCTAssertFalse(model.isClockRunning)
            XCTAssertFalse(model.canOfferRewardedRescue)
            let ended = try model.gameForPersistence.encoded()
            model.tickClock(at: now.advanced(by: .seconds(30)))
            model.setClockRunning(true, at: now.advanced(by: .seconds(31)))
            XCTAssertEqual(try model.gameForPersistence.encoded(), ended)
        }
    }

    func testKeepFillingAfterRelaunchOnWonResultsRetainsClock() throws {
        let model = try makeModel(remaining: 18.25, phase: .won)
        XCTAssertEqual(model.page, .results)
        XCTAssertFalse(model.isClockRunning)
        XCTAssertEqual(model.secondsLeft, 19)
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        XCTAssertFalse(model.isClockRunning)

        model.keepFilling()
        model.setClockRunning(true, at: now.advanced(by: .seconds(200)))
        model.tickClock(at: now.advanced(by: .seconds(202)))

        XCTAssertEqual(model.puzzle?.phase, .keepFilling)
        XCTAssertEqual(try remaining(model), 16.25)
    }

    func testAchievementsDoNotSpendTimeAndReturnResumesSameClock() throws {
        let model = try makeModel(remaining: 80)
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(2)))
        model.openAchievements()
        model.setClockRunning(false, at: now.advanced(by: .seconds(2)))
        model.tickClock(at: now.advanced(by: .seconds(100)))
        XCTAssertEqual(try remaining(model), 78)
        XCTAssertEqual(model.page, .achievements)
        model.closeAchievements()
        model.setClockRunning(true, at: now.advanced(by: .seconds(200)))
        model.tickClock(at: now.advanced(by: .seconds(201)))
        XCTAssertEqual(model.page, .puzzle)
        XCTAssertEqual(try remaining(model), 77)
    }

    func testTimerTicksDoNotInvalidateGameOrUrgencyUntilItsThreshold() throws {
        let model = try makeModel(remaining: 34)
        let change = ChangeFlag()
        withObservationTracking {
            _ = model.game
            _ = model.clockIsUrgent
        } onChange: {
            change.mark()
        }
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(3)))
        XCTAssertFalse(change.wasChanged, "Only the isolated timer label should update before the threshold")
        XCTAssertFalse(model.clockIsUrgent)
        model.tickClock(at: now.advanced(by: .seconds(4)))
        XCTAssertTrue(change.wasChanged)
        XCTAssertTrue(model.clockIsUrgent)
    }

    func testFrozenPageCannotStartTickStopOrSaveItsClock() throws {
        let game = try makeGame(remaining: 17.5)
        let model = GameModel(frozen: game, page: .puzzle)
        let snapshot = try model.gameForPersistence.encoded()
        let now = ContinuousClock().now
        XCTAssertEqual(model.secondsLeft, 18)
        model.startClock()
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(300)))
        model.setClockRunning(false, at: now.advanced(by: .seconds(400)))
        model.stopClock()
        XCTAssertFalse(model.isClockRunning)
        XCTAssertEqual(model.secondsLeft, 18)
        XCTAssertEqual(model.puzzle?.phase, .playing)
        XCTAssertNil(model.run.outcome)
        XCTAssertEqual(try model.gameForPersistence.encoded(), snapshot)
    }

    func testUntimedPuzzleNeverStartsOrAcquiresASavedClock() throws {
        var game = Game(seed: "untimed-clock-test")
        try game.startPuzzle()
        let model = GameModel(resuming: game, savesProgress: false)
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        model.tickClock(at: now.advanced(by: .seconds(300)))
        XCTAssertFalse(model.isClockRunning)
        XCTAssertNil(model.secondsLeft)
        XCTAssertFalse(model.clockIsUrgent)
        XCTAssertNil(model.gameForPersistence.puzzle?.clockSecondsRemaining)
        XCTAssertEqual(model.puzzle?.phase, .playing)
    }

    func testZeroRemainingSaveExpiresOnActivationNotDuringBackgroundResume() throws {
        let model = try makeModel(remaining: 0)
        XCTAssertEqual(model.puzzle?.phase, .playing)
        XCTAssertEqual(model.secondsLeft, 0)
        model.setClockRunning(false)
        XCTAssertNil(model.run.outcome)
        model.setClockRunning(true)
        XCTAssertEqual(model.run.outcome, .failed)
        XCTAssertEqual(model.page, .results)
    }

    private func makeGame(remaining: Double = 180, phase: PuzzlePhase = .playing) throws -> Game {
        var run = RunState(seed: "tik-tak-lifecycle")
        run.slot = .boss
        run.pendingBoss = .tikTak
        var game = Game(run: run)
        try game.startPuzzle()
        var prepared = game.run
        prepared.puzzle?.clockSecondsRemaining = remaining
        prepared.puzzle?.phase = phase
        return Game(run: prepared)
    }

    private func makeModel(remaining: Double = 180, phase: PuzzlePhase = .playing) throws -> GameModel {
        GameModel(resuming: try makeGame(remaining: remaining, phase: phase), savesProgress: false)
    }

    private func remaining(_ model: GameModel) throws -> Double {
        try XCTUnwrap(model.gameForPersistence.puzzle?.clockSecondsRemaining)
    }

    private final class ChangeFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        var wasChanged: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func mark() {
            lock.lock()
            value = true
            lock.unlock()
        }
    }
}
