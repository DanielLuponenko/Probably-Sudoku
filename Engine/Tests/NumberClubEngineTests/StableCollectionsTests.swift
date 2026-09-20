import XCTest
@testable import ProbablySudokuEngine

final class StableCollectionsTests: XCTestCase {
    private struct Values: Codable, Equatable {
        @StableMap var copies: [UUID: Int] = [:]
        @StableSet var ids: Set<UUID> = []
        @StableMap var squares: [Square: Bool] = [:]
        @StableSetMap var turns: [Int: Set<Int>] = [:]
        @StableOptionalMap var snapshot: [UUID: Int]? = nil
    }

    private struct Legacy: Codable {
        var copies: [UUID: Int]
        var ids: Set<UUID>
        var squares: [Square: Bool]
        var turns: [Int: Set<Int>]
        var snapshot: [UUID: Int]?
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    func testCanonicalMapsAndSetsIgnoreInsertionAndDecodeHashOrder() throws {
        let ids = (0..<24).map { SkipOffer.stableIdentity(seed: "canonical", domain: "copy.\($0)") }
        var a = Values(), b = Values()
        for index in ids.indices {
            a.copies[ids[index]] = index; a.ids.insert(ids[index])
            a.squares[Square(index)] = index.isMultiple(of: 2)
            a.turns[index] = [1, 3, 12, 2]
        }
        for index in ids.indices.reversed() {
            b.copies[ids[index]] = index; b.ids.insert(ids[index])
            b.squares[Square(index)] = index.isMultiple(of: 2)
            b.turns[index] = [2, 12, 3, 1]
        }
        a.snapshot = a.copies; b.snapshot = b.copies
        let canonical = try encoded(a)
        XCTAssertEqual(a, b)
        XCTAssertEqual(canonical, try encoded(b))
        for _ in 0..<10 {
            a = try JSONDecoder().decode(Values.self, from: canonical)
            XCTAssertEqual(try encoded(a), canonical)
        }
    }

    func testLegacyAlternatingUUIDArraysAndIntegerObjectMapsRemainReadable() throws {
        let id = UUID()
        let legacy = Legacy(copies: [id: 8], ids: [id], squares: [Square(80): true],
            turns: [3: [1, 2, 4]], snapshot: [id: 9])
        let decoded = try JSONDecoder().decode(Values.self, from: encoded(legacy))
        XCTAssertEqual(decoded.copies, legacy.copies)
        XCTAssertEqual(decoded.ids, legacy.ids)
        XCTAssertEqual(decoded.squares, legacy.squares)
        XCTAssertEqual(decoded.turns, legacy.turns)
        XCTAssertEqual(decoded.snapshot, legacy.snapshot)
        XCTAssertEqual(try encoded(JSONDecoder().decode(Values.self, from: encoded(decoded))), try encoded(decoded))
        XCTAssertEqual(try JSONDecoder().decode(Values.self, from: Data("{}".utf8)), Values())
        XCTAssertThrowsError(try JSONDecoder().decode(Values.self, from: Data("{\"copies\":[\"\(id.uuidString)\"]}".utf8)))
    }

    func testFullBookmarkFactsAndLockedCopiesRoundTripCanonically() throws {
        struct Facts: Codable {
            var run = BookmarkRunState()
            var puzzle = BookmarkPuzzleState()
            var scoring = TurnScoringState(bookmarks: [], disabledBookmarkID: nil,
                runState: [:], observedItemState: [:])
        }
        var facts = Facts()
        let ids = (0..<12).map { SkipOffer.stableIdentity(seed: "facts", domain: "copy.\($0)") }
        facts.run.shop = BookmarkShopState(visitID: 7, ownedOnEntry: Set(ids))
        for (index, id) in ids.enumerated() {
            facts.run.copies[id, default: .init()].numberIndexMult = index
            facts.puzzle.copies[id, default: .init()].personalTriggers = index
            facts.puzzle.turn.copies[id, default: .init()].carbonPoints = index * 10
            facts.puzzle.suspended.insert(id)
            facts.puzzle.boxTurns[index] = [1, 3, 5, 8]
            facts.puzzle.clearedIssueBoxes.insert(index)
            facts.run.shop?.buybackUsed.insert(id)
            facts.run.shop?.recycledChoices[id] = [Buffs.peek, Buffs.redraw]
            facts.run.shop?.recycledEligible.insert(id)
            facts.run.shop?.recycledClaimed.insert(id)
            facts.run.shop?.recycledDismissed.insert(id)
        }
        facts.scoring.bookmarkCopies = facts.run.copies
        let canonical = try encoded(facts)
        for _ in 0..<10 {
            facts = try JSONDecoder().decode(Facts.self, from: canonical)
            XCTAssertEqual(try encoded(facts), canonical)
        }
        XCTAssertEqual(facts.scoring.bookmarkCopies, facts.run.copies)
    }
}
