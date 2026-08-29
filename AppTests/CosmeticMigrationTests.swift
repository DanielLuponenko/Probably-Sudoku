import XCTest
@testable import ProbablySudoku

final class CosmeticMigrationTests: XCTestCase {
    func testLegacyFiveSlotProfileKeepsActiveLoadout() throws {
        let json = """
        {
          "cosmeticCurrency": 73,
          "ownedCosmeticIDs": [
            "dk_ebony", "pc_blue", "pp_ivory", "bd_laser", "nb_flame"
          ],
          "equipped": {
            "deskID": "dk_ebony",
            "paperID": "pp_ivory",
            "boardID": "bd_laser",
            "numberID": "nb_flame",
            "markerID": "pc_blue"
          }
        }
        """

        let profile = try JSONDecoder().decode(PlayerProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.cosmeticCurrency, 73)
        XCTAssertEqual(profile.equipped.paperID, "pp_ivory")
        XCTAssertEqual(profile.equipped.boardID, "bd_laser")
        XCTAssertEqual(profile.equipped.numberID, "nb_flame")
    }

    func testThreeSlotProfileAndMissingSlotsDecodeSafely() throws {
        let current = """
        {"paperID":"pp_white","boardID":"bd_gilt","numberID":"nb_laser"}
        """
        let decoded = try JSONDecoder().decode(EquippedCosmetics.self, from: Data(current.utf8))
        XCTAssertEqual(decoded, EquippedCosmetics(paperID: "pp_white", boardID: "bd_gilt",
                                                   numberID: "nb_laser"))

        let partial = try JSONDecoder().decode(EquippedCosmetics.self,
                                               from: Data("{\"paperID\":\"pp_graph\"}".utf8))
        XCTAssertEqual(partial.paperID, "pp_graph")
        XCTAssertEqual(partial.boardID, EquippedCosmetics.starting.boardID)
        XCTAssertEqual(partial.numberID, EquippedCosmetics.starting.numberID)
    }

    func testEncodingKeepsLegacyEnvelopeAtFixedDefaults() throws {
        let encoded = try JSONEncoder().encode(EquippedCosmetics.starting)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["paperID", "boardID", "numberID", "deskID", "markerID"])
        XCTAssertEqual(object["deskID"] as? String, "dk_walnut")
        XCTAssertEqual(object["markerID"] as? String, "pc_graphite")
    }

    func testCatalogHasOnlyThreeActiveCategoriesAndRichNumberSet() {
        XCTAssertEqual(Set(CosmeticCatalog.items.map(\.category)),
                       Set([CosmeticCategory.paper, .board, .numbers]))
        XCTAssertFalse(CosmeticCatalog.items.contains { $0.id.hasPrefix("dk_") || $0.id.hasPrefix("pc_") })

        let numbers = CosmeticCatalog.items(in: .numbers)
        XCTAssertGreaterThanOrEqual(numbers.count, 7)
        XCTAssertNotNil(numbers.first { $0.id == "nb_laser" })
        XCTAssertNotNil(numbers.first { $0.id == "nb_flame" })
    }
}
