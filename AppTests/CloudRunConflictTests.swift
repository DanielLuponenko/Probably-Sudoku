import Foundation
import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// The production comparison only, with synthetic in-memory saves. Never read
/// the local run, cloud account, or choose/publish either side of a conflict.
final class CloudRunConflictTests: XCTestCase {
    func testEveryUnorderedCollectionCanSerializeInAnotherOrderWithoutAConflict() throws {
        let local = try fixture()
        let original = try object(local)
        let originalBytes = try json(original)
        for path in unorderedPaths {
            var remoteObject = original
            let values = try XCTUnwrap(value(at: path, in: original) as? [Any])
            XCTAssertGreaterThan(values.count, 1, path.joined(separator: "."))
            let reordered: [Any]
            if path.last == "fouled" {
                // Codable's non-string-key Dictionary is [key, value, ...].
                // Reverse whole pairs, not their key/value relationship.
                reordered = stride(from: 0, to: values.count, by: 2).reversed().flatMap {
                    [values[$0], values[$0 + 1]]
                }
            } else {
                reordered = Array(values.reversed())
            }
            try set(reordered, at: path, in: &remoteObject)
            let remoteBytes = try json(remoteObject)
            XCTAssertNotEqual(remoteBytes, originalBytes)
            let remote = try Game(decoding: remoteBytes)

            XCTAssertNil(RunStore.conflict(local: local, remote: remote), path.joined(separator: "."))
            XCTAssertNil(RunStore.conflict(local: remote, remote: local), "Comparison is symmetric")
        }
    }

    func testChangedSetMembershipOrFoulExpiryStillProducesAConflict() throws {
        let local = try fixture()
        let changes: [(String, (inout RunState) -> Void)] = [
            ("clueReveals", { _ = $0.puzzle?.clueReveals.insert(Square(80)) }),
            ("obstacleBlockedDigits", { _ = $0.puzzle?.obstacleBlockedDigits.insert(.nine) }),
            ("armedFlags", { _ = $0.puzzle?.armedFlags.insert(.litmus) }),
            ("blockedDigits", { _ = $0.puzzle?.bossTurn?.blockedDigits.insert(.nine) }),
            ("blockedHandIndices", { _ = $0.puzzle?.bossTurn?.blockedHandIndices.insert(5) }),
            ("greyed", { _ = $0.puzzle?.bossTurn?.greyed.insert(Square(80)) }),
            ("fouled membership", { $0.puzzle?.bossTurn?.fouled[Square(80)] = 7 }),
            ("fouled expiry", { $0.puzzle?.bossTurn?.fouled[Square(6)] = 9 })
        ]
        for (name, change) in changes {
            var run = local.run
            change(&run)
            XCTAssertNotNil(RunStore.conflict(local: local, remote: Game(run: run)), name)
        }
    }

    func testRewardTurnBookScoreAndPurchaseFactsRemainGenuineConflicts() throws {
        let local = try fixture()
        let changes: [([String], Any)] = [
            (["seed"], "ANOTHER-BOOK-ATTEMPT"),
            (["book"], Book.probably.rawValue),
            (["obstacle"], Obstacle.shortHanded.rawValue),
            (["level"], 2),
            (["coins"], local.run.coins + 1),
            (["shopVisitCount"], 10),
            (["puzzle", "rewardedRescueUsed"], true),
            (["puzzle", "turnNumber"], 2),
            (["puzzle", "turnsMax"], 13),
            (["puzzle", "score"], 999_999),
            (["puzzle", "pendingBase"], 42),
            (["puzzle", "clockSecondsRemaining"], 123.5),
            (["puzzle", "itemState", "a"], 9),
            (["runItemState", "a"], 9)
        ]
        for (path, changedValue) in changes {
            var state = try object(local)
            try set(changedValue, at: path, in: &state)
            let remote = try Game(decoding: json(state))
            let conflict = try XCTUnwrap(RunStore.conflict(local: local, remote: remote),
                                        path.joined(separator: "."))
            XCTAssertEqual(conflict.local.run.seed, local.run.seed)
            XCTAssertEqual(conflict.remote.run.seed, remote.run.seed)
            XCTAssertEqual(conflict.local.puzzle?.rewardedRescueUsed, local.puzzle?.rewardedRescueUsed)
            XCTAssertEqual(conflict.remote.puzzle?.rewardedRescueUsed, remote.puzzle?.rewardedRescueUsed)
            XCTAssertEqual(conflict.local.puzzle?.score, local.puzzle?.score)
            XCTAssertEqual(conflict.remote.puzzle?.score, remote.puzzle?.score)
        }
        var changed = local.run
        changed.bookmarks[0] = OwnedBookmark(defID: changed.bookmarks[0].defID,
                                             boughtAtLevel: 1, pricePaid: 5, boughtInShopVisitID: 7)
        XCTAssertNotNil(RunStore.conflict(local: local, remote: Game(run: changed)))
        changed = local.run
        changed.buffs.removeLast()
        XCTAssertNotNil(RunStore.conflict(local: local, remote: Game(run: changed)))
    }

    func testOrderedHandBoardPoolAndInventoryPermutationsAreNotNormalizedAway() throws {
        let local = try fixture()
        for path in [
            ["puzzle", "hand"], ["puzzle", "pool", "counts"],
            ["puzzle", "board", "solution"], ["puzzle", "board", "isGiven"],
            ["puzzle", "board", "placed"], ["puzzle", "board", "filledBy"],
            ["bookmarks"], ["buffs"], ["markers"], ["subscriptions"]
        ] {
            var state = try object(local)
            let values = try XCTUnwrap(value(at: path, in: state) as? [Any])
            try set(swappingDistinctValues(values), at: path, in: &state)
            let remote = try Game(decoding: json(state))
            XCTAssertNotNil(RunStore.conflict(local: local, remote: remote), path.joined(separator: "."))
        }
        var run = local.run
        run.markers[0].squares.reverse()
        XCTAssertNotNil(RunStore.conflict(local: local, remote: Game(run: run)))
    }

    func testShopOfferOrderAndSaleStatusRemainGenuineConflicts() throws {
        var run = RunState(seed: "CLOUD-SHOP-ORDER")
        Shop.open(&run)
        let local = Game(run: run)
        run.shop?.offers.reverse()
        XCTAssertNotNil(RunStore.conflict(local: local, remote: Game(run: run)))
        run = local.run
        run.shop?.offers[0].sold = true
        XCTAssertNotNil(RunStore.conflict(local: local, remote: Game(run: run)))
        XCTAssertNil(RunStore.conflict(local: local, remote: try Game(decoding: local.encoded())))
    }

    func testEveryIndependentRandomStreamStillParticipatesInEquality() throws {
        let local = try fixture()
        for stream in ["board", "pool", "shop", "boss"] {
            var state = try object(local)
            let path = ["streams", stream, "state"]
            let old = try XCTUnwrap(value(at: path, in: state) as? NSNumber)
            try set(old.uint32Value &+ 1, at: path, in: &state)
            XCTAssertNotNil(RunStore.conflict(local: local, remote: try Game(decoding: json(state))), stream)
        }
    }

    func testComparisonDoesNotMutateInputsOrSilentlyResolveAnEncodingFailure() throws {
        let local = try fixture()
        let remote = try Game(decoding: local.encoded())
        XCTAssertNil(RunStore.conflict(local: local, remote: remote))
        XCTAssertEqual(local.puzzle?.clueReveals.count, 3)
        XCTAssertEqual(remote.puzzle?.bossTurn?.fouled.count, 3)
        XCTAssertEqual(local.puzzle?.armedFlags.count, 3)
        XCTAssertEqual(remote.puzzle?.hand, local.puzzle?.hand)

        var run = local.run
        run.puzzle?.pendingMult = .nan
        let unencodable = Game(run: run)
        XCTAssertNotNil(RunStore.conflict(local: unencodable, remote: unencodable))
    }

    private let unorderedPaths = [
        ["puzzle", "clueReveals"], ["puzzle", "obstacleBlockedDigits"], ["puzzle", "armedFlags"],
        ["puzzle", "bossTurn", "blockedDigits"], ["puzzle", "bossTurn", "blockedHandIndices"],
        ["puzzle", "bossTurn", "greyed"], ["puzzle", "bossTurn", "fouled"]
    ]

    private func fixture() throws -> Game {
        var game = Game(seed: "CLOUD-UNORDERED-COLLECTIONS", book: .smallVictories)
        try game.startPuzzle()
        var run = game.run
        run.puzzle?.hand = [.one, .two, .three, .four, .five, .six]
        run.puzzle?.clueReveals = [Square(0), Square(10), Square(20)]
        run.puzzle?.obstacleBlockedDigits = [.one, .four, .seven]
        run.puzzle?.armedFlags = [.insurance, .doubleDown, .secondPrint]
        run.puzzle?.itemState = ["b": 2, "a": 1]
        run.runItemState = ["b": 2, "a": 1]
        var boss = BossTurnState()
        boss.blockedDigits = [.two, .five, .eight]
        boss.blockedHandIndices = [0, 2, 4]
        boss.greyed = [Square(3), Square(14), Square(25)]
        boss.fouled = [Square(6): 4, Square(17): 5, Square(28): 6]
        run.puzzle?.bossTurn = boss
        run.bookmarks = [
            OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 5),
            OwnedBookmark(defID: Bookmarks.marketWrap, boughtAtLevel: 1, pricePaid: 6)
        ]
        run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 4), OwnedBuff(defID: Buffs.redraw, pricePaid: 3)]
        run.markers = [OwnedMarker(defID: "mk_azure", boughtAtLevel: 1, pricePaid: 5,
                                   squares: [Square(2), Square(13)]),
                       OwnedMarker(defID: "mk_copper", boughtAtLevel: 1, pricePaid: 6)]
        run.subscriptions = [OwnedSubscription(defID: Subscriptions.homeDelivery, pricePaid: 12),
                             OwnedSubscription(defID: Subscriptions.wireService, pricePaid: 14)]
        return Game(run: run)
    }

    private func swappingDistinctValues(_ values: [Any]) throws -> [Any] {
        let first = try XCTUnwrap(values.first)
        let firstBytes = try json(first)
        let other = try XCTUnwrap(values.indices.dropFirst().first { try json(values[$0]) != firstBytes })
        var swapped = values
        swapped.swapAt(0, other)
        return swapped
    }

    private func object(_ game: Game) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
    }

    private func json(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    }

    private func value(at path: [String], in object: [String: Any]) -> Any? {
        path.reduce(object as Any?) { current, key in (current as? [String: Any])?[key] }
    }

    private func set(_ value: Any, at path: [String], in object: inout [String: Any]) throws {
        let key = try XCTUnwrap(path.first)
        if path.count == 1 {
            object[key] = value
        } else {
            var child = try XCTUnwrap(object[key] as? [String: Any])
            try set(value, at: Array(path.dropFirst()), in: &child)
            object[key] = child
        }
    }
}
