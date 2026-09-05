import XCTest
import SwiftUI
import UIKit
import Vision
@testable import ProbablySudoku

@MainActor
final class RollingNumberTests: XCTestCase {
    func testGroupedHighScoresAndNegativeSignFitAsOneCompleteNumber() throws {
        for (value, expected, width) in [
            (122_541, "122,541", CGFloat(150)),
            (123_456_789, "123,456,789", CGFloat(150)),
            (-123_456_789, "-123,456,789", CGFloat(160))
        ] {
            let image = try render(value, size: 48, width: width)
            XCTAssertEqual(try printedText(in: image), expected,
                           "All digits, grouping marks and sign must survive the width constraint")
            XCTAssertEqual(image.size.width, width + 24, accuracy: 0.5)
        }
    }

    func testRenderedHeightStaysFixedThroughCarriesAndShrinkingValues() throws {
        let sequence = [9, 10, 99, 100, 999, 1_000, 9_999, 10_000, 999]
        for size: CGFloat in [36, 48] {
            var previousHeight: CGFloat?
            for value in sequence {
                let image = try render(value, size: size, width: 140)
                if let previousHeight {
                    XCTAssertEqual(image.size.height, previousHeight, accuracy: 0.5,
                                   "A carry or shrink must not change the containing score band's height")
                }
                previousHeight = image.size.height
                XCTAssertEqual(image.size.height, size * 1.18 + 24, accuracy: 0.5)
            }
        }
    }

    func testUngroupedReadoutsPreserveEveryDigitAndSignWithoutAddingSeparators() throws {
        for value in [123_456_789, -98_765] {
            let image = try render(value, size: 32, width: 120, grouped: false)
            XCTAssertEqual(try printedText(in: image), String(value))
        }
    }

    private func render(_ value: Int, size: CGFloat, width: CGFloat,
                        grouped: Bool = true) throws -> UIImage {
        let renderer = ImageRenderer(content:
            RollingNumber(value: value, size: size, color: Paper.ink, grouped: grouped)
                .frame(width: width, alignment: .leading)
                .padding(12)
                .background(Paper.page)
                .environment(\.locale, Locale(identifier: "en_US"))
                .transaction { $0.disablesAnimations = true })
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "number-\(value)-size\(Int(size))-width\(Int(width))-grouped\(grouped)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func printedText(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().filter { !$0.isWhitespace }
        // Vision may name an identical-looking printed minus as a typographic
        // dash. Preserve and verify it; never strip signs or grouping marks.
        return text.replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
    }
}
