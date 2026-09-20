import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ScorePerformanceTests: XCTestCase {
    private func startedGame() throws -> Game {
        var game = Game(seed: "APPSTORE7")
        try game.startPuzzle()
        var run = game.run
        run.bookmarks = ["bm_local_gossip", "bm_morning_edition"].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0)
        }
        return Game(run: run)
    }

    func testReceiptHasPlacementThenNamedBonusThenQueue() throws {
        var game = try startedGame()
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first {
            game.puzzle!.hand.contains(game.puzzle!.board.correctDigit(at: $0))
        })
        let index = try XCTUnwrap(game.puzzle?.hand.firstIndex(of: game.puzzle!.board.correctDigit(at: square)))
        let outcome = try game.place(handIndex: index, at: square)
        let receipt = ScorePerformance.placement(outcome, square: square, previousScore: 0, finalScore: 0)
        XCTAssertEqual(receipt.beats.map(\.source), ["Number placed", "Local Gossip", "Turn points"])
        XCTAssertEqual(receipt.beats[1].value, "+30 → \(outcome.points.formatted())")
        XCTAssertEqual(receipt.beats.last?.queuedBase, outcome.points)
        XCTAssertTrue(receipt.beats.last?.value.hasSuffix("Points") == true)
        XCTAssertFalse(receipt.summary.localizedCaseInsensitiveContains("queue"))
    }

    func testLiveCalculationUpdatesBeforePlacementReceiptAndNeverMixesAnimationValues() throws {
        let model = GameModel(resuming: try liveGame(), savesProgress: false)
        let square = try placeCorrect(in: model)
        let ledger = try XCTUnwrap(model.puzzle?.pendingScoringLedger)
        let performance = try XCTUnwrap(model.scorePerformance)
        let saved = try model.game.encoded()
        XCTAssertGreaterThan(ledger.points, 0)
        XCTAssertEqual(ledger.multiplier, 6)
        XCTAssertEqual(model.presentedQueue, 0, "The attribution animation still starts at the previous queue")
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: ledger),
                       "The live product must update immediately instead of waiting for the final queue beat")
        for beat in performance.beats {
            model.advanceScore(beat, performanceID: performance.id)
            XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: ledger))
        }
        XCTAssertNotNil(model.puzzle?.board[square])
        XCTAssertEqual(try model.game.encoded(), saved, "Rendering every live update cannot change saved arithmetic")
    }

    func testBuffAndWrongPlacementImmediatelyReplaceAnOlderLiveCalculation() throws {
        let model = GameModel(resuming: try liveGame(), savesProgress: false)
        _ = try placeCorrect(in: model)
        let oldPerformance = try XCTUnwrap(model.scorePerformance)
        let beforeBuff = model.liveScoreCalculation
        XCTAssertTrue(model.useBuff(at: 0))
        let afterBuff = try XCTUnwrap(model.puzzle?.pendingScoringLedger)
        XCTAssertGreaterThan(afterBuff.multiplier, beforeBuff.multiplier)
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: afterBuff))
        // A delayed beat from the previous placement cannot restore its values.
        model.advanceScore(try XCTUnwrap(oldPerformance.beats.last), performanceID: oldPerformance.id)
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: afterBuff))

        let puzzle = try XCTUnwrap(model.puzzle)
        let square = try XCTUnwrap(puzzle.board.blanks.first { puzzle.board.correctDigit(at: $0) != puzzle.hand[0] })
        model.place(handIndex: 0, at: square)
        XCTAssertEqual(model.lastOutcome?.correct, false)
        let afterWrong = try XCTUnwrap(model.puzzle?.pendingScoringLedger)
        XCTAssertLessThan(afterWrong.points, afterBuff.points)
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: afterWrong))
        XCTAssertNil(model.scorePerformance)
    }

    func testRapidPlacementsReplaceReceiptButKeepLatestEngineSubtotal() throws {
        let model = GameModel(resuming: try liveGame(), savesProgress: false)
        _ = try placeCorrect(in: model)
        let oldPerformance = try XCTUnwrap(model.scorePerformance)
        let before = model.liveScoreCalculation
        _ = try placeCorrect(in: model)
        let latest = try XCTUnwrap(model.puzzle?.pendingScoringLedger)
        let currentPerformance = try XCTUnwrap(model.scorePerformance)
        XCTAssertNotEqual(oldPerformance.id, currentPerformance.id)
        XCTAssertGreaterThan(latest.points, before.points)
        model.advanceScore(try XCTUnwrap(oldPerformance.beats.last), performanceID: oldPerformance.id)
        model.finishScorePresentation(id: oldPerformance.id)
        XCTAssertEqual(model.scorePerformance?.id, currentPerformance.id)
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: latest))
        let restored = GameModel(resuming: try Game(decoding: model.game.encoded()), savesProgress: false)
        XCTAssertEqual(restored.liveScoreCalculation, model.liveScoreCalculation)
    }

    func testKeepFillingDoesNotAdvertiseAnotherScoreAward() throws {
        var game = try liveGame()
        var run = game.run
        run.puzzle?.phase = .keepFilling
        run.puzzle?.score = 1_000
        // A historical queue must not be presented as a new Keep Filling reward.
        run.puzzle?.pendingBase = 120
        game = Game(run: run)
        let model = GameModel(resuming: game, savesProgress: false)
        let saved = try model.game.encoded()
        XCTAssertEqual(model.liveScoreCalculation, .empty)
        XCTAssertEqual(try model.game.encoded(), saved)
    }

    func testCrimsonFourAndFreshInkShowExact960Then1920WithNamedOperations() throws {
        let fixture = try modifierGame()
        let model = GameModel(resuming: fixture.game, savesProgress: false)
        let buff = try XCTUnwrap(model.run.buffs.first)
        let bookmarkIDs = model.run.bookmarks.map { $0.id.uuidString }
        model.place(handIndex: 0, at: fixture.square)
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(points: 160, multiplier: 6, total: 960,
                                                                         scoreLimitApplied: false))
        let placement = try XCTUnwrap(model.scorePerformance)
        XCTAssertEqual(placement.feedbackBeats.map(\.source), ["Crimson Marker", "Op-Ed Column", "Stop the Presses"])
        XCTAssertEqual(placement.feedbackBeats.map(\.compactValue), ["×4 placement Points", "+1 Mult", "×3 Mult"])
        XCTAssertEqual(placement.feedbackBeats.first?.square, fixture.square)
        XCTAssertEqual(placement.feedbackBeats.dropFirst().map(\.sourceInstanceID), bookmarkIDs.map { Optional($0) })
        for beat in placement.feedbackBeats {
            model.advanceScore(beat, performanceID: placement.id)
            XCTAssertEqual(model.liveScoreCalculation.total, 960, "Attribution is not another score calculation")
        }

        XCTAssertTrue(model.useBuff(at: 0))
        XCTAssertTrue(model.run.buffs.isEmpty, "Fresh Ink leaves its inventory slot when consumed")
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(points: 160, multiplier: 12, total: 1_920,
                                                                         scoreLimitApplied: false))
        let activation = try XCTUnwrap(model.scorePerformance)
        XCTAssertEqual(activation.feedbackBeats.map(\.source), ["Fresh Ink", "Op-Ed Column", "Stop the Presses"])
        XCTAssertEqual(activation.feedbackBeats.map(\.compactValue), ["+2 Mult", "+1 Mult", "×3 Mult"])
        XCTAssertEqual(activation.feedbackBeats.first?.sourceInstanceID, buff.id.uuidString)
        XCTAssertEqual(activation.feedbackBeats.first?.sourceInventorySlot, 0)
        XCTAssertTrue(activation.feedbackBeats.dropFirst().allSatisfy { $0.sourceInventorySlot == nil })
        XCTAssertEqual(model.puzzle?.scoringBuffSources[Buffs.freshInk], [buff.id])
        let saved = try model.game.encoded()
        for beat in activation.feedbackBeats {
            model.advanceScore(beat, performanceID: activation.id)
            XCTAssertEqual(model.liveScoreCalculation.total, 1_920)
        }
        XCTAssertEqual(try model.game.encoded(), saved)
        model.endTurn()
        let banking = try XCTUnwrap(model.scorePerformance)
        XCTAssertEqual(banking.bankCalculation?.total, 1_920)
        XCTAssertEqual(model.puzzle?.score, 1_920)
        XCTAssertEqual(model.liveScoreCalculation.total, 1_920, "Keep the captured transfer until its bank beat")
        let bank = try XCTUnwrap(banking.feedbackBeats.first { $0.kind == .bank })
        model.advanceScore(bank, performanceID: banking.id)
        XCTAssertEqual(model.liveScoreCalculation, .empty)
        XCTAssertEqual(model.presentedScore, 1_920)
    }

    func testReversedBookmarkOrderAndDuplicateBuffCopiesKeepTheirExactSources() throws {
        let fixture = try modifierGame(reversed: true, duplicateBuff: true)
        let model = GameModel(resuming: fixture.game, savesProgress: false)
        let buffs = model.run.buffs
        model.place(handIndex: 0, at: fixture.square)
        XCTAssertEqual(model.liveScoreCalculation.total, 640, "(1 ×3 +1) ×160")
        let placement = try XCTUnwrap(model.scorePerformance)
        XCTAssertEqual(placement.feedbackBeats.map(\.source), ["Crimson Marker", "Stop the Presses", "Op-Ed Column"])
        XCTAssertTrue(model.useBuff(at: 1))
        XCTAssertEqual(model.liveScoreCalculation.total, 1_600, "((1 +2) ×3 +1) ×160")
        let secondCopy = try XCTUnwrap(model.scorePerformance)
        XCTAssertEqual(secondCopy.feedbackBeats.first?.sourceInstanceID, buffs[1].id.uuidString)
        XCTAssertEqual(secondCopy.feedbackBeats.first?.sourceInventorySlot, 1)
        XCTAssertEqual(model.run.buffs.map(\.id), [buffs[0].id])
        XCTAssertTrue(model.useBuff(at: 0))
        let firstCopy = try XCTUnwrap(model.scorePerformance)
        XCTAssertEqual(firstCopy.feedbackBeats.first?.sourceInstanceID, buffs[0].id.uuidString)
        XCTAssertEqual(firstCopy.feedbackBeats.first?.sourceInventorySlot, 0)
        XCTAssertFalse(firstCopy.feedbackBeats.contains { $0.sourceInstanceID == buffs[1].id.uuidString },
                       "Do not replay an earlier consumed copy as if it were activated twice")
        XCTAssertEqual(model.liveScoreCalculation.total, 2_560, "((1 +2 +2) ×3 +1) ×160")
        model.advanceScore(try XCTUnwrap(secondCopy.feedbackBeats.last), performanceID: secondCopy.id)
        model.finishScorePresentation(id: secondCopy.id)
        XCTAssertEqual(model.scorePerformance?.id, firstCopy.id)
        XCTAssertEqual(model.liveScoreCalculation.total, 2_560)
        model.finishScorePresentation(id: firstCopy.id)
        XCTAssertNil(model.scoreBeat)
        XCTAssertEqual(model.liveScoreCalculation.total, 2_560)
    }

    func testFogHidesMarkerFeedbackAndAccessibilityWithoutChangingActualScore() throws {
        let fixture = try modifierGame(fog: true)
        let model = GameModel(resuming: fixture.game, savesProgress: false)
        model.place(handIndex: 0, at: fixture.square)
        let performance = try XCTUnwrap(model.scorePerformance)
        XCTAssertEqual(model.liveScoreCalculation.total, 960)
        XCTAssertEqual(performance.feedbackBeats.map(\.source), ["Op-Ed Column", "Stop the Presses"])
        XCTAssertFalse(performance.summary.contains("Crimson"))
        XCTAssertFalse(performance.summary.contains("placement Points ×4"))
        let hidden = try XCTUnwrap(performance.beats.first { $0.sourceID == "mk_crimson" })
        model.advanceScore(hidden, performanceID: performance.id)
        XCTAssertNotEqual(model.scoreBeat?.sourceID, "mk_crimson")
        XCTAssertNil(model.scoreBeat?.square)
        let saved = try model.game.encoded()
        var ledger = try XCTUnwrap(model.puzzle).pendingScoringLedger
        ledger.operations = try XCTUnwrap(model.puzzle).turnScoringOperations + ledger.operations
        XCTAssertTrue(ScorePerformance.explanation(for: ledger).contains { $0.source.contains("Crimson") })
        let fogLines = ScorePerformance.explanation(for: ledger, hidesMarkerSources: true)
        XCTAssertFalse(fogLines.contains { $0.source.contains("Crimson") || $0.operation.contains("×4") })
        XCTAssertTrue(fogLines.contains { $0.source == "Op-Ed Column" })
        XCTAssertEqual(try model.game.encoded(), saved, "Fog only filters the displayed explanation")
    }

    func testPresentationCannotChangeSavedRulesAndOldTaskCannotClearNewReceipt() throws {
        var game = try startedGame()
        let firstBase = try placeForMorningEdition(in: &game)
        let turn = try game.endTurn()
        let firstScore = firstBase + 100
        XCTAssertEqual(turn.pointsGained, firstScore)
        XCTAssertEqual(game.puzzle?.score, firstScore)
        let receipt = ScorePerformance.banking(turn, previousScore: 0, finalScore: firstScore)

        // A second genuine Turn supplies the newer receipt. Neither animation
        // may mutate or replay either of the already committed engine awards.
        let secondBase = try placeForMorningEdition(in: &game)
        let nextTurn = try game.endTurn()
        let finalScore = firstScore + secondBase + 100
        XCTAssertEqual(nextTurn.pointsGained, secondBase + 100)
        XCTAssertEqual(game.puzzle?.score, finalScore)
        let next = ScorePerformance.banking(nextTurn, previousScore: firstScore, finalScore: finalScore)
        let model = GameModel(resuming: game, savesProgress: false)
        let saved = try model.game.encoded()
        model.presentScore(receipt)
        XCTAssertEqual(model.presentedScore, 0)
        XCTAssertTrue(model.isPresentingScore)
        XCTAssertEqual(receipt.beats.map(\.source), ["Turn points", "BANKED", "Morning Edition"])
        let bank = try XCTUnwrap(receipt.beats.first { $0.kind == .bank })
        let morning = try XCTUnwrap(receipt.beats.first { $0.sourceID == "bm_morning_edition" })
        model.advanceScore(bank, performanceID: receipt.id)
        XCTAssertEqual(model.presentedScore, firstBase, "The product banks before printed direct payouts")
        model.advanceScore(morning, performanceID: receipt.id)
        XCTAssertEqual(model.bookmarkScoreLabel("bm_morning_edition"), "+100 → \(firstScore.formatted())")
        XCTAssertEqual(model.presentedScore, firstScore)
        model.presentScore(next)
        model.advanceScore(morning, performanceID: receipt.id)
        model.finishScorePresentation(id: receipt.id)
        XCTAssertEqual(model.scorePerformance?.id, next.id)
        XCTAssertEqual(model.presentedScore, firstScore)
        model.advanceScore(try XCTUnwrap(next.beats.last), performanceID: next.id)
        XCTAssertEqual(model.presentedScore, finalScore)
        model.finishScorePresentation()
        XCTAssertFalse(model.isPresentingScore)
        XCTAssertNil(model.presentedScore)
        XCTAssertEqual(try model.game.encoded(), saved)
    }

    func testOrderedLedgerExplanationUsesEngineRunningTotalsAndExactItemIdentity() throws {
        var game = Game(seed: "ordered-app-ledger")
        try game.startPuzzle()
        var run = game.run
        let add = OwnedBookmark(defID: "bm_op_ed", boughtAtLevel: 1, pricePaid: 0)
        let multiply = OwnedBookmark(defID: "bm_stop_the_presses", boughtAtLevel: 1, pricePaid: 0)
        let morning = OwnedBookmark(defID: "bm_morning_edition", boughtAtLevel: 1, pricePaid: 0)
        run.bookmarks = [add, multiply, morning]
        game = Game(run: run)
        // Choose a held correct digit without changing model internals.
        let puzzle = try XCTUnwrap(game.puzzle)
        let square = try XCTUnwrap(puzzle.board.blanks.first { puzzle.hand.contains(puzzle.board.correctDigit(at: $0)) })
        let digit = puzzle.board.correctDigit(at: square)
        _ = try game.place(handIndex: XCTUnwrap(puzzle.hand.firstIndex(of: digit)), at: square)
        let livePreview = try XCTUnwrap(game.puzzle?.pendingScoringLedger)
        let turn = try game.endTurn()
        let ledger = try XCTUnwrap(turn.scoringLedger)
        let lines = ScorePerformance.explanation(for: ledger)
        XCTAssertTrue(lines.contains { $0.source == "Op-Ed Column" && $0.runningTotal == "Mult 1 → 2" })
        XCTAssertTrue(lines.contains { $0.source == "Stop the Presses" && $0.runningTotal == "Mult 2 → 6" })
        let receipt = ScorePerformance.banking(turn, previousScore: 0, finalScore: game.puzzle?.score ?? 0)
        XCTAssertEqual(receipt.beats.map(\.source), ["Turn points", "Op-Ed Column", "Stop the Presses", "BANKED", "Morning Edition"])
        let model = GameModel(resuming: game, savesProgress: false)
        model.presentScore(receipt)
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: livePreview))
        XCTAssertEqual(model.presentedQueue, digit.rawValue * 10)
        XCTAssertEqual(model.presentedMultiplier, 1)
        XCTAssertEqual(model.puzzle?.pendingBase, 0, "Engine has already committed the batch")
        let beat = try XCTUnwrap(receipt.beats.first { $0.sourceInstanceID == add.id.uuidString })
        model.advanceScore(beat, performanceID: receipt.id)
        XCTAssertEqual(model.bookmarkScoreLabel(instanceID: add.id), "+1 → ×2")
        XCTAssertEqual(model.presentedMultiplier, 2)
        XCTAssertEqual(model.liveScoreCalculation, LiveScoreCalculation(ledger: livePreview),
                       "Attribution steps must not mix an intermediate Mult with an already-final subtotal")
        let multiplyBeat = try XCTUnwrap(receipt.beats.first { $0.sourceInstanceID == multiply.id.uuidString })
        model.advanceScore(multiplyBeat, performanceID: receipt.id)
        XCTAssertEqual(model.presentedQueue, digit.rawValue * 10)
        XCTAssertEqual(model.presentedMultiplier, 6)
        let bank = try XCTUnwrap(receipt.beats.first { $0.kind == .bank })
        model.advanceScore(bank, performanceID: receipt.id)
        XCTAssertEqual(model.presentedScore, digit.rawValue * 60)
        XCTAssertEqual(model.presentedQueue, 0)
        XCTAssertEqual(model.presentedMultiplier, 1)
        XCTAssertEqual(model.liveScoreCalculation, .empty)
        model.advanceScore(try XCTUnwrap(receipt.beats.last), performanceID: receipt.id)
        XCTAssertEqual(model.presentedScore, digit.rawValue * 60 + 100)
        model.finishScorePresentation()
        XCTAssertNil(model.presentedMultiplier)
        XCTAssertNil(model.bookmarkScoreLabel(instanceID: multiply.id))
        XCTAssertEqual(ledger.total, digit.rawValue * 60 + 100)
    }

    func testFrozenPageNeverPlaysScoringAndResumeDoesNotReplayAwards() throws {
        var game = try startedGame()
        let base = try placeForMorningEdition(in: &game)
        let turn = try game.endTurn()
        let expectedScore = base + 100
        XCTAssertEqual(turn.pointsGained, expectedScore)
        let receipt = ScorePerformance.banking(turn, previousScore: 0, finalScore: expectedScore)
        XCTAssertFalse(receipt.beats.isEmpty, "A frozen page must reject a real earned receipt")
        let frozen = GameModel(frozen: game, page: .puzzle)
        frozen.presentScore(receipt)
        XCTAssertFalse(frozen.isPresentingScore)
        let restored = GameModel(resuming: try Game(decoding: game.encoded()), savesProgress: false)
        XCTAssertFalse(restored.isPresentingScore)
        XCTAssertEqual(restored.puzzle?.score, expectedScore)
    }

    func testEmptyTurnDoesNotInventMorningEditionAwardOrPresentation() throws {
        var game = try startedGame()
        let turn = try game.endTurn()
        XCTAssertEqual(turn.pointsGained, 0)
        XCTAssertEqual(game.puzzle?.score, 0)
        let receipt = ScorePerformance.banking(turn, previousScore: 0, finalScore: 0)
        XCTAssertTrue(receipt.beats.isEmpty)
        let model = GameModel(resuming: game, savesProgress: false)
        let saved = try model.game.encoded()
        model.presentScore(receipt)
        XCTAssertFalse(model.isPresentingScore)
        XCTAssertNil(model.presentedScore)
        XCTAssertEqual(try model.game.encoded(), saved)
    }

    func testMixedEligibleAndOnyxClueProductsStayExactThroughResumeAndBank() throws {
        var game = Game(seed: "mixed-live-score-products")
        try game.startPuzzle()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        func nonClearingSquare(_ digit: Digit) throws -> Square {
            try XCTUnwrap(puzzle.board.blanks.first { square in
                puzzle.board.correctDigit(at: square) == digit
                    && [Unit.row, .col, .box].allSatisfy { unit in
                        Geometry.cells(of: unit, through: square).filter { puzzle.board.isBlank($0) }.count > 2
                    }
            })
        }
        let ordinarySquare = try nonClearingSquare(.three)
        let clueSquare = try nonClearingSquare(.five)
        for card in puzzle.removeAllHandCards() { puzzle.pool.put(card.digit) }
        XCTAssertTrue(puzzle.pool.take(.three))
        puzzle.appendHandDigits([.three])
        let spare = try XCTUnwrap(Digit.all.first { $0 != .five && puzzle.pool[$0] > 0 })
        XCTAssertTrue(puzzle.pool.take(spare))
        puzzle.appendHandDigits([spare])
        puzzle.target = 100_000
        puzzle.boss = .sashimi
        run.puzzle = puzzle
        run.bookmarks = [Bookmarks.syndication, Bookmarks.stopThePresses].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0)
        }
        run.runItemState[Bookmarks.syndication] = 1 // An already earned ×1.25 factor.
        run.markers = [OwnedMarker(defID: Markers.onyx, boughtAtLevel: 1, pricePaid: 0, squares: [clueSquare])]
        run.buffs = [Buffs.peek, Buffs.tightDeadline].map { OwnedBuff(defID: $0, pricePaid: 0) }
        game = Game(run: run)

        XCTAssertTrue(try game.useBuff(at: 0)) // Earn the Clue from a real Peek; this Book starts without one.
        XCTAssertTrue(try game.useBuff(at: 0)) // +3 only on eligible Points.
        let ordinary = try game.place(handIndex: 0, at: ordinarySquare)
        let clue = try game.useClue(at: clueSquare)
        XCTAssertEqual(ordinary.points, 30)
        XCTAssertEqual(clue.points, 50)
        XCTAssertTrue(ordinary.lineClears.isEmpty)
        XCTAssertTrue(clue.lineClears.isEmpty)
        XCTAssertNil(ordinary.automaticTurn)
        XCTAssertNil(clue.automaticTurn)

        // (1+3)×1.25×3×0.5 versus 1×1.25×3×0.5.
        // Keep all fractional digits; floor the combined 318.75 once.
        let expected = LiveScoreCalculation(points: 80, multiplier: 318.75 / 80, total: 318,
            scoreLimitApplied: false, eligiblePoints: 30, eligibleMultiplier: 7.5, ineligibleMultiplier: 1.875)
        let model = GameModel(resuming: game, savesProgress: false)
        XCTAssertEqual(model.liveScoreCalculation, expected)
        XCTAssertEqual(model.liveScoreCalculation.factors, ["30 × 7.5", "50 × 1.875"])
        XCTAssertEqual(model.liveScoreCalculation.explanation, "30 × 7.5 plus 50 × 1.875")
        XCTAssertEqual(Int((30 * 7.5 + 50 * 1.875).rounded(.down)), model.liveScoreCalculation.total)
        let restored = GameModel(resuming: try Game(decoding: game.encoded()), savesProgress: false)
        XCTAssertEqual(restored.liveScoreCalculation, expected)

        let turn = try game.endTurn()
        XCTAssertEqual(turn.pointsGained, 318)
        XCTAssertEqual(game.puzzle?.score, 318)
        let performance = ScorePerformance.banking(turn, previousScore: 0, finalScore: 318)
        XCTAssertEqual(performance.bankCalculation, expected)
        let bankModel = GameModel(resuming: game, savesProgress: false)
        let saved = try bankModel.game.encoded()
        bankModel.presentScore(performance)
        XCTAssertEqual(bankModel.liveScoreCalculation.factors, expected.factors)
        let bank = try XCTUnwrap(performance.beats.first { $0.kind == .bank })
        XCTAssertEqual(bank.value, "+318")
        bankModel.advanceScore(bank, performanceID: performance.id)
        XCTAssertEqual(bankModel.presentedScore, 318)
        XCTAssertEqual(bankModel.liveScoreCalculation, .empty)
        XCTAssertEqual(try bankModel.game.encoded(), saved)
    }

    func testCappedBankPresentationShowsOnlyAwardedPointsAndNoPhantomMorningBonus() throws {
        var game = try startedGame()
        var run = game.run
        run.bookmarks = ["bm_stop_the_presses", "bm_morning_edition"].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0)
        }
        let startingScore = ScoreMath.ceiling - 10
        run.puzzle?.score = startingScore
        run.puzzle?.target = Int.max
        game = Game(run: run)
        let puzzle = try XCTUnwrap(game.puzzle)
        let square = try XCTUnwrap(puzzle.board.blanks.first {
            puzzle.hand.contains(puzzle.board.correctDigit(at: $0))
        })
        let index = try XCTUnwrap(puzzle.hand.firstIndex(of: puzzle.board.correctDigit(at: square)))
        _ = try game.place(handIndex: index, at: square)
        XCTAssertEqual(game.puzzle?.pendingScoringLedger.total, 10)
        XCTAssertEqual(game.puzzle?.pendingScoringLedger.scoreLimitApplied, true)
        let turn = try game.endTurn()
        let performance = ScorePerformance.banking(turn, previousScore: startingScore,
                                                   finalScore: ScoreMath.ceiling)
        XCTAssertEqual(performance.beats.first { $0.kind == .bank }?.value, "+10")
        let morning = try XCTUnwrap(performance.beats.first { $0.source == "Morning Edition" })
        XCTAssertEqual(morning.value, "+0 → \(ScoreMath.ceiling.formatted())")
        let model = GameModel(resuming: try Game(decoding: game.encoded()), savesProgress: false)
        let saved = try model.game.encoded()
        model.presentScore(performance)
        XCTAssertEqual(model.liveScoreCalculation.total, 10)
        XCTAssertTrue(model.liveScoreCalculation.scoreLimitApplied)
        model.advanceScore(morning, performanceID: performance.id)
        XCTAssertEqual(model.presentedScore, ScoreMath.ceiling)
        model.finishScorePresentation()
        XCTAssertEqual(try model.game.encoded(), saved)
        XCTAssertEqual(model.puzzle?.lastScoringLedger?.scoreLimitApplied, true)
    }

    #if DEBUG && targetEnvironment(simulator)
    func testFractionalCatalogueMultStaysExactThroughPreviewBankAndReceipt() throws {
        var game = try QAScoringFixture.simultaneousClears.makeGame()
        var run = game.run
        run.bookmarks = [Bookmarks.syndication, "bm_stop_the_presses"].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0)
        }
        run.runItemState[Bookmarks.syndication] = 1
        run.puzzle?.boss = .sashimi
        game = Game(run: run)

        _ = try game.place(handIndex: 0, at: Square(4))
        let preview = try XCTUnwrap(game.puzzle?.pendingScoringLedger)
        XCTAssertEqual(preview.points, 140)
        XCTAssertEqual(preview.multiplier, 1.875)
        XCTAssertEqual(preview.total, 262, "Floor 140 × 1.875 once; rounding Mult to 1.88 would promise 263")
        XCTAssertEqual(ScorePerformance.number(preview.multiplier), "1.875")
        let live = GameModel(resuming: game, savesProgress: false)
        XCTAssertEqual(live.liveScoreCalculation, LiveScoreCalculation(ledger: preview))
        let lines = ScorePerformance.explanation(for: preview)
        XCTAssertTrue(lines.contains { $0.runningTotal == "Mult 3.75 → 1.875" })

        let turn = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, 262)
        let receipt = ScorePerformance.banking(turn, previousScore: 0, finalScore: 262)
        XCTAssertTrue(receipt.beats.contains { $0.value == "×0.5 → ×1.875" })
        XCTAssertEqual(receipt.beats.last?.value, "+262")
        let restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.puzzle?.lastScoringLedger?.multiplier, 1.875)
        XCTAssertEqual(restored.puzzle?.lastScoringLedger?.total, 262)
    }
    #endif

    /// Qualifies Morning Edition using an actual held card and a non-clearing
    /// square, so the expected bank is exactly digit ×10 plus Local Gossip.
    private func placeForMorningEdition(in game: inout Game) throws -> Int {
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertGreaterThan(puzzle.hand.count, 1, "Keep manual banking under test")
        let square = try XCTUnwrap(puzzle.board.blanks.first { square in
            puzzle.hand.contains(puzzle.board.correctDigit(at: square))
                && [Unit.row, .col, .box].allSatisfy { unit in
                    Geometry.cells(of: unit, through: square).filter { puzzle.board.isBlank($0) }.count > 1
                }
        })
        let digit = puzzle.board.correctDigit(at: square)
        let index = try XCTUnwrap(puzzle.hand.firstIndex(of: digit))
        let outcome = try game.place(handIndex: index, at: square)
        let base = digit.rawValue * 10 + 30
        XCTAssertTrue(outcome.correct)
        XCTAssertNil(outcome.automaticTurn)
        XCTAssertEqual(outcome.points, base)
        return base
    }

    private func liveGame() throws -> Game {
        var run = try startedGame().run
        run.bookmarks = ["bm_op_ed", "bm_stop_the_presses", "bm_morning_edition"].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0)
        }
        run.buffs = [OwnedBuff(defID: Buffs.freshInk, pricePaid: 0)]
        run.puzzle?.target = 100_000
        return Game(run: run)
    }

    private func modifierGame(reversed: Bool = false, duplicateBuff: Bool = false,
                              fog: Bool = false) throws -> (game: Game, square: Square) {
        var game = Game(seed: "score-modifier-preview")
        try game.startPuzzle()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        let square = try XCTUnwrap(puzzle.board.blanks.first { square in
            puzzle.board.correctDigit(at: square) == .four
                && [Unit.row, .col, .box].allSatisfy { unit in
                    Geometry.cells(of: unit, through: square).filter { puzzle.board.isBlank($0) }.count > 1
                }
        })
        // This arranges a real hand from the existing pool and preserves all
        // number counts. The second card prevents an automatic Turn boundary.
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = []
        XCTAssertTrue(puzzle.pool.take(.four))
        puzzle.hand.append(.four)
        let spare = try XCTUnwrap(Digit.all.first { puzzle.pool[$0] > 0 })
        XCTAssertTrue(puzzle.pool.take(spare))
        puzzle.hand.append(spare)
        puzzle.target = 100_000
        if fog { puzzle.boss = .fog }
        run.puzzle = puzzle
        let bookmarkIDs = reversed ? ["bm_stop_the_presses", "bm_op_ed"] : ["bm_op_ed", "bm_stop_the_presses"]
        run.bookmarks = bookmarkIDs.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0) }
        run.markers = [OwnedMarker(defID: "mk_crimson", boughtAtLevel: 1, pricePaid: 0, squares: [square])]
        run.buffs = (0..<(duplicateBuff ? 2 : 1)).map { _ in OwnedBuff(defID: Buffs.freshInk, pricePaid: 0) }
        return (Game(run: run), square)
    }

    @discardableResult
    private func placeCorrect(in model: GameModel) throws -> Square {
        let puzzle = try XCTUnwrap(model.puzzle)
        let square = try XCTUnwrap(puzzle.board.blanks.first {
            puzzle.hand.contains(puzzle.board.correctDigit(at: $0))
        })
        let index = try XCTUnwrap(puzzle.hand.firstIndex(of: puzzle.board.correctDigit(at: square)))
        model.place(handIndex: index, at: square)
        XCTAssertEqual(model.lastOutcome?.correct, true)
        return square
    }
}
