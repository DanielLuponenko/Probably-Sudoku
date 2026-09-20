import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Numeric limits must be checked on the production HUD, not the retired
/// ScoreMeter. The fixed proposal is the actual compact phone content width.
@MainActor
final class GameplayScorePanelRenderingTests: XCTestCase {
    func testLiveFormulaShowsTheActualPointsMultiplierAndBankableTotal() throws {
        for compact in [false, true] {
            let live = try model(score: 42, points: 100, multiplier: 3)
            let saved = try live.game.encoded()
            XCTAssertEqual(live.liveScoreCalculation,
                           LiveScoreCalculation(points: 100, multiplier: 3, total: 300, scoreLimitApplied: false))
            let image = try render(live, name: "live-formula-\(compact ? "compact" : "regular")", compact: compact)
            let text = try recognize(image)
            let formula = normalizedFormula(text)
            XCTAssertTrue(formula.contains("+300") && formula.contains("100×3"),
                          "Players must see the pending gain with its actual supporting calculation: \(text)")
            XCTAssertFalse(formula.contains("=+"), "The result-first design does not repeat an equation: \(text)")
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Queued"),
                           "The old queue-only label must be replaced by the live formula")
            XCTAssertEqual(try live.game.encoded(), saved, "Reading a formula must not score it again")
        }
    }

    func testEmptyTurnHidesZeroCalculationWhileKeepingScoreAndBoss() throws {
        for compact in [false, true] {
            let live = try model(score: 200, points: 0, multiplier: 1)
            let image = try render(live, name: "empty-turn-\(compact)", compact: compact)
            let text = try recognize(image)
            XCTAssertTrue(digits(text).contains("200"), text)
            XCTAssertTrue(text.contains("Final Draft"), text)
            XCTAssertFalse(normalizedFormula(text).contains("+0"), text)
            XCTAssertFalse(normalizedFormula(text).contains("0×1"), text)
        }
    }

    func testLongAccessibilityReceiptFitsAboveTheScoreInItsFixedBand() throws {
        let arranged = try model(score: 200, points: 160, multiplier: 12)
        let live = GameModel(resuming: arranged.game, savesProgress: false)
        let beat = ScorePerformance.Beat(source: "Stop the Presses",
            value: "×9,000,000,000,000,000 Mult", kind: .multiplier,
            sourceID: "bm_stop_the_presses")
        live.presentScore(ScorePerformance(beats: [beat]))
        let image = try render(live, name: "large-text-receipt", type: .accessibility5)
        let lines = try observations(image)
        let text = lines.map(\.text).joined(separator: " ")
        XCTAssertTrue(text.contains("Stop the Presses"), text)
        XCTAssertTrue(digits(text).contains("9000000000000000"), text)
        XCTAssertTrue(normalizedFormula(text).contains("+1920"), text)
        let name = try XCTUnwrap(lines.first { $0.text.contains("Stop the Presses") })
        let effect = try XCTUnwrap(lines.first { digits($0.text).contains("9000000000000000") })
        let score = try XCTUnwrap(lines.first { digits($0.text).hasPrefix("200") })
        XCTAssertLessThanOrEqual(max(name.rect.maxY, effect.rect.maxY), score.rect.minY + 1)
        for line in lines { XCTAssertLessThanOrEqual(line.rect.maxY, 116, text) }
        XCTAssertEqual(image.size.height, 124, accuracy: 0.5)
    }

    func testSourceReceiptAppearingAndDisappearingDoesNotMoveTheScore() throws {
        for compact in [true, false] {
            let arranged = try model(score: 200, points: 160, multiplier: 12)
            let live = GameModel(resuming: arranged.game, savesProgress: false)
            let resting = try observations(render(live, name: "receipt-space-resting-\(compact)", compact: compact))
            let beat = ScorePerformance.Beat(source: "Stop the Presses", value: "×3 Mult", kind: .multiplier,
                                            sourceID: "bm_stop_the_presses")
            live.presentScore(ScorePerformance(beats: [beat]))
            let active = try observations(render(live, name: "receipt-space-active-\(compact)", compact: compact))
            let before = try XCTUnwrap(resting.first { digits($0.text).hasPrefix("200") })
            let after = try XCTUnwrap(active.first { digits($0.text).hasPrefix("200") })
            XCTAssertEqual(before.rect.minY, after.rect.minY, accuracy: 1,
                           "The source-label band must reserve its space even when empty")
            for line in active {
                XCTAssertLessThanOrEqual(line.rect.maxY, compact ? 82 : 98,
                                        "The entire score header must fit above the board: \(line.text)")
            }
        }
    }

    func testKeepFillingShowsScoreFrozenInsteadOfPromisingAnotherScoreAward() throws {
        let live = try model(score: 2_048_000, points: 100, multiplier: 3, phase: .keepFilling)
        let saved = try live.game.encoded()
        XCTAssertEqual(live.liveScoreCalculation, .empty)
        for compact in [false, true] {
            let image = try render(live, name: "keep-filling-frozen-\(compact ? "compact" : "regular")", compact: compact)
            let text = try recognize(image)
            XCTAssertTrue(text.localizedCaseInsensitiveContains("Score frozen"), text)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Queued"), text)
            XCTAssertFalse(normalizedFormula(text).contains("+300"),
                           "Keep Filling must not advertise the stale pending score as a new award")
            XCTAssertTrue(digits(text).contains("2048000"), "The frozen score must stay visible: \(text)")
        }
        XCTAssertEqual(try live.game.encoded(), saved)
    }

    func testCompactBossHUDKeepsLargeScoreAndTargetReadable() throws {
        for value in [9_000_000_000_000_000, Int.max] {
            let model = try model(score: value, points: 0, multiplier: 1)
            let image = try render(model, name: "score-\(value)")
            let text = try recognize(image)
            XCTAssertTrue(digits(text).contains(String(value)),
                          "The production boss HUD must expose every saved score digit: \(text)")
            XCTAssertTrue(digits(text).contains("2048000"),
                          "The score cannot crowd its target off the compact boss HUD: \(text)")
            XCTAssertTrue(text.localizedCaseInsensitiveContains("Final Draft"),
                          "The score cannot push the actual boss identity outside its allocated column: \(text)")
        }
    }

    func testCompactBossHUDKeepsBoundedFactorsFractionalMultAndActualTotalReadable() throws {
        for multiplier in [1.875, 1.52587890625, 2.5, 9_000_000_000_000_000.0] {
            let model = try model(score: 122_541, points: 9_000_000_000_000_000, multiplier: multiplier)
            let image = try render(model, name: "ceiling-formula-mult-\(multiplier)")
            let text = try recognize(image)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("Queued"), text)
            XCTAssertTrue(digits(text).contains("9000000000000000"),
                          "Capped Points must not become an ellipsis: \(text)")
            let actualTotal = try XCTUnwrap(model.puzzle).pendingScoringLedger.total
            XCTAssertTrue(normalizedFormula(text).contains("+\(actualTotal)"),
                          "The displayed total must be the actual bankable award after the score ceiling: \(text)")
            if multiplier < 3 {
                XCTAssertTrue(text.contains(String(multiplier)),
                              "A fractional Mult must remain visible beside the Points factor: \(text)")
            } else {
                let occurrences = digits(text).components(separatedBy: "9000000000000000").count - 1
                XCTAssertGreaterThanOrEqual(occurrences, 2,
                               "Both capped Points and capped Mult must be represented; a repeated total is also allowed: \(text)")
            }
        }
    }

    func testCompactBossHUDKeepsCombinedExtremeNumbersAndActiveReceiptInsideItsBand() throws {
        let arranged = try model(score: Int.max, points: 9_000_000_000_000_000,
                                 multiplier: 9_000_000_000_000_000)
        let live = GameModel(resuming: arranged.game, savesProgress: false)
        let beat = ScorePerformance.Beat(source: "Stop the Presses", value: "×3", kind: .multiplier,
                                        sourceID: "bm_stop_the_presses")
        live.presentScore(ScorePerformance(beats: [beat], bankedFrom: Int.max,
            queuedFrom: 9_000_000_000_000_000, multiplierFrom: 9_000_000_000_000_000))
        XCTAssertNotNil(live.scoreBeat, "The screenshot must contain an actual active receipt")
        let saved = try live.game.encoded()
        let image = try render(live, name: "combined-extremes-active-receipt")
        let lines = try observations(image)
        let text = lines.map(\.text).joined(separator: " ")
        XCTAssertTrue(digits(text).contains(String(Int.max)), text)
        XCTAssertTrue(digits(text).contains("2048000"), text)
        XCTAssertGreaterThanOrEqual(digits(text).components(separatedBy: "9000000000000000").count - 1, 2, text)
        XCTAssertTrue(normalizedFormula(text).contains("+0"),
                      "A historical score above the current ceiling cannot receive a new score award: \(text)")
        XCTAssertTrue(text.localizedCaseInsensitiveContains("Final Draft"), text)
        let receipt = try XCTUnwrap(lines.first { $0.text.localizedCaseInsensitiveContains("Stop the Presses") },
                                   "The active receipt must remain readable above the score: \(text)")
        let factorLines = lines.filter { digits($0.text).contains("9000000000000000") }
        let factorTop = try XCTUnwrap(factorLines.map(\.rect.minY).min())
        XCTAssertLessThanOrEqual(receipt.rect.maxY, factorTop + 1,
                                   "The receipt cannot overlap the Points or Mult line")
        let totalLine = try XCTUnwrap(lines.first { normalizedFormula($0.text).contains("+0") })
        XCTAssertLessThanOrEqual(receipt.rect.maxY, totalLine.rect.minY + 1,
                                   "The active receipt cannot overlap the formula total")
        for line in factorLines + [totalLine, receipt] {
            XCTAssertGreaterThanOrEqual(line.rect.minX, 7)
            XCTAssertLessThanOrEqual(line.rect.maxX, image.size.width - 7,
                                     "All formula and receipt text must remain inside the HUD capture")
        }
        XCTAssertLessThanOrEqual(receipt.rect.maxY, 82,
                                 "74-point HUD plus its 8-point top capture margin; no spill into the board")
        XCTAssertEqual(image.size.height, 90, accuracy: 0.5,
                       "The fixed HUD allocation cannot grow to make the receipt fit")
        XCTAssertEqual(try live.game.encoded(), saved, "Rendering cannot reapply a scoring operation")
    }

    private func model(score: Int, points: Int, multiplier: Double,
                       phase: PuzzlePhase = .playing) throws -> GameModel {
        var game = Game(seed: "independent-hud-number-limits")
        try game.startPuzzle()
        var run = game.run
        run.puzzle?.boss = .heavyLifter
        run.puzzle?.phase = phase
        run.puzzle?.score = score
        run.puzzle?.target = 2_048_000
        run.puzzle?.pendingBase = points
        run.puzzle?.pendingMult = 1
        run.puzzle?.itemState[Buffs.freshInk] = multiplier - 1
        let model = GameModel(frozen: Game(run: run), page: .puzzle)
        XCTAssertEqual(try XCTUnwrap(model.puzzle).pendingMultiplier, multiplier,
                       "The rendered fixture must exercise the requested v2 Mult")
        return model
    }

    private func render(_ model: GameModel, name: String, compact: Bool = true,
                        type: DynamicTypeSize = .large) throws -> UIImage {
        let puzzle = try XCTUnwrap(model.puzzle)
        let renderer = ImageRenderer(content: GameplayScorePanel(model: model, puzzle: puzzle, compact: compact)
            .frame(width: compact ? 359 : 386, height: type.isAccessibilitySize ? 108 : compact ? 74 : 90)
            .padding(8)
            .background(GameplaySurface.ivory)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.levelPalette, .boss)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.dynamicTypeSize, type)
            .transaction { $0.disablesAnimations = true })
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "actual-gameplay-hud-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/numberclub-actual-gameplay-hud-\(name).png"))
        return image
    }

    private struct PrintedLine {
        let text: String
        let rect: CGRect
    }

    private func recognize(_ image: UIImage) throws -> String {
        try observations(image).map(\.text).joined(separator: " ")
    }

    private func observations(_ image: UIImage) throws -> [PrintedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let rect = observation.boundingBox
            return PrintedLine(text: text,
                rect: CGRect(x: rect.minX * image.size.width,
                             y: (1 - rect.maxY) * image.size.height,
                             width: rect.width * image.size.width,
                             height: rect.height * image.size.height))
        }
    }

    private func normalizedFormula(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "x", with: "×")
            .replacingOccurrences(of: "X", with: "×")
            .filter { !$0.isWhitespace }
    }

    private func digits(_ text: String) -> String { text.filter(\.isNumber) }
}
