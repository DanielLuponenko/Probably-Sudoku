import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Render the production lesson inside real phone/tablet viewports. These tests
/// verify visible instructions and scroll reachability; TutorialSessionTests
/// cover mutations, and the release walkthrough covers actual button taps.
@MainActor
final class TutorialPresentationTests: XCTestCase {
    func testCompactPhoneAndIPadKeepTheOutlinedHandCardAboveTheFooter() async throws {
        for viewport in [Viewport.compactPhone, .iPad] {
            let session = TutorialSession(practice: try TutorialPractice.make())
            try TutorialTestDriver.reach(.select, in: session)
            let host = try host(session, viewport: viewport)
            defer { host.close() }
            await settle(host)
            let image = screenshot(host, name: "tutorial-select-\(viewport.name)")
            let rows = try recognizedRows(in: image)
            try assertReadable("Start with a number", rows: rows)
            try assertReadable("Exit practice", rows: rows)
            let handTitle = try textFrame("Your Hand", rows: rows, exact: true)
            let scroll = try XCTUnwrap(lessonScroll(in: host))
            let visible = scroll.convert(scroll.bounds, to: host.window)
            let handArea = CGRect(x: visible.minX, y: handTitle.maxY,
                                  width: visible.width, height: visible.maxY - handTitle.maxY)
            let highlighted = try XCTUnwrap(highlightBounds(in: image, within: handArea),
                                            "The outlined Hand card must be visible without scrolling.")
            XCTAssertGreaterThanOrEqual(highlighted.width, 40)
            XCTAssertGreaterThanOrEqual(highlighted.height, 40,
                                        "A clipped strip of the Hand card does not provide a usable target.")
            XCTAssertLessThanOrEqual(highlighted.maxY, visible.maxY - 1,
                                     "The pinned footer must not cover the outlined Hand card.")
            let digitImage = try crop(image, to: highlighted.insetBy(dx: -2, dy: -2))
            try assertReadable(String(try XCTUnwrap(session.targetDigit).rawValue),
                               rows: recognizedRows(in: digitImage))
            XCTAssertFalse(normalized(rows).contains("showme"))
            XCTAssertFalse(normalized(rows).contains("lettheguidecontinue"))
        }
    }

    func testItemActionsAndMultiplierAreReadableOnCompactPhone() async throws {
        let cases: [(TutorialSession.Step, String, String)] = [
            (.buyBookmark, "Buy a Bookmark", "Buy Local Gossip"),
            (.buyMultiplier, "Give your score a multiplier", "Buy Op-Ed Column"),
            (.buyMarker, "A bonus on one square", "Buy Golden Marker"),
            (.useBuff, "Use Fresh Ink", "Use Fresh Ink"),
            (.sellBookmark, "Sell a Bookmark", "Sell Local Gossip"),
            (.sellBuff, "Unused Buffs can be sold too", "Sell Overtime")
        ]
        for (step, title, action) in cases {
            let session = TutorialSession(practice: try TutorialPractice.make())
            try TutorialTestDriver.reach(step, in: session)
            let host = try host(session, viewport: .compactPhone)
            defer { host.close() }
            await settle(host)
            let initialRows = try recognizedRows(in: screenshot(host, name: "tutorial-\(step)-top"))
            try assertReadable(title, rows: initialRows)
            try assertReadable("Exit practice", rows: initialRows)
            let actionImage = try await revealAction(action, in: host)
            if [.buyBookmark, .sellBookmark].contains(step) {
                attach(actionImage, name: "tutorial-\(step)-compact")
            }
            XCTAssertEqual(session.step, step, "Inspecting or scrolling the lesson must not autoplay it.")
            XCTAssertFalse(normalized(try recognizedRows(in: actionImage)).contains("showme"))
        }

        let combo = TutorialSession(practice: try TutorialPractice.make())
        try TutorialTestDriver.reach(.comboScore, in: combo)
        let host = try host(combo, viewport: .compactPhone)
        defer { host.close() }
        await settle(host)
        let image = screenshot(host, name: "tutorial-combination-compact")
        let rows = try recognizedRows(in: image)
        try assertReadable("See your combination", rows: rows)
        try assertReadable("265 queued base", rows: rows)
        try assertReadable("530 points to bank", rows: rows)
        try assertReadable("Continue", rows: rows)
    }

    func testLargestDynamicTypeCanScrollToRealBuyUseAndSellButtons() async throws {
        let cases: [(TutorialSession.Step, String, String)] = [
            (.buyBookmark, "Buy a Bookmark", "Buy Local Gossip"),
            (.useBuff, "Use Fresh Ink", "Use Fresh Ink"),
            (.sellBuff, "Unused Buffs can be sold too", "Sell Overtime")
        ]
        for (step, heading, action) in cases {
            let session = TutorialSession(practice: try TutorialPractice.make())
            try TutorialTestDriver.reach(step, in: session)
            let host = try host(session, viewport: .compactPhone, dynamicType: .accessibility5)
            defer { host.close() }
            await settle(host)
            let top = screenshot(host, name: "tutorial-accessibility5-\(step)-heading")
            let rows = try recognizedRows(in: top)
            try assertReadable("Exit", rows: rows)
            try assertReadable(heading, rows: rows)
            let scroll = try XCTUnwrap(lessonScroll(in: host))
            try assertAccessibleChrome(rows: rows, host: host, step: step)
            XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height,
                                 "Large text must grow into a scrollable page instead of being compressed.")
            let image = try await revealAction(action, in: host)
            try assertAccessibleChrome(rows: recognizedRows(in: image), host: host, step: step)
            attach(image, name: "tutorial-accessibility5-\(step)-action")
            XCTAssertEqual(session.step, step)
        }

        // Stages with a real pinned action retain it at the largest text size.
        for (step, action) in [(TutorialSession.Step.bank, "End Turn"), (.comboScore, "Continue"), (.won, "Cash Out")] {
            let session = TutorialSession(practice: try TutorialPractice.make())
            try TutorialTestDriver.reach(step, in: session)
            let host = try host(session, viewport: .compactPhone, dynamicType: .accessibility5)
            defer { host.close() }
            await settle(host)
            let image = screenshot(host, name: "tutorial-accessibility5-\(step)-pinned")
            let rows = try recognizedRows(in: image)
            try assertAccessibleChrome(rows: rows, host: host, step: step)
            let actionFrame = try textFrame(action, rows: rows, exact: true)
            let scroll = try XCTUnwrap(lessonScroll(in: host))
            let visible = scroll.convert(scroll.bounds, to: host.window)
            XCTAssertGreaterThanOrEqual(actionFrame.minY, visible.maxY,
                                        "The real \(action) control must remain pinned below the lesson.")
            XCTAssertLessThanOrEqual(actionFrame.maxY, host.viewport.size.height)
        }
    }

    private struct Viewport {
        let name: String
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
        static let compactPhone = Viewport(name: "375x667", size: CGSize(width: 375, height: 667), top: 20, bottom: 0)
        static let iPad = Viewport(name: "768x1024", size: CGSize(width: 768, height: 1024), top: 24, bottom: 20)
    }

    @MainActor
    private final class HostedLesson {
        let window: UIWindow
        let controller: UIHostingController<AnyView>
        let previousKey: UIWindow?
        let viewport: Viewport
        init(window: UIWindow, controller: UIHostingController<AnyView>, previousKey: UIWindow?, viewport: Viewport) {
            self.window = window; self.controller = controller
            self.previousKey = previousKey; self.viewport = viewport
        }
        func close() {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
    }

    private func host(_ session: TutorialSession, viewport: Viewport,
                      dynamicType: DynamicTypeSize = .large) throws -> HostedLesson {
        let page = TutorialLessonPage(session: session, presentation: .replay)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.dynamicTypeSize, dynamicType)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .padding(.top, viewport.top).padding(.bottom, viewport.bottom)
            .frame(width: viewport.size.width, height: viewport.size.height)
            .transaction { $0.disablesAnimations = true }
        let controller = UIHostingController(rootView: AnyView(page))
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: viewport.size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return HostedLesson(window: window, controller: controller, previousKey: previousKey, viewport: viewport)
    }

    private func settle(_ host: HostedLesson) async {
        let ready = expectation(description: "Tutorial layout settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            host.window.layoutIfNeeded(); host.controller.view.layoutIfNeeded(); ready.fulfill()
        }
        await fulfillment(of: [ready], timeout: 3)
    }

    private func lessonScroll(in host: HostedLesson) -> UIScrollView? {
        func find(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { find(in: $0) }
        }
        return find(in: host.controller.view).max { $0.bounds.height < $1.bounds.height }
    }

    /// Find the actual green action button by rendered pixels, then verify its
    /// label. This cannot mistake a matching heading for the button below it.
    private func revealAction(_ action: String, in host: HostedLesson) async throws -> UIImage {
        let scroll = try XCTUnwrap(lessonScroll(in: host))
        let visible = scroll.convert(scroll.bounds, to: host.window)
        let maximum = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        let increment = max(20, min(40, visible.height / 6))
        var offset: CGFloat = 0
        while true {
            scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
            await settle(host)
            let image = screenshot(host)
            if let highlight = highlightBounds(in: image, within: visible),
               highlight.height >= 40, highlight.minY > visible.minY + 1,
               highlight.maxY < visible.maxY - 1 {
                let buttonImage = try crop(image, to: highlight.insetBy(dx: -2, dy: -2))
                if normalized(try recognizedRows(in: buttonImage)).contains(normalize(action)) {
                    XCTAssertGreaterThanOrEqual(highlight.width, 40)
                    return image
                }
            }
            if offset >= maximum { break }
            offset = min(maximum, offset + increment)
        }
        let failure = screenshot(host, name: "tutorial-missing-\(normalize(action))")
        XCTFail("Could not scroll the complete '\(action)' button above the pinned footer. Rendered: \(normalized(try recognizedRows(in: failure)))")
        return failure
    }

    private struct TextRow {
        let text: String
        let frame: CGRect
    }

    private func recognizedRows(in image: UIImage) throws -> [TextRow] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { result in
            guard let text = result.topCandidates(1).first?.string else { return nil }
            let box = result.boundingBox
            return TextRow(text: text, frame: CGRect(x: box.minX * image.size.width,
                y: (1 - box.maxY) * image.size.height, width: box.width * image.size.width,
                height: box.height * image.size.height))
        }
    }

    private func textFrame(_ phrase: String, rows: [TextRow], exact: Bool = false) throws -> CGRect {
        try XCTUnwrap(rows.first { exact ? normalize($0.text) == normalize(phrase)
            : normalize($0.text).contains(normalize(phrase)) }, "Missing rendered '\(phrase)': \(rows.map(\.text))").frame
    }

    private func assertAccessibleChrome(rows: [TextRow], host: HostedLesson,
                                        step: TutorialSession.Step) throws {
        let scroll = try XCTUnwrap(lessonScroll(in: host))
        let visible = scroll.convert(scroll.bounds, to: host.window)
        XCTAssertGreaterThanOrEqual(visible.height, host.viewport.size.height * 0.65,
                                    "Pinned chrome must leave enough room to read and use a large-text lesson.")
        let chrome = rows.filter { $0.frame.midY < visible.minY || $0.frame.midY > visible.maxY }
        try assertReadable("Exit", rows: chrome)
        try assertReadable("\(step.rawValue + 1)/\(TutorialSession.Step.allCases.count)", rows: chrome)
        XCTAssertFalse(chrome.contains { $0.text.contains("…") || $0.text.contains("...") },
                       "Pinned controls and progress must not truncate: \(chrome.map(\.text))")
        XCTAssertFalse(normalized(chrome).contains("tapbuy"))
        XCTAssertFalse(normalized(chrome).contains("practicenever"))
    }

    private func assertReadable(_ phrase: String, rows: [TextRow],
                                file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(normalized(rows).contains(normalize(phrase)),
                      "Missing or clipped '\(phrase)': \(rows.map(\.text))", file: file, line: line)
    }

    private func normalized(_ rows: [TextRow]) -> String { normalize(rows.map(\.text).joined(separator: " ")) }
    private func normalize(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }

    /// Selected fills are opaque. Measure their visible interior in points;
    /// strokes add another two points on each edge of the real touch target.
    private func highlightBounds(in image: UIImage, within area: CGRect) -> CGRect? {
        guard let cg = image.cgImage else { return nil }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let scale = CGFloat(width) / image.size.width
        let rect = area.intersection(CGRect(origin: .zero, size: image.size))
        guard !rect.isNull, !rect.isEmpty else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in max(0, Int(rect.minY * scale))..<min(height, Int(rect.maxY * scale)) {
            for x in max(0, Int(rect.minX * scale))..<min(width, Int(rect.maxX * scale)) {
                let p = (y * width + x) * 4
                if abs(Int(pixels[p]) - 211) <= 3, abs(Int(pixels[p + 1]) - 217) <= 3,
                   abs(Int(pixels[p + 2]) - 194) <= 3 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
                      width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
    }

    private func crop(_ image: UIImage, to rect: CGRect) throws -> UIImage {
        let scale = image.scale
        let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                            width: rect.width * scale, height: rect.height * scale).integral
        return UIImage(cgImage: try XCTUnwrap(image.cgImage?.cropping(to: pixels)), scale: scale, orientation: .up)
    }

    private func screenshot(_ host: HostedLesson, name: String? = nil) -> UIImage {
        let image = UIGraphicsImageRenderer(size: host.viewport.size).image { _ in
            host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
        }
        if let name { attach(image, name: name) }
        return image
    }

    private func attach(_ image: UIImage, name: String) {
        // A plain PNG survives a simulator XCTest symbolication stall too.
        try? image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/numberclub-\(name).png"))
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
