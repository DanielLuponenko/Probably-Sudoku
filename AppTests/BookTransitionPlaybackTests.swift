import XCTest
@testable import ProbablySudoku

@MainActor
final class BookTransitionPlaybackTests: XCTestCase {
    func testBothDirectionsKeepTheirTimingsAndCompleteOnlyOnce() async {
        for direction in [BookTransitionPlayback.Direction.opening, .closing] {
            let playback = BookTransitionPlayback(direction: direction)
            var waits: [Duration] = []
            var haptics = 0
            var finishes = 0
            await playback.play(request(), wait: { waits.append($0) }, haptic: { haptics += 1 }) {
                finishes += 1
            }

            XCTAssertTrue(playback.hasFinished)
            XCTAssertEqual(playback.angle, direction == .opening ? -172 : 0)
            XCTAssertEqual(playback.zoom, direction == .opening ? 1 : 0)
            XCTAssertEqual(playback.wash, direction == .opening ? 1 : 0)
            XCTAssertEqual(waits.count, direction == .opening ? 3 : 2)
            let elapsed = waits.reduce(Duration.zero, +).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            XCTAssertEqual(seconds, direction == .opening ? 1.35 : 0.9, accuracy: 0.000_001)
            XCTAssertEqual(haptics, 1)
            XCTAssertEqual(finishes, 1)

            await playback.play(request(skip: true), wait: { _ in XCTFail("Already finished") },
                                haptic: { XCTFail("Already finished") }) { finishes += 1 }
            XCTAssertEqual(finishes, 1)
        }
    }

    func testThrownCancellationNeverFinishesAnOpeningOrClosing() async {
        for direction in [BookTransitionPlayback.Direction.opening, .closing] {
            for skip in [false, true] {
                let playback = BookTransitionPlayback(direction: direction)
                var finishes = 0
                await playback.play(request(skip: skip), wait: { _ in throw CancellationError() },
                                    haptic: {}) { finishes += 1 }
                XCTAssertEqual(finishes, 0)
                XCTAssertFalse(playback.hasFinished)
            }
        }
    }

    func testDisappearanceRejectsAnAlreadyFinishingWaitWithoutCompletingOrMovingAgain() async {
        for direction in [BookTransitionPlayback.Direction.opening, .closing] {
            for skip in [false, true] {
                let playback = BookTransitionPlayback(direction: direction)
                let gate = BookTransitionGate(started: expectation(description: "Cover waiting"))
                var finishes = 0
                let task = Task { @MainActor in
                    await playback.play(request(skip: skip), wait: gate.wait, haptic: {}) { finishes += 1 }
                }
                await fulfillment(of: [gate.started], timeout: 1)
                playback.cancel()
                let angle = playback.angle, zoom = playback.zoom, wash = playback.wash
                gate.release()
                await task.value

                XCTAssertEqual(finishes, 0)
                XCTAssertFalse(playback.hasFinished)
                XCTAssertEqual(playback.angle, angle)
                XCTAssertEqual(playback.zoom, zoom)
                XCTAssertEqual(playback.wash, wash)
            }
        }
    }

    func testViewTaskCancellationRejectsAWaitThatDoesNotThrow() async {
        let playback = BookTransitionPlayback(direction: .opening)
        let gate = BookTransitionGate(started: expectation(description: "Opening started"))
        var finishes = 0
        let task = Task { @MainActor in
            await playback.play(request(), wait: gate.wait, haptic: {}) { finishes += 1 }
        }
        await fulfillment(of: [gate.started], timeout: 1)
        task.cancel()
        gate.release()
        await task.value

        XCTAssertEqual(finishes, 0)
        XCTAssertFalse(playback.hasFinished)
        XCTAssertEqual(playback.zoom, 0)
        XCTAssertEqual(playback.wash, 0)
    }

    func testSkipTakesOwnershipAndOldAutomaticWaitCannotFinishAgain() async {
        for direction in [BookTransitionPlayback.Direction.opening, .closing] {
            let playback = BookTransitionPlayback(direction: direction)
            let gate = BookTransitionGate(started: expectation(description: "Automatic cover started"))
            var finishes = 0
            let task = Task { @MainActor in
                await playback.play(request(), wait: gate.wait, haptic: {}) { finishes += 1 }
            }
            await fulfillment(of: [gate.started], timeout: 1)
            var skipWaits: [Duration] = []
            await playback.play(request(skip: true), wait: { skipWaits.append($0) }, haptic: {
                XCTFail("Skipping does not add another haptic")
            }) { finishes += 1 }
            gate.release()
            await task.value

            XCTAssertEqual(skipWaits, [.milliseconds(160)])
            XCTAssertTrue(playback.hasFinished)
            XCTAssertEqual(playback.wash, direction == .opening ? 1 : 0)
            if direction == .closing { XCTAssertEqual(playback.angle, 0) }
            XCTAssertEqual(finishes, 1)
        }
    }

    func testInactiveSceneDoesNotCompleteEvenWithReduceMotionAndActiveReturnFinishesOnce() async {
        for direction in [BookTransitionPlayback.Direction.opening, .closing] {
            let playback = BookTransitionPlayback(direction: direction)
            var finishes = 0
            await playback.play(.init(isSceneActive: false, reduceMotion: true, skip: true),
                                wait: { _ in XCTFail("Inactive") }, haptic: { XCTFail("Inactive") }) {
                finishes += 1
            }
            XCTAssertFalse(playback.hasFinished)
            XCTAssertEqual(finishes, 0)
            XCTAssertEqual(playback.wash, 0)
            await playback.play(.init(isSceneActive: true, reduceMotion: true, skip: false),
                                wait: { _ in XCTFail("Reduce Motion") }, haptic: { XCTFail("Reduce Motion") }) {
                finishes += 1
            }
            XCTAssertTrue(playback.hasFinished)
            XCTAssertEqual(finishes, 1)
        }
    }

    func testForegroundRestartOwnsCompletionEvenWhenOldBackgroundWaitReturnsLast() async {
        let playback = BookTransitionPlayback(direction: .closing)
        let gate = BookTransitionGate(started: expectation(description: "Closing before background"))
        var finishes = 0
        let old = Task { @MainActor in
            await playback.play(request(), wait: gate.wait, haptic: {}) { finishes += 1 }
        }
        await fulfillment(of: [gate.started], timeout: 1)
        playback.cancel()
        await playback.play(request(), wait: { _ in }, haptic: {}) { finishes += 1 }
        gate.release()
        await old.value
        XCTAssertTrue(playback.hasFinished)
        XCTAssertEqual(playback.angle, 0)
        XCTAssertEqual(playback.wash, 0)
        XCTAssertEqual(finishes, 1)
    }

    func testClosingKeepsCoverOpenUntilTheActualPageHasWithdrawn() async {
        let playback = BookTransitionPlayback(direction: .closing)
        let gate = BookTransitionGate(started: expectation(description: "Actual page is withdrawing"))
        var waits: [Duration] = []
        var finishes = 0
        let task = Task { @MainActor in
            await playback.play(request(), hasOutgoingPage: true, wait: { duration in
                waits.append(duration)
                if waits.count == 1 { try await gate.wait(duration) }
            }, haptic: {}) { finishes += 1 }
        }
        await fulfillment(of: [gate.started], timeout: 1)
        XCTAssertEqual(waits, [.milliseconds(280)])
        XCTAssertEqual(playback.angle, -172)
        XCTAssertEqual(playback.zoom, 1)
        XCTAssertFalse(playback.hasWithdrawnPage)
        XCTAssertEqual(finishes, 0)
        gate.release()
        await task.value
        XCTAssertTrue(playback.hasWithdrawnPage)
        XCTAssertEqual(playback.angle, 0)
        XCTAssertEqual(playback.wash, 0)
        XCTAssertEqual(finishes, 1)
        XCTAssertEqual(waits.count, 3)
    }

    func testCancelledPageWithdrawalCannotStartTheCoverOrCloseTheBook() async {
        let playback = BookTransitionPlayback(direction: .closing)
        let gate = BookTransitionGate(started: expectation(description: "Page withdrawal started"))
        var finishes = 0
        let task = Task { @MainActor in
            await playback.play(request(), hasOutgoingPage: true, wait: gate.wait, haptic: {}) { finishes += 1 }
        }
        await fulfillment(of: [gate.started], timeout: 1)
        playback.cancel()
        gate.release()
        await task.value
        XCTAssertEqual(playback.angle, -172)
        XCTAssertFalse(playback.hasWithdrawnPage)
        XCTAssertFalse(playback.hasFinished)
        XCTAssertEqual(finishes, 0)
    }

    func testClosingAndItsSkipNeverWashOutTheCoverDuringTheStandHandoff() async {
        for skip in [false, true] {
            let playback = BookTransitionPlayback(direction: .closing)
            var waits: [Duration] = []
            var finishes = 0
            await playback.play(request(skip: skip), hasOutgoingPage: true, wait: { duration in
                waits.append(duration)
                XCTAssertEqual(playback.wash, 0, "The cover remains visible at every handoff stage")
            }, haptic: {}) {
                finishes += 1
                XCTAssertEqual(playback.angle, 0)
                XCTAssertEqual(playback.wash, 0)
                XCTAssertTrue(playback.hasWithdrawnPage)
            }
            XCTAssertTrue(playback.hasFinished)
            XCTAssertEqual(finishes, 1)
            if skip { XCTAssertEqual(waits, [.milliseconds(160)]) }
            await playback.play(request(skip: true), hasOutgoingPage: true,
                                wait: { _ in XCTFail("Already closed") }, haptic: {}) { finishes += 1 }
            XCTAssertEqual(finishes, 1)
        }
    }

    func testActualPageWithdrawalPreservesImageAspectRatioAndStaysInsideSmallAndLargeScreens() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 375, height: 667),
                     CGSize(width: 402, height: 874), CGSize(width: 430, height: 932),
                     CGSize(width: 768, height: 1024)] {
            let page = BookClosingPageGeometry(viewport: size, imageSize: size)
            let screen = CGRect(origin: .zero, size: size)
            XCTAssertEqual(page.initial, screen)
            XCTAssertEqual(page.frame(at: 0), screen)
            XCTAssertEqual(page.frame(at: 1), page.leaf)
            XCTAssertLessThan(page.leaf.width, screen.width)
            XCTAssertLessThan(page.leaf.height, screen.height)
            for progress in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let frame = page.frame(at: progress)
                XCTAssertTrue(screen.contains(frame), "\(size), progress \(progress): \(frame)")
                XCTAssertEqual(frame.width / frame.height, size.width / size.height, accuracy: 0.000_001)
            }
        }
    }

    private func request(skip: Bool = false) -> BookTransitionPlayback.Request {
        .init(isSceneActive: true, reduceMotion: false, skip: skip)
    }
}

@MainActor
private final class BookTransitionGate {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?

    init(started: XCTestExpectation) { self.started = started }

    func wait(_ duration: Duration) async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }

    func release() {
        let waiting = continuation
        continuation = nil
        waiting?.resume()
    }
}
