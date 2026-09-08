import Foundation
import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Pure progression values and non-persisting models: no live profile, save,
/// cloud, Game Center, or ad service writes. SceneKit material reuse/selection
/// is covered separately by BookstoreObstacleTests; this matrix checks the
/// identity-bearing progress and lifecycle values those materials consume.
@MainActor
final class BookProgressionMatrixTests: XCTestCase {
    func testEveryBooksWholeObstacleLadderSurvivesCloudMergeAndSelectionWithoutLeaking() throws {
        for completedBook in Book.allCases {
            var progress = RunStore.Progress()
            var profile = PlayerProfile()
            for obstacle in Obstacle.allCases {
                XCTAssertTrue(progress.recordCompletion(of: completedBook, obstacle: obstacle))
                XCTAssertFalse(progress.recordCompletion(of: completedBook, obstacle: obstacle))
                progress = try roundTrip(progress)
                profile.achievementProgress.merge(localProgress: progress)

                var otherDevice = PlayerProfile()
                otherDevice.merge(remote: try roundTrip(profile))
                otherDevice.merge(remote: PlayerProfile())
                profile.merge(remote: otherDevice)
                profile = try roundTrip(profile)
                let access = BookEdition.obstacleUnlocks(for: profile.achievementProgress, arguments: [])
                let expectedCeiling = min(9, obstacle.rawValue + 1)
                XCTAssertEqual(profile.achievementProgress.completedBookVolumes, [completedBook.volume])
                XCTAssertEqual(progress.completedBooks, [completedBook.rawValue])

                // Selecting the just-unlocked edition and then every other
                // edition must resolve its own ceiling, never the last focus.
                let requested = try XCTUnwrap(Obstacle(rawValue: expectedCeiling))
                for edition in BookEdition.shelf.reversed() {
                    let expected = edition.rule == completedBook ? expectedCeiling : 1
                    XCTAssertEqual(progress.unlockedObstacle(for: edition.rule).rawValue, expected)
                    XCTAssertEqual(edition.unlockedObstacleRawValue(progressByBookID: access), expected)
                    XCTAssertEqual(edition.availableObstacle(requested, progressByBookID: access),
                                   edition.rule == completedBook ? requested : .none)
                }
                XCTAssertFalse(progress.recordCompletion(of: completedBook, obstacle: .none))
            }
        }
    }

    func testEachBooksFinalReceiptSettlesOnceAndFeedsOnlyItsOwnProgressIdentity() throws {
        for book in Book.allCases {
            let obstacle = try XCTUnwrap(Obstacle(rawValue: (book.volume - 1) % 9 + 1))
            var run = RunState(seed: "profile-final-\(book.rawValue)", book: book, obstacle: obstacle)
            run.level = 9
            run.slot = .boss
            run.pendingBoss = .unluckyLucky
            var won = Game(run: run)
            try won.startPuzzle()
            won.qaMeetTarget()
            let expectedPayout = won.run.payout(for: try XCTUnwrap(won.puzzle)).total
            let model = GameModel(resuming: won, savesProgress: false)
            XCTAssertEqual(model.run.outcome, .bookCompleted)
            XCTAssertEqual(model.page, .results)
            XCTAssertEqual(model.run.book, book)
            XCTAssertEqual(model.run.obstacle, obstacle)
            XCTAssertEqual(model.run.coins, won.run.coins + expectedPayout)
            XCTAssertNil(model.shop)

            // Use the same pure progress reducers as persist(), deliberately
            // without invoking the real on-disk/profile stores from a test.
            var progress = RunStore.Progress()
            XCTAssertTrue(progress.recordCompletion(of: model.run.book, obstacle: model.run.obstacle))
            var profile = PlayerProfile()
            profile.achievementProgress.recordBookCompleted(model.run.book, obstacle: model.run.obstacle)
            let resumed = try resumedModel(model.gameForPersistence)
            resumed.showResults()
            XCTAssertEqual(resumed.run.coins, model.run.coins)
            XCTAssertNil(resumed.lastPayout)
            XCTAssertNil(resumed.shop)
            XCTAssertFalse(progress.recordCompletion(of: resumed.run.book, obstacle: resumed.run.obstacle))
            let access = try roundTrip(profile).achievementProgress.unlockedObstaclesByBookID
            for other in Book.allCases {
                let expected = other == book ? min(9, obstacle.rawValue + 1) : 1
                XCTAssertEqual(access[other.rawValue], expected)
                XCTAssertEqual(progress.unlockedObstacle(for: other).rawValue, expected)
            }
        }
    }

    func testEveryBookAndObstacleResumesRewardWithInventoryScoringAndRestrictionsIntact() throws {
        for book in Book.allCases {
            for obstacle in Obstacle.allCases {
                let pending = try pendingInventoryGame(book: book, obstacle: obstacle)
                let model = GameModel(resuming: pending, savesProgress: false)
                XCTAssertEqual(model.page, .results)
                let ticket = try XCTUnwrap(model.beginRewardedRescue())
                XCTAssertTrue(model.receiveRewardedRescue(ticket))
                XCTAssertFalse(model.receiveRewardedRescue(ticket))
                XCTAssertEqual(model.page, .results, "The ad has not dismissed yet")

                let resumed = try resumedModel(model.gameForPersistence)
                XCTAssertEqual(resumed.run.book, book)
                XCTAssertEqual(resumed.run.obstacle, obstacle)
                XCTAssertEqual(resumed.page, .puzzle)
                XCTAssertEqual(resumed.puzzle?.turnsRemaining, 3)
                XCTAssertEqual(resumed.puzzle?.rewardedRescueUsed, true)
                XCTAssertEqual(resumed.puzzle?.board.placed, pending.puzzle?.board.placed)
                XCTAssertEqual(resumed.puzzle?.hand, pending.puzzle?.hand)
                XCTAssertEqual(resumed.puzzle?.score, pending.puzzle?.score)
                XCTAssertGreaterThan(resumed.score, 0)
                XCTAssertEqual(resumed.puzzle?.itemState, pending.puzzle?.itemState)
                XCTAssertEqual(resumed.puzzle?.armedFlags, pending.puzzle?.armedFlags)
                XCTAssertEqual(resumed.puzzle?.blockedDigits, pending.puzzle?.blockedDigits)
                XCTAssertEqual(try normalizedSnapshot(resumed.game),
                               try normalizedSnapshot(model.gameForPersistence))
                XCTAssertFalse(resumed.receiveRewardedRescue(ticket), "An old model's ticket cannot grant again")
                XCTAssertNil(resumed.beginRewardedRescue())

                resumed.endTurn()
                let afterAnotherClose = try resumedModel(resumed.gameForPersistence)
                XCTAssertEqual(afterAnotherClose.puzzle?.turnsRemaining, 2)
                XCTAssertEqual(afterAnotherClose.page, .puzzle)
                XCTAssertEqual(try normalizedSnapshot(afterAnotherClose.game),
                               try normalizedSnapshot(resumed.gameForPersistence))
            }
        }
    }

    private func pendingInventoryGame(book: Book, obstacle: Obstacle) throws -> Game {
        var run = RunState(seed: "profile-rescue-\(book.rawValue)-\(obstacle.rawValue)",
                           book: book, obstacle: obstacle)
        run.bookmarks = [Bookmarks.helpWanted, "bm_local_gossip", "bm_morning_edition", "bm_op_ed"]
            .map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5) }
        run.buffs = ["bf_insurance", "bf_insurance"]
            .map { OwnedBuff(defID: $0, pricePaid: 4) }
        var game = Game(run: run)
        try game.startPuzzle()
        let puzzle = try XCTUnwrap(game.puzzle)
        let index = try XCTUnwrap(puzzle.hand.indices.first { !puzzle.isBlocked(handIndex: $0) })
        let square = try XCTUnwrap(puzzle.board.blanks.first { puzzle.board.correctDigit(at: $0) == puzzle.hand[index] })
        run = game.run
        run.markers = [OwnedMarker(defID: Markers.rose, boughtAtLevel: 1, pricePaid: 5, squares: [square])]
        // Previously used Fresh Ink is stored separately from the two held
        // Buff slots; rescue must preserve both the effect and the inventory.
        run.puzzle?.itemState[Buffs.freshInk] = 2
        // A deliberately high fixture target permits the genuine exhausted
        // Turn/rescue path despite Morning Edition's passive score income.
        run.puzzle?.target = 1_000_000
        game = Game(run: run)
        XCTAssertTrue(try game.useBuff(at: 0))
        XCTAssertFalse(try game.useBuff(at: 0), "Spare Insurance must remain held while already armed")
        _ = try game.place(handIndex: index, at: square)
        while game.puzzle?.phase == .playing { _ = try game.endTurn() }
        XCTAssertTrue(game.canClaimRewardedRescue)
        XCTAssertEqual(game.run.buffs.map(\.defID), ["bf_insurance"])
        XCTAssertEqual(game.puzzle?.armedFlags, [.insurance])
        return game
    }

    private func resumedModel(_ game: Game) throws -> GameModel {
        let bytes = try XCTUnwrap(RunStore.dataForStorage(of: game))
        return GameModel(resuming: try XCTUnwrap(RunStore.game(from: bytes)), savesProgress: false)
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    /// These fixtures have no Boss dictionaries. Canonicalize only the
    /// unordered obstacle digit set; keep Hand, inventory and board order.
    private func normalizedSnapshot(_ game: Game) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        if var puzzle = json["puzzle"] as? [String: Any] {
            puzzle["obstacleBlockedDigits"] = game.puzzle?.obstacleBlockedDigits.sorted().map(\.rawValue)
            json["puzzle"] = puzzle
        }
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }
}
