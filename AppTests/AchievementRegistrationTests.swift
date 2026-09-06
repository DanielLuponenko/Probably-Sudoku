import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class AchievementRegistrationTests: XCTestCase {
    private let key = "game-center.pending-achievements.v1"

    func testNewLocalAwardsAreNeverEnqueuedOrSentBeforeAppleRegistration() async throws {
        let suite = "AchievementRegistrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let client = AchievementRegistrationClient()
        let service = GameCenterService(defaults: defaults, client: client)
        service.start()
        for definition in AchievementCatalog.all where !definition.isRegisteredWithGameCenter {
            service.recordAchievement(definition.gameCenterID)
        }
        await settle(service)
        XCTAssertEqual(service.pendingDeliveryCount, 0)
        XCTAssertTrue(client.batches.isEmpty)
        XCTAssertNil(defaults.object(forKey: key))
    }

    func testRegisteredAwardsStillDeliverWhenAnOlderQueueContainsUnregisteredIDs() async throws {
        let suite = "AchievementRegistrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let registered = "com.numberclub.app.achievement.finish_book"
        let pending = "com.numberclub.app.achievement.first_boss"
        let unknown = "other.app.future-achievement"
        defaults.set([registered, pending, unknown], forKey: key)
        let client = AchievementRegistrationClient()
        let service = GameCenterService(defaults: defaults, client: client)
        service.start()
        await settle(service)
        XCTAssertEqual(client.batches, [[registered]])
        XCTAssertEqual(Set(defaults.stringArray(forKey: key) ?? []), [pending, unknown],
                       "Preserve unfamiliar old queue entries, but keep them out of Apple's batch.")
        XCTAssertEqual(service.pendingDeliveryCount, 0)
        XCTAssertNil(service.achievementDeliveryIssue)
        service.setAppIsActive(false)
        service.setAppIsActive(true)
        await settle(service)
        XCTAssertEqual(client.batches.count, 1)
    }

    func testHistoricalBackfillOnlyMirrorsRegisteredLocalAwards() {
        var profile = PlayerProfile()
        profile.earnedAchievementIDs = Set(AchievementCatalog.all.map(\.id))
        let before = profile
        let history = GameCenterService.HistoricalProgress(profile: profile, progress: RunStore.Progress(), run: nil)
        XCTAssertEqual(history.achievementIDs, AchievementCatalog.registeredGameCenterIDs)
        XCTAssertEqual(profile, before, "Being local-only must never remove an earned achievement.")
        XCTAssertEqual(profile.earnedAchievementIDs.count, 31)
    }

    private func settle(_ service: GameCenterService) async {
        for _ in 0..<100 where service.isDelivering { await Task.yield() }
        XCTAssertFalse(service.isDelivering)
    }
}

@MainActor
private final class AchievementRegistrationClient: GameCenterClient {
    var isAuthenticated = true
    var batches: [[String]] = []
    func startAuthentication(onChange: @escaping @MainActor (GameCenterService.ServiceIssue?) -> Void) {}
    func hideAccessPoint() {}
    func presentAuthentication() -> GameCenterService.DashboardResult { .requested }
    func presentDashboard(_ dashboard: GameCenterService.Dashboard) -> Bool { true }
    func submitScore(_ score: Int, leaderboardID: String) async throws {}
    func reportAchievements(_ identifiers: [String]) async throws { batches.append(identifiers) }
}
