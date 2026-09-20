import XCTest
@testable import ProbablySudokuEngine

final class ExpandedBossHandTests: XCTestCase {
    private func fixture(_ boss: BossModifier, hand: [Digit] = [.one, .two, .three, .four, .five, .six],
                         blanks: [Square] = Square.all) -> RunState {
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        let blankSet = Set(blanks)
        let board = Board(GeneratedPuzzle(solution: solution, isGiven: Square.all.map { !blankSet.contains($0) }))
        var pool = Pool(blanksOf: board)
        for digit in hand { XCTAssertTrue(pool.take(digit)) }
        var puzzle = PuzzleState(level: 9, slot: .boss, difficulty: .boss, board: board,
            pool: pool, hand: hand, handSize: hand.count, turnNumber: 1, turnsMax: 10,
            tossedThisPuzzle: 0, tossAllowance: 4, score: 0, target: 1_000_000,
            cluesRemaining: 8, boss: boss, censoredDigit: nil, blockedDigit: nil,
            bossTurn: nil, phase: .playing, keepFillingCoins: 0)
        var run = RunState(seed: "boss-hand-tests", book: .noPressure)
        puzzle.ensureHandIdentities(seed: run.seed)
        BossRuntime.puzzleStarted(run: run, puzzle: &puzzle)
        puzzle.startBossTurn(&run)
        run.puzzle = puzzle
        return run
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }
    private func restored(_ run: RunState) throws -> RunState {
        try JSONDecoder().decode(RunState.self, from: encoded(run))
    }
    private func checkConservation(_ run: RunState, file: StaticString = #filePath, line: UInt = #line) {
        let p = run.puzzle!
        XCTAssertNil(Conservation.check(board: p.board, pool: p.pool,
                                       hand: p.hand + p.markerState.reservedForkCards), file: file, line: line)
    }
    private func put(_ digit: Digit, at square: Square, in run: inout RunState) throws -> PlacementOutcome {
        try Actions.place(&run, handIndex: XCTUnwrap(run.puzzle?.hand.firstIndex(of: digit)), square: square)
    }

    func testGalleyArrivalOrderSurvivesSortingAndRestoreAndAdvancesAfterPlay() throws {
        var run = fixture(.galleyQueue)
        let original = run.puzzle!.handCards
        let reversed = Array(original.reversed())
        run.puzzle!.hand = reversed.map(\.digit); run.puzzle!.handCardIDs = reversed.map(\.id)
        run = try restored(run)
        XCTAssertEqual(run.puzzle!.hand.indices.filter { !run.puzzle!.isBlocked(handIndex: $0) }.map { reversed[$0].id },
                       [original[1].id, original[0].id])
        let before = try encoded(run)
        XCTAssertThrowsError(try Actions.place(&run, handIndex: 0, square: Square(5)))
        XCTAssertEqual(try encoded(run), before)
        _ = try put(.one, at: Square(0), in: &run)
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: run.puzzle!.hand.firstIndex(of: .three)!))
        checkConservation(run)
    }

    func testGalleySkipsIndependentBarsAndDoesNotForbidOrdinaryToss() throws {
        var run = fixture(.galleyQueue, hand: [.one, .two, .three, .four])
        run.puzzle!.obstacleBlockedDigits = [.one]
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: 1))
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: 2))
        XCTAssertTrue(run.puzzle!.isBlocked(handIndex: 3))
        XCTAssertFalse(run.puzzle!.isTossBlocked(handIndex: 3))
        _ = try Actions.toss(&run, handIndex: 3)
        XCTAssertEqual(run.puzzle!.hand, [.one, .two, .three])
        checkConservation(run)
    }

    func testBookendsExcludesBarsAndAllowsEveryExtremeCopy() throws {
        var run = fixture(.bookends, hand: [.one, .two, .two, .three, .four, .five])
        run.puzzle!.obstacleBlockedDigits = [.one, .five]
        XCTAssertEqual(run.puzzle!.hand.indices.filter { !run.puzzle!.isBlocked(handIndex: $0) }, [1, 2, 4])
        XCTAssertThrowsError(try Actions.revealClue(&run, handIndex: 3))
        _ = try Actions.revealClue(&run, handIndex: 1)
        XCTAssertEqual(run.puzzle!.cluesRemaining, 7)
        checkConservation(run)
    }

    func testReprintOnlyRepeatsReleaseAndNewUnusedDrawRestoresRestriction() throws {
        var run = fixture(.reprintBan, hand: [.one, .one])
        _ = try put(.one, at: Square(0), in: &run)
        XCTAssertEqual(run.puzzle!.bossState.usedDigits, [.one])
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: 0))
        XCTAssertTrue(run.puzzle!.pool.take(.two)); run.puzzle!.appendHandDigits([.two])
        XCTAssertTrue(run.puzzle!.isBlocked(handIndex: 0))
        run.puzzle!.obstacleBlockedDigits = [.two]
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: 0))
        _ = try Actions.endTurn(&run)
        XCTAssertTrue(run.puzzle!.bossState.usedDigits.isEmpty)
        checkConservation(run)
    }

    func testCorrectClueCountsForReprintAndWrongAttemptDoesNot() throws {
        var run = fixture(.reprintBan, hand: [.one, .two, .three])
        _ = try Actions.useClue(&run, square: Square(0))
        XCTAssertEqual(run.puzzle!.bossState.usedDigits, [.one])
        XCTAssertTrue(run.puzzle!.isBlocked(handIndex: 0))
        _ = try put(.two, at: Square(2), in: &run)
        XCTAssertEqual(run.puzzle!.bossState.usedDigits, [.one])
        checkConservation(run)
    }

    func testCollatorReleasesAfterTwoFillsIncludingClueAndNewCardsAreOpen() throws {
        var run = fixture(.collator, hand: [.one, .two, .three, .four])
        let waiting = Set(run.puzzle!.handCards.suffix(2).map(\.id))
        XCTAssertEqual(run.puzzle!.bossState.waitingIDs, waiting)
        XCTAssertTrue(run.puzzle!.pool.take(.five)); run.puzzle!.appendHandDigits([.five])
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: 4))
        _ = try put(.one, at: Square(0), in: &run)
        XCTAssertEqual(run.puzzle!.bossState.correctFills, 1)
        XCTAssertFalse(run.puzzle!.bossState.waitingIDs.isEmpty)
        _ = try Actions.useClue(&run, square: Square(1))
        XCTAssertEqual(run.puzzle!.bossState.correctFills, 2)
        XCTAssertTrue(run.puzzle!.bossState.waitingIDs.isEmpty)
        checkConservation(run)
    }

    func testCollatorFallbackUsesVisibleBarsAndTossNotHiddenCorrectness() throws {
        var run = fixture(.collator, hand: [.one, .two, .three, .four])
        run.puzzle!.obstacleBlockedDigits = [.one, .two]
        BossRuntime.synchronizeHand(puzzle: &run.puzzle!)
        XCTAssertTrue(run.puzzle!.bossState.waitingIDs.isEmpty)
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: 2))
        var tossed = fixture(.collator, hand: [.one, .two, .three, .four])
        _ = try Actions.toss(&tossed, handIndex: 0)
        XCTAssertFalse(tossed.puzzle!.bossState.waitingIDs.isEmpty)
        _ = try Actions.toss(&tossed, handIndex: 0)
        XCTAssertTrue(tossed.puzzle!.bossState.waitingIDs.isEmpty)
        XCTAssertEqual(tossed.puzzle!.turnNumber, 1)
        checkConservation(tossed)
    }

    func testReturnSlipAndJadeReturnExactlyOneIdentityAndPenaltyStillApplies() throws {
        var run = fixture(.returnSlip, hand: [.one, .one, .two])
        run.markers = [OwnedMarker(defID: Markers.jade, boughtAtLevel: 1, pricePaid: 4, squares: [Square(1)])]
        MarkerRuntime.synchronizeOwnership(run: &run)
        let card = run.puzzle!.handCards[0]
        run.puzzle!.pendingBase = 100
        let result = try Actions.place(&run, handIndex: 0, square: Square(1))
        XCTAssertTrue(result.returnedToHand); XCTAssertEqual(result.penalty, 50)
        XCTAssertEqual(run.puzzle!.handCards.filter { $0.id == card.id }, [card])
        XCTAssertEqual(run.puzzle!.bossState.sealedIDs, [card.id])
        XCTAssertEqual(run.puzzle!.pendingBase, 50)
        let sealedIndex = run.puzzle!.handCardIDs.firstIndex(of: card.id)!
        XCTAssertTrue(run.puzzle!.isBlocked(handIndex: sealedIndex))
        XCTAssertTrue(run.puzzle!.isTossBlocked(handIndex: sealedIndex))
        XCTAssertFalse(run.puzzle!.isBlocked(handIndex: 0), "Other copy is not sealed")
        let before = try encoded(run)
        XCTAssertThrowsError(try Actions.revealClue(&run, handIndex: sealedIndex))
        XCTAssertThrowsError(try Actions.toss(&run, handIndex: sealedIndex))
        XCTAssertEqual(try encoded(run), before)
        run = try restored(run)
        _ = try Actions.endTurn(&run)
        XCTAssertTrue(run.puzzle!.bossState.sealedIDs.isEmpty)
        XCTAssertTrue(run.puzzle!.handCardIDs.contains(card.id))
        checkConservation(run)
    }

    func testProtectedReturnSlipStillReturnsAndExplicitReleaseAllowsToss() throws {
        var run = fixture(.returnSlip, hand: [.one, .two, .three])
        run.puzzle!.armedFlags.insert(.insurance)
        let card = run.puzzle!.handCards[0]
        let result = try Actions.place(&run, handIndex: 0, square: Square(1))
        XCTAssertEqual(result.penalty, 0)
        run.puzzle!.buffState.releasedCard = card.id; run.puzzle!.buffState.releaseTurn = 1
        _ = try Actions.toss(&run, handIndex: run.puzzle!.handCardIDs.firstIndex(of: card.id)!)
        XCTAssertFalse(run.puzzle!.handCardIDs.contains(card.id))
        XCTAssertTrue(run.puzzle!.bossState.sealedIDs.isEmpty)
        XCTAssertNil(run.puzzle!.buffState.releasedCard)
        checkConservation(run)
    }

    func testWrongLastCardPaysPenaltyThenBanksOnceButReturnedCardDoesNot() throws {
        var run = fixture(.bookends, hand: [.one])
        run.puzzle!.pendingBase = 100
        let wrong = try Actions.place(&run, handIndex: 0, square: Square(1))
        XCTAssertEqual(wrong.penalty, 50)
        XCTAssertEqual(wrong.automaticTurn?.pointsGained, 50)
        XCTAssertEqual(run.puzzle!.turnNumber, 2)
        XCTAssertEqual(run.puzzle!.score, 50)
        checkConservation(run)
        var returned = fixture(.returnSlip, hand: [.one])
        let slip = try Actions.place(&returned, handIndex: 0, square: Square(1))
        XCTAssertNil(slip.automaticTurn)
        XCTAssertEqual(returned.puzzle!.turnNumber, 1)
        XCTAssertEqual(returned.puzzle!.hand, [.one])
        checkConservation(returned)
    }

    func testLastTossBanksOnceAndRefillsWithoutDuplicateTurn() throws {
        var run = fixture(.collator, hand: [.one])
        run.puzzle!.pendingBase = 20
        XCTAssertEqual(try Actions.toss(&run, handIndex: 0), .one)
        XCTAssertEqual(run.puzzle!.turnNumber, 2)
        XCTAssertEqual(run.puzzle!.score, 20)
        XCTAssertEqual(run.puzzle!.hand.count, 1)
        XCTAssertNil(try Actions.finishAutomaticTurnIfNeeded(&run))
        checkConservation(run)
    }

    func testRebinderReturnsAllExactLeftoversAndConservesFreshHand() throws {
        var run = fixture(.rebinder, hand: [.one, .two, .three])
        let old = Set(run.puzzle!.handCardIDs)
        run.puzzle!.pendingBase = 100
        let turn = try Actions.endTurn(&run)
        XCTAssertEqual(turn.pointsGained, 100)
        XCTAssertEqual(run.puzzle!.hand.count, 3)
        XCTAssertTrue(old.isDisjoint(with: run.puzzle!.handCardIDs))
        XCTAssertEqual(run.puzzle!.tossedThisPuzzle, 0)
        XCTAssertEqual(run.puzzle!.turnNumber, 2)
        checkConservation(run)
    }

    func testRebinderNearCompletionDoesNotInventSupply() throws {
        var run = fixture(.rebinder, hand: [.one, .two], blanks: [Square(0), Square(1)])
        run.puzzle!.handSize = 7
        _ = try Actions.endTurn(&run)
        XCTAssertEqual(run.puzzle!.hand.sorted(), [.one, .two])
        XCTAssertTrue(run.puzzle!.pool.isEmpty)
        checkConservation(run)
    }

    func testCourierDefersWithoutDrawingOrAdvancingRNGAndCountsTowardRefill() throws {
        var run = fixture(.lateCourier, hand: [.one, .two, .three, .four])
        _ = try put(.one, at: Square(0), in: &run)
        _ = try put(.two, at: Square(1), in: &run)
        let beforePool = try encoded(run.puzzle!.pool), beforeStreams = try encoded(run.streams)
        XCTAssertTrue(BossRuntime.deferAutomaticDraw(count: 1, sourceID: Markers.sapphire, puzzle: &run.puzzle!))
        XCTAssertTrue(BossRuntime.deferAutomaticDraw(count: 1, sourceID: Bookmarks.crosswordDaily, puzzle: &run.puzzle!))
        XCTAssertEqual(try encoded(run.puzzle!.pool), beforePool)
        XCTAssertEqual(try encoded(run.streams), beforeStreams)
        XCTAssertEqual(run.puzzle!.hand.count, 2)
        var copy = try restored(run)
        let turn = try Actions.endTurn(&run), restoredTurn = try Actions.endTurn(&copy)
        XCTAssertEqual(turn.numbersDrawn, 2)
        XCTAssertEqual(restoredTurn, turn)
        XCTAssertEqual(run.puzzle!.hand.count, 4)
        XCTAssertTrue(run.puzzle!.bossState.deferredDraws.isEmpty)
        XCTAssertEqual(try encoded(copy), try encoded(run))
        checkConservation(run)
    }

    func testCourierRealSapphireDefersAndPrismUsesDeliveryHand() throws {
        var run = fixture(.lateCourier, hand: [.one, .two, .three])
        run.markers = [OwnedMarker(defID: Markers.sapphire, boughtAtLevel: 1, pricePaid: 4, squares: [Square(0)])]
        MarkerRuntime.synchronizeOwnership(run: &run)
        let claim = try XCTUnwrap(run.markerState.claims.first)
        let result = try put(.one, at: Square(0), in: &run)
        XCTAssertEqual(result.numbersDrawn, 0)
        XCTAssertEqual(run.puzzle!.bossState.deferredDraws.reduce(0) { $0 + $1.count }, 1)
        XCTAssertEqual(run.puzzle!.bossState.deferredDraws.first?.sourceID, Markers.sapphire)
        XCTAssertEqual(run.puzzle!.bossState.deferredDraws.first?.sourceClaimID, claim.id)
        XCTAssertNil(run.puzzle!.bossState.deferredDraws.first?.sourceInstanceID)
        XCTAssertEqual(try restored(run).puzzle!.bossState.deferredDraws,
                       run.puzzle!.bossState.deferredDraws)
        XCTAssertTrue(BossRuntime.deferAutomaticDraw(count: 1, sourceID: Markers.prism,
            policy: .absentFromHand, puzzle: &run.puzzle!))
        _ = try Actions.endTurn(&run)
        XCTAssertEqual(run.puzzle!.hand.count, 4)
        XCTAssertFalse(Set(run.puzzle!.hand.dropLast()).contains(run.puzzle!.hand.last!))
        checkConservation(run)
    }

    func testCourierEmptyPoolDeliversZeroWithoutDuplicatingCards() throws {
        var run = fixture(.lateCourier, hand: [.one, .two], blanks: [Square(0), Square(1)])
        XCTAssertTrue(BossRuntime.deferAutomaticDraw(count: 3, sourceID: Markers.sapphire, puzzle: &run.puzzle!))
        let ids = run.puzzle!.handCardIDs
        let turn = try Actions.endTurn(&run)
        XCTAssertEqual(turn.numbersDrawn, 0)
        XCTAssertEqual(run.puzzle!.handCardIDs, ids)
        XCTAssertTrue(run.puzzle!.bossState.deferredDraws.isEmpty)
        checkConservation(run)
    }

    func testPrismCourierPersistsExactClaimWithoutDrawingEarlyAndDeliversOnlyOnce() throws {
        var run = fixture(.lateCourier, hand: [.one, .two, .three])
        run.markers = [OwnedMarker(defID: Markers.prism, boughtAtLevel: 1, pricePaid: 4, squares: [Square(0)])]
        MarkerRuntime.synchronizeOwnership(run: &run)
        let claim = try XCTUnwrap(run.markerState.claims.first)
        let pool = try encoded(run.puzzle!.pool), streams = try encoded(run.streams)
        let itemRandom = try encoded(run.itemRandom)
        _ = try put(.one, at: Square(0), in: &run)
        let request = try XCTUnwrap(run.puzzle!.bossState.deferredDraws.first)
        XCTAssertEqual(request.sourceClaimID, claim.id)
        XCTAssertEqual(request.sourceID, Markers.prism)
        XCTAssertEqual(request.policy, .absentFromHand)
        XCTAssertEqual(try encoded(run.puzzle!.pool), pool, "The played card came from Hand; no owed draw removes a Pool token")
        XCTAssertEqual(try encoded(run.streams), streams)
        XCTAssertEqual(try encoded(run.itemRandom), itemRandom)
        var copy = try restored(run)
        XCTAssertEqual(copy.puzzle!.bossState.deferredDraws, [request])
        let turn = try Actions.endTurn(&copy)
        XCTAssertEqual(turn.numbersDrawn, 1)
        XCTAssertEqual(copy.puzzle!.hand.count, 3)
        XCTAssertTrue(copy.puzzle!.bossState.deferredDraws.isEmpty)
        let completed = try encoded(copy)
        var puzzle = copy.puzzle!
        XCTAssertEqual(BossRuntime.beforeRefill(run: &copy, puzzle: &puzzle), 0)
        copy.puzzle = puzzle
        XCTAssertEqual(try encoded(copy), completed)
        checkConservation(copy)
    }

    func testPageCutterFourthFillAndEmptyHandBankOnce() throws {
        var run = fixture(.pageCutter, hand: [.one, .two, .three, .four])
        for index in 0..<3 { _ = try put(Digit(rawValue: index + 1)!, at: Square(index), in: &run) }
        XCTAssertEqual(run.puzzle!.turnNumber, 1)
        let fourth = try put(.four, at: Square(3), in: &run)
        XCTAssertNotNil(fourth.automaticTurn)
        XCTAssertEqual(run.puzzle!.turnNumber, 2)
        XCTAssertEqual(run.puzzle!.score, 100)
        XCTAssertEqual(run.puzzle!.bossState.correctFills, 0)
        XCTAssertFalse(run.puzzle!.bossState.pendingAutoEnd)
        XCTAssertNil(try Actions.finishAutomaticTurnIfNeeded(&run))
        checkConservation(run)
    }

    func testPageCutterWaitsForMandatoryMarkerChoiceAcrossRestore() throws {
        var run = fixture(.pageCutter)
        run.markers = [OwnedMarker(defID: Markers.fork, boughtAtLevel: 1, pricePaid: 4, squares: [Square(3)])]
        MarkerRuntime.synchronizeOwnership(run: &run)
        for index in 0..<4 { _ = try put(Digit(rawValue: index + 1)!, at: Square(index), in: &run) }
        XCTAssertEqual(run.puzzle!.turnNumber, 1)
        XCTAssertTrue(run.puzzle!.bossState.pendingAutoEnd)
        let choice = try XCTUnwrap(run.pendingItemDecisions.first)
        XCTAssertFalse(choice.allowsCancel)
        XCTAssertThrowsError(try Actions.endTurn(&run))
        var game = Game(run: try restored(run))
        XCTAssertTrue(try game.resolveItemDecision(id: choice.id, selected: [choice.options[0].id]))
        XCTAssertEqual(game.puzzle!.turnNumber, 2)
        XCTAssertEqual(game.puzzle!.score, 100)
        let finished = try encoded(game.run)
        XCTAssertFalse(try game.resolveItemDecision(id: choice.id, selected: [choice.options[0].id]))
        XCTAssertEqual(try encoded(game.run), finished)
        checkConservation(game.run)
    }

    func testPageCutterCorrectCluesCountAndManualBoundaryResets() throws {
        var run = fixture(.pageCutter)
        for index in 0..<3 { _ = try Actions.useClue(&run, square: Square(index)) }
        XCTAssertEqual(run.puzzle!.bossState.correctFills, 3)
        let fourth = try Actions.useClue(&run, square: Square(3))
        XCTAssertNotNil(fourth.automaticTurn)
        XCTAssertEqual(run.puzzle!.turnNumber, 2)
        XCTAssertEqual(run.puzzle!.score, 0)
        _ = try Actions.useClue(&run, square: Square(4))
        _ = try Actions.endTurn(&run)
        XCTAssertEqual(run.puzzle!.bossState.correctFills, 0)
        checkConservation(run)
    }

    func testPageCutterFourthFillFullBoardAndEmptyHandShareOneBoundary() throws {
        var run = fixture(.pageCutter, hand: [.one, .two, .three, .four],
                          blanks: [Square(0), Square(1), Square(2), Square(3)])
        for index in 0..<3 { _ = try put(Digit(rawValue: index + 1)!, at: Square(index), in: &run) }
        let fourth = try put(.four, at: Square(3), in: &run)
        XCTAssertTrue(fourth.fullClear)
        XCTAssertNotNil(fourth.automaticTurn)
        XCTAssertEqual(run.puzzle!.turnNumber, 2)
        XCTAssertTrue(run.puzzle!.board.isFull)
        XCTAssertFalse(run.puzzle!.bossState.pendingAutoEnd)
        XCTAssertNil(try Actions.finishAutomaticTurnIfNeeded(&run))
        checkConservation(run)
    }

    func testKeepFillingRebinderConservesCardsAndPageCutterStillEndsFourFills() throws {
        var run = fixture(.rebinder)
        run.puzzle!.phase = .keepFilling; run.puzzle!.score = 1_000
        _ = try Actions.endTurn(&run)
        XCTAssertEqual(run.puzzle!.score, 1_000)
        XCTAssertEqual(run.puzzle!.phase, .keepFilling)
        checkConservation(run)
        var cutter = fixture(.pageCutter)
        cutter.puzzle!.phase = .keepFilling; cutter.puzzle!.score = 1_000
        for index in 0..<4 { _ = try put(Digit(rawValue: index + 1)!, at: Square(index), in: &cutter) }
        XCTAssertEqual(cutter.puzzle!.turnNumber, 2)
        XCTAssertEqual(cutter.puzzle!.score, 1_000)
        checkConservation(cutter)
    }

    func testReviewBoardScoreAloneCannotWinOrRecordEarlyPayout() throws {
        var run = fixture(.reviewBoard)
        run.puzzle!.score = run.puzzle!.target
        _ = try Actions.endTurn(&run)
        XCTAssertEqual(run.puzzle!.phase, .playing)
        XCTAssertNil(run.puzzle!.bookmarkState.winningTurn)
        XCTAssertThrowsError(try Actions.cashOut(&run))
        run.puzzle!.turnsMax = 2
        _ = try Actions.endTurn(&run)
        XCTAssertEqual(run.puzzle!.phase, .outOfTurns)
        XCTAssertTrue(Actions.canClaimRewardedRescue(run))
        checkConservation(run)
    }

    func testReviewBoardClueCompletesAllThreeAndFullClearApproves() throws {
        var run = fixture(.reviewBoard, hand: [], blanks: [Square(0)])
        run.puzzle!.score = run.puzzle!.target
        let result = try Actions.useClue(&run, square: Square(0))
        XCTAssertEqual(Set(result.lineClears.map(\.rawValue)), ["row", "col", "box"])
        XCTAssertEqual(run.puzzle!.bossState.reviewApproved, Set(BossReviewUnit.allCases))
        XCTAssertEqual(run.puzzle!.phase, .won)
        XCTAssertEqual(run.puzzle!.turnNumber, 2)
        XCTAssertFalse(run.puzzle!.canKeepFilling)
        checkConservation(run)
    }

    func testReviewPartialApprovalsPersistWithoutInferringPositiveScores() throws {
        var run = fixture(.reviewBoard, hand: [.one, .one], blanks: [Square(0), Square(15)])
        _ = try Actions.useClue(&run, square: Square(0))
        XCTAssertEqual(run.puzzle!.bossState.reviewApproved, Set(BossReviewUnit.allCases))
        XCTAssertEqual(run.puzzle!.pendingBase, 0)
        let copy = try restored(run)
        XCTAssertEqual(copy.puzzle!.bossState.reviewApproved, run.puzzle!.bossState.reviewApproved)
        checkConservation(run)
    }

    func testExpandedBossStateDefaultsAndDeterministicRoundTrip() throws {
        let old = try JSONDecoder().decode(ExpandedBossState.self, from: Data("{}".utf8))
        XCTAssertTrue(old.waitingIDs.isEmpty); XCTAssertFalse(old.pendingAutoEnd)
        XCTAssertFalse(old.placementStarted); XCTAssertEqual(old.royaltyCount, 0)
        var run = fixture(.collator)
        run.puzzle!.bossState.sealedIDs = Set(run.puzzle!.handCardIDs.prefix(2))
        run.puzzle!.bossState.usedDigits = [.one, .three, .nine]
        XCTAssertEqual(try encoded(run), try encoded(restored(run)))
    }

    func testLegacyHandWithoutIDsStartsCollatorAndGalleyWithoutChangingTokensOrRNG() throws {
        for boss in [BossModifier.collator, .galleyQueue] {
            var run = fixture(boss, hand: [.one, .two, .three, .four])
            run.puzzle!.handCardIDs = []
            run.puzzle!.bossState = .init()
            let beforePool = try encoded(run.puzzle!.pool)
            let beforeStreams = try encoded(run.streams)
            var p = run.puzzle!
            p.startBossTurn(&run)
            XCTAssertEqual(p.hand, [.one, .two, .three, .four])
            XCTAssertEqual(p.handCardIDs.count, 4)
            XCTAssertEqual(Set(p.handCardIDs).count, 4)
            XCTAssertEqual(try encoded(p.pool), beforePool)
            XCTAssertEqual(try encoded(run.streams), beforeStreams)
            XCTAssertEqual(p.hand.indices.filter { !p.isBlocked(handIndex: $0) }, [0, 1])
            run.puzzle = p
            checkConservation(run)
            let ids = p.handCardIDs
            BossRuntime.synchronizeHand(puzzle: &p)
            XCTAssertEqual(p.handCardIDs, ids)
        }
    }
}
