import XCTest
@testable import ProbablySudokuEngine

final class ExpandedMarkerTests: XCTestCase {
    private func fixture(_ marker: String? = nil, squares: [Square] = [Square(0)],
                         hand: [Digit] = [.one, .two, .three, .four]) -> RunState {
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        let board = Board(GeneratedPuzzle(solution: solution, isGiven: Array(repeating: false, count: 81)))
        var pool = Pool(blanksOf: board)
        for digit in hand { XCTAssertTrue(pool.take(digit)) }
        var puzzle = PuzzleState(level: 1, slot: .easy, difficulty: .easy, board: board,
            pool: pool, hand: hand, handSize: 4, turnNumber: 1, turnsMax: 10,
            tossedThisPuzzle: 0, tossAllowance: 4, score: 0, target: 1_000_000,
            cluesRemaining: 0, boss: nil, censoredDigit: nil, blockedDigit: nil,
            bossTurn: nil, phase: .playing, keepFillingCoins: 0)
        puzzle.ensureHandIdentities(seed: "marker-tests")
        var run = RunState(seed: "marker-tests", book: .noPressure)
        run.puzzle = puzzle
        if let marker { run.markers = [OwnedMarker(defID: marker, boughtAtLevel: 1, pricePaid: 5, squares: squares)] }
        MarkerRuntime.synchronizeOwnership(run: &run)
        return run
    }

    private func event(_ puzzle: PuzzleState, square: Square = Square(0), digit: Digit = .one,
                       eligible: Bool = true, clue: Bool = false, units: [ProbablySudokuEngine.Unit] = [],
                       card: UUID? = nil) -> CataloguePlacement {
        CataloguePlacement(digit: digit, square: square, cardID: card,
            boardBefore: puzzle.board, handBefore: puzzle.handCards, completedUnits: units,
            positiveClearUnits: units, isClue: clue, isEligible: eligible,
            placementPoints: digit.rawValue * 10, originalPlacementPoints: digit.rawValue * 10,
            turnNumber: puzzle.turnNumber)
    }

    @discardableResult
    private func activate(_ run: inout RunState, square: Square = Square(0), digit: Digit = .one,
                          eligible: Bool = true, clue: Bool = false, units: [ProbablySudokuEngine.Unit] = [],
                          card: UUID? = nil) -> EffectResult {
        var puzzle = run.puzzle!
        let observation = event(puzzle, square: square, digit: digit, eligible: eligible,
                                clue: clue, units: units, card: card)
        var result = EffectResult()
        MarkerRuntime.beforePlacement(observation, run: &run, puzzle: &puzzle, result: &result)
        MarkerRuntime.afterPlacement(observation, run: &run, puzzle: &puzzle)
        run.puzzle = puzzle
        return result
    }

    private func encoded<Value: Encodable>(_ run: Value) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(run)
    }

    func testCatalogueHasFiftyDistinctDefinitionsAndHistoricalIDs() {
        XCTAssertEqual(Markers.all.count, 50)
        XCTAssertEqual(Set(Markers.all.map(\.id)).count, 50)
        for id in [Markers.crimson, Markers.golden, Markers.azure, Markers.ivory, Markers.emerald,
                   Markers.onyx, Markers.silver, Markers.sapphire, Markers.rose, Markers.copper,
                   Markers.violet, Markers.jade] { XCTAssertNotNil(Catalog.item(id), id) }
        XCTAssertTrue(Catalog.item(Markers.jade)!.text.contains("does not cancel"))
        XCTAssertTrue(Markers.all.allSatisfy { !$0.text.isEmpty && $0.listedPrice > 0 })
    }

    func testNewMarkersIgnoreCluesBossZeroesAndKeepFilling() throws {
        for definition in Markers.all.dropFirst(12) {
            for mode in 0..<3 {
                var run = fixture(definition.id)
                if mode == 2 { run.puzzle?.phase = .keepFilling }
                let coins = run.coins, pool = run.puzzle!.pool.total
                let result = activate(&run, eligible: mode != 0, clue: mode == 1)
                XCTAssertEqual(result.flat, 0, definition.id)
                XCTAssertEqual(result.coins, 0, definition.id)
                XCTAssertEqual(run.coins, coins, definition.id)
                XCTAssertEqual(run.puzzle!.pool.total, pool, definition.id)
                XCTAssertTrue(run.pendingItemDecisions.isEmpty, definition.id)
                XCTAssertTrue(run.puzzle!.markerState.counts.isEmpty, definition.id)
                XCTAssertNil(run.markerState.claims.first!.lastTriggeredPuzzle, definition.id)
            }
        }
    }

    func testHearthCountsOnlyOrthogonalBlankNeighbors() {
        var corner = fixture(Markers.hearth)
        XCTAssertEqual(activate(&corner).flat, 40)
        var center = fixture(Markers.hearth, squares: [Square(40)])
        center.puzzle!.board.fill(Square(31), with: .five, by: .given)
        XCTAssertEqual(activate(&center, square: Square(40)).flat, 60)
    }

    func testBridgeRequiresPlayerFilledPairsAndCapsAtTwoAxes() {
        var run = fixture(Markers.bridge, squares: [Square(40)])
        for index in [39, 41, 31, 49] { run.puzzle!.board.fill(Square(index), with: .one, by: .player) }
        XCTAssertEqual(activate(&run, square: Square(40)).flat, 120)
        run.puzzle!.board.fill(Square(39), with: .one, by: .clue)
        XCTAssertEqual(activate(&run, square: Square(40)).flat, 60)
        run.puzzle!.board.fill(Square(31), with: .one, by: .given)
        XCTAssertEqual(activate(&run, square: Square(40)).flat, 0)
    }

    func testConstellationRhythmAndCarbonUsePriorTurnEventsOnly() {
        var run = fixture(Markers.constellation)
        run.puzzle!.markerState.turn.eligibleMarkerTypes = [Markers.hearth, Markers.rose, Markers.crimson, Markers.azure, Markers.golden]
        XCTAssertEqual(activate(&run).flat, 200)
        var rhythm = fixture(Markers.rhythm)
        XCTAssertEqual(activate(&rhythm).flat, 0)
        XCTAssertEqual(activate(&rhythm).flat, 25)
        for _ in 0..<8 { activate(&rhythm) }
        XCTAssertEqual(activate(&rhythm).flat, 150)
        MarkerRuntime.interrupt(.toss, puzzle: &rhythm.puzzle!)
        XCTAssertEqual(activate(&rhythm).flat, 0)
        var carbon = fixture(Markers.carbon)
        activate(&carbon, square: Square(8), digit: .nine)
        activate(&carbon, square: Square(7), digit: .eight)
        XCTAssertEqual(activate(&carbon).flat, 170)
    }

    func testCrossroadsPaysOnceAndFinalePaysTwoDistinctDigits() {
        var cross = fixture(Markers.crossroads)
        XCTAssertEqual(activate(&cross, units: [.row]).flat, 0)
        XCTAssertEqual(activate(&cross, units: [.row, .col]).flat, 300)
        XCTAssertEqual(activate(&cross, units: [.row, .col, .box]).flat, 0)
        var finale = fixture(Markers.finale)
        for digit in [Digit.one, .two, .three] {
            for index in (digit.rawValue * 10)..<(digit.rawValue * 10 + 8) {
                finale.puzzle!.board.fill(Square(index), with: digit, by: .given)
            }
            XCTAssertEqual(activate(&finale, digit: digit).flat, digit == .three ? 0 : 800)
            XCTAssertEqual(activate(&finale, digit: digit).flat, 0)
        }
    }

    func testLedgerMandatoryTradeStopsAfterThreeAndKeepsEligibilityRecord() {
        var run = fixture(Markers.ledger)
        for _ in 0..<3 {
            let result = activate(&run)
            XCTAssertTrue(result.zeroed); XCTAssertEqual(result.coins, 2)
            XCTAssertEqual(result.zeroSourceID, Markers.ledger)
        }
        XCTAssertFalse(activate(&run).zeroed)
        XCTAssertEqual(run.puzzle!.markerState.turn.eligibleMarkerTypes, [Markers.ledger])
    }

    func testEraserRefundsPaidChargesAndDoesNotInventExtraTosses() {
        var run = fixture(Markers.eraser)
        activate(&run)
        XCTAssertEqual(run.puzzle!.markerState.count(Markers.eraser), 0)
        run.puzzle!.tossChargesSpent = 3; run.puzzle!.tossedThisPuzzle = 5
        for _ in 0..<3 { activate(&run) }
        XCTAssertEqual(run.puzzle!.tossChargesSpent, 1)
        XCTAssertEqual(run.puzzle!.tossedThisPuzzle, 5)
        XCTAssertEqual(run.puzzle!.tossesRemaining, 3)
    }

    func testEchoPrismDrawActualPoolCopiesWithoutAdvancingGameStreams() throws {
        for id in [Markers.echo, Markers.prism] {
            var run = fixture(id)
            let streams = try encoded(run.streams)
            let before = run.puzzle!.pool.total
            let priorHand = Set(run.puzzle!.hand)
            activate(&run)
            XCTAssertEqual(run.puzzle!.pool.total, before - 1)
            if id == Markers.echo { XCTAssertEqual(run.puzzle!.hand.last, .one) }
            else { XCTAssertFalse(priorHand.contains(run.puzzle!.hand.last!)) }
            XCTAssertEqual(try encoded(run.streams), streams)
            XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
        }
    }

    func testForecastAndCensusArePureLiveReadingsAndExpireAtTurnEnd() throws {
        var run = fixture(Markers.forecast)
        activate(&run)
        XCTAssertTrue(run.puzzle!.pool.scheduleDraws([.nine, .eight]))
        let before = try encoded(run)
        for _ in 0..<5 { XCTAssertEqual(MarkerRuntime.forecast(run: run, puzzle: run.puzzle!), .nine) }
        XCTAssertEqual(try encoded(run), before)
        XCTAssertTrue(run.puzzle!.pool.take(.nine))
        XCTAssertEqual(MarkerRuntime.forecast(run: run, puzzle: run.puzzle!), .eight)
        MarkerRuntime.ordinaryDrawOccurred(puzzle: &run.puzzle!)
        XCTAssertNil(MarkerRuntime.forecast(run: run, puzzle: run.puzzle!))
        var census = fixture(Markers.census)
        activate(&census, digit: .nine)
        XCTAssertEqual(MarkerRuntime.census(puzzle: census.puzzle!)?.count, 9)
        census.puzzle!.pool.take(.nine)
        XCTAssertEqual(MarkerRuntime.census(puzzle: census.puzzle!)?.count, 8)
        MarkerRuntime.endTurn(puzzle: &census.puzzle!)
        XCTAssertNil(MarkerRuntime.census(puzzle: census.puzzle!))
    }

    func testEscapementAndCollectionCarryProgressButPayOnlyOncePerPuzzle() {
        var clock = fixture(Markers.escapement)
        clock.markerState.escapementProgress = 2
        for _ in 0..<8 { activate(&clock) }
        XCTAssertEqual(clock.puzzle!.turnsMax, 11)
        XCTAssertEqual(clock.markerState.escapementProgress, 0)
        var collection = fixture(Markers.collection)
        collection.markerState.collectionDigits = [.one, .two]
        let before = collection.coins
        activate(&collection, digit: .two)
        XCTAssertEqual(collection.coins, before)
        activate(&collection, digit: .three)
        for digit in Digit.all { activate(&collection, digit: digit) }
        XCTAssertEqual(collection.coins, before + 4)
        XCTAssertTrue(collection.markerState.collectionDigits.isEmpty)
        collection.markers = []
        collection.markerState.collectionDigits = [.one]
        MarkerRuntime.synchronizeOwnership(run: &collection)
        XCTAssertTrue(collection.markerState.collectionDigits.isEmpty)
    }

    func testLampDebtInterestAndStipendHaveDistinctCaps() {
        var lamp = fixture(Markers.lamp)
        activate(&lamp); lamp.puzzle!.cluesRemaining = 0; activate(&lamp)
        XCTAssertEqual(lamp.puzzle!.cluesRemaining, 0)
        var debt = fixture(Markers.debt); debt.coins = -5
        for _ in 0..<8 { activate(&debt) }
        XCTAssertEqual(debt.coins, 0)
        debt.coins = -10; activate(&debt)
        XCTAssertEqual(debt.coins, -9)
        var interest = fixture(Markers.interest)
        for _ in 0..<5 { activate(&interest) }
        XCTAssertEqual(interest.puzzle!.markerState.interestCapIncrease, 2)
        var stipend = fixture(Markers.stipend)
        activate(&stipend)
        MarkerRuntime.interrupt(.wrongPlacement, puzzle: &stipend.puzzle!)
        XCTAssertEqual(MarkerRuntime.stipendPayout(puzzle: stipend.puzzle!), 4)
        MarkerRuntime.interrupt(.solutionAssistance, puzzle: &stipend.puzzle!)
        activate(&stipend)
        XCTAssertEqual(MarkerRuntime.stipendPayout(puzzle: stipend.puzzle!), 0)
    }

    func testUmbrellaPreservesArmForFullWaiverAndBlotterLocksOnlyThisTurn() {
        var run = fixture(Markers.umbrella); activate(&run)
        var puzzle = run.puzzle!
        XCTAssertEqual(MarkerRuntime.reduceWrongPenalty(100, alreadyCancelled: true, puzzle: &puzzle).penalty, 100)
        XCTAssertNotNil(puzzle.markerState.turn.umbrella)
        XCTAssertEqual(MarkerRuntime.reduceWrongPenalty(150, alreadyCancelled: false, puzzle: &puzzle).penalty, 50)
        XCTAssertNil(puzzle.markerState.turn.umbrella)
        var blotter = fixture(Markers.blotter)
        puzzle = blotter.puzzle!
        let protection = MarkerRuntime.beforeWrongPlacement(at: Square(0), run: &blotter, puzzle: &puzzle)
        XCTAssertTrue(protection.cancelsScorePenalty); XCTAssertTrue(protection.returnsCard)
        XCTAssertTrue(puzzle.isBarred(Square(0)))
        MarkerRuntime.endTurn(puzzle: &puzzle)
        XCTAssertFalse(puzzle.isBarred(Square(0)))
        XCTAssertFalse(MarkerRuntime.beforeWrongPlacement(at: Square(0), run: &blotter, puzzle: &puzzle).returnsCard)
    }

    func testRouteLadderAndCounterweightFollowupsResolveBeforeNewSource() {
        var route = fixture(Markers.route); activate(&route)
        XCTAssertEqual(activate(&route, square: Square(3)).flat, 0)
        XCTAssertEqual(activate(&route, square: Square(6)).flat, 120)
        activate(&route)
        activate(&route, square: Square(3))
        XCTAssertEqual(activate(&route, square: Square(4)).flat, 0)
        XCTAssertNil(route.puzzle!.markerState.turn.route)
        var ladder = fixture(Markers.ladder)
        activate(&ladder, digit: .seven)
        activate(&ladder, square: Square(3), digit: .eight)
        XCTAssertEqual(activate(&ladder, square: Square(6), digit: .nine).flat, 90)
        activate(&ladder, digit: .eight)
        XCTAssertNil(ladder.puzzle!.markerState.turn.ladder)
        var pair = fixture(Markers.counterweight)
        activate(&pair, digit: .four)
        XCTAssertEqual(activate(&pair, square: Square(6), digit: .six).flat, 70)
        activate(&pair, digit: .five)
        MarkerRuntime.interrupt(.wrongPlacement, puzzle: &pair.puzzle!)
        XCTAssertEqual(activate(&pair, square: Square(6), digit: .five).flat, 0)
    }

    func testNonClueAssistanceAndExchangeOnlyInterruptTheirSpecifiedContracts() {
        var run = fixture(Markers.route); activate(&run)
        run.puzzle!.markerState.stipend = .active
        MarkerRuntime.interrupt(.solutionAssistance, puzzle: &run.puzzle!)
        XCTAssertNotNil(run.puzzle!.markerState.turn.route)
        XCTAssertEqual(run.puzzle!.markerState.stipend, .broken)
        MarkerRuntime.interrupt(.exchange, puzzle: &run.puzzle!)
        XCTAssertNotNil(run.puzzle!.markerState.turn.route)
        XCTAssertEqual(run.puzzle!.markerState.turn.streak, 0)
        activate(&run, square: Square(3))
        XCTAssertEqual(activate(&run, square: Square(6)).flat, 120)
        activate(&run, square: Square(8), eligible: false)
        XCTAssertEqual(run.puzzle!.markerState.turn.streak, 0)
    }

    func testPressmarkAndBeaconUseExactBoundedFuturePlacements() {
        var press = fixture(Markers.pressmark); activate(&press)
        XCTAssertEqual(activate(&press).flat, 0)
        for _ in 0..<3 { XCTAssertEqual(activate(&press, square: Square(3)).flat, 20) }
        XCTAssertEqual(activate(&press, square: Square(3)).flat, 0)
        var beacon = fixture(Markers.beacon); activate(&beacon, digit: .five)
        XCTAssertEqual(activate(&beacon, square: Square(3), digit: .six).flat, 0)
        XCTAssertEqual(activate(&beacon, square: Square(3), digit: .five).flat, 40)
        MarkerRuntime.endTurn(puzzle: &beacon.puzzle!)
        XCTAssertEqual(activate(&beacon, square: Square(3), digit: .five).flat, 40)
        XCTAssertNil(beacon.puzzle!.markerState.beacon)
    }

    func testKeystoneClueClearExpiresUnpaidAndNaturalBoxPays() {
        var run = fixture(Markers.keystone); activate(&run)
        var puzzle = run.puzzle!, result = EffectResult()
        MarkerRuntime.beforeClear(event(puzzle, clue: true), unit: .box, puzzle: &puzzle, result: &result)
        XCTAssertEqual(result.flat, 0); XCTAssertNil(puzzle.markerState.keystone)
        run.puzzle = puzzle; activate(&run); puzzle = run.puzzle!
        MarkerRuntime.beforeClear(event(puzzle), unit: .row, puzzle: &puzzle, result: &result)
        XCTAssertNotNil(puzzle.markerState.keystone)
        MarkerRuntime.beforeClear(event(puzzle), unit: .box, puzzle: &puzzle, result: &result)
        XCTAssertEqual(result.flat, 120); XCTAssertNil(puzzle.markerState.keystone)
    }

    func testVoucherSurvivesFreeRerollAndExpiresAfterPaidVisit() {
        var run = fixture(Markers.voucher)
        for _ in 0..<4 { activate(&run) }
        MarkerRuntime.shopOpened(run: &run, visitID: 1)
        XCTAssertEqual(MarkerRuntime.discountedRerollCost(2, run: run), 0)
        MarkerRuntime.paidRerollAccepted(ordinaryCost: 0, run: &run)
        XCTAssertEqual(run.markerState.shopVoucherCoins, 2)
        MarkerRuntime.shopOpened(run: &run, visitID: 1)
        XCTAssertEqual(run.markerState.shopVoucherCoins, 2)
        MarkerRuntime.paidRerollAccepted(ordinaryCost: 2, run: &run)
        XCTAssertEqual(MarkerRuntime.discountedRerollCost(3, run: run), 3)
        run.markerState.pendingVoucherCoins = 1
        MarkerRuntime.shopOpened(run: &run, visitID: 2)
        MarkerRuntime.shopClosed(run: &run)
        XCTAssertEqual(run.markerState.shopVoucherCoins, 0)
    }

    func testForkReservationSurvivesSaveAndRewardCannotDuplicateOrCancel() throws {
        var run = fixture(Markers.fork); activate(&run)
        let decision = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertEqual(run.puzzle!.markerState.reservedForkCards.count, 2)
        XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool,
            hand: run.puzzle!.hand + run.puzzle!.markerState.reservedForkCards))
        run = try JSONDecoder().decode(RunState.self, from: encoded(run))
        let before = try encoded(run)
        XCTAssertFalse(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: nil))
        XCTAssertEqual(try encoded(run), before)
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: [decision.options[0].id]))
        XCTAssertEqual(run.puzzle!.hand.count, 5)
        XCTAssertTrue(run.puzzle!.markerState.reservedForkCards.isEmpty)
        let after = try encoded(run)
        XCTAssertFalse(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: [decision.options[1].id]))
        XCTAssertEqual(try encoded(run), after)
        XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
    }

    func testExchangeUsesExactDuplicateCardIdentityAndCancelKeepsHand() throws {
        var run = fixture(Markers.exchange, hand: [.two, .two, .three])
        run.puzzle!.buffState.cleanFinish = BuffChallenge(source: UUID(),
            cards: Set(run.puzzle!.handCards.map(\.id)), turn: 1)
        activate(&run)
        var decision = try XCTUnwrap(run.pendingItemDecisions.first)
        let original = run.puzzle!.handCards
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: nil))
        XCTAssertEqual(run.puzzle!.handCards, original)
        XCTAssertEqual(run.puzzle!.buffState.cleanFinish?.failed, false)
        XCTAssertEqual(run.puzzle!.markerState.count(Markers.exchange), 0)
        activate(&run); decision = try XCTUnwrap(run.pendingItemDecisions.first)
        let selected = try XCTUnwrap(decision.options.first { $0.cardID == original[1].id })
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: [selected.id]))
        XCTAssertTrue(run.puzzle!.handCards.contains { $0.id == original[0].id })
        XCTAssertFalse(run.puzzle!.handCards.contains { $0.id == original[1].id })
        XCTAssertEqual(run.puzzle!.buffState.cleanFinish?.failed, true)
        XCTAssertNotEqual(run.puzzle!.hand.last, .two)
        XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
    }

    func testTiebreakerCapturesDuplicateIDsAndLaterDrawDoesNotJoin() throws {
        var run = fixture(Markers.tiebreaker, hand: [.two, .two]); activate(&run)
        let decision = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: ["accept"]))
        let ids = run.puzzle!.handCards.map(\.id)
        XCTAssertTrue(run.puzzle!.pool.take(.two)); run.puzzle!.appendHandDigits([.two])
        let later = run.puzzle!.handCards.last!.id
        XCTAssertEqual(activate(&run, square: Square(3), digit: .two, card: later).flat, 0)
        XCTAssertEqual(activate(&run, square: Square(3), digit: .two, card: ids[0]).flat, 0)
        XCTAssertEqual(activate(&run, square: Square(4), digit: .two, card: ids[1]).flat, 250)
        XCTAssertEqual(run.puzzle!.markerState.count(Markers.tiebreaker), 1)
    }

    func testWindlassSpendsChargeWithoutTossStatisticAndSweepDoesOpposite() throws {
        var wind = fixture(Markers.windlass); activate(&wind)
        let decision = try XCTUnwrap(wind.pendingItemDecisions.first)
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &wind, id: decision.id, selected: ["accept"]))
        XCTAssertEqual(wind.puzzle!.hand.count, 6)
        XCTAssertEqual(wind.puzzle!.tossesRemaining, 3)
        XCTAssertEqual(wind.puzzle!.tossedThisPuzzle, 0)
        var sweep = fixture(Markers.sweep, hand: [.two, .two, .three]); activate(&sweep)
        let sweepDecision = try XCTUnwrap(sweep.pendingItemDecisions.first)
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &sweep, id: sweepDecision.id, selected: ["digit-2"]))
        XCTAssertEqual(sweep.puzzle!.hand, [.three])
        XCTAssertEqual(sweep.puzzle!.tossedThisPuzzle, 2)
        XCTAssertEqual(sweep.puzzle!.tossesRemaining, 4)
        XCTAssertNil(Conservation.check(board: sweep.puzzle!.board, pool: sweep.puzzle!.pool, hand: sweep.puzzle!.hand))
    }

    func testHarvestExchangesAtMostThreeExactCopiesAndPreservesOthers() throws {
        var run = fixture(Markers.harvest, hand: [.one, .one, .one, .one, .two]); activate(&run)
        let original = run.puzzle!.handCards
        let decision = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: ["accept"]))
        XCTAssertEqual(run.puzzle!.hand.count, 5)
        XCTAssertTrue(run.puzzle!.handCards.contains(original[3]))
        XCTAssertTrue(run.puzzle!.handCards.contains(original[4]))
        XCTAssertEqual(run.puzzle!.hand.filter { $0 == .one }.count, 1)
        XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
    }

    func testCrosscheckReadsOnlySuppliedVisibleValuesNeverSolutionOrFog() throws {
        var run = fixture(Markers.crosscheck); activate(&run)
        let decision = try XCTUnwrap(run.pendingItemDecisions.first)
        let option = try XCTUnwrap(decision.options.first { $0.square == Square(1) })
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: [option.id]))
        run.puzzle!.board.fill(Square(0), with: .one, by: .player)
        var values = Array<Digit?>(repeating: nil, count: 81)
        XCTAssertEqual(MarkerRuntime.visibleCandidates(at: Square(1), puzzle: run.puzzle!, visibleValues: values), Digit.all)
        values[0] = .one
        XCTAssertFalse(MarkerRuntime.visibleCandidates(at: Square(1), puzzle: run.puzzle!, visibleValues: values).contains(.one))
        XCTAssertEqual(MarkerRuntime.visibleCandidates(at: Square(1), puzzle: run.puzzle!, visibleValues: values).count, 8)
    }

    func testBountyIsDeterministicUnmarkedSameBoxAndExpiresWhenClued() throws {
        var first = fixture(Markers.bounty), second = first
        let streams = try encoded(first.streams)
        activate(&first); activate(&second)
        let target = try XCTUnwrap(first.puzzle!.markerState.turn.bounty)
        XCTAssertEqual(target, second.puzzle!.markerState.turn.bounty)
        XCTAssertNotEqual(target.square, Square(0)); XCTAssertEqual(MarkerRuntime.boxIndex(target.square), 0)
        XCTAssertTrue(first.squareIsFree(target.square))
        XCTAssertEqual(try encoded(first.streams), streams)
        XCTAssertEqual(activate(&first, square: target.square).flat, 120)
        XCTAssertEqual(activate(&second, square: target.square, clue: true).flat, 0)
        XCTAssertNil(second.puzzle!.markerState.turn.bounty)
    }

    func testPatinaGrowthIsPerClaimPerPuzzleAndRelocationCarriesHistory() throws {
        var run = fixture(Markers.patina)
        XCTAssertEqual(activate(&run).flat, 0)
        XCTAssertEqual(run.markerState.claims[0].patinaSuccesses, 1)
        activate(&run)
        XCTAssertEqual(run.markerState.claims[0].patinaSuccesses, 1)
        let claim = run.markerState.claims[0].id
        XCTAssertFalse(MarkerRuntime.canRelocateClaim(id: claim, to: Square(1), run: run))
        run.level = 2
        XCTAssertTrue(MarkerRuntime.relocateClaim(id: claim, to: Square(1), run: &run))
        XCTAssertEqual(run.markerState.claims[0].id, claim)
        XCTAssertEqual(activate(&run, square: Square(1)).flat, 25)
        XCTAssertEqual(run.markerState.claims[0].patinaSuccesses, 2)
        run = try JSONDecoder().decode(RunState.self, from: encoded(run))
        XCTAssertEqual(run.markerState.claims[0].patinaSuccesses, 2)
        run.markers = []; MarkerRuntime.synchronizeOwnership(run: &run)
        XCTAssertTrue(run.markerState.claims.isEmpty)
    }

    func testTranspositionMovesFullRecordsAndCannotSwapSameTypeOrTriggeredClaim() {
        var run = fixture(Markers.patina, squares: [Square(0), Square(1)])
        run.markers.append(OwnedMarker(defID: Markers.hearth, boughtAtLevel: 1, pricePaid: 5, squares: [Square(2)]))
        MarkerRuntime.synchronizeOwnership(run: &run)
        run.markerState.claims[0].patinaSuccesses = 7
        let a = run.markerState.claims[0].id, same = run.markerState.claims[1].id, b = run.markerState.claims[2].id
        XCTAssertFalse(MarkerRuntime.canSwapClaims(first: a, second: same, run: run))
        XCTAssertTrue(MarkerRuntime.swapClaims(first: a, second: b, run: &run))
        XCTAssertEqual(run.markerState.claims[0].square, Square(2))
        XCTAssertEqual(run.markerState.claims[0].patinaSuccesses, 7)
        XCTAssertEqual(run.markers[0].entitledSquares(atLevel: 2), 2)
        activate(&run, square: Square(2))
        XCTAssertFalse(MarkerRuntime.canSwapClaims(first: a, second: b, run: run))
    }

    func testPledgeDefersEverythingThenDeclinePlacesOnceWithoutFee() throws {
        var run = fixture(Markers.pledge)
        let hand = run.puzzle!.handCards, coins = run.coins
        XCTAssertTrue(MarkerRuntime.preparePledge(handCardID: hand[0].id, square: Square(0), run: &run))
        let decision = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertEqual(run.puzzle!.handCards, hand); XCTAssertTrue(run.puzzle!.board.isBlank(Square(0)))
        XCTAssertEqual(run.coins, coins)
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: ["decline"]))
        XCTAssertEqual(run.puzzle!.board[Square(0)], .one)
        XCTAssertEqual(run.coins, coins)
        XCTAssertEqual(run.puzzle!.markerState.count(Markers.pledge), 0)
        XCTAssertFalse(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: ["pay"]))
    }

    func testPledgeAcceptPaysExactlyTwoAndAddsOneHundredThroughRealAction() throws {
        var run = fixture(Markers.pledge)
        let before = run.coins
        let result = try Actions.place(&run, handIndex: 0, square: Square(0))
        XCTAssertTrue(result.pendingDecision)
        let decision = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertTrue(try MarkerRuntime.resolveDecision(run: &run, id: decision.id, selected: ["pay"]))
        XCTAssertEqual(run.coins, before - 2)
        XCTAssertEqual(run.puzzle!.pendingBase, 110)
        XCTAssertEqual(run.puzzle!.markerState.count(Markers.pledge), 1)
        XCTAssertNil(run.puzzle!.markerState.acceptedPledgeSquare)
        XCTAssertNil(Conservation.check(board: run.puzzle!.board, pool: run.puzzle!.pool, hand: run.puzzle!.hand))
    }
}
