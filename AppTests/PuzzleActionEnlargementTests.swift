import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class PuzzleActionEnlargementTests: XCTestCase {
    func testRealPuzzleActionsAndTossAllowanceEnlargeWithoutClippingOrShrinkingBoardBelowMinimum() async throws {
        var game = Game(seed: "puzzle-action-enlargement")
        try game.startPuzzle()
        for phone in [
            Phone(size: CGSize(width: 320, height: 568), top: 20, bottom: 0),
            Phone(size: CGSize(width: 375, height: 667), top: 20, bottom: 0),
            Phone(size: CGSize(width: 393, height: 852), top: 59, bottom: 34),
            Phone(size: CGSize(width: 402, height: 874), top: 62, bottom: 34)
        ] {
            let normal = try await render(game, phone: phone, type: .large)
            let enlarged = try await render(game, phone: phone, type: .accessibility5)
            for phrase in ["Toss", "End Turn", "4 left"] {
                let before = try XCTUnwrap(normal.labels[phrase])
                let after = try XCTUnwrap(enlarged.labels[phrase])
                XCTAssertGreaterThan(after.height, before.height * 1.2,
                                     "\(Int(phone.size.width)): \(phrase) must actually enlarge")
                XCTAssertGreaterThanOrEqual(after.height, phrase == "4 left" ? 12 : 14,
                                            "Enlarged copy must remain readable, not be fitted back to tiny type")
            }
        }
    }

    private struct Phone {
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
    }

    private struct PrintedPage {
        let labels: [String: CGRect]
    }

    private func render(_ game: Game, phone: Phone, type: DynamicTypeSize) async throws -> PrintedPage {
        let model = GameModel(frozen: game, page: .puzzle)
        model.selectedHandIndex = 0
        let puzzle = try XCTUnwrap(model.puzzle)
        XCTAssertEqual(puzzle.tossesRemaining, 4)
        XCTAssertTrue(model.canToss)
        let original = try model.game.encoded()
        let flipper = PageFlipper()
        let measured = expectation(description: "Real puzzle geometry")
        var didMeasure = false
        var frames: [String: CGRect] = [:]
        var pageFrame = CGRect.zero
        let content = BookView(flipper: flipper, showsChrome: false) {
            GameplayShell(model: model, controls: [], onTapBuff: { _ in }) {
                PuzzlePageView(model: model, puzzle: puzzle, isClockRunning: false)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { pageFrame = $0 }
            }
        }
        .padding(.top, phone.top)
        .padding(.bottom, phone.bottom)
        .environment(\.dynamicTypeSize, type)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.scenePhase, .active)
        .environment(\.locale, Locale(identifier: "en_US"))
        .transaction { $0.disablesAnimations = true }
        .onPreferenceChange(NumberReturnMotionFrames.self) { latest in
            frames = latest
            if !didMeasure, latest[NumberReturnMotionAnchor.grid] != nil,
               latest[NumberReturnMotionAnchor.hand] != nil {
                didMeasure = true
                measured.fulfill()
            }
        }
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        window.rootViewController = controller
        defer {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [measured], timeout: 4)
        for _ in 0..<3 {
            window.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(20))
        }
        let grid = try XCTUnwrap(frames[NumberReturnMotionAnchor.grid])
        let hand = try XCTUnwrap(frames[NumberReturnMotionAnchor.hand])
        let localPage = CGRect(origin: .zero, size: pageFrame.size)
        XCTAssertTrue(localPage.insetBy(dx: -1, dy: -1).contains(grid))
        XCTAssertTrue(localPage.insetBy(dx: -1, dy: -1).contains(hand))
        XCTAssertEqual(grid.width, grid.height, accuracy: 1)
        XCTAssertGreaterThanOrEqual(grid.width, 140)
        XCTAssertGreaterThanOrEqual(hand.minY, grid.maxY)

        let image = UIGraphicsImageRenderer(size: phone.size).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: phone.size), afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "puzzle-action-growth-\(Int(phone.size.width))-\(type)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        var labels: [String: CGRect] = [:]
        for phrase in ["Toss", "End Turn", "4 left"] {
            let pattern = phrase.components(separatedBy: " ").joined(separator: "\\s*")
            for observation in request.results ?? [] {
                guard let text = observation.topCandidates(1).first,
                      let range = text.string.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
                      let box = try text.boundingBox(for: range)?.boundingBox else { continue }
                let located = CGRect(x: box.minX * image.size.width,
                    y: (1 - box.maxY) * image.size.height,
                    width: box.width * image.size.width, height: box.height * image.size.height)
                labels[phrase] = try inkBounds(in: image, near: located, light: phrase == "End Turn")
                break
            }
            let frame = try XCTUnwrap(labels[phrase], "\(phrase) missing from the actual puzzle at \(type)")
            XCTAssertTrue(pageFrame.insetBy(dx: -1, dy: -1).contains(frame))
            XCTAssertGreaterThanOrEqual(frame.minY, pageFrame.minY + hand.maxY - 1,
                                       "An enlarged action must stay below the Hand")
        }
        XCTAssertFalse(try XCTUnwrap(labels["Toss"]).intersects(XCTUnwrap(labels["End Turn"])))
        XCTAssertEqual(try model.game.encoded(), original)
        return PrintedPage(labels: labels)
    }

    /// Vision locates the exact words but its estimated box includes variable
    /// padding: a 17pt Toss was reported taller than its 22pt AX counterpart.
    /// Measure the actual printed pixels within that small, verified region.
    private func inkBounds(in image: UIImage, near location: CGRect, light: Bool) throws -> CGRect {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        let scale = CGFloat(width) / image.size.width
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let bounds: CGRect? = bytes.withUnsafeMutableBytes { storage in
            guard let context = CGContext(data: storage.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            let pixelBounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            context.draw(cgImage, in: pixelBounds)
            let region = location.insetBy(dx: -3, dy: -3)
                .applying(CGAffineTransform(scaleX: scale, y: scale))
                .intersection(pixelBounds).integral
            let pixels = storage.bindMemory(to: UInt8.self)
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in Int(region.minY)..<Int(region.maxY) {
                for x in Int(region.minX)..<Int(region.maxX) {
                    let offset = (y * width + x) * 4
                    let r = pixels[offset], g = pixels[offset + 1], b = pixels[offset + 2]
                    let isInk = light ? (r > 190 && g > 190 && b > 170) : (r < 80 && g < 90 && b < 80)
                    if isInk {
                        minX = min(minX, x); maxX = max(maxX, x)
                        minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return CGRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
                          width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
        }
        return try XCTUnwrap(bounds, "The recognized action must contain actual contrasting glyphs")
    }
}
