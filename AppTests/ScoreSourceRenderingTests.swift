import XCTest
import SwiftUI
import UIKit
import Vision
@testable import ProbablySudoku

@MainActor
final class ScoreSourceRenderingTests: XCTestCase {
    func testStagedSourcesStayAtTheScoreWithoutChangingItsHeight() throws {
        let beats: [ScorePerformance.Beat] = [
            .init(source: "Number placed", value: "+90", kind: .points),
            .init(source: "Local Gossip", value: "+30", kind: .points,
                  sourceID: "bm_local_gossip"),
            .init(source: "Morning Edition", value: "+100", kind: .points,
                  sourceID: "bm_morning_edition"),
            .init(source: "Turn multiplier", value: "×39.75", kind: .multiplier),
            .init(source: "BANKED", value: "+128,000", kind: .bank)
        ]
        for width: CGFloat in [280, 327, 365] {
            for compact in [false, true] {
                let baseline = try render(meter(compact: compact), width: width,
                                          name: "rest-\(Int(width))-\(compact)")
                for beat in beats {
                    let image = try render(meter(compact: compact, beat: beat), width: width,
                                           name: "\(beat.source)-\(Int(width))-\(compact)")
                    XCTAssertEqual(image.size.height, baseline.size.height, accuracy: 0.5,
                                   "Attribution must reuse the queue line, not resize the board below it")
                    let copy = try recognize(image)
                    XCTAssertTrue(normalize(copy).contains(normalize(beat.source)), copy)
                    XCTAssertTrue(normalize(copy).contains(normalize(beat.value)), copy)
                    XCTAssertTrue(normalize(copy).contains("122541"), "The score must remain visible: \(copy)")
                    XCTAssertTrue(normalize(copy).contains("128000"), "The target must remain visible: \(copy)")
                    XCTAssertFalse(copy.contains("…") || copy.contains("..."), copy)
                }
            }
        }
    }

    func testPlainAttributionFitsTheExistingFourteenPointQueueBand() throws {
        let beat = ScorePerformance.Beat(source: "Morning Edition", value: "+100", kind: .points)
        let image = try render(ScoreReceiptView(beat: beat, summary: "Morning Edition, plus 100"),
                               width: 280, name: "plain-score-line")
        XCTAssertLessThanOrEqual(image.size.height - 16, 14.5,
                                "No receipt box, icon or padding should create another banner")
        let copy = try recognize(image)
        XCTAssertTrue(normalize(copy).contains("morningedition"), copy)
        XCTAssertTrue(copy.contains("100"), copy)
    }

    private func meter(compact: Bool, beat: ScorePerformance.Beat? = nil) -> some View {
        ScoreMeter(score: 122_541, target: 128_000, queuedBase: 495,
                   queuedMultiplier: 39.75, recentCoins: 6, compact: compact,
                   beat: beat, performanceSummary: beat.map { "\($0.source), \($0.value)" })
    }

    private func render<V: View>(_ content: V, width: CGFloat, name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: content.frame(width: width).padding(8)
            .background(Paper.page)
            .environment(\.levelPalette, .forDisplay(slot: .easy))
            .environment(\.locale, Locale(identifier: "en_US"))
            .transaction { $0.disablesAnimations = true })
        renderer.scale = 4
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "score-at-scoreboard-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func recognize(_ image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
