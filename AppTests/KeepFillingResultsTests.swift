import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class KeepFillingResultsTests: XCTestCase {
    func testEnlargedResultsGrowsEarnedCoinsAndDecisionsWithoutChangingTheGame() async throws {
        var game = Game(seed: "results-readable-enlargement")
        try game.startPuzzle()
        game.qaMeetTarget()
        let model = GameModel(frozen: game, page: .results)
        let before = try model.game.encoded()
        let normal = try await render(model, width: 386, height: 646,
                                      named: "readable-normal")
        let enlarged = try await render(model, width: 386, height: 646,
                                        dynamicType: .accessibility5, named: "readable-AX5")
        for phrase in ["coins", "cashout"] {
            let initial = try phrase == "coins"
                ? recognizedWordFrame("coins", in: normal.initial)
                : recognizedFrame(containing: phrase, in: normal.initial, exact: true)
            let larger = try phrase == "coins"
                ? recognizedWordFrame("coins", in: enlarged.initial)
                : recognizedFrame(containing: phrase, in: enlarged.initial, exact: true)
            XCTAssertGreaterThan(larger.height, initial.height * 1.2,
                                 "Earned coins and the decision must actually enlarge")
        }
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testEnlargedResultsShowsEveryEarnedPayoutComponentAndTheWholeBoard() async throws {
        var game = Game(seed: "results-all-payout-components")
        try game.startPuzzle()
        game.qaMeetTarget()
        var run = game.run
        run.coins = 100
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.paperRoute, boughtAtLevel: 1, pricePaid: 4)]
        run.puzzle?.keepFillingCoins = 12
        let model = GameModel(frozen: Game(run: run), page: .results)
        for (name, width, height) in [("SE", 359.0, 529.0), ("17pro", 386.0, 646.0)] {
            let rendered = try await render(model, width: width, height: height,
                                            dynamicType: .accessibility5, named: "all-payout-\(name)")
            let copy = try recognizedText(in: rendered.initial)
            for component in ["base", "unusedturns", "keptfilling", "interest", "paperroute"] {
                XCTAssertTrue(copy.contains(component), "\(name) omitted payout component \(component): \(copy)")
            }
        }
    }

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

    func testResultsPrintsKeepFillingOnlyWhenThereArePlayableBlanks() async throws {
        var partial = Game(seed: "results-keep-filling-copy")
        try partial.startPuzzle()
        partial.qaMeetTarget()
        for (name, game, offersKeepFilling) in [
            ("partial", partial, true),
            ("full-clear", try fullClearAfterKeepFilling(), false)
        ] {
            let model = GameModel(frozen: game, page: .results)
            let rendered = try await render(model, named: name)
            let initialText = try recognizedText(in: rendered.initial)
            let boardText = try recognizedText(in: rendered.boardVisible)
            XCTAssertTrue(initialText.contains("puzzlecomplete"), initialText)
            XCTAssertTrue(initialText.contains("cashout"), initialText)
            XCTAssertEqual(initialText.contains("keepfilling"), offersKeepFilling, initialText)
            XCTAssertEqual(initialText.contains("playon"), offersKeepFilling, initialText)
            XCTAssertTrue(boardText.contains(offersKeepFilling ? "boardasplayed" : "boardcomplete"), boardText)
            XCTAssertTrue(boardText.contains("cashout"), boardText)
            if !offersKeepFilling {
                XCTAssertTrue(initialText.contains("boardcomplete"), initialText)
                XCTAssertFalse(initialText.contains("totheshop"), initialText)
            }
        }
    }

    func testSuccessfulResultsPrintsItsPlayedBoardAndKeepsActionsReachable() async throws {
        var partial = Game(seed: "results-played-board-partial")
        try partial.startPuzzle()
        partial.qaMeetTarget()
        let partialModel = GameModel(frozen: partial, page: .results)
        let partialBefore = try partialModel.game.encoded()
        let partialImages = try await render(partialModel, named: "played-board-partial-phone")
        let partialHeader = try recognizedText(in: partialImages.initial)
        let partialBoard = try recognizedText(in: partialImages.boardVisible)
        XCTAssertTrue(partialHeader.contains("puzzlecomplete"), partialHeader)
        XCTAssertTrue(partialHeader.contains("targetmet"), partialHeader)
        XCTAssertTrue(partialHeader.contains("cashout"), partialHeader)
        XCTAssertTrue(partialBoard.contains("boardasplayed"), partialBoard)
        XCTAssertTrue(partialBoard.contains("cashout"), partialBoard)
        XCTAssertFalse(partialImages.scrolled, "All nine rows and both decisions must fit without scrolling.")
        XCTAssertEqual(try partialModel.game.encoded(), partialBefore)

        let largeText = try await render(partialModel, dynamicType: .accessibility5,
                                         named: "played-board-accessibility5")
        let keepFilling = try recognizedFrame(containing: "keepfilling", in: largeText.boardVisible, exact: true)
        let cashOut = try recognizedFrame(containing: "cashout", in: largeText.boardVisible, exact: true)
        XCTAssertLessThan(keepFilling.maxX, cashOut.minX,
                          "At AX5, complete labels share one compact decision row without hiding the board.")
        XCTAssertEqual(keepFilling.midY, cashOut.midY, accuracy: 18)
        XCTAssertGreaterThan(keepFilling.minX, 0)
        XCTAssertLessThan(keepFilling.maxX, largeText.boardVisible.size.width)

        for (name, width, height) in [("short-phone", 359.0, 529.0), ("iphone-17-pro-content", 386.0, 646.0)] {
            let fitted = try await render(partialModel, width: width, height: height,
                                          named: "played-board-\(name)")
            XCTAssertFalse(fitted.scrolled)
            XCTAssertEqual(try partialModel.game.encoded(), partialBefore)
        }
        let realPhone = try await render(partialModel, width: 402, height: 874,
                                         insideRunSurface: true,
                                         safeAreaInsets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0),
                                         named: "played-board-iphone-17-pro-fullscreen")
        XCTAssertFalse(realPhone.scrolled)

        let full = try fullClearAfterKeepFilling()
        let fullModel = GameModel(frozen: full, page: .results)
        let fullImages = try await render(fullModel, width: 834, height: 1210,
                                          horizontalSizeClass: .regular,
                                          named: "played-board-complete-ipad")
        let fullHeader = try recognizedText(in: fullImages.initial)
        let fullBoard = try recognizedText(in: fullImages.boardVisible)
        XCTAssertTrue(fullHeader.contains("puzzlecomplete"), fullHeader)
        XCTAssertTrue(fullHeader.contains("boardcomplete"), fullHeader)
        XCTAssertTrue(fullBoard.contains("boardcomplete"), fullBoard)
        XCTAssertTrue(fullBoard.contains("cashout"), fullBoard)
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

    private struct RenderedResults {
        let initial: UIImage
        let boardVisible: UIImage
        let scrolled: Bool
    }

    /// A real window verifies the rendered grid, its complete outer rim and
    /// all four horizontal box boundaries, above the visible decisions. Merely
    /// clipping an oversized board or hiding a ScrollView cannot satisfy this.
    private func render(_ model: GameModel, width: CGFloat = 328, height: CGFloat = 590,
                        horizontalSizeClass: UserInterfaceSizeClass = .compact,
                        dynamicType: DynamicTypeSize = .large,
                        insideRunSurface: Bool = false,
                        safeAreaInsets: EdgeInsets = EdgeInsets(),
                        named name: String) async throws -> RenderedResults {
        let before = try model.game.encoded()
        let ready = expectation(description: "Hosted Results layout: \(name)")
        var reportedLayout = false
        let flipper = PageFlipper()
        let page = ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
        let content = Group {
            if insideRunSurface {
                RunPageSurface(model: model, flipper: flipper, controls: [],
                               safeAreaInsets: safeAreaInsets, onTapBuff: { _ in }) { page }
            } else {
                page
            }
        }
            .frame(width: width, height: height)
            .environment(flipper)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
            .environment(\.levelPalette, .forDisplay(slot: .easy))
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.horizontalSizeClass, horizontalSizeClass)
            .environment(\.dynamicTypeSize, dynamicType)
            .transaction { $0.disablesAnimations = true }
            .background(Paper.page)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                if !reportedLayout, size.width > 0, size.height > 0 {
                    reportedLayout = true
                    ready.fulfill()
                }
            }
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.rootViewController = host
        defer {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        window.layoutIfNeeded()
        let initial = screenshot(window)
        attach(initial, name: "keep-filling-results-\(name)-initial-hosted")
        let initialAction = try recognizedFrame(containing: "cashout", in: initial, exact: true)
        XCTAssertGreaterThan(initialAction.minY, height / 2, "Decisions must remain at the bottom: \(name)")
        XCTAssertLessThanOrEqual(initialAction.maxY, height, name)

        let scrolls = scrollViews(in: host.view)
        XCTAssertTrue(scrolls.isEmpty, "The complete Results page must have no scroll container: \(name)")
        let boardVisible = initial
        attach(boardVisible, name: "keep-filling-results-\(name)-board-caption-hosted")
        let pinnedAction = try recognizedFrame(containing: "cashout", in: boardVisible, exact: true)
        XCTAssertEqual(pinnedAction.midY, initialAction.midY, accuracy: 1,
                       "Cash Out remains visible beside the complete board: \(name)")
        let caption = try recognizedFrame(containing: model.puzzle?.board.isFull == true
                                          ? "boardcomplete" : "boardasplayed", in: boardVisible,
                                          preferLast: true)
        XCTAssertGreaterThan(caption.minY, 0, "The board caption must be inside the visible viewport: \(name)")
        XCTAssertLessThan(caption.maxY, pinnedAction.minY,
                          "The board caption must be visible above, not hidden behind, the decisions: \(name)")
        try assertCompleteBoard(in: initial, before: caption, name: name,
                                minimumSide: dynamicType.isAccessibilitySize ? 140 : 200)
        XCTAssertEqual(try model.game.encoded(), before,
                       "Hosting Results must not place, score or pay out: \(name)")
        return RenderedResults(initial: initial, boardVisible: boardVisible, scrolled: !scrolls.isEmpty)
    }

    private func assertCompleteBoard(in image: UIImage, before caption: CGRect, name: String,
                                     minimumSide: Int) throws {
        let width = Int(image.size.width), height = Int(image.size.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                                space: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(try XCTUnwrap(image.cgImage), in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var rules: [(y: Int, left: Int, right: Int)] = []
        for y in 0..<min(height, Int(caption.minY)) {
            let matches = (0..<width).filter { x in
                let offset = (y * width + x) * 4
                let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
                return r < 150 && g > r + 15 && b > r + 10 && g > b + 4
            }
            if matches.count > min(width / 2, minimumSide - 10), let first = matches.first, let last = matches.last {
                rules.append((y, first, last))
            }
        }
        let top = try XCTUnwrap(rules.first, "No complete upper board rim: \(name)")
        let bottom = try XCTUnwrap(rules.last, "No complete lower board rim: \(name)")
        let boardWidth = rules.map { $0.right - $0.left }.max() ?? 0
        XCTAssertGreaterThanOrEqual(boardWidth, minimumSide,
                                   "Keep the whole preview visible while making space for enlarged receipt text: \(name)")
        XCTAssertEqual(CGFloat(bottom.y - top.y), CGFloat(boardWidth), accuracy: 5,
                       "Both rims of the entire square must be visible; a clipped ninth row fails: \(name)")
        var groups = 0
        var previousY = -10
        for row in rules {
            if row.y > previousY + 2 { groups += 1 }
            previousY = row.y
        }
        XCTAssertEqual(groups, 4, "Top, both box dividers, and bottom must be on screen: \(name)")
        XCTAssertLessThan(CGFloat(bottom.y), caption.minY,
                          "The caption and choices must follow all nine rows without overlap: \(name)")
    }

    private func screenshot(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func recognizedWordFrame(_ word: String, in image: UIImage) throws -> CGRect {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first,
                  let range = candidate.string.range(of: word, options: .caseInsensitive),
                  let bounds = try candidate.boundingBox(for: range)?.boundingBox else { continue }
            return CGRect(x: bounds.minX * image.size.width, y: (1 - bounds.maxY) * image.size.height,
                          width: bounds.width * image.size.width, height: bounds.height * image.size.height)
        }
        XCTFail("Missing complete rendered word: \(word)")
        return .zero
    }

    private func recognizedFrame(containing phrase: String, in image: UIImage,
                                 preferLast: Bool = false, exact: Bool = false) throws -> CGRect {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let matches = (request.results ?? []).filter { observation in
            guard let text = observation.topCandidates(1).first?.string.lowercased()
                .filter({ $0.isLetter || $0.isNumber }) else { return false }
            // Full-clear subtitles also contain "Cash out". Only the exact
            // printed button label identifies the pinned decision control.
            return exact ? text == phrase : text.contains(phrase)
        }
        // Vision lists text from top to bottom. The full-board subtitle can
        // also say "Board complete"; prefer the lower, actual board caption.
        let match = try XCTUnwrap(preferLast ? matches.min { $0.boundingBox.minY < $1.boundingBox.minY }
                                           : matches.first,
                                 "Visible Results text missing: \(phrase)")
        let box = match.boundingBox
        return CGRect(x: box.minX * image.size.width, y: (1 - box.maxY) * image.size.height,
                      width: box.width * image.size.width, height: box.height * image.size.height)
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
