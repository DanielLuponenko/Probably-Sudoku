import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Printed-page coverage uses pure content or a frozen game, never saved data or ad requests.
@MainActor
final class FailurePageRenderingTests: XCTestCase {
    func testReadyPageNaturalSizesAtPhoneWidths() throws {
        for compact in [false, true] {
            let image = try render(
                page(adState: .ready, compact: compact),
                named: compact ? "failure-ready-compact" : "failure-ready-regular"
            )
            let availableHeight: CGFloat = compact ? 590 : 700
            print("Failure page \(compact ? "compact" : "regular") natural size: \(image.size)")
            XCTAssertEqual(image.size.width, 328, accuracy: 0.5)
            XCTAssertLessThanOrEqual(image.size.height, availableHeight,
                                     "The full page, including End book, must fit without clipping or scrolling.")
            let text = try recognizedText(in: image)
            assertContains(text, "Out of turns", "A few more moves?", "Your score", "Target",
                           "Watch ad", "+3 turns", "Optional", "Once per puzzle", "End book")
        }
    }

    func testLoadingAndUnavailablePagesKeepTheSeparateEndBookDecisionVisible() throws {
        let states: [(RewardedAdService.State, String, String)] = [
            (.preparing, "loading", "Loading ad"),
            (.unavailable("Fixture: no fill"), "unavailable", "Try loading again")
        ]
        for (state, name, expectedButton) in states {
            let image = try render(
                page(adState: state, canWatchAd: name == "unavailable", compact: true),
                named: "failure-\(name)-compact"
            )
            XCTAssertLessThanOrEqual(image.size.height, 590)
            let text = try recognizedText(in: image)
            assertContains(text, "Out of turns", expectedButton, "End book",
                           "Finish this attempt without an ad")
            if name == "unavailable" {
                assertContains(text, "No ad available")
            }
        }
    }

    func testInFlightPageRetainsRescueCopyUntilTheAdDismisses() throws {
        let image = try render(
            page(adState: .presenting, canWatchAd: false, isBusy: true, compact: true),
            named: "failure-ad-in-flight-compact"
        )
        XCTAssertLessThanOrEqual(image.size.height, 590)
        let text = try recognizedText(in: image)
        assertContains(text, "Out of turns", "Ad in progress", "End book")
        XCTAssertFalse(text.contains(normalize("New book")))
    }

    func testTerminalFailureHasNoAdOfferEvenIfAnAdWasReady() throws {
        let image = try render(
            page(offersRescue: false, adState: .ready, canWatchAd: false, compact: true),
            named: "failure-terminal-no-rescue"
        )
        XCTAssertLessThanOrEqual(image.size.height, 590)
        let text = try recognizedText(in: image)
        assertContains(text, "Book over", "This attempt is over", "New book")
        XCTAssertFalse(text.contains(normalize("Watch ad")))
        XCTAssertFalse(text.contains(normalize("Once per puzzle")))
        XCTAssertFalse(text.contains(normalize("extra turns")))
        XCTAssertFalse(text.contains(normalize("Out of turns")))
    }

    func testLargeScoreAndTargetRemainReadableInTheirCompactColumns() throws {
        let image = try render(
            page(score: 98_765_432, target: 123_456_789, adState: .ready, compact: true),
            named: "failure-large-score-compact"
        )
        XCTAssertEqual(image.size.width, 328, accuracy: 0.5)
        XCTAssertLessThanOrEqual(image.size.height, 590)
        let text = try recognizedText(in: image)
        assertContains(text, "Your score", "98,765,432", "Target", "123,456,789", "End book")
    }

    func testAccessibilityFiveContentGrowsWithoutDiscardingEitherDecision() throws {
        let content = page(adState: .ready, compact: true)
        let regular = try render(content, named: "failure-dynamic-type-large")
        let accessible = try render(content, dynamicType: .accessibility5,
                                    named: "failure-dynamic-type-accessibility5-full-content")

        // The live caller owns the ScrollView fallback. Test the unbounded
        // content here, not a copied fallback that could pass independently.
        XCTAssertGreaterThan(accessible.size.height, regular.size.height)
        XCTAssertGreaterThan(accessible.size.height, 590)
        XCTAssertEqual(accessible.size.width, 328, accuracy: 0.5)
        let text = try recognizedText(in: accessible)
        assertContains(text, "Out of turns", "Watch ad", "End book")
    }

    func testAccessibilityFiveCanScrollToEndBookInsideTheRealBookContainer() async throws {
        var game = Game(seed: "failure-page-accessible-scroll")
        try game.startPuzzle()
        while game.puzzle?.phase == .playing { _ = try game.endTurn() }
        let model = GameModel(frozen: game, page: .results)
        let flipper = PageFlipper()
        let viewport = CGSize(width: 375, height: 812)
        let content = VStack(spacing: 0) {
            Color.clear.frame(height: 86) // Space occupied by the HUD/bookmark band.
            BookView(flipper: flipper) { FailureResultsPage(model: model, offersRescue: true) }
                .padding(.leading, 8).padding(.trailing, 10)
        }
        .padding(.bottom, 8)
        .frame(width: viewport.width, height: viewport.height)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard).environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.dynamicTypeSize, .accessibility5)
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = [] // The fixed viewport already represents the usable game area.
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
        let settled = expectation(description: "Hosted SwiftUI scroll view completed layout")
        DispatchQueue.main.async { window.layoutIfNeeded(); settled.fulfill() }
        await fulfillment(of: [settled], timeout: 3)
        func scrollViews(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        let scroll = try XCTUnwrap(scrollViews(in: controller.view).first)
        XCTAssertGreaterThan(scroll.bounds.height, 100)
        XCTAssertLessThanOrEqual(scroll.bounds.height, viewport.height - 86 - 8 - 26 - 18)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height + 300)
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
        let attachment = XCTAttachment(image: image)
        attachment.name = "failure-accessibility5-real-book-scrolled-to-bottom"
        attachment.lifetime = .keepAlways
        add(attachment)
        assertContains(try recognizedText(in: image), "End book", "Finish this attempt without an ad")
    }

    private func page(score: Int = 720, target: Int = 1_000,
                      offersRescue: Bool = true,
                      adState: RewardedAdService.State,
                      canWatchAd: Bool = true, isBusy: Bool = false,
                      compact: Bool = false) -> FailurePageContents {
        FailurePageContents(score: score, target: target, offersRescue: offersRescue,
                            adState: adState, canWatchAd: canWatchAd, isBusy: isBusy,
                            compact: compact)
    }

    private func render(_ content: FailurePageContents,
                        dynamicType: DynamicTypeSize = .large,
                        named name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: content
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.dynamicTypeSize, dynamicType)
            .background(Paper.page))
        // An unspecified height exposes the real content height. A fixed
        // screenshot frame alone would hide overflow and prove nothing.
        renderer.proposedSize = ProposedViewSize(width: 328, height: nil)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "\(name) failed to render")
        XCTAssertTrue(image.size.height.isFinite)
        XCTAssertGreaterThan(image.size.height, 0)
        let attachment = XCTAttachment(image: image)
        attachment.name = "\(name)-\(Int(image.size.width))x\(Int(image.size.height))"
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    /// Check actual rendered copy, including clipping, rather than echoing
    /// view inputs. These are visual labels, not a VoiceOver-tree assertion.
    private func recognizedText(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        let cgImage = try XCTUnwrap(image.cgImage)
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return normalize((request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
        }.joined(separator: " "))
    }

    private func assertContains(_ renderedText: String, _ phrases: String...,
                                file: StaticString = #filePath, line: UInt = #line) {
        for phrase in phrases {
            XCTAssertTrue(renderedText.contains(normalize(phrase)),
                          "Missing or unreadable '\(phrase)' in rendered text: \(renderedText)",
                          file: file, line: line)
        }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
