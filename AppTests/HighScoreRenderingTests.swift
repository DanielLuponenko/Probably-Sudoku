import XCTest
import SwiftUI
import UIKit
import Vision
@testable import ProbablySudoku

@MainActor
final class HighScoreRenderingTests: XCTestCase {
    func testPhotographedScoreAndBonusesRemainReadableOnPhoneWidths() throws {
        for width: CGFloat in [300, 327, 365] {
            let image = try render(ScoreMeter(score: 122_541, target: 128_000,
                                              queuedBase: 495,
                                              queuedMultiplier: 39.75, recentCoins: 6),
                                   width: width, name: "photo-\(Int(width))")
            let lines = try recognize(image)
            let all = lines.map(\.text).joined(separator: " ")
            XCTAssertTrue(digits(all).contains("122541"), "Complete score must be readable: \(all)")
            XCTAssertTrue(digits(all).contains("128000"), "Complete target must be readable: \(all)")
            XCTAssertTrue(all.lowercased().contains("queued"), "Queued reward must remain visible: \(all)")
            XCTAssertTrue(all.lowercased().contains("coins"), "Coin reward must remain visible: \(all)")
            let scoreLine = try XCTUnwrap(lines.first { digits($0.text).contains("122541") })
            let queuedLine = try XCTUnwrap(lines.first { $0.text.lowercased().contains("queued") })
            XCTAssertGreaterThanOrEqual(scoreLine.rect.height, 18,
                                        "The main score must not be compressed into caption-size digits")
            XCTAssertLessThanOrEqual(scoreLine.rect.maxY, queuedLine.rect.minY + 1,
                                     "The reward receipt needs its own line, not the score's remaining pixels")
        }
    }

    func testHighScoreBandsKeepTheSameHeightWithAndWithoutRewards() throws {
        for compact in [false, true] {
            var heights = [CGFloat]()
            for (score, target, queued, multiplier, coins) in [
                (0, 1_000, 0, 1.0, 0),
                (122_541, 128_000, 495, 39.75, 6),
                (9_999_999, 2_048_000, 123_456, 123.5, 1_234),
                (123_456_789, 999_999_999, 123_456_789, 999.75, 999_999)
            ] {
                let image = try render(ScoreMeter(score: score, target: target,
                                                  queuedBase: queued, queuedMultiplier: multiplier,
                                                  recentCoins: coins, compact: compact),
                                       width: 300, name: "boundary-\(score)-\(compact)")
                heights.append(image.size.height)
                let text = try recognize(image).map(\.text).joined(separator: " ")
                XCTAssertTrue(digits(text).contains(String(score)), "Score clipped: \(text)")
                XCTAssertTrue(digits(text).contains(String(target)), "Target clipped: \(text)")
                if queued > 0 {
                    XCTAssertTrue(text.lowercased().contains("queued"), "Queued label clipped: \(text)")
                    XCTAssertTrue(digits(text).contains(String(queued)), "Queued base clipped: \(text)")
                    XCTAssertTrue(digits(text).contains(digits(multiplier.formatted(.number.precision(.fractionLength(0...2))))),
                                  "Queued multiplier clipped: \(text)")
                }
                if coins > 0 {
                    XCTAssertTrue(text.lowercased().contains("coins"), "Coin label clipped: \(text)")
                    XCTAssertTrue(digits(text).contains(String(coins)), "Coin receipt clipped: \(text)")
                }
            }
            for height in heights { XCTAssertEqual(height, heights[0], accuracy: 0.5) }
        }
    }

    private struct PrintedLine {
        var text: String
        var rect: CGRect
    }

    private func render<V: View>(_ content: V, width: CGFloat, name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: content
            .frame(width: width)
            .padding(12)
            .background(Paper.page)
            .environment(\.levelPalette, .forDisplay(slot: .boss))
            .environment(\.cosmeticTheme, .standard)
            .environment(\.locale, Locale(identifier: "en_US"))
            .transaction { $0.disablesAnimations = true })
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "high-score-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/numberclub-high-score-\(name).png"))
        return image
    }

    private func recognize(_ image: UIImage) throws -> [PrintedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { item in
            guard let text = item.topCandidates(1).first?.string else { return nil }
            let r = item.boundingBox
            return PrintedLine(text: text,
                               rect: CGRect(x: r.minX * image.size.width,
                                            y: (1 - r.maxY) * image.size.height,
                                            width: r.width * image.size.width,
                                            height: r.height * image.size.height))
        }
    }

    private func digits(_ text: String) -> String { text.filter(\.isNumber) }
}
