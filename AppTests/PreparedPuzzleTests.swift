import XCTest
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class PreparedPuzzleTests: XCTestCase {
    func testPreparationMatchesSynchronousDealWithoutAdvancingLiveState() async throws {
        for slot in [PuzzleSlot.easy, .medium, .boss] {
            var run = RunState(seed: "prepared-puzzle-determinism")
            run.slot = slot
            if slot == .boss { run.pendingBoss = .censor }
            let original = Game(run: run)
            let originalBytes = try original.encoded()
            let model = GameModel(resuming: original, savesProgress: false)
            let clock = ContinuousClock()
            let started = clock.now
            let prepared = try await prepare(model)
            let preparationTime = started.duration(to: clock.now)

            XCTAssertEqual(try model.game.encoded(), originalBytes)
            XCTAssertEqual(model.page, .briefing)
            let expected = try await Task.detached {
                var game = original
                try game.startPuzzle()
                return game
            }.value

            let commitStarted = clock.now
            XCTAssertTrue(model.beginPreparedPuzzle(prepared))
            let commitTime = commitStarted.duration(to: clock.now)
            XCTAssertEqual(try model.game.encoded(), try expected.encoded())
            XCTAssertEqual(model.page, .puzzle)
            XCTAssertFalse(model.beginPreparedPuzzle(prepared), "A prepared deal commits only once.")
            print("PUZZLE_PREPARATION slot=\(slot.rawValue) generate=\(preparationTime) commit=\(commitTime)")
        }
    }

    func testPreparationRunsOffMainAndMainActorRemainsAvailable() async throws {
        let model = makeModel()
        let probe = PreparationProbe()
        let started = expectation(description: "Detached generator started")
        probe.started = started
        let waiting = Task {
            await model.prepareUpcomingPuzzle(using: probe.generate)
        }
        await fulfillment(of: [started], timeout: 3)
        // This assertion runs while the generator is still waiting, proving
        // that generation does not occupy the main actor's display-link lane.
        XCTAssertFalse(probe.ranOnMain)
        XCTAssertEqual(probe.calls, 1)
        probe.release()
        let prepared = await waiting.value
        XCTAssertNotNil(prepared)
        XCTAssertEqual(model.page, .briefing)
    }

    func testWarmLookupReusesOneGeneration() async throws {
        let model = makeModel()
        let probe = PreparationProbe(blocking: false)
        let first = await model.prepareUpcomingPuzzle(using: probe.generate)
        let second = await model.prepareUpcomingPuzzle(using: probe.generate)
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(probe.calls, 1)
        XCTAssertTrue(model.beginPreparedPuzzle(try XCTUnwrap(second)))
        XCTAssertFalse(model.beginPreparedPuzzle(try XCTUnwrap(first)))
    }

    func testInventoryAndCoinMutationRejectsAnOldPreparedDeal() async throws {
        let model = makeModel()
        let prepared = try await prepare(model)
        let revision = model.puzzlePreparationRevision
        model.qaAward(coins: 9)
        model.qaSetBookmark("bm_help_wanted")
        XCTAssertGreaterThan(model.puzzlePreparationRevision, revision)
        let changed = try model.game.encoded()
        XCTAssertFalse(model.beginPreparedPuzzle(prepared))
        XCTAssertEqual(try model.game.encoded(), changed)

        var expected = model.game
        try expected.startPuzzle()
        let replacement = try await prepare(model)
        XCTAssertTrue(model.beginPreparedPuzzle(replacement))
        XCTAssertEqual(try model.game.encoded(), try expected.encoded())
    }

    func testChangingSlotRejectsOldPreparedBoardAndRNG() async throws {
        let model = makeModel()
        let prepared = try await prepare(model)
        model.continueToNextPuzzle()
        let changed = try model.game.encoded()
        XCTAssertEqual(model.run.slot, .medium)
        XCTAssertFalse(model.beginPreparedPuzzle(prepared))
        XCTAssertEqual(try model.game.encoded(), changed)
    }

    func testCancellationDiscardsReadyResultWithoutChangingLiveRNG() async throws {
        let model = makeModel()
        let original = try model.game.encoded()
        let prepared = try await prepare(model)
        model.cancelPuzzlePreparation()
        XCTAssertFalse(model.beginPreparedPuzzle(prepared))
        XCTAssertEqual(try model.game.encoded(), original)
        XCTAssertEqual(model.page, .briefing)
    }

    func testCancelledInFlightPreparationCannotPublishItsResult() async throws {
        let model = makeModel()
        let original = try model.game.encoded()
        let probe = PreparationProbe()
        let started = expectation(description: "Preparation can be cancelled")
        probe.started = started
        let waiting = Task { await model.prepareUpcomingPuzzle(using: probe.generate) }
        await fulfillment(of: [started], timeout: 3)
        waiting.cancel()
        model.cancelPuzzlePreparation()
        probe.release()
        let prepared = await waiting.value
        XCTAssertNil(prepared)
        XCTAssertEqual(try model.game.encoded(), original)
        XCTAssertEqual(model.page, .briefing)
    }

    func testMutationWhilePreparingCannotPublishStaleInventoryOrRNG() async throws {
        let model = makeModel()
        let probe = PreparationProbe()
        let started = expectation(description: "Old snapshot worker started")
        probe.started = started
        let waiting = Task { await model.prepareUpcomingPuzzle(using: probe.generate) }
        await fulfillment(of: [started], timeout: 3)
        model.qaAward(coins: 13)
        let changed = try model.game.encoded()
        probe.release()
        let stale = await waiting.value
        XCTAssertNil(stale)
        XCTAssertFalse(model.hasPreparedPuzzle)
        XCTAssertEqual(try model.game.encoded(), changed)
        let current = try await prepare(model)
        XCTAssertTrue(model.beginPreparedPuzzle(current))
        XCTAssertEqual(model.coins, 18)
    }

    func testConcurrentPrewarmAndPlayShareTheSameWorker() async throws {
        let model = makeModel()
        let probe = PreparationProbe()
        let started = expectation(description: "Shared worker started")
        probe.started = started
        let prewarm = Task { await model.prepareUpcomingPuzzle(using: probe.generate) }
        await fulfillment(of: [started], timeout: 3)
        let play = Task { await model.prepareUpcomingPuzzle(using: probe.generate) }
        await Task.yield()
        probe.release()
        let first = await prewarm.value
        let second = await play.value
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(probe.calls, 1)
        XCTAssertTrue(model.beginPreparedPuzzle(try XCTUnwrap(second)))
        XCTAssertFalse(model.beginPreparedPuzzle(try XCTUnwrap(first)))
    }

    func testCancelledPlayWaiterDoesNotCancelTheBriefingPrewarm() async throws {
        let model = makeModel()
        let probe = PreparationProbe()
        let started = expectation(description: "Briefing owns shared worker")
        probe.started = started
        let prewarm = Task { await model.prepareUpcomingPuzzle(using: probe.generate) }
        await fulfillment(of: [started], timeout: 3)
        let play = Task { await model.prepareUpcomingPuzzle(using: probe.generate) }
        await Task.yield()
        play.cancel()
        probe.release()
        let warmed = await prewarm.value
        let cancelled = await play.value
        XCTAssertNotNil(warmed)
        XCTAssertNil(cancelled)
        XCTAssertEqual(probe.calls, 1)
        XCTAssertTrue(model.hasPreparedPuzzle)
        XCTAssertEqual(model.page, .briefing)
    }

    func testFailedPreparationDoesNotMutateAndReportsOnlyForPlayRequest() async throws {
        let model = makeModel()
        let original = try model.game.encoded()
        let result = await model.prepareUpcomingPuzzle(using: { _ in throw PreparationFailure.expected })
        XCTAssertNil(result)
        XCTAssertNil(model.message, "Background prewarming is quiet.")
        let requested = await model.prepareUpcomingPuzzle(reportFailure: true)
        XCTAssertNil(requested)
        XCTAssertNotNil(model.message)
        XCTAssertEqual(try model.game.encoded(), original)
    }

    func testFrozenPageNeverPreparesOrChangesRun() async throws {
        let original = Game(seed: "prepared-frozen")
        let model = GameModel(frozen: original, page: .briefing)
        let probe = PreparationProbe(blocking: false)
        let prepared = await model.prepareUpcomingPuzzle(using: probe.generate)
        XCTAssertNil(prepared)
        XCTAssertEqual(probe.calls, 0)
        XCTAssertEqual(try model.game.encoded(), try original.encoded())
    }

    func testCancelledFlipNeverCommitsPreparedPuzzle() async throws {
        let model = makeModel()
        let original = try model.game.encoded()
        let prepared = try await prepare(model)
        let driver = PreparedPuzzleTurnDriver()
        let flipper = PageFlipper(driver: driver, snapshotProvider: Self.snapshot)
        let started = expectation(description: "Prepared turn starts")
        driver.started = { started.fulfill() }
        let turning = Task {
            await flipper.flip(from: model, reduceMotion: false) {
                _ = model.beginPreparedPuzzle(prepared)
            }
        }
        await fulfillment(of: [started], timeout: 1)
        flipper.cancel()
        await turning.value
        driver.firstFrame?()
        XCTAssertEqual(try model.game.encoded(), original)
        XCTAssertEqual(model.page, .briefing)
    }

    private func makeModel() -> GameModel {
        GameModel(resuming: Game(seed: "prepared-puzzle-tests"), savesProgress: false)
    }

    private func prepare(_ model: GameModel) async throws -> GameModel.PreparedPuzzle {
        let result = await model.prepareUpcomingPuzzle()
        return try XCTUnwrap(result)
    }

    private static func snapshot() -> PageTurnSnapshot {
        let size = CGSize(width: 8, height: 12)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return PageTurnSnapshot(image: image.cgImage!, size: size, scale: 1)
    }
}

private enum PreparationFailure: Error { case expected }

/// Only the test worker waits. A bounded wait makes a scheduling regression
/// fail rather than hanging the suite if someone moves generation to main.
private final class PreparationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private let blocking: Bool
    private var recordedCalls = 0
    private var recordedMain = false
    var started: XCTestExpectation?

    init(blocking: Bool = true) { self.blocking = blocking }
    var calls: Int { lock.withLock { recordedCalls } }
    var ranOnMain: Bool { lock.withLock { recordedMain } }
    func release() { gate.signal() }

    func generate(_ source: Game) throws -> Game {
        lock.withLock {
            recordedCalls += 1
            recordedMain = recordedMain || Thread.isMainThread
        }
        started?.fulfill()
        if blocking { _ = gate.wait(timeout: .now() + 2) }
        var game = source
        try game.startPuzzle()
        return game
    }
}

@MainActor
private final class PreparedPuzzleTurnDriver: PageTurnRendering {
    var started: (() -> Void)?
    var firstFrame: (() -> Void)?
    func prepare(image: CGImage, pageSize: CGSize, scale: CGFloat) -> Bool { true }
    func start(duration: TimeInterval, heldProgress: Double?,
               onFirstFrame: @escaping @MainActor () -> Void,
               completion: @escaping @MainActor () -> Void) {
        firstFrame = onFirstFrame
        started?()
    }
    func cancel() {}
}
