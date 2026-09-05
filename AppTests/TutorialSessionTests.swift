import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

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
        XCTAssertEqual(placed.turn, 1)
        XCTAssertTrue(session.bankTurn())
        let banked = try XCTUnwrap(session.snapshot)
        XCTAssertEqual(session.step, .banked)
        XCTAssertEqual(banked.score, placed.queued)
        XCTAssertEqual(banked.queued, 0)
        XCTAssertEqual(banked.turn, 2)
        XCTAssertEqual(banked.hand.count, before.hand.count)
        XCTAssertEqual(banked.coins, before.coins)
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

    func testIdleGuideCompletesUsingSameActionsInUnderTwoMinutes() async throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        XCTAssertEqual(TutorialSession.Step.allCases.reduce(0) { $0 + $1.idleSeconds }, 97)
        for _ in TutorialSession.Step.allCases {
            await session.advanceWhenIdle(enabled: true, delay: .zero)
        }
        XCTAssertEqual(session.completion, .completed)
        XCTAssertTrue(session.isStopped)
        XCTAssertEqual(session.snapshot?.turn, 2)
        XCTAssertGreaterThan(session.snapshot?.score ?? 0, 0)
        XCTAssertEqual(session.snapshot?.coins, 5)
    }

    func testVoiceOverOrBackgroundGateNeverAdvances() async throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        await session.advanceWhenIdle(enabled: false, delay: .zero)
        XCTAssertEqual(session.step, .goal)
        XCTAssertNil(session.completion)
        session.continueLesson()
        XCTAssertEqual(session.step, .select, "Self-paced controls remain usable")
    }

    func testSkipIsAvailableAtEveryStepAndLateActionsCannotAdvanceOrFinishAgain() async throws {
        for targetStep in TutorialSession.Step.allCases {
            let session = TutorialSession(practice: try TutorialPractice.make())
            while session.step != targetStep { session.continueLesson() }
            let before = session.snapshot
            session.skip()
            session.continueLesson()
            await session.advanceWhenIdle(enabled: true, delay: .zero)
            XCTAssertEqual(session.completion, .skipped)
            XCTAssertEqual(session.snapshot, before)
        }
    }

    func testCancellationAndDisappearNeverCompleteOrInstallAStoppedSession() async throws {
        let session = TutorialSession(practice: try TutorialPractice.make())
        let pending = Task { await session.advanceWhenIdle(enabled: true, delay: .seconds(60)) }
        pending.cancel()
        await pending.value
        XCTAssertEqual(session.step, .goal)
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

    func testPracticeDoesNotResolveOnboardingUntilTheOwnerRecordsAnExplicitExit() throws {
        let suite = "ProbablySudoku.TutorialIsolationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = OnboardingStore(defaults: defaults)
        let session = TutorialSession(practice: try TutorialPractice.make())
        for _ in TutorialSession.Step.allCases { session.continueLesson() }
        XCTAssertEqual(session.completion, .completed)
        XCTAssertFalse(store.isResolved)
        XCTAssertNil(defaults.persistentDomain(forName: suite)?[OnboardingStore.resolutionKey])
        store.resolve(as: .completed)
        XCTAssertTrue(store.isResolved)
    }
}
