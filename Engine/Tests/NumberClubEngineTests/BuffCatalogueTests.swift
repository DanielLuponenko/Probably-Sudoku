import XCTest
@testable import ProbablySudokuEngine

final class BuffCatalogueTests: XCTestCase {
    private static let baseline: RunState = {
        var game = Game(seed: "buff-catalogue-contracts")
        try! game.startPuzzle()
        return game.run
    }()

    private func fresh() -> RunState { Self.baseline }

    @discardableResult
    private func give(_ definition: String, run: inout RunState, price: Int = 0) -> OwnedBuff {
        let source = OwnedBuff(defID: definition, pricePaid: price, boughtInShopVisitID: price > 0 ? 7 : nil)
        run.buffs.append(source)
        return source
    }

    @discardableResult
    private func use(_ definition: String, _ choice: BuffChoice = .none,
                     run: inout RunState) throws -> BuffUseOutcome {
        let source = give(definition, run: &run)
        return try BuffRuntime.use(BuffUseRequest(buffID: source.id, context: BuffRuntime.context(run), choice: choice), run: &run)
    }

    private func saved(_ run: RunState) throws -> Data { try Game(run: run).encoded() }
    private func restored(_ run: RunState) throws -> RunState { try Game(decoding: saved(run)).run }

    private func shopRun() -> RunState {
        var run = fresh(); run.puzzle = nil; run.coins = 100
        Shop.open(&run)
        return run
    }

    func testBuffStateEncodingIsStableAndReadsLegacyUnorderedCollections() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let ids = (1...8).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))! }
        var puzzle = BuffPuzzleState()
        puzzle.usedOnce = [Buffs.carbonReceipt, Buffs.returnReceipt, Buffs.rainCheck]
        puzzle.processedPlacements = ["3:8", "1:2", "1:1"]
        puzzle.parity = Dictionary(uniqueKeysWithValues: Square.all.prefix(12).map { ($0, $0.index.isMultiple(of: 2)) })
        puzzle.cleanFinish = BuffChallenge(source: ids[0], cards: Set(ids), completed: Set(ids.prefix(3)), turn: 2)
        puzzle.bracket = BuffBracket(source: ids[1], squares: [Square.all[0], Square.all[40]], completed: [Square.all[40]])
        let canonical = try encoder.encode(puzzle)
        for _ in 0..<20 {
            puzzle = try JSONDecoder().decode(BuffPuzzleState.self, from: encoder.encode(puzzle))
            XCTAssertEqual(try encoder.encode(puzzle), canonical)
        }

        // Synthesized historical Set/Dictionary encodings used the same array
        // shapes, but their element/pair order depended on hash iteration.
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: canonical) as? [String: Any])
        for key in ["usedOnce", "processedPlacements"] {
            legacy[key] = Array((legacy[key] as! [Any]).reversed())
        }
        let pairs = legacy["parity"] as! [Any]
        legacy["parity"] = stride(from: pairs.count - 2, through: 0, by: -2).flatMap { [pairs[$0], pairs[$0 + 1]] }
        for key in ["cleanFinish", "bracket"] {
            var value = legacy[key] as! [String: Any]
            value["completed"] = Array((value["completed"] as! [Any]).reversed())
            if let cards = value["cards"] as? [Any] { value["cards"] = Array(cards.reversed()) }
            legacy[key] = value
        }
        let decoded = try JSONDecoder().decode(BuffPuzzleState.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(try encoder.encode(decoded), canonical)

        var run = BuffRunState()
        run.counterofferVisits = [9, 2, 5]
        run.detourUsed = ["9:1", "1:0", "3:1"]
        run.bossDraftLevels = [1, 9, 3]
        let stableRun = try encoder.encode(run)
        for _ in 0..<20 {
            run = try JSONDecoder().decode(BuffRunState.self, from: encoder.encode(run))
            XCTAssertEqual(try encoder.encode(run), stableRun)
        }
    }

    func testCatalogueContainsAllFortyExactDefinitionsAndPrices() {
        XCTAssertEqual(Buffs.all.count, 40)
        XCTAssertEqual(Set(Buffs.all.map(\.id)).count, 40)
        XCTAssertTrue(Buffs.all.allSatisfy { $0.kind == .buff && !$0.text.isEmpty })
        let prices = [3,3,7,5,3,5,3,6,9,8,6,5,3,4,5,4,3,3,3,7,5,6,5,3,5,3,4,3,8,10,6,8,3,5,5,6,5,6,6,5]
        XCTAssertEqual(Buffs.all.map(\.listedPrice), prices)
        XCTAssertEqual(Catalog.item(Buffs.paperCrane)?.rarity, .uncommon)
    }

    func testEveryTargetlessRetainedBuffUsesRealEffectAndArchive() throws {
        for definition in [Buffs.peek, Buffs.redraw, Buffs.overtime, Buffs.doubleDown,
                           Buffs.insurance, Buffs.secondPrint, Buffs.luckyDip, Buffs.birdSeed, Buffs.freshInk] {
            var run = fresh()
            let before = run.puzzle!
            let source = give(definition, run: &run, price: 5)
            let outcome = try BuffRuntime.use(.init(buffID: source.id, context: BuffRuntime.context(run)), run: &run)
            XCTAssertEqual(outcome.consumedID, source.id)
            XCTAssertFalse(run.buffs.contains { $0.id == source.id })
            XCTAssertEqual(run.puzzle?.buffState.spent.last?.owned.id, source.id)
            XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
            switch definition {
            case Buffs.peek: XCTAssertEqual(run.puzzle!.cluesRemaining, before.cluesRemaining + 1)
            case Buffs.overtime: XCTAssertEqual(run.puzzle!.turnsMax, before.turnsMax + 2)
            case Buffs.doubleDown: XCTAssertTrue(run.puzzle!.armedFlags.contains(.doubleDown))
            case Buffs.insurance: XCTAssertTrue(run.puzzle!.armedFlags.contains(.insurance))
            case Buffs.secondPrint: XCTAssertTrue(run.puzzle!.armedFlags.contains(.secondPrint))
            case Buffs.luckyDip: XCTAssertEqual(run.puzzle!.hand.count, before.hand.count + 2)
            case Buffs.birdSeed: XCTAssertEqual(run.runItemState[definition], Double(run.level))
            case Buffs.freshInk: XCTAssertEqual(run.puzzle!.itemState[definition], 2)
            default: XCTAssertEqual(run.puzzle!.hand.count, before.handSize)
            }
        }
    }

    func testLitmusLocksDigitPersistsAndConsumesOnlyAcceptedPlacement() throws {
        var run = fresh()
        try use(Buffs.litmus, .digit(.five), run: &run)
        run = try restored(run)
        XCTAssertEqual(run.puzzle!.buffState.litmusDigit, .five)
        let blank = run.puzzle!.board.blanks[0]
        XCTAssertEqual(BuffRuntime.litmusReading(at: blank, puzzle: run.puzzle!), run.puzzle!.board.correctDigit(at: blank) == .five)
        let snapshot = try saved(run)
        XCTAssertThrowsError(try Actions.place(&run, handIndex: -1, square: blank))
        XCTAssertEqual(try saved(run), snapshot)
        let card = run.puzzle!.handCards[0]
        BuffRuntime.acceptedAttempt(cardID: card.id, square: blank, puzzle: &run.puzzle!)
        XCTAssertNil(run.puzzle!.buffState.litmusDigit)
        XCTAssertNil(BuffRuntime.litmusReading(at: blank, puzzle: run.puzzle!))
    }

    func testHistoricalPaidLitmusGetsOneSavedChoiceWithoutAReplacementBuff() throws {
        var run = fresh()
        run.puzzle!.armedFlags.insert(.litmus)
        BuffRuntime.prepareLegacyLitmus(&run)
        BuffRuntime.prepareLegacyLitmus(&run)
        XCTAssertEqual(run.pendingItemDecisions.count, 1)
        let choice = run.pendingItemDecisions[0]
        XCTAssertFalse(BuffRuntime.cancel(decisionID: choice.id, run: &run))
        run = try restored(run)
        try BuffRuntime.commit(decisionID: choice.id, selected: ["7"], run: &run)
        XCTAssertEqual(run.puzzle!.buffState.litmusDigit, .seven)
        XCTAssertTrue(run.buffs.isEmpty)
        XCTAssertTrue(run.puzzle!.buffState.spent.isEmpty)
        BuffRuntime.prepareLegacyLitmus(&run)
        XCTAssertTrue(run.pendingItemDecisions.isEmpty)
    }

    func testPaperCraneStacksByChosenDigitAndDuplicateSourceIdentities() throws {
        var run = fresh()
        try use(Buffs.paperCrane, .digit(.three), run: &run)
        try use(Buffs.paperCrane, .digit(.three), run: &run)
        XCTAssertEqual(run.puzzle!.itemState[Buffs.paperCraneKey(.three)], 100)
        XCTAssertEqual(Set(run.puzzle!.scoringBuffSources[Buffs.paperCraneKey(.three)]!).count, 2)
    }

    func testTargetedDrawCutExchangeConserveAndRetainUnselectedCardIdentity() throws {
        var run = fresh()
        let before = run.puzzle!.handCards
        let digit = Digit.all.first { run.puzzle!.pool[$0] > 0 }!
        let poolCount = run.puzzle!.pool[digit]
        try use(Buffs.indexRequest, .digit(digit), run: &run)
        XCTAssertEqual(run.puzzle!.pool[digit], poolCount - 1)
        XCTAssertEqual(Array(run.puzzle!.handCards.prefix(before.count)), before)
        let returned = Array(run.puzzle!.handCards.prefix(3).map(\.id))
        let allowance = run.puzzle!.tossesRemaining
        try use(Buffs.carefulCut, .cards(returned), run: &run)
        XCTAssertEqual(run.puzzle!.tossesRemaining, allowance)
        XCTAssertEqual(run.puzzle!.tossedThisPuzzle, 0)
        XCTAssertTrue(Set(returned).isDisjoint(with: run.puzzle!.handCards.map(\.id)))
        let card = run.puzzle!.handCards[0]
        let take = Digit.all.first { $0 != card.digit && run.puzzle!.pool[$0] > 0 }!
        let count = run.puzzle!.hand.count
        try use(Buffs.fairExchange, .exchange(card: card.id, digit: take), run: &run)
        XCTAssertEqual(run.puzzle!.hand.count, count)
        XCTAssertFalse(run.puzzle!.handCards.contains { $0.id == card.id })
        XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
    }

    func testInvalidCutAndExchangeRollbackBuffRNGAndAllState() throws {
        var run = fresh()
        let source = give(Buffs.carefulCut, run: &run)
        let snapshot = try saved(run)
        let id = run.puzzle!.handCards[0].id
        XCTAssertThrowsError(try BuffRuntime.use(.init(buffID: source.id, context: BuffRuntime.context(run), choice: .cards([id,id])), run: &run))
        XCTAssertEqual(try saved(run), snapshot)
        run.buffs = []
        let exchange = give(Buffs.fairExchange, run: &run)
        let card = run.puzzle!.handCards[0]
        let sameDigitSnapshot = try saved(run)
        XCTAssertThrowsError(try BuffRuntime.use(.init(buffID: exchange.id, context: BuffRuntime.context(run), choice: .exchange(card: card.id, digit: card.digit)), run: &run))
        XCTAssertEqual(try saved(run), sameDigitSnapshot)
    }

    func testTossRestorationDoesNotEraseLifetimeTosses() throws {
        var run = fresh()
        run.puzzle!.spendTossCharge(); run.puzzle!.spendTossCharge(); run.puzzle!.spendTossCharge()
        try use(Buffs.eraserShavings, run: &run)
        XCTAssertEqual(run.puzzle!.tossedThisPuzzle, 3)
        XCTAssertEqual(run.puzzle!.tossChargesSpent, 1)
        try use(Buffs.eraserShavings, run: &run)
        XCTAssertEqual(run.puzzle!.tossesRemaining, run.puzzle!.tossAllowance)
        XCTAssertTrue(BuffRuntime.options(for: Buffs.eraserShavings, run: run).isEmpty)
    }

    func testCollationConsumesOnRevealPersistsAndDrawsScheduledWithoutSecondRNGSample() throws {
        var run = fresh()
        let source = give(Buffs.collation, run: &run)
        let pool = run.puzzle!.pool.total
        let boardStream = run.streams.board.state
        let shopStream = run.streams.shop.state
        let bossStream = run.streams.boss.state
        let outcome = try BuffRuntime.begin(buffID: source.id, run: &run)
        XCTAssertTrue(outcome.requiresDecision)
        XCTAssertEqual(run.puzzle!.pool.total, pool)
        XCTAssertFalse(run.buffs.contains { $0.id == source.id })
        var decision = run.pendingItemDecisions[0]
        XCTAssertFalse(BuffRuntime.cancel(decisionID: decision.id, run: &run))
        run = try restored(run); decision = run.pendingItemDecisions[0]
        let sample = run.buffState.collationChoice!.sample
        let order = Array(sample.indices.reversed())
        try BuffRuntime.commit(decisionID: decision.id, selected: order.map(String.init), run: &run)
        let poolStream = run.streams.pool.state
        let draws = run.puzzle!.pool.draw(&run.streams.pool, count: sample.count)
        XCTAssertEqual(draws, order.map { sample[$0] })
        XCTAssertEqual(run.streams.pool.state, poolStream)
        XCTAssertEqual(run.streams.board.state, boardStream)
        XCTAssertEqual(run.streams.shop.state, shopStream)
        XCTAssertEqual(run.streams.boss.state, bossStream)
        XCTAssertThrowsError(try BuffRuntime.commit(decisionID: decision.id, selected: order.map(String.init), run: &run))
    }

    func testInformationBuffsAreScopedAndProofDoesNotReadHiddenValues() throws {
        var run = fresh()
        XCTAssertNil(BuffRuntime.poolCounts(run.puzzle!))
        try use(Buffs.inventoryCount, run: &run)
        XCTAssertEqual(BuffRuntime.poolCounts(run.puzzle!)?[.one], run.puzzle!.pool[.one])
        let square = run.puzzle!.board.blanks[0]
        try use(Buffs.proofSheet, .unit(.row, square.row), run: &run)
        let candidates = BuffRuntime.proofCandidates(puzzle: run.puzzle!, visibleValues: Array(repeating: nil, count: 81))
        XCTAssertEqual(candidates[square], Digit.all)
        try use(Buffs.foldTest, .squares([square]), run: &run)
        XCTAssertEqual(run.puzzle!.buffState.parity[square], run.puzzle!.board.correctDigit(at: square).rawValue.isMultiple(of: 2))
        BuffRuntime.didBank(puzzle: &run.puzzle!)
        XCTAssertNil(BuffRuntime.poolCounts(run.puzzle!))
        XCTAssertTrue(BuffRuntime.proofCandidates(puzzle: run.puzzle!, visibleValues: run.puzzle!.board.placed).isEmpty)
        XCTAssertNotNil(run.puzzle!.buffState.parity[square])
    }

    func testPassageAndReleaseNoteAreExactOneAttemptExceptions() throws {
        var run = fresh()
        let square = run.puzzle!.board.blanks[0]
        run.puzzle!.bossTurn = BossTurnState()
        run.puzzle!.bossTurn!.greyed = [square]
        run.puzzle!.bossTurn!.blockedHandIndices = [0]
        let id = run.puzzle!.handCards[0].id
        try use(Buffs.passage, .squares([square]), run: &run)
        try use(Buffs.releaseNote, .cards([id]), run: &run)
        XCTAssertTrue(BuffRuntime.passageAllows(square, puzzle: run.puzzle!))
        XCTAssertTrue(BuffRuntime.releaseAllows(cardID: id, puzzle: run.puzzle!))
        let other = run.puzzle!.handCards[1].id
        XCTAssertFalse(BuffRuntime.releaseAllows(cardID: other, puzzle: run.puzzle!))
        BuffRuntime.acceptedAttempt(cardID: id, square: square, puzzle: &run.puzzle!)
        XCTAssertFalse(BuffRuntime.passageAllows(square, puzzle: run.puzzle!))
        XCTAssertFalse(BuffRuntime.releaseAllows(cardID: id, puzzle: run.puzzle!))
        XCTAssertTrue(run.puzzle!.bossTurn!.greyed.contains(square), "The underlying boss restriction remains")
    }

    func testReturnReceiptRestoresExactOriginalAndCannotRecoverItTwice() throws {
        var run = fresh()
        let original = give(Buffs.insurance, run: &run, price: 3)
        try BuffRuntime.use(.init(buffID: original.id, context: BuffRuntime.context(run)), run: &run)
        try use(Buffs.returnReceipt, .recovered(original.id), run: &run)
        let recovered = try XCTUnwrap(run.buffs.first)
        XCTAssertEqual(recovered.id, original.id)
        XCTAssertEqual(recovered.pricePaid, 3)
        XCTAssertEqual(recovered.boughtInShopVisitID, 7)
        XCTAssertFalse(run.puzzle!.armedFlags.contains(.insurance))
        XCTAssertTrue(BuffRuntime.options(for: Buffs.returnReceipt, run: run).isEmpty)
        run = try restored(run)
        XCTAssertEqual(run.buffs[0].id, original.id)
    }

    func testSpentAndCarbonGeneratedArmsCannotBeRecovered() throws {
        var run = fresh()
        try use(Buffs.doubleDown, run: &run)
        _ = run.puzzle!.consume(.doubleDown)
        BuffRuntime.markTriggered(Buffs.doubleDown, puzzle: &run.puzzle!)
        XCTAssertTrue(BuffRuntime.options(for: Buffs.returnReceipt, run: run).isEmpty)
        try use(Buffs.carbonReceipt, run: &run)
        XCTAssertTrue(run.puzzle!.armedFlags.contains(.doubleDown))
        XCTAssertEqual(run.puzzle!.buffState.spent.last?.owned.defID, Buffs.carbonReceipt)
        XCTAssertEqual(run.puzzle!.buffState.spent.last?.effectID, Buffs.doubleDown)
        XCTAssertTrue(run.puzzle!.buffState.spent.last!.generated)
        XCTAssertTrue(BuffRuntime.options(for: Buffs.returnReceipt, run: run).isEmpty)
        XCTAssertTrue(BuffRuntime.options(for: Buffs.carbonReceipt, run: run).isEmpty)
        XCTAssertEqual(run.puzzle!.buffState.lastEligibleUse, Buffs.doubleDown)
    }

    func testTurnMultipliersPartitionCluePointsAndExpireWithoutRefund() throws {
        var run = fresh()
        run.coins = 3
        run.puzzle!.pendingBase = 150
        BuffRuntime.recordPoints(id: "natural", points: 100, eligible: true, originalPlacement: true, puzzle: &run.puzzle!)
        BuffRuntime.recordPoints(id: "onyx-clue", points: 50, eligible: false, originalPlacement: false, puzzle: &run.puzzle!)
        let maxTurns = run.puzzle!.turnsMax
        try use(Buffs.tightDeadline, run: &run)
        try use(Buffs.exchangeRate, .amount(3), run: &run)
        XCTAssertEqual(run.coins, 0)
        XCTAssertEqual(run.puzzle!.turnsMax, maxTurns - 1)
        XCTAssertEqual(BuffRuntime.additionalEligibleMult(run.puzzle!), 6)
        XCTAssertEqual(BuffRuntime.eligibleQueuedPoints(run.puzzle!), 100)
        BuffRuntime.didBank(puzzle: &run.puzzle!)
        XCTAssertEqual(BuffRuntime.additionalEligibleMult(run.puzzle!), 0)
        XCTAssertEqual(run.coins, 0)
    }

    func testRainCheckDebitsOnlyEligibleOriginalPointsAndReturnsOnceNextTurn() throws {
        var run = fresh()
        run.puzzle!.pendingBase = 300
        BuffRuntime.recordPoints(id: "placement", points: 80, eligible: true, originalPlacement: true, puzzle: &run.puzzle!)
        BuffRuntime.recordPoints(id: "clear", points: 120, eligible: true, originalPlacement: false, puzzle: &run.puzzle!)
        BuffRuntime.recordPoints(id: "clue", points: 100, eligible: false, originalPlacement: false, puzzle: &run.puzzle!)
        try use(Buffs.rainCheck, .amount(80), run: &run)
        XCTAssertEqual(run.puzzle!.pendingBase, 220)
        XCTAssertEqual(BuffRuntime.availableRainCheckPoints(run.puzzle!), 0)
        BuffRuntime.didBank(puzzle: &run.puzzle!)
        run.puzzle!.turnNumber += 1; run.puzzle!.pendingBase = 0
        let square = run.puzzle!.board.blanks[0]
        let event = CataloguePlacement(digit: .one, square: square, boardBefore: run.puzzle!.board,
            isEligible: true, placementPoints: 10, turnNumber: 2)
        let awards = BuffRuntime.didPlace(event, run: &run)
        XCTAssertEqual(awards.map(\.points), [160])
        XCTAssertEqual(run.puzzle!.pendingBase, 160)
        XCTAssertEqual(BuffRuntime.availableRainCheckPoints(run.puzzle!), 0)
        XCTAssertTrue(BuffRuntime.didPlace(event, run: &run).isEmpty)
        XCTAssertEqual(run.puzzle!.pendingBase, 160)
    }

    func testQueuedPenaltyRemovesRainFundingAndMissedNextTurnExpires() throws {
        var run = fresh()
        run.puzzle!.pendingBase = 100
        BuffRuntime.recordPoints(id: "p", points: 100, eligible: true, originalPlacement: true, puzzle: &run.puzzle!)
        BuffRuntime.debitQueuedPoints(70, puzzle: &run.puzzle!); run.puzzle!.pendingBase -= 70
        XCTAssertEqual(BuffRuntime.availableRainCheckPoints(run.puzzle!), 30)
        try use(Buffs.rainCheck, .amount(30), run: &run)
        BuffRuntime.didBank(puzzle: &run.puzzle!)
        run.puzzle!.turnNumber += 1
        BuffRuntime.didBank(puzzle: &run.puzzle!)
        XCTAssertNil(run.puzzle!.buffState.rainCheck)
    }

    func testCleanFinishTracksOriginalCardsNotNewDrawsAndFailsOnReturn() throws {
        var run = fresh()
        let cards = run.puzzle!.handCards
        try use(Buffs.cleanFinish, run: &run)
        let blanks = run.puzzle!.board.blanks
        for (index, card) in cards.enumerated() {
            let event = CataloguePlacement(digit: card.digit, square: blanks[index], cardID: card.id,
                boardBefore: run.puzzle!.board, isEligible: true, placementPoints: 10, turnNumber: 1)
            let awards = BuffRuntime.didPlace(event, run: &run)
            XCTAssertEqual(awards.reduce(0) { $0 + $1.points }, index == cards.count - 1 ? 150 : 0)
        }
        XCTAssertTrue(run.puzzle!.buffState.cleanFinish!.paid)
        var failure = fresh()
        try use(Buffs.cleanFinish, run: &failure)
        BuffRuntime.invalidateCards([failure.puzzle!.handCards[0].id], puzzle: &failure.puzzle!)
        XCTAssertTrue(failure.puzzle!.buffState.cleanFinish!.failed)
    }

    func testCrossCutAndOpenBracketRewardOnlyEligibleCompletionOnce() throws {
        var run = fresh()
        let a = run.puzzle!.board.blanks[0]
        let b = run.puzzle!.board.blanks.first { $0.box != a.box }!
        try use(Buffs.openBracket, .squares([a,b]), run: &run)
        try use(Buffs.crossCut, run: &run)
        let first = CataloguePlacement(digit: .one, square: a, boardBefore: run.puzzle!.board,
            completedUnits: [.row], positiveClearUnits: [.row], isEligible: true, placementPoints: 10)
        XCTAssertTrue(BuffRuntime.didPlace(first, run: &run).isEmpty)
        XCTAssertNotNil(run.puzzle!.buffState.crossCut)
        let second = CataloguePlacement(digit: .two, square: b, boardBefore: run.puzzle!.board,
            completedUnits: [.row,.col,.box], positiveClearUnits: [.row,.col,.box], isEligible: true, placementPoints: 20)
        XCTAssertEqual(BuffRuntime.didPlace(second, run: &run).map(\.points).sorted(), [180,200])
        XCTAssertTrue(BuffRuntime.didPlace(second, run: &run).isEmpty)
        XCTAssertNil(run.puzzle!.buffState.crossCut)
    }

    func testClueFilledBracketFailsAndCollateralRestoresAtPuzzleEnd() throws {
        var run = fresh()
        let a = run.puzzle!.board.blanks[0], b = run.puzzle!.board.blanks.first { $0.box != run.puzzle!.board.blanks[0].box }!
        try use(Buffs.openBracket, .squares([a,b]), run: &run)
        BuffRuntime.didPlace(.init(digit: .one, square: a, boardBefore: run.puzzle!.board,
            isClue: true, placementPoints: 10), run: &run)
        XCTAssertTrue(run.puzzle!.buffState.bracket!.failed)
        var pledge = fresh()
        let owned = OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 5)
        pledge.bookmarks = [owned]
        let hand = pledge.puzzle!.hand
        try use(Buffs.collateral, .bookmark(owned.id), run: &pledge)
        XCTAssertEqual(pledge.puzzle!.hand, hand)
        XCTAssertTrue(pledge.puzzle!.bookmarkState.suspended.contains(owned.id))
        XCTAssertFalse(BookmarkMechanics.canRemove(id: owned.id, run: pledge))
        BuffRuntime.didEndPuzzle(&pledge)
        XCTAssertTrue(pledge.puzzle!.bookmarkState.suspended.isEmpty)
        XCTAssertEqual(pledge.bookmarks[0].id, owned.id)
    }

    func testSingleIssueChangesOnlyChosenUnsoldSlotAndRetainsRarity() throws {
        var run = shopRun()
        let original = run.shop!
        let choice = try XCTUnwrap(BuffShop.options(Buffs.singleIssue, run: run).first)
        guard case .offer(let slot) = choice.choice else { return XCTFail("Expected Shop target") }
        let old = original.offers.first { $0.slot == slot }!
        try use(Buffs.singleIssue, choice.choice, run: &run)
        let changed = run.shop!.offers.first { $0.slot == slot }!
        XCTAssertNotEqual(changed.defID, old.defID)
        XCTAssertEqual(changed.def.kind, old.def.kind)
        XCTAssertEqual(changed.def.rarity, old.def.rarity)
        XCTAssertEqual(changed.price, changed.def.listedPrice)
        XCTAssertEqual(run.shop!.rerollsUsed, original.rerollsUsed)
        for offer in original.offers where offer.slot != slot {
            let retained = run.shop!.offers.first { $0.slot == offer.slot }!
            XCTAssertEqual(retained.defID, offer.defID)
            XCTAssertEqual(retained.price, offer.price)
        }
    }

    func testReservationSpendsOnlyAtDepartureAndSurvivesDestinationReroll() throws {
        var run = shopRun()
        let offer = run.shop!.offers[0]
        let source = give(Buffs.reservation, run: &run)
        let outcome = try BuffRuntime.use(.init(buffID: source.id, context: BuffRuntime.context(run), choice: .offer(offer.slot)), run: &run)
        XCTAssertNil(outcome.consumedID)
        XCTAssertTrue(run.buffs.contains { $0.id == source.id })
        run = try restored(run)
        BuffShop.leave(&run)
        XCTAssertFalse(run.buffs.contains { $0.id == source.id })
        XCTAssertEqual(run.buffState.reservation?.definition, offer.defID)
        run.shop = nil
        Shop.open(&run)
        BuffShop.didOpen(&run, initialStock: true)
        let destination = run.shop!.visitID
        XCTAssertEqual(run.shop!.offers.filter { !$0.sold && $0.defID == offer.defID }.count, 1)
        XCTAssertEqual(run.shop!.offers.first { $0.defID == offer.defID }?.price, offer.price)
        var fresh = Shop.stock(&run); fresh.visitID = destination; fresh.rerollsUsed = 1
        run.shop = fresh
        BuffShop.didOpen(&run, initialStock: false)
        XCTAssertEqual(run.shop!.offers.filter { !$0.sold && $0.defID == offer.defID }.count, 1)
        BuffShop.leave(&run)
        XCTAssertNil(run.buffState.reservation)
    }

    func testCancelledOrBoughtReservationKeepsItsSource() throws {
        var run = shopRun()
        let source = give(Buffs.reservation, run: &run)
        let slot = run.shop!.offers[0].slot
        try BuffRuntime.use(.init(buffID: source.id, context: BuffRuntime.context(run), choice: .offer(slot)), run: &run)
        BuffShop.cancelReservation(&run)
        BuffShop.leave(&run)
        XCTAssertTrue(run.buffs.contains { $0.id == source.id })
        XCTAssertNil(run.buffState.reservation)
        try BuffRuntime.use(.init(buffID: source.id, context: BuffRuntime.context(run), choice: .offer(slot)), run: &run)
        run.shop!.offers[0].sold = true
        BuffShop.didBuy(slot: slot, run: &run)
        BuffShop.leave(&run)
        XCTAssertTrue(run.buffs.contains { $0.id == source.id })
    }

    func testReservationRejectsShopImmediatelyBeforeFinalBoss() {
        var run = shopRun()
        run.level = 9; run.slot = .medium
        XCTAssertTrue(BuffShop.options(Buffs.reservation, run: run).isEmpty)
        run.slot = .easy
        XCTAssertFalse(BuffShop.options(Buffs.reservation, run: run).isEmpty)
    }

    func testCounterofferActualPaidPriceAndSingleVisitLimit() throws {
        var run = shopRun()
        let offer = run.shop!.offers.first { $0.def.kind == .marker }!
        try use(Buffs.counteroffer, .offer(offer.slot), run: &run)
        XCTAssertEqual(run.shop!.offers.first { $0.slot == offer.slot }?.price, max(1, offer.price - 4))
        XCTAssertTrue(BuffShop.options(Buffs.counteroffer, run: run).isEmpty)
        try Shop.buy(&run, slot: offer.slot)
        XCTAssertEqual(run.markers.last?.pricePaid, max(1, offer.price - 4))
    }

    func testSupplementAddsExactlyOneInitialOfferAndFreePressPreservesFreeReroll() throws {
        var run = fresh()
        try use(Buffs.supplement, .category(.buff), run: &run)
        run.puzzle = nil
        Shop.open(&run)
        BuffShop.didOpen(&run, initialStock: true)
        XCTAssertEqual(run.shop!.offers.filter { $0.def.kind == .buff }.count, 2)
        XCTAssertNil(run.buffState.supplement)
        try use(Buffs.freePress, run: &run)
        XCTAssertEqual(BuffShop.rerollPrice(run), max(0, run.shop!.rerollCost - 6))
        BuffShop.willReroll(&run, ordinaryCost: 0)
        XCTAssertNotNil(run.buffState.freePressSource)
        BuffShop.willReroll(&run, ordinaryCost: 8)
        XCTAssertNil(run.buffState.freePressSource)
        let visit = run.shop!.visitID
        run.shop = Shop.stock(&run); run.shop!.visitID = visit
        BuffShop.didOpen(&run, initialStock: false)
        XCTAssertEqual(run.shop!.offers.filter { $0.def.kind == .buff }.count, 1)
    }

    func testNewEditionCreatesFreshSameRarityCopyWithoutPurchaseOrSale() throws {
        var run = shopRun()
        let old = OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 5, boughtInShopVisitID: 3)
        run.bookmarks = [old]
        let coins = run.coins
        try use(Buffs.newEdition, .bookmark(old.id), run: &run)
        XCTAssertEqual(run.bookmarks.count, 1)
        XCTAssertNotEqual(run.bookmarks[0].id, old.id)
        XCTAssertNotEqual(run.bookmarks[0].defID, old.defID)
        XCTAssertEqual(run.bookmarks[0].def.rarity, old.def.rarity)
        XCTAssertEqual(run.bookmarks[0].pricePaid, 0)
        XCTAssertNil(run.bookmarks[0].boughtInShopVisitID)
        XCTAssertEqual(run.coins, coins)
    }

    func testPocketInsertTargetCountsTheExactActivatingBuffAsConsumed() throws {
        for definition in [Buffs.newEdition, Buffs.collateral] {
            var run = definition == Buffs.newEdition ? shopRun() : fresh()
            let pocket = OwnedBookmark(defID: Bookmarks.pocketInsert, boughtAtLevel: 1, pricePaid: 8)
            run.bookmarks = [pocket]
            let firstCopy = give(definition, run: &run)
            let chosenCopy = give(definition, run: &run)
            let kept = give(Buffs.peek, run: &run)
            XCTAssertEqual(BookmarkMechanics.capacity(run: run), 3)
            XCTAssertFalse(BookmarkMechanics.canRemove(id: pocket.id, run: run),
                           "Ordinary sale must still reject losing an occupied third slot")
            XCTAssertTrue(BuffRuntime.canUse(buffID: chosenCopy.id, run: run))
            try BuffRuntime.begin(buffID: chosenCopy.id, run: &run)
            let cancelled = try XCTUnwrap(run.pendingItemDecisions.first)
            XCTAssertTrue(BuffRuntime.cancel(decisionID: cancelled.id, run: &run))
            XCTAssertEqual(run.buffs.map(\.id), [firstCopy.id, chosenCopy.id, kept.id])
            XCTAssertEqual(run.bookmarks.map(\.id), [pocket.id])
            XCTAssertFalse(run.puzzle?.bookmarkState.suspended.contains(pocket.id) ?? false)

            try BuffRuntime.begin(buffID: chosenCopy.id, run: &run)
            let choice = try XCTUnwrap(run.pendingItemDecisions.first)
            run = try restored(run)
            try BuffRuntime.commit(decisionID: choice.id, selected: [pocket.id.uuidString], run: &run)
            XCTAssertEqual(run.buffs.map(\.id), [firstCopy.id, kept.id])
            XCTAssertEqual(BookmarkMechanics.capacity(run: run), 2)
            XCTAssertLessThanOrEqual(run.buffs.count, BookmarkMechanics.capacity(run: run))
            if definition == Buffs.collateral {
                XCTAssertTrue(run.puzzle!.bookmarkState.suspended.contains(pocket.id))
                XCTAssertEqual(run.puzzle!.buffState.spent.last?.owned.id, chosenCopy.id)
            } else {
                XCTAssertNotEqual(run.bookmarks.first?.id, pocket.id)
                XCTAssertNotEqual(run.bookmarks.first?.defID, pocket.defID)
            }
            let after = try saved(run)
            XCTAssertThrowsError(try BuffRuntime.commit(decisionID: choice.id, selected: [pocket.id.uuidString], run: &run))
            XCTAssertEqual(try saved(run), after)
        }
    }

    func testPocketInsertTargetStillRejectsActualOverflowAfterBuffCost() throws {
        for definition in [Buffs.newEdition, Buffs.collateral] {
            var run = definition == Buffs.newEdition ? shopRun() : fresh()
            let pocket = OwnedBookmark(defID: Bookmarks.pocketInsert, boughtAtLevel: 1, pricePaid: 8)
            run.bookmarks = [pocket]
            let source = give(definition, run: &run)
            for _ in 0..<3 { give(Buffs.peek, run: &run) }
            let before = try saved(run)
            XCTAssertFalse(BuffRuntime.options(for: definition, run: run, consuming: source.id)
                .contains { $0.choice == .bookmark(pocket.id) })
            XCTAssertThrowsError(try BuffRuntime.use(.init(buffID: source.id, context: BuffRuntime.context(run),
                                                        choice: .bookmark(pocket.id)), run: &run))
            XCTAssertEqual(try saved(run), before)
        }
    }

    func testDetourAndBossDraftRevealSavedAlternativesWithoutShiftingAnyStream() throws {
        for definition in [Buffs.detour, Buffs.bossDraft] {
            var run = RunState(seed: "buff-route-domain")
            let source = give(definition, run: &run)
            let streams = [run.streams.board.state, run.streams.pool.state, run.streams.shop.state, run.streams.boss.state]
            let skip = run.currentSkipOffer
            try BuffRuntime.begin(buffID: source.id, run: &run)
            XCTAssertFalse(run.buffs.contains { $0.id == source.id })
            XCTAssertEqual([run.streams.board.state, run.streams.pool.state, run.streams.shop.state, run.streams.boss.state], streams)
            XCTAssertEqual(run.currentSkipOffer, skip)
            let originalDecision = run.pendingItemDecisions[0]
            XCTAssertFalse(BuffRuntime.cancel(decisionID: originalDecision.id, run: &run))
            run = try restored(run)
            XCTAssertEqual(run.pendingItemDecisions[0], originalDecision)
            try BuffRuntime.commit(decisionID: originalDecision.id, selected: ["alternate"], run: &run)
            if definition == Buffs.detour {
                XCTAssertEqual(BuffRoutes.selectedBoard(run: run)?.placed, run.buffState.layoutChoice?.alternate.placed)
                XCTAssertTrue(BuffRuntime.options(for: definition, run: run).isEmpty)
            } else {
                XCTAssertEqual(run.pendingBoss, run.buffState.bossChoice?.alternate)
                XCTAssertNotEqual(run.pendingBoss, run.buffState.bossChoice?.original)
                XCTAssertTrue(BuffRuntime.options(for: definition, run: run).isEmpty)
            }
        }
    }

    func testMarkerRelocationBuffsPreserveClaimIdentityAndOtherSquares() throws {
        var run = fresh()
        let blanks = run.puzzle!.board.blanks
        run.markers = [OwnedMarker(defID: Markers.ivory, boughtAtLevel: 1, pricePaid: 5, squares: [blanks[0],blanks[1]]),
                       OwnedMarker(defID: Markers.jade, boughtAtLevel: 1, pricePaid: 6, squares: [blanks[2]])]
        let before = MarkerRuntime.relocatableClaims(run: run)
        let ivory = before.first { $0.markerID == Markers.ivory && $0.square == blanks[0] }!
        let jade = before.first { $0.markerID == Markers.jade }!
        try use(Buffs.rebind, .claim(ivory.id, destination: blanks[3]), run: &run)
        let moved = MarkerRuntime.relocatableClaims(run: run)
        XCTAssertEqual(moved.first { $0.id == ivory.id }?.square, blanks[3])
        XCTAssertTrue(run.markers.first { $0.defID == Markers.ivory }!.squares.contains(blanks[1]))
        try use(Buffs.transposition, .claims(ivory.id, jade.id), run: &run)
        let swapped = MarkerRuntime.relocatableClaims(run: run)
        XCTAssertEqual(swapped.first { $0.id == ivory.id }?.square, blanks[2])
        XCTAssertEqual(swapped.first { $0.id == jade.id }?.square, blanks[3])
        XCTAssertEqual(run.markers.first { $0.defID == Markers.ivory }?.pricePaid, 5)
    }

    func testUnpaidMultiStepCancellationAndStaleDecisionCannotSpendAnotherCopy() throws {
        var run = fresh()
        let source = give(Buffs.fairExchange, run: &run)
        let initialCards = run.puzzle!.handCards
        try BuffRuntime.begin(buffID: source.id, run: &run)
        let first = run.pendingItemDecisions[0]
        try BuffRuntime.commit(decisionID: first.id, selected: [first.options[0].id], run: &run)
        let second = run.pendingItemDecisions[0]
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertTrue(BuffRuntime.cancel(decisionID: second.id, run: &run))
        XCTAssertEqual(run.puzzle!.handCards, initialCards)
        XCTAssertEqual(run.buffs[0].id, source.id)
        XCTAssertThrowsError(try BuffRuntime.commit(decisionID: second.id, selected: [second.options[0].id], run: &run))
        XCTAssertEqual(run.buffs[0].id, source.id)
    }

    func testPaywallBuffborgerKeepFillingAndHistoricalSkipGuards() throws {
        var run = fresh()
        run.puzzle!.boss = .paywall
        for definition in [Buffs.peek, Buffs.litmus, Buffs.foldTest] {
            XCTAssertTrue(BuffRuntime.options(for: definition, run: run).isEmpty)
        }
        run.puzzle!.boss = .buffborger
        for definition in Buffs.all { XCTAssertTrue(BuffRuntime.options(for: definition.id, run: run).isEmpty, definition.id) }
        run.puzzle!.boss = nil; run.puzzle!.phase = .keepFilling
        for definition in Buffs.all where ![Buffs.peek, Buffs.redraw, Buffs.overtime, Buffs.luckyDip, Buffs.birdSeed].contains(definition.id) {
            XCTAssertTrue(BuffRuntime.options(for: definition.id, run: run).isEmpty, definition.id)
        }
        var old = RunState(seed: "historical-skip-table")
        old.catalogueVersion = 1
        let allowed = Set(Buffs.all.prefix(11).map(\.id))
        for level in 1...9 {
            for slot in [PuzzleSlot.easy, .medium] {
                let offer = SkipOffer.offer(seed: old.seed, level: level, slot: slot)
                XCTAssertTrue(allowed.contains(offer.buffID))
                XCTAssertEqual(offer, SkipOffer.offer(seed: old.seed, level: level, slot: slot, version: 1))
            }
        }
        XCTAssertNil(try restored(old).puzzle)
    }
}
