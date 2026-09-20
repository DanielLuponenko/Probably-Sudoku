import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ScoreLedgerEnlargementTests: XCTestCase {
    func testActualLedgerCopyAndFactorsEnlargeWhileEverySourceAndCloseRemainReachable() async throws {
        let model = GameModel(resuming: try QAScoringFixture.modifierPreview.makeGame(), savesProgress: false)
        model.place(handIndex: 0, at: Square(3))
        XCTAssertTrue(model.useBuff(at: 0))
        let puzzle = try XCTUnwrap(model.puzzle)
        // Match GameplayScorePanel.previewLedger: its readable receipt shows
        // real placement operations before the current ordered Mult preview.
        var ledger = puzzle.pendingScoringLedger
        ledger.operations = puzzle.turnScoringOperations + ledger.operations
        XCTAssertEqual(ledger.total, 1_920)
        XCTAssertTrue(ledger.operations.contains { $0.sourceID == "mk_crimson" && $0.scope == .event })
        XCTAssertEqual(Array(ledger.operations.suffix(3).map(\.sourceID)), [Buffs.freshInk, "bm_op_ed", "bm_stop_the_presses"])
        let original = try model.game.encoded()
        for phone in [Phone(size: CGSize(width: 375, height: 667), top: 20, bottom: 0),
                      Phone(size: CGSize(width: 402, height: 874), top: 62, bottom: 34)] {
            let normal = try await read(ledger, phone: phone, type: .large)
            let enlarged = try await read(ledger, phone: phone, type: .accessibility5)
            // Real calculation, explanation, marker name, running-total,
            // +2 operation and final note; no synthetic font sample.
            for word in measuredWords {
                let before = try XCTUnwrap(normal[word], word)
                let after = try XCTUnwrap(enlarged[word], word)
                XCTAssertGreaterThan(after, before * 1.5,
                                     "\(Int(phone.size.width)): ledger \(word) must actually enlarge")
            }
        }
        XCTAssertEqual(try model.game.encoded(), original)
    }

    private let measuredWords = ["Points", "bonuses", "Crimson", "Event", "2", "separate"]

    private struct Phone {
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
        var safeBounds: CGRect {
            CGRect(x: 0, y: top, width: size.width, height: size.height - top - bottom)
        }
    }

    private func read(_ ledger: ScoreLedger, phone: Phone, type: DynamicTypeSize) async throws -> [String: CGFloat] {
        let controller = UIHostingController(rootView:
            ScoreLedgerSlip(ledger: ledger, isPreview: true) {
                XCTFail("Reading the ledger must not activate dismissal")
            }
            .padding(.top, phone.top).padding(.bottom, phone.bottom)
            .environment(\.dynamicTypeSize, type)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
            .transaction { $0.disablesAnimations = true })
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        window.rootViewController = controller
        defer { window.isHidden = true; window.rootViewController = nil; previousKey?.makeKey() }
        window.makeKeyAndVisible()
        await settle(window)
        // Normal copy may fit without a ScrollView; accessibility copy uses
        // PaperSlip's existing scrolling article with a stationary Close.
        let scroll = scrollViews(in: window).max { $0.contentSize.height < $1.contentSize.height }
        let bottom = scroll.map { max(0, $0.contentSize.height - $0.bounds.height + $0.adjustedContentInset.bottom) } ?? 0
        if type.isAccessibilitySize {
            XCTAssertNotNil(scroll)
            XCTAssertGreaterThan(bottom, 0, "The enlarged ordered ledger must remain fully scrollable")
        }
        let step = max(44, (scroll?.bounds.height ?? phone.size.height) * 0.45)
        let offsets = Array(stride(from: CGFloat.zero, to: bottom, by: step)) + [bottom]
        var heights: [String: CGFloat] = [:]
        var observedText = ""
        for (index, offset) in offsets.enumerated() {
            scroll?.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
            await settle(window)
            let image = UIGraphicsImageRenderer(size: phone.size).image { _ in
                window.drawHierarchy(in: CGRect(origin: .zero, size: phone.size), afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "ledger-growth-\(Int(phone.size.width))-\(type)-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
            let rows = request.results ?? []
            let articleBounds = scroll.map { $0.convert($0.bounds, to: window) } ?? phone.safeBounds
            var closeVisible = false
            for observation in rows {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let row = logicalBounds(observation.boundingBox, in: image)
                if candidate.string.caseInsensitiveCompare("Close") == .orderedSame {
                    closeVisible = phone.safeBounds.contains(row)
                }
                guard articleBounds.insetBy(dx: -1, dy: -1).contains(row) else { continue }
                observedText += " " + candidate.string
                for word in measuredWords {
                    guard let range = candidate.string.range(of: "\\b\(word)\\b", options: [.regularExpression, .caseInsensitive]),
                          let box = try candidate.boundingBox(for: range)?.boundingBox else { continue }
                    heights[word] = max(heights[word] ?? 0, box.height * image.size.height)
                }
            }
            XCTAssertTrue(closeVisible, "Close must remain readable at every ledger scroll offset")
        }
        let normalized = observedText.lowercased().filter { $0.isLetter || $0.isNumber }
        for source in Set(ledger.operations.map(\.sourceName)) {
            XCTAssertTrue(normalized.contains(source.lowercased().filter { $0.isLetter || $0.isNumber }),
                          "The complete source must be reachable: \(source)")
        }
        for word in measuredWords {
            XCTAssertNotNil(heights[word], "The complete ledger must expose \(word)")
        }
        return heights
    }

    private func logicalBounds(_ rect: CGRect, in image: UIImage) -> CGRect {
        CGRect(x: rect.minX * image.size.width, y: (1 - rect.maxY) * image.size.height,
               width: rect.width * image.size.width, height: rect.height * image.size.height)
    }

    private func settle(_ window: UIWindow) async {
        window.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(80))
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }
}
