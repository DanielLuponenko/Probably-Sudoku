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
