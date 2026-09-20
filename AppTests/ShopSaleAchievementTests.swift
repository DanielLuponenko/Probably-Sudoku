import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// In-memory engine events and the exact policy used by recordSale. These
/// tests never instantiate the disk-backed profile singleton or submit awards.
@MainActor
final class ShopSaleAchievementTests: XCTestCase {
    func testBookmarkAndBuffSalesInTheirPurchaseShopBothRequestBuyersRemorse() throws {
        for kind in [ItemKind.bookmark, .buff] {
            var run = try purchasedItem(kind)
            let purchaseID = try XCTUnwrap(purchaseVisit(in: run, kind: kind))
            let shopID = try XCTUnwrap(run.shop?.visitID)
            let coins = run.coins

            let refund = try Shop.sell(&run, kind: kind, index: 0)

            XCTAssertEqual(run.coins, coins + refund)
            XCTAssertEqual(PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: purchaseID,
                                                                  currentShopVisitID: shopID),
                           ["same-shop-sale"], "\(kind) must use purchase provenance, not item category")
        }
    }

    func testRerollKeepsTheAchievementEligibleAcrossSaveAndResume() throws {
        for kind in [ItemKind.bookmark, .buff] {
            var run = try purchasedItem(kind)
            let purchaseID = try XCTUnwrap(purchaseVisit(in: run, kind: kind))
            try Shop.reroll(&run)
            let restored = try Game(decoding: Game(run: run).encoded()).run

            XCTAssertEqual(purchaseVisit(in: restored, kind: kind), purchaseID)
            XCTAssertEqual(PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: purchaseID,
                                                                  currentShopVisitID: restored.shop?.visitID),
                           ["same-shop-sale"])
        }
    }

    func testAnotherShopInTheSameLevelDoesNotRequestTheAchievement() throws {
        for kind in [ItemKind.bookmark, .buff] {
            var game = Game(run: try purchasedItem(kind))
            let purchaseID = try XCTUnwrap(purchaseVisit(in: game.run, kind: kind))
            XCTAssertTrue(game.advance())
            try game.startPuzzle()
            game.qaMeetTarget()
            _ = try game.cashOut()
            game.openShop()

            XCTAssertEqual(game.run.level, 1)
            XCTAssertEqual(game.run.slot, .medium)
            XCTAssertNotEqual(game.shop?.visitID, purchaseID)
            XCTAssertTrue(PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: purchaseID,
                                                                  currentShopVisitID: game.shop?.visitID).isEmpty)
        }
    }

    func testLeavingTheShopDisqualifiesTheSaleWithoutDisablingItsRefund() throws {
        for kind in [ItemKind.bookmark, .buff] {
            var game = Game(run: try purchasedItem(kind))
            let purchaseID = try XCTUnwrap(purchaseVisit(in: game.run, kind: kind))
            XCTAssertTrue(game.advance())
            XCTAssertNil(game.shop)
            XCTAssertGreaterThan(try game.sell(kind: kind, index: 0), 0)
            XCTAssertTrue(PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: purchaseID,
                                                                  currentShopVisitID: game.shop?.visitID).isEmpty)
        }
    }

    func testUnknownLegacyOriginsAndMissingOrInvalidCurrentVisitsFailClosed() {
        let cases: [(Int?, Int?)] = [(nil, nil), (nil, 1), (1, nil), (1, 2), (0, 0), (-1, -1)]
        for (purchase, current) in cases {
            XCTAssertTrue(PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: purchase,
                                                                  currentShopVisitID: current).isEmpty)
        }
    }

    func testAlreadyEarnedLegacyAwardSurvivesDecodeNormalizationAndCloudMerge() throws {
        let oldJSON = Data(#"{"earnedAchievementIDs":["same-shop-sale"]}"#.utf8)
        var earned = try JSONDecoder().decode(PlayerProfile.self, from: oldJSON)
        earned.normalize()
        earned.merge(remote: PlayerProfile())
        let restored = try JSONDecoder().decode(PlayerProfile.self, from: JSONEncoder().encode(earned))
        XCTAssertEqual(restored.earnedAchievementIDs, ["same-shop-sale"])

        var otherDevice = PlayerProfile()
        otherDevice.merge(remote: restored)
        XCTAssertEqual(otherDevice.earnedAchievementIDs, ["same-shop-sale"])
        otherDevice.merge(remote: restored)
        XCTAssertEqual(otherDevice.earnedAchievementIDs.count, 1, "Replaying a cloud award is idempotent")
    }

    func testEligibilityKeepsTheExistingLocalAndServerAchievementIdentityAndWording() throws {
        let requested = PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: 3, currentShopVisitID: 3)
        let definition = try XCTUnwrap(AchievementCatalog.definition(for: try XCTUnwrap(requested.first)))
        XCTAssertEqual(definition.id, "same-shop-sale")
        XCTAssertEqual(definition.gameCenterID, "com.numberclub.app.achievement.same_shop_sale")
        XCTAssertEqual(definition.detail, "Sell an item back in the Shop where you bought it.")
    }

    func testCapacitySaleReportsBothExactOriginalPurchaseReceipts() throws {
        for bookmarkBoughtHere in [false, true] {
            var model = GameModel(resuming: capacitySaleGame(bookmarkBoughtHere: bookmarkBoughtHere), savesProgress: false)
            let pocket = try XCTUnwrap(model.run.bookmarks.first)
            let chosen = model.run.buffs[1]
            let retained = [model.run.buffs[0].id, model.run.buffs[2].id]
            model.sell(kind: .bookmark, index: 0)
            let before = model.run
            let choice = try XCTUnwrap(model.pendingItemDecision)
            XCTAssertEqual(choice.kind, "bookmark.capacitySale")
            let selected = [chosen.id.uuidString]
            model = GameModel(resuming: try Game(decoding: model.game.encoded()), savesProgress: false)

            XCTAssertTrue(model.resolveItemDecision(id: choice.id, selected: selected))
            let receipts = GameModel.capacitySaleReceipts(before: before, after: model.run,
                                                          decisionID: choice.id, selected: selected)
            XCTAssertEqual(receipts.map(\.kind), [.buff, .bookmark])
            XCTAssertEqual(receipts.map(\.instanceID), [chosen.id, pocket.id])
            XCTAssertEqual(receipts.map(\.boughtInShopVisitID), [chosen.boughtInShopVisitID, pocket.boughtInShopVisitID])
            XCTAssertEqual(receipts.map(\.currentShopVisitID), [before.shop?.visitID, before.shop?.visitID])
            XCTAssertEqual(model.run.buffs.map(\.id), retained, "Duplicate Buff definitions retain separate identities")
            XCTAssertTrue(model.run.bookmarks.isEmpty)
            for receipt in receipts {
                let boughtHere = receipt.kind == .bookmark ? bookmarkBoughtHere : !bookmarkBoughtHere
                let awards = PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: receipt.boughtInShopVisitID,
                                                                   currentShopVisitID: receipt.currentShopVisitID)
                XCTAssertEqual(awards, boughtHere ? ["same-shop-sale"] : [])
            }
        }
    }

    func testCapacitySaleCancellationInvalidChoiceAndReplayProduceNoReceipts() throws {
        let model = GameModel(resuming: capacitySaleGame(bookmarkBoughtHere: true), savesProgress: false)
        model.sell(kind: .bookmark, index: 0)
        let beforeCancel = model.run
        let cancelled = try XCTUnwrap(model.pendingItemDecision)
        XCTAssertTrue(model.resolveItemDecision(id: cancelled.id, selected: nil))
        XCTAssertTrue(GameModel.capacitySaleReceipts(before: beforeCancel, after: model.run,
                                                     decisionID: cancelled.id, selected: nil).isEmpty)
        XCTAssertEqual(model.run.buffs.map(\.id), beforeCancel.buffs.map(\.id))
        XCTAssertEqual(model.run.bookmarks.map(\.id), beforeCancel.bookmarks.map(\.id))
        XCTAssertEqual(model.run.coins, beforeCancel.coins)

        model.sell(kind: .bookmark, index: 0)
        let before = model.run
        let choice = try XCTUnwrap(model.pendingItemDecision)
        let selected = [before.buffs[1].id.uuidString]
        let saved = try model.game.encoded()
        XCTAssertFalse(model.resolveItemDecision(id: cancelled.id, selected: selected))
        XCTAssertTrue(GameModel.capacitySaleReceipts(before: before, after: model.run,
                                                     decisionID: cancelled.id, selected: selected).isEmpty)
        let invalid = [UUID().uuidString]
        XCTAssertFalse(model.resolveItemDecision(id: choice.id, selected: invalid))
        XCTAssertTrue(GameModel.capacitySaleReceipts(before: before, after: model.run,
                                                     decisionID: choice.id, selected: invalid).isEmpty)
        XCTAssertEqual(try model.game.encoded(), saved)
        XCTAssertTrue(model.resolveItemDecision(id: choice.id, selected: selected))
        let committed = model.run
        XCTAssertFalse(model.resolveItemDecision(id: choice.id, selected: selected))
        XCTAssertTrue(GameModel.capacitySaleReceipts(before: committed, after: model.run,
                                                     decisionID: choice.id, selected: selected).isEmpty)
    }

    func testCapacitySaleOutsideShopKeepsSelectedHandCopyAndCannotAwardSameShopSale() throws {
        var game = capacitySaleGame(bookmarkBoughtHere: true)
        XCTAssertTrue(game.advance())
        try game.startPuzzle()
        let model = GameModel(resuming: game, savesProgress: false)
        let card = try XCTUnwrap(model.handCards.first)
        model.tapHandCard(card.id)
        let hand = model.handCards.map(\.id)
        model.sell(kind: .bookmark, index: 0)
        let before = model.run
        let choice = try XCTUnwrap(model.pendingItemDecision)
        let selected = [before.buffs[1].id.uuidString]
        XCTAssertTrue(model.resolveItemDecision(id: choice.id, selected: selected))
        XCTAssertEqual(model.handCards.map(\.id), hand)
        let selection = try XCTUnwrap(model.selectedHandIndex)
        XCTAssertEqual(model.handCards[selection].id, card.id)
        let receipts = GameModel.capacitySaleReceipts(before: before, after: model.run,
                                                      decisionID: choice.id, selected: selected)
        XCTAssertEqual(receipts.count, 2)
        for receipt in receipts {
            XCTAssertNil(receipt.currentShopVisitID)
            XCTAssertTrue(PlayerProfileStore.saleAchievementIDs(boughtInShopVisitID: receipt.boughtInShopVisitID,
                                                                 currentShopVisitID: receipt.currentShopVisitID).isEmpty)
        }
    }

    private func capacitySaleGame(bookmarkBoughtHere: Bool) -> Game {
        var run = RunState(seed: "CAPACITY-SALE-ACHIEVEMENT")
        Shop.open(&run)
        let visit = run.shop!.visitID!
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.pocketInsert, boughtAtLevel: 1, pricePaid: 8,
                                      boughtInShopVisitID: bookmarkBoughtHere ? visit : visit + 1)]
        run.buffs = (0..<3).map { index in
            OwnedBuff(defID: Buffs.peek, pricePaid: 3,
                      boughtInShopVisitID: index == 1 && !bookmarkBoughtHere ? visit : visit + 1)
        }
        return Game(run: run)
    }

    private func purchasedItem(_ kind: ItemKind) throws -> RunState {
        var run = RunState(seed: "SHOP-SALE-ACHIEVEMENT")
        run.coins = 100
        Shop.open(&run)
        let offer = try XCTUnwrap(run.shop?.offers.first { $0.def.kind == kind })
        try Shop.buy(&run, slot: offer.slot)
        return run
    }

    private func purchaseVisit(in run: RunState, kind: ItemKind) -> Int? {
        switch kind {
        case .bookmark: return run.bookmarks.first?.boughtInShopVisitID
        case .buff: return run.buffs.first?.boughtInShopVisitID
        case .marker, .subscription: return nil
        }
    }
}
