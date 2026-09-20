import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ItemDetailCardTests: XCTestCase {
    func testSyndicationPaperPanelShowsItsFullTitleAndDescriptionOnPhoneWidths() async throws {
        for width in [CGFloat(320), 375, 402] {
            try await withPaperPanel(width: width, dynamicType: .large) { host, window in
                let snapshot = try capture(window, named: "syndication-paper-\(Int(width))")
                let frame = snapshot.paperBounds
                XCTAssertGreaterThanOrEqual(frame.width, 240)
                XCTAssertGreaterThanOrEqual(frame.minX, 20, "The custom paper keeps its 22-point screen margin.")
                XCTAssertLessThanOrEqual(frame.maxX, width - 20)
                XCTAssertGreaterThanOrEqual(frame.minY, 0)
                XCTAssertLessThanOrEqual(frame.maxY, window.bounds.height)
                XCTAssertLessThan(frame.height, 320,
                                  "The short explanation, heading, and Close button should fit a compact slip.")
                XCTAssertTrue(scrollViews(in: host.view).allSatisfy { $0.contentSize.height <= $0.bounds.height + 1 },
                              "Regular text should fit completely without needing to scroll any container.")
                assertFullDescription(snapshot.text)
                XCTAssertTrue(snapshot.text.contains(normalize("Close")))
                assertTextFitsPaper(snapshot)
            }
        }
    }

    func testSyndicationAccessibilityTextCanScrollThroughTheCompleteDescription() async throws {
        try await withPaperPanel(width: 320, dynamicType: .accessibility5) { host, window in
            let top = try capture(window, named: "syndication-accessibility5-top")
            XCTAssertGreaterThanOrEqual(top.paperBounds.minY, 0)
            XCTAssertLessThanOrEqual(top.paperBounds.maxY, window.bounds.height)
            XCTAssertGreaterThan(top.paperBounds.height, 300,
                                 "The custom presentation must retain the source accessibility text size.")
            XCTAssertTrue(top.text.contains(normalize("Syndication")))
            let scrolling = scrollViews(in: host.view).filter { $0.contentSize.height > $0.bounds.height + 1 }
            XCTAssertFalse(scrolling.isEmpty, "Large text needs a working scroll region, not clipped copy.")
            // PaperSlip may also scroll its article to keep its heading and
            // Close button visible. Reach the end of both nested regions.
            for scroll in scrolling.reversed() {
                scroll.setContentOffset(CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height
                                                + scroll.adjustedContentInset.bottom), animated: false)
                host.view.layoutIfNeeded()
            }
            let bottom = try capture(window, named: "syndication-accessibility5-bottom")
            XCTAssertTrue(bottom.text.contains(normalize("Apply the stored factor at this Bookmark’s locked slot")),
                          "The complete final sentence must be readable after scrolling: \(bottom.text)")
            XCTAssertTrue(bottom.text.contains(normalize("Close")))
            assertTextFitsPaper(top)
            assertTextFitsPaper(bottom)
        }
    }

    private func withPaperPanel(width: CGFloat, dynamicType: DynamicTypeSize,
                             inspect: (UIViewController, UIWindow) throws -> Void) async throws {
        let item = try XCTUnwrap(Catalog.item(Bookmarks.syndication))
        let appeared = expectation(description: "Item explanation entered the root paper portal")
        let root = PaperPanelProbe(def: item, onPresented: { appeared.fulfill() })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paperPanelHost()
            .environment(\.dynamicTypeSize, dynamicType)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
            .transaction { $0.disablesAnimations = true }
        let host = UIHostingController(rootView: root)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 568)
        window.rootViewController = host
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [appeared], timeout: 5)
        // The observable entry is inserted before its 180ms opacity transition
        // is committed by SwiftUI. Give the real render loop time to present
        // and finish that arrival; otherwise drawHierarchy captures the source
        // bookmark while the panel's UIKit children already exist at alpha 0.
        try await Task.sleep(for: .milliseconds(350))
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()
        XCTAssertNil(host.presentedViewController, "Item details must use in-game paper, not a UIKit popover or sheet.")
        try inspect(host, window)
    }

    private struct Snapshot {
        let text: String
        let textBounds: CGRect
        let paperBounds: CGRect
    }

    private func capture(_ view: UIView, named name: String) throws -> Snapshot {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let observations = request.results ?? []
        let text = normalize(observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " "))
        let textBounds = observations.reduce(CGRect.null) { result, observation in
            let bounds = observation.boundingBox
            return result.union(CGRect(x: bounds.minX * view.bounds.width,
                                       y: (1 - bounds.maxY) * view.bounds.height,
                                       width: bounds.width * view.bounds.width,
                                       height: bounds.height * view.bounds.height))
        }
        return Snapshot(text: text, textBounds: textBounds, paperBounds: try paperBounds(in: image))
    }

    /// The portal fills the screen, so its UIView bounds do not measure the
    /// slip. Its bright paper is distinct from the 48%-dimmed source content.
    private func paperBounds(in image: UIImage) throws -> CGRect {
        let scale = image.scale
        let image = try XCTUnwrap(image.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var frame = CGRect.null
        for y in 0..<height {
            var first = width, last = -1, count = 0
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
                if min(red, green, blue) > 175 && red + green + blue > 590 {
                    first = min(first, x)
                    last = max(last, x)
                    count += 1
                }
            }
            if count > width * 2 / 5 {
                frame = frame.union(CGRect(x: first, y: y, width: last - first + 1, height: 1))
            }
        }
        XCTAssertFalse(frame.isNull, "The custom slip's visible paper must be present.")
        guard !frame.isNull else { return .zero }
        return CGRect(x: frame.minX / scale, y: frame.minY / scale,
                      width: frame.width / scale, height: frame.height / scale)
    }

    private func assertTextFitsPaper(_ snapshot: Snapshot, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(snapshot.textBounds.isNull, file: file, line: line)
        XCTAssertTrue(snapshot.paperBounds.insetBy(dx: -1, dy: -1).contains(snapshot.textBounds),
                      "Visible title, description, and Close copy must stay on the paper: \(snapshot.textBounds) in \(snapshot.paperBounds)",
                      file: file, line: line)
    }

    private func assertFullDescription(_ text: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        for phrase in ["Syndication", "Start the Book at x1", "Each Puzzle win adds", "0.25",
                       "for later Puzzles", "Apply the stored factor at this Bookmark’s locked slot"] {
            XCTAssertTrue(text.contains(normalize(phrase)), "Missing or clipped '\(phrase)': \(text)",
                          file: file, line: line)
        }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap { scrollViews(in: $0) }
    }

    private struct PaperPanelProbe: View {
        let def: ItemDef
        let onPresented: () -> Void
        @Environment(\.paperPanelPresenter) private var presenter
        @State private var isPresented = false

        var body: some View {
            VStack {
                InventoryBookmark(def: def, colour: Paper.pageWarm, ink: Paper.ink, flagged: false,
                                  slot: 0, pulling: false, asleep: false, fired: false,
                                  explaining: $isPresented)
                    .frame(width: 40, height: 50)
                Spacer()
            }
            .padding(.top, 80)
            .task { isPresented = true }
            .onChange(of: presenter?.isPresenting) { _, isPresenting in
                if isPresenting == true { onPresented() }
            }
        }
    }
}
