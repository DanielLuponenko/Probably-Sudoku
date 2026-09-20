import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Permanent eligibility and migration use in-memory profiles only.
final class BookCompletionAchievementTests: XCTestCase {
    func testAllTwelveBooksHaveDistinctStableLocalAchievements() {
        let expected = ["probably", "slightlyHarder", "noPressure", "bites", "genuinely", "snackBreak",
                        "trustMe", "overthinking", "smallVictories", "rainyDay", "secondThoughts", "wellEarned"]
            .map { "complete-book-\($0)" }
        let definitions = Book.allCases.map { AchievementCatalog.bookCompletion(for: $0) }
        XCTAssertEqual(definitions.map(\.id), expected)
        XCTAssertEqual(Set(definitions.map(\.id)).count, 12)
        for (book, definition) in zip(Book.allCases, definitions) {
            XCTAssertEqual(AchievementCatalog.definition(for: definition.id), definition)
            XCTAssertEqual(definition.title, "Volume \(book.volume) Complete")
            XCTAssertTrue(definition.detail.contains(BookEdition.edition(for: book).title))
            XCTAssertFalse(definition.isRegisteredWithGameCenter)
        }
        XCTAssertEqual(AchievementCatalog.registeredGameCenterLocalIDs.count, 19)
    }

    func testEveryBookAwardsOnlyItsOwnPermanentIdentityAcrossRepeatedObstaclesAndResume() throws {
        for book in Book.allCases {
            var profile = PlayerProfile()
            let expected = AchievementCatalog.bookCompletion(for: book).id
            for obstacle in Obstacle.allCases {
                for _ in 0..<3 {
                    profile.achievementProgress.recordBookCompleted(book, obstacle: obstacle)
                    profile.earnedAchievementIDs.formUnion(AchievementRules.bookCompleted(
                        progress: profile.achievementProgress, obstacle: obstacle))
                    profile = try JSONDecoder().decode(PlayerProfile.self, from: JSONEncoder().encode(profile))
                }
            }
            XCTAssertEqual(Set(profile.earnedAchievementIDs.filter { $0.hasPrefix("complete-book-") }), [expected])
            XCTAssertTrue(profile.earnedAchievementIDs.contains("finish-book"))
            XCTAssertEqual(profile.achievementProgress.completedBookVolumes, [book.volume])
            XCTAssertEqual(profile.achievementProgress.completedObstacles[book.rawValue], 9)
        }
    }

    func testHistoricalIdentifiedWinsBackfillWithoutGuessingFromGenericAwards() throws {
        var historical = PlayerProfile()
        historical.earnedAchievementIDs = ["finish-book", "future-preserved-award"]
        historical.achievementProgress.completedBookVolumes = [2, 8, 999]
        historical.achievementProgress.completedObstaclesByBookID = [Book.wellEarned.rawValue: 3, "future-book": 2]
        let restored = try JSONDecoder().decode(PlayerProfile.self, from: JSONEncoder().encode(historical))
        XCTAssertEqual(Set(restored.earnedAchievementIDs.filter { $0.hasPrefix("complete-book-") }),
                       ["complete-book-slightlyHarder", "complete-book-overthinking", "complete-book-wellEarned"])
        XCTAssertTrue(restored.earnedAchievementIDs.contains("future-preserved-award"))
        XCTAssertEqual(restored.achievementProgress.completedBookVolumes, [2, 8, 999])
        XCTAssertEqual(restored.achievementProgress.completedObstaclesByBookID?["future-book"], 2)

        let unidentified = try JSONDecoder().decode(PlayerProfile.self,
            from: Data(#"{"earnedAchievementIDs":["finish-book","finish-three-books"]}"#.utf8))
        XCTAssertTrue(unidentified.earnedAchievementIDs.allSatisfy { !$0.hasPrefix("complete-book-") })
    }

    func testLocalProgressAndRepeatedCloudMergesKeepExactlyOneAwardForEachCompletedBook() throws {
        var local = PlayerProfile()
        var durable = RunStore.Progress()
        for book in Book.allCases {
            XCTAssertTrue(durable.recordCompletion(of: book))
        }
        local.achievementProgress.merge(localProgress: durable)
        local.normalize()
        let expected = Set(Book.allCases.map { AchievementCatalog.bookCompletion(for: $0).id })
        XCTAssertEqual(Set(local.earnedAchievementIDs.filter { $0.hasPrefix("complete-book-") }), expected)
        var remote = PlayerProfile()
        for _ in 0..<4 { remote.merge(remote: local); local.merge(remote: remote) }
        let restored = try JSONDecoder().decode(PlayerProfile.self, from: JSONEncoder().encode(local))
        XCTAssertEqual(restored.earnedAchievementIDs, expected)
        XCTAssertEqual(restored.achievementProgress.completedBookVolumes, Set(1...12))
    }
}
