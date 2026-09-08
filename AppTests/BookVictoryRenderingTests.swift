import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

/// All inputs are in-memory completed games. No live model, saved progress,
/// profile, ad service or game action is used while rendering these pages.
@MainActor
final class BookVictoryRenderingTests: XCTestCase {
    func testCompletedBookFitsBothPhoneLayoutsAndPrintsItsActualIdentity() throws {
        let fixture = try completedBook()
        for compact in [false, true] {
            let image = try render(contents(fixture, compact: compact),
                                   named: compact ? "compact" : "regular")
            XCTAssertEqual(image.size.width, 328, accuracy: 0.5)
            XCTAssertLessThanOrEqual(image.size.height, compact ? 590 : 680,
                                    "The normal-size victory page and its close button must fit the Book.")
            let text = try recognizedText(in: image)
            assertContains(text, "Book Complete", fixture.summary.edition.title,
                           "Final Boss Beaten", fixture.bossName,
                           "Obstacle II", "In this Book only", "Close the Book")
        }
    }

    func testMaximumObstacleDoesNotInventAnotherObstacleOrBookUnlock() throws {
        let fixture = try completedBook(obstacle: .finalEdition)
        let image = try render(contents(fixture, compact: true), named: "maximum-obstacle-IX")
        let text = try recognizedText(in: image)
        assertContains(text, "Book Complete", "Obstacle IX", "All 9 obstacles conquered", "Close the Book")
        XCTAssertFalse(text.contains(normalize("Obstacle X")), text)
        XCTAssertFalse(text.contains(normalize("unlocked")), text)
        XCTAssertFalse(text.contains(normalize("next Book")), text)
        XCTAssertFalse(text.contains(normalize("next obstacle")), text)
        XCTAssertFalse(text.contains(normalize("Obstacle II is ready")), text)
    }

    func testNextChallengeTitleUsesTheExactNextObstacleAndStopsAtNine() throws {
        let fixture = try completedBook()
        let expected = [
            "Obstacle II is ready", "Obstacle III is ready", "Obstacle IV is ready",
            "Obstacle V is ready", "Obstacle VI is ready", "Obstacle VII is ready",
            "Obstacle VIII is ready", "Obstacle IX is ready", "All 9 obstacles conquered"
        ]
        for (obstacle, title) in zip(Obstacle.allCases, expected) {
            for compact in [false, true] {
                let page = BookVictoryContents(summary: fixture.summary, board: fixture.model.puzzle?.board,
                                              bossName: fixture.bossName, obstacle: obstacle, compact: compact)
                XCTAssertEqual(page.nextChallengeTitle, title,
                               "The semantic title must preserve the exact numeral, independent of OCR.")
            }
        }
        XCTAssertEqual(Obstacle.allCases.count, expected.count)
    }

    func testOCRAliasCorrectionIsRestrictedToTheTwoVisuallyVerifiedPhrases() {
        XCTAssertEqual(normalize("Obstacle Il is ready"), normalize("Obstacle II is ready"))
        XCTAssertEqual(normalize("Ail 9 obstacles conquered"), normalize("All 9 obstacles conquered"))
        XCTAssertEqual(normalize("Obstacle III is ready"), "obstacleiiiisready")
        XCTAssertEqual(normalize("Obstacle IX is ready"), "obstacleixisready")
        XCTAssertNotEqual(normalize("Obstacle I is ready"), normalize("Obstacle II is ready"),
                          "A genuinely missing numeral must still fail visual assertions.")
        XCTAssertEqual(normalize("Illegible final illustration"), "illegiblefinalillustration")
        XCTAssertEqual(normalize("Ail 9 illustrations"), "ail9illustrations")
    }

    func testLongRealNamesAndNineDigitBestScoreStayReadableAtPhoneWidths() throws {
        let fixture = try completedBook(edition: .eighth, bestScore: 123_456_789)
        XCTAssertEqual(fixture.bossName, "The Executive Editor")
        for width: CGFloat in [300, 328, 365] {
            let image = try render(contents(fixture, compact: true), width: width,
                                   named: "long-names-high-score-\(Int(width))")
            XCTAssertEqual(image.size.width, width, accuracy: 0.5)
            let text = try recognizedText(in: image)
            assertContains(text, "Professionally Overthinking", "The Executive Editor",
                           "123,456,789", "Close the Book")
            if width == 328 { XCTAssertLessThanOrEqual(image.size.height, 590) }
        }
    }

    func testRenderingPreservesTheRealBlanksAndDoesNotChangeTheCompletedRun() throws {
        let fixture = try completedBook()
        let board = try XCTUnwrap(fixture.model.puzzle?.board)
        XCTAssertFalse(board.isFull, "A score win fixture deliberately retains unfilled squares.")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(fixture.model.run)
        let actual = try render(contents(fixture, compact: true), named: "actual-partial-final-board")
        XCTAssertEqual(try encoder.encode(fixture.model.run), before)
        XCTAssertEqual(fixture.model.puzzle?.board.placed, board.placed)
        XCTAssertEqual(fixture.model.puzzle?.board.filledBy, board.filledBy)
        XCTAssertEqual(fixture.model.run.outcome, .bookCompleted)
        XCTAssertEqual(fixture.model.puzzle?.phase, .cashedOut)

        // Only this local visual control is filled, never the frozen model.
        // If the victory view secretly fills its input from the solution,
        // these two images would be identical and the regression would fail.
        var solvedControl = board
        for square in solvedControl.blanks {
            solvedControl.fill(square, with: solvedControl.correctDigit(at: square), by: .player)
        }
        let control = try render(BookVictoryContents(summary: fixture.summary, board: solvedControl,
                                bossName: fixture.bossName, obstacle: fixture.model.run.obstacle, compact: true),
                                 named: "comparison-only-synthetic-filled-board")
        XCTAssertNotEqual(try XCTUnwrap(actual.pngData()), try XCTUnwrap(control.pngData()),
                          "The printed board must distinguish real blanks from a filled control.")
        XCTAssertEqual(try encoder.encode(fixture.model.run), before)
    }

    func testAccessibilityFiveContentGrowsWithoutLosingTheCloseDecision() throws {
        let fixture = try completedBook()
        let content = contents(fixture, compact: true)
        let regular = try render(content, named: "dynamic-type-large")
        let accessible = try render(content, dynamicType: .accessibility5,
                                    named: "dynamic-type-accessibility5-full-content")
        XCTAssertGreaterThan(accessible.size.height, regular.size.height)
        XCTAssertGreaterThan(accessible.size.height, 590)
        XCTAssertEqual(accessible.size.width, 328, accuracy: 0.5)
        assertContains(try recognizedText(in: accessible), "Book Complete", fixture.summary.edition.title,
                       "Obstacle II", "In this Book only", "Close the Book")
    }

    func testCompletedResultsRoutesToVictoryInTheRealPhoneBookInsteadOfShopActions() async throws {
        let fixture = try completedBook()
        let image = try await renderResultsInBook(fixture.model, named: "completed-results-real-book-375x812")
        XCTAssertEqual(image.size, CGSize(width: 375, height: 812))
        let text = try recognizedText(in: image)
        assertContains(text, "Book Complete", fixture.summary.edition.title,
                       "Final Boss Beaten", fixture.bossName, "Obstacle II", "Close the Book")
        for obsolete in ["Continue", "To the Shop", "Keep Filling", "Cash Out"] {
            XCTAssertFalse(text.contains(normalize(obsolete)), "Completed Book offered \(obsolete): \(text)")
        }
        XCTAssertEqual(fixture.model.run.outcome, .bookCompleted)
        XCTAssertEqual(fixture.model.puzzle?.phase, .cashedOut)
    }

    func testRegularWonAndBankedResultsKeepTheirExistingPuzzleChoices() async throws {
        var game = Game(seed: "book-victory-nonterminal-routing")
        try game.startPuzzle()
        game.qaMeetTarget()
        let won = GameModel(frozen: game, page: .results)
        let wonImage = try await renderResultsInBook(won, named: "regular-won-results-real-book")
        let wonText = try recognizedText(in: wonImage)
        assertContains(wonText, "Puzzle Complete", "Keep Filling", "Cash Out")
        XCTAssertFalse(wonText.contains(normalize("Book Complete")), wonText)
        XCTAssertFalse(wonText.contains(normalize("Close the Book")), wonText)

        _ = try game.cashOut()
        let banked = GameModel(frozen: game, page: .results)
        let bankedImage = try await renderResultsInBook(banked, named: "regular-banked-results-real-book")
        let bankedText = try recognizedText(in: bankedImage)
        assertContains(bankedText, "Puzzle Complete", "Continue", "To the Shop")
        XCTAssertFalse(bankedText.contains(normalize("Book Complete")), bankedText)
        XCTAssertFalse(bankedText.contains(normalize("Close the Book")), bankedText)
        XCTAssertNil(banked.run.outcome)
    }

    func testIPadResultsKeepPayoutNearHeaderAndActionsAtBottomWithoutMutatingRun() async throws {
        var game = Game(seed: "book-victory-ipad-results-spacing")
        try game.startPuzzle()
        game.qaMeetTarget()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let won = GameModel(frozen: game, page: .results)
        let wonBoard = try XCTUnwrap(won.puzzle?.board)
        XCTAssertFalse(wonBoard.isFull, "The preview fixture must retain real blank cells.")
        let wonBefore = try encoder.encode(won.run)
        let wonImage = try await renderResultsInBook(
            won,
            viewport: CGSize(width: 834, height: 1210),
            horizontalSizeClass: .regular,
            named: "regular-won-results-real-book-ipad"
        )
        try assertResultsSpacing(in: wonImage, action: "Cash Out",
                                 score: try XCTUnwrap(won.puzzle?.score),
                                 target: try XCTUnwrap(won.puzzle?.target))
        assertContains(try recognizedText(in: wonImage), "Your board, as played")
        XCTAssertEqual(try encoder.encode(won.run), wonBefore,
                       "Rendering the won results page must not mutate the run")

        _ = try game.cashOut()
        let banked = GameModel(frozen: game, page: .results)
        let bankedBefore = try encoder.encode(banked.run)
        let bankedImage = try await renderResultsInBook(
            banked,
            viewport: CGSize(width: 834, height: 1210),
            horizontalSizeClass: .regular,
            named: "regular-banked-results-real-book-ipad"
        )
        try assertResultsSpacing(in: bankedImage, action: "Continue",
                                 score: try XCTUnwrap(banked.puzzle?.score),
                                 target: try XCTUnwrap(banked.puzzle?.target))
        assertContains(try recognizedText(in: bankedImage), "Your board, as played")
        XCTAssertEqual(try encoder.encode(banked.run), bankedBefore,
                       "Rendering the banked results page must not mutate the run")
    }

    func testShortRegularResultsOmitBoardPreviewAndKeepActionsVisible() async throws {
        var game = Game(seed: "book-victory-short-regular-results")
        try game.startPuzzle()
        game.qaMeetTarget()
        let won = GameModel(frozen: game, page: .results)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(won.run)
        let image = try await renderResultsInBook(
            won,
            viewport: CGSize(width: 834, height: 700),
            horizontalSizeClass: .regular,
            named: "short-regular-won-results"
        )
        let text = try recognizedText(in: image)
        XCTAssertFalse(text.contains(normalize("Your board, as played")), text)
        assertContains(text, "Puzzle Complete", "Cash Out")
        try assertResultsSpacing(in: image, action: "Cash Out",
                                 score: try XCTUnwrap(won.puzzle?.score),
                                 target: try XCTUnwrap(won.puzzle?.target))
        XCTAssertEqual(try encoder.encode(won.run), before,
                       "Short regular rendering must not mutate the run")
    }

    func testAccessibilityFiveCanScrollToCloseInsideTheRealBookContainer() async throws {
        let fixture = try completedBook()
        let flipper = PageFlipper()
        let viewport = CGSize(width: 375, height: 812)
        let content = VStack(spacing: 0) {
            Color.clear.frame(height: 86) // The unchanged HUD/bookmark reservation.
            BookView(flipper: flipper) {
                BookVictoryPage(summary: fixture.summary, board: fixture.model.puzzle?.board,
                                bossName: fixture.bossName, obstacle: fixture.model.run.obstacle,
                                onClose: {})
            }
            .padding(.leading, 8).padding(.trailing, 10)
        }
        .padding(.bottom, 8)
        .frame(width: viewport.width, height: viewport.height)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.dynamicTypeSize, .accessibility5)
        .transaction { $0.disablesAnimations = true }
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: viewport)
        window.rootViewController = controller
        defer {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        let settled = expectation(description: "Victory scroll view completed layout")
        DispatchQueue.main.async { window.layoutIfNeeded(); settled.fulfill() }
        await fulfillment(of: [settled], timeout: 3)

        func scrollViews(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        let scroll = try XCTUnwrap(scrollViews(in: controller.view).first)
        XCTAssertGreaterThan(scroll.bounds.height, 100)
        XCTAssertLessThanOrEqual(scroll.bounds.height, viewport.height - 86 - 8 - 26 - 18)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height + 100)
        let visibleFrame = scroll.convert(scroll.bounds, to: window)
        XCTAssertGreaterThanOrEqual(visibleFrame.minY, 86)
        XCTAssertLessThanOrEqual(visibleFrame.maxY, viewport.height - 8)
        let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
        window.layoutIfNeeded()
        XCTAssertEqual(scroll.contentOffset.y, bottom, accuracy: 1)
        let image = UIGraphicsImageRenderer(size: viewport).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        attach(image, named: "accessibility5-real-book-scrolled-to-close")
        assertContains(try recognizedText(in: image), "Close the Book", "Back to the shelf")
        XCTAssertFalse(try XCTUnwrap(fixture.model.puzzle?.board).isFull)
        XCTAssertEqual(fixture.model.run.outcome, .bookCompleted)
    }

    private struct Fixture {
        let model: GameModel
        let summary: GameModel.BookCompletionSummary
        let bossName: String
    }

    private func completedBook(edition: BookEdition = .first, obstacle: Obstacle = .none,
                               bestScore: Int = 122_541) throws -> Fixture {
        var run = RunState(seed: "book-victory-print-\(edition.rule.rawValue)-\(obstacle.rawValue)",
                           book: edition.rule, obstacle: obstacle)
        run.level = 9
        run.slot = .boss
        run.pendingBoss = .unluckyLucky
        run.bestPuzzleScore = bestScore
        var game = Game(run: run)
        try game.startPuzzle()
        game.qaMeetTarget()
        _ = try game.cashOut()
        let model = GameModel(frozen: game, page: .results)
        let summary = try XCTUnwrap(model.bookCompletionSummary)
        return Fixture(model: model, summary: summary,
                       bossName: try XCTUnwrap(model.puzzle?.boss).name)
    }

    private func contents(_ fixture: Fixture, compact: Bool) -> BookVictoryContents {
        BookVictoryContents(summary: fixture.summary, board: fixture.model.puzzle?.board,
                            bossName: fixture.bossName, obstacle: fixture.model.run.obstacle, compact: compact)
    }

    private func render(_ content: BookVictoryContents, width: CGFloat = 328,
                        dynamicType: DynamicTypeSize = .large, named name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: content
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.dynamicTypeSize, dynamicType)
            .transaction { $0.disablesAnimations = true }
            .background(Paper.page))
        // No fixed screenshot height: expose the content's true size.
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) failed to render")
        XCTAssertTrue(image.size.height.isFinite)
        XCTAssertGreaterThan(image.size.height, 0)
        attach(image, named: name)
        return image
    }

    private func renderResultsInBook(
        _ model: GameModel,
        viewport: CGSize = CGSize(width: 375, height: 812),
        horizontalSizeClass: UserInterfaceSizeClass = .compact,
        named name: String
    ) async throws -> UIImage {
        let flipper = PageFlipper()
        let content = VStack(spacing: 0) {
            // Use the real HUD with frozen values and inert controls, while
            // retaining the same combined HUD/bookmark space as the layout proof.
            IslandBar(coins: model.coins, controls: [
                StripControl(systemImage: "rosette", label: "Achievements", action: {}),
                StripControl(systemImage: "questionmark", label: "Run information", action: {}),
                StripControl(systemImage: "gearshape", label: "Settings", action: {})
            ])
            .frame(height: 86, alignment: .top)
            BookView(flipper: flipper) {
                ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
            }
            .padding(.leading, 8).padding(.trailing, 10)
        }
        .padding(.bottom, 8)
        .frame(width: viewport.width, height: viewport.height)
        .background(Paper.deskDark)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.horizontalSizeClass, horizontalSizeClass)
        .environment(\.dynamicTypeSize, .large)
        .transaction { $0.disablesAnimations = true }
        // BookView contains a UIKit capture anchor. Host the actual hierarchy
        // rather than flattening that representable through ImageRenderer,
        // which can incorrectly apply the book's shadow to every text glyph.
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: viewport)
        window.rootViewController = controller
        defer {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        let settled = expectation(description: "\(name) hosted hierarchy completed layout")
        DispatchQueue.main.async { window.layoutIfNeeded(); settled.fulfill() }
        await fulfillment(of: [settled], timeout: 3)
        let image = UIGraphicsImageRenderer(size: viewport).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        attach(image, named: name)
        return image
    }

    private struct PrintedObservation {
        let text: String
        let bounds: CGRect
    }

    private func assertResultsSpacing(in image: UIImage, action: String,
                                      score: Int, target: Int) throws {
        let observations = try printedObservations(in: image)
        let base = try XCTUnwrap(observations.first { normalize($0.text).contains("base") },
                                 "The payout Base line must remain visible")
        let baseTop = (1 - base.bounds.maxY) * image.size.height
        let expectedNumbers = [score, target].map { normalize(String($0)) }
        let scoreOrTarget = observations
            .filter { observation in
                let printed = normalize(observation.text)
                let bottom = (1 - observation.bounds.minY) * image.size.height
                let matchesHeaderNumber = expectedNumbers.contains { printed.contains($0) }
                return matchesHeaderNumber && bottom <= baseTop + 8
            }
            .min { lhs, rhs in
                lhs.bounds.minY < rhs.bounds.minY
            }
        let score = try XCTUnwrap(scoreOrTarget,
                                  "The score or target must remain visible above the payout")
        let scoreBottom = (1 - score.bounds.minY) * image.size.height
        XCTAssertLessThanOrEqual(baseTop - scoreBottom, 120,
                                 "The payout Base line drifted too far below the score/target")

        let expectedAction = normalize(action)
        let actionObservation = try XCTUnwrap(
            observations.first { normalize($0.text).contains(expectedAction) },
            "The \(action) action must remain visible"
        )
        let actionBottom = (1 - actionObservation.bounds.minY) * image.size.height
        XCTAssertLessThanOrEqual(image.size.height - actionBottom, 180,
                                 "The \(action) action must remain near the bottom of the Book")
    }

    private func printedObservations(in image: UIImage) throws -> [PrintedObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { result in
            guard let candidate = result.topCandidates(1).first else { return nil }
            return PrintedObservation(text: candidate.string, bounds: result.boundingBox)
        }
    }

    private func attach(_ image: UIImage, named name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = "book-victory-\(name)-\(Int(image.size.width))x\(Int(image.size.height))"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// These are rendered-copy assertions, not a VoiceOver-tree audit.
    private func recognizedText(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return normalize((request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
        }.joined(separator: " "))
    }

    private func assertContains(_ text: String, _ phrases: String...,
                                file: StaticString = #filePath, line: UInt = #line) {
        for phrase in phrases {
            XCTAssertTrue(text.contains(normalize(phrase)),
                          "Missing or unreadable '\(phrase)' in rendered text: \(text)", file: file, line: line)
        }
    }

    private func normalize(_ text: String) -> String {
        // App-host screenshots were visually inspected: the printed serif
        // II and "All" are correct, but Vision confuses I/l in these phrases.
        // Keep exact semantic-title equality above; correct only these two
        // complete word contexts, never arbitrary I/l or other Roman numerals.
        text.lowercased()
            .replacingOccurrences(of: #"\bobstacle\s+il\b"#, with: "obstacle ii", options: .regularExpression)
            .replacingOccurrences(of: #"\bail\s+9\s+obstacles\s+conquered\b"#,
                                  with: "all 9 obstacles conquered", options: .regularExpression)
            .filter { $0.isLetter || $0.isNumber }
    }
}
