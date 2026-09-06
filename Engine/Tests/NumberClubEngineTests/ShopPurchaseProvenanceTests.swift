import Foundation
import XCTest
@testable import ProbablySudokuEngine

final class ShopPurchaseProvenanceTests: XCTestCase {
    func testBookmarkAndBuffPurchasesPersistTheCurrentShopVisit() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        try game.buy(slot: 1)

        let saved = try savedObject(game)
        let shop = try XCTUnwrap(saved["shop"] as? [String: Any])
        let visit = try XCTUnwrap(shop["visitID"] as? Int)
        let bookmarks = try XCTUnwrap(saved["bookmarks"] as? [[String: Any]])
        let buffs = try XCTUnwrap(saved["buffs"] as? [[String: Any]])
        XCTAssertEqual(bookmarks.first?["boughtInShopVisitID"] as? Int, visit)
        XCTAssertEqual(buffs.first?["boughtInShopVisitID"] as? Int, visit)
        XCTAssertEqual(game.run.coins, 91)
    }

    func testRerollPreservesPurchaseShopIdentity() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        let before = try savedObject(game)
        let originalVisit = try XCTUnwrap((before["shop"] as? [String: Any])?["visitID"] as? Int)

        try game.reroll()

        let after = try savedObject(game)
        XCTAssertEqual((after["shop"] as? [String: Any])?["visitID"] as? Int, originalVisit)
        XCTAssertEqual((after["bookmarks"] as? [[String: Any]])?.first?["boughtInShopVisitID"] as? Int,
                       originalVisit)
        XCTAssertEqual(game.shop?.rerollsUsed, 1)
    }

    func testLaterShopWithinTheSameLevelHasADifferentVisit() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        let before = try savedObject(game)
        let purchaseVisit = try XCTUnwrap((before["shop"] as? [String: Any])?["visitID"] as? Int)

        XCTAssertTrue(game.advance())
        game.openShop()

        XCTAssertEqual(game.run.level, 1)
        XCTAssertEqual(game.run.slot, .medium)
        XCTAssertEqual(game.run.bookmarks.first?.boughtAtLevel, 1,
                       "The old level-only achievement check cannot distinguish these Shops")
        let after = try savedObject(game)
        let currentVisit = try XCTUnwrap((after["shop"] as? [String: Any])?["visitID"] as? Int)
        XCTAssertNotEqual(currentVisit, purchaseVisit)
        XCTAssertEqual((after["bookmarks"] as? [[String: Any]])?.first?["boughtInShopVisitID"] as? Int,
                       purchaseVisit)
    }

    func testNewStockOpeningIsDistinctEvenWithoutAdvancingThePuzzleSlot() throws {
        var game = stockedGame()
        let firstVisit = try XCTUnwrap(game.shop?.visitID)
        game.openShop()
        XCTAssertEqual(game.run.level, 1)
        XCTAssertEqual(game.run.slot, .easy)
        XCTAssertEqual(game.shop?.visitID, firstVisit + 1)
    }

    func testResumeThenRerollRetainsBothItemsOriginsAndRefundsWithoutExtraRandomness() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        try game.buy(slot: 1)
        var restored = try Game(decoding: game.encoded())
        XCTAssertEqual(try savedObject(restored) as NSDictionary, try savedObject(game) as NSDictionary)
        let visit = try XCTUnwrap(restored.shop?.visitID)
        try restored.reroll()
        XCTAssertEqual(restored.shop?.visitID, visit)
        XCTAssertEqual(restored.run.bookmarks.first?.boughtInShopVisitID, visit)
        XCTAssertEqual(restored.run.buffs.first?.boughtInShopVisitID, visit)

        let streams = try encoded(restored.run.streams)
        let coins = restored.run.coins
        XCTAssertEqual(try restored.sell(kind: .bookmark, index: 0), 2)
        XCTAssertEqual(try restored.sell(kind: .buff, index: 0), 2)
        XCTAssertEqual(restored.run.coins, coins + 4)
        XCTAssertTrue(restored.run.bookmarks.isEmpty)
        XCTAssertTrue(restored.run.buffs.isEmpty)
        XCTAssertEqual(try encoded(restored.run.streams), streams)
        XCTAssertEqual(restored.shop?.visitID, visit)
        XCTAssertThrowsError(try restored.sell(kind: .buff, index: 0)) {
            XCTAssertEqual($0 as? Shop.ShopError, .nothingToSell)
        }
        XCTAssertEqual(restored.run.coins, coins + 4)
    }

    func testMidPuzzleSalesRemainAllowedButThereIsNoCurrentShop() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        try game.buy(slot: 1)
        let purchaseVisit = try XCTUnwrap(game.shop?.visitID)
        XCTAssertTrue(game.advance())
        try game.startPuzzle()
        XCTAssertNil(game.shop)
        XCTAssertEqual(game.run.bookmarks.first?.boughtInShopVisitID, purchaseVisit)
        XCTAssertEqual(game.run.buffs.first?.boughtInShopVisitID, purchaseVisit)
        let board = try encoded(try XCTUnwrap(game.puzzle?.board))
        let streams = try encoded(game.run.streams)
        let coins = game.run.coins

        XCTAssertEqual(try game.sell(kind: .bookmark, index: 0), 2)
        XCTAssertEqual(try game.sell(kind: .buff, index: 0), 2)

        XCTAssertEqual(game.run.coins, coins + 4)
        XCTAssertEqual(try encoded(try XCTUnwrap(game.puzzle?.board)), board)
        XCTAssertEqual(try encoded(game.run.streams), streams)
    }

    func testLegacySaveLoadsWithoutAttributingOldItemsToItsOpenShop() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        try game.buy(slot: 1)
        let legacy = removingProvenance(try savedObject(game))
        let restored = try Game(decoding: JSONSerialization.data(withJSONObject: legacy))

        XCTAssertNil(restored.shop?.visitID)
        XCTAssertNil(restored.run.bookmarks.first?.boughtInShopVisitID)
        XCTAssertNil(restored.run.buffs.first?.boughtInShopVisitID)
        XCTAssertEqual(restored.run.shopVisitCount, 0)
        XCTAssertEqual(removingProvenance(try savedObject(restored)) as NSDictionary, legacy as NSDictionary,
                       "Migration must preserve stock, ownership, prices, coins, and every RNG stream")
    }

    func testOnlyNewPurchasesAcquireProvenanceInALegacyShop() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        let legacy = removingProvenance(try savedObject(game))
        var restored = try Game(decoding: JSONSerialization.data(withJSONObject: legacy))
        let streams = try encoded(restored.run.streams)

        try restored.buy(slot: 1)

        let visit = try XCTUnwrap(restored.shop?.visitID)
        XCTAssertGreaterThan(visit, 0)
        XCTAssertNil(restored.run.bookmarks.first?.boughtInShopVisitID)
        XCTAssertEqual(restored.run.buffs.first?.boughtInShopVisitID, visit)
        XCTAssertEqual(try encoded(restored.run.streams), streams,
                       "Establishing a visit must not roll anything")
        try restored.reroll()
        XCTAssertEqual(restored.shop?.visitID, visit)
        XCTAssertNil(restored.run.bookmarks.first?.boughtInShopVisitID)
    }

    func testFailedPurchaseCannotAssignLegacyProvenanceOrMutateState() throws {
        let legacy = removingProvenance(try savedObject(stockedGame()))
        var game = try Game(decoding: JSONSerialization.data(withJSONObject: legacy))
        game.run.coins = 0
        let before = try game.encoded()
        XCTAssertThrowsError(try game.buy(slot: 0)) {
            XCTAssertEqual($0 as? Shop.ShopError, .notEnoughCoins)
        }
        XCTAssertEqual(try game.encoded(), before)

        game.run.coins = 100
        game.run.buffs = Array(repeating: OwnedBuff(defID: Buffs.peek, pricePaid: 4),
                              count: ItemKind.buff.capacity)
        let full = try game.encoded()
        XCTAssertThrowsError(try game.buy(slot: 1)) {
            XCTAssertEqual($0 as? Shop.ShopError, .slotsFull)
        }
        XCTAssertEqual(try game.encoded(), full)
    }

    func testMissingCounterCannotReuseKnownItemOrCurrentShopIdentity() throws {
        var game = stockedGame()
        try game.buy(slot: 0)
        game.openShop()
        let secondVisit = try XCTUnwrap(game.shop?.visitID)
        var partial = try savedObject(game)
        partial.removeValue(forKey: "shopVisitCount")
        var restored = try Game(decoding: JSONSerialization.data(withJSONObject: partial))
        restored.openShop()
        XCTAssertGreaterThan(try XCTUnwrap(restored.shop?.visitID), secondVisit)

        partial.removeValue(forKey: "shop")
        restored = try Game(decoding: JSONSerialization.data(withJSONObject: partial))
        restored.openShop()
        XCTAssertGreaterThan(try XCTUnwrap(restored.shop?.visitID),
                             try XCTUnwrap(restored.run.bookmarks.first?.boughtInShopVisitID))
    }

    func testNewVisitDoesNotAlterStockOrAnyRandomStream() throws {
        var original = RunState(seed: "SHOP-PROVENANCE-RNG")
        var identified = original
        let expectedStock = Shop.stock(&original)

        Shop.open(&identified)

        XCTAssertEqual(try encoded(identified.shop?.offers), try encoded(expectedStock.offers))
        XCTAssertEqual(try encoded(identified.streams), try encoded(original.streams))
        XCTAssertEqual(identified.coins, original.coins)
    }

    func testLegacyOwnedItemInitializersAndJSONRemainReadableWithUnknownOrigin() throws {
        let bookmark = try JSONDecoder().decode(OwnedBookmark.self,
            from: Data(#"{"defID":"bm_help_wanted","boughtAtLevel":2,"pricePaid":5}"#.utf8))
        let buff = try JSONDecoder().decode(OwnedBuff.self,
            from: Data(#"{"defID":"bf_peek","pricePaid":4}"#.utf8))
        XCTAssertNil(bookmark.boughtInShopVisitID)
        XCTAssertNil(buff.boughtInShopVisitID)
        XCTAssertEqual(bookmark.boughtAtLevel, 2)
        XCTAssertEqual(bookmark.pricePaid, 5)
        XCTAssertEqual(buff.pricePaid, 4)
        XCTAssertNil(OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 2,
                                   pricePaid: 5).boughtInShopVisitID)
        XCTAssertNil(OwnedBuff(defID: Buffs.peek, pricePaid: 4).boughtInShopVisitID)
    }

    private func stockedGame() -> Game {
        var game = Game(seed: "SHOP-PROVENANCE")
        game.run.coins = 100
        game.openShop()
        game.run.shop?.offers = [
            ShopOffer(slot: 0, defID: Bookmarks.helpWanted, price: 5),
            ShopOffer(slot: 1, defID: Buffs.peek, price: 4)
        ]
        return game
    }

    private func savedObject(_ game: Game) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
    }

    private func removingProvenance(_ object: [String: Any]) -> [String: Any] {
        var legacy = object
        legacy.removeValue(forKey: "shopVisitCount")
        if var shop = legacy["shop"] as? [String: Any] {
            shop.removeValue(forKey: "visitID")
            legacy["shop"] = shop
        }
        for key in ["bookmarks", "buffs"] {
            legacy[key] = (legacy[key] as? [[String: Any]])?.map { item in
                var legacyItem = item
                legacyItem.removeValue(forKey: "boughtInShopVisitID")
                return legacyItem
            }
        }
        return legacy
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
