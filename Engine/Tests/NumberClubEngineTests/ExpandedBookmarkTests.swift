import XCTest
@testable import ProbablySudokuEngine

final class ExpandedBookmarkTests: XCTestCase {
    private func fixture(_ ids: [String], boss: Bool = false) -> RunState {
        var run = RunState(seed: "bookmark-catalogue-contract", book: .probably)
        if boss { run.slot = .boss }
        run.bookmarks = ids.enumerated().map {
            OwnedBookmark(defID: $0.element, boughtAtLevel: 1, pricePaid: 7,
                id: SkipOffer.stableIdentity(seed: run.seed, domain: "test.\($0.offset).\($0.element)"))
        }
        let digits = (0..<81).map { Digit(($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1)! }
        let board = Board(GeneratedPuzzle(solution: digits, isGiven: Array(repeating: false, count: 81)))
        var pool = Pool(blanksOf: board)
        let hand = pool.draw(&run.streams.pool, count: 7)
        var puzzle = PuzzleState(level: 1, slot: run.slot, difficulty: run.slot.difficulty,
            board: board, pool: pool, hand: hand, handSize: 7, turnNumber: 1, turnsMax: 10,
            tossedThisPuzzle: 0, tossAllowance: 4, score: 0, target: 9_000_000,
            cluesRemaining: 0, boss: nil, censoredDigit: nil, blockedDigit: nil,
            bossTurn: nil, phase: .playing, keepFillingCoins: 0)
        puzzle.ensureHandIdentities(seed: run.seed)
        run.puzzle = puzzle
        return run
    }

    private func event(_ run: RunState, digit: Digit = .one, square: Int = 40,
                       eligible: Bool = true, units: [ProbablySudokuEngine.Unit] = [], marker: Int = 0) -> CataloguePlacement {
        CataloguePlacement(digit: digit, square: Square(square), boardBefore: run.puzzle!.board,
            handBefore: run.puzzle!.handCards, completedUnits: units, positiveClearUnits: units,
            isEligible: eligible, placementPoints: 10, markerExtraPoints: marker,
            turnNumber: run.puzzle!.turnNumber)
    }

    @discardableResult
    private func before(_ run: inout RunState, _ e: CataloguePlacement) -> EffectResult {
        var p = run.puzzle!
        let result = BookmarkMechanics.beforePlacement(e, run: &run, puzzle: &p)
        run.puzzle = p
        return result
    }

    @discardableResult
    private func after(_ run: inout RunState, _ e: CataloguePlacement) -> EffectResult {
        var p = run.puzzle!
        let result = BookmarkMechanics.afterPlacement(e, run: &run, puzzle: &p)
        run.puzzle = p
        return result
    }

    private func held(_ run: RunState, _ index: Int = 0) -> EffectResult {
        BookmarkMechanics.heldEffect(run.bookmarks[index], previous: index > 0 ? run.bookmarks[index - 1] : nil,
                                    run: run, puzzle: run.puzzle!)
    }

    private func restored(_ run: RunState) throws -> RunState { try Game(decoding: Game(run: run).encoded()).run }

    private func prepareBox(_ puzzle: inout PuzzleState, leaving last: Square) throws {
        for square in Geometry.boxes[last.box] where square != last && puzzle.board.isBlank(square) {
            let digit = puzzle.board.correctDigit(at: square)
            if !puzzle.pool.take(digit) {
                _ = puzzle.removeHandCard(at: try XCTUnwrap(puzzle.hand.firstIndex(of: digit)))
            }
            puzzle.board.fill(square, with: digit, by: .player)
        }
        puzzle.assertConservation()
    }

    func testPostPlacementCoinReceiptAndTargetedDrawsMatchTheCommittedAction() throws {
        var run = fixture([Bookmarks.issueTracker, Bookmarks.personalColumn])
        let source = run.bookmarks[0].id
        var puzzle = try XCTUnwrap(run.puzzle)
        try prepareBox(&puzzle, leaving: Square(0))
        puzzle.turnNumber = 3
        puzzle.bookmarkState.boxTurns[0] = [1, 2]
        puzzle.bookmarkState.copies[run.bookmarks[1].id, default: .init()].personalDigit = .one
        run.puzzle = puzzle
        run.markers = [OwnedMarker(defID: Markers.echo, boughtAtLevel: 1, pricePaid: 6, squares: [Square(0)])]
        var game = Game(run: run)
        let card = try XCTUnwrap(game.stackHand(with: .one))
        let beforeCoins = game.run.coins
        let beforeHand = game.puzzle!.hand.count
        let result = try game.place(handIndex: card, at: Square(0))
        XCTAssertEqual(result.numbersDrawn, 2, "Personal Column and Echo each draw one real card")
        XCTAssertEqual(game.puzzle?.hand.count, beforeHand - 1 + 2)
        XCTAssertEqual(result.coinsEarned, 3)
        XCTAssertEqual(game.run.coins, beforeCoins + 3)
        let receipt = result.scoreReceipts.flatMap(\.operations).filter { $0.sourceID == Bookmarks.issueTracker }
        XCTAssertEqual(receipt.count, 1)
        XCTAssertEqual(receipt.first?.sourceInstanceID, source.uuidString)
        XCTAssertEqual(receipt.first?.before.coins, beforeCoins)
        XCTAssertEqual(receipt.first?.after.coins, beforeCoins + 3)
        XCTAssertEqual(game.puzzle?.turnScoringOperations.filter { $0.sourceID == Bookmarks.issueTracker }.count, 1)
        XCTAssertEqual(try Game(decoding: game.encoded()).run.coins, beforeCoins + 3)
        game.puzzle?.assertConservation()
    }

    func testHistoricalClueClearDoesNotRepriceItsAlreadyLockedRollingMultiplier() throws {
        var run = fixture([Bookmarks.rollingPresses])
        var puzzle = try XCTUnwrap(run.puzzle)
        try prepareBox(&puzzle, leaving: Square(0))
        puzzle.cluesRemaining = 1
        puzzle.pendingBase = 100
        puzzle.lockScoringOrder(run: run)
        run.puzzle = puzzle
        var saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Game(run: run).encoded()) as? [String: Any])
        var oldPuzzle = try XCTUnwrap(saved["puzzle"] as? [String: Any])
        oldPuzzle.removeValue(forKey: "bookmarkState")
        saved["puzzle"] = oldPuzzle
        var game = try Game(decoding: JSONSerialization.data(withJSONObject: saved))
        XCTAssertTrue(game.puzzle!.bookmarkState.legacyTurn)
        let clue = try game.useClue(at: Square(0))
        XCTAssertEqual(clue.lineClears, [.box])
        XCTAssertEqual(game.puzzle?.itemState[Bookmarks.rollingPresses], 1)
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 1, "Old Clue event cannot change the saved Turn's observed held effects")
        XCTAssertEqual(try game.endTurn().pointsGained, 100)
        XCTAssertFalse(game.puzzle!.bookmarkState.legacyTurn)
    }

    func testAllFiftyDefinitionsExactlyMatchApprovedCatalogue() throws {
        XCTAssertEqual(Bookmarks.all.count, 50)
        XCTAssertEqual(Set(Bookmarks.all.map(\.id)).count, 50)
        for item in Bookmarks.all {
            let source = try XCTUnwrap(CatalogueDetails.item(item.id))
            XCTAssertEqual(item.name, source.name, item.id)
            XCTAssertEqual(item.text, source.effect, item.id)
            XCTAssertEqual(item.listedPrice, source.price, item.id)
            XCTAssertEqual(item.rarity.rawValue, source.rarity.lowercased(), item.id)
        }
    }

    func testRetainedPlacementAndClearHooksKeepTheirExistingScopes() {
        let cases: [(String, GameEvent, Int, Int, Int, Double)] = [
            (Bookmarks.localGossip, .place, 30, 0, 0, 1),
            (Bookmarks.sportsSection, .lineClear, 25, 0, 0, 1),
            (Bookmarks.societyPages, .fullClear, 500, 0, 0, 1),
            (Bookmarks.extraExtra, .lineClear, 0, 0, 0, 3),
            (Bookmarks.extraExtra, .fullClear, 0, 0, 0, 3),
            (Bookmarks.financePages, .lineClear, 0, 1, 0, 1),
            (Bookmarks.crosswordDaily, .lineClear, 0, 0, 1, 1)]
        for (id, event, flat, coins, draws, factor) in cases {
            let run = fixture([id])
            let context = Resolver.context(event, run: run, puzzle: run.puzzle!, isClue: true)
            var r = EffectResult(); Catalog.item(id)!.hooks[event]?(context, &r)
            XCTAssertEqual(r.flat, flat, id); XCTAssertEqual(r.coins, coins, id)
            XCTAssertEqual(r.draws, draws, id); XCTAssertEqual(r.eventMultX, factor, id)
        }
    }

    func testEligibleTurnDirectAwardsAndTurnTenLimitSurviveResume() throws {
        var run = fixture([Bookmarks.morningEdition, Bookmarks.eveningEdition])
        var p = run.puzzle!
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 0)
        p.turnNumber = 10; run.puzzle = p
        before(&run, event(run))
        run = try restored(run); p = run.puzzle!
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 400)
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 0)
        BookmarkMechanics.turnStarted(puzzle: &p); p.turnNumber = 11; run.puzzle = p
        before(&run, event(run)); p = run.puzzle!
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 100)
        p.phase = .keepFilling; BookmarkMechanics.turnStarted(puzzle: &p)
        p.bookmarkState.turn.eligiblePlacements = 1
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 0)
    }

    func testEditorialNeedsThreeUniqueBoxesAndStopLosesFactorOnThirdPlacement() {
        var run = fixture([Bookmarks.editorialBoard, Bookmarks.stopThePresses])
        before(&run, event(run, square: 0)); before(&run, event(run, square: 1))
        XCTAssertEqual(held(run).multAdd, 0); XCTAssertEqual(held(run, 1).multX, 3)
        before(&run, event(run, square: 3, eligible: false))
        XCTAssertEqual(held(run, 1).multX, 3)
        before(&run, event(run, square: 3)); before(&run, event(run, square: 6))
        XCTAssertEqual(held(run).multAdd, 3); XCTAssertEqual(held(run, 1).multX, 1)
    }

    func testLettersRequiresPreviousActualPaidPenaltyAndBossEligibility() {
        var run = fixture([Bookmarks.lettersToTheEditor], boss: true)
        var p = run.puzzle!
        BookmarkMechanics.wrongPlacement(digit: .nine, paidPenalty: 0, run: run, puzzle: &p)
        BookmarkMechanics.didBank(ordinaryBank: 0, puzzle: &p); BookmarkMechanics.turnStarted(puzzle: &p)
        run.puzzle = p; before(&run, event(run))
        XCTAssertEqual(held(run).multAdd, 0)
        p = run.puzzle!
        BookmarkMechanics.wrongPlacement(digit: .nine, paidPenalty: 1, run: run, puzzle: &p)
        BookmarkMechanics.didBank(ordinaryBank: 0, puzzle: &p); BookmarkMechanics.turnStarted(puzzle: &p)
        run.puzzle = p
        XCTAssertEqual(held(run).multAdd, 0)
        before(&run, event(run)); XCTAssertEqual(held(run).multAdd, 3)
    }

    func testMarginCornersOnlyPayOnceAndNeighbourhoodExcludesCluesAndGivens() {
        var run = fixture([Bookmarks.marginNotes, Bookmarks.neighbourhoodNews])
        XCTAssertEqual(before(&run, event(run, square: 0)).flat, 50)
        run.puzzle!.board.fill(Square(39), with: .one, by: .player)
        run.puzzle!.board.fill(Square(41), with: .two, by: .clue)
        XCTAssertEqual(before(&run, event(run)).flat, 0)
        run.puzzle!.board.fill(Square(31), with: .three, by: .player)
        XCTAssertEqual(before(&run, event(run)).flat, 45)
        XCTAssertEqual(before(&run, event(run, eligible: false)).flat, 0)
    }

    func testSerialStoryBreaksOnWrongClueNonconsecutiveAndDoesNotWrap() {
        var run = fixture([Bookmarks.serialStory])
        before(&run, event(run, digit: .eight)); before(&run, event(run, digit: .nine))
        XCTAssertEqual(before(&run, event(run, digit: .one)).flat, 0)
        before(&run, event(run, digit: .two, eligible: false))
        before(&run, event(run, digit: .three)); before(&run, event(run, digit: .four))
        var p = run.puzzle!
        BookmarkMechanics.wrongPlacement(digit: .five, paidPenalty: 0, run: run, puzzle: &p)
        run.puzzle = p
        XCTAssertEqual(before(&run, event(run, digit: .five)).flat, 0)
        before(&run, event(run, digit: .six))
        XCTAssertEqual(before(&run, event(run, digit: .seven)).flat, 120)
        XCTAssertEqual(before(&run, event(run, digit: .eight)).flat, 0)
    }

    func testDoubleColumnRequiresSameDigitInDistinctBoxes() {
        var run = fixture([Bookmarks.doubleColumn])
        before(&run, event(run, digit: .one, square: 0)); before(&run, event(run, digit: .one, square: 1))
        before(&run, event(run, digit: .two, square: 3))
        XCTAssertEqual(held(run).multAdd, 0)
        before(&run, event(run, digit: .one, square: 4))
        XCTAssertEqual(held(run).multAdd, 2)
    }

    func testCarryoverUsesPreviousOrdinaryBankWithoutRecursingAndCaps() {
        var run = fixture([Bookmarks.carryover])
        before(&run, event(run)); var p = run.puzzle!
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 0)
        BookmarkMechanics.didBank(ordinaryBank: 2_349, puzzle: &p)
        BookmarkMechanics.turnStarted(puzzle: &p); run.puzzle = p
        before(&run, event(run)); p = run.puzzle!
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 234)
        BookmarkMechanics.didBank(ordinaryBank: 9_000, puzzle: &p)
        BookmarkMechanics.turnStarted(puzzle: &p); run.puzzle = p
        before(&run, event(run)); p = run.puzzle!
        XCTAssertEqual(BookmarkMechanics.turnEnd(run: run, puzzle: &p).directScore, 300)
    }

    func testNumberIndexAwardsCurrentTurnOncePerPuzzleAndCapsPerCopy() throws {
        var run = fixture([Bookmarks.numberIndex])
        for round in 0..<6 {
            var p = run.puzzle!; BookmarkMechanics.puzzleStarted(puzzle: &p); run.puzzle = p
            for digit in Digit.all { before(&run, event(run, digit: digit)) }
            XCTAssertEqual(held(run).multAdd, Double(min(10, (round + 1) * 2)))
            for digit in Digit.all { before(&run, event(run, digit: digit)) }
            run = try restored(run)
            XCTAssertEqual(held(run).multAdd, Double(min(10, (round + 1) * 2)))
        }
    }

    func testEarlyDeadlineUsesWinningBankNotLaterKeepFillingTurn() {
        var run = fixture([Bookmarks.earlyDeadline]); var p = run.puzzle!
        p.turnNumber = 5; p.score = p.target
        BookmarkMechanics.didBank(ordinaryBank: p.target, puzzle: &p)
        p.phase = .keepFilling; p.turnNumber = 9
        BookmarkMechanics.didBank(ordinaryBank: 0, puzzle: &p)
        XCTAssertEqual(BookmarkMechanics.earlyDeadlineCoins(run: run, puzzle: p), 4)
        p.bookmarkState.winningTurn = nil
        XCTAssertEqual(BookmarkMechanics.earlyDeadlineCoins(run: run, puzzle: p), 0)
        run.puzzle = p
    }

    func testOverflowCountsHandBeforeRemovalAndUsesEffectiveRefillTarget() {
        var run = fixture([Bookmarks.overflowColumn])
        var e = event(run); e.handBefore = (0..<12).map { _ in CatalogueHandCard(id: UUID(), digit: .one) }
        XCTAssertEqual(before(&run, e).flat, 100)
        run.puzzle?.handSize = 10
        XCTAssertEqual(before(&run, e).flat, 50)
        e.isEligible = false
        XCTAssertEqual(before(&run, e).flat, 0)
    }

    func testDuplicateDispatchCancelAndExchangeConserveCardsAndRetainedIdentity() throws {
        var run = fixture([Bookmarks.duplicateDispatch]); var p = run.puzzle!
        for card in p.removeAllHandCards() { p.pool.put(card.digit) }
        for digit in [Digit.five, .five, .five, .one] {
            XCTAssertTrue(p.pool.take(digit)); p.appendHandDigits([digit])
        }
        run.puzzle = p; let original = p.handCards
        BookmarkMechanics.enqueueChoices(run: &run)
        let canceled = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertFalse(try BookmarkMechanics.resolveDecision(id: canceled.id, selected: nil, run: &run))
        XCTAssertEqual(run.puzzle?.handCards, original)
        XCTAssertFalse(run.puzzle!.bookmarkState.copies[run.bookmarks[0].id, default: .init()].duplicateUsed)
        p = run.puzzle!; BookmarkMechanics.turnStarted(puzzle: &p); p.turnNumber += 1; run.puzzle = p
        BookmarkMechanics.enqueueChoices(run: &run)
        let accepted = try XCTUnwrap(run.pendingItemDecisions.first)
        let marker = MarkerSource(markerID: Markers.tiebreaker, claimID: "exchange-test", square: Square(40))
        run.puzzle?.buffState.cleanFinish = BuffChallenge(source: UUID(), cards: Set(original.map(\.id)), turn: p.turnNumber)
        run.puzzle?.markerState.turn.streak = 3
        run.puzzle?.markerState.turn.tiebreaker = MarkerCardChallenge(source: marker, cardIDs: original.map(\.id))
        run.puzzle?.markerState.turn.forecast = marker
        let stream = run.streams.pool.state
        XCTAssertTrue(try BookmarkMechanics.resolveDecision(id: accepted.id, selected: ["5"], run: &run))
        XCTAssertEqual(run.puzzle?.hand.count, 4)
        XCTAssertEqual(run.puzzle?.handCards.first, original.first)
        XCTAssertTrue(run.puzzle!.handCards.contains(original[3]))
        XCTAssertNotEqual(run.streams.pool.state, stream)
        XCTAssertEqual(run.puzzle?.buffState.cleanFinish?.failed, true)
        XCTAssertEqual(run.puzzle?.markerState.turn.streak, 0)
        XCTAssertNil(run.puzzle?.markerState.turn.tiebreaker)
        XCTAssertNil(run.puzzle?.markerState.turn.forecast)
        XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
        XCTAssertThrowsError(try BookmarkMechanics.resolveDecision(id: accepted.id, selected: ["5"], run: &run))
    }

    func testPaperSalvageDrawsExactlyOnceAfterTossAndForecastIsPure() throws {
        var run = fixture([Bookmarks.paperSalvage, Bookmarks.forthcomingEdition]); var p = run.puzzle!
        let expected = BookmarkMechanics.poolForecast(run: run, puzzle: p)
        let encoded = try Game(run: run).encoded()
        for _ in 0..<10 { XCTAssertEqual(BookmarkMechanics.poolForecast(run: run, puzzle: p), expected) }
        XCTAssertEqual(try Game(run: run).encoded(), encoded)
        let count = p.hand.count
        p.markerState.turn.forecast = MarkerSource(markerID: Markers.forecast,
            claimID: "salvage-preview", square: Square(40))
        BookmarkMechanics.afterToss(run: &run, puzzle: &p)
        XCTAssertEqual(p.hand.count, count + 1); XCTAssertEqual(p.hand.last, expected.first)
        XCTAssertNil(p.markerState.turn.forecast, "An actual ordinary draw consumes Forecast's preview")
        BookmarkMechanics.afterToss(run: &run, puzzle: &p)
        XCTAssertEqual(p.hand.count, count + 1)
        XCTAssertNil(Conservation.check(board: p.board, pool: p.pool, hand: p.hand))
    }

    func testCarbonCopiesOnlyPositiveMarkerDeltaToNextEligibleUnmarkedPlacement() {
        var run = fixture([Bookmarks.carbonPaper]); run.markers = [OwnedMarker(defID: "mk_crimson", boughtAtLevel: 1, pricePaid: 9, squares: [Square(0)])]
        XCTAssertEqual(before(&run, event(run, square: 0, marker: 270)).flat, 0)
        XCTAssertEqual(before(&run, event(run, square: 1, eligible: false)).flat, 0)
        XCTAssertEqual(before(&run, event(run, square: 2)).flat, 180)
        before(&run, event(run, square: 0, marker: 50))
        XCTAssertEqual(before(&run, event(run, square: 3)).flat, 0)
    }

    func testPocketInsertRequiresExplicitCapacityResolutionAndCancellationIsAtomic() throws {
        var run = fixture([Bookmarks.pocketInsert]); let id = run.bookmarks[0].id
        run.buffs = ["bf_peek", "bf_peek", "bf_redraw"].map { OwnedBuff(defID: $0, pricePaid: 3) }
        XCTAssertEqual(BookmarkMechanics.capacity(run: run), 3)
        XCTAssertFalse(BookmarkMechanics.retire(id: id, run: &run))
        let heldIDs = run.buffs.map(\.id)
        try BookmarkMechanics.requestCapacitySale(bookmarkID: id, run: &run)
        let choice = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertFalse(try BookmarkMechanics.resolveDecision(id: choice.id, selected: nil, run: &run))
        XCTAssertEqual(run.buffs.map(\.id), heldIDs); XCTAssertEqual(run.bookmarks.first?.id, id)
        try BookmarkMechanics.requestCapacitySale(bookmarkID: id, run: &run)
        let next = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertTrue(try BookmarkMechanics.resolveDecision(id: next.id, selected: [heldIDs[1].uuidString], run: &run))
        XCTAssertEqual(run.buffs.map(\.id), [heldIDs[0], heldIDs[2]])
        XCTAssertTrue(run.bookmarks.isEmpty); XCTAssertEqual(BookmarkMechanics.capacity(run: run), 2)
    }

    func testShopDiscountBuybackAndWindowShoppingTrackCanonicalVisit() throws {
        var run = fixture([Bookmarks.bulkNotice, Bookmarks.buybackColumn, Bookmarks.windowShopping, Bookmarks.localGossip])
        run.puzzle = nil
        run.shop = ShopState(offers: [ShopOffer(slot: 0, defID: "bf_peek", price: 3)], visitID: 1)
        BookmarkMechanics.shopOpened(run: &run)
        XCTAssertEqual(Shop.purchasePrice(run, slot: 0), 2)
        XCTAssertEqual(BookmarkMechanics.salePrice(for: run.bookmarks[3], run: run), 7)
        _ = try Shop.sell(&run, kind: .bookmark, index: 3)
        XCTAssertEqual(BookmarkMechanics.salePrice(for: run.bookmarks[0], run: run), 3)
        let before = run.coins
        XCTAssertEqual(BookmarkMechanics.shopLeaving(run: &run), 3)
        XCTAssertEqual(run.coins, before + 3)
        XCTAssertEqual(BookmarkMechanics.shopLeaving(run: &run), 0)
        run.shop?.visitID = 2; BookmarkMechanics.shopOpened(run: &run)
        try Shop.buy(&run, slot: 0)
        XCTAssertEqual(run.buffs.last?.pricePaid, 2)
        XCTAssertEqual(BookmarkMechanics.shopLeaving(run: &run), 0)
        XCTAssertEqual(Shop.purchasePrice(run, slot: 0), 3)
    }

    func testFreeRerollDisqualifiesWindowShoppingAndBoughtThisVisitCannotBuyBack() {
        var run = fixture([Bookmarks.windowShopping, Bookmarks.buybackColumn]); run.puzzle = nil
        run.shop = ShopState(offers: [], rerollCost: 0, visitID: 2)
        BookmarkMechanics.shopOpened(run: &run)
        let bought = OwnedBookmark(defID: Bookmarks.localGossip, boughtAtLevel: 1, pricePaid: 5, boughtInShopVisitID: 2)
        run.bookmarks.append(bought)
        XCTAssertEqual(BookmarkMechanics.salePrice(for: bought, run: run), 2)
        BookmarkMechanics.didReroll(run: &run)
        XCTAssertEqual(BookmarkMechanics.shopLeaving(run: &run), 0)
    }

    func testAuctionBoughtBeforeFirstRerollAndSoldAfterKeepsTheSavedPriceLadder() throws {
        var run = RunState(seed: "auction-acquired-during-visit")
        run.coins = 100
        Shop.open(&run)
        run.shop?.offers = [ShopOffer(slot: 0, defID: Bookmarks.auctionNotices, price: 8)]
        let visit = run.shop?.visitID
        XCTAssertEqual(Shop.rerollPrice(run), 2)
        try Shop.buy(&run, slot: 0)
        XCTAssertEqual(Shop.rerollPrice(run), 0)
        run = try restored(run)
        let beforeFree = run.coins
        try Shop.reroll(&run)
        XCTAssertEqual(run.coins, beforeFree)
        XCTAssertEqual(run.shop?.rerollsUsed, 1)
        XCTAssertEqual(Shop.rerollPrice(run), 2)
        _ = try Shop.sell(&run, kind: .bookmark, index: 0)
        run = try restored(run)
        for price in 2...4 {
            let coins = run.coins
            XCTAssertEqual(Shop.rerollPrice(run), price)
            try Shop.reroll(&run)
            XCTAssertEqual(run.coins, coins - price)
            XCTAssertEqual(Shop.rerollPrice(run), price + 1)
            XCTAssertEqual(run.shop?.visitID, visit)
        }
    }

    func testAuctionSaleBeforeFirstRequestRemovesDiscountAndLatePurchaseCannotResetVisit() throws {
        var run = RunState(seed: "auction-sold-before-request")
        run.coins = 100
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.auctionNotices, boughtAtLevel: 1, pricePaid: 8)]
        Shop.open(&run)
        XCTAssertEqual(Shop.rerollPrice(run), 0)
        _ = try Shop.sell(&run, kind: .bookmark, index: 0)
        XCTAssertEqual(Shop.rerollPrice(run), 2)
        let beforePaid = run.coins
        try Shop.reroll(&run)
        XCTAssertEqual(run.coins, beforePaid - 2)
        XCTAssertEqual(Shop.rerollPrice(run), 3)
        run.shop?.offers = [ShopOffer(slot: 0, defID: Bookmarks.auctionNotices, price: 8)]
        try Shop.buy(&run, slot: 0)
        run = try restored(run)
        XCTAssertEqual(Shop.rerollPrice(run), 3)
        let beforeNext = run.coins
        try Shop.reroll(&run)
        XCTAssertEqual(run.coins, beforeNext - 3)
        XCTAssertEqual(Shop.rerollPrice(run), 4)
    }

    func testAdvancePaymentAndPersonalColumnChoicesAreSavedAndCannotRepeat() throws {
        var run = fixture([Bookmarks.advancePayment, Bookmarks.personalColumn]); run.coins = 10
        BookmarkMechanics.enqueueChoices(run: &run)
        let pay = try XCTUnwrap(run.pendingItemDecisions.first { $0.kind == "bookmark.advance" })
        XCTAssertTrue(try BookmarkMechanics.resolveDecision(id: pay.id, selected: ["pay"], run: &run))
        XCTAssertEqual(run.coins, 7)
        XCTAssertThrowsError(try BookmarkMechanics.resolveDecision(id: pay.id, selected: ["pay"], run: &run))
        let choose = try XCTUnwrap(run.pendingItemDecisions.first { $0.kind == "bookmark.personal" })
        XCTAssertTrue(try BookmarkMechanics.resolveDecision(id: choose.id, selected: ["4"], run: &run))
        run = try restored(run)
        XCTAssertEqual(held(run).multX, 1)
        let count = run.puzzle!.hand.count
        for _ in 0..<3 { let e = event(run, digit: .four); before(&run, e); after(&run, e) }
        XCTAssertEqual(held(run).multX, 2.5)
        XCTAssertEqual(run.puzzle!.hand.count, count + 2)
    }

    func testTypeCaseStopsOnChosenWrongAttemptAndHasThreeBonuses() throws {
        var run = fixture([Bookmarks.typeCase]); BookmarkMechanics.enqueueChoices(run: &run)
        let choice = try XCTUnwrap(run.pendingItemDecisions.first)
        let chosen = try XCTUnwrap(choice.options.first?.digit)
        XCTAssertTrue(try BookmarkMechanics.resolveDecision(id: choice.id, selected: [String(chosen.rawValue)], run: &run))
        let other: Digit = chosen == .one ? .two : .one
        for i in 0..<4 { XCTAssertEqual(before(&run, event(run, digit: other)).flat, i < 3 ? 50 : 0) }
        var p = run.puzzle!; BookmarkMechanics.turnStarted(puzzle: &p); run.puzzle = p
        BookmarkMechanics.enqueueChoices(run: &run)
        let second = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertTrue(try BookmarkMechanics.resolveDecision(id: second.id, selected: [String(chosen.rawValue)], run: &run))
        p = run.puzzle!
        BookmarkMechanics.wrongPlacement(digit: chosen, paidPenalty: 0, run: run, puzzle: &p); run.puzzle = p
        XCTAssertEqual(before(&run, event(run, digit: other)).flat, 0)
    }

    func testCrossReferenceWaitsForPlayableRefillAndLimitsTwoPackets() {
        var run = fixture([Bookmarks.crossReference]); let e = event(run, units: [.row, .box])
        for _ in 0..<3 { before(&run, e); after(&run, e) }
        var p = run.puzzle!; let count = p.hand.count
        XCTAssertEqual(p.bookmarkState.pendingRefillDraws, 4)
        p.phase = .won; BookmarkMechanics.afterPlayableRefill(run: &run, puzzle: &p)
        XCTAssertEqual(p.hand.count, count)
        p.phase = .playing; BookmarkMechanics.afterPlayableRefill(run: &run, puzzle: &p)
        XCTAssertEqual(p.hand.count, count + 4); XCTAssertEqual(p.bookmarkState.pendingRefillDraws, 0)
        XCTAssertNil(Conservation.check(board: p.board, pool: p.pool, hand: p.hand))
    }

    func testIssueTrackerCountsDistinctEligibleTurnsAndBoxOnly() {
        var run = fixture([Bookmarks.issueTracker])
        for turn in 1...4 {
            run.puzzle?.turnNumber = turn; before(&run, event(run, square: 0))
            before(&run, event(run, square: 1))
        }
        XCTAssertEqual(after(&run, event(run, square: 2, units: [.row])).coins, 0)
        XCTAssertEqual(after(&run, event(run, square: 2, units: [.box])).coins, 3)
        XCTAssertEqual(after(&run, event(run, square: 2, units: [.box])).coins, 0)
    }

    func testCorrectionLedgerUsesActualPaidAmountAndOnlyThreeLaterEligiblePlacements() throws {
        var run = fixture([Bookmarks.correctionLedger]); var p = run.puzzle!
        BookmarkMechanics.wrongPlacement(digit: .nine, paidPenalty: 0, run: run, puzzle: &p)
        XCTAssertNil(p.bookmarkState.copies[run.bookmarks[0].id])
        BookmarkMechanics.wrongPlacement(digit: .nine, paidPenalty: 19, run: run, puzzle: &p); run.puzzle = p
        XCTAssertEqual(after(&run, event(run, eligible: false)).directScore, 0)
        XCTAssertEqual(after(&run, event(run)).directScore, 0)
        run = try restored(run)
        XCTAssertEqual(after(&run, event(run)).directScore, 0)
        XCTAssertEqual(after(&run, event(run)).directScore, 9)
        XCTAssertEqual(after(&run, event(run)).directScore, 0)
    }

    func testReferenceDeskConsumesEarlyOpportunityAndRestoresOnlySpentClues() {
        var run = fixture([Bookmarks.referenceDesk])
        after(&run, event(run, units: [.row]))
        run.puzzle?.bookmarkState.spentClues = 1
        after(&run, event(run, units: [.row]))
        XCTAssertEqual(run.puzzle?.cluesRemaining, 0)
        after(&run, event(run, units: [.col, .box]))
        XCTAssertEqual(run.puzzle?.cluesRemaining, 1)
        XCTAssertEqual(run.puzzle?.bookmarkState.spentClues, 0)
        after(&run, event(run, units: [.col, .box]))
        XCTAssertEqual(run.puzzle?.cluesRemaining, 1)
    }

    func testRecycledPurchasedReceiptsChoicesAndFullReplacementAreExactlyOnce() throws {
        var run = fixture([Bookmarks.recycledInsert]); let item = run.bookmarks[0]
        for price in [3, 0, 2, 1] { BookmarkMechanics.buffConsumed(OwnedBuff(defID: "bf_peek", pricePaid: price), run: &run) }
        XCTAssertEqual(run.bookmarkState.copies[item.id]?.purchasedBuffReceipts, 3)
        run.puzzle = nil; run.shop = ShopState(offers: [], visitID: 1)
        BookmarkMechanics.shopOpened(run: &run); BookmarkMechanics.enqueueChoices(run: &run)
        let choice = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertEqual(choice.options.count, 2)
        XCTAssertEqual(Set(choice.options.map(\.id)).count, 2)
        XCTAssertTrue(choice.options.allSatisfy { Catalog.item($0.id)?.rarity == .common })
        run.buffs = [OwnedBuff(defID: "bf_peek", pricePaid: 0), OwnedBuff(defID: "bf_peek", pricePaid: 0)]
        let ids = run.buffs.map(\.id)
        run = try restored(run)
        XCTAssertTrue(try BookmarkMechanics.resolveDecision(id: choice.id, selected: [choice.options[0].id], run: &run))
        XCTAssertEqual(run.bookmarkState.copies[item.id]?.purchasedBuffReceipts, 3)
        let replacement = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertFalse(try BookmarkMechanics.resolveDecision(id: replacement.id, selected: nil, run: &run))
        XCTAssertEqual(run.buffs.map(\.id), ids)
        BookmarkMechanics.enqueueChoices(run: &run); XCTAssertTrue(run.pendingItemDecisions.isEmpty)
        BookmarkMechanics.reopenRecycledChoice(bookmarkID: item.id, run: &run)
        let again = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertEqual(again.options, choice.options)
        _ = try BookmarkMechanics.resolveDecision(id: again.id, selected: [again.options[0].id], run: &run)
        let replace = try XCTUnwrap(run.pendingItemDecisions.first)
        _ = try BookmarkMechanics.resolveDecision(id: replace.id, selected: [ids[0].uuidString], run: &run)
        XCTAssertEqual(run.buffs.count, 2); XCTAssertEqual(run.buffs[0].id, ids[1])
        XCTAssertEqual(run.buffs.last?.pricePaid, 0)
        XCTAssertEqual(run.bookmarkState.copies[item.id]?.purchasedBuffReceipts, 0)
        XCTAssertThrowsError(try BookmarkMechanics.resolveDecision(id: replace.id, selected: [ids[0].uuidString], run: &run))
    }

    func testReadersCircleUsesImmediateLockedNeighbourAndNeverCopiesMultiplicationOrCopier() {
        var run = fixture([Bookmarks.frontPageSplash, Bookmarks.readersCircle, Bookmarks.readersCircle])
        before(&run, event(run)); XCTAssertEqual(held(run, 1).multAdd, 3); XCTAssertEqual(held(run, 2).multAdd, 0)
        run.puzzle?.bossTurn = BossTurnState(); run.puzzle?.bossTurn?.disabledBookmark = 0
        XCTAssertEqual(held(run, 1).multAdd, 0)
        var multiply = fixture([Bookmarks.stopThePresses, Bookmarks.readersCircle])
        before(&multiply, event(multiply)); XCTAssertEqual(held(multiply, 1).multAdd, 0)
    }

    func testArchivePreservesPacketAcrossSkipAndConsumesOnlyEligiblePlacement() throws {
        var run = fixture([Bookmarks.archiveRoom]); var p = run.puzzle!
        p.cluesRemaining = 4; p.phase = .won
        BookmarkMechanics.puzzleWon(run: &run, puzzle: &p)
        let id = run.bookmarks[0].id
        XCTAssertEqual(run.bookmarkState.copies[id]?.archivePoints, 150)
        run.puzzle = nil
        var game = Game(run: run); _ = try game.skipPuzzle(ifCurrent: XCTUnwrap(game.run.currentSkipOffer))
        run = game.run; p.phase = .playing; BookmarkMechanics.puzzleStarted(puzzle: &p); run.puzzle = p
        XCTAssertEqual(before(&run, event(run, eligible: false)).flat, 0)
        XCTAssertEqual(before(&run, event(run)).flat, 150)
        XCTAssertEqual(before(&run, event(run)).flat, 0)
    }

    func testRightToReplyRedirectsOneExistingSelectionWithoutRandomness() throws {
        var run = fixture([Bookmarks.opEd, Bookmarks.rightToReply]); var p = run.puzzle!
        XCTAssertFalse(BookmarkMechanics.hasGameplayHooks(run.bookmarks[1]))
        let encoded = try Game(run: run).encoded()
        XCTAssertEqual(BookmarkMechanics.redirectBossSilence(proposedIndex: 0, run: run, puzzle: &p), 1)
        XCTAssertEqual(BookmarkMechanics.redirectBossSilence(proposedIndex: 0, run: run, puzzle: &p), 0)
        XCTAssertEqual(try Game(run: run).encoded(), encoded)
        run.puzzle = p; run = try restored(run); p = run.puzzle!
        XCTAssertEqual(BookmarkMechanics.redirectBossSilence(proposedIndex: 0, run: run, puzzle: &p), 0)
    }

    func testLegacyTurnKeepsOldRulesUntilNextTurnWithoutInventingFacts() {
        var run = fixture([Bookmarks.editorialBoard, Bookmarks.stopThePresses]); run.puzzle?.bookmarkState.legacyTurn = true
        XCTAssertEqual(held(run).multAdd, 2); XCTAssertEqual(held(run, 1).multX, 3)
        before(&run, event(run))
        XCTAssertEqual(run.puzzle?.bookmarkState.turn.eligiblePlacements, 0)
        var p = run.puzzle!; BookmarkMechanics.turnStarted(puzzle: &p); run.puzzle = p
        XCTAssertEqual(held(run).multAdd, 0); XCTAssertEqual(held(run, 1).multX, 1)
    }

    func testProductionPlacementAndBankUseExpandedRulesAfterSaveResume() throws {
        var game = Game(run: fixture([Bookmarks.marginNotes, Bookmarks.morningEdition]))
        let hand = try XCTUnwrap(game.stackHand(with: .one))
        let placed = try game.place(handIndex: hand, at: Square(0))
        XCTAssertEqual(placed.points, 60)
        game = try Game(decoding: game.encoded())
        let bank = try game.endTurn()
        XCTAssertEqual(bank.pointsGained, 160)
        XCTAssertEqual(game.puzzle?.score, 160)
        let empty = try game.endTurn()
        XCTAssertEqual(empty.pointsGained, 0)
    }

    func testProductionThirdEligiblePlacementRemovesStopThePressesLiveFactor() throws {
        var game = Game(run: fixture([Bookmarks.stopThePresses]))
        for raw in 1...3 {
            let hand = try XCTUnwrap(game.stackHand(with: Digit(raw)!))
            _ = try game.place(handIndex: hand, at: Square(raw - 1))
            XCTAssertEqual(game.puzzle?.pendingMultiplier, raw < 3 ? 3 : 1)
        }
        XCTAssertEqual(try game.endTurn().pointsGained, 60)
    }

    func testSuspensionDisablesPassiveAndHooksWithoutDestroyingCopyGrowth() {
        var run = fixture([Bookmarks.helpWanted, Bookmarks.numberIndex]); let id = run.bookmarks[1].id
        run.bookmarkState.copies[id] = .init(); run.bookmarkState.copies[id]?.numberIndexMult = 8
        run.puzzle?.bookmarkState.suspended = Set(run.bookmarks.map(\.id))
        XCTAssertFalse(BookmarkMechanics.owns(Bookmarks.helpWanted, run: run))
        XCTAssertEqual(held(run, 1).multAdd, 0)
        XCTAssertFalse(BookmarkMechanics.retire(id: id, run: &run))
        run.puzzle?.bookmarkState.suspended = []
        XCTAssertEqual(held(run, 1).multAdd, 8)
    }

    func testSelectiveBuffMultDoesNotMultiplyIneligiblePointsAndRespectsBookmarkOrder() throws {
        for ids in [[Bookmarks.opEd, Bookmarks.stopThePresses], [Bookmarks.stopThePresses, Bookmarks.opEd]] {
            var run = fixture(ids); var p = run.puzzle!
            p.bookmarkState.turn.eligiblePlacements = 1
            p.pendingBase = 100
            p.buffState.pointLots = [BuffPointLot(id: "eligible", points: 50, eligible: true, originalPlacement: true),
                                    BuffPointLot(id: "clue", points: 50, eligible: false, originalPlacement: true)]
            p.buffState.turnMult = [BuffTurnMult(source: UUID(), definition: Buffs.tightDeadline, amount: 3, turn: 1)]
            p.lockScoringOrder(run: run); run.puzzle = p
            let ledger = p.pendingScoringLedger
            // (1+3+1)*3 versus (1+1)*3, or (1+3)*3+1 versus 1*3+1.
            let first = ids[0] == Bookmarks.opEd
            XCTAssertEqual(ledger.total, first ? 1_050 : 850)
            XCTAssertEqual(ledger.eligibleMultiplier, first ? 15 : 13)
            XCTAssertEqual(ledger.ineligibleMultiplier, first ? 6 : 4)
            XCTAssertEqual(try restored(run).puzzle?.pendingScoringLedger, ledger)
        }
    }
}
