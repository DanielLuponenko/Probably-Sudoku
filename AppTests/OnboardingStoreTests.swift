import XCTest
@testable import ProbablySudoku

@MainActor
final class OnboardingStoreTests: XCTestCase {
    func testOpeningTheQuestionDoesNotWriteACompletionFlag() throws {
        try withDefaults { defaults, suite in
            let store = OnboardingStore(defaults: defaults)
            XCTAssertFalse(store.isResolved)
            XCTAssertNil(store.resolution)
            XCTAssertNil(defaults.persistentDomain(forName: suite)?[OnboardingStore.resolutionKey])
        }
    }

    func testEveryExplicitExitPersistsOnlyItsLocalVersionedDecision() throws {
        for resolution in OnboardingStore.Resolution.allCases {
            try withDefaults { defaults, suite in
                defaults.set("untouched", forKey: "other-setting")
                let store = OnboardingStore(defaults: defaults)
                store.resolve(as: resolution)
                XCTAssertTrue(store.isResolved)
                XCTAssertEqual(OnboardingStore(defaults: defaults).resolution, resolution)
                let domain = try XCTUnwrap(defaults.persistentDomain(forName: suite))
                XCTAssertEqual(Set(domain.keys), ["other-setting", OnboardingStore.resolutionKey])
                XCTAssertEqual(domain["other-setting"] as? String, "untouched")
            }
        }
    }

    func testRepeatedCallbacksDoNotReplaceTheOriginalDecision() throws {
        try withDefaults { defaults, _ in
            let store = OnboardingStore(defaults: defaults)
            store.resolve(as: .experienced)
            store.resolve(as: .completed)
            XCTAssertEqual(store.resolution, .experienced)
            XCTAssertEqual(OnboardingStore(defaults: defaults).resolution, .experienced)
        }
    }

    func testUnknownStoredValueDoesNotSilentlyMarkTheLessonComplete() throws {
        try withDefaults { defaults, _ in
            defaults.set("started", forKey: OnboardingStore.resolutionKey)
            XCTAssertFalse(OnboardingStore(defaults: defaults).isResolved)
        }
    }

    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let suite = "ProbablySudoku.OnboardingStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults, suite)
    }
}
