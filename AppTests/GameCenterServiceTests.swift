import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class GameCenterServiceTests: XCTestCase {
    private let scoreKey = "game-center.pending-scores.v1"
    private let achievementKey = "game-center.pending-achievements.v1"

    func testInitializationDoesNotStartGameKitAndEveryLifecycleKeepsBadgeHidden() throws {
        let fixture = try Fixture()
        XCTAssertEqual(fixture.client.authenticationStarts, 0)
        XCTAssertEqual(fixture.client.hideCalls, 0)
        fixture.client.badgeVisible = true
        fixture.service.start()
        fixture.service.start()
        XCTAssertEqual(fixture.client.authenticationStarts, 1)
        XCTAssertFalse(fixture.client.badgeVisible)
        for active in [false, true, true, false] {
            fixture.client.badgeVisible = true
            fixture.service.setAppIsActive(active)
            XCTAssertFalse(fixture.client.badgeVisible)
        }
        fixture.client.badgeVisible = true
        fixture.client.isAuthenticated = true
        fixture.client.authenticationChanged?(nil)
        XCTAssertTrue(fixture.service.isAuthenticated)
        XCTAssertFalse(fixture.client.badgeVisible)
    }

    func testSignedOutDashboardIsExplicitAndDoesNotPromptOrSubmit() throws {
        let fixture = try Fixture()
        fixture.service.start()
        XCTAssertEqual(fixture.service.openDashboard(.leaderboards), .signInRequired)
        XCTAssertEqual(fixture.service.openDashboard(.achievements), .signInRequired)
        XCTAssertTrue(fixture.client.dashboards.isEmpty)
        XCTAssertTrue(fixture.client.scores.isEmpty)
        XCTAssertTrue(fixture.client.achievementBatches.isEmpty)
        XCTAssertFalse(fixture.client.badgeVisible)
    }

    func testOfferedAuthenticationWaitsForExplicitTapAndNeverAutoOpensDashboard() throws {
        let fixture = try Fixture()
        fixture.client.hasAuthenticationController = true
        fixture.service.start()
        fixture.client.authenticationChanged?(nil)
        XCTAssertEqual(fixture.client.authenticationRequests, 0, "An offered controller must not create a launch prompt.")
        XCTAssertEqual(fixture.service.openDashboard(.leaderboards), .requested)
        XCTAssertEqual(fixture.client.authenticationRequests, 1)
        XCTAssertTrue(fixture.client.dashboards.isEmpty)
        XCTAssertTrue(fixture.client.scores.isEmpty)
        XCTAssertTrue(fixture.client.achievementBatches.isEmpty)

        fixture.client.isAuthenticated = true
        fixture.client.authenticationChanged?(nil)
        XCTAssertTrue(fixture.client.dashboards.isEmpty, "Authentication must not automatically open a dashboard.")
        fixture.client.canPresent = false // Apple's authentication screen is still dismissing.
        XCTAssertEqual(fixture.service.openDashboard(.achievements), .unavailable)
        fixture.client.canPresent = true
        XCTAssertEqual(fixture.service.openDashboard(.achievements), .requested)
        XCTAssertEqual(fixture.client.authenticationRequests, 1)
    }

    func testOfferedAuthenticationRespectsInactiveAndUnavailablePresentation() throws {
        let fixture = try Fixture()
        fixture.client.hasAuthenticationController = true
        fixture.service.start()
        fixture.service.setAppIsActive(false)
        XCTAssertEqual(fixture.service.openDashboard(.leaderboards), .unavailable)
        XCTAssertEqual(fixture.client.authenticationRequests, 0)

        fixture.service.setAppIsActive(true)
        fixture.client.canPresentAuthentication = false
        XCTAssertEqual(fixture.service.openDashboard(.achievements), .unavailable)
        XCTAssertEqual(fixture.client.authenticationRequests, 1)
        XCTAssertTrue(fixture.client.dashboards.isEmpty)
        fixture.client.hasAuthenticationController = false
        XCTAssertEqual(fixture.service.openDashboard(.achievements), .signInRequired)
    }

    func testDashboardRoutesBothDestinationsAndRejectsUnavailableOrInactivePresentation() throws {
        let fixture = try Fixture()
        fixture.client.isAuthenticated = true
        fixture.service.start()
        XCTAssertEqual(fixture.service.openDashboard(.leaderboards), .requested)
        XCTAssertEqual(fixture.service.openDashboard(.achievements), .requested)
        XCTAssertEqual(fixture.client.dashboards, [.leaderboards, .achievements])
        fixture.client.canPresent = false
        XCTAssertEqual(fixture.service.openDashboard(.leaderboards), .unavailable)
        fixture.service.setAppIsActive(false)
        let requests = fixture.client.dashboards.count
        XCTAssertEqual(fixture.service.openDashboard(.achievements), .unavailable)
        XCTAssertEqual(fixture.client.dashboards.count, requests)
        fixture.client.isAuthenticated = false
        fixture.service.setAppIsActive(true)
        XCTAssertEqual(fixture.service.openDashboard(.leaderboards), .signInRequired)
        XCTAssertFalse(fixture.service.isAuthenticated)
        XCTAssertFalse(fixture.client.badgeVisible)
    }

    func testAuthenticationFailureRetainsOnlyNonIdentifyingDiagnosticAndCanRecover() throws {
        let fixture = try Fixture()
        fixture.service.start()
        let error = NSError(domain: "GameKit.test", code: 6,
                            userInfo: [NSLocalizedDescriptionKey: "private account detail"])
        fixture.client.authenticationChanged?(.init(error))
        XCTAssertEqual(fixture.service.authenticationIssue?.domain, "GameKit.test")
        XCTAssertEqual(fixture.service.authenticationIssue?.code, 6)
        XCTAssertFalse(fixture.service.isAuthenticated)
        fixture.client.isAuthenticated = true
        fixture.client.authenticationChanged?(nil)
        XCTAssertTrue(fixture.service.isAuthenticated)
        XCTAssertNil(fixture.service.authenticationIssue)
    }

    func testSignedOutScoresKeepMaximumAndAchievementsKeepMembershipUntilAuthentication() async throws {
        let fixture = try Fixture()
        fixture.service.start()
        fixture.service.record(400, for: .highestPuzzleScore)
        fixture.service.record(200, for: .highestPuzzleScore)
        fixture.service.record(0, for: .booksCompleted)
        fixture.service.recordAchievement("com.numberclub.app.achievement.finish-book")
        fixture.service.recordAchievement("com.numberclub.app.achievement.finish_book")
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 2)
        XCTAssertTrue(fixture.client.scores.isEmpty)
        XCTAssertTrue(fixture.client.achievementBatches.isEmpty)
        fixture.client.isAuthenticated = true
        fixture.client.authenticationChanged?(nil)
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.scores.map(\.value), [400])
        XCTAssertEqual(fixture.client.scores.map(\.identifier), [GameCenterService.Leaderboard.highestPuzzleScore.rawValue])
        XCTAssertEqual(fixture.client.achievementBatches, [["com.numberclub.app.achievement.finish_book"]])
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 0)
    }

    func testFailedDeliveriesRetryOnceOnForegroundWithoutNewGameplayOrHotLoop() async throws {
        let fixture = try Fixture()
        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        fixture.client.scoreAction = { _, _ in throw offline }
        fixture.client.achievementAction = { _ in throw offline }
        fixture.service.record(700, for: .highestPuzzleScore)
        fixture.service.recordAchievement("com.numberclub.app.achievement.full_clear")
        fixture.client.isAuthenticated = true
        fixture.service.start()
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.scores.count, 1)
        XCTAssertEqual(fixture.client.achievementBatches.count, 1)
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 2)
        XCTAssertEqual(fixture.service.scoreDeliveryIssue?.code, NSURLErrorNotConnectedToInternet)
        XCTAssertEqual(fixture.service.achievementDeliveryIssue?.code, NSURLErrorNotConnectedToInternet)
        XCTAssertEqual(fixture.defaults.dictionary(forKey: scoreKey) as? [String: Int],
                       [GameCenterService.Leaderboard.highestPuzzleScore.rawValue: 700])
        XCTAssertEqual(fixture.defaults.stringArray(forKey: achievementKey),
                       ["com.numberclub.app.achievement.full_clear"])

        fixture.service.setAppIsActive(true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(fixture.client.scores.count, 1, "Repeated active notifications must not create retries.")
        XCTAssertEqual(fixture.client.achievementBatches.count, 1)

        fixture.client.scoreAction = { _, _ in }
        fixture.client.achievementAction = { _ in }
        fixture.service.setAppIsActive(false)
        fixture.service.setAppIsActive(true)
        fixture.service.setAppIsActive(true)
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.scores.count, 2)
        XCTAssertEqual(fixture.client.achievementBatches.count, 2)
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 0)
        XCTAssertNil(fixture.service.scoreDeliveryIssue)
        XCTAssertNil(fixture.service.achievementDeliveryIssue)
    }

    func testInFlightOldScoreCannotRemoveANewerMaximumOrCauseDuplicateFlushes() async throws {
        let fixture = try Fixture()
        var pending: CheckedContinuation<Void, Never>?
        fixture.client.scoreAction = { _, _ in
            if pending == nil {
                await withCheckedContinuation { pending = $0 }
            }
        }
        fixture.client.isAuthenticated = true
        fixture.service.start()
        fixture.service.record(100, for: .highestPuzzleScore)
        await waitUntil { pending != nil }
        fixture.service.record(900, for: .highestPuzzleScore)
        fixture.service.record(300, for: .highestPuzzleScore)
        fixture.service.setAppIsActive(false)
        fixture.service.setAppIsActive(true)
        XCTAssertEqual(fixture.client.scores.count, 1)
        XCTAssertEqual(fixture.defaults.dictionary(forKey: scoreKey) as? [String: Int],
                       [GameCenterService.Leaderboard.highestPuzzleScore.rawValue: 900])
        pending?.resume()
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.scores.map(\.value), [100, 900])
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 0)
    }

    func testPartialFailureClearsOnlyAcceptedScores() async throws {
        let fixture = try Fixture()
        let failedID = GameCenterService.Leaderboard.highestLevelReached.rawValue
        fixture.service.record(4, for: .highestLevelReached)
        fixture.service.record(500, for: .highestPuzzleScore)
        fixture.client.scoreAction = { _, identifier in
            if identifier == failedID { throw NSError(domain: "GameKit.test", code: 3) }
        }
        fixture.client.isAuthenticated = true
        fixture.service.start()
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.scores.count, 2)
        XCTAssertEqual(fixture.defaults.dictionary(forKey: scoreKey) as? [String: Int], [failedID: 4])
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 1)
    }

    func testAchievementEarnedDuringDeliveryIsNotLost() async throws {
        let fixture = try Fixture()
        var pending: CheckedContinuation<Void, Never>?
        fixture.client.achievementAction = { _ in
            if pending == nil {
                await withCheckedContinuation { pending = $0 }
            }
        }
        fixture.client.isAuthenticated = true
        fixture.service.start()
        fixture.service.recordAchievement("com.numberclub.app.achievement.full_clear")
        await waitUntil { pending != nil }
        fixture.service.recordAchievement("com.numberclub.app.achievement.finish_book")
        pending?.resume()
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.achievementBatches,
                       [["com.numberclub.app.achievement.full_clear"], ["com.numberclub.app.achievement.finish_book"]])
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 0)
    }

    func testHistoricalProjectionUsesExactSavedFactsAndKnownIdentitiesOnly() throws {
        var profile = PlayerProfile()
        profile.earnedAchievementIDs = ["finish-book", "no-clue", "hundred-thousand", "future-award"]
        profile.achievementProgress.highestLevelReached = 9
        profile.achievementProgress.completedBookVolumes = [Book.probably.volume, 999]
        var progress = RunStore.Progress()
        progress.completedBookIDs = [Book.probably.rawValue, Book.slightlyHarder.rawValue, "future-book"]
        var run = RunState(seed: "historical-projection")
        run.level = 3
        run.bestPuzzleScore = 5_125
        let game = Game(run: run)
        let beforeProfile = profile
        let beforeRun = try game.encoded()

        let history = GameCenterService.HistoricalProgress(profile: profile, progress: progress, run: game)

        XCTAssertEqual(history.scores, [.highestPuzzleScore: 5_125, .highestLevelReached: 9, .booksCompleted: 2])
        XCTAssertEqual(history.achievementIDs, ["com.numberclub.app.achievement.finish_book",
                                               "com.numberclub.app.achievement.no_clue",
                                               "com.numberclub.app.achievement.hundred_thousand"])
        XCTAssertEqual(profile, beforeProfile)
        XCTAssertEqual(try game.encoded(), beforeRun)
    }

    func testHistoricalProjectionDoesNotInventFreshLevelOrAnUnfinishedPuzzleScore() throws {
        var profile = PlayerProfile()
        let empty = GameCenterService.HistoricalProgress(profile: profile, progress: .init(), run: nil)
        XCTAssertTrue(empty.scores.isEmpty)
        XCTAssertTrue(empty.achievementIDs.isEmpty)

        profile.earnedAchievementIDs = ["hundred-thousand"]
        var game = Game(seed: "unfinished-history")
        try game.startPuzzle()
        var run = game.run
        run.puzzle?.score = 123_456
        let history = GameCenterService.HistoricalProgress(profile: profile, progress: .init(), run: Game(run: run))
        XCTAssertEqual(history.scores, [.highestLevelReached: 1], "A dealt Puzzle proves Level 1, not a banked score.")
        XCTAssertNil(history.scores[.highestPuzzleScore], "Do not turn the Six Figures award into a fabricated score.")
        XCTAssertEqual(history.achievementIDs, ["com.numberclub.app.achievement.hundred_thousand"])
    }

    func testHistoricalBackfillReplaysEmptyQueuesOnlyAfterStartWithInjectedFacts() async throws {
        var providerCalls = 0
        let history = savedHistory()
        let fixture = try Fixture(historyProvider: { providerCalls += 1; return history })
        XCTAssertEqual(providerCalls, 0, "Construction must not read any history, including test fixtures.")
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 0)
        fixture.client.isAuthenticated = true
        fixture.service.start()
        await waitUntil { !fixture.service.isDelivering }

        XCTAssertEqual(providerCalls, 1)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: fixture.client.scores.map { ($0.identifier, $0.value) }),
                       [GameCenterService.Leaderboard.highestPuzzleScore.rawValue: 5_125,
                        GameCenterService.Leaderboard.highestLevelReached.rawValue: 9,
                        GameCenterService.Leaderboard.booksCompleted.rawValue: 1])
        XCTAssertEqual(fixture.client.achievementBatches, [history.achievementIDs.sorted()])
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 0)
    }

    func testHistoricalBackfillMergesLegacyQueuesByMaximumAndAchievementUnion() throws {
        let history = savedHistory()
        let fixture = try Fixture(historyProvider: { history })
        fixture.defaults.set(["com.numberclub.app.highest-puzzle-score": 8_000], forKey: scoreKey)
        fixture.defaults.set(["com.numberclub.app.achievement.full-clear"], forKey: achievementKey)
        let service = GameCenterService(defaults: fixture.defaults, client: fixture.client, historyProvider: { history })
        service.start() // Signed out: persisted, without any server request.

        XCTAssertEqual(fixture.defaults.dictionary(forKey: scoreKey) as? [String: Int],
                       [GameCenterService.Leaderboard.highestPuzzleScore.rawValue: 8_000,
                        GameCenterService.Leaderboard.highestLevelReached.rawValue: 9,
                        GameCenterService.Leaderboard.booksCompleted.rawValue: 1])
        XCTAssertEqual(Set(fixture.defaults.stringArray(forKey: achievementKey) ?? []),
                       history.achievementIDs.union(["com.numberclub.app.achievement.full_clear"]))
        XCTAssertTrue(fixture.client.scores.isEmpty)
        XCTAssertTrue(fixture.client.achievementBatches.isEmpty)
    }

    func testHistoricalFailuresRemainQueuedForLaterRetryAndDoNotLoop() async throws {
        let history = savedHistory()
        let fixture = try Fixture(historyProvider: { history })
        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        fixture.client.scoreAction = { _, _ in throw offline }
        fixture.client.achievementAction = { _ in throw offline }
        fixture.client.isAuthenticated = true
        fixture.service.start()
        await waitUntil { !fixture.service.isDelivering }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(fixture.client.scores.count, 3)
        XCTAssertEqual(fixture.client.achievementBatches.count, 1)
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 3 + history.achievementIDs.count)
        XCTAssertEqual((fixture.defaults.dictionary(forKey: scoreKey) ?? [:]).count, 3)
        XCTAssertEqual(fixture.defaults.stringArray(forKey: achievementKey), history.achievementIDs.sorted())

        // A new process without any provider can deliver the durable v1 batch.
        fixture.client.scoreAction = { _, _ in }
        fixture.client.achievementAction = { _ in }
        let restarted = GameCenterService(defaults: fixture.defaults, client: fixture.client)
        restarted.start()
        await waitUntil { !restarted.isDelivering }
        XCTAssertEqual(restarted.pendingDeliveryCount, 0)
        XCTAssertEqual(fixture.client.scores.count, 6)
        XCTAssertEqual(fixture.client.achievementBatches.count, 2)
    }

    func testHistoricalForegroundSnapshotsOnlyEnqueueNewFactsAfterCloudOrLocalProgressChanges() async throws {
        var history = savedHistory()
        let fixture = try Fixture(historyProvider: { history })
        fixture.client.isAuthenticated = true
        fixture.service.start()
        await waitUntil { !fixture.service.isDelivering }
        for _ in 0..<3 {
            fixture.service.setAppIsActive(false)
            fixture.service.setAppIsActive(true)
            fixture.client.authenticationChanged?(nil)
        }
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.scores.count, 3)
        XCTAssertEqual(fixture.client.achievementBatches.count, 1)

        history = savedHistory(score: 6_000, earned: ["finish-book", "no-clue", "two-skips"])
        fixture.service.setAppIsActive(false)
        fixture.service.setAppIsActive(true)
        await waitUntil { !fixture.service.isDelivering }
        XCTAssertEqual(fixture.client.scores.count, 4)
        XCTAssertEqual(fixture.client.scores.last?.value, 6_000)
        XCTAssertEqual(fixture.client.achievementBatches.last, ["com.numberclub.app.achievement.two_skips"])
        XCTAssertEqual(fixture.service.pendingDeliveryCount, 0)
    }

    private func savedHistory(score: Int = 5_125, earned: Set<String> = ["finish-book", "no-clue"])
        -> GameCenterService.HistoricalProgress {
        var profile = PlayerProfile()
        profile.earnedAchievementIDs = earned
        profile.achievementProgress.highestLevelReached = 9
        profile.achievementProgress.completedBookVolumes = [Book.probably.volume]
        var run = RunState(seed: "saved-history-fixture")
        run.bestPuzzleScore = score
        return .init(profile: profile, progress: .init(), run: Game(run: run))
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("The fake Game Center operation did not settle.", file: file, line: line)
    }

    @MainActor
    private final class Fixture {
        let suite = "GameCenterServiceTests.\(UUID().uuidString)"
        let defaults: UserDefaults
        let client = FakeGameCenterClient()
        let service: GameCenterService

        init(historyProvider: (() -> GameCenterService.HistoricalProgress)? = nil) throws {
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            service = GameCenterService(defaults: defaults, client: client, historyProvider: historyProvider)
        }

        deinit { defaults.removePersistentDomain(forName: suite) }
    }
}

@MainActor
private final class FakeGameCenterClient: GameCenterClient {
    struct SubmittedScore {
        let value: Int
        let identifier: String
    }

    var isAuthenticated = false
    var badgeVisible = false
    var hideCalls = 0
    var authenticationStarts = 0
    var authenticationChanged: (@MainActor (GameCenterService.ServiceIssue?) -> Void)?
    var hasAuthenticationController = false
    var canPresentAuthentication = true
    var authenticationRequests = 0
    var canPresent = true
    var dashboards: [GameCenterService.Dashboard] = []
    var scores: [SubmittedScore] = []
    var achievementBatches: [[String]] = []
    var scoreAction: (Int, String) async throws -> Void = { _, _ in }
    var achievementAction: ([String]) async throws -> Void = { _ in }

    func startAuthentication(onChange: @escaping @MainActor (GameCenterService.ServiceIssue?) -> Void) {
        authenticationStarts += 1
        authenticationChanged = onChange
    }

    func hideAccessPoint() {
        hideCalls += 1
        badgeVisible = false
    }

    func presentDashboard(_ dashboard: GameCenterService.Dashboard) -> Bool {
        dashboards.append(dashboard)
        return canPresent
    }

    func presentAuthentication() -> GameCenterService.DashboardResult {
        authenticationRequests += 1
        guard hasAuthenticationController else { return .signInRequired }
        return canPresentAuthentication ? .requested : .unavailable
    }

    func submitScore(_ score: Int, leaderboardID: String) async throws {
        scores.append(.init(value: score, identifier: leaderboardID))
        try await scoreAction(score, leaderboardID)
    }

    func reportAchievements(_ identifiers: [String]) async throws {
        achievementBatches.append(identifiers)
        try await achievementAction(identifiers)
    }
}
