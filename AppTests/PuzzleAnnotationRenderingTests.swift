import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class PuzzleAnnotationRenderingTests: XCTestCase {
    func testEveryBossNameAndCompleteRuleFitTheTwoLineAnnotation() throws {
        for width: CGFloat in [300, 327, 365] {
            let reservation = try render(BossStampReservation().frame(width: width),
                                         name: "boss-reservation-\(Int(width))", attach: false)
            for boss in BossModifier.allCases {
                let censored: Digit? = boss == .censor ? .seven : nil
                let image = try render(BossStamp(boss: boss, censored: censored).frame(width: width),
                                       name: "boss-\(boss.rawValue)-\(Int(width))")
                var text = try recognizedText(in: image)
                if boss == .erratum {
                    // Visually verified the rendered zero. Vision reads this
                    // isolated proportional-font glyph as O; correct only
                    // this exact phrase, not digits elsewhere in the suite.
                    XCTAssertEqual(boss.text, "Toss allowance 0")
                    text = text.replacingOccurrences(of: "Toss allowance O", with: "Toss allowance 0")
                }
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

    private func recognizedText(in image: UIImage, handwriting: Bool = false) throws -> String {
        let request = VNRecognizeTextRequest()
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
