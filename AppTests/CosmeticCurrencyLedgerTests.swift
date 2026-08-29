import XCTest
@testable import ProbablySudoku

/// Merge tests branch two copies from one ancestor before diverging, matching
/// two devices that play offline and later exchange their profiles.
final class CosmeticCurrencyLedgerTests: XCTestCase {
    private let paidItem = CosmeticCatalog.item("pp_white")!
    private let otherPaidItem = CosmeticCatalog.item("pp_ivory")!

    func testConcurrentDistinctEarnsBothCount() {
        let ancestor = PlayerProfile()
        var local = ancestor
        local.rewardedCompletionIDs.insert("book:a")
        local.earnedRewardAmounts["book:a"] = 60
        var remote = ancestor
        remote.rewardedCompletionIDs.insert("book:b")
        remote.earnedRewardAmounts["book:b"] = 25

        local.merge(remote: remote)

        XCTAssertEqual(local.cosmeticCurrency, 85)
        XCTAssertEqual(local.earnedRewardAmounts, ["book:a": 60, "book:b": 25])
    }

    func testConcurrentDistinctPurchasesBothDeduct() {
        var ancestor = PlayerProfile()
        ancestor.earnedRewardAmounts["seed"] = 200
        var local = ancestor
        local.ownedCosmeticIDs.insert(paidItem.id)
        local.purchaseAmounts[paidItem.id] = paidItem.price
        var remote = ancestor
        remote.ownedCosmeticIDs.insert(otherPaidItem.id)
        remote.purchaseAmounts[otherPaidItem.id] = otherPaidItem.price

        local.merge(remote: remote)

        XCTAssertTrue(local.ownedCosmeticIDs.isSuperset(of: [paidItem.id, otherPaidItem.id]))
        XCTAssertEqual(local.cosmeticCurrency, 200 - paidItem.price - otherPaidItem.price)
    }

    func testConcurrentSameItemChargedOnce() {
        var ancestor = PlayerProfile()
        ancestor.earnedRewardAmounts["seed"] = 200
        var local = ancestor
        local.ownedCosmeticIDs.insert(paidItem.id)
        local.purchaseAmounts[paidItem.id] = paidItem.price
        var remote = ancestor
        remote.ownedCosmeticIDs.insert(paidItem.id)
        remote.purchaseAmounts[paidItem.id] = paidItem.price

        local.merge(remote: remote)

        XCTAssertEqual(local.purchaseAmounts[paidItem.id], paidItem.price)
        XCTAssertEqual(local.cosmeticCurrency, 200 - paidItem.price)
    }

    func testLegacyPaidOwnershipPreservesExactBalance() throws {
        let json = """
        {
          "cosmeticCurrency": 73,
          "ownedCosmeticIDs": ["pp_white"],
          "rewardedCompletionIDs": ["book:seed-1"]
        }
        """
        let profile = try JSONDecoder().decode(PlayerProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.cosmeticCurrency, 73)
        XCTAssertEqual(profile.purchaseAmounts[paidItem.id], paidItem.price)
        XCTAssertEqual(profile.legacyEarnedAnchor, 73 + paidItem.price)
        XCTAssertEqual(profile.legacyEarnedAnchorCoverage, ["book:seed-1"])
    }

    func testStalePrePurchaseSnapshotDoesNotRefundOnMerge() throws {
        let beforeJSON = """
        {"cosmeticCurrency": 100, "ownedCosmeticIDs": [], "rewardedCompletionIDs": ["book:seed-1"]}
        """
        let afterJSON = """
        {"cosmeticCurrency": 65, "ownedCosmeticIDs": ["pp_white"], "rewardedCompletionIDs": ["book:seed-1"]}
        """
        var stale = try JSONDecoder().decode(PlayerProfile.self, from: Data(beforeJSON.utf8))
        let current = try JSONDecoder().decode(PlayerProfile.self, from: Data(afterJSON.utf8))

        stale.merge(remote: current)

        XCTAssertEqual(stale.cosmeticCurrency, 65)
        XCTAssertTrue(stale.ownedCosmeticIDs.contains("pp_white"))
    }

    func testOwnershipGrantPostMigrationDoesNotCharge() throws {
        let json = """
        {"cosmeticCurrency": 50, "ownedCosmeticIDs": [], "rewardedCompletionIDs": []}
        """
        var profile = try JSONDecoder().decode(PlayerProfile.self, from: Data(json.utf8))
        profile.ownedCosmeticIDs.insert(paidItem.id)

        XCTAssertEqual(profile.cosmeticCurrency, 50)
        XCTAssertNil(profile.purchaseAmounts[paidItem.id])
    }

    func testStoredPurchaseAmountDrivesDeductionNotCatalogPrice() {
        var profile = PlayerProfile()
        profile.earnedRewardAmounts["seed"] = 200
        profile.ownedCosmeticIDs.insert(paidItem.id)
        profile.purchaseAmounts[paidItem.id] = 9

        XCTAssertNotEqual(paidItem.price, 9)
        XCTAssertEqual(profile.cosmeticCurrency, 191)
    }

    func testMergeIsIdempotent() {
        var ancestor = PlayerProfile()
        ancestor.earnedRewardAmounts["seed"] = 100
        var local = ancestor
        local.rewardedCompletionIDs.insert("book:a")
        local.earnedRewardAmounts["book:a"] = 60
        var remote = ancestor
        remote.ownedCosmeticIDs.insert(paidItem.id)
        remote.purchaseAmounts[paidItem.id] = paidItem.price

        local.merge(remote: remote)
        let onceMerged = local
        local.merge(remote: remote)

        XCTAssertEqual(local, onceMerged)
    }

    func testMergeIsCommutative() {
        var ancestor = PlayerProfile()
        ancestor.earnedRewardAmounts["seed"] = 100
        var branchA = ancestor
        branchA.rewardedCompletionIDs.insert("book:a")
        branchA.earnedRewardAmounts["book:a"] = 60
        branchA.ownedCosmeticIDs.insert(paidItem.id)
        branchA.purchaseAmounts[paidItem.id] = paidItem.price
        var branchB = ancestor
        branchB.rewardedCompletionIDs.insert("book:b")
        branchB.earnedRewardAmounts["book:b"] = 25

        var aThenB = branchA
        aThenB.merge(remote: branchB)
        var bThenA = branchB
        bThenA.merge(remote: branchA)

        XCTAssertEqual(aThenB.cosmeticCurrency, bThenA.cosmeticCurrency)
        XCTAssertEqual(aThenB.earnedRewardAmounts, bThenA.earnedRewardAmounts)
        XCTAssertEqual(aThenB.legacyEarnedAnchor, bThenA.legacyEarnedAnchor)
        XCTAssertEqual(aThenB.legacyEarnedAnchorCoverage, bThenA.legacyEarnedAnchorCoverage)
    }

    func testOldBuildRewriteWithKnownAndNewRewardDoesNotDoubleCount() throws {
        var local = PlayerProfile()
        local.rewardedCompletionIDs.insert("book:a")
        local.earnedRewardAmounts["book:a"] = 60
        let json = """
        {"cosmeticCurrency": 85, "ownedCosmeticIDs": [], "rewardedCompletionIDs": ["book:a", "book:b"]}
        """
        let remote = try JSONDecoder().decode(PlayerProfile.self, from: Data(json.utf8))

        local.merge(remote: remote)

        XCTAssertEqual(local.cosmeticCurrency, 85)
        XCTAssertEqual(local.rewardedCompletionIDs, ["book:a", "book:b"])
    }

    @MainActor
    func testLedgerKeyMissingFromCompatibilitySetCannotBeEarnedTwice() throws {
        let json = """
        {"earnedRewardAmounts": {"book:x": 30}, "rewardedCompletionIDs": []}
        """
        let profile = try JSONDecoder().decode(PlayerProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.rewardedCompletionIDs, ["book:x"])

        let store = PlayerProfileStore(profile: profile)
        let balanceBefore = store.currency
        let earned = store.earn(
            CosmeticRewardEvent(id: "book:x", amount: 30, reason: .bookCompleted)
        )

        XCTAssertFalse(earned)
        XCTAssertEqual(store.currency, balanceBefore)
    }

    #if DEBUG
    @MainActor
    func testDebugGrantOverridesVisibleBalanceWithoutEncodingIt() throws {
        var seed = PlayerProfile()
        seed.earnedRewardAmounts["seed"] = 5
        let store = PlayerProfileStore(profile: seed)
        store.debugApplyCurrencyGrant(9_999)

        try store.purchase(paidItem)

        XCTAssertTrue(store.owns(paidItem))
        XCTAssertEqual(store.currency, 9_999 - paidItem.price)
        XCTAssertNil(store.profile.purchaseAmounts[paidItem.id])
        XCTAssertEqual(store.profile.lastModifiedAt, .distantPast)
        let encoded = try JSONEncoder().encode(store.profile)
        let decoded = try JSONDecoder().decode(PlayerProfile.self, from: encoded)
        XCTAssertEqual(decoded.cosmeticCurrency, 5)
    }
    #endif
}
