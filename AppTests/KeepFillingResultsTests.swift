import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class KeepFillingResultsTests: XCTestCase {
    func testFullClearCannotNavigateBackToAnUnplayableBoardOrDuplicateItsPayout() throws {
        let game = try fullClearAfterKeepFilling()
        let model = GameModel(frozen: game, page: .results)
        let before = try game.encoded()
        XCTAssertEqual(model.puzzle?.phase, .won)
        XCTAssertEqual(model.puzzle?.keepFillingCoins, 6, "Last row, column, box and Full Clear.")

        model.keepFilling()

        XCTAssertEqual(model.page, .results)
        XCTAssertEqual(try model.game.encoded(), before)
        let coins = model.coins
        let payout = try XCTUnwrap(model.payoutPreview)
        model.cashOut()
        model.cashOut()
        XCTAssertEqual(model.coins, coins + payout.total)
        XCTAssertEqual(model.puzzle?.phase, .cashedOut)
        model.openShop()
        XCTAssertEqual(model.page, .shop)
        XCTAssertNotNil(model.shop)
        XCTAssertNil(model.run.outcome)
    }

    func testPartialWonBoardStillContinuesWithTheSameScoreAndBoard() throws {
        var game = Game(seed: "partial-results-keep-filling")
        try game.startPuzzle()
        game.qaMeetTarget()
        let model = GameModel(frozen: game, page: .results)

        model.keepFilling()

        XCTAssertEqual(model.page, .puzzle)
        XCTAssertEqual(model.puzzle?.phase, .keepFilling)
        XCTAssertEqual(model.puzzle?.board.placed, game.puzzle?.board.placed)
        XCTAssertEqual(model.puzzle?.score, game.puzzle?.score)
        XCTAssertEqual(model.puzzle?.turnNumber, game.puzzle?.turnNumber)
        XCTAssertEqual(model.coins, game.run.coins)
    }

    func testResultsPrintsKeepFillingOnlyWhenThereArePlayableBlanks() throws {
        var partial = Game(seed: "results-keep-filling-copy")
        try partial.startPuzzle()
        partial.qaMeetTarget()
        for (name, game, offersKeepFilling) in [
            ("partial", partial, true),
            ("full-clear", try fullClearAfterKeepFilling(), false)
        ] {
            let model = GameModel(frozen: game, page: .results)
            let image = try render(model, named: name)
            let text = try recognizedText(in: image)
            XCTAssertTrue(text.contains("cashout"), text)
            XCTAssertEqual(text.contains("keepfilling"), offersKeepFilling, text)
            XCTAssertEqual(text.contains("playon"), offersKeepFilling, text)
            if !offersKeepFilling {
                XCTAssertTrue(text.contains("boardcomplete"), text)
                XCTAssertFalse(text.contains("totheshop"), text)
            }
        }
    }

    func testLegacyFullKeepFillingRestoresToResultsWithItsEarnedBankIntact() throws {
        let completed = try fullClearAfterKeepFilling()
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: completed.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(legacy["puzzle"] as? [String: Any])
        puzzle["phase"] = PuzzlePhase.keepFilling.rawValue
        legacy["puzzle"] = puzzle
        let restored = try Game(decoding: JSONSerialization.data(withJSONObject: legacy))

        let model = GameModel(resuming: restored, savesProgress: false)

        XCTAssertEqual(model.page, .results)
        XCTAssertEqual(model.puzzle?.phase, .won)
        XCTAssertEqual(model.puzzle?.board.placed, completed.puzzle?.board.placed)
        XCTAssertEqual(model.puzzle?.keepFillingCoins, completed.puzzle?.keepFillingCoins)
        XCTAssertEqual(model.puzzle?.score, completed.puzzle?.score)
        XCTAssertEqual(model.coins, completed.run.coins)
        XCTAssertNil(model.lastPayout, "Restoring the result must not cash out implicitly.")
    }

    /// Keep the final placement real so the fixture includes exactly one Full
    /// Clear bonus. All setup is in-memory and preserves digit conservation.
    private func fullClearAfterKeepFilling() throws -> Game {
        var game = Game(seed: "results-full-clear-keep-filling")
        try game.startPuzzle()
        game.qaMeetTarget()
        try game.keepFilling()
        let blanks = try XCTUnwrap(game.puzzle?.board.blanks)
        let last = try XCTUnwrap(blanks.last)
        for square in blanks.dropLast() {
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            XCTAssertTrue(game.qaPlace(digit: digit, at: square))
        }
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: last))
        if game.puzzle?.hand.contains(digit) != true { XCTAssertTrue(game.qaTakeFromPool(digit)) }
        let index = try XCTUnwrap(game.puzzle?.hand.firstIndex(of: digit))
        let outcome = try game.place(handIndex: index, at: last)
        XCTAssertTrue(outcome.fullClear)
        XCTAssertEqual(game.puzzle?.phase, .won)
        return game
    }

    private func render(_ model: GameModel, named name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
            .frame(width: 328, height: 590)
            .padding(12)
            .environment(PageFlipper())
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.dynamicTypeSize, .large)
            .transaction { $0.disablesAnimations = true }
            .background(Paper.page))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "keep-filling-results-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func recognizedText(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
