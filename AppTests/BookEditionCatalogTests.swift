import XCTest
import Foundation
import ProbablySudokuEngine
@testable import ProbablySudoku

final class BookEditionCatalogTests: XCTestCase {
    func testShelfContainsTwelveDistinctPlayableRulesInVolumeOrder() {
        let shelf = BookEdition.shelf

        XCTAssertEqual(shelf.count, 12)
        XCTAssertEqual(shelf.map(\.rule.volume), Array(1...12))
        XCTAssertEqual(Set(shelf.map(\.id)).count, 12)
        XCTAssertEqual(Set(shelf.map(\.rule.rawValue)).count, 12,
                       "A new cover must not alias another book's gameplay rule")
        XCTAssertEqual(Set(shelf.map(\.rule.rawValue)), Set(Book.allCases.map(\.rawValue)))
        XCTAssertEqual(Set(shelf.map { normalized($0.title) }).count, 12)
    }

    func testEveryBookHasItsOwnBenefitAndPrintedBenefitDescription() {
        let benefits = BookEdition.shelf.map(\.benefit)

        XCTAssertEqual(Set(benefits).count, 12,
                       "Every rack slot must offer a distinct book benefit")
        XCTAssertEqual(Set(benefits.map(\.title)).count, 12)
        XCTAssertEqual(Set(benefits.map(\.detail)).count, 12)
        for benefit in benefits {
            XCTAssertFalse(benefit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(benefit.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testAllTwelveEditionsAreWrittenUnlockedAndNotPlaceholderCovers() {
        for edition in BookEdition.shelf {
            XCTAssertTrue(edition.isWritten, "\(edition.id) still has an unwritten cover")
            XCTAssertTrue(edition.isUnlocked, "\(edition.id) must be playable without earlier completions")
            XCTAssertFalse(edition.design.isBare, "\(edition.id) still uses the placeholder design")
            XCTAssertFalse(edition.id.hasPrefix("future-"))
            for text in [edition.title, edition.blurb, edition.shelfLabel] {
                let normalizedText = normalized(text)
                XCTAssertFalse(normalizedText.isEmpty)
                XCTAssertFalse(normalizedText.contains("notwrittenyet"))
                XCTAssertFalse(normalizedText.contains("comingsoon"))
                XCTAssertFalse(normalizedText.contains("placeholder"))
            }
        }
    }

    func testPrintedCoverTitleAndVolumeMatchTheEditionCatalog() {
        for edition in BookEdition.shelf {
            let design = edition.design
            let printedTitle = (design.titleLines + [design.flourish]).joined(separator: " ")
            XCTAssertEqual(normalized(printedTitle), normalized(edition.title),
                           "\(edition.id)'s cover must print its own title, not a reused design's title")
            XCTAssertEqual(edition.shelfLabel, "Volume \(edition.rule.volume)")
            XCTAssertEqual(design.volume, edition.shelfLabel)
        }
    }

    func testEveryNewEditionHasNonemptyMarginalia() {
        let newEditions = BookEdition.shelf.filter { $0.rule.volume > 4 }
        XCTAssertEqual(newEditions.count, 8)
        for edition in newEditions {
            XCTAssertFalse(edition.marginalia.isEmpty, "\(edition.id) needs its own in-game voice")
            XCTAssertTrue(edition.marginalia.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }, "\(edition.id) has blank lines in its gameplay margins")
        }
    }

    func testFirstFourPersistedBookAndEditionIdentitiesArePreserved() throws {
        let existingRules: [Book] = [.probably, .slightlyHarder, .noPressure, .bites]
        let rawIDs = ["probably", "slightlyHarder", "noPressure", "bites"]
        let editionIDs = ["probably", "sorry", "pressure", "bites"]

        XCTAssertEqual(existingRules.map(\.rawValue), rawIDs)
        XCTAssertEqual(Array(BookEdition.shelf.prefix(4)).map(\.id), editionIDs)
        for (index, rawID) in rawIDs.enumerated() {
            let decoded = try JSONDecoder().decode(Book.self, from: Data("\"\(rawID)\"".utf8))
            XCTAssertEqual(decoded, existingRules[index])
            XCTAssertEqual(BookEdition.edition(for: decoded).id, editionIDs[index])
        }
    }

    func testEveryEngineBookLooksUpItsExactEditionInsteadOfFallingBackToVolumeOne() throws {
        for book in Book.allCases {
            let expected = try XCTUnwrap(BookEdition.shelf.first { $0.rule == book })
            let actual = BookEdition.edition(for: book)
            XCTAssertEqual(actual.id, expected.id)
            XCTAssertEqual(actual.rule, book)
            XCTAssertEqual(actual.rule.volume, book.volume)
        }
    }

    private func normalized(_ text: String) -> String {
        // Curly apostrophes, punctuation and authored cover line breaks are
        // typographic differences, not permission to print another title.
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
