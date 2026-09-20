import XCTest
@testable import ProbablySudokuEngine

final class BossScoringTests: XCTestCase {
    private func game(_ boss: BossModifier, bookmarks: [String] = [], blanks: [Int]? = nil,
                      target: Int = 1_000_000) -> Game {
        var run = RunState(seed: "expanded-boss-score-proof", book: .probably)
        run.slot = .boss
        run.bookmarks = bookmarks.enumerated().map { index, id in
            OwnedBookmark(defID: id, boughtAtLevel: 1, pricePaid: 5,
                id: SkipOffer.stableIdentity(seed: run.seed, domain: "bookmark.\(index)"))
        }
        let digits = (0..<81).map { Digit(($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1)! }
        let board = Board(GeneratedPuzzle(solution: digits,
            isGiven: (0..<81).map { !(blanks ?? Array(0..<81)).contains($0) }))
        var pool = Pool(blanksOf: board)
        let hand = pool.draw(&run.streams.pool, count: min(7, pool.total))
        var puzzle = PuzzleState(level: 1, slot: .boss, difficulty: .boss, board: board,
            pool: pool, hand: hand, handSize: 7, turnNumber: 1, turnsMax: 10,
            tossedThisPuzzle: 0, tossAllowance: 4, score: 0, target: target,
            cluesRemaining: 3, boss: boss, censoredDigit: nil, blockedDigit: nil,
            bossTurn: nil, phase: .playing, keepFillingCoins: 0)
        puzzle.ensureHandIdentities(seed: run.seed)
        BossScoring.puzzleStarted(run: run, puzzle: &puzzle)
        run.puzzle = puzzle
        return Game(run: run)
    }

    @discardableResult
    private func place(_ index: Int, in game: inout Game) throws -> PlacementOutcome {
        let digit = try XCTUnwrap(game.puzzle).board.correctDigit(at: Square(index))
        let card = try XCTUnwrap(game.stackHand(with: digit))
        return try game.place(handIndex: card, at: Square(index))
    }

    private func restored(_ game: Game) throws -> Game { try Game(decoding: game.encoded()) }

    func testChainUsesMovingNaturalAnchorAndCluesDoNotMoveIt() throws {
        var g = game(.chainStitcher)
        XCTAssertEqual(try place(0, in: &g).points, 10)
        let disconnected = try place(40, in: &g)
        XCTAssertEqual(disconnected.points, 45)
        let receipt = try XCTUnwrap(disconnected.scoreReceipts.first)
        let bossOperation = try XCTUnwrap(receipt.operations.first {
            $0.sourceID == "boss.\(BossModifier.chainStitcher.rawValue)"
        })
        XCTAssertEqual(bossOperation.kind, .multiplyPoints)
        XCTAssertEqual(bossOperation.amount, 0.5)
        XCTAssertEqual(bossOperation.before.points, 90)
        XCTAssertEqual(bossOperation.after.points, 45)
        XCTAssertEqual(receipt.operations.last?.kind, .queue)
        XCTAssertEqual(receipt.operations.last?.amount, 45)
        XCTAssertEqual(g.puzzle?.bossState.scoring.chainAnchor, Square(40))
        g = try restored(g)
        XCTAssertEqual(try place(41, in: &g).points, 10, "The new anchor, not the first square, shares this row")
        _ = try g.useClue(at: Square(1))
        XCTAssertEqual(g.puzzle?.bossState.scoring.chainAnchor, Square(41))
        let before = try XCTUnwrap(g.puzzle).bossState.scoring.chainAnchor
        let wrong = try XCTUnwrap(g.stackHand(with: .one))
        XCTAssertFalse(try g.place(handIndex: wrong, at: Square(2)).correct)
        XCTAssertEqual(g.puzzle?.bossState.scoring.chainAnchor, before)
        _ = try g.endTurn()
        XCTAssertNil(g.puzzle?.bossState.scoring.chainAnchor)
    }

    func testChainHalvesOnlyPlacementNotSimultaneousClearsOrFullClear() throws {
        var g = game(.chainStitcher, blanks: [0, 40])
        _ = try place(0, in: &g)
        let last = try place(40, in: &g)
        XCTAssertEqual(last.points, 45)
        XCTAssertEqual(last.lineClearPoints, [45, 45, 45])
        XCTAssertEqual(last.fullClearPoints, 500)
    }

    func testBackPageNaturalBaseAndVioletOverrideAreSeparateOperations() throws {
        for digit in Digit.all {
            var g = game(.backPage)
            let square = digit.rawValue - 1
            XCTAssertEqual(try place(square, in: &g).points, 10 * (10 - digit.rawValue))
        }
        var g = game(.backPage)
        g.give(marker: Markers.violet, on: [Square(8)])
        let outcome = try place(8, in: &g)
        XCTAssertEqual(outcome.points, 90, "Violet still scores as9 after Back Page's natural10")
        let operations = try XCTUnwrap(outcome.scoreReceipts.first).operations
        XCTAssertEqual(operations.first { $0.kind == .setBase }?.after.points, 10)
        XCTAssertEqual(operations.first { $0.sourceID == Markers.violet }?.amount, 80)
        XCTAssertEqual(g.puzzle?.board[Square(8)], .nine)
        let clue = try g.useClue(at: Square(0))
        XCTAssertEqual(clue.points, 0)
    }

    func testPublicistUsesCopyIdentityAndDoesNotSpendBudgetOnZeroedEvent() throws {
        var g = game(.publicist, bookmarks: [Bookmarks.localGossip, Bookmarks.localGossip])
        g.give(marker: Markers.ledger, on: [Square(0)])
        XCTAssertEqual(try place(0, in: &g).points, 0)
        XCTAssertTrue(try XCTUnwrap(g.puzzle).bossState.scoring.publicistPaid.isEmpty)
        XCTAssertEqual(try place(1, in: &g).points, 80)
        XCTAssertEqual(g.puzzle?.bossState.scoring.publicistPaid, Set(g.run.bookmarks.map(\.id)))
        g = try restored(g)
        XCTAssertEqual(try place(2, in: &g).points, 30)
        _ = try g.endTurn()
        XCTAssertEqual(try place(3, in: &g).points, 100)
    }

    func testPublicistLineClearPaysOneFlatContributionButPreservesGrowthAndCoins() throws {
        var g = game(.publicist, bookmarks: [Bookmarks.sportsSection, Bookmarks.rollingPresses, Bookmarks.financePages], blanks: [0])
        let coins = g.run.coins
        let result = try place(0, in: &g)
        XCTAssertEqual(result.lineClearPoints, [70, 45, 45])
        XCTAssertEqual(g.run.coins, coins + 3)
        XCTAssertEqual(g.puzzle?.itemState[Bookmarks.rollingPresses], 3)
        XCTAssertEqual(result.fullClearPoints, 500)
    }

    func testWordCountRetainsNaturalBaseAndClipsFundingLotsBeforeBank() throws {
        var g = game(.wordCount, bookmarks: [Bookmarks.localGossip])
        g.give(marker: Markers.crimson, on: [Square(8)])
        g.give(marker: Markers.golden, on: [Square(0)])
        let first = try place(8, in: &g)
        XCTAssertEqual(first.points, 240, "Natural90 plus only150 of390 extra Points")
        XCTAssertEqual(first.scoreReceipts.first?.operations.last?.amount, 240)
        XCTAssertEqual(g.puzzle?.bossState.scoring.wordCountSpent, 150)
        g = try restored(g)
        XCTAssertEqual(try place(0, in: &g).points, 10, "Natural Points remain after the allowance is spent")
        let puzzle = try XCTUnwrap(g.puzzle)
        XCTAssertEqual(puzzle.pendingBase, 250)
        XCTAssertEqual(BuffRuntime.availableRainCheckPoints(puzzle), 250)
        XCTAssertEqual(puzzle.buffState.pointLots.reduce(0) { $0 + $1.remaining }, 250)
        XCTAssertEqual(try g.endTurn().pointsGained, 250)
        XCTAssertEqual(g.puzzle?.bossState.scoring.wordCountSpent, 0)
    }

    func testWordCountVioletConsumesActualExtraAndClueRulesAreUnchanged() throws {
        var g = game(.wordCount)
        g.give(marker: Markers.violet, on: [Square(0), Square(1)])
        g.give(marker: Markers.onyx, on: [Square(4)])
        XCTAssertEqual(try place(0, in: &g).points, 90)
        XCTAssertEqual(g.puzzle?.bossState.scoring.wordCountSpent, 80)
        XCTAssertEqual(try place(1, in: &g).points, 90)
        XCTAssertEqual(g.puzzle?.bossState.scoring.wordCountSpent, 150)
        XCTAssertEqual(try g.useClue(at: Square(4)).points, 50)
        XCTAssertEqual(g.puzzle?.bossState.scoring.wordCountSpent, 150)
    }

    func testDryPressGatesCurrentMarkerOnlyAndReinksOnPlainFillAcrossSave() throws {
        var g = game(.dryPress, bookmarks: [Bookmarks.localGossip])
        g.give(marker: Markers.golden, on: [Square(0)])
        g.give(marker: Markers.crimson, on: [Square(8), Square(7)])
        XCTAssertEqual(try place(0, in: &g).points, 140)
        XCTAssertFalse(try XCTUnwrap(g.puzzle).bossState.scoring.dryPressReady)
        g = try restored(g)
        XCTAssertEqual(try place(8, in: &g).points, 120, "The Bookmark's30 and natural90 remain")
        _ = try g.endTurn()
        XCTAssertFalse(try XCTUnwrap(g.puzzle).bossState.scoring.dryPressReady, "Banking does not re-ink")
        XCTAssertEqual(try place(1, in: &g).points, 50)
        XCTAssertTrue(try XCTUnwrap(g.puzzle).bossState.scoring.dryPressReady)
        XCTAssertEqual(try place(7, in: &g).points, 440)
    }

    func testDryPressKeepsRoseDrawsAndClueRestorationAndNeverChargesSuppressedPledge() throws {
        var g = game(.dryPress)
        g.give(marker: Markers.golden, on: [Square(0)])
        g.give(marker: Markers.rose, on: [Square(1)])
        g.give(marker: Markers.sapphire, on: [Square(2)])
        g.give(marker: Markers.onyx, on: [Square(3)])
        g.give(marker: Markers.pledge, on: [Square(4)])
        _ = try place(0, in: &g)
        _ = try place(1, in: &g)
        XCTAssertEqual(g.puzzle?.itemState[Markers.rose], 1)
        XCTAssertEqual(try place(2, in: &g).numbersDrawn, 1)
        XCTAssertEqual(try g.useClue(at: Square(3)).points, 40)
        let coins = g.run.coins
        let pledge = try place(4, in: &g)
        XCTAssertFalse(pledge.pendingDecision)
        XCTAssertEqual(pledge.points, 50)
        XCTAssertEqual(g.run.coins, coins)
        XCTAssertEqual(g.puzzle?.markerState.count(Markers.pledge), 0)
    }

    func testDryPressPreservesFiniteScoreUseAndPreviouslyPromisedReward() throws {
        var g = game(.dryPress)
        g.give(marker: Markers.crossroads, on: [Square(40), Square(41)])
        var run = g.run
        var p = try XCTUnwrap(run.puzzle)
        p.bossState.scoring.dryPressReady = false
        let source = MarkerSource(markerID: Markers.beacon, claimID: "earlier-beacon", square: Square(0))
        p.markerState.beacon = MarkerDigitPromise(source: source, digit: .nine, uses: 1)
        let event = CataloguePlacement(digit: .nine, square: Square(40), boardBefore: p.board,
            completedUnits: [.row, .col], isEligible: true, turnNumber: p.turnNumber)
        var result = EffectResult()
        MarkerRuntime.beforePlacement(event, run: &run, puzzle: &p, result: &result)
        XCTAssertEqual(result.flat, 40, "An earlier square's promise remains payable")
        XCTAssertEqual(p.markerState.count(Markers.crossroads), 0)
        XCTAssertNil(p.markerState.beacon)
        p.bossState.scoring.dryPressReady = true
        result = EffectResult()
        MarkerRuntime.beforePlacement(event, run: &run, puzzle: &p, result: &result)
        XCTAssertEqual(result.flat, 300)
        XCTAssertEqual(p.markerState.count(Markers.crossroads), 1)
    }

    func testDryPressWaivesDryingWhenNoPlainBlankRemainsAndKeepFillingDoesNotSuppress() throws {
        var g = game(.dryPress, blanks: [0, 1, 8])
        g.give(marker: Markers.golden, on: [Square(0), Square(8)])
        var run = g.run
        run.puzzle?.bossState.scoring.dryPressReady = false
        g = Game(run: run)
        _ = try g.useClue(at: Square(1))
        XCTAssertTrue(try XCTUnwrap(g.puzzle).bossState.scoring.dryPressReady)
        XCTAssertEqual(try place(0, in: &g).points, 110)
        XCTAssertTrue(try XCTUnwrap(g.puzzle).bossState.scoring.dryPressReady)
        XCTAssertEqual(try place(8, in: &g).points, 190)
        run = game(.dryPress).run
        run.puzzle?.phase = .keepFilling
        run.puzzle?.bossState.scoring.dryPressReady = false
        run.markers = [OwnedMarker(defID: Markers.golden, boughtAtLevel: 1, pricePaid: 0, squares: [Square(0)])]
        XCTAssertFalse(BossScoring.suppressesImmediateMarker(square: Square(0), run: run, puzzle: run.puzzle!))
    }

    func testOrphanDebitsOldestMixedLotsInPreviewAndOnceAtActualBank() throws {
        var g = game(.orphanLine, bookmarks: [Bookmarks.opEd])
        var run = g.run
        var p = try XCTUnwrap(run.puzzle)
        for card in p.removeAllHandCards() { p.pool.put(card.digit) }
        for digit in [Digit.one, .two] { XCTAssertTrue(p.pool.take(digit)); p.appendHandDigits([digit]) }
        p.pendingBase = 100
        BuffRuntime.recordPoints(id: "older-clue", points: 30, eligible: false, originalPlacement: true, puzzle: &p)
        BuffRuntime.recordPoints(id: "later-natural", points: 70, eligible: true, originalPlacement: true, puzzle: &p)
        p.buffState.turnMult = [BuffTurnMult(source: UUID(), definition: Buffs.tightDeadline, amount: 3, turn: 1)]
        p.lockScoringOrder(run: run); run.puzzle = p; g = Game(run: run)
        let saved = try g.encoded()
        let preview = try XCTUnwrap(g.puzzle).pendingScoringLedger
        XCTAssertEqual(preview.points, 60)
        XCTAssertEqual(preview.total, 300, "40 debit removes30 ineligible then10 eligible; remaining60 gets(1+3+1)")
        XCTAssertEqual(preview.operations.filter { $0.kind == .subtractPoints }.map(\.amount), [40])
        XCTAssertEqual(try g.encoded(), saved, "Preview cannot debit spendable point lots")
        g = try restored(g)
        let turn = try g.endTurn()
        XCTAssertEqual(turn.pointsGained, preview.total)
        XCTAssertEqual(turn.scoringLedger?.operations.filter { $0.kind == .subtractPoints }.count, 1)
        XCTAssertEqual(g.puzzle?.score, 300)
    }

    func testOrphanFloorsAtZeroSkipsKeepFillingAndEmptyHand() throws {
        var p = try XCTUnwrap(game(.orphanLine).puzzle)
        p.pendingBase = 19
        BossScoring.prepareBank(puzzle: &p)
        XCTAssertEqual(p.pendingBase, 0)
        let operations = p.turnScoringOperations
        BossScoring.prepareBank(puzzle: &p)
        XCTAssertEqual(p.turnScoringOperations, operations)
        p.bossState.scoring.orphanDebitedTurn = nil; p.pendingBase = 50; p.phase = .keepFilling
        XCTAssertEqual(BossScoring.orphanDebit(p), 0)
        p.phase = .playing; p.hand = []; p.handCardIDs = []
        XCTAssertEqual(BossScoring.orphanDebit(p), 0)
    }

    func testSerialCarriesPostMultScoreReleasesOnEmptyBankAndKeepsDirectAwardsSeparate() throws {
        var g = game(.serialPublisher, bookmarks: [Bookmarks.morningEdition], target: 1_000)
        var run = g.run
        run.puzzle?.pendingBase = 1_000
        run.puzzle?.bookmarkState.turn.eligiblePlacements = 1
        g = Game(run: run)
        let saved = try g.encoded()
        XCTAssertEqual(g.puzzle?.pendingScore, 334)
        XCTAssertEqual(try g.encoded(), saved)
        XCTAssertEqual(try g.endTurn().pointsGained, 434)
        XCTAssertEqual(g.puzzle?.bossState.scoring.serialCarry, 666)
        g = try restored(g)
        XCTAssertEqual(g.puzzle?.pendingScore, 334)
        XCTAssertEqual(try g.endTurn().pointsGained, 334)
        XCTAssertEqual(g.puzzle?.bossState.scoring.serialCarry, 332)
        XCTAssertEqual(g.puzzle?.score, 768)
    }

    func testSerialFullClearReleasesAllCarryBeforeWinCheck() throws {
        var g = game(.serialPublisher, blanks: [0], target: 900)
        var run = g.run
        run.puzzle?.bossState.scoring.serialCarry = 1_000
        g = try restored(Game(run: run))
        let last = try place(0, in: &g)
        XCTAssertEqual(last.automaticTurn?.pointsGained, 1_645)
        XCTAssertEqual(g.puzzle?.bossState.scoring.serialCarry, 0)
        XCTAssertEqual(g.puzzle?.phase, .won)
    }

    func testSerialKeepFillingFullClearPaysOnlySavedCarryExactlyOnce() throws {
        var g = game(.serialPublisher, blanks: [0], target: 900)
        var run = g.run
        run.puzzle?.score = 900
        run.puzzle?.phase = .won
        run.puzzle?.bossState.scoring.serialCarry = 725
        g = try restored(Game(run: run))
        try g.keepFilling()
        let turn = try XCTUnwrap(g.puzzle).turnNumber
        let last = try place(0, in: &g)
        XCTAssertTrue(last.fullClear)
        XCTAssertNil(last.automaticTurn, "Paying old carry must not spend another Turn")
        XCTAssertEqual(g.puzzle?.score, 1_625, "New placement10, clears135 and Full Clear500 stay frozen")
        XCTAssertEqual(g.puzzle?.pendingBase, 0)
        XCTAssertEqual(g.puzzle?.turnNumber, turn)
        XCTAssertEqual(g.puzzle?.keepFillingCoins, 6)
        XCTAssertEqual(g.puzzle?.bossState.scoring.serialCarry, 0)
        XCTAssertEqual(g.puzzle?.phase, .won)
        let bank = try XCTUnwrap(last.scoreReceipts.flatMap(\.operations).first { $0.kind == .bank })
        XCTAssertEqual(bank.sourceID, "boss.\(BossModifier.serialPublisher.rawValue)")
        XCTAssertEqual(bank.before.score, 900)
        XCTAssertEqual(bank.after.score, 1_625)
        XCTAssertEqual(bank.amount, 725)
        g = try restored(g)
        var puzzle = try XCTUnwrap(g.puzzle)
        XCTAssertEqual(puzzle.lastScoringLedger?.bossSettlement?.gross, 0)
        XCTAssertEqual(puzzle.lastScoringLedger?.bossSettlement?.carryBefore, 725)
        XCTAssertEqual(puzzle.lastScoringLedger?.total, 725)
        XCTAssertNil(BossScoring.releaseCarryOnFullClear(puzzle: &puzzle))
        puzzle.phase = .keepFilling
        XCTAssertNil(BossScoring.releaseCarryOnFullClear(puzzle: &puzzle))
        XCTAssertEqual(puzzle.score, 1_625)
    }

    func testSerialKeepFillingCarryHonorsCeilingAndRequiresActualFullClear() throws {
        var puzzle = try XCTUnwrap(game(.serialPublisher, blanks: [0]).puzzle)
        puzzle.phase = .keepFilling
        puzzle.score = ScoreMath.ceiling - 5
        puzzle.bossState.scoring.serialCarry = 20
        XCTAssertNil(BossScoring.releaseCarryOnFullClear(puzzle: &puzzle))
        XCTAssertEqual(puzzle.bossState.scoring.serialCarry, 20)
        _ = puzzle.board.fill(Square(0), with: .one, by: .player)
        let receipt = try XCTUnwrap(BossScoring.releaseCarryOnFullClear(puzzle: &puzzle))
        XCTAssertEqual(receipt.operations.last?.amount, 5)
        XCTAssertEqual(puzzle.score, ScoreMath.ceiling)
        XCTAssertEqual(puzzle.bossState.scoring.serialCarry, 0)
        XCTAssertEqual(puzzle.lastScoringLedger?.scoreLimitApplied, true)
    }

    func testRivalUsesUntaxedPreviousGrossEmptyBanksDoNotResetAndFeeCaps() throws {
        var g = game(.rivalColumn)
        for (gross, expected) in [(503, 503), (503, 403), (101, 81), (0, 0), (102, 102)] {
            var run = g.run; run.puzzle?.pendingBase = gross; g = Game(run: run)
            let preview = try XCTUnwrap(g.puzzle).pendingScoringLedger
            XCTAssertEqual(preview.total, expected)
            XCTAssertNotEqual(preview.scoreLimitApplied, true, "A boss fee is not numerical saturation")
            XCTAssertEqual(try g.endTurn().pointsGained, expected)
            if gross > 0 { XCTAssertEqual(g.puzzle?.bossState.scoring.rivalBenchmark, gross) }
            else { XCTAssertEqual(g.puzzle?.bossState.scoring.rivalBenchmark, 101) }
            g = try restored(g)
        }
    }

    func testBinderyReversesTraversalButReadersCircleKeepsPhysicalLeftNeighbour() throws {
        var g = game(.bindery, bookmarks: [Bookmarks.opEd, Bookmarks.readersCircle, Bookmarks.theSundaySupplement])
        let order = g.run.bookmarks.map(\.id)
        _ = try place(0, in: &g)
        XCTAssertEqual(g.puzzle?.pendingMultiplier, 9, "(1+1+1)×3")
        XCTAssertFalse(g.reorderBookmark(id: order[0], to: 2))
        _ = try g.endTurn()
        g = try restored(g)
        _ = try place(1, in: &g)
        XCTAssertEqual(g.puzzle?.pendingMultiplier, 5, "1×3+1+1, not a copy of the traversal neighbour")
        XCTAssertEqual(g.run.bookmarks.map(\.id), order)
        XCTAssertEqual(g.puzzle?.bossState.scoring.binderyOrder, order)
    }

    func testBinderyPinOnTossAndRetirementDoesNotMoveAReadersPhysicalNeighbour() throws {
        var g = game(.bindery, bookmarks: [Bookmarks.opEd, Bookmarks.frontPageSplash, Bookmarks.readersCircle, Bookmarks.theSundaySupplement])
        let ids = g.run.bookmarks.map(\.id)
        _ = try g.toss(handIndex: 0)
        XCTAssertFalse(g.reorderBookmark(id: ids[0], to: 3))
        var run = g.run
        XCTAssertTrue(BookmarkMechanics.retire(id: ids[1], run: &run))
        g = Game(run: run)
        _ = try place(0, in: &g)
        XCTAssertEqual(g.puzzle?.pendingMultiplier, 6, "The vanished physical neighbour cannot become Op-Ed")
        XCTAssertEqual(g.run.bookmarks.map(\.id), [ids[0], ids[2], ids[3]])
    }

    func testNewScoringStateDefaultsAndCanonicalSavePreserveExactlyOnceBudgets() throws {
        let empty = try JSONDecoder().decode(BossScoringState.self, from: Data("{}".utf8))
        XCTAssertTrue(empty.dryPressReady)
        XCTAssertEqual(empty.serialCarry, 0)
        XCTAssertFalse(empty.binderyPinned)
        var g = game(.publicist, bookmarks: [Bookmarks.localGossip])
        _ = try place(0, in: &g)
        let saved = try g.encoded()
        XCTAssertEqual(try restored(g).encoded(), saved)
    }

    func testDryEligibilityUsesHistoricalGrowthAndSharedPurchaseEntitlements() throws {
        var run = game(.dryPress).run
        let board = try XCTUnwrap(run.puzzle).board
        run.markers = [OwnedMarker(defID: Markers.patina, boughtAtLevel: 1, pricePaid: 0, squares: [Square(0), Square(1)])]
        MarkerRuntime.synchronizeOwnership(run: &run)
        XCTAssertEqual(BossScoring.positiveImmediateMarkerSquares(run: run, board: board), [])
        run.markerState.claims[0].patinaSuccesses = 1
        XCTAssertEqual(BossScoring.positiveImmediateMarkerSquares(run: run, board: board), [Square(0)])
        run.markerState.claims[1].patinaSuccesses = 2
        XCTAssertEqual(BossScoring.positiveImmediateMarkerSquares(run: run, board: board), [Square(0), Square(1)])
        run.markers = [OwnedMarker(defID: Markers.pledge, boughtAtLevel: 1, pricePaid: 0, squares: [Square(0), Square(1), Square(2)])]
        run.coins = 2
        XCTAssertEqual(BossScoring.positiveImmediateMarkerSquares(run: run, board: board).count, 1)
        run.coins = 8
        run.puzzle?.markerState.increment(Markers.pledge, by: 2)
        XCTAssertEqual(BossScoring.positiveImmediateMarkerSquares(run: run, board: board).count, 1)
    }

    func testDryEligibilityCannotCountConstellationWithoutAnotherQualifyingType() throws {
        var run = game(.dryPress).run
        let board = try XCTUnwrap(run.puzzle).board
        run.markers = [OwnedMarker(defID: Markers.constellation, boughtAtLevel: 1, pricePaid: 0, squares: [Square(0), Square(1)])]
        XCTAssertTrue(BossScoring.positiveImmediateMarkerSquares(run: run, board: board).isEmpty)
        run.markers.append(OwnedMarker(defID: Markers.ivory, boughtAtLevel: 1, pricePaid: 0, squares: [Square(2)]))
        XCTAssertTrue(BossScoring.positiveImmediateMarkerSquares(run: run, board: board).isEmpty)
        run.markers.append(OwnedMarker(defID: Markers.rose, boughtAtLevel: 1, pricePaid: 0, squares: [Square(3)]))
        XCTAssertEqual(BossScoring.positiveImmediateMarkerSquares(run: run, board: board), [Square(0), Square(1)])
    }

    func testWordEligibilityUsesPublicNumericCapabilitiesWithoutHiddenSolution() throws {
        var run = game(.wordCount, bookmarks: [Bookmarks.localGossip]).run
        let board = try XCTUnwrap(run.puzzle).board
        XCTAssertTrue(BossScoring.hasWordCountLoadout(run: run, board: board), "Seven possible30-Point bonuses exceed150")
        run.bookmarks = []
        run.markers = [OwnedMarker(defID: Markers.golden, boughtAtLevel: 1, pricePaid: 0, squares: [Square(0)])]
        XCTAssertFalse(BossScoring.hasWordCountLoadout(run: run, board: board), "One finite100-Point square is insufficient")
        run.markers[0].squares.append(Square(1))
        XCTAssertTrue(BossScoring.hasWordCountLoadout(run: run, board: board))
        let changedSolution = board.solution.map { Digit(10 - $0.rawValue)! }
        let other = Board(GeneratedPuzzle(solution: changedSolution, isGiven: Array(repeating: false, count: 81)))
        XCTAssertEqual(BossScoring.hasWordCountLoadout(run: run, board: board), BossScoring.hasWordCountLoadout(run: run, board: other))
    }
}
