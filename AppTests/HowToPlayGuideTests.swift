import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import ProbablySudoku

@MainActor
final class HowToPlayGuideTests: XCTestCase {
    func testTopicsHaveStableIdentityAndBoundedPreviousNextNavigation() {
        let topics = HowToPlayTopic.allCases
        XCTAssertEqual(topics.count, 9)
        XCTAssertEqual(Set(topics.map(\.id)).count, topics.count)
        XCTAssertNil(topics.first?.previous)
        XCTAssertNil(topics.last?.next)
        for topic in topics {
            if let next = topic.next { XCTAssertEqual(next.previous, topic) }
            if let previous = topic.previous { XCTAssertEqual(previous.next, topic) }
            XCTAssertTrue((1...topics.count).contains(topic.pageNumber))
        }
    }

    func testEveryTopicHasAnActualGameFigureAndThreeOrderedInstructions() {
        for topic in HowToPlayTopic.allCases {
            XCTAssertFalse(topic.figures.isEmpty, topic.rawValue)
            XCTAssertEqual(Set(topic.figures.map(\.id)).count, topic.figures.count)
            XCTAssertEqual(topic.steps.map(\.id), [1, 2, 3])
            XCTAssertFalse(topic.title.isEmpty)
            XCTAssertFalse(topic.introduction.isEmpty)
            XCTAssertFalse(topic.note.isEmpty)
            for step in topic.steps {
                XCTAssertFalse(step.title.isEmpty)
                XCTAssertFalse(step.detail.isEmpty)
            }
        }
    }

    func testProgressAndRewardCopyMatchesTheGameInsteadOfPaidSubscriptions() {
        let completion = HowToPlayTopic.finishing.steps.map(\.detail).joined(separator: " ")
        XCTAssertTrue(completion.contains("same Book only"))
        XCTAssertFalse(completion.contains("different Book to unlock"))
        XCTAssertTrue(completion.contains("once per Puzzle"))
        XCTAssertTrue(completion.contains("same board, score and Hand"))

        let allCopy = HowToPlayTopic.allCases.flatMap(\.steps)
            .map { $0.title + " " + $0.detail }.joined(separator: " ").lowercased()
        XCTAssertFalse(allCopy.contains("subscription"))
        XCTAssertTrue(allCopy.contains("not real money"))
        XCTAssertTrue(HowToPlayTopic.cashOut.steps.last?.detail.contains("empty squares and turns") == true)
        XCTAssertTrue(HowToPlayTopic.cashOut.steps.last?.detail.contains("row, column or box earns 1") == true)
        XCTAssertTrue(HowToPlayTopic.cashOut.steps.last?.detail.contains("whole board earns 3") == true)
        XCTAssertTrue(HowToPlayTopic.turns.steps.last?.detail.contains("banked") == true)
        XCTAssertTrue(HowToPlayTopic.turns.steps.last?.detail.contains("automatically") == true)
        XCTAssertTrue(HowToPlayTopic.markers.steps[1].detail.contains("removes the other Marker"))
    }

    func testRealScreenAssetsArePresentAtTheirOriginalResolution() throws {
        for name in Set(GuideFigure.allCases.map(\.asset)) {
            let image = try XCTUnwrap(UIImage(named: name), "Missing actual game capture: \(name)")
            let pixels = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(pixels.width, 1284, name)
            XCTAssertEqual(pixels.height, 2778, name)
        }
    }

    func testAllCropsStayInsideTheirCaptureAndOutsideUnrelatedTopHUD() {
        for figure in GuideFigure.allCases {
            XCTAssertGreaterThanOrEqual(figure.crop.minX, 0)
            XCTAssertGreaterThanOrEqual(figure.crop.minY, 0.18)
            XCTAssertLessThanOrEqual(figure.crop.maxX, 1)
            XCTAssertLessThanOrEqual(figure.crop.maxY, 1)
            XCTAssertGreaterThan(figure.crop.width, 0)
            XCTAssertGreaterThan(figure.crop.height, 0)
            XCTAssertTrue(figure.aspectRatio.isFinite)
            XCTAssertGreaterThan(figure.aspectRatio, 0)
            XCTAssertFalse(figure.caption.isEmpty)
            XCTAssertFalse(figure.accessibilityDescription.isEmpty)
        }
    }

    func testBundledTurnRecordingIsPlayableAndShort() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "guide-place-and-bank", withExtension: "mp4"))
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertFalse(tracks.isEmpty)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 1)
        XCTAssertLessThan(CMTimeGetSeconds(duration), 120)
    }

    func testGuidePagesRenderAtPhoneTabletAndAccessibilityWidths() throws {
        let examples: [(String, HowToPlayTopic, CGFloat, DynamicTypeSize)] = [
            ("phone-place", .place, 320, .large),
            ("phone-route", .bosses, 320, .large),
            ("phone-shop", .shop, 320, .large),
            ("tablet-place", .place, 720, .large),
            ("accessibility-place", .place, 320, .accessibility3)
        ]
        for (name, topic, width, textSize) in examples {
            let renderer = ImageRenderer(content:
                GuideTopicPage(topic: topic, watchTurn: {})
                    .frame(width: width)
                    .padding(16)
                    .background(Paper.page)
                    .environment(\.dynamicTypeSize, textSize)
                    .environment(\.colorScheme, .light)
                    .environment(\.locale, Locale(identifier: "en_US")))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage, name)
            XCTAssertEqual(image.size.width, width + 32, accuracy: 1, name)
            XCTAssertGreaterThan(image.size.height, 200, name)
            if name == "tablet-place" {
                XCTAssertLessThan(image.size.height, 900,
                                  "The wide guide must use two reading columns, not a 720pt-wide board")
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "how-to-play-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
