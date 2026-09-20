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
            XCTAssertLessThanOrEqual(image.size.height, 900,
                                    "The full celebratory article remains bounded before live board sizing.")
            let text = try recognizedText(in: image)
            assertContains(text, "Book Complete", fixture.summary.edition.title,
                           "Final Boss Beaten", fixture.bossName,
                           "Obstacle II", "Congratulations", "Book Achievement", "Volume 1 Complete", "Close the Book")
            XCTAssertFalse(text.contains(normalize("Achievement Earned")),
                           "Reopening or replaying a completed Book must not claim a newly earned achievement")
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
            if width == 328 { XCTAssertLessThanOrEqual(image.size.height, 900) }
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

    func testAccessibilityFiveEnlargesTheAwardTextWithoutLosingTheCloseDecision() throws {
        let fixture = try completedBook()
        let content = contents(fixture, compact: true)
        let regular = try render(content, named: "dynamic-type-large")
        let accessible = try render(content, dynamicType: .accessibility5,
                                    named: "dynamic-type-accessibility5-full-content")
        XCTAssertEqual(accessible.size.width, 328, accuracy: 0.5)
        let regularAward = try XCTUnwrap(printedObservations(in: regular).first {
            normalize($0.text).contains("volume1complete")
        })
        let accessibleAward = try XCTUnwrap(printedObservations(in: accessible).first {
            normalize($0.text).hasPrefix("volume1")
        })
        XCTAssertGreaterThan(accessibleAward.bounds.height * accessible.size.height,
                             regularAward.bounds.height * regular.size.height * 1.25,
                             "The concise hierarchy must enlarge its award type, even if total page height is unchanged")
        // The concise accessibility hierarchy retains the Book, award, next
        // challenge and decision. The hosted test below checks their bounds.
        assertContains(try recognizedText(in: accessible), "Congratulations", fixture.summary.edition.title,
                       "Obstacle II", "Book Achievement", "Volume 1 Complete", "Close", "The Book")
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

    func testShortRegularResultsRetainTheBoardAndKeepActionsVisible() async throws {
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
        XCTAssertGreaterThanOrEqual(ResultsBoardLayout(available: CGSize(width: 818, height: 588)).side, 300,
                                   "Short windows retain a substantial scrollable board instead of omitting it.")
        assertContains(text, "Puzzle Complete", "Cash Out")
        try assertResultsSpacing(in: image, action: "Cash Out",
                                 score: try XCTUnwrap(won.puzzle?.score),
                                 target: try XCTUnwrap(won.puzzle?.target))
        XCTAssertEqual(try encoder.encode(won.run), before,
                       "Short regular rendering must not mutate the run")
    }

    func testCelebrationAndNextChallengeFitOneScreenOn17ProAndSEAtNormalAndLargeText() async throws {
        let fixture = try completedBook(edition: .eighth)
        for viewport in [CGSize(width: 402, height: 874), CGSize(width: 375, height: 667)] {
            let safeArea = phoneSafeArea(for: viewport)
            for dynamicType in [DynamicTypeSize.large, .accessibility5] {
                let image = try await renderResultsInBook(fixture.model, viewport: viewport,
                    dynamicType: dynamicType, requiresSingleScreen: true,
                    named: "single-screen-\(Int(viewport.height))-\(dynamicType)")
                let text = try recognizedText(in: image)
                assertContains(text, "Congratulations", "Professionally Overthinking",
                               "Book Achievement", "Volume 8 Complete", "Obstacle II", "Close the Book")
                let observations = try printedObservations(in: image)
                let obstacle = try XCTUnwrap(observations.first { normalize($0.text).contains("obstacle") })
                let close = try XCTUnwrap(observations.first { normalize($0.text).contains("close") })
                XCTAssertGreaterThan(obstacle.bounds.minY, close.bounds.maxY,
                                     "The next challenge must sit fully above Close, not clip into it")
                let closeBottom = (1 - close.bounds.minY) * image.size.height
                XCTAssertLessThanOrEqual(closeBottom, viewport.height - safeArea.bottom - 4,
                                         "The complete Close label must remain above the phone's bottom safe area")
                let congratulations = try XCTUnwrap(observations.first {
                    normalize($0.text).contains("congratulations")
                })
                XCTAssertGreaterThanOrEqual((1 - congratulations.bounds.maxY) * viewport.height, safeArea.top,
                                            "The celebration must remain below the phone's top safe area")
                XCTAssertEqual(fixture.model.run.outcome, .bookCompleted)
            }
        }
    }

    func testBoardFitsTheMeasuredHeaderAndFooterWithoutHidingItsLastRow() {
        for available in [CGSize(width: 374, height: 640), CGSize(width: 347, height: 440)] {
            let layout = BookVictoryBoardLayout(available: available, headerHeight: 100, footerHeight: 205)
            XCTAssertGreaterThan(layout.side, 100)
            XCTAssertLessThanOrEqual(layout.side, available.width)
            XCTAssertLessThanOrEqual(100 + layout.side + 205 + layout.spacing * 2, available.height)
        }
        XCTAssertEqual(BookVictoryBoardLayout(available: CGSize(width: 340, height: 400),
            headerHeight: 190, footerHeight: 210).side, 0,
            "Large text never forces the board behind the celebration or the action")
    }

    private struct Fixture {
        let model: GameModel
        let summary: GameModel.BookCompletionSummary
        let bossName: String
    }

    private func phoneSafeArea(for viewport: CGSize) -> EdgeInsets {
        viewport.height > 700
            ? EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
            : EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
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
        dynamicType: DynamicTypeSize = .large, requiresSingleScreen: Bool = false,
        named name: String
    ) async throws -> UIImage {
        let flipper = PageFlipper()
        // Match the live stable host, including its actual header/inventory.
        let content = RunPageSurface(model: model, flipper: flipper, controls: [
                    StripControl(systemImage: "questionmark", label: "Run information", action: {}),
                    StripControl(systemImage: "gearshape", label: "Settings", action: {})
                ], safeAreaInsets: requiresSingleScreen ? phoneSafeArea(for: viewport) : EdgeInsets(),
                onTapBuff: { _ in }) {
                ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
        }
        .frame(width: viewport.width, height: viewport.height)
        .background(Paper.deskDark)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.horizontalSizeClass, horizontalSizeClass)
        .environment(\.dynamicTypeSize, dynamicType)
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
        if requiresSingleScreen {
            func scrollViews(in view: UIView) -> [UIScrollView] {
                (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
            }
            XCTAssertFalse(scrollViews(in: controller.view).contains {
                $0.contentSize.height > $0.bounds.height + 1
            }, "Completion must not need vertical scrolling")
        }
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
