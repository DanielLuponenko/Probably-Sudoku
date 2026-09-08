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
        let resumed = GameModel(resuming: try Game(decoding: model.game.encoded()), savesProgress: false)
        XCTAssertEqual(resumed.payoutPreview, payout, "Full Clear's bank must survive with the whole receipt.")
        XCTAssertEqual(resumed.puzzle?.bankedPayout?.keepFillingBank, 6)
        model.openShop()
        XCTAssertEqual(model.page, .shop)
        XCTAssertNil(model.puzzle, "A Shop must not keep the previous Puzzle's receipt alive.")
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

    func testSuccessfulResultsPrintsItsPlayedBoardAndKeepsActionsReachable() throws {
        var partial = Game(seed: "results-played-board-partial")
        try partial.startPuzzle()
        partial.qaMeetTarget()
        let partialModel = GameModel(frozen: partial, page: .results)
        let partialBefore = try partialModel.game.encoded()
        let partialImage = try render(partialModel, named: "played-board-partial-phone")
        let partialText = try recognizedText(in: partialImage)
        XCTAssertTrue(partialText.contains("targetmet"), partialText)
        XCTAssertTrue(partialText.contains("boardasplayed"), partialText)
        XCTAssertTrue(partialText.contains("cashout"), partialText)
        XCTAssertEqual(try partialModel.game.encoded(), partialBefore)

        let full = try fullClearAfterKeepFilling()
        let fullModel = GameModel(frozen: full, page: .results)
        let fullImage = try render(fullModel, width: 834, height: 1210,
                                   horizontalSizeClass: .regular,
                                   named: "played-board-complete-ipad")
        let fullText = try recognizedText(in: fullImage)
        XCTAssertTrue(fullText.contains("boardcomplete"), fullText)
        XCTAssertTrue(fullText.contains("continue") || fullText.contains("cashout"), fullText)
        XCTAssertTrue(full.puzzle?.board.isFull == true)
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

    func testBankedReceiptSurvivesResumeWithoutRecomputingOrRecharging() throws {
        var game = Game(seed: "banked-receipt-resume")
        try game.startPuzzle()
        game.qaMeetTarget()
        let actualReceipt = try game.cashOut()
        let paidBytes = try game.encoded()
        let paidRun = game.run
        let frozen = GameModel(frozen: game, page: .results)
        XCTAssertEqual(frozen.payoutPreview, actualReceipt, "Rendering a banked result uses the same saved receipt.")

        let restored = try Game(decoding: paidBytes)
        let model = GameModel(resuming: restored, savesProgress: false)

        XCTAssertEqual(model.page, .results)
        XCTAssertEqual(model.puzzle?.phase, .cashedOut)
        XCTAssertEqual(try XCTUnwrap(model.payoutPreview), actualReceipt,
                       "A restored banked result must use its original receipt, not current coins.")
        XCTAssertEqual(model.coins, paidRun.coins)
        XCTAssertNil(model.lastPayout, "Resume must not synthesize a second in-memory payment.")
        XCTAssertEqual(model.puzzle?.hand, paidRun.puzzle?.hand)
        XCTAssertEqual(model.puzzle?.board.placed, paidRun.puzzle?.board.placed)
        XCTAssertEqual(model.run.book, paidRun.book)
        XCTAssertEqual(model.run.obstacle, paidRun.obstacle)
        XCTAssertEqual(model.run.streams.board.state, paidRun.streams.board.state)
        XCTAssertEqual(model.run.streams.pool.state, paidRun.streams.pool.state)
        XCTAssertEqual(model.run.streams.shop.state, paidRun.streams.shop.state)
        XCTAssertEqual(model.run.streams.boss.state, paidRun.streams.boss.state)

        var retry = restored
        let retryBefore = try retry.encoded()
        XCTAssertThrowsError(try retry.cashOut(), "A paid Puzzle cannot be cashed out twice.")
        XCTAssertEqual(retry.run.coins, paidRun.coins)
        XCTAssertEqual(try retry.encoded(), retryBefore)
    }

    func testLegacyBankedSaveDoesNotInventReceiptAndUnpaidWinStillPreviews() throws {
        var paid = Game(seed: "legacy-banked-receipt")
        try paid.startPuzzle()
        paid.qaMeetTarget()
        _ = try paid.cashOut()
        var paidJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: paid.encoded()) as? [String: Any])
        var paidPuzzle = try XCTUnwrap(paidJSON["puzzle"] as? [String: Any])
        paidPuzzle.removeValue(forKey: "bankedPayout")
        paidJSON["puzzle"] = paidPuzzle

        let legacyPaid = try Game(decoding: JSONSerialization.data(withJSONObject: paidJSON))
        let paidModel = GameModel(resuming: legacyPaid, savesProgress: false)
        XCTAssertEqual(paidModel.page, .results)
        XCTAssertEqual(paidModel.puzzle?.phase, .cashedOut)
        XCTAssertNil(paidModel.payoutPreview,
                     "An old paid save has no receipt and must not invent one from post-payment coins.")
        let coins = paidModel.coins
        paidModel.openShop()
        XCTAssertEqual(paidModel.page, .shop)
        XCTAssertNotNil(paidModel.shop)
        XCTAssertEqual(paidModel.coins, coins)

        var unpaid = Game(seed: "legacy-unpaid-win")
        try unpaid.startPuzzle()
        unpaid.qaMeetTarget()
        let expectedPreview = unpaid.run.payout(for: try XCTUnwrap(unpaid.puzzle))
        var unpaidJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: unpaid.encoded()) as? [String: Any])
        var unpaidPuzzle = try XCTUnwrap(unpaidJSON["puzzle"] as? [String: Any])
        unpaidPuzzle.removeValue(forKey: "bankedPayout")
        unpaidJSON["puzzle"] = unpaidPuzzle

        let legacyUnpaid = try Game(decoding: JSONSerialization.data(withJSONObject: unpaidJSON))
        let unpaidModel = GameModel(resuming: legacyUnpaid, savesProgress: false)
        XCTAssertEqual(unpaidModel.puzzle?.phase, .won)
        XCTAssertEqual(try XCTUnwrap(unpaidModel.payoutPreview), expectedPreview)
        XCTAssertNil(unpaidModel.lastPayout)
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

    private func render(_ model: GameModel, width: CGFloat = 328, height: CGFloat = 590,
                        horizontalSizeClass: UserInterfaceSizeClass = .compact,
                        named name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
            .frame(width: width, height: height)
            .padding(12)
            .environment(PageFlipper())
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.horizontalSizeClass, horizontalSizeClass)
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
