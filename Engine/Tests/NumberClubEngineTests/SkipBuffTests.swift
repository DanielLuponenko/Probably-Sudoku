import Foundation
import XCTest
@testable import ProbablySudokuEngine

final class SkipBuffTests: XCTestCase {
    func testEveryOrdinaryPuzzleAcrossEveryChapterCanBeSkippedWithBossesMandatory() throws {
        var game = Game(seed: "all-eighteen-skips")
        for level in 1...9 {
            XCTAssertEqual(game.run.level, level)
            for slot in [PuzzleSlot.easy, .medium] {
                XCTAssertEqual(game.run.slot, slot)
                let offer = try XCTUnwrap(game.run.currentSkipOffer)
                let oldCount = game.run.buffs.count
                let replacement = oldCount == 2 ? game.run.buffs[0].id : nil
                let streams = try encoded(game.run.streams)
                let coins = game.run.coins
                let record = try game.skipPuzzle(ifCurrent: offer, replacingBuffID: replacement)
                XCTAssertEqual(record.offer, offer)
                XCTAssertEqual(record.replacedBuffID, replacement)
                XCTAssertEqual(game.run.buffs.last?.defID, offer.buffID)
                XCTAssertEqual(game.run.buffs.last?.id, record.rewardID)
                XCTAssertEqual(game.run.buffs.count, min(oldCount + 1, 2))
                XCTAssertEqual(game.run.level, level)
                XCTAssertEqual(game.run.slot, slot == .easy ? .medium : .boss)
                XCTAssertEqual(game.run.coins, coins)
                XCTAssertEqual(try encoded(game.run.streams), streams)
                XCTAssertFalse(game.run.runItemState.keys.contains { $0.hasPrefix("clipping.") })
                game = try Game(decoding: game.encoded())
            }
            XCTAssertNil(game.run.currentSkipOffer)
            let last = try XCTUnwrap(game.run.skipHistory.last)
            let before = try game.encoded()
            XCTAssertThrowsError(try game.skipPuzzle(ifCurrent: last.offer)) {
                XCTAssertEqual($0 as? SkipError, .cannotSkip)
            }
            XCTAssertEqual(try game.encoded(), before)
            try game.startPuzzle()
            XCTAssertNotNil(game.puzzle?.boss)
            // Mandatory bosses use their real completion objective. A forged
            // won phase cannot stand in for Split's ledgers or Last's bank.
            game.qaMeetTarget()
            if game.puzzle?.boss == .reviewBoard { game.qaFillBoard() }
            _ = try game.cashOut()
            if level < 9 {
                game.openShop()
                XCTAssertTrue(game.advance())
            }
        }
        XCTAssertEqual(game.run.skipsUsed, 18)
        XCTAssertEqual(game.run.skipHistory.count, 18)
        XCTAssertEqual(Set(game.run.skipHistory.map(\.rewardID)).count, 18)
        XCTAssertEqual(game.run.outcome, .bookCompleted)
    }

    func testOfferReadsResumeAndShopNavigationDoNotChangeOfferOrAnyGameplayStream() throws {
        var game = Game(seed: "stable-skip-offers")
        let first = try XCTUnwrap(game.run.currentSkipOffer)
        let before = try game.encoded()
        for _ in 0..<100 { XCTAssertEqual(game.run.currentSkipOffer, first) }
        XCTAssertEqual(try game.encoded(), before)
        XCTAssertEqual(try Game(decoding: before).run.currentSkipOffer, first)

        try game.startPuzzle()
        try finishAndOpenShop(&game)
        XCTAssertNil(game.run.currentSkipOffer)
        var resumedShop = try Game(decoding: game.encoded())
        _ = game.advance()
        _ = resumedShop.advance()
        let next = try XCTUnwrap(game.run.currentSkipOffer)
        XCTAssertEqual(next, resumedShop.run.currentSkipOffer)
        var position = RunState(seed: game.run.seed)
        position.slot = .medium
        XCTAssertEqual(next, position.currentSkipOffer)
        let streams = try encoded(game.run.streams)
        for _ in 0..<100 { _ = game.run.currentSkipOffer }
        XCTAssertEqual(try encoded(game.run.streams), streams)
    }

    func testFullInventoryRequiresExplicitReplacementAndFailureChangesNothing() throws {
        var game = Game(seed: "full-skip")
        game.run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 3),
                          OwnedBuff(defID: Buffs.peek, pricePaid: 4)]
        let offer = try XCTUnwrap(game.run.currentSkipOffer)
        let before = try game.encoded()
        XCTAssertThrowsError(try game.skipPuzzle(ifCurrent: offer)) {
            XCTAssertEqual($0 as? SkipError, .inventoryFull)
        }
        XCTAssertEqual(try game.encoded(), before)
        XCTAssertThrowsError(try game.skipPuzzle(ifCurrent: offer, replacingBuffID: UUID())) {
            XCTAssertEqual($0 as? SkipError, .invalidReplacement)
        }
        XCTAssertEqual(try game.encoded(), before)

        // Cancellation leaves this unchanged state intact, including the offer.
        let kept = game.run.buffs[0].id
        let replaced = game.run.buffs[1].id
        let record = try game.skipPuzzle(ifCurrent: offer, replacingBuffID: replaced)
        XCTAssertEqual(game.run.buffs.map(\.id), [kept, offer.id])
        XCTAssertEqual(game.run.buffs[0].pricePaid, 3)
        XCTAssertEqual(record.replacedBuffID, replaced)
        XCTAssertEqual(record.buffID, offer.buffID)
        let restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.run.buffs.map(\.id), [kept, offer.id])
        XCTAssertEqual(restored.run.skipHistory, [record])
    }

    func testReplacementIsRejectedWithAnAvailableSlot() throws {
        var game = Game(seed: "available-slot")
        game.run.buffs = [OwnedBuff(defID: Buffs.redraw, pricePaid: 3)]
        let offer = try XCTUnwrap(game.run.currentSkipOffer)
        let before = try game.encoded()
        XCTAssertThrowsError(try game.skipPuzzle(ifCurrent: offer, replacingBuffID: game.run.buffs[0].id)) {
            XCTAssertEqual($0 as? SkipError, .invalidReplacement)
        }
        XCTAssertEqual(try game.encoded(), before)
        _ = try game.skipPuzzle(ifCurrent: offer)
        XCTAssertEqual(game.run.buffs.count, 2)
    }

    func testDuplicateClaimsAndStaleOffersNeverAdvanceOrGrantAgain() throws {
        var game = Game(seed: "exactly-once")
        let first = try XCTUnwrap(game.run.currentSkipOffer)
        _ = try game.skipPuzzle(ifCurrent: first)
        let after = try game.encoded()
        for _ in 0..<10 {
            XCTAssertThrowsError(try game.skipPuzzle(ifCurrent: first)) {
                XCTAssertEqual($0 as? SkipError, .staleOffer)
            }
            XCTAssertEqual(try game.encoded(), after)
        }
        game = try Game(decoding: after)
        XCTAssertThrowsError(try game.skipPuzzle(ifCurrent: first))
        XCTAssertEqual(try game.encoded(), after)
        XCTAssertEqual(game.run.skipsUsed, 1)
        XCTAssertEqual(game.run.slot, .medium)
        let current = try XCTUnwrap(game.run.currentSkipOffer)
        var otherRun = Game(seed: "different-run")
        otherRun.run.slot = .medium
        XCTAssertThrowsError(try otherRun.skipPuzzle(ifCurrent: current)) {
            XCTAssertEqual($0 as? SkipError, .staleOffer)
        }
    }

    func testDuplicateRewardDefinitionsRetainDifferentInstanceIdentities() throws {
        let seed = try XCTUnwrap((0..<1000).map { "duplicate-skip-\($0)" }.first {
            SkipOffer.offer(seed: $0, level: 1, slot: .easy, version: 2).buffID
                == SkipOffer.offer(seed: $0, level: 1, slot: .medium, version: 2).buffID
        })
        var game = Game(seed: seed)
        _ = try game.skipPuzzle(ifCurrent: XCTUnwrap(game.run.currentSkipOffer))
        _ = try game.skipPuzzle(ifCurrent: XCTUnwrap(game.run.currentSkipOffer))
        XCTAssertEqual(game.run.buffs[0].defID, game.run.buffs[1].defID)
        XCTAssertNotEqual(game.run.buffs[0].id, game.run.buffs[1].id)
        let restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.run.buffs.map(\.id), game.run.buffs.map(\.id))
    }

    func testLegacySaveKeepsClippingsAndGetsNoRetroactiveBuffsOrAllowanceLimit() throws {
        var game = Game(seed: "historical-skip-save")
        game.run.level = 2
        game.run.runItemState["clipping.taken.1.\(PuzzleSlot.easy.rawValue)"] = 1
        game.run.runItemState["clipping.taken.1.\(PuzzleSlot.medium.rawValue)"] = 1
        game.run.runItemState["clipping.circulation"] = 5
        game.run.runItemState["clipping.overprint"] = 1
        game.run.coins += 8
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        object.removeValue(forKey: "skipHistory")
        object["buffs"] = [["defID": Buffs.peek, "pricePaid": 3],
                           ["defID": Buffs.peek, "pricePaid": 4]]
        var restored = try Game(decoding: JSONSerialization.data(withJSONObject: object))
        let secondDecode = try Game(decoding: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(try restored.encoded(), try secondDecode.encoded(),
                       "Loading one historical save twice must not create a save conflict")
        XCTAssertTrue(restored.run.skipHistory.isEmpty)
        XCTAssertEqual(restored.run.skipsUsed, 2)
        XCTAssertEqual(restored.run.buffs.count, 2)
        XCTAssertNotEqual(restored.run.buffs[0].id, restored.run.buffs[1].id)
        XCTAssertEqual(restored.run.takenClippings, game.run.takenClippings)
        XCTAssertEqual(restored.run.coins, game.run.coins)
        XCTAssertEqual(restored.run.interestCap, game.run.interestCap)
        let ids = restored.run.buffs.map(\.id)
        restored = try Game(decoding: restored.encoded())
        XCTAssertEqual(restored.run.buffs.map(\.id), ids)
        let offer = try XCTUnwrap(restored.run.currentSkipOffer)
        let state = restored.run.runItemState
        _ = try restored.skipPuzzle(ifCurrent: offer, replacingBuffID: restored.run.buffs[0].id)
        XCTAssertEqual(restored.run.skipsUsed, 3)
        XCTAssertEqual(restored.run.skipHistory.count, 1)
        XCTAssertEqual(restored.run.runItemState, state)
        try restored.startPuzzle()
        XCTAssertEqual(restored.puzzle?.pendingMult, 2)
        XCTAssertNil(restored.run.runItemState["clipping.overprint"])
        XCTAssertEqual(restored.run.runItemState["clipping.circulation"], 5)
    }

    func testActivePuzzleShopAndFinishedRunsRejectClaimsWithoutMutation() throws {
        let base = Game(seed: "invalid-phase")
        let offer = try XCTUnwrap(base.run.currentSkipOffer)
        var active = base
        try active.startPuzzle()
        var shopping = base
        try finishAndOpenShop(&shopping)
        var finished = base
        finished.run.outcome = .failed
        for var game in [active, shopping, finished] {
            let before = try game.encoded()
            XCTAssertNil(game.run.currentSkipOffer)
            XCTAssertThrowsError(try game.skipPuzzle(ifCurrent: offer))
            XCTAssertEqual(try game.encoded(), before)
        }
    }

    func testOfferRewardTableCoversCatalogueAndRemainsIndependentOfLiveStreams() throws {
        var offered = Set<String>()
        for value in 0..<1000 {
            var game = Game(seed: "reward-table-\(value)")
            let offer = try XCTUnwrap(game.run.currentSkipOffer)
            offered.insert(offer.buffID)
            XCTAssertEqual(offer.buff.kind, .buff)
            XCTAssertFalse(offer.buff.text.isEmpty)
            var expected = game
            _ = expected.run.advance()
            _ = try game.skipPuzzle(ifCurrent: offer)
            XCTAssertEqual(try encoded(game.run.streams), try encoded(expected.run.streams))
        }
        XCTAssertEqual(offered, Set(Buffs.all.map(\.id)))
    }

    func testPurchasedBuffIdentitiesRemainDeterministicAndDistinctThroughRerollsAndVisits() throws {
        func exercise() throws -> Game {
            var game = Game(seed: "deterministic-purchase-identity")
            game.run.coins = 100
            try finishAndOpenShop(&game)
            game.run.shop!.offers = [ShopOffer(slot: 4, defID: Buffs.peek, price: 3)]
            let initialStreams = try encoded(game.run.streams)
            try game.buy(slot: 4)
            XCTAssertEqual(try encoded(game.run.streams), initialStreams)
            let first = game.run.buffs[0].id
            try game.reroll()
            game.run.shop!.offers = [ShopOffer(slot: 4, defID: Buffs.peek, price: 3)]
            try game.buy(slot: 4)
            let second = game.run.buffs[1].id
            XCTAssertNotEqual(first, second)
            game = try Game(decoding: game.encoded())
            XCTAssertEqual(game.run.buffs.map(\.id), [first, second])
            _ = try game.sell(kind: .buff, index: 0)
            _ = game.advance()
            try finishAndOpenShop(&game)
            game.run.shop!.offers = [ShopOffer(slot: 4, defID: Buffs.peek, price: 3)]
            try game.buy(slot: 4)
            XCTAssertEqual(Set([first, second, game.run.buffs[1].id]).count, 3)
            return game
        }
        XCTAssertEqual(try exercise().encoded(), try exercise().encoded())
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func finishAndOpenShop(_ game: inout Game) throws {
        if game.puzzle == nil { try game.startPuzzle() }
        game.run.puzzle!.score = game.run.puzzle!.target
        game.run.puzzle!.phase = .won
        _ = try game.cashOut()
        game.openShop()
        XCTAssertNotNil(game.shop)
        XCTAssertNil(game.puzzle)
    }
}
