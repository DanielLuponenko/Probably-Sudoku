import XCTest
@testable import ProbablySudoku

final class OnboardingEligibilityTests: XCTestCase {
    func testFreshPlayerGetsTheQuestion() {
        XCTAssertTrue(offers(PlayerProfile()))
    }

    func testExistingProgressAndSavedRunsNeverGetForcedIntoPractice() {
        var profile = PlayerProfile()
        profile.hasStartedFirstRunTutorial = true
        XCTAssertFalse(offers(profile))
        profile = PlayerProfile()
        profile.earnedAchievementIDs = ["first-puzzle"]
        XCTAssertFalse(offers(profile))
        profile = PlayerProfile()
        profile.achievementProgress.highestLevelReached = 2
        XCTAssertFalse(offers(profile))
        XCTAssertFalse(OnboardingEligibility.shouldOffer(hasResolved: false, hasSavedRun: true,
                                                        profile: PlayerProfile()))
    }

    func testRecordedDecisionAndExplicitPreviewBypassWithoutChangingProfile() {
        let profile = PlayerProfile()
        XCTAssertFalse(OnboardingEligibility.shouldOffer(hasResolved: true, hasSavedRun: false,
                                                        profile: profile))
        XCTAssertFalse(OnboardingEligibility.shouldOffer(hasResolved: false, hasSavedRun: false,
                                                        profile: profile, isPreviewLaunch: true))
        XCTAssertEqual(profile, PlayerProfile())
    }

    private func offers(_ profile: PlayerProfile) -> Bool {
        OnboardingEligibility.shouldOffer(hasResolved: false, hasSavedRun: false, profile: profile)
    }
}
