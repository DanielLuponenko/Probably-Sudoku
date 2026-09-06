import XCTest
@testable import ProbablySudoku

@MainActor
final class GameCenterIDMigrationTests: XCTestCase {
    private let scoreKey = "game-center.pending-scores.v1"
    private let achievementKey = "game-center.pending-achievements.v1"
    private let legacyScore = "com.numberclub.app.highest-puzzle-score"
    private let currentScore = "com.numberclub.app.highest_puzzle_score"

    func testExternalIdentifiersUseTheExactASCCompatibleNamespace() {
        XCTAssertEqual(GameCenterService.Leaderboard.allCases.map(\.rawValue), [
            "com.numberclub.app.highest_puzzle_score",
            "com.numberclub.app.highest_level_reached",
            "com.numberclub.app.books_completed"
        ])
        let localIDs = [
            "finish-book", "finish-every-book", "reach-level-5", "reach-level-7",
            "reach-level-9", "beat-ten-bosses", "full-clear", "three-way-clear",
            "hundred-thousand", "flawless-boss", "no-clue", "hold-thirty-coins",
            "buy-subscription", "five-bookmarks", "same-shop-sale", "obstacle-three-book",
            "last-turn-win", "two-skips", "keep-filling-full-clear"
        ]
        let registered = AchievementCatalog.all.filter(\.isRegisteredWithGameCenter)
        XCTAssertEqual(registered.map(\.id), localIDs,
                       "All 19 existing local/server identities remain unchanged when local awards are added.")
        XCTAssertEqual(AchievementCatalog.registeredGameCenterLocalIDs, Set(localIDs))
        XCTAssertEqual(registered.map(\.gameCenterID), localIDs.map {
            "com.numberclub.app.achievement.\($0.replacingOccurrences(of: "-", with: "_"))"
        })
        let identifiers = GameCenterService.Leaderboard.allCases.map(\.rawValue)
            + AchievementCatalog.all.map(\.gameCenterID)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._")
        for identifier in identifiers {
            XCTAssertTrue(identifier.allSatisfy(allowed.contains), identifier)
        }
    }

    func testScoreAliasesMergeByMaximumAndLeaveUnknownIdentifiersUntouched() {
        let scores = [
            legacyScore: 900, currentScore: 700,
            "com.numberclub.app.highest-level-reached": 5,
            "com.numberclub.app.highest_level_reached": 9,
            "com.numberclub.app.books-completed": 4,
            "com.numberclub.app.future-board": 71,
            "other.app.highest-puzzle-score": 31
        ]
        XCTAssertEqual(GameCenterService.normalizedPendingScores(scores), [
            currentScore: 900,
            "com.numberclub.app.highest_level_reached": 9,
            "com.numberclub.app.books_completed": 4,
            "com.numberclub.app.future-board": 71,
            "other.app.highest-puzzle-score": 31
        ])
    }

    func testAchievementAliasesUnionKnownAwardsWithoutChangingUnknownOrLocalIDs() {
        let legacy = Set(AchievementCatalog.all.map { "com.numberclub.app.achievement.\($0.id)" })
        let current = Set(AchievementCatalog.all.map(\.gameCenterID))
        let untouched: Set<String> = [
            "com.numberclub.app.achievement.future-award",
            "other.app.achievement.finish-book",
            "finish-book"
        ]
        let migrated = GameCenterService.normalizedPendingAchievements(legacy.union(current).union(untouched))
        XCTAssertEqual(migrated, current.union(untouched))
        XCTAssertEqual(GameCenterService.normalizedPendingAchievements(migrated), migrated)
    }

    func testMigrationIsIdempotentAcrossADowngradeAndReupgrade() {
        let migrated = GameCenterService.normalizedPendingScores([legacyScore: 400])
        XCTAssertEqual(GameCenterService.normalizedPendingScores(migrated), migrated)
        var oldBuildQueue = migrated
        oldBuildQueue[legacyScore] = 600
        XCTAssertEqual(GameCenterService.normalizedPendingScores(oldBuildQueue), [currentScore: 600])
        oldBuildQueue[legacyScore] = 200
        XCTAssertEqual(GameCenterService.normalizedPendingScores(oldBuildQueue), [currentScore: 400])
    }

    func testInitializationPersistsMigrationInExistingQueueKeysWithoutStartingGameKit() throws {
        try withIsolatedDefaults { defaults in
            defaults.set([legacyScore: 500, currentScore: 300], forKey: scoreKey)
            defaults.set(["com.numberclub.app.achievement.finish-book",
                          "com.numberclub.app.achievement.finish_book"], forKey: achievementKey)
            defaults.set("untouched", forKey: "unrelated-player-preference")
            let service = GameCenterService(defaults: defaults)
            XCTAssertFalse(service.isAuthenticated)
            XCTAssertEqual(defaults.dictionary(forKey: scoreKey) as? [String: Int], [currentScore: 500])
            XCTAssertEqual(defaults.stringArray(forKey: achievementKey),
                           ["com.numberclub.app.achievement.finish_book"])
            XCTAssertEqual(defaults.string(forKey: "unrelated-player-preference"), "untouched")
            let stored = defaults.dictionaryRepresentation() as NSDictionary
            _ = GameCenterService(defaults: defaults)
            XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, stored)
        }
    }

    func testPartiallyMigratedQueuesCanFinishIndependentlyOnRetry() throws {
        try withIsolatedDefaults { defaults in
            defaults.set([currentScore: 500], forKey: scoreKey)
            defaults.set(["com.numberclub.app.achievement.two-skips"], forKey: achievementKey)
            _ = GameCenterService(defaults: defaults)
            XCTAssertEqual(defaults.dictionary(forKey: scoreKey) as? [String: Int], [currentScore: 500])
            XCTAssertEqual(defaults.stringArray(forKey: achievementKey),
                           ["com.numberclub.app.achievement.two_skips"])

            // An old build can append a legacy score after the first migration.
            defaults.set([legacyScore: 800, currentScore: 500], forKey: scoreKey)
            _ = GameCenterService(defaults: defaults)
            XCTAssertEqual(defaults.dictionary(forKey: scoreKey) as? [String: Int], [currentScore: 800])
            XCTAssertEqual(defaults.stringArray(forKey: achievementKey),
                           ["com.numberclub.app.achievement.two_skips"])
        }
    }

    func testSavedLocalAwardsRoundTripWithoutChangingTheirIdentity() throws {
        var profile = PlayerProfile()
        profile.earnedAchievementIDs = Set(AchievementCatalog.all.map(\.id))
        let data = try JSONEncoder().encode(profile)
        let restored = try JSONDecoder().decode(PlayerProfile.self, from: data)
        XCTAssertEqual(restored.earnedAchievementIDs, profile.earnedAchievementIDs)
        for id in restored.earnedAchievementIDs {
            XCTAssertNotNil(AchievementCatalog.definition(for: id))
            XCTAssertTrue(id.contains("-"))
        }
    }

    func testEmptyInstallationDoesNotInventPendingScoresOrAwards() throws {
        try withIsolatedDefaults { defaults in
            _ = GameCenterService(defaults: defaults)
            XCTAssertNil(defaults.object(forKey: scoreKey))
            XCTAssertNil(defaults.object(forKey: achievementKey))
        }
    }

    private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "GameCenterIDMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
