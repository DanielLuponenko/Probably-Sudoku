import XCTest
@testable import ProbablySudokuEngine

final class CatalogueMetadataTests: XCTestCase {
    func testPlayerDescriptionsDoNotExposeImplementationInstructions() {
        // Full effects are read aloud in the inventory and skip offer, even
        // where the visible card uses the shorter summary. Check both sources
        // so importing or regenerating catalogue copy cannot reintroduce notes
        // intended for developers into either presentation.
        let implementationLanguage = #"(?i)\b(engine|hook|atomic|seeded|canonical|UUID)\b|effectiveHandSize|claim record|normal proposed|normal guards|preserve current|preserve existing|legal token transfer|score-zeroing|boss-zeroed|local multipliers|locked loadout|locked slot|orthogonally|wrong-placement routing|ordinary correctness|held Turn Mult|nonzeroed|stored solution"#
        for source in CatalogueDetails.all {
            for text in [source.effect, source.shortEffect] {
                XCTAssertNil(text.range(of: implementationLanguage, options: .regularExpression),
                             "\(source.code) exposes implementation language: \(text)")
            }
        }
    }

    func testAll140RuntimeDefinitionsMatchTheBundledApprovedCatalogue() throws {
        let runtime = Bookmarks.all + Markers.all + Buffs.all
        XCTAssertEqual(runtime.count, 140)
        XCTAssertEqual(CatalogueDetails.all.count, 140)
        XCTAssertEqual(Set(runtime.map(\.id)), Set(CatalogueDetails.all.map(\.id)))
        for definition in runtime {
            let source = try XCTUnwrap(CatalogueDetails.item(definition.id), definition.id)
            XCTAssertEqual(definition.name, source.name, source.code)
            XCTAssertEqual(definition.kind.rawValue, source.category.lowercased(), source.code)
            XCTAssertEqual(definition.rarity.rawValue, source.rarity.lowercased(), source.code)
            XCTAssertEqual(definition.listedPrice, source.price, source.code)
            XCTAssertEqual(definition.text, source.effect, source.code)
        }
    }
}
