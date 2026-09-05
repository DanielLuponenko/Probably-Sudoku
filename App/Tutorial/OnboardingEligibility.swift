import Foundation

/// Snapshot this once at launch; a late cloud update never interrupts a lesson.
enum OnboardingEligibility {
    static func shouldOffer(hasResolved: Bool, hasSavedRun: Bool,
                            profile: PlayerProfile, isPreviewLaunch: Bool = false) -> Bool {
        guard !hasResolved, !hasSavedRun, !isPreviewLaunch else { return false }
        let progress = profile.achievementProgress
        let hasPlayed = profile.hasStartedFirstRunTutorial
            || !profile.earnedAchievementIDs.isEmpty
            || !profile.rewardedCompletionIDs.isEmpty
            || progress.highestLevelReached > 1
            || !progress.completedBookVolumes.isEmpty
            || !progress.completedBossEncounterIDs.isEmpty
            || !progress.completedObstacles.isEmpty
        return !hasPlayed
    }
}
