import XCTest
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class PreparedPuzzleTests: XCTestCase {
    func testPreparationMatchesSynchronousDealWithoutAdvancingLiveState() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
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
            let preview = try XCTUnwrap(model.preparedPuzzlePreview)
            XCTAssertEqual(try encoder.encode(preview.board),
                           try encoder.encode(XCTUnwrap(prepared.puzzle).board))
            let expected = try await Task.detached {
                var game = original
                try game.startPuzzle()
                return game
            }.value

            let commitStarted = clock.now
            XCTAssertTrue(model.beginPreparedPuzzle(prepared))
            let commitTime = commitStarted.duration(to: clock.now)
            XCTAssertEqual(try model.game.encoded(), try expected.encoded())
            XCTAssertEqual(try encoder.encode(XCTUnwrap(model.puzzle).board), try encoder.encode(preview.board),
                           "Play must deal the exact board shown in the briefing")
            XCTAssertNil(model.preparedPuzzlePreview)
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
            await model.prepareUpcomingPuzzle(using: { try probe.generate($0) })
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

    func testPersistenceEncodingWarmsOffMainWithoutCommittingASaveState() async throws {
        let model = makeModel()
        let original = try model.game.encoded()
        let originalSaveState = try RunStore.dataForStorage(of: model.game)
        let probe = PersistenceWarmupProbe()
        let started = expectation(description: "Detached persistence encoding completed")
        probe.started = started
        let waiting = Task {
            await model.prepareUpcomingPuzzle(warmingPersistenceWith: { probe.warm($0) })
        }
        await fulfillment(of: [started], timeout: 8)

        XCTAssertFalse(probe.ranOnMain)
        XCTAssertNotNil(probe.warmedGame?.puzzle, "Warm the dealt board, not the empty briefing state.")
        XCTAssertEqual(try model.game.encoded(), original)
        XCTAssertEqual(try RunStore.dataForStorage(of: model.game), originalSaveState,
                       "The durable live snapshot must remain the briefing until acceptance.")
        XCTAssertEqual(model.page, .briefing)
        XCTAssertFalse(model.hasPreparedPuzzle)
        probe.release()
        let result = await waiting.value
        let prepared = try XCTUnwrap(result)
        XCTAssertEqual(try model.game.encoded(), original,
                       "Completing warm-up is not permission to save the future puzzle.")
        XCTAssertTrue(model.beginPreparedPuzzle(prepared))
        XCTAssertEqual(model.page, .puzzle)
        XCTAssertEqual(try model.game.encoded(), try probe.warmedGame?.encoded())
    }

    func testWarmLookupReusesOneGeneration() async throws {
        let model = makeModel()
        let probe = PreparationProbe(blocking: false)
        let first = await model.prepareUpcomingPuzzle(using: { try probe.generate($0) })
        let second = await model.prepareUpcomingPuzzle(using: { try probe.generate($0) })
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
        XCTAssertNil(model.preparedPuzzlePreview, "A revised run cannot display the previous prepared board")
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
        // The next slot must be entered through an accepted transition, not
        // a stale Shop callback while this Puzzle is still only a briefing.
        XCTAssertTrue(model.takeSkip(ifCurrent: try XCTUnwrap(model.currentSkipClaim)))
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
        let waiting = Task { await model.prepareUpcomingPuzzle(using: { try probe.generate($0) }) }
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
        let waiting = Task { await model.prepareUpcomingPuzzle(using: { try probe.generate($0) }) }
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

    func testAcceptedSkipInvalidatesAReadyDealWithoutLosingItsReward() async throws {
        let model = makeModel()
        let prepared = try await prepare(model)
        let claim = try XCTUnwrap(model.currentSkipClaim)
        XCTAssertTrue(model.takeSkip(ifCurrent: claim))
        let committed = try model.game.encoded()

        XCTAssertFalse(model.beginPreparedPuzzle(prepared))
        XCTAssertEqual(try model.game.encoded(), committed)
        XCTAssertEqual(model.run.slot, .medium)
        XCTAssertEqual(model.run.skipHistory.count, 1)
        XCTAssertEqual(model.run.buffs.map(\.defID), [claim.offer.buffID])
        let next = try await prepare(model)
        XCTAssertTrue(model.beginPreparedPuzzle(next))
        XCTAssertEqual(model.puzzle?.slot, .medium)
        XCTAssertEqual(model.run.buffs.map(\.defID), [claim.offer.buffID])
    }

    func testAcceptedSkipWhilePreparingCannotPublishTheSkippedPuzzle() async throws {
        let model = makeModel()
        let probe = PreparationProbe()
        let started = expectation(description: "Skipped puzzle is preparing")
        probe.started = started
        let waiting = Task { await model.prepareUpcomingPuzzle(using: { try probe.generate($0) }) }
        await fulfillment(of: [started], timeout: 3)

        let claim = try XCTUnwrap(model.currentSkipClaim)
        XCTAssertTrue(model.takeSkip(ifCurrent: claim))
        let committed = try model.game.encoded()
        probe.release()
        let stale = await waiting.value

        XCTAssertNil(stale)
        XCTAssertFalse(model.hasPreparedPuzzle)
        XCTAssertEqual(try model.game.encoded(), committed)
        XCTAssertEqual(model.run.slot, .medium)
        XCTAssertEqual(model.run.skipHistory.count, 1)
        XCTAssertEqual(model.run.buffs.map(\.defID), [claim.offer.buffID])
        XCTAssertFalse(model.takeSkip(ifCurrent: claim))
    }

    func testConcurrentPrewarmAndPlayShareTheSameWorker() async throws {
        let model = makeModel()
        let probe = PreparationProbe()
        let started = expectation(description: "Shared worker started")
        probe.started = started
        let prewarm = Task { await model.prepareUpcomingPuzzle(using: { try probe.generate($0) }) }
        await fulfillment(of: [started], timeout: 3)
        let play = Task { await model.prepareUpcomingPuzzle(using: { try probe.generate($0) }) }
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
        let prewarm = Task { await model.prepareUpcomingPuzzle(using: { try probe.generate($0) }) }
        await fulfillment(of: [started], timeout: 3)
        let play = Task { await model.prepareUpcomingPuzzle(using: { try probe.generate($0) }) }
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
        let prepared = await model.prepareUpcomingPuzzle(using: { try probe.generate($0) })
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

    func testShopBossPreparationRunsOffMainAndCommitsExactlyOnce() async throws {
        let original = try shopFixture()
        var saves: [Data] = []
        let persistence = GameModel.Persistence(save: { game, _ in
            saves.append(try! game.encoded()); return true
        }, recordCompletion: { _, _ in true }, clear: { true }, recordsPlayerProfile: false)
        let model = GameModel(resuming: original, savesProgress: true, persistence: persistence)
        saves.removeAll()
        let bytes = try original.encoded()
        let probe = ShopPreparationProbe()
        let started = expectation(description: "Boss preparation is off main")
        probe.started = started
        let task = Task { await model.prepareShopExit(using: { try probe.advance($0) }) }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertFalse(probe.ranOnMain)
        XCTAssertEqual(try model.game.encoded(), bytes)
        XCTAssertTrue(saves.isEmpty)
        XCTAssertEqual(model.page, .shop)
        probe.release()
        let result = await task.value
        let ready = try XCTUnwrap(result)
        let second = await model.prepareShopExit(using: { try probe.advance($0) })
        XCTAssertNotNil(second)
        XCTAssertEqual(probe.calls, 1)
        var expected = original
        XCTAssertTrue(expected.advance())
        XCTAssertTrue(model.leavePreparedShop(ready))
        XCTAssertEqual(try model.game.encoded(), try expected.encoded())
        XCTAssertEqual(model.page, .briefing)
        XCTAssertEqual(model.run.level, 2)
        XCTAssertEqual(saves, [try expected.encoded()])
        XCTAssertFalse(model.leavePreparedShop(ready))
        XCTAssertFalse(model.leavePreparedShop(try XCTUnwrap(second)))
        XCTAssertEqual(saves.count, 1)
        let resumed = GameModel(resuming: try Game(decoding: saves[0]), savesProgress: false)
        XCTAssertEqual(resumed.run.pendingBoss, expected.run.pendingBoss)
        XCTAssertEqual(resumed.currentSkipClaim?.offer, model.currentSkipClaim?.offer)
    }

    func testShopMutationInvalidatesPreparedBossAndPreservesPurchase() async throws {
        let model = GameModel(resuming: try shopFixture(), savesProgress: false)
        let result = await model.prepareShopExit()
        let ready = try XCTUnwrap(result)
        model.qaAward(coins: 20)
        model.reroll()
        let updated = try model.game.encoded()
        XCTAssertFalse(model.leavePreparedShop(ready))
        XCTAssertEqual(try model.game.encoded(), updated)
        var expected = model.game
        XCTAssertTrue(expected.advance())
        let replacement = await model.prepareShopExit()
        XCTAssertTrue(model.leavePreparedShop(try XCTUnwrap(replacement)))
        XCTAssertEqual(try model.game.encoded(), try expected.encoded())
    }

    func testCancelledShopPreparationCannotAdvanceOrReplaceANewerRun() async throws {
        let model = GameModel(resuming: try shopFixture(), savesProgress: false)
        let before = try model.game.encoded()
        let probe = ShopPreparationProbe()
        let started = expectation(description: "Shop worker began")
        probe.started = started
        let task = Task { await model.prepareShopExit(using: { try probe.advance($0) }) }
        await fulfillment(of: [started], timeout: 3)
        model.cancelPuzzlePreparation() // Background/departure uses this shared cancellation boundary.
        probe.release()
        let cancelled = await task.value
        XCTAssertNil(cancelled)
        XCTAssertEqual(try model.game.encoded(), before)
        let ready = await model.prepareShopExit()
        XCTAssertTrue(model.abandonRun())
        XCTAssertFalse(model.leavePreparedShop(try XCTUnwrap(ready)))
        XCTAssertEqual(try model.game.encoded(), before)
    }

    private func shopFixture() throws -> Game {
        var run = RunState(seed: "prepared-chapter-exit")
        run.slot = .boss
        run.pendingBoss = .editor
        var game = Game(run: run)
        try game.startPuzzle()
        game.qaMeetTarget()
        _ = try game.cashOut()
        game.openShop()
        XCTAssertNotNil(game.shop)
        return game
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

private final class ShopPreparationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var main = false
    private var count = 0
    var started: XCTestExpectation?
    var ranOnMain: Bool { lock.withLock { main } }
    var calls: Int { lock.withLock { count } }
    func release() { gate.signal() }
    func advance(_ source: Game) throws -> Game {
        lock.withLock { main = Thread.isMainThread; count += 1 }
        started?.fulfill()
        _ = gate.wait(timeout: .now() + 3)
        var next = source
        _ = next.advance()
        return next
    }
}

private final class PersistenceWarmupProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var recordedMain = false
    private var recordedGame: Game?
    var started: XCTestExpectation?

    var ranOnMain: Bool { lock.withLock { recordedMain } }
    var warmedGame: Game? { lock.withLock { recordedGame } }
    func release() { gate.signal() }

    func warm(_ game: Game) {
        GameModel.warmPersistenceEncoding(game)
        lock.withLock {
            recordedMain = Thread.isMainThread
            recordedGame = game
        }
        started?.fulfill()
        _ = gate.wait(timeout: .now() + 3)
    }
}

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
