import XCTest
import Foundation
import ProbablySudokuEngine
@testable import ProbablySudoku

/// All models are deliberately non-saving. These tests exercise stale owner
/// callbacks without reading or modifying the player's local/cloud run.
@MainActor
final class RunPersistenceLifecycleTests: XCTestCase {
    func testAbandonedBookRejectsAReadyPreparedPuzzleAndItsOldSkipClaim() async throws {
        let original = Game(seed: "abandon-ready")
        let model = GameModel(resuming: original, savesProgress: false)
        let claim = try XCTUnwrap(model.currentSkipClaim)
        let ready = await model.prepareUpcomingPuzzle()
        let prepared = try XCTUnwrap(ready)
        XCTAssertTrue(model.hasPreparedPuzzle)

        model.abandonRun()
        let retired = model.gameForPersistence
        XCTAssertTrue(model.wantsMenu)
        XCTAssertFalse(model.hasPreparedPuzzle)
        XCTAssertNil(model.preparedPuzzlePreview)
        XCTAssertFalse(model.beginPreparedPuzzle(prepared))
        XCTAssertFalse(model.takeSkip(ifCurrent: claim))
        let later = await model.prepareUpcomingPuzzle()
        XCTAssertNil(later)
        XCTAssertNil(RunStore.conflict(local: model.gameForPersistence, remote: retired))
        XCTAssertNil(RunStore.conflict(local: retired, remote: original))
    }

    func testFinishingDetachedPreparationAfterAbandonCannotReviveTheBook() async throws {
        let original = Game(seed: "abandon-inflight")
        let model = GameModel(resuming: original, savesProgress: false)
        let started = expectation(description: "Worker began using its private Game copy")
        let gate = PersistencePreparationGate(started: started)
        let waiting = Task {
            await model.prepareUpcomingPuzzle(using: { try gate.generate($0) })
        }
        await fulfillment(of: [started], timeout: 4)
        model.abandonRun()
        gate.release()
        let prepared = await waiting.value

        XCTAssertNil(prepared)
        XCTAssertTrue(model.wantsMenu)
        XCTAssertFalse(model.hasPreparedPuzzle)
        XCTAssertNil(model.puzzle)
        XCTAssertNil(model.preparedPuzzlePreview)
        XCTAssertNil(RunStore.conflict(local: model.gameForPersistence, remote: original))
    }

    func testRepeatedAbandonAndClockExitCallbacksKeepTheRetiredSnapshotStable() throws {
        var run = RunState(seed: "abandon-timed")
        run.slot = .boss
        run.pendingBoss = .tikTak
        var game = Game(run: run)
        try game.startPuzzle()
        let model = GameModel(resuming: game, savesProgress: false)
        let instant = ContinuousClock().now
        model.setClockRunning(true, at: instant)
        model.tickClock(at: instant.advanced(by: .seconds(2)))
        model.abandonRun()
        let retired = model.gameForPersistence

        model.abandonRun()
        model.setClockRunning(false, at: instant.advanced(by: .seconds(30)))
        model.setClockRunning(true, at: instant.advanced(by: .seconds(40)))
        model.tickClock(at: instant.advanced(by: .seconds(90)))
        XCTAssertFalse(model.isClockRunning)
        XCTAssertTrue(model.wantsMenu)
        XCTAssertNil(RunStore.conflict(local: model.gameForPersistence, remote: retired))
    }
}

private final class PersistencePreparationGate: @unchecked Sendable {
    private let started: XCTestExpectation
    private let semaphore = DispatchSemaphore(value: 0)

    init(started: XCTestExpectation) { self.started = started }
    func release() { semaphore.signal() }

    func generate(_ source: Game) throws -> Game {
        started.fulfill()
        guard semaphore.wait(timeout: .now() + 4) == .success else {
            throw CancellationError()
        }
        var generated = source
        try generated.startPuzzle()
        return generated
    }
}
