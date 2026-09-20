import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Exercises the app's claim lifetime and the exact persisted RunStore payload
/// without touching the player's disk save, cloud account, or achievements.
@MainActor
final class SkipRewardSessionTests: XCTestCase {
    func testNormalBookStartSavesTheFirstUndealtOfferBeforeAnyAction() throws {
        var snapshots: [Data] = []
        let started = try XCTUnwrap(GameModel.startingBook(seed: "normal-first-briefing", book: .probably,
                                            obstacle: .none) { game in
            guard let data = try? RunStore.dataForStorage(of: game) else { return false }
            snapshots.append(data)
            return true
        })
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(started.page, .briefing)
        XCTAssertNil(started.puzzle)
        let saved = try XCTUnwrap(RunStore.game(from: XCTUnwrap(snapshots.first)))
        let resumed = GameModel(resuming: saved, savesProgress: false)
        XCTAssertEqual(resumed.page, .briefing)
        XCTAssertNil(resumed.puzzle)
        XCTAssertEqual(resumed.run.seed, started.run.seed)
        XCTAssertEqual(resumed.run.currentSkipOffer, started.run.currentSkipOffer)
        XCTAssertTrue(resumed.run.skipHistory.isEmpty)
        XCTAssertTrue(resumed.run.buffs.isEmpty)
        XCTAssertEqual(try saved.encoded(), try started.game.encoded(),
                       "Starting a Book must save its initial streams without dealing or granting its offer")
    }

    func testOfferSurvivesRedrawsNavigationAndResumeButOldClaimsDoNot() throws {
        let model = makeModel()
        let first = try XCTUnwrap(model.currentSkipClaim)
        let before = try XCTUnwrap(RunStore.dataForStorage(of: model.game))
        for _ in 0..<10 {
            XCTAssertEqual(model.currentSkipClaim, first)
            XCTAssertEqual(model.run.currentSkipOffer, first.offer)
        }

        model.openAchievements()
        XCTAssertNil(model.currentSkipClaim)
        XCTAssertFalse(model.takeSkip(ifCurrent: first))
        model.closeAchievements()
        let returned = try XCTUnwrap(model.currentSkipClaim)
        XCTAssertEqual(returned.offer, first.offer)
        XCTAssertNotEqual(returned, first, "A delayed callback from the departing page must expire.")
        XCTAssertFalse(model.takeSkip(ifCurrent: first))
        XCTAssertEqual(try RunStore.dataForStorage(of: model.game), before)

        let restoredGame = try XCTUnwrap(RunStore.game(from: before))
        let restored = GameModel(resuming: restoredGame, savesProgress: false)
        let restoredClaim = try XCTUnwrap(restored.currentSkipClaim)
        XCTAssertEqual(restoredClaim.offer, first.offer)
        XCTAssertFalse(restored.takeSkip(ifCurrent: returned))
        XCTAssertTrue(restored.takeSkip(ifCurrent: restoredClaim))
        XCTAssertEqual(restored.run.buffs.map(\.defID), [first.offer.buffID])
        XCTAssertEqual(restored.run.skipHistory.count, 1)
    }

    func testShopExitAndShopResumeExposeTheSameNextOffer() throws {
        var game = Game(seed: "skip-shop-resume")
        try game.startPuzzle()
        game.qaMeetTarget()
        _ = try game.cashOut()
        game.openShop()
        let shopSave = try XCTUnwrap(RunStore.dataForStorage(of: game))
        let direct = GameModel(resuming: game, savesProgress: false)
        let restored = GameModel(resuming: try XCTUnwrap(RunStore.game(from: shopSave)), savesProgress: false)
        XCTAssertNil(direct.currentSkipClaim)
        XCTAssertNil(restored.currentSkipClaim)

        direct.continueToNextPuzzle()
        restored.continueToNextPuzzle()
        let expected = try XCTUnwrap(direct.currentSkipClaim)
        let actual = try XCTUnwrap(restored.currentSkipClaim)
        XCTAssertEqual(actual.offer, expected.offer)
        XCTAssertEqual(actual.offer.slot, .medium)
        XCTAssertNil(restored.shop)
        XCTAssertTrue(restored.takeSkip(ifCurrent: actual))
        XCTAssertEqual(restored.run.slot, .boss)
        XCTAssertNil(restored.currentSkipClaim)
    }

    func testFullInventoryRequiresAnExplicitChoiceAndCancellationKeepsEverything() throws {
        var run = RunState(seed: "skip-full-inventory")
        run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 3),
                     OwnedBuff(defID: Buffs.peek, pricePaid: 4)]
        let model = makeModel(run)
        let claim = try XCTUnwrap(model.currentSkipClaim)
        let before = try XCTUnwrap(RunStore.dataForStorage(of: model.game))
        let originalIDs = model.run.buffs.map(\.id)
        XCTAssertEqual(Set(originalIDs).count, 2, "Duplicate definitions are separate consumables.")

        XCTAssertFalse(model.takeSkip(ifCurrent: claim))
        XCTAssertEqual(try RunStore.dataForStorage(of: model.game), before)
        XCTAssertEqual(model.currentSkipClaim, claim,
                       "Requesting a replacement must not discard the advertised offer.")
        XCTAssertFalse(model.takeSkip(ifCurrent: claim, replacingBuffID: UUID()))
        XCTAssertEqual(try RunStore.dataForStorage(of: model.game), before)

        // Closing the chooser performs no acceptance. Navigation also expires
        // any delayed replacement callback while preserving both originals.
        model.openAchievements()
        model.closeAchievements()
        XCTAssertFalse(model.takeSkip(ifCurrent: claim, replacingBuffID: originalIDs[0]))
        XCTAssertEqual(try RunStore.dataForStorage(of: model.game), before)
        XCTAssertEqual(model.run.buffs.map(\.id), originalIDs)

        let fresh = try XCTUnwrap(model.currentSkipClaim)
        XCTAssertTrue(model.takeSkip(ifCurrent: fresh, replacingBuffID: originalIDs[1]))
        XCTAssertEqual(model.run.buffs.count, 2)
        XCTAssertEqual(model.run.buffs[0].id, originalIDs[0])
        XCTAssertEqual(model.run.buffs[0].pricePaid, 3)
        XCTAssertFalse(model.run.buffs.contains { $0.id == originalIDs[1] })
        XCTAssertEqual(model.run.buffs[1].defID, fresh.offer.buffID)
        XCTAssertEqual(model.run.skipHistory.first?.replacedBuffID, originalIDs[1])
        XCTAssertEqual(model.run.skipHistory.first?.rewardID, model.run.buffs[1].id)
        let committed = try model.game.encoded()
        XCTAssertFalse(model.takeSkip(ifCurrent: fresh, replacingBuffID: originalIDs[0]))
        XCTAssertEqual(try model.game.encoded(), committed)
    }

    func testSkipRewardInventoryAndProgressionRoundTripAsOneSavedAction() throws {
        var run = RunState(seed: "skip-atomic-save")
        run.buffs = [OwnedBuff(defID: Buffs.freshInk, pricePaid: 4)]
        let existing = run.buffs[0].id
        let model = makeModel(run)
        let claim = try XCTUnwrap(model.currentSkipClaim)
        let coins = model.coins

        XCTAssertTrue(model.takeSkip(ifCurrent: claim))
        let committedData = try XCTUnwrap(RunStore.dataForStorage(of: model.gameForPersistence))
        let committed = try XCTUnwrap(RunStore.game(from: committedData))
        let record = try XCTUnwrap(committed.run.skipHistory.first)
        XCTAssertEqual(committed.run.slot, .medium)
        XCTAssertEqual(committed.run.level, 1)
        XCTAssertEqual(committed.run.skipsUsed, 1)
        XCTAssertEqual(committed.run.buffs.count, 2)
        XCTAssertEqual(committed.run.buffs[0].id, existing)
        XCTAssertEqual(committed.run.buffs[1].id, record.rewardID)
        XCTAssertEqual(record.offer, claim.offer)
        XCTAssertNil(record.replacedBuffID)
        XCTAssertEqual(committed.run.coins, coins)
        XCTAssertTrue(committed.run.takenClippings.isEmpty)
        XCTAssertNil(committed.run.runItemState["clipping.overprint"])
        XCTAssertNil(committed.run.runItemState["clipping.circulation"])
        XCTAssertNil(committed.puzzle)
        XCTAssertNil(committed.shop)

        let restored = GameModel(resuming: committed, savesProgress: false)
        XCTAssertFalse(restored.takeSkip(ifCurrent: claim))
        XCTAssertEqual(try RunStore.dataForStorage(of: restored.game), committedData)
        XCTAssertEqual(restored.run.buffs.map(\.id), committed.run.buffs.map(\.id))
        XCTAssertEqual(restored.run.skipHistory, committed.run.skipHistory)
    }

    func testEveryChapterStillOffersOrdinarySkipsAfterPriorSkips() throws {
        var game = Game(seed: "skip-all-chapters-app")
        for level in 1...9 {
            let model = GameModel(resuming: game, savesProgress: false)
            for slot in [PuzzleSlot.easy, .medium] {
                XCTAssertEqual(model.run.level, level)
                XCTAssertEqual(model.run.slot, slot)
                let claim = try XCTUnwrap(model.currentSkipClaim)
                let replacing = model.run.buffs.count == ItemKind.buff.capacity ? model.run.buffs[0].id : nil
                XCTAssertTrue(model.takeSkip(ifCurrent: claim, replacingBuffID: replacing))
                XCTAssertLessThanOrEqual(model.run.buffs.count, ItemKind.buff.capacity)
            }
            XCTAssertEqual(model.run.slot, .boss)
            XCTAssertNil(model.currentSkipClaim)
            XCTAssertEqual(model.run.skipsUsed, level * 2)
            game = model.game
            let mandatoryBoss = try game.encoded()
            XCTAssertFalse(game.advance(), "A mandatory Boss cannot be bypassed from its briefing")
            XCTAssertEqual(try game.encoded(), mandatoryBoss)
            try game.startPuzzle()
            XCTAssertNotNil(game.puzzle?.boss)
            // Boss gameplay has separate engine coverage. Seed a won result
            // through the QA helper, then use the real cash-out/Shop lifecycle.
            game.qaMeetTarget()
            XCTAssertEqual(game.puzzle?.phase, .won)
            _ = try game.cashOut()
            if level < 9 {
                game.openShop()
                XCTAssertNotNil(game.shop)
                XCTAssertTrue(game.advance())
            } else {
                XCTAssertEqual(game.run.outcome, .bookCompleted)
                game.openShop()
                XCTAssertNil(game.shop)
                XCTAssertFalse(game.advance())
            }
        }
    }

    func testFrozenOutgoingPageCannotClaimTheLiveOffer() throws {
        let game = Game(seed: "skip-outgoing-page")
        let live = GameModel(resuming: game, savesProgress: false)
        let frozen = GameModel(frozen: game, page: .briefing)
        let claim = try XCTUnwrap(live.currentSkipClaim)
        XCTAssertNil(frozen.currentSkipClaim)
        XCTAssertFalse(frozen.takeSkip(ifCurrent: claim))
        XCTAssertEqual(try frozen.game.encoded(), try game.encoded())
    }

    private func makeModel(_ run: RunState = RunState(seed: "skip-session")) -> GameModel {
        GameModel(resuming: Game(run: run), savesProgress: false)
    }
}
