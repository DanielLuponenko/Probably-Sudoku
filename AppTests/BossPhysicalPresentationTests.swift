import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BossPhysicalPresentationTests: XCTestCase {
    func testCountdownUsesCeilingAndWarningCrossingsWithoutAnotherClock() {
        for (seconds, expected) in [(240.0, "04:00"), (60, "01:00"), (30, "00:30"),
                                    (10, "00:10"), (0.001, "00:01"), (0, "00:00"), (-4, "00:00")] {
            XCTAssertEqual(TikTakCountdownValue(remaining: seconds, isPaused: false).text, expected)
        }
        XCTAssertEqual(TikTakCountdownValue(remaining: .nan, isPaused: false).text, "04:00")
        XCTAssertEqual(TikTakCountdownValue(remaining: 61, isPaused: false).accessibilityLabel,
                       "Time left, 1 minute, 1 second.")
        XCTAssertEqual(TikTakCountdownValue(remaining: 60, isPaused: false).urgency, .warning)
        XCTAssertEqual(TikTakCountdownValue(remaining: 30, isPaused: false).urgency, .urgent)
        XCTAssertEqual(TikTakCountdownValue(remaining: 10, isPaused: false).urgency, .finalSeconds)
        XCTAssertTrue(TikTakCountdownValue(remaining: 12, isPaused: true).caption.contains("Paused"))
        XCTAssertFalse(TikTakCountdownValue(remaining: 0, isPaused: true).isPaused)
        XCTAssertNil(TikTakCountdownValue.warningCrossed(from: 30, to: 30))
        XCTAssertNil(TikTakCountdownValue.warningCrossed(from: 30, to: 120))
        XCTAssertEqual(TikTakCountdownValue.warningCrossed(from: 61, to: 60), 60)
        XCTAssertEqual(TikTakCountdownValue.warningCrossed(from: 31, to: 30), 30)
        XCTAssertEqual(TikTakCountdownValue.warningCrossed(from: 11, to: 9), 10)
        XCTAssertEqual(TikTakCountdownValue.warningCrossed(from: 40, to: 0), 0)
    }

    func testCountdownAtEveryThresholdIsReadableInCompactHeaderAllocation() throws {
        for width in [CGFloat(129), 140, 160] {
            for seconds in [240.0, 60, 30, 10] {
                let value = TikTakCountdownValue(remaining: seconds, isPaused: false)
                let image = try image(TikTakCountdown(value: value, compact: true)
                    .frame(width: width, height: 58, alignment: .topTrailing)
                    .background(Paper.page).environment(\.gameReduceMotion, true))
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                XCTAssertTrue(text.contains(value.text), "Unreadable \(value.text) at \(width): \(text)")
                XCTAssertTrue(text.lowercased().contains("time left"), text)
                attach(image, "tik-tak-\(Int(width))-\(Int(seconds))")
            }
        }
    }

    func testFogHasTwoVisibleMovingStrataAndRemainsVisibleWithoutMotion() throws {
        let base = try image(Paper.page.frame(width: 300, height: 300))
        let still = try image(BossFogDrawing(elapsed: 0).frame(width: 300, height: 300).background(Paper.page))
        let moved = try image(BossFogDrawing(elapsed: 9).frame(width: 300, height: 300).background(Paper.page))
        XCTAssertNotEqual(base.pngData(), still.pngData())
        XCTAssertNotEqual(still.pngData(), moved.pngData())
        let center = CGRect(x: 100, y: 100, width: 100, height: 100)
        XCTAssertNotEqual(UIImage(cgImage: try XCTUnwrap(still.cgImage?.cropping(to: center))).pngData(),
                          UIImage(cgImage: try XCTUnwrap(moved.cgImage?.cropping(to: center))).pngData(),
                          "Fog must drift through the centre, not only around the edge")
        let normal = BossFogLayer.shouldAnimate(isActive: true, presented: true, sceneActive: true,
                                                ambient: true, reduced: false, lowPower: false)
        XCTAssertTrue(normal)
        for disabled in 0..<6 {
            XCTAssertFalse(BossFogLayer.shouldAnimate(isActive: disabled != 0, presented: disabled != 1,
                sceneActive: disabled != 2, ambient: disabled != 3, reduced: disabled == 4, lowPower: disabled == 5))
        }
        attach(still, "fog-settled-two-strata")
        attach(moved, "fog-drift-phase-nine")
    }

    func testEqualFogBoardsWithDifferentHiddenMapsHaveIdenticalPixelsAtEachPhase() async throws {
        let game = try fixture(.fog)
        let initial = try await BossHostedGridCapture.image(game, phase: 0)
        let drifted = try await BossHostedGridCapture.image(game, phase: 9)
        XCTAssertNotEqual(initial.pngData(), drifted.pngData(),
                          "The complete board must visibly render its fog phase")
        let blanks = try XCTUnwrap(game.puzzle?.board.blanks)
        let encoded = try game.encoded()
        for phase in [0.0, 2.0, 9.0] {
            let baseline = try await BossHostedGridCapture.image(game, phase: phase)
            for target in [try XCTUnwrap(blanks.first), try XCTUnwrap(blanks.last)] {
                var changed = game.run
                changed.markers = [OwnedMarker(defID: "mk_jade", boughtAtLevel: 1, pricePaid: 0, squares: [target])]
                let hidden = Game(run: changed)
                let concealed = try await BossHostedGridCapture.image(hidden, phase: phase)
                XCTAssertEqual(baseline.pngData(), concealed.pngData())
                let model = GameModel(frozen: hidden, page: .puzzle)
                XCTAssertTrue(model.visibleMarkers.isEmpty)
                XCTAssertNil(MarkerInspectionInfo.make(square: target, run: model.run))
            }
        }
        XCTAssertEqual(try game.encoded(), encoded)
    }

    func testWetInkRendersEveryOverlappingSavedFoulAndExpiresOnlyWithEngine() throws {
        var game = try fixture(.overPusher)
        let first = Set(try XCTUnwrap(game.puzzle?.bossTurn).fouled.keys)
        XCTAssertEqual(first.count, 3)
        _ = try game.endTurn()
        let second = Set(try XCTUnwrap(game.puzzle?.bossTurn).fouled.keys)
        XCTAssertEqual(second.count, 6)
        XCTAssertTrue(first.isSubset(of: second))
        let image = try image(BossInkLandingOverlay(squares: second, reduceMotion: true)
            .frame(width: 360, height: 360).background(Paper.page))
        attach(image, "shredder-six-real-overlapping-fouls")
        _ = try game.endTurn()
        let third = Set(try XCTUnwrap(game.puzzle?.bossTurn).fouled.keys)
        let thirdExpiries = try XCTUnwrap(game.puzzle?.bossTurn).fouled
        XCTAssertTrue(thirdExpiries.values.allSatisfy { $0 > 3 }, "Expired entries clear; a newly selected square may be fouled again")
        XCTAssertEqual(third.count, 6)
    }

    func testWetInkImpactSpreadsThenKeepsOneSettledPose() throws {
        var frames = [Data]()
        for elapsed in [0.05, 0.30, 0.55, 1.0, 5.0] {
            let rendered = try image(BossInkDrawing(size: 60, squareIndex: 31, elapsed: elapsed).background(Paper.page))
            frames.append(try XCTUnwrap(rendered.pngData()))
            attach(rendered, "ink-impact-\(elapsed)")
        }
        XCTAssertNotEqual(frames[0], frames[1])
        XCTAssertNotEqual(frames[1], frames[2])
        XCTAssertNotEqual(frames[2], frames[3])
        XCTAssertEqual(frames[3], frames[4])
    }

    func testBudgetCutReceiptUsesTheActualSingleFinalBankOperation() throws {
        var game = try fixture(.sashimi)
        let puzzle = try XCTUnwrap(game.puzzle)
        let square = try XCTUnwrap(puzzle.board.blanks.first {
            puzzle.hand.contains(puzzle.board.correctDigit(at: $0))
        })
        let handIndex = try XCTUnwrap(puzzle.hand.firstIndex(of: puzzle.board.correctDigit(at: square)))
        _ = try game.place(handIndex: handIndex, at: square)
        let preview = try XCTUnwrap(game.puzzle?.pendingScoringLedger.operations.first {
            $0.sourceID == "boss.sashimi"
        })
        XCTAssertFalse(BossScoreReceipt.supports(preview, banked: false),
                       "A live preview must not replay the bank's physical cut")
        _ = try game.endTurn()
        let operations = try XCTUnwrap(game.puzzle?.lastScoringLedger).operations.filter {
            $0.sourceID == "boss.sashimi"
        }
        XCTAssertEqual(operations.count, 1)
        let cut = try XCTUnwrap(operations.first)
        XCTAssertEqual(cut.after.mult, cut.before.mult * 0.5)
        XCTAssertTrue(BossScoreReceipt.supports(cut, banked: true))
        attach(try image(BossScoreReceipt(operation: cut).frame(width: 360, height: 24)
            .background(Paper.page).environment(\.gameReduceMotion, true)), "budget-cut-real-bank-receipt")
    }

    func testExpandedBossReceiptsUseRealPlacementAndBankOperations() throws {
        for boss in [BossModifier.backPage, .chainStitcher, .wordCount, .orphanLine, .serialPublisher, .rivalColumn] {
            var game = try fixture(boss)
            var effects: [ScoreOperation] = []
            for _ in 0..<3 {
                let puzzle = try XCTUnwrap(game.puzzle)
                let anchor = puzzle.bossState.scoring.chainAnchor
                let eligible = puzzle.board.blanks.filter { square in
                    puzzle.hand.contains(puzzle.board.correctDigit(at: square))
                }
                let square = try XCTUnwrap(eligible.first(where: { square in
                    guard let anchor, boss == .chainStitcher else { return true }
                    return square.row != anchor.row && square.col != anchor.col && square.box != anchor.box
                }) ?? eligible.first)
                let index = try XCTUnwrap(puzzle.hand.firstIndex(of: puzzle.board.correctDigit(at: square)))
                let outcome = try game.place(handIndex: index, at: square)
                effects += outcome.scoreReceipts.flatMap(\.operations).filter {
                    BossScoreReceipt.supports($0, banked: false)
                }
            }
            _ = try game.endTurn()
            let ledger = try XCTUnwrap(game.puzzle?.lastScoringLedger)
            effects += ledger.operations.filter { BossScoreReceipt.supports($0, banked: true) }
            let operation = try XCTUnwrap(effects.first { $0.sourceID == "boss.\(boss.rawValue)" },
                                          "No real affected receipt for \(boss.name)")
            let before = try game.encoded()
            let rendered = try image(BossScoreReceipt(operation: operation, settlement: ledger.bossSettlement)
                .frame(width: 360, height: 24).background(Paper.page).environment(\.gameReduceMotion, true))
            attach(rendered, "actual-receipt-\(boss.rawValue)")
            XCTAssertEqual(try game.encoded(), before)
        }
    }

    func testDryPressAndReviewBoardObjectsReflectOnlyTheirPublicSavedState() throws {
        let inked = try image(BossInkPadStatus(ready: true).frame(width: 145, height: 36).background(Paper.page))
        let dry = try image(BossInkPadStatus(ready: false).frame(width: 145, height: 36).background(Paper.page))
        XCTAssertNotEqual(inked.pngData(), dry.pngData())
        let pending = try image(BossReviewApprovalStatus(approved: []).frame(width: 145, height: 36).background(Paper.page))
        let rowApproved = try image(BossReviewApprovalStatus(approved: [.row]).frame(width: 145, height: 36).background(Paper.page))
        let allApproved = try image(BossReviewApprovalStatus(approved: [.row, .col, .box]).frame(width: 145, height: 36).background(Paper.page))
        XCTAssertNotEqual(pending.pngData(), rowApproved.pngData())
        XCTAssertNotEqual(rowApproved.pngData(), allApproved.pngData())
        attach(inked, "dry-press-inked-pad")
        attach(dry, "dry-press-dry-pad")
        attach(allApproved, "review-three-approved-stamps")
    }

    func testModelVisualLedgerRejectsRepeatedEventsWithoutSavingOrChangingGame() throws {
        let game = try fixture(.garryTheGray)
        let model = GameModel(resuming: game, savesProgress: false)
        let before = try model.game.encoded()
        XCTAssertNil(model.bossEntranceID, "Restored encounters start settled")
        XCTAssertFalse(model.hasConsumedBossVisualEvent("bricks:turn1"))
        XCTAssertTrue(model.consumeBossVisualEvent("bricks:turn1"))
        XCTAssertFalse(model.consumeBossVisualEvent("bricks:turn1"))
        XCTAssertTrue(model.consumeBossVisualEvent("bricks:turn2"))
        XCTAssertEqual(try model.game.encoded(), before)
        XCTAssertEqual(BossBoardDesign(boss: .deadline).headerRule(censored: nil, turns: 11), "11 turns")
    }

    func testCollectorReceiptUsesOnlySavedWithheldInterestAndPreservesPayout() throws {
        var run = try fixture(.collector).run
        run.coins = 47
        let payout = run.payout(for: try XCTUnwrap(run.puzzle))
        XCTAssertEqual(payout.suppressedInterest, 4)
        XCTAssertEqual(payout.interest, 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let saved = try encoder.encode(payout)
        let restored = try JSONDecoder().decode(RunState.Payout.self, from: saved)
        XCTAssertEqual(restored, payout)
        let rendered = try image(CollectorPayoutPrint(details: "Base +5", suppressed: restored.suppressedInterest,
            eventKey: nil).font(Print.body(15)).frame(width: 320, height: 40)
            .background(Paper.page).environment(\.gameReduceMotion, true))
        attach(rendered, "collector-saved-interest-receipt")
        XCTAssertEqual(try encoder.encode(restored), saved)
        XCTAssertEqual(restored.total, restored.base + restored.unusedTurns + restored.keepFillingBank
            + restored.paperRoute + restored.earlyDeadline + restored.stipend)
    }

    func testRestoredFinalDraftAndRoyaltyTargetsRenderActualValueWithoutReplayingTransformation() throws {
        for boss in [BossModifier.heavyLifter, .royaltyContract] {
            let view = BossTargetNumber(target: 24_000, boss: boss, fontSize: 16, entranceKey: nil)
            let actual = try image(view.frame(width: 170, height: 45).background(Paper.page))
            let plain = try image(BossTargetNumber(target: 24_000, boss: nil, fontSize: 16)
                .frame(width: 170, height: 45).background(Paper.page))
            XCTAssertEqual(actual.pngData(), plain.pngData(), "Restoration must not stage a smaller target or replay a contract")
            attach(actual, "restored-target-\(boss.rawValue)")
        }
    }

    func testPhysicalControlCuesStayWithinTheirExistingAllocations() throws {
        let row = HStack(spacing: 12) {
            BossEditorFold(handSize: 6)
            BossActionSeal()
            BossCrossedTossTab()
            BossTurnCut()
        }
        let rendered = try image(row.frame(width: 320, height: 36).background(Paper.page))
        XCTAssertEqual(rendered.size, CGSize(width: 320, height: 36))
        attach(rendered, "current-boss-control-paper-objects")
        let thread = BossBinderyThread(centers: [22, 69, 116, 163, 210], activeSlot: nil,
            beatID: nil, eventKey: nil, consumeEvent: { _ in XCTFail("A settled capture cannot consume an event"); return false })
        attach(try image(thread.frame(width: 240, height: 44).background(Paper.page)), "bindery-pinned-thread")
    }

    func testHandBossTreatmentsLeaveThePrintedNumeralAreaUnobstructed() throws {
        let tile = Text("8").font(Print.numeral(29, weight: .medium))
            .foregroundStyle(GameplaySurface.ink).frame(width: 44, height: 60).background(GameplaySurface.ivory)
        let baseline = try image(tile)
        let numeral = CGRect(x: 5, y: 8, width: 34, height: 30)
        let baselineNumeral = UIImage(cgImage: try XCTUnwrap(baseline.cgImage?.cropping(to: numeral))).pngData()
        for treatment in [BossHandTreatment.queueFront, .queueWaiting, .bookend, .middle,
                          .repeatWaiting, .packetWaiting(0), .packetWaiting(1), .sealed] {
            let rendered = try image(tile.overlay { BossHandTreatmentView(treatment: treatment) })
            let protected = UIImage(cgImage: try XCTUnwrap(rendered.cgImage?.cropping(to: numeral))).pngData()
            XCTAssertEqual(protected, baselineNumeral, "Boss treatment crossed the printed number: \(treatment)")
            XCTAssertNotEqual(rendered.pngData(), baseline.pngData(), "The restriction still needs its visible cue")
        }
    }

    func testSelectedBarredHandCardCannotAdvertiseAPlacementAccessibilityAction() throws {
        let game = try fixture(.handyDandy)
        let model = GameModel(frozen: game, page: .puzzle)
        let puzzle = try XCTUnwrap(model.puzzle)
        let barred = try XCTUnwrap(puzzle.hand.indices.first { model.isBlocked(handIndex: $0) })
        model.tapHandCard(puzzle.handCards[barred].id)
        XCTAssertEqual(model.selectedHandIndex, barred)
        let square = try XCTUnwrap(puzzle.board.blanks.first)
        let board = GridView(model: model, board: puzzle.board)
        let before = try model.game.encoded()
        let hint = board.accessibilityHint(for: square, digit: nil, state: .plain)
        XCTAssertEqual(hint, model.handRestrictionDescription(barred))
        XCTAssertFalse(hint.contains("Places number"))
        let playable = try XCTUnwrap(puzzle.hand.indices.first { !model.isBlocked(handIndex: $0) })
        model.tapHandCard(puzzle.handCards[playable].id)
        XCTAssertTrue(board.accessibilityHint(for: square, digit: nil, state: .plain).hasPrefix("Places number"))
        XCTAssertEqual(try model.game.encoded(), before)
    }

    private func fixture(_ boss: BossModifier) throws -> Game {
        var run = RunState(seed: "physical-boss-regression")
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss
        run.pendingBoss = boss
        if boss == .wordCount {
            run.bookmarks = (0..<3).map { _ in
                OwnedBookmark(defID: Bookmarks.localGossip, boughtAtLevel: 1, pricePaid: 0)
            }
        }
        var game = Game(run: run)
        try game.startPuzzle()
        return game
    }

    private func image<V: View>(_ view: V) throws -> UIImage {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }

    private func attach(_ image: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
