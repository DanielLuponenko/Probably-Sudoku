import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Calls the same explicit control actions as a learner. Continue must never
/// become a hidden implementation of buying, placing, selling or banking.
@MainActor
enum TutorialTestDriver {
    enum Failure: Error { case actionRejected(TutorialSession.Step), didNotReach(TutorialSession.Step) }

    static func act(_ session: TutorialSession) throws {
        let accepted: Bool
        switch session.step {
        case .select, .comboSelect:
            accepted = session.selectCard(try XCTUnwrap(session.targetCardID))
        case .place, .comboPlace:
            accepted = session.place(at: try XCTUnwrap(session.targetSquare))
        case .bank, .comboBank:
            accepted = session.bankTurn()
        case .buyBookmark, .buyMultiplier, .buyMarker, .buyBuff:
            accepted = session.buyOffer(try XCTUnwrap(session.targetOfferSlot))
        case .markerPlacement:
            accepted = session.claimMarker(at: try XCTUnwrap(session.targetSquare))
        case .useBuff:
            accepted = session.useBuff(try XCTUnwrap(session.targetBuffIndex))
        case .sellBookmark, .sellBuff:
            accepted = session.sellItem(kind: try XCTUnwrap(session.targetSaleKind),
                                       index: try XCTUnwrap(session.targetSaleIndex))
        case .won:
            accepted = session.cashOut()
        default:
            session.continueLesson()
            accepted = true
        }
        guard accepted else { throw Failure.actionRejected(session.step) }
    }

    static func reach(_ target: TutorialSession.Step, in session: TutorialSession) throws {
        for _ in TutorialSession.Step.allCases {
            if session.step == target { return }
            try act(session)
        }
        throw Failure.didNotReach(target)
    }

    static func complete(_ session: TutorialSession) throws {
        try reach(.ready, in: session)
        try act(session)
        XCTAssertEqual(session.completion, .completed)
    }
}

@MainActor
final class TutorialSessionTests: XCTestCase {
    func testPracticeIsDeterministicFreshEngineGameWithNormalFirstPuzzleRules() throws {
        let first = TutorialSession(practice: try TutorialPractice.make())
        let second = TutorialSession(practice: try TutorialPractice.make())
        let snapshot = try XCTUnwrap(first.snapshot)
        XCTAssertEqual(snapshot, second.snapshot)
        XCTAssertEqual(first.targetSquare, second.targetSquare)
        XCTAssertEqual(first.targetDigit, second.targetDigit)
        XCTAssertEqual(snapshot.cells.count, 81)
        XCTAssertEqual(snapshot.hand.count, 7)
        XCTAssertEqual(snapshot.turns, 10)
        XCTAssertEqual(snapshot.target, 1_000)
        XCTAssertEqual(snapshot.score, 0)
        XCTAssertEqual(snapshot.queued, 0)
        XCTAssertEqual(snapshot.coins, 5)
        XCTAssertTrue(snapshot.bookmarks.isEmpty)
        let square = try XCTUnwrap(first.targetSquare)
        let digit = try XCTUnwrap(first.targetDigit)
        XCTAssertNil(snapshot.cells[square.index].digit)
        XCTAssertFalse(Geometry.peers[square.index].contains { snapshot.cells[$0].digit == digit })
    }

    func testPlayerSelectionPlacementAndEndTurnUseRealQueueAndBankRules() throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        let before = try XCTUnwrap(session.snapshot)
        session.continueLesson()
        XCTAssertEqual(session.step, .select)
        XCTAssertTrue(session.selectCard(try XCTUnwrap(session.targetCardID)))
        XCTAssertEqual(session.step, .place)
        let square = try XCTUnwrap(session.targetSquare)
        XCTAssertTrue(session.place(at: square))
        XCTAssertEqual(session.step, .bank)
        let placed = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(placed.cells[square.index].digit, session.targetDigit)
        XCTAssertEqual(placed.hand.count, before.hand.count - 1)
        XCTAssertEqual(placed.score, 0)
        XCTAssertGreaterThan(placed.queued, 0)
        XCTAssertEqual(placed.multiplier, 1)
        XCTAssertEqual(placed.turn, 1)
        XCTAssertTrue(session.bankTurn())
        let banked = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(session.step, .banked)
        XCTAssertEqual(banked.score, placed.queued)
        XCTAssertEqual(banked.queued, 0)
        XCTAssertEqual(banked.turn, 2)
        XCTAssertEqual(banked.hand.count, before.hand.count)
        XCTAssertEqual(banked.coins, before.coins)
        XCTAssertFalse(session.bankTurn(), "A duplicate tap must not spend another Turn")
        XCTAssertEqual(session.snapshot, banked)
    }

    func testWrongPracticeTapsPreserveBoardHandTurnScoreAndCoins() throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        let before = session.snapshot
        session.continueLesson()
        XCTAssertFalse(session.selectCard(-1))
        XCTAssertEqual(session.step, .select)
        XCTAssertEqual(session.snapshot, before)
        XCTAssertNotNil(session.feedback)
        XCTAssertTrue(session.selectCard(try XCTUnwrap(session.targetCardID)))
        let wrong = try XCTUnwrap(session.snapshot?.cells.first { $0.square != session.targetSquare && $0.digit == nil })
        XCTAssertFalse(session.place(at: wrong.square))
        XCTAssertEqual(session.step, .place)
        XCTAssertEqual(session.snapshot, before)
        XCTAssertNotNil(session.feedback)
        XCTAssertTrue(session.place(at: try XCTUnwrap(session.targetSquare)))
        XCTAssertNil(session.feedback)
    }

    func testIdleAndContinueNeverPerformLearnerActions() async throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        for expected in TutorialSession.Step.allCases {
            XCTAssertEqual(session.step, expected)
            let before = session.snapshot
            await session.advanceWhenIdle(enabled: true, delay: .zero)
            await session.advanceWhenIdle(enabled: false, delay: .zero)
            XCTAssertEqual(session.step, expected, "Waiting must not advance any lesson")
            XCTAssertEqual(session.snapshot, before)
            XCTAssertNil(session.completion)
            if expected.requiresInteraction {
                session.continueLesson()
                XCTAssertEqual(session.step, expected, "Continue must not bypass \(expected)")
                XCTAssertEqual(session.snapshot, before)
            }
            try TutorialTestDriver.act(session)
        }
        XCTAssertEqual(session.completion, .completed)
    }

    func testPracticeShopPurchasesSpendSuppliedCoinsAndRejectWrongOrDuplicateOffers() throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.reach(.shop, in: session)
        let shop = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(shop.coins, 30)
        XCTAssertEqual(shop.buffs.map(\.defID), [TutorialPractice.spareBuffID])
        XCTAssertEqual(shop.offers.map(\.defID), [TutorialPractice.bookmarkID,
            TutorialPractice.multiplierID, TutorialPractice.markerID, Buffs.freshInk])
        XCTAssertTrue(shop.cells.isEmpty)
        session.continueLesson()
        XCTAssertFalse(session.buyOffer(3))
        XCTAssertEqual(session.snapshot, shop)
        XCTAssertTrue(session.buyOffer(0))
        XCTAssertEqual(session.snapshot?.coins, 26)
        XCTAssertEqual(session.snapshot?.bookmarks.map(\.defID), [TutorialPractice.bookmarkID])
        XCTAssertEqual(session.snapshot?.offers.first?.sold, true)
        let bought = session.snapshot
        XCTAssertFalse(session.buyOffer(0))
        XCTAssertEqual(session.snapshot, bought)
        XCTAssertTrue(session.buyOffer(1))
        XCTAssertTrue(session.buyOffer(2))
        XCTAssertTrue(session.buyOffer(3))
        XCTAssertEqual(session.step, .markerPlacement)
        XCTAssertEqual(session.snapshot?.coins, 12)
        XCTAssertEqual(session.snapshot?.bookmarks.count, 2)
        XCTAssertEqual(session.snapshot?.markers.count, 1)
        XCTAssertEqual(session.snapshot?.buffs.count, 2)
        XCTAssertTrue(session.snapshot?.offers.isEmpty == true)
    }

    func testCuratedRowAndMarkerAreDeterministicAndClaimDoesNotSpendCoinsOrNumber() throws {
        let first = TutorialSession(practice: try TutorialPractice.make())
        let second = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.reach(.markerPlacement, in: first)
        try TutorialTestDriver.reach(.markerPlacement, in: second)
        XCTAssertEqual(first.snapshot, second.snapshot)
        let before = try XCTUnwrap(first.snapshot)
        let target = try XCTUnwrap(first.targetSquare)
        XCTAssertEqual(first.targetDigit, .nine)
        XCTAssertEqual(before.cells.filter { $0.square.row == target.row && $0.digit == nil }.count, 1)
        XCTAssertEqual(before.cells[target.index].digit, nil)
        XCTAssertEqual(before.hand.first?.digit, .nine)
        let other = try XCTUnwrap(before.cells.first { $0.square != target }).square
        XCTAssertFalse(first.claimMarker(at: other))
        XCTAssertEqual(first.snapshot, before)
        XCTAssertTrue(first.claimMarker(at: target))
        let claimed = try XCTUnwrap(first.snapshot)
        XCTAssertEqual(claimed.markedSquares, [target])
        XCTAssertEqual(claimed.cells, before.cells)
        XCTAssertEqual(claimed.hand, before.hand)
        XCTAssertEqual(claimed.coins, before.coins)
        XCTAssertFalse(first.claimMarker(at: target))
        XCTAssertEqual(first.snapshot, claimed)
    }

    func testCombinationUsesRealBookmarkMarkerLineClearAndMultiplierRules() throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.reach(.comboScore, in: session)
        let scored = try XCTUnwrap(session.snapshot)
        let receipt = try XCTUnwrap(session.lastPlacement)
        XCTAssertTrue(receipt.correct)
        XCTAssertEqual(receipt.points, 90 + 30 + 100, "9, Local Gossip, Golden Marker")
        XCTAssertEqual(receipt.lineClears, [.row])
        XCTAssertEqual(receipt.lineClearPoints, [45])
        XCTAssertEqual(scored.completedUnits, 1)
        XCTAssertEqual(scored.queuedBase, 265)
        XCTAssertEqual(scored.multiplier, 2, "Op-Ed adds one to the base multiplier")
        XCTAssertEqual(scored.queued, 530)
        XCTAssertEqual(scored.score, 0)
        XCTAssertEqual(scored.phase, .playing)
        XCTAssertEqual(scored.turn, 1)
        XCTAssertEqual(scored.hand.count, 6)
    }

    func testFreshInkConsumesOnlyItsCopyAndIncreasesAlreadyQueuedMultiplier() throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.reach(.useBuff, in: session)
        let before = try XCTUnwrap(session.snapshot)
        XCTAssertFalse(session.useBuff(0), "Overtime is held for the sale lesson")
        XCTAssertEqual(session.snapshot, before)
        XCTAssertTrue(session.useBuff(try XCTUnwrap(session.targetBuffIndex)))
        let after = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(after.buffs.map(\.defID), [TutorialPractice.spareBuffID])
        XCTAssertEqual(after.queuedBase, before.queuedBase)
        XCTAssertEqual(after.multiplier, 4)
        XCTAssertEqual(after.queued, 1_060)
        XCTAssertEqual(after.score, 0)
        XCTAssertEqual(after.turn, before.turn)
        XCTAssertEqual(after.turns, before.turns)
        XCTAssertEqual(after.coins, before.coins)
        XCTAssertFalse(session.useBuff(0), "A duplicate activation cannot spend the next item")
        XCTAssertEqual(session.snapshot, after)
    }

    func testSellingBookmarkAndUnusedBuffRefundsCoinsAndPreservesEarnedQueueAndMarker() throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.reach(.sellBookmark, in: session)
        let before = try XCTUnwrap(session.snapshot)
        XCTAssertFalse(session.sellItem(kind: .marker, index: 0))
        XCTAssertEqual(session.snapshot, before)
        XCTAssertFalse(session.sellItem(kind: .bookmark, index: 1))
        XCTAssertEqual(session.snapshot, before)
        XCTAssertTrue(session.sellItem(kind: .bookmark, index: 0))
        let soldBookmark = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(soldBookmark.bookmarks.map(\.defID), [TutorialPractice.multiplierID])
        XCTAssertEqual(soldBookmark.coins, before.coins + 2)
        XCTAssertEqual(soldBookmark.queued, before.queued)
        XCTAssertEqual(soldBookmark.queuedBase, before.queuedBase)
        XCTAssertFalse(session.sellItem(kind: .bookmark, index: 0))
        XCTAssertEqual(session.snapshot, soldBookmark)
        XCTAssertTrue(session.sellItem(kind: .buff, index: 0))
        let soldBuff = try XCTUnwrap(session.snapshot)
        XCTAssertTrue(soldBuff.buffs.isEmpty)
        XCTAssertEqual(soldBuff.coins, before.coins + 4)
        XCTAssertEqual(soldBuff.queued, before.queued)
        XCTAssertEqual(soldBuff.markers, before.markers)
        XCTAssertEqual(soldBuff.markedSquares, before.markedSquares)
        XCTAssertFalse(session.sellItem(kind: .buff, index: 0))
        XCTAssertEqual(session.snapshot, soldBuff)
    }

    func testBankReachesTargetAndCashOutPaysExactlyOnceWithReceipt() throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.reach(.comboBank, in: session)
        let queued = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(queued.score, 0)
        XCTAssertEqual(queued.queued, 1_060)
        XCTAssertFalse(session.cashOut(), "Pending points have not won the puzzle")
        XCTAssertTrue(session.bankTurn())
        let won = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(won.phase, .won)
        XCTAssertEqual(won.score, 1_060)
        XCTAssertEqual(won.queued, 0)
        XCTAssertEqual(won.turn, 2)
        XCTAssertEqual(won.hand.count, 7)
        XCTAssertEqual(session.lastTurn?.queuedBase, 265)
        XCTAssertEqual(session.lastTurn?.multiplier, 4)
        XCTAssertFalse(session.bankTurn())
        XCTAssertEqual(session.snapshot, won)
        XCTAssertTrue(session.cashOut())
        let paid = try XCTUnwrap(session.snapshot)
        let receipt = try XCTUnwrap(paid.payout)
        XCTAssertEqual(paid.phase, .cashedOut)
        XCTAssertEqual(receipt.base, 5)
        XCTAssertEqual(receipt.unusedTurns, 9)
        XCTAssertEqual(receipt.interest, 1)
        XCTAssertEqual(receipt.total, 15)
        XCTAssertEqual(paid.coins, won.coins + receipt.total)
        XCTAssertFalse(session.cashOut())
        XCTAssertEqual(session.snapshot, paid)
    }

    func testExitAtEveryStepFreezesLateActionsAndCannotCompleteAgain() async throws {
        for target in TutorialSession.Step.allCases {
            let session = TutorialSession(practice: try TutorialPractice.make())
            try TutorialTestDriver.reach(target, in: session)
            let before = session.snapshot
            session.skip()
            session.continueLesson()
            await session.advanceWhenIdle(enabled: true, delay: .zero)
            XCTAssertFalse(session.selectCard(0))
            XCTAssertFalse(session.place(at: Square(0)))
            XCTAssertFalse(session.buyOffer(0))
            XCTAssertFalse(session.claimMarker(at: Square(0)))
            XCTAssertFalse(session.useBuff(0))
            XCTAssertFalse(session.sellItem(kind: .bookmark, index: 0))
            XCTAssertFalse(session.bankTurn())
            XCTAssertFalse(session.cashOut())
            XCTAssertEqual(session.completion, .skipped)
            XCTAssertEqual(session.snapshot, before)
        }
    }

    func testStoppedPreparationNeverInstallsAndDisappearDoesNotResolve() async throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        session.stop()
        session.continueLesson()
        XCTAssertNil(session.completion)
        let unopened = TutorialSession()
        unopened.stop()
        await unopened.prepare()
        XCTAssertNil(unopened.snapshot)
        XCTAssertNil(unopened.completion)
        unopened.skip()
        XCTAssertNil(unopened.completion, "Disappearance is not an explicit Skip")
    }

    func testPracticeDoesNotResolveOnboardingUntilOwnerRecordsExplicitExit() throws {
        let suite = "ProbablySudoku.TutorialIsolationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = OnboardingStore(defaults: defaults)
        let session = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.complete(session)
        XCTAssertTrue(session.isStopped)
        XCTAssertFalse(store.isResolved)
        XCTAssertNil(defaults.persistentDomain(forName: suite)?[OnboardingStore.resolutionKey])
        store.resolve(as: .completed)
        XCTAssertTrue(store.isResolved)
    }
}
