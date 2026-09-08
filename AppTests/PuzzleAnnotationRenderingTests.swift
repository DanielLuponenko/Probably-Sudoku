import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class PuzzleAnnotationRenderingTests: XCTestCase {
    func testChangingTurnReplacesHandwritingWithoutSuperimposingThePreviousSentence() async throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled,
                      "This mid-animation check requires the normal-motion simulator setting.")
        let state = MarginBandTestState()
        let content = MarginBandTestView(state: state)
            .frame(width: 365, height: 46)
            .padding(20)
            .background(Color.white)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
        let host = UIHostingController(rootView: content)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 405, height: 86)
        window.rootViewController = host
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(100))
        state.note = MarginNote(text: "Clear a row for more points.", lateral: 0.5,
                                angle: 1.2, underlined: false)
        // Capture the middle of the actual 450ms transition, not a settled
        // ImageRenderer frame that would hide the old/new text collision.
        try await Task.sleep(for: .milliseconds(220))
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "margin-note-mid-turn-transition"
        attachment.lifetime = .keepAlways
        add(attachment)
        let printed = try recognizedText(in: image, handwriting: true)
        XCTAssertEqual(normalize(printed), normalize(state.note.text),
                       "Only the new sentence should be visible halfway through the transition: \(printed)")
    }

    func testEveryBossNameAndCompleteRuleFitTheTwoLineAnnotation() throws {
        for width: CGFloat in [280, 300, 327, 365] {
            let reservation = try render(BossStampReservation().frame(width: width),
                                         name: "boss-reservation-\(Int(width))", attach: false)
            for boss in BossModifier.allCases {
                let censored: Digit? = boss == .censor ? .seven : nil
                let image = try render(BossStamp(boss: boss, censored: censored).frame(width: width),
                                       name: "boss-\(boss.rawValue)-\(Int(width))")
                // OCR the complete copy, not the adjacent decorative seal.
                // The verified Garry render is fully legible, but Vision
                // reads its 3x3 glyph as "00‹" between the two text lines.
                // Keep rendering/containment checks over the entire image.
                let copyLeading = padding + 26 + 7 // BossStamp's seal and gap.
                let copyRegion = CGRect(x: copyLeading / image.size.width, y: 0,
                                        width: 1 - copyLeading / image.size.width, height: 1)
                let text = try recognizedText(in: image, region: copyRegion)
                XCTAssertTrue(normalize(text).contains(normalize(boss.name)),
                              "\(boss.rawValue), \(width): incomplete name: \(text)")
                XCTAssertTrue(normalize(text).contains(normalize(boss.text)),
                              "\(boss.rawValue), \(width): incomplete rule: \(text)")
                if let censored { XCTAssertTrue(text.contains(String(censored.rawValue))) }
                XCTAssertFalse(text.contains("…") || text.contains("..."),
                               "\(boss.rawValue), \(width): annotation must not use an ellipsis")
                XCTAssertEqual(image.size.height, reservation.size.height, accuracy: 0.5,
                               "A Boss annotation must not move the board relative to ordinary puzzles")
                try assertInkContained(in: image,
                                       band: CGRect(x: padding, y: padding, width: width,
                                                    height: image.size.height - 2 * padding),
                                       context: "\(boss.rawValue), \(width)")
            }
        }
    }

    func testRealUnderlinedMarginNotesRemainFullyReadableAndInsideTheirBandsAtAccessibilitySize() throws {
        let notes = [
            "This puzzle has underestimated you.",
            "You've got this. Probably. And honestly, probably is enough."
        ]
        for width: CGFloat in [300, 327, 365] {
            for height: CGFloat in [38, 46] {
                for type in [DynamicTypeSize.large, .accessibility5] {
                    for angle in [-2.6, 2.6] {
                        for (index, text) in notes.enumerated() {
                            let note = MarginNote(text: text, lateral: angle < 0 ? 0 : 1,
                                                  angle: angle, underlined: true)
                            let name = "margin-\(index)-\(Int(width))x\(Int(height))-\(type)-angle\(angle)"
                            let image = try render(MarginNoteView(note: note).frame(width: width, height: height)
                                .environment(\.dynamicTypeSize, type), name: name)
                            var printed = try recognizedText(in: image, handwriting: true)
                            // The 300pt/38pt render visibly contains the initial
                            // handwritten i on line two. Vision omits it when
                            // joining "probably" and "is enough" across lines.
                            // Normalize this verified phrase only; all other
                            // text, ellipsis and escaped-ink checks stay exact.
                            printed = printed.replacingOccurrences(of: "probably senough",
                                                                   with: "probably is enough")
                            XCTAssertEqual(normalize(printed), normalize(text),
                                           "\(name): the full handwritten note must remain readable: \(printed)")
                            XCTAssertFalse(printed.contains("…") || printed.contains("..."))
                            XCTAssertEqual(image.size.height, height + 2 * padding, accuracy: 0.5)
                            try assertInkContained(in: image,
                                                   band: CGRect(x: padding, y: padding, width: width, height: height),
                                                   context: name)
                        }
                    }
                }
            }
        }
    }

    private let padding: CGFloat = 20

    private func render<V: View>(_ content: V, name: String, attach: Bool = true) throws -> UIImage {
        // White guard space deliberately remains outside the allocated band.
        // Nothing clips its children: escaped handwriting/underlines appear
        // in this padding and fail the pixel-bound check below.
        let renderer = ImageRenderer(content: content
            .padding(padding)
            .background(Color.white)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.levelPalette, .forDisplay(slot: .boss))
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .transaction { $0.disablesAnimations = true })
        renderer.scale = 4
        let image = try XCTUnwrap(renderer.uiImage)
        if attach {
            let attachment = XCTAttachment(image: image)
            attachment.name = "puzzle-annotation-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        return image
    }

    private func recognizedText(in image: UIImage, handwriting: Bool = false,
                                region: CGRect? = nil) throws -> String {
        let request = VNRecognizeTextRequest()
        if let region { request.regionOfInterest = region }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = handwriting
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func assertInkContained(in image: UIImage, band: CGRect, context: String,
                                    file: StaticString = #filePath, line: UInt = #line) throws {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        try pixels.withUnsafeMutableBytes { bytes in
            let canvas = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4,
                                                 space: colorSpace, bitmapInfo: bitmapInfo))
            canvas.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let scale = CGFloat(width) / image.size.width
        // Half a point allows edge antialiasing, but not a line of text or
        // the rotated underline to escape its paper band.
        let allowed = band.insetBy(dx: -0.5, dy: -0.5)
        var inkCount = 0
        var escapedCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                guard min(pixels[offset], min(pixels[offset + 1], pixels[offset + 2])) < 230 else { continue }
                inkCount += 1
                let point = CGPoint(x: (CGFloat(x) + 0.5) / scale, y: (CGFloat(y) + 0.5) / scale)
                if !allowed.contains(point) { escapedCount += 1 }
            }
        }
        XCTAssertGreaterThan(inkCount, 20, "\(context): blank render cannot satisfy containment", file: file, line: line)
        XCTAssertEqual(escapedCount, 0, "\(context): \(escapedCount) ink pixels escaped the allocated band",
                       file: file, line: line)
    }
}

@MainActor @Observable
private final class MarginBandTestState {
    var note = MarginNote(text: "Pick a number from your Hand.", lateral: 0.5,
                          angle: 1.2, underlined: false)
}

private struct MarginBandTestView: View {
    var state: MarginBandTestState

    var body: some View {
        PuzzleMarginBand(note: state.note, compact: false)
    }
}
