import Foundation
import XCTest
@testable import ProbablySudokuEngine

final class BossModifierTests: XCTestCase {

    private var run: RunState { RunState(seed: "boss") }

    func testEveryModifierHasNameTextAndTarget() {
        for boss in BossModifier.allCases {
            XCTAssertFalse(boss.name.isEmpty)
            XCTAssertFalse(boss.text.isEmpty)
            XCTAssertFalse(boss.attacks.isEmpty)
        }
        XCTAssertEqual(BossModifier.allCases.count, 19)
    }

    func testBossBriefingCommitsTheSameBossThatPuzzleStarts() throws {
        var game = Game(seed: "boss-briefing")
        let announcedAtStart = try XCTUnwrap(game.run.pendingBoss)
        XCTAssertTrue(game.advance())
        XCTAssertTrue(game.advance())

        let announced = try XCTUnwrap(game.run.pendingBoss)
        XCTAssertEqual(announced, announcedAtStart)
        XCTAssertEqual(game.run.slot, .boss)

        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.boss, announced)
        XCTAssertNil(game.run.pendingBoss)
    }

    func testTheEditorShrinksTheHand() {
        XCTAssertEqual(run.effectiveHandSize(boss: nil), 7)          // Book 1 benefit
        XCTAssertEqual(run.effectiveHandSize(boss: .editor), 6)
    }

    func testTheDeadlineCutsTurnsAndLateCityFinalStillAddsOne() {
        var r = run
        XCTAssertEqual(r.effectiveTurns(boss: nil), 10)
        XCTAssertEqual(r.effectiveTurns(boss: .deadline), 8)
        r.bookmarks.append(OwnedBookmark(defID: Bookmarks.lateCityFinal, boughtAtLevel: 1, pricePaid: 7))
        XCTAssertEqual(r.effectiveTurns(boss: .deadline), 9)
    }

    func testTheErratumRemovesTheTossAllowanceEntirely() {
        var r = run
        XCTAssertEqual(r.effectiveTossAllowance(boss: nil), 4)
        r.bookmarks.append(OwnedBookmark(defID: Bookmarks.weatherForecast, boughtAtLevel: 1, pricePaid: 4))
        XCTAssertEqual(r.effectiveTossAllowance(boss: nil), 6)
        XCTAssertEqual(r.effectiveTossAllowance(boss: .erratum), 0)
    }

    func testThePaywallDisablesCluesIncludingBuffGranted() throws {
        var r = RunState(seed: "boss", book: .noPressure)
        XCTAssertEqual(r.effectiveClues(boss: nil), 1)
        XCTAssertEqual(r.effectiveClues(boss: .paywall), 0)

        // Peek's free Clue is blocked too.
        r.slot = .boss
        var game = Game(run: r)
        try game.startPuzzle()
        game.run.puzzle?.boss = .paywall
        game.run.puzzle?.cluesRemaining = 0
        game.give(buff: Buffs.peek)
        XCTAssertThrowsError(try game.useBuff(at: 0)) {
            XCTAssertEqual($0 as? PlacementError, .cluesDisabled)
        }
        XCTAssertEqual(game.puzzle?.cluesRemaining, 0)
        XCTAssertEqual(game.run.buffs.map(\.defID), [Buffs.peek])
    }

    func testTheCriticDoublesTheWrongPlacementPenalty() throws {
        var game = Game(seed: "critic")
        try game.startPuzzle()
        game.run.puzzle?.boss = .critic
        // Bank enough that the doubled penalty is visible above the floor at 0.
        game.give(ad: "bm_stop_the_presses")
        game.give(ad: "bm_editorial_board")
        _ = try game.place(handIndex: game.stackHand(with: .nine)!, at: game.blank(wanting: .nine)!)
        _ = try game.endTurn()
        let before = game.puzzle!.score
        XCTAssertEqual(before, 810)

        let square = game.blank(wanting: .one)!
        let wrong: Digit = game.puzzle!.board.correctDigit(at: square) == .four ? .five : .four
        let outcome = try game.place(handIndex: game.stackHand(with: wrong)!, at: square)
        XCTAssertEqual(outcome.penalty, 50 * wrong.rawValue * 2)
        XCTAssertEqual(game.puzzle?.score, before - outcome.penalty)
    }

    func testTheMirrorZeroesLineClearsButNotTheFullClear() throws {
        var game = Game(seed: "mirror")
        try game.startPuzzle()
        game.run.puzzle?.boss = .mirror
        let last = try game.setUpRowClear(row: game.emptiestRow)!
        let digit = game.puzzle!.board.correctDigit(at: last)
        let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: last)

        XCTAssertEqual(outcome.lineClearPoints.first, 0)
        XCTAssertEqual(outcome.points, 10 * digit.rawValue, "the placement itself is untouched")
    }

    func testTheCensorZeroesOneNumber() throws {
        var game = Game(seed: "censor")
        try game.startPuzzle()
        game.run.puzzle?.boss = .censor
        game.run.puzzle?.censoredDigit = .seven

        let censored = try game.place(handIndex: game.stackHand(with: .seven)!,
                                      at: game.blank(wanting: .seven)!)
        XCTAssertEqual(censored.points, 0)
        XCTAssertTrue(censored.censored)

        let untouched = try game.place(handIndex: game.stackHand(with: .six)!,
                                       at: game.blank(wanting: .six)!)
        XCTAssertEqual(untouched.points, 60)
    }

    func testTheCollectorRemovesInterestFromThePayout() throws {
        var run = RunState(seed: "collector")
        run.coins = 100
        var puzzle = try PuzzleState.create(run: &run)
        puzzle.boss = nil
        XCTAssertEqual(run.payout(for: puzzle).interest, 10)
        puzzle.boss = .collector
        XCTAssertEqual(run.payout(for: puzzle).interest, 0)
    }

    func testTheFogOnlyHidesMarks() {
        // The Marker still fires; the player just cannot see where it is.
        XCTAssertTrue(BossModifier.fog.hidesMarkedSquares)
        XCTAssertEqual(BossModifier.fog.handSizeDelta, 0)
        XCTAssertNil(BossModifier.fog.turnsOverride)
    }

    func testHeavyLifterQuadruplesTheTargetInTheQAPath() throws {
        var game = Game(seed: "heavy")
        try game.startPuzzle()
        let baseTarget = game.puzzle!.target

        #if DEBUG
        game.qaSetBoss(.heavyLifter)
        XCTAssertEqual(game.puzzle?.target, baseTarget * 4)
        #endif
    }

    func testBuffborgerAndAccountantApplyTheirResourcePressure() throws {
        var game = Game(seed: "resources")
        try game.startPuzzle()
        game.give(buff: Buffs.peek)
        game.run.puzzle?.boss = .buffborger
        XCTAssertThrowsError(try game.useBuff(at: 0)) {
            XCTAssertEqual($0 as? PlacementError, .buffsDisabled)
        }
        XCTAssertEqual(game.run.buffs.count, 1, "a blocked Buff stays held")

        game.run.puzzle?.boss = .accountant
        let coinsBefore = game.run.coins
        let square = game.blank(wanting: .five)!
        _ = try game.place(handIndex: game.stackHand(with: .five)!, at: square)
        XCTAssertEqual(game.run.coins, coinsBefore - 1)
    }

    func testSashimiHalvesTheWholeScoreMultiplier() throws {
        var game = Game(seed: "sashimi")
        try game.startPuzzle()
        game.give(ad: "bm_op_ed") // normal x2
        game.run.puzzle?.boss = .sashimi

        let outcome = try game.place(handIndex: game.stackHand(with: .five)!,
                                     at: game.blank(wanting: .five)!)
        XCTAssertEqual(outcome.points, 50, "Sashimi takes the normal x2 back to x1")
    }

    func testHandyDandyBarsTwoHeldDigitsAndTheGrayBossesBarTheirUnits() throws {
        var handy = Game(seed: "handy")
        try handy.startPuzzle()
        handy.run.puzzle?.boss = .handyDandy
        var handyPuzzle = handy.run.puzzle!
        handyPuzzle.startBossTurn(&handy.run)
        handy.run.puzzle = handyPuzzle
        XCTAssertEqual(handy.puzzle?.bossTurn?.blockedHandIndices.count, min(2, handy.puzzle!.hand.count))
        XCTAssertTrue(handy.puzzle!.bossTurn!.blockedHandIndices.allSatisfy { handy.puzzle!.hand.indices.contains($0) })

        // Duplicate digits are separate cards. Handy Dandy must still bar two
        // positions, never every copy of a selected digit.
        handyPuzzle = handy.puzzle!
        handyPuzzle.hand = [.six, .six, .two, .three]
        handyPuzzle.startBossTurn(&handy.run)
        XCTAssertEqual(handyPuzzle.bossTurn?.blockedHandIndices.count, 2)
        XCTAssertEqual((0..<handyPuzzle.hand.count).filter(handyPuzzle.isBlocked(handIndex:)).count, 2)
        handy.run.puzzle = handyPuzzle
        let barredCard = try XCTUnwrap(handyPuzzle.bossTurn?.blockedHandIndices.first)
        XCTAssertThrowsError(try handy.toss(handIndex: barredCard)) {
            XCTAssertEqual($0 as? PlacementError, .numberBlocked)
        }

        for boss in [BossModifier.grayTheGarry, .garryTheGray] {
            var game = Game(seed: boss.rawValue)
            try game.startPuzzle()
            game.run.puzzle?.boss = boss
            var puzzle = game.run.puzzle!
            puzzle.startBossTurn(&game.run)
            game.run.puzzle = puzzle
            let barred = try XCTUnwrap(game.puzzle?.barredSquares.first)
            XCTAssertThrowsError(try game.place(handIndex: 0, at: barred)) {
                XCTAssertEqual($0 as? PlacementError, .squareBarred)
            }
            if boss == .grayTheGarry {
                XCTAssertEqual(Set(game.puzzle!.barredSquares.map(\.row)).count, 1)
            } else {
                XCTAssertEqual(Set(game.puzzle!.barredSquares.map(\.box)).count, 1)
            }
        }
    }

    func testHandyDandyRebasesBlockedCardsAfterPlacement() throws {
        for correctPlacement in [true, false] {
            var game = Game(seed: "handy-rebase-\(correctPlacement)")
            try game.startPuzzle()

            var puzzle = try XCTUnwrap(game.puzzle)
            puzzle.boss = .handyDandy
            var bossTurn = BossTurnState()
            bossTurn.blockedHandIndices = [2, 5]
            puzzle.bossTurn = bossTurn
            game.run.puzzle = puzzle

            let playedIndex = 0
            let playedDigit = puzzle.hand[playedIndex]
            let target = try XCTUnwrap(puzzle.board.blanks.first { square in
                (puzzle.board.correctDigit(at: square) == playedDigit) == correctPlacement
            })
            let blockedCardsBefore = bossTurn.blockedHandIndices.sorted().map { puzzle.hand[$0] }

            _ = try game.place(handIndex: playedIndex, at: target)

            let rebasedIndices = try XCTUnwrap(game.puzzle?.bossTurn?.blockedHandIndices)
            XCTAssertEqual(rebasedIndices, [1, 4], "correct placement: \(correctPlacement)")
            XCTAssertEqual(rebasedIndices.sorted().map { game.puzzle!.hand[$0] },
                           blockedCardsBefore,
                           "Handy Dandy must keep blocking the same remaining cards")
        }
    }

    func testOverPusherExpiresFoulsAndUnluckyLuckySleepsABookmark() throws {
        var pusher = Game(seed: "push")
        try pusher.startPuzzle()
        pusher.run.puzzle?.boss = .overPusher
        var puzzle = pusher.run.puzzle!
        let filledSquare = try XCTUnwrap(Geometry.rows.flatMap { $0 }
            .first { !puzzle.board.isBlank($0) })
        var previousTurn = BossTurnState()
        previousTurn.fouled = [filledSquare: puzzle.turnNumber]
        puzzle.bossTurn = previousTurn
        puzzle.startBossTurn(&pusher.run)
        XCTAssertFalse(puzzle.barredSquares.contains(filledSquare))
        XCTAssertFalse(puzzle.barredSquares.isEmpty)

        var unlucky = Game(seed: "unlucky")
        try unlucky.startPuzzle()
        unlucky.give(ad: "bm_local_gossip")
        unlucky.run.puzzle?.boss = .unluckyLucky
        var sleepingTurn = BossTurnState()
        sleepingTurn.disabledBookmark = 0
        unlucky.run.puzzle?.bossTurn = sleepingTurn
        let outcome = try unlucky.place(handIndex: unlucky.stackHand(with: .five)!,
                                        at: unlucky.blank(wanting: .five)!)
        XCTAssertEqual(outcome.points, 50, "the sleeping Bookmark cannot contribute its +30")
    }

    func testTikTakDefinesTheClockAndExpiryFailsEvenWhileKeepingFilling() throws {
        XCTAssertEqual(BossModifier.tikTak.secondsAllowed, 180)
        var game = Game(seed: "clock")
        try game.startPuzzle()
        game.run.puzzle?.phase = .keepFilling
        game.failPuzzle()
        XCTAssertEqual(game.puzzle?.phase, .failed)
        XCTAssertEqual(game.run.outcome, .failed)
    }

    #if DEBUG
    func testQASelectorsMakeAnyLoadoutAndBossRepeatable() throws {
        var game = Game(seed: "qa-selectors")
        try game.startPuzzle()

        game.qaSetBoss(.editor)
        XCTAssertEqual(game.puzzle?.handSize, 6)

        game.qaSetBoss(.overPusher)
        XCTAssertFalse(game.puzzle!.barredSquares.isEmpty)
        game.qaSetBoss(.grayTheGarry)
        XCTAssertTrue(game.puzzle!.bossTurn!.fouled.isEmpty,
                      "a new QA Boss starts without the old Boss's fouls")
        game.qaSetBoss(.editor)

        game.qaSetBookmark(Bookmarks.helpWanted)
        game.qaSetMarker("mk_silver", at: Square(row: 4, col: 4))
        game.qaSetBuff(Buffs.peek)

        XCTAssertEqual(game.run.bookmarks.map(\.defID), [Bookmarks.helpWanted])
        XCTAssertEqual(game.run.markers.first?.defID, "mk_silver")
        XCTAssertEqual(game.run.markers.first?.squares, [Square(row: 4, col: 4)])
        XCTAssertEqual(game.run.buffs.map(\.defID), [Buffs.peek])
        XCTAssertEqual(game.puzzle?.boss, .editor)
        XCTAssertEqual(game.puzzle?.handSize, 7, "Help Wanted offsets The Editor")
        XCTAssertNil(Conservation.check(board: game.puzzle!.board,
                                        pool: game.puzzle!.pool,
                                        hand: game.puzzle!.hand))

        game.qaSetMarker("mk_copper", at: Square(row: 1, col: 1))
        XCTAssertEqual(game.run.markers.count, 1)
        XCTAssertEqual(game.run.markers.first?.squares, [Square(row: 1, col: 1)])
        XCTAssertEqual(game.run.markers.first?.defID, "mk_copper")
    }
    #endif

    func testBossPuzzlesAlwaysRollAModifierAndOthersNever() throws {
        var run = RunState(seed: "rolls")
        run.slot = .easy
        XCTAssertNil(try PuzzleState.create(run: &run).boss)
        run.slot = .boss
        let puzzle = try PuzzleState.create(run: &run)
        XCTAssertNotNil(puzzle.boss)
        if puzzle.boss == .censor { XCTAssertNotNil(puzzle.censoredDigit) }
    }
}

final class ShopTests: XCTestCase {

    func testStockIsAlwaysTwoAdsTwoMarkersAndOneBuff() {
        var run = RunState(seed: "shop")
        Shop.open(&run)
        let offers = run.shop!.offers
        XCTAssertEqual(offers.count, 5)
        XCTAssertEqual(offers.filter { $0.def.kind == .bookmark }.count, 2)
        XCTAssertEqual(offers.filter { $0.def.kind == .marker }.count, 2)
        XCTAssertEqual(offers.filter { $0.def.kind == .buff }.count, 1)
    }

    func testAnAdYouOwnIsNeverOfferedAgain() {
        var run = RunState(seed: "shop")
        // Own every Bookmark but one; that one must be what the Shop offers.
        let allAds = Catalog.items(of: .bookmark)
        for ad in allAds.dropLast(1).prefix(5) {
            run.bookmarks.append(OwnedBookmark(defID: ad.id, boughtAtLevel: 1, pricePaid: 0))
        }
        for _ in 0..<20 {
            Shop.open(&run)
            for offer in run.shop!.offers where offer.def.kind == .bookmark {
                XCTAssertFalse(run.owns(bookmark: offer.defID), "offered an owned Bookmark: \(offer.defID)")
            }
        }
    }

    func testTheSameAdIsNeverOfferedTwiceInOneShop() {
        var run = RunState(seed: "dupes")
        for _ in 0..<50 {
            Shop.open(&run)
            let ads = run.shop!.offers.filter { $0.def.kind == .bookmark }.map(\.defID)
            XCTAssertEqual(Set(ads).count, ads.count)
        }
    }

    func testPricesFallInTheBandForTheirKindAndRarity() {
        var run = RunState(seed: "prices")
        for level in [1, 5, 9] {
            run.level = level
            for _ in 0..<40 {
                Shop.open(&run)
                for offer in run.shop!.offers {
                    let band = Shop.priceBand(offer.def.kind, offer.def.rarity)
                    XCTAssertTrue(band.contains(offer.price),
                                  "\(offer.defID) priced \(offer.price), band \(band)")
                }
            }
        }
    }

    func testRarityOddsShiftAsTheBookGoesOn() {
        func rareShare(level: Int) -> Double {
            var rng = RandomStream(seed: "odds", stream: "shop")
            var rare = 0
            for _ in 0..<20_000 where Shop.rollRarity(&rng, level: level) == .rare { rare += 1 }
            return Double(rare) / 20_000
        }
        XCTAssertEqual(rareShare(level: 1), 0.05, accuracy: 0.01)
        XCTAssertEqual(rareShare(level: 5), 0.12, accuracy: 0.015)
        XCTAssertEqual(rareShare(level: 9), 0.20, accuracy: 0.02)
    }

    func testBuyingSpendsCoinsFillsASlotAndMarksTheOfferSold() throws {
        var run = RunState(seed: "buy", book: .slightlyHarder)
        Shop.open(&run)
        let offer = run.shop!.offers.first { $0.price <= run.coins }!
        let coinsBefore = run.coins

        try Shop.buy(&run, slot: offer.slot)
        XCTAssertEqual(run.coins, coinsBefore - offer.price)
        XCTAssertTrue(run.shop!.offers.first { $0.slot == offer.slot }!.sold)
        XCTAssertThrowsError(try Shop.buy(&run, slot: offer.slot)) {
            XCTAssertEqual($0 as? Shop.ShopError, .alreadySold)
        }
    }

    func testBuyingIsRefusedWithoutCoinsOrSlots() throws {
        var run = RunState(seed: "buy")
        run.coins = 0
        Shop.open(&run)
        XCTAssertThrowsError(try Shop.buy(&run, slot: run.shop!.offers[0].slot)) {
            XCTAssertEqual($0 as? Shop.ShopError, .notEnoughCoins)
        }

        run.coins = 999
        run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 3),
                     OwnedBuff(defID: Buffs.redraw, pricePaid: 3)]
        let buffOffer = run.shop!.offers.first { $0.def.kind == .buff }!
        XCTAssertThrowsError(try Shop.buy(&run, slot: buffOffer.slot)) {
            XCTAssertEqual($0 as? Shop.ShopError, .slotsFull)
        }
    }

    func testMarkersCanBeBoughtBeyondTheFormerThreeMarkerLimit() throws {
        var run = RunState(seed: "unlimited-markers")
        run.coins = 20
        run.shop = ShopState(
            offers: (0..<4).map { ShopOffer(slot: $0, defID: "mk_golden", price: 5) },
            rerollCost: 2,
            rerollsUsed: 0
        )

        for slot in 0..<4 {
            try Shop.buy(&run, slot: slot)
        }

        XCTAssertEqual(run.markers.count, 4)
        XCTAssertEqual(run.coins, 0)
    }

    func testRerollCostsTwoThenClimbs() throws {
        var run = RunState(seed: "reroll")
        run.coins = 100
        Shop.open(&run)
        XCTAssertEqual(run.shop?.rerollCost, 2)
        try Shop.reroll(&run)
        XCTAssertEqual(run.coins, 98)
        XCTAssertEqual(run.shop?.rerollCost, 3)
        try Shop.reroll(&run)
        XCTAssertEqual(run.coins, 95)
        XCTAssertEqual(run.shop?.rerollCost, 4)
    }

    func testAuctionNoticesMakesTheFirstRerollFree() throws {
        var run = RunState(seed: "reroll")
        run.coins = 100
        run.bookmarks.append(OwnedBookmark(defID: Bookmarks.auctionNotices, boughtAtLevel: 1, pricePaid: 6))
        Shop.open(&run)
        XCTAssertEqual(run.shop?.rerollCost, 0)
        try Shop.reroll(&run)
        XCTAssertEqual(run.coins, 100)
    }

    func testSellingRefundsHalfRoundedDownMinimumOne() {
        XCTAssertEqual(RunState.sellValue(pricePaid: 8), 4)
        XCTAssertEqual(RunState.sellValue(pricePaid: 7), 3)
        XCTAssertEqual(RunState.sellValue(pricePaid: 1), 1)
        XCTAssertEqual(RunState.sellValue(pricePaid: 0), 1)
    }

    func testSellingBookmarksAndBuffsRefundsAndFreesTheirSlots() throws {
        var game = Game(seed: "sell")
        try game.startPuzzle()
        game.run.bookmarks.append(OwnedBookmark(defID: "bm_op_ed", boughtAtLevel: 1, pricePaid: 7))
        game.run.buffs.append(OwnedBuff(defID: Buffs.peek, pricePaid: 3))
        let coins = game.run.coins

        XCTAssertEqual(try game.sell(kind: .bookmark, index: 0), 3)
        XCTAssertEqual(try game.sell(kind: .buff, index: 0), 1)
        XCTAssertEqual(game.run.coins, coins + 4)
        XCTAssertTrue(game.run.bookmarks.isEmpty)
        XCTAssertTrue(game.run.buffs.isEmpty)
    }

    func testSellingWorksMidPuzzleButRejectsMarkers() throws {
        var game = Game(seed: "sell2")
        try game.startPuzzle()
        game.run.buffs.append(OwnedBuff(defID: Buffs.peek, pricePaid: 4))
        XCTAssertEqual(try game.sell(kind: .buff, index: 0), 2)

        game.run.markers.append(OwnedMarker(defID: Markers.rose, boughtAtLevel: 1, pricePaid: 8))
        XCTAssertThrowsError(try game.sell(kind: .marker, index: 0)) { error in
            XCTAssertEqual(error as? Shop.ShopError, .cannotBeSold)
        }
        XCTAssertEqual(game.run.markers.count, 1)
    }
}

final class RunAndDeterminismTests: XCTestCase {

    func testSubscriptionsStackPersistAndDoNotUseHeldSlots() throws {
        var run = RunState(seed: "subscriptions")
        run.subscriptions = [
            OwnedSubscription(defID: Subscriptions.homeDelivery, pricePaid: 12),
            OwnedSubscription(defID: Subscriptions.weekendEdition, pricePaid: 14),
            OwnedSubscription(defID: Subscriptions.wireService, pricePaid: 14),
            OwnedSubscription(defID: Subscriptions.annualRate, pricePaid: 18),
            OwnedSubscription(defID: Subscriptions.overseasEdition, pricePaid: 20),
        ]
        run.bookmarks.append(OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 0))
        XCTAssertEqual(run.effectiveHandSize(boss: nil), 9)
        XCTAssertEqual(run.effectiveTurns(boss: nil), 11)
        XCTAssertEqual(run.effectiveTossAllowance(boss: nil), 6)
        XCTAssertEqual(run.interestCap, 20)
        XCTAssertEqual(run.markerCapacity, .max)
        XCTAssertTrue(run.bookmarks.count < ItemKind.bookmark.capacity)
        XCTAssertTrue(run.buffs.count < ItemKind.buff.capacity)

        let restored = try Game(decoding: try Game(run: run).encoded())
        XCTAssertEqual(restored.run.subscriptions.map(\.defID), run.subscriptions.map(\.defID))
    }

    func testStockContainsOnlyBookmarksMarkersAndBuffs() {
        for seed in 0..<100 {
            var run = RunState(seed: "sub-\(seed)")
            run.level = 3
            Shop.open(&run)
            XCTAssertEqual(run.shop!.offers.count, 5)
            XCTAssertEqual(run.shop!.offers.filter { $0.def.kind == .bookmark }.count, 2)
            XCTAssertEqual(run.shop!.offers.filter { $0.def.kind == .marker }.count, 2)
            XCTAssertEqual(run.shop!.offers.filter { $0.def.kind == .buff }.count, 1)
            XCTAssertFalse(run.shop!.offers.contains { $0.def.kind == .subscription })
        }
    }

    func testBuyingSubscriptionUsesCoinsButNoHeldSlotAndCannotBeSold() throws {
        var run = RunState(seed: "buy-subscription")
        run.coins = 20
        run.shop = ShopState(offers: [ShopOffer(slot: 0, defID: Subscriptions.homeDelivery, price: 12)],
                             rerollCost: 2, rerollsUsed: 0)
        try Shop.buy(&run, slot: 0)
        XCTAssertEqual(run.coins, 8)
        XCTAssertEqual(run.subscriptions.map(\.defID), [Subscriptions.homeDelivery])
        XCTAssertTrue(run.bookmarks.isEmpty)
        XCTAssertTrue(run.markers.isEmpty)
        XCTAssertTrue(run.buffs.isEmpty)
        XCTAssertThrowsError(try Shop.sell(&run, kind: .subscription, index: 0)) { error in
            XCTAssertEqual(error as? Shop.ShopError, .cannotBeSold)
        }
    }

    func testABookIsNineLevelsOfThreePuzzles() {
        var run = RunState(seed: "book")
        var puzzles = 0
        while run.advance() { puzzles += 1 }
        XCTAssertEqual(puzzles + 1, 27)
        XCTAssertEqual(run.outcome, .bookCompleted)
    }

    func testBooksApplyTheirOwnBenefits() {
        XCTAssertEqual(RunState(seed: "s").effectiveHandSize(boss: nil), 7)
        XCTAssertEqual(RunState(seed: "s", book: .slightlyHarder).coins, 15)
        XCTAssertEqual(RunState(seed: "s", book: .noPressure).effectiveClues(boss: nil), 1)
        XCTAssertEqual(RunState(seed: "s", book: .slightlyHarder).effectiveHandSize(boss: nil), 6)
        XCTAssertEqual(RunState(seed: "s", book: .bites).effectiveTurns(boss: nil), 11)
    }

    func testSameSeedAndSameChoicesReproduceTheBookExactly() throws {
        func play(_ seed: String) throws -> Data {
            var game = Game(seed: seed)
            try game.startPuzzle()
            for _ in 0..<3 {
                _ = try? game.toss(handIndex: 0)
                _ = try? game.endTurn()
            }
            game.openShop()
            try? game.reroll()
            return try game.encoded()
        }
        XCTAssertEqual(try play("share-me"), try play("share-me"))
        XCTAssertNotEqual(try play("share-me"), try play("other-seed"))
    }

    func testClippingsAreSeededLimitedAndNeverOfferedForBosses() throws {
        var first = Game(seed: "clip")
        var second = Game(seed: "clip")
        XCTAssertEqual(first.run.currentClipping, second.run.currentClipping)
        XCTAssertEqual(first.run.skipsRemaining, 2)

        _ = try first.skipPuzzle()
        _ = try second.skipPuzzle()
        XCTAssertEqual(first.run.slot, .medium)
        XCTAssertEqual(first.run.currentClipping, second.run.currentClipping)
        _ = try first.skipPuzzle()
        XCTAssertEqual(first.run.slot, .boss)
        XCTAssertEqual(first.run.skipsRemaining, 0)
        XCTAssertNil(first.run.currentClipping)
        XCTAssertThrowsError(try first.skipPuzzle()) { error in
            XCTAssertEqual(error as? ClippingError, .cannotSkip)
        }
    }

    func testNormalPuzzleKeepsItsClippingOfferAfterPreviousShopCloses() throws {
        var game = Game(seed: "second-puzzle-clipping")
        try game.startPuzzle()
        game.openShop()

        XCTAssertTrue(game.advance())
        XCTAssertEqual(game.run.slot, .medium)
        XCTAssertNil(game.shop)
        XCTAssertNotNil(game.run.currentClipping)
    }

    func testOverprintIsConsumedByTheNextPuzzle() throws {
        let seed = try XCTUnwrap((0..<100).map(String.init).first { seed in
            Game(seed: seed).run.currentClipping == .overprint
        })
        var game = Game(seed: seed)
        _ = try game.skipPuzzle()
        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.pendingMult, 2)
        XCTAssertNil(game.run.runItemState["clipping.overprint"])
    }

    func testEveryClippingAppliesItsAdvertisedRewardAndPersists() throws {
        for clipping in Clipping.allCases {
            let seed = try XCTUnwrap((0..<500).map(String.init).first { seed in
                Game(seed: seed).run.currentClipping == clipping
            })
            var game = Game(seed: seed)
            let coinsBefore = game.run.coins
            let capBefore = game.run.interestCap

            XCTAssertEqual(try game.skipPuzzle(), clipping)
            XCTAssertEqual(try Game(decoding: game.encoded()).run.takenClippings, game.run.takenClippings)

            switch clipping {
            case .coupon:
                XCTAssertEqual(game.run.coins, coinsBefore + 8)
            case .circulation:
                XCTAssertEqual(game.run.interestCap, capBefore + 5)
            case .overprint:
                try game.startPuzzle()
                XCTAssertEqual(game.puzzle?.pendingMult, 2)
            }
        }
    }

    func testSaveAndLoadRoundTripsMidPuzzle() throws {
        var game = Game(seed: "save", book: .noPressure)
        try game.startPuzzle()
        game.give(ad: "bm_op_ed")
        game.give(marker: "mk_golden", on: [game.puzzle!.board.blanks[0]])
        _ = try game.place(handIndex: 0, at: game.blank(wanting: game.puzzle!.hand[0])!)
        _ = try game.endTurn()

        let restored = try Game(decoding: try game.encoded())
        XCTAssertEqual(try restored.encoded(), try game.encoded())
        XCTAssertEqual(restored.puzzle?.score, game.puzzle?.score)
        XCTAssertEqual(restored.puzzle?.hand, game.puzzle?.hand)
        XCTAssertEqual(restored.run.markers.first?.squares, game.run.markers.first?.squares)
    }

    func testPreTurnBankSaveStillLoadsWithAnEmptyQueue() throws {
        var game = Game(seed: "legacy-queue")
        try game.startPuzzle()
        let encoded = try game.encoded()
        var root = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var puzzle = try XCTUnwrap(root["puzzle"] as? [String: Any])
        puzzle.removeValue(forKey: "pendingBase")
        puzzle.removeValue(forKey: "pendingMult")
        root["puzzle"] = puzzle

        let oldSave = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        let restored = try Game(decoding: oldSave)
        XCTAssertEqual(restored.puzzle?.pendingBase, 0)
        XCTAssertEqual(restored.puzzle?.pendingMultiplier, 1)
    }

    func testPreSubscriptionSaveLoadsWithNoSubscriptions() throws {
        let game = Game(seed: "legacy-subscription")
        var root = try XCTUnwrap(try JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        root.removeValue(forKey: "subscriptions")
        let legacy = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        XCTAssertTrue(try Game(decoding: legacy).run.subscriptions.isEmpty)
    }

    func testItemCatalogueMatchesTheDesignTables() {
        XCTAssertEqual(Catalog.items(of: .bookmark).count, 23)
        XCTAssertEqual(Catalog.items(of: .marker).count, 12)
        XCTAssertEqual(Catalog.items(of: .buff).count, 11)
        XCTAssertEqual(Catalog.items(of: .subscription).count, 7)
        // Ids must be unique — the catalogue is keyed by them.
        let ids = Catalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for item in Catalog.all {
            XCTAssertFalse(item.name.isEmpty)
            XCTAssertFalse(item.text.isEmpty)
            XCTAssertTrue(Shop.priceBand(item.kind, item.rarity).contains(item.listedPrice),
                          "\(item.id) listed at \(item.listedPrice), outside its band")
        }
    }
}
