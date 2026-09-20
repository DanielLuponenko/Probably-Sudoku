import XCTest
import SceneKit
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookstoreSignPresentationTests: XCTestCase {
    func testEveryObstaclePrintsItsActualCombinedRestrictionsAndKeepsTheBookBenefit() {
        let expected: [[String]] = [
            [], ["−1 HAND"], ["−1 HAND · UP TO 1 BLOCKED/TURN"],
            ["−2 HAND · UP TO 1 BLOCKED/TURN"], ["−2 HAND · UP TO 2 BLOCKED/TURN"],
            ["−2 HAND · UP TO 2 BLOCKED/TURN", "−1 TURN"],
            ["−2 HAND · UP TO 2 BLOCKED/TURN", "−1 TURN · NO TOSSES"],
            ["−2 HAND · UP TO 3 BLOCKED/TURN", "−1 TURN · NO TOSSES"],
            ["−3 HAND · UP TO 3 BLOCKED/TURN", "−1 TURN · NO TOSSES"]
        ]
        var keys = Set<String>()
        for edition in BookEdition.shelf {
            for obstacle in Obstacle.allCases {
                let presentation = BookstoreSignPresentation(edition: edition, obstacle: obstacle)
                XCTAssertEqual(presentation.title, edition.benefit.title)
                XCTAssertEqual(presentation.effectLines, expected[obstacle.rawValue - 1])
                XCTAssertTrue(presentation.accessibilityLabel.contains(edition.benefit.detail))
                if obstacle != .none {
                    XCTAssertTrue(presentation.accessibilityLabel.contains(obstacle.name))
                    XCTAssertTrue(presentation.accessibilityLabel.contains(obstacle.text))
                } else {
                    XCTAssertEqual(presentation.cacheKey, "benefit|\(edition.id)")
                    XCTAssertFalse(presentation.accessibilityLabel.contains("Selected Obstacle"))
                }
                XCTAssertTrue(keys.insert(presentation.cacheKey).inserted,
                              "Each Book/Obstacle pair needs independent artwork identity.")
            }
        }
        XCTAssertEqual(keys.count, BookEdition.shelf.count * Obstacle.allCases.count)
    }

    func testRealSceneSignUpdatesForAllObstaclesWithoutMovingOrAccumulatingTextures() throws {
        let rack = Rack()
        defer { rack.close() }
        let node = try XCTUnwrap(rack.coordinator.standTitlePrintNodeForTesting)
        let originalTransform = try XCTUnwrap(node.parent?.simdWorldTransform)
        let plane = try XCTUnwrap(node.geometry as? SCNPlane)
        let size = CGSize(width: plane.width, height: plane.height)
        let plaqueNode = try XCTUnwrap(node.parent?.childNodes.first { $0.geometry is SCNBox })
        let plaque = try XCTUnwrap(plaqueNode.geometry as? SCNBox)
        let printTop = CGFloat(node.position.y) + plane.height * 0.5
        let plaqueTop = CGFloat(plaqueNode.position.y) + plaque.height * 0.5
        let original = try rack.image()
        var previous: UIImage?

        for obstacle in Obstacle.allCases {
            rack.update(obstacle: obstacle)
            let image = try rack.image()
            let presentation = BookstoreSignPresentation(edition: .first, obstacle: obstacle)
            XCTAssertEqual(rack.coordinator.standTitleContentKeyForTesting, presentation.cacheKey)
            XCTAssertFalse(image === previous)
            let expectedHeight: CGFloat = presentation.effectLines.count > 1 ? 0.35 : 0.29
            XCTAssertEqual(image.size.width, original.size.width)
            XCTAssertEqual(image.size.height, image.size.width * expectedHeight / size.width, accuracy: 1)
            XCTAssertEqual(node.parent?.simdWorldTransform, originalTransform)
            XCTAssertEqual(plane.width, size.width)
            XCTAssertEqual(plane.height, expectedHeight, accuracy: 0.0001)
            XCTAssertEqual(CGFloat(node.position.y) + plane.height * 0.5, printTop, accuracy: 0.0001)
            XCTAssertEqual(CGFloat(plaqueNode.position.y) + plaque.height * 0.5, plaqueTop, accuracy: 0.0001)
            XCTAssertEqual(plaque.width, 1.54, accuracy: 0.0001)
            XCTAssertEqual(plaque.height, expectedHeight + 0.07, accuracy: 0.0001)
            XCTAssertLessThanOrEqual(plane.height - size.height, 0.061,
                                     "Only the small downward extension approved above the Book is allowed.")
            XCTAssertEqual(rack.coordinator.standTitleTextureCountForTesting, 2)
            try assertPrint(presentation, image: image)
            if [.none, .shortHanded, .finalEdition].contains(obstacle) {
                attach(image, name: "sign-obstacle-\(obstacle.rawValue)")
            }
            rack.update(obstacle: obstacle)
            XCTAssertTrue(try rack.image() === image, "A redraw must reuse unchanged sign artwork.")
            previous = image
        }

        // A long benefit on another Book must replace both old identities and
        // retain every selected effect on the same physical sign.
        let other = BookEdition.shelf[7]
        rack.update(edition: other, obstacle: .finalEdition)
        let otherImage = try rack.image()
        try assertPrint(BookstoreSignPresentation(edition: other, obstacle: .finalEdition), image: otherImage)
        XCTAssertFalse(otherImage === previous)
        attach(otherImage, name: "sign-long-benefit-obstacle-9")
        XCTAssertEqual(rack.coordinator.standTitleTextureCountForTesting, 2)

        rack.update(edition: other, obstacle: .none, live: false)
        XCTAssertEqual(rack.coordinator.standTitleContentKeyForTesting, "identity")
        XCTAssertTrue(try rack.image() === original)
        XCTAssertEqual(node.parent?.simdWorldTransform, originalTransform)
        XCTAssertEqual(CGSize(width: plane.width, height: plane.height), size)
        XCTAssertEqual(node.position.y, 0)
        XCTAssertEqual(plaqueNode.position.y, 0)
    }

    func testRapidObstacleChangesDuringEraseFinishOnOnlyTheLatestArtwork() async throws {
        let rack = Rack()
        defer { rack.close() }
        let node = try XCTUnwrap(rack.coordinator.standTitlePrintNodeForTesting)
        let material = try XCTUnwrap(node.geometry?.firstMaterial)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = rack.view.scene
        // One renderer owns the clock. The stopped SCNView is only the
        // coordinator's installation surface, not a second animation driver.
        rack.view.scene = nil
        renderer.isPlaying = true
        defer { renderer.isPlaying = false; renderer.scene = nil }
        func advance(_ frames: Int) async throws {
            for _ in 0..<frames {
                // update(atTime:) takes system time, not a zero-based movie
                // timeline. Commit newly queued actions and yield so their
                // real SceneKit callbacks can run between rendered frames.
                SCNTransaction.flush()
                renderer.update(atTime: CACurrentMediaTime())
                try await Task.sleep(for: .milliseconds(16))
            }
        }
        rack.update(obstacle: .none)
        try await advance(2)
        rack.update(obstacle: .shortHanded, reducedMotion: false)
        try await advance(4)
        XCTAssertNotNil(node.action(forKey: "stand-title-writing"))
        let partialReveal = try XCTUnwrap(material.value(forKey: "standTitleReveal") as? NSNumber).floatValue
        XCTAssertLessThan(partialReveal, 1, "Exercise a real partially erased frame, not only queued actions.")

        rack.update(obstacle: .finalEdition, reducedMotion: false)
        try await advance(3)
        rack.update(obstacle: .smallerHand, reducedMotion: false)
        try await advance(100)

        let latest = BookstoreSignPresentation(edition: .first, obstacle: .smallerHand)
        XCTAssertEqual(rack.coordinator.standTitleContentKeyForTesting, latest.cacheKey)
        try assertPrint(latest, image: rack.image())
        XCTAssertEqual((material.value(forKey: "standTitleReveal") as? NSNumber)?.floatValue, 1)
        XCTAssertNil(node.action(forKey: "stand-title-writing"))
        XCTAssertEqual(rack.coordinator.standTitleTextureCountForTesting, 2)
        XCTAssertEqual((node.geometry as? SCNPlane)?.height, 0.29)

        // A motion-preference change during another erase commits the newest
        // choice immediately and cannot be overwritten by an old completion.
        rack.update(obstacle: .finalEdition, reducedMotion: false)
        try await advance(4)
        rack.update(obstacle: .shortHanded, reducedMotion: true)
        let immediate = try rack.image()
        try await advance(100)
        XCTAssertTrue(try rack.image() === immediate)
        try assertPrint(BookstoreSignPresentation(edition: .first, obstacle: .shortHanded), image: immediate)
        XCTAssertNil(node.action(forKey: "stand-title-writing"))
    }

    func testObstacleLetteringKeepsReadableFixedTypeWithoutNarrowingTheText() throws {
        let rack = Rack()
        defer { rack.close() }
        let font = UIFont.systemFont(ofSize: 56, weight: .semibold)
        for obstacle in Obstacle.allCases where obstacle != .none {
            let presentation = BookstoreSignPresentation(edition: .first, obstacle: obstacle)
            for line in presentation.effectLines {
                XCTAssertLessThanOrEqual((line as NSString).size(withAttributes: [.font: font]).width, 936,
                                         "Effects must fit at their readable size without font shrinking: \(line)")
            }
            rack.update(obstacle: obstacle)
            let image = try rack.image()
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
            let effectRows = (request.results ?? []).filter { observation in
                guard let copy = observation.topCandidates(1).first?.string else { return false }
                return copy.contains("BLOCKED") || copy.contains("TOSSES") || copy.contains("TURN")
                    || (copy.contains("HAND") && !copy.contains("SIZE"))
            }
            XCTAssertFalse(effectRows.isEmpty, "The larger rule text must be visible, not only fit mathematically.")
            for row in effectRows {
                XCTAssertGreaterThan(row.boundingBox.height * image.size.height, 35,
                                     "Real rendered glyphs must grow beyond the previous 44-point effect text.")
            }
        }
    }

    private func assertPrint(_ presentation: BookstoreSignPresentation, image: UIImage,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let rows = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        func normalized(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
        let visible = normalized(rows.joined(separator: " "))
        for expected in [presentation.title] + presentation.effectLines {
            XCTAssertTrue(visible.contains(normalized(expected)), "Missing printed '\(expected)': \(rows)", file: file, line: line)
        }
        XCTAssertFalse(rows.contains { $0.contains("…") }, "The selected effects must not truncate.", file: file, line: line)
    }

    private func attach(_ image: UIImage, name: String) {
        try? image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/numberclub-\(name).png"))
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private final class Rack {
        let coordinator = BookstoreSceneCoordinator(editions: BookEdition.shelf)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))

        init() {
            coordinator.install(in: view)
            coordinator.updateViewport(view.bounds.size)
            view.isPlaying = false
            view.rendersContinuously = false
        }

        func update(edition: BookEdition = .first, obstacle: Obstacle,
                    live: Bool = true, reducedMotion: Bool = true) {
            coordinator.update(
                phase: .choosingBook, selectedEditionID: edition.id, selectedObstacle: obstacle,
                unlockedObstaclesByBookID: Dictionary(uniqueKeysWithValues: Book.allCases.map { ($0.rawValue, 9) }),
                turnCommand: .init(serial: -1, selectedIndex: 0),
                focusCommand: .init(serial: -1, editionID: edition.id),
                returnFocusCommand: .init(serial: -1),
                isLiveBookPresented: live, shopCategory: .paper, shopItem: nil,
                shopPresentation: .init(currentIndex: 0, itemCount: 0, stampBalance: 0,
                                        owned: false, equipped: false, affordable: false, message: nil),
                shopDragOffset: nil, counterYaw: 0, counterForward: 0, counterSide: 0,
                cameraForward: 0, cameraSide: 0, reduceMotion: reducedMotion,
                ambientMotionEnabled: false, debugCameraPosition: nil,
                onSelectEdition: { _ in }, onRequestBookFocus: { _ in }, onSelectObstacle: { _ in },
                onShowObstacleInfo: { _ in }, onSelectShopCategory: { _ in }, onStepShopItem: { _ in },
                onBuyOrEquipShopItem: {}, onBookFocusChanged: { _ in }, onTransitionFinished: { _ in })
        }

        func image() throws -> UIImage {
            try XCTUnwrap(coordinator.standTitlePrintNodeForTesting?.geometry?.firstMaterial?.diffuse.contents as? UIImage)
        }

        func close() {
            coordinator.stopBookPresentation()
            view.scene?.rootNode.enumerateChildNodes { node, _ in node.removeAllActions() }
            view.delegate = nil
            view.scene = nil
        }
    }
}
