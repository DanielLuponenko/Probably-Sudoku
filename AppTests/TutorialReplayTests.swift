import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class TutorialReplayTests: XCTestCase {
    func testReplayCopyReturnsToSettingsWithoutChangingFirstRunDestination() {
        XCTAssertEqual(TutorialPresentation.replay.exitTitle, "Exit practice")
        XCTAssertEqual(TutorialPresentation.replay.completionTitle, "Back to Settings")
        XCTAssertEqual(TutorialPresentation.firstRun.exitTitle, "Skip tutorial")
        XCTAssertEqual(TutorialPresentation.firstRun.completionTitle, "Choose my first Book")
    }

    func testCompletingAndExitingRepeatedPracticeStartsFreshWithoutResolvingOnboarding() throws {
        let suite = "ProbablySudoku.TutorialReplayTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let onboarding = OnboardingStore(defaults: defaults)
        onboarding.resolve(as: .skipped)
        let originalResolution = defaults.string(forKey: OnboardingStore.resolutionKey)

        let first = TutorialSession(practice: try TutorialPractice.make())
        let freshSnapshot = first.snapshot
        for _ in TutorialSession.Step.allCases { first.continueLesson() }
        XCTAssertEqual(first.completion, .completed)
        XCTAssertGreaterThan(first.snapshot?.score ?? 0, 0)

        let second = TutorialSession(practice: try TutorialPractice.make())
        XCTAssertEqual(second.snapshot, freshSnapshot)
        XCTAssertEqual(second.step, .goal)
        XCTAssertNil(second.completion)
        second.skip()
        XCTAssertEqual(second.completion, .skipped)
        XCTAssertEqual(defaults.string(forKey: OnboardingStore.resolutionKey), originalResolution)
    }

    func testPracticeNeverTouchesExistingBookOrItsEncodedSave() throws {
        var book = Game(seed: "replay-does-not-own-this-book", book: .probably, obstacle: .none)
        try book.startPuzzle()
        let savedBefore = try RunStore.dataForStorage(of: book)
        let replay = TutorialSession(practice: try TutorialPractice.make())
        for _ in TutorialSession.Step.allCases { replay.continueLesson() }
        XCTAssertEqual(replay.completion, .completed)
        XCTAssertEqual(try RunStore.dataForStorage(of: book), savedBefore)
        XCTAssertEqual(book.puzzle?.turnNumber, 1)
        XCTAssertEqual(book.puzzle?.score, 0)
    }
}
