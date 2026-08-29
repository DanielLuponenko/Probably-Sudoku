import XCTest
@testable import ProbablySudoku

final class CosmeticSyncTests: XCTestCase {
    private let combo = EquippedCosmetics(
        paperID: "pp_ivory", boardID: "bd_laser", numberID: "nb_flame"
    )
    private let comboOwned: Set<String> = ["pp_ivory", "bd_laser", "nb_flame"]

    func testDecisionClockRoundTripAndLegacyDefault() throws {
        var profile = PlayerProfile()
        profile.ownedCosmeticIDs.formUnion(comboOwned)
        profile.equipped = combo
        profile.equippedDecisionAt = Date(timeIntervalSince1970: 2_000)
        let roundTrip = try JSONDecoder().decode(
            PlayerProfile.self,
            from: JSONEncoder().encode(profile)
        )
        XCTAssertEqual(roundTrip.equipped, combo)
        XCTAssertEqual(roundTrip.equippedDecisionAt, profile.equippedDecisionAt)

        let legacy = """
        {
          "ownedCosmeticIDs": ["pp_ivory", "bd_laser", "nb_flame"],
          "equipped": {"paperID": "pp_ivory", "boardID": "bd_laser", "numberID": "nb_flame"}
        }
        """
        let decoded = try JSONDecoder().decode(PlayerProfile.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.equippedDecisionAt, .distantPast)
        XCTAssertEqual(decoded.equipped, combo)
    }

    func testNewerLegacyLoadoutStillMigratesBeforeAnyV2Decision() {
        var local = PlayerProfile()
        var remote = PlayerProfile()
        remote.ownedCosmeticIDs.formUnion(comboOwned)
        remote.equipped = combo
        remote.lastModifiedAt = Date(timeIntervalSince1970: 500)

        local.merge(remote: remote)

        XCTAssertEqual(local.equipped, combo)
        XCTAssertEqual(local.equippedDecisionAt, .distantPast)
    }

    func testOldProfileCannotOverrideEstablishedV2Decision() {
        var local = PlayerProfile()
        local.ownedCosmeticIDs.formUnion(comboOwned)
        local.equipped = combo
        local.equippedDecisionAt = Date(timeIntervalSince1970: 1_000)

        var oldBuildRepublish = PlayerProfile()
        oldBuildRepublish.equipped = .starting
        oldBuildRepublish.lastModifiedAt = Date(timeIntervalSince1970: 9_999)
        local.merge(remote: oldBuildRepublish)

        XCTAssertEqual(local.equipped, combo)
        XCTAssertEqual(local.equippedDecisionAt, Date(timeIntervalSince1970: 1_000))
    }

    @MainActor
    func testUnrelatedSaveDoesNotAdvanceDecisionClock() {
        var seed = PlayerProfile()
        seed.ownedCosmeticIDs.formUnion(comboOwned)
        seed.equipped = combo
        seed.equippedDecisionAt = Date(timeIntervalSince1970: 1_000)
        seed.lastModifiedAt = Date(timeIntervalSince1970: 1_000)
        let store = PlayerProfileStore(profile: seed)

        store.earn(CosmeticRewardEvent(id: "sync-test", amount: 5, reason: .bookCompleted))

        XCTAssertEqual(store.profile.equippedDecisionAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertGreaterThan(store.profile.lastModifiedAt, Date(timeIntervalSince1970: 1_000))
    }

    @MainActor
    func testRemoteV2AcceptsNewerAndRejectsStaleDecision() {
        var seed = PlayerProfile()
        seed.ownedCosmeticIDs.formUnion(comboOwned)
        seed.equippedDecisionAt = Date(timeIntervalSince1970: 1_000)
        let store = PlayerProfileStore(profile: seed)

        store.applyRemoteEquipped(combo, decisionAt: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(store.profile.equipped, combo)
        XCTAssertEqual(store.profile.equippedDecisionAt, Date(timeIntervalSince1970: 2_000))

        store.applyRemoteEquipped(.starting, decisionAt: Date(timeIntervalSince1970: 1_500))
        XCTAssertEqual(store.profile.equipped, combo)
        XCTAssertEqual(store.profile.equippedDecisionAt, Date(timeIntervalSince1970: 2_000))
    }

    @MainActor
    func testRemoteV2RetriesAfterOwnershipArrives() {
        let decisionAt = Date(timeIntervalSince1970: 3_000)
        let store = PlayerProfileStore(profile: PlayerProfile())

        store.applyRemoteEquipped(combo, decisionAt: decisionAt)
        XCTAssertEqual(store.profile.equipped, .starting)
        XCTAssertEqual(store.profile.equippedDecisionAt, .distantPast)

        var ownership = PlayerProfile()
        ownership.ownedCosmeticIDs.formUnion(comboOwned)
        store.merge(remote: ownership)
        store.applyRemoteEquipped(combo, decisionAt: decisionAt)

        XCTAssertEqual(store.profile.equipped, combo)
        XCTAssertEqual(store.profile.equippedDecisionAt, decisionAt)
    }

    #if DEBUG
    @MainActor
    func testEquipUnderDebugOverrideUpdatesInMemoryOnlyAndNeverPublishes() {
        var seed = PlayerProfile()
        seed.ownedCosmeticIDs.formUnion(comboOwned)
        let store = PlayerProfileStore(profile: seed)
        store.debugApplyCurrencyGrant(0)
        var publishedCount = 0
        store.debugPublishEquippedHook = { _, _ in publishedCount += 1 }

        store.equip(CosmeticCatalog.item("pp_ivory")!)

        XCTAssertEqual(store.profile.equipped.paperID, "pp_ivory")
        XCTAssertNotEqual(store.profile.equippedDecisionAt, .distantPast)
        XCTAssertEqual(publishedCount, 0)
        XCTAssertEqual(store.profile.lastModifiedAt, .distantPast)
    }
    #endif
}
