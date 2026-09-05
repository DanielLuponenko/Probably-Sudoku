import XCTest
import Foundation
import ProbablySudokuEngine
@testable import ProbablySudoku

/// All migration checks encode/decode in-memory values. Never call RunStore's
/// disk-backed progress accessors or mutate the player's completion file.
final class BookCompletionProgressTests: XCTestCase {
    func testLegacyTwoBookJSONRetainsCompletedIdentitiesAndObstacleUnlock() throws {
        let progress = try legacyProgress()

        XCTAssertEqual(progress.completedBooks, Set(["probably", "slightlyHarder"]))
        XCTAssertEqual(progress.completedBooks.count, 2)
        XCTAssertEqual(progress.booksCompleted, 2)
        XCTAssertEqual(progress.unlockedObstacle, 3)
        XCTAssertEqual(progress.unlockedObstacle(for: .probably), .shortHanded)
        XCTAssertEqual(progress.unlockedObstacle(for: .slightlyHarder), .shortHanded)
        for book in Book.allCases where book.volume > 2 {
            XCTAssertEqual(progress.unlockedObstacle(for: book), .none)
        }
    }

    func testOutOfOrderTwelfthBookCountsOnceWithoutInventingTheFirstElevenCompletions() throws {
        var progress = RunStore.Progress()
        let lastBook = try book(volume: 12)

        XCTAssertTrue(progress.recordCompletion(of: lastBook))

        XCTAssertEqual(progress.completedBooks, Set([lastBook.rawValue]))
        XCTAssertEqual(progress.completedBooks.count, 1)
        XCTAssertEqual(progress.booksCompleted, 0, "The legacy field remains a contiguous prefix")
        XCTAssertEqual(progress.unlockedObstacle(for: lastBook), .shortHanded)
        for book in Book.allCases where book != lastBook {
            XCTAssertEqual(progress.unlockedObstacle(for: book), .none)
        }
    }

    func testReplayingACompletedBookDoesNotIncreaseCountOrUnlockAgain() throws {
        var progress = RunStore.Progress()
        let lastBook = try book(volume: 12)
        XCTAssertTrue(progress.recordCompletion(of: lastBook))

        for _ in 0..<3 {
            XCTAssertFalse(progress.recordCompletion(of: lastBook))
        }

        XCTAssertEqual(progress.completedBooks, Set([lastBook.rawValue]))
        XCTAssertEqual(progress.booksCompleted, 0)
        XCTAssertEqual(progress.unlockedObstacle(for: lastBook), .shortHanded)
    }

    func testClosingGapsAdvancesOnlyTheLegacyContiguousPrefix() throws {
        var progress = RunStore.Progress()
        XCTAssertTrue(progress.recordCompletion(of: try book(volume: 12)))
        XCTAssertTrue(progress.recordCompletion(of: .noPressure))
        XCTAssertEqual(progress.booksCompleted, 0)

        XCTAssertTrue(progress.recordCompletion(of: .probably))
        XCTAssertEqual(progress.booksCompleted, 1)
        XCTAssertEqual(progress.completedBooks.count, 3)

        XCTAssertTrue(progress.recordCompletion(of: .slightlyHarder))
        XCTAssertEqual(progress.booksCompleted, 3,
                       "Volume 3 was already completed, so closing Volume 2 fills the prefix")
        XCTAssertEqual(progress.completedBooks.count, 4)
        for book in Book.allCases {
            XCTAssertEqual(progress.unlockedObstacle(for: book),
                           progress.completedBooks.contains(book.rawValue) ? .shortHanded : .none)
        }
    }

    func testFirstNewCompletionMaterializesLegacyIdentitiesAndRejectsLegacyReplay() throws {
        var progress = try legacyProgress()
        XCTAssertFalse(progress.recordCompletion(of: .probably))
        XCTAssertEqual(progress.unlockedObstacle, 3)

        XCTAssertTrue(progress.recordCompletion(of: .noPressure))
        XCTAssertEqual(progress.completedBooks, Set(["probably", "slightlyHarder", "noPressure"]))
        XCTAssertEqual(progress.booksCompleted, 3)
        XCTAssertEqual(progress.unlockedObstacle, 3, "Keep the old ambiguous scalar for rollback only")
        XCTAssertEqual(progress.unlockedObstacle(for: .noPressure), .shortHanded)
        XCTAssertEqual(progress.unlockedObstacle(for: .bites), .none)
    }

    func testNewProgressRoundTripKeepsOutOfOrderIdentitiesAndReplayProtection() throws {
        var progress = RunStore.Progress()
        let lastBook = try book(volume: 12)
        XCTAssertTrue(progress.recordCompletion(of: lastBook))
        XCTAssertTrue(progress.recordCompletion(of: .probably))
        let encoded = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(RunStore.Progress.self, from: encoded)

        XCTAssertEqual(restored.completedBooks, progress.completedBooks)
        XCTAssertEqual(restored.booksCompleted, 1)
        XCTAssertEqual(restored.unlockedObstacle(for: lastBook), .shortHanded)
        XCTAssertFalse(restored.recordCompletion(of: lastBook))
        XCTAssertFalse(restored.recordCompletion(of: .probably))
        XCTAssertEqual(restored.unlockedObstacle(for: .probably), .shortHanded)
    }

    func testExplicitNewIdentitySetIsAuthoritativeRatherThanRemigratingLegacyCounter() throws {
        let json = Data(#"{"unlockedObstacle":3,"booksCompleted":2,"completedBookIDs":[]}"#.utf8)
        let progress = try JSONDecoder().decode(RunStore.Progress.self, from: json)

        XCTAssertTrue(progress.completedBooks.isEmpty,
                      "Only a missing identity set should migrate the old contiguous count")
        for book in Book.allCases { XCTAssertEqual(progress.unlockedObstacle(for: book), .none) }
    }

    func testCompletingAllTwelveBooksOnOneUnlocksOnlyTwoForEachBook() {
        var progress = RunStore.Progress()
        for book in Book.allCases.reversed() {
            XCTAssertTrue(progress.recordCompletion(of: book))
            XCTAssertEqual(progress.unlockedObstacle(for: book), .shortHanded)
        }
        XCTAssertEqual(progress.completedBooks.count, 12)
        XCTAssertEqual(progress.booksCompleted, 12)
        for book in Book.allCases {
            XCTAssertFalse(progress.recordCompletion(of: book))
            XCTAssertEqual(progress.unlockedObstacle(for: book), .shortHanded)
        }
    }

    func testHarderWinsAdvanceOnlyThatBookAndDuplicateOrEasierWinsCannotAdvanceAgain() throws {
        var progress = RunStore.Progress()
        for obstacle in Obstacle.allCases {
            XCTAssertTrue(progress.recordCompletion(of: .probably, obstacle: obstacle))
            XCTAssertEqual(progress.unlockedObstacle(for: .probably).rawValue, min(9, obstacle.rawValue + 1))
            for other in Book.allCases where other != .probably {
                XCTAssertEqual(progress.unlockedObstacle(for: other), .none)
            }
            XCTAssertFalse(progress.recordCompletion(of: .probably, obstacle: obstacle))
            XCTAssertFalse(progress.recordCompletion(of: .probably, obstacle: .none))
        }
        let restored = try JSONDecoder().decode(RunStore.Progress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored.completedBooks, [Book.probably.rawValue])
        XCTAssertEqual(restored.completedObstacles, [Book.probably.rawValue: 9])
        XCTAssertEqual(restored.unlockedObstacle(for: .probably), .finalEdition)
    }

    func testLegacyGlobalQAUnlockWithoutIdentifiedWinsDoesNotUnlockAnyBook() throws {
        let data = Data(#"{"unlockedObstacle":9,"booksCompleted":0}"#.utf8)
        let progress = try JSONDecoder().decode(RunStore.Progress.self, from: data)
        for book in Book.allCases { XCTAssertEqual(progress.unlockedObstacle(for: book), .none) }
        XCTAssertEqual(progress.unlockedObstacle, 9, "Ambiguous legacy evidence is preserved, not attributed")
    }

    @MainActor
    func testEachBooksFirstWinSurvivesSaveAndCloudRoundTripsWithoutUnlockingAnotherBook() throws {
        for completedBook in Book.allCases {
            // A retained old global IX is not evidence that any particular
            // Book was completed. Only this identified I win can unlock II.
            let legacy = Data(#"{"unlockedObstacle":9,"booksCompleted":0}"#.utf8)
            var localProgress = try JSONDecoder().decode(RunStore.Progress.self, from: legacy)
            XCTAssertTrue(localProgress.recordCompletion(of: completedBook, obstacle: .none))
            localProgress = try JSONDecoder().decode(RunStore.Progress.self,
                                                     from: JSONEncoder().encode(localProgress))
            var localProfile = PlayerProfile()
            localProfile.achievementProgress.merge(localProgress: localProgress)

            // Model the upload, second-device receive, stale snapshot merge,
            // and eventual reread without touching disk or the real cloud.
            let uploaded = try JSONDecoder().decode(PlayerProfile.self,
                                                     from: JSONEncoder().encode(localProfile))
            var otherDevice = PlayerProfile()
            otherDevice.merge(remote: uploaded)
            otherDevice.merge(remote: PlayerProfile())
            localProfile.merge(remote: otherDevice)
            for _ in 0..<3 {
                XCTAssertFalse(localProgress.recordCompletion(of: completedBook, obstacle: .none))
                localProfile.achievementProgress.recordBookCompleted(completedBook, obstacle: .none)
                otherDevice.merge(remote: localProfile)
            }
            let restored = try JSONDecoder().decode(PlayerProfile.self,
                                                     from: JSONEncoder().encode(otherDevice))
            let access = BookEdition.obstacleUnlocks(for: restored.achievementProgress, arguments: [])
            XCTAssertEqual(restored.achievementProgress.completedBookVolumes, [completedBook.volume])
            XCTAssertEqual(localProgress.completedBooks, [completedBook.rawValue])
            XCTAssertEqual(localProgress.unlockedObstacle, 9, "Do not destroy rollback evidence")
            for edition in BookEdition.shelf {
                let expected = edition.rule == completedBook ? 2 : 1
                XCTAssertEqual(localProgress.unlockedObstacle(for: edition.rule).rawValue, expected)
                XCTAssertEqual(edition.unlockedObstacleRawValue(progressByBookID: access), expected,
                               "Completing \(completedBook) leaked its unlock to \(edition.id)")
                XCTAssertEqual(edition.availableObstacle(.shortHanded, progressByBookID: access),
                               edition.rule == completedBook ? .shortHanded : .none)
                XCTAssertEqual(edition.availableObstacle(.smallerHand, progressByBookID: access), .none)
            }
        }
    }

    func testCloudCompletionFactsMergeByBookIdentityAndMaximumNotByTotalCount() throws {
        var local = PlayerProfile()
        local.achievementProgress.recordBookCompleted(.probably, obstacle: .smallerHand)
        var remote = PlayerProfile()
        remote.achievementProgress.recordBookCompleted(.slightlyHarder, obstacle: .shortHanded)
        remote.achievementProgress.recordBookCompleted(.probably, obstacle: .none)
        var reverse = remote
        local.merge(remote: remote)
        reverse.merge(remote: local)
        local.merge(remote: remote)

        XCTAssertEqual(local.achievementProgress, reverse.achievementProgress)
        let restored = try JSONDecoder().decode(PlayerProfile.self, from: JSONEncoder().encode(local))
        let ceilings = restored.achievementProgress.unlockedObstaclesByBookID
        XCTAssertEqual(ceilings[Book.probably.rawValue], Obstacle.smallerHand.rawValue + 1)
        XCTAssertEqual(ceilings[Book.slightlyHarder.rawValue], 3)
        for book in Book.allCases where book != .probably && book != .slightlyHarder {
            XCTAssertEqual(ceilings[book.rawValue], 1)
        }
    }

    func testLocalAndLegacyCloudMigrationKeepOnlyIdentifiedCompletions() throws {
        let json = Data(#"{"highestLevelReached":9,"completedBookVolumes":[4],"completedBossEncounterIDs":[]}"#.utf8)
        var achievements = try JSONDecoder().decode(AchievementProgress.self, from: json)
        achievements.merge(localProgress: try legacyProgress())
        achievements.merge(localProgress: try legacyProgress())
        XCTAssertEqual(achievements.completedBookVolumes, [1, 2, 4])
        for book in Book.allCases {
            XCTAssertEqual(achievements.unlockedObstaclesByBookID[book.rawValue],
                           [1, 2, 4].contains(book.volume) ? 2 : 1)
        }
        XCTAssertFalse(achievements.hasCompletedAllBooks)
    }

    func testUnknownFutureBookFactsSurviveRoundTripWithoutUnlockingCurrentBooks() throws {
        let json = Data(#"{"unlockedObstacle":9,"booksCompleted":0,"completedBookIDs":["future-volume"],"completedObstaclesByBookID":{"future-volume":7}}"#.utf8)
        let progress = try JSONDecoder().decode(RunStore.Progress.self, from: json)
        var achievements = AchievementProgress()
        achievements.merge(localProgress: progress)
        let restored = try JSONDecoder().decode(AchievementProgress.self, from: JSONEncoder().encode(achievements))
        XCTAssertEqual(restored.completedObstacles["future-volume"], 7)
        XCTAssertTrue(restored.completedBookVolumes.isEmpty)
        for book in Book.allCases { XCTAssertEqual(restored.unlockedObstaclesByBookID[book.rawValue], 1) }
    }

    func testWholeShelfRequiresAllTwelveBooksButDoesNotRevokeAlreadyEarnedLegacyAchievement() {
        var profile = PlayerProfile()
        profile.earnedAchievementIDs.insert("finish-every-book")
        profile.achievementProgress.completedBookVolumes = [1, 2, 3, 4, 99]
        XCTAssertFalse(profile.achievementProgress.hasCompletedAllBooks)
        profile.merge(remote: PlayerProfile())
        XCTAssertTrue(profile.earnedAchievementIDs.contains("finish-every-book"))
        for book in Book.allCases { profile.achievementProgress.recordBookCompleted(book, obstacle: .none) }
        XCTAssertTrue(profile.achievementProgress.hasCompletedAllBooks)
        XCTAssertEqual(AchievementCatalog.allBookVolumes, 12)
    }

    private func legacyProgress() throws -> RunStore.Progress {
        let json = Data(#"{"unlockedObstacle":3,"booksCompleted":2}"#.utf8)
        return try JSONDecoder().decode(RunStore.Progress.self, from: json)
    }

    private func book(volume: Int) throws -> Book {
        try XCTUnwrap(Book.allCases.first { $0.volume == volume })
    }
}
