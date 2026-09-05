import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ItemDetailCardTests: XCTestCase {
    func testSyndicationPopoverShowsItsFullTitleAndDescriptionOnPhoneWidths() async throws {
        for width in [CGFloat(320), 375, 402] {
            try await withPopover(width: width, dynamicType: .large) { presented, window in
                let frame = presented.view.convert(presented.view.bounds, to: window)
                print("Syndication native popover at width \(width): \(frame)")
                XCTAssertGreaterThanOrEqual(frame.width, 240)
                XCTAssertLessThanOrEqual(frame.width, width - 24)
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, width)
                XCTAssertLessThan(frame.height, 220, "A short item explanation should fit its content.")
                XCTAssertTrue(scrollViews(in: presented.view).isEmpty,
                              "Regular text should retain the compact, content-sized native popover.")
                let text = try capture(presented.view, named: "syndication-native-\(Int(width))")
                assertFullDescription(text)
            }
        }
    }

    func testSyndicationAccessibilityTextCanScrollThroughTheCompleteDescription() async throws {
        try await withPopover(width: 320, dynamicType: .accessibility5) { presented, window in
            let frame = presented.view.convert(presented.view.bounds, to: window)
            XCTAssertGreaterThanOrEqual(frame.minY, 0)
            XCTAssertLessThanOrEqual(frame.maxY, window.bounds.height)
            XCTAssertGreaterThan(frame.height, 300,
                                 "The native presentation must retain the source accessibility text size.")
            let scroll = try XCTUnwrap(scrollViews(in: presented.view).first,
                                       "Large text needs a native scroll region, not clipped popover content.")
            XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
            let top = try capture(presented.view, named: "syndication-accessibility5-top")
            XCTAssertTrue(top.contains(normalize("Syndication")))
            scroll.setContentOffset(CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height
                                            + scroll.adjustedContentInset.bottom), animated: false)
            presented.view.layoutIfNeeded()
            let bottom = try capture(presented.view, named: "syndication-accessibility5-bottom")
            XCTAssertTrue(bottom.contains(normalize("Resets only at a new Book")))
        }
    }

    private func withPopover(width: CGFloat, dynamicType: DynamicTypeSize,
                             inspect: (UIViewController, UIWindow) throws -> Void) async throws {
        let item = try XCTUnwrap(Catalog.item(Bookmarks.syndication))
        let appeared = expectation(description: "Native item popover appeared")
        let root = PopoverProbe(def: item)
            .environment(\.dynamicTypeSize, dynamicType)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
            .transaction { $0.disablesAnimations = true }
        let host = PopoverHostingController(rootView: root)
        host.onPresented = { appeared.fulfill() }
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 568)
        window.rootViewController = host
        defer {
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [appeared], timeout: 5)
        window.layoutIfNeeded()
        let presented = try XCTUnwrap(host.presentedViewController)
        presented.view.layoutIfNeeded()
        try inspect(presented, window)
    }

    private func capture(_ view: UIView, named name: String) throws -> String {
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
        return normalize((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " "))
    }

    private func assertFullDescription(_ text: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        for phrase in ["Syndication", "Starts at x1", "permanently gains", "0.25",
                       "every Puzzle you win", "Resets only at a new Book"] {
            XCTAssertTrue(text.contains(normalize(phrase)), "Missing or clipped '\(phrase)': \(text)",
                          file: file, line: line)
        }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private struct PopoverProbe: View {
        let def: ItemDef
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
        }
    }

    private final class PopoverHostingController<Content: View>: UIHostingController<Content> {
        var onPresented: (() -> Void)?

        override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                              completion: (() -> Void)? = nil) {
            super.present(viewControllerToPresent, animated: flag) {
                self.onPresented?()
                completion?()
            }
        }
    }
}
