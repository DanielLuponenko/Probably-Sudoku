import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Full printed values, not accessibility labels, must survive narrow pages.
/// Frozen/pure views avoid saves, scene navigation, and ad requests.
@MainActor
final class LargeNumberSurfaceTests: XCTestCase {
    func testResultsRetainScoreAndTargetAtNarrowPageWidths() async throws {
        var game = Game(seed: "large-number-results")
        try game.startPuzzle()
        var run = game.run
        run.puzzle?.score = 9_999_999
        run.puzzle?.target = 2_048_000
        run.puzzle?.phase = .won
        let model = GameModel(frozen: Game(run: run), page: .results)
        for width: CGFloat in [300, 328, 365] {
            let image = try await renderHostedResults(model, width: width, height: 620,
                                                       name: "large-results-\(Int(width))")
            try assertPrinted(image, "9,999,999", "2,048,000", "Total", "Cash Out")
        }
    }

    func testFailureRetainsLargeScoreAndTargetAtAccessibilityFive() throws {
        for (score, target) in [(122_541, 128_000), (9_999_999, 2_048_000),
                                (123_456_789, 999_999_999)] {
            for width: CGFloat in [300, 365] {
                let page = FailurePageContents(score: score, target: target,
                                              offersRescue: false, adState: .idle,
                                              canWatchAd: false, isBusy: false, compact: true)
                let image = try render(page, width: width, dynamicType: .accessibility5,
                                       name: "large-failure-accessibility5-\(score)-\(Int(width))")
                try assertPrinted(image, String(score), String(target), "New book", "for now")
            }
        }
    }

    func testIslandBarRetainsSixDigitBalanceBesideThreeControls() throws {
        let controls = [
            StripControl(systemImage: "rosette", label: "Achievements", action: {}),
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ]
        for width: CGFloat in [300, 328, 365] {
            let image = try render(IslandBar(coins: 999_999, controls: controls)
                .background(Paper.deskDark), width: width,
                dynamicType: .accessibility5, name: "large-coins-\(Int(width))")
            try assertPrinted(image, "999999")
            XCTAssertLessThanOrEqual(image.size.height, 47.5,
                                     "A larger balance must not grow the fixed HUD band.")
        }
    }

    func testRunInformationScoreRowRetainsBothLongValues() throws {
        for width: CGFloat in [300, 365] {
            let image = try render(LeaderRow(label: "Score", value: "9,999,999 of 2,048,000"),
                                   width: width, name: "large-run-info-\(Int(width))")
            try assertPrinted(image, "Score", "9,999,999", "2,048,000")
        }
    }

    func testBookCompletionRetainsLongBestScoreOnSmallPhone() throws {
        let summary = GameModel.BookCompletionSummary(
            edition: BookEdition.first, levelsCleared: 9, bossesBeaten: 9,
            bestPuzzleScore: 9_999_999, loadout: [], nextBook: nil)
        let image = try render(BookVictoryContents(summary: summary, board: nil,
                               bossName: "The Final Draft", obstacle: .none, compact: true),
                               width: 320, name: "large-book-completion-320")
        try assertPrinted(image, "Best Puzzle", "9,999,999", "Close the Book")
    }

    /// Results switches to a UIKit-backed ScrollView when its board overflows.
    /// Host that production view so this remains a numeric layout test, not an
    /// ImageRenderer snapshot of only the pure SwiftUI decision footer.
    private func renderHostedResults(_ model: GameModel, width: CGFloat, height: CGFloat,
                                     name: String) async throws -> UIImage {
        let before = try model.game.encoded()
        let ready = expectation(description: "Hosted large Results: \(name)")
        var reportedLayout = false
        let flipper = PageFlipper()
        let content = ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
            .frame(width: width, height: height)
            .environment(flipper)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
            .environment(\.levelPalette, .forDisplay(slot: .easy))
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, .large)
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
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size.width, width, accuracy: 0.5, name)
        XCTAssertEqual(try model.game.encoded(), before, "Rendering cannot pay out or change the saved score")
        let attachment = XCTAttachment(image: image)
        attachment.name = "\(name)-hosted"
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func render<V: View>(_ content: V, width: CGFloat, height: CGFloat? = nil,
                                dynamicType: DynamicTypeSize = .large,
                                name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: content
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.dynamicTypeSize, dynamicType)
            .transaction { $0.disablesAnimations = true }
            .background(Paper.page))
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, name)
        XCTAssertEqual(image.size.width, width, accuracy: 0.5, name)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if name.hasPrefix("large-failure-") {
            let path = FileManager.default.temporaryDirectory
                .appendingPathComponent("numberclub-\(name).png")
            try XCTUnwrap(image.pngData()).write(to: path, options: .atomic)
            print("LARGE_NUMBER_RENDER \(path.path)")
        }
        return image
    }

    private func assertPrinted(_ image: UIImage, _ expected: String...,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let printed = normalize((request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
        }.joined(separator: " "))
        for value in expected {
            XCTAssertTrue(printed.contains(normalize(value)),
                          "Missing printed value '\(value)' in \(printed)", file: file, line: line)
        }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
