import XCTest
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Exercises navigation ownership without a GPU, display clock or animation
/// delays. The driver advances only when a test explicitly presents a frame.
@MainActor
final class PageFlipTests: XCTestCase {
    func testReduceMotionChangesPageWithoutCapturingOrStartingRenderer() async {
        let driver = ManualPageTurnRenderer()
        var captures = 0
        var changes = 0
        let flipper = PageFlipper(driver: driver) {
            captures += 1
            return Self.snapshot()
        }

        await flipper.flip(from: model(), reduceMotion: true) { changes += 1 }

        XCTAssertEqual(changes, 1)
        XCTAssertEqual(captures, 0)
        XCTAssertEqual(driver.prepareCount, 0)
        XCTAssertTrue(driver.starts.isEmpty)
        XCTAssertFalse(flipper.isFlipping)
    }

    func testMissingSnapshotDoesNotBlockNavigation() async {
        let driver = ManualPageTurnRenderer()
        let flipper = PageFlipper(driver: driver, snapshotProvider: { nil })
        var changes = 0

        await flipper.flip(from: model(), reduceMotion: false) { changes += 1 }

        XCTAssertEqual(changes, 1)
        XCTAssertEqual(driver.prepareCount, 0)
        XCTAssertTrue(driver.starts.isEmpty)
        XCTAssertFalse(flipper.isFlipping)
    }

    func testRendererPreparationFailureDoesNotBlockNavigation() async {
        let driver = ManualPageTurnRenderer()
        driver.canPrepare = false
        let flipper = makeFlipper(driver: driver)
        var changes = 0

        await flipper.flip(from: model(), reduceMotion: false) { changes += 1 }

        XCTAssertEqual(changes, 1)
        XCTAssertEqual(driver.prepareCount, 1)
        XCTAssertTrue(driver.starts.isEmpty)
        XCTAssertFalse(flipper.isFlipping)
    }

    func testAlreadyCancelledTaskDoesNotCaptureOrChangePage() async {
        let driver = ManualPageTurnRenderer()
        let flipper = makeFlipper(driver: driver)
        var changes = 0
        let finished = expectation(description: "Cancelled request returned")
        let source = model()
        let task = Task { @MainActor in
            await flipper.flip(from: source, reduceMotion: false) { changes += 1 }
            finished.fulfill()
        }
        // This MainActor task cannot start until this method yields below.
        task.cancel()
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertEqual(changes, 0)
        XCTAssertEqual(driver.prepareCount, 0)
        XCTAssertTrue(driver.starts.isEmpty)
        XCTAssertFalse(flipper.isFlipping)
    }

    func testDestinationChangesOnlyAfterPrintedFirstFrameAndUnlocksOnCompletion() async {
        let driver = ManualPageTurnRenderer()
        let flipper = makeFlipper(driver: driver)
        defer { flipper.cancel() }
        var changes = 0
        let turn = await startTurn(flipper, driver: driver) { changes += 1 }

        XCTAssertTrue(flipper.isFlipping)
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(driver.prepareCount, 1)
        XCTAssertEqual(driver.preparedSize, CGSize(width: 8, height: 12))
        guard let callbacks = driver.starts.first else { return }

        callbacks.firstFrame()
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(flipper.isFlipping)

        callbacks.completion()
        await fulfillment(of: [turn.finished], timeout: 1)
        XCTAssertFalse(flipper.isFlipping)
        XCTAssertEqual(driver.cancelCount, 0)
        callbacks.completion()
        XCTAssertFalse(flipper.isFlipping)
    }

    func testRepeatedTapCannotStartAnotherTurnOrChangeDestination() async {
        let driver = ManualPageTurnRenderer()
        let flipper = makeFlipper(driver: driver)
        defer { flipper.cancel() }
        var firstChanges = 0
        var secondChanges = 0
        let turn = await startTurn(flipper, driver: driver) { firstChanges += 1 }

        await flipper.flip(from: model(), reduceMotion: false) { secondChanges += 1 }

        XCTAssertEqual(driver.starts.count, 1)
        XCTAssertEqual(driver.prepareCount, 1)
        XCTAssertEqual(secondChanges, 0)
        guard let callbacks = driver.starts.first else { return }
        callbacks.firstFrame()
        callbacks.completion()
        await fulfillment(of: [turn.finished], timeout: 1)
        XCTAssertEqual(firstChanges, 1)
        XCTAssertEqual(secondChanges, 0)
    }

    func testDuplicateFirstFrameCallbackCommitsDestinationOnlyOnce() async {
        let driver = ManualPageTurnRenderer()
        let flipper = makeFlipper(driver: driver)
        defer { flipper.cancel() }
        var changes = 0
        let turn = await startTurn(flipper, driver: driver) { changes += 1 }
        guard let callbacks = driver.starts.first else { return }

        callbacks.firstFrame()
        callbacks.firstFrame()
        XCTAssertEqual(changes, 1)
        callbacks.completion()
        await fulfillment(of: [turn.finished], timeout: 1)
        callbacks.firstFrame()
        XCTAssertEqual(changes, 1)
    }

    func testCompletionBeforeFirstFrameKeepsOriginAndReleasesTurn() async {
        let driver = ManualPageTurnRenderer()
        let flipper = makeFlipper(driver: driver)
        defer { flipper.cancel() }
        var changes = 0
        let turn = await startTurn(flipper, driver: driver) { changes += 1 }
        guard let callbacks = driver.starts.first else { return }

        callbacks.completion()
        await fulfillment(of: [turn.finished], timeout: 1)
        callbacks.firstFrame()

        XCTAssertEqual(changes, 0)
        XCTAssertFalse(flipper.isFlipping)
    }

    func testCancellationBeforeFirstFrameKeepsOriginAndRejectsStaleCallbacks() async {
        let driver = ManualPageTurnRenderer()
        let flipper = makeFlipper(driver: driver)
        defer { flipper.cancel() }
        var oldChanges = 0
        var newChanges = 0
        let oldTurn = await startTurn(flipper, driver: driver) { oldChanges += 1 }
        guard let oldCallbacks = driver.starts.first else { return }

        flipper.cancel()
        flipper.cancel()
        await fulfillment(of: [oldTurn.finished], timeout: 1)
        XCTAssertEqual(driver.cancelCount, 1)
        XCTAssertFalse(flipper.isFlipping)
        XCTAssertEqual(oldChanges, 0)

        let newTurn = await startTurn(flipper, driver: driver) { newChanges += 1 }
        guard driver.starts.count == 2 else {
            XCTFail("A cancelled turn must allow another page turn")
            return
        }
        let newCallbacks = driver.starts[1]
        oldCallbacks.firstFrame()
        oldCallbacks.completion()
        XCTAssertTrue(flipper.isFlipping)
        XCTAssertEqual(oldChanges, 0)
        XCTAssertEqual(newChanges, 0)

        newCallbacks.firstFrame()
        newCallbacks.completion()
        await fulfillment(of: [newTurn.finished], timeout: 1)
        XCTAssertEqual(newChanges, 1)
        XCTAssertFalse(flipper.isFlipping)
    }

    func testTaskCancellationAfterFirstFrameKeepsCommittedDestinationAndReleasesTurn() async {
        let driver = ManualPageTurnRenderer()
        let flipper = makeFlipper(driver: driver)
        defer { flipper.cancel() }
        var changes = 0
        let turn = await startTurn(flipper, driver: driver) { changes += 1 }
        guard let callbacks = driver.starts.first else { return }
        callbacks.firstFrame()

        turn.task.cancel()
        await fulfillment(of: [turn.finished], timeout: 1)

        XCTAssertFalse(flipper.isFlipping)
        XCTAssertEqual(driver.cancelCount, 1)
        XCTAssertEqual(changes, 1)
        callbacks.firstFrame()
        callbacks.completion()
        XCTAssertEqual(changes, 1)
        XCTAssertFalse(flipper.isFlipping)
    }

    private func model() -> GameModel {
        // No tutorial, saved-run mutation or live puzzle clock in these tests.
        GameModel(frozen: Game(seed: "page-turn-lifecycle"), page: .briefing)
    }

    private func makeFlipper(driver: ManualPageTurnRenderer) -> PageFlipper {
        PageFlipper(driver: driver, snapshotProvider: { Self.snapshot() })
    }

    private static func snapshot() -> PageTurnSnapshot {
        let size = CGSize(width: 8, height: 12)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return PageTurnSnapshot(image: image.cgImage!, size: size, scale: 1)
    }

    private struct RunningTurn {
        let task: Task<Void, Never>
        let finished: XCTestExpectation
    }

    private func startTurn(_ flipper: PageFlipper,
                           driver: ManualPageTurnRenderer,
                           change: @escaping () -> Void) async -> RunningTurn {
        let started = expectation(description: "Renderer started")
        let finished = expectation(description: "Turn waiter released")
        driver.didStart = { started.fulfill() }
        let source = model()
        let task = Task { @MainActor in
            await flipper.flip(from: source, reduceMotion: false, change)
            finished.fulfill()
        }
        // A timeout is only a deadlock guard. No test relies on elapsed time to
        // advance the turn: all progress is driven by callbacks below.
        await fulfillment(of: [started], timeout: 1)
        driver.didStart = nil
        return RunningTurn(task: task, finished: finished)
    }
}

@MainActor
private final class ManualPageTurnRenderer: PageTurnRendering {
    struct Start {
        let firstFrame: @MainActor () -> Void
        let completion: @MainActor () -> Void
    }

    var canPrepare = true
    var didStart: (() -> Void)?
    private(set) var prepareCount = 0
    private(set) var preparedSize: CGSize?
    private(set) var cancelCount = 0
    private(set) var starts: [Start] = []

    func prepare(image: CGImage, pageSize: CGSize, scale: CGFloat) -> Bool {
        prepareCount += 1
        preparedSize = pageSize
        return canPrepare
    }

    func start(duration: TimeInterval, heldProgress: Double?,
               onFirstFrame: @escaping @MainActor () -> Void,
               completion: @escaping @MainActor () -> Void) {
        starts.append(Start(firstFrame: onFirstFrame, completion: completion))
        didStart?()
    }

    func cancel() { cancelCount += 1 }
}
