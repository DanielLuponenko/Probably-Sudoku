import XCTest
import SceneKit
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookstoreObstacleTests: XCTestCase {
    func testOnlyDebugSimulatorFirstBookGetsTheNineObstacleSamplerForEverySavedCeiling() {
        XCTAssertEqual(BookEdition.shelf.count, 12)
        for progress in [-10, 0, 1, 4, 9, 20] {
            for (index, edition) in BookEdition.shelf.enumerated() {
                let expected = expectedCeiling(isFirstBook: index == 0, progress: progress)
                XCTAssertEqual(edition.unlockedObstacleRawValue(progressUnlockedThrough: progress),
                               expected, "\(edition.id), saved ceiling \(progress)")
                for obstacle in Obstacle.allCases {
                    XCTAssertEqual(edition.availableObstacle(obstacle, progressUnlockedThrough: progress),
                                   obstacle.rawValue <= expected ? obstacle : .none,
                                   "\(edition.id), saved ceiling \(progress), obstacle \(obstacle)")
                }
            }
        }
    }

    func testPreviewObstacleCannotCarryIntoAnotherBookAboveItsSavedUnlock() {
        for progress in [1, 4, 9] {
            for preview in Obstacle.allCases {
                let selected = BookEdition.first.availableObstacle(preview, progressUnlockedThrough: progress)
                let firstBookCeiling = expectedCeiling(isFirstBook: true, progress: progress)
                XCTAssertEqual(selected, preview.rawValue <= firstBookCeiling ? preview : .none,
                               "Volume 1 sampler access must match the build configuration")
                for edition in BookEdition.shelf.dropFirst() {
                    XCTAssertEqual(edition.availableObstacle(selected, progressUnlockedThrough: progress),
                                   preview.rawValue <= progress ? preview : .none,
                                   "Preview \(preview) carried into \(edition.id)")
                }
            }
        }
    }

    func testSamplerDoesNotPromoteTheSavedProgressLadder() throws {
        // Decode a real legacy save envelope in memory; never touch RunStore's
        // disk-backed progress or resume files from a rendering test.
        let data = Data(#"{"unlockedObstacle":4,"booksCompleted":3}"#.utf8)
        let progress = try JSONDecoder().decode(RunStore.Progress.self, from: data)
        for edition in BookEdition.shelf {
            _ = edition.availableObstacle(.finalEdition, progressUnlockedThrough: progress.unlockedObstacle)
        }
        let restored = try JSONDecoder().decode(RunStore.Progress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored.unlockedObstacle, 4)
        XCTAssertEqual(restored.booksCompleted, 3)
        XCTAssertEqual(restored.completedBooks, progress.completedBooks)
        XCTAssertEqual(BookEdition.first.unlockedObstacleRawValue(progressUnlockedThrough: restored.unlockedObstacle),
                       expectedCeiling(isFirstBook: true, progress: 4))
        for edition in BookEdition.shelf.dropFirst() {
            XCTAssertEqual(edition.unlockedObstacleRawValue(progressUnlockedThrough: restored.unlockedObstacle), 4)
        }
    }

    func testRealShelfMaterialsKeepTheirOwnUnlocksAcrossFirstBookFocusReturnAndOtherBookFocus() throws {
        let rack = Rack()
        defer { rack.close() }

        for (index, edition) in BookEdition.shelf.enumerated() {
            try assertMaterial(rack, edition: edition,
                               unlockedThrough: expectedCeiling(isFirstBook: index == 0, progress: 1))
        }
        let original = try rack.coverData()

        rack.focusSerial = 1
        rack.update()
        rack.isLiveBookPresented = true
        rack.update()
        try assertMaterials(rack, equalTo: original, stage: "first book selected")

        rack.returnSerial = 1
        rack.isLiveBookPresented = false
        rack.update()
        try assertMaterials(rack, equalTo: original, stage: "first book returned")

        rack.selectedIndex = 1
        rack.turnSerial = 1
        rack.focusSerial = 2
        rack.update()
        rack.isLiveBookPresented = true
        rack.update()
        try assertMaterials(rack, equalTo: original, stage: "second book selected")

        rack.returnSerial = 2
        rack.isLiveBookPresented = false
        rack.update()
        try assertMaterials(rack, equalTo: original, stage: "second book returned")
    }

    func testPreviewArtworkStaysLocalAndRealMaterialsContinueToRespectSavedAndDebugCeilings() throws {
        let rack = Rack()
        defer { rack.close() }
        let original = try rack.coverData()

        rack.selectedObstacle = BookEdition.first.availableObstacle(.finalEdition, progressUnlockedThrough: 1)
        rack.focusSerial = 1
        rack.update()
        try assertMaterial(rack, edition: .first,
                           unlockedThrough: expectedCeiling(isFirstBook: true, progress: 1),
                           selected: rack.selectedObstacle)
        for edition in BookEdition.shelf.dropFirst() {
            let actual = try rack.coverData(for: edition)
            XCTAssertTrue(actual == original[edition.id], "Preview changed the unrelated \(edition.id) material")
        }

        rack.returnSerial = 1
        rack.update()
        rack.selectedIndex = 1
        rack.selectedObstacle = BookEdition.second.availableObstacle(.finalEdition, progressUnlockedThrough: 1)
        rack.turnSerial = 1
        rack.focusSerial = 2
        rack.update()
        try assertMaterials(rack, equalTo: original, stage: "high preview followed by another book")

        rack.returnSerial = 2
        rack.update()

        // The same base value is supplied for every edition. This exercises the
        // actual coordinator update, not a stand-alone copy of its lock policy.
        for progress in [4, 9, 1] {
            rack.progressUnlockedThrough = progress
            rack.selectedIndex = 11
            rack.update()
            for (index, edition) in BookEdition.shelf.enumerated() {
                try assertMaterial(rack, edition: edition,
                                   unlockedThrough: expectedCeiling(isFirstBook: index == 0, progress: progress))
            }
        }
    }

    func testFirstBookSamplerIsExcludedFromReleaseAndPhysicalDeviceBuilds() {
        #if DEBUG && targetEnvironment(simulator)
        XCTAssertEqual(BookEdition.first.unlockedObstacleRawValue(progressUnlockedThrough: 1), 9)
        XCTAssertEqual(BookEdition.first.availableObstacle(.finalEdition, progressUnlockedThrough: 1), .finalEdition)
        #else
        for edition in BookEdition.shelf {
            XCTAssertEqual(edition.unlockedObstacleRawValue(progressUnlockedThrough: 1), 1)
            XCTAssertEqual(edition.availableObstacle(.finalEdition, progressUnlockedThrough: 1), .none)
        }
        #endif
    }

    /// Keep the expected build policy independent of the production helper.
    private func expectedCeiling(isFirstBook: Bool, progress: Int) -> Int {
        #if DEBUG && targetEnvironment(simulator)
        if isFirstBook { return 9 }
        #endif
        return min(9, max(1, progress))
    }

    private func assertMaterial(
        _ rack: Rack,
        edition: BookEdition,
        unlockedThrough: Int,
        selected: Obstacle = .none,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try rack.coverData(for: edition)
        let expected = try expectedCoverData(edition: edition, unlockedThrough: unlockedThrough, selected: selected)
        XCTAssertTrue(actual == expected,
                      "\(edition.id) material must show only obstacles 1...\(unlockedThrough), selected \(selected)",
                      file: file, line: line)
    }

    private func assertMaterials(
        _ rack: Rack,
        equalTo expected: [String: Data],
        stage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try rack.coverData()
        XCTAssertEqual(actual.count, 12, file: file, line: line)
        for edition in BookEdition.shelf {
            XCTAssertTrue(actual[edition.id] == expected[edition.id],
                          "\(edition.id) lock/selection artwork changed during \(stage)", file: file, line: line)
        }
    }

    private func expectedCoverData(
        edition: BookEdition,
        unlockedThrough: Int,
        selected: Obstacle
    ) throws -> Data {
        // Match the production canvas, but supply the expected threshold
        // independently: calling the policy helper here would hide a bad rule.
        let bookWidth: CGFloat = 480
        let canvas = CGSize(width: bookWidth * 1.20, height: bookWidth * 1.4 + bookWidth * 0.045)
        let renderer = ImageRenderer(content:
            ZStack(alignment: .topLeading) {
                LiveBook(
                    edition: edition,
                    ribbons: LiveBook.RibbonStrip(
                        levels: Obstacle.allCases,
                        selected: selected,
                        isUnlocked: { $0.rawValue <= unlockedThrough },
                        onPick: { _ in },
                        onShowInfo: { _ in }
                    )
                )
                .frame(width: bookWidth)
                .allowsHitTesting(false)
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "Expected cover did not render: \(edition.id)")
        return try XCTUnwrap(image.pngData())
    }

    /// No window or screenshot renderer is needed: inspect the very UIImage
    /// assigned to each production SCNPlane material after real update calls.
    @MainActor
    private final class Rack {
        let coordinator = BookstoreSceneCoordinator(editions: BookEdition.shelf)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var selectedIndex = 0
        var selectedObstacle: Obstacle = .none
        var progressUnlockedThrough = 1
        var focusSerial = 0
        var returnSerial = 0
        var turnSerial = 0
        var isLiveBookPresented = false

        init() {
            coordinator.install(in: view)
            coordinator.updateViewport(view.bounds.size)
            update()
        }

        func update() {
            let editionID = BookEdition.shelf[selectedIndex].id
            coordinator.update(
                phase: .choosingBook,
                selectedEditionID: editionID,
                selectedObstacle: selectedObstacle,
                unlockedObstacleRawValue: progressUnlockedThrough,
                turnCommand: .init(serial: turnSerial, selectedIndex: selectedIndex),
                focusCommand: .init(serial: focusSerial, editionID: editionID),
                returnFocusCommand: .init(serial: returnSerial),
                isLiveBookPresented: isLiveBookPresented,
                shopCategory: .paper,
                shopItem: nil,
                shopPresentation: .init(currentIndex: 0, itemCount: 0, stampBalance: 0,
                                        owned: false, equipped: false, affordable: false, message: nil),
                shopDragOffset: nil,
                counterYaw: 0,
                counterForward: 0,
                counterSide: 0,
                cameraForward: 0,
                cameraSide: 0,
                reduceMotion: true,
                debugCameraPosition: nil,
                onSelectEdition: { _ in },
                onRequestBookFocus: { _ in },
                onSelectObstacle: { _ in },
                onShowObstacleInfo: { _ in },
                onSelectShopCategory: { _ in },
                onStepShopItem: { _ in },
                onBuyOrEquipShopItem: {},
                onBookFocusChanged: { _ in },
                onTransitionFinished: { _ in }
            )
        }

        func coverData(for edition: BookEdition) throws -> Data {
            let scene = try XCTUnwrap(view.scene)
            var images: [UIImage] = []
            scene.rootNode.enumerateChildNodes { node, _ in
                guard node.name == "edition:\(edition.id)", node.geometry is SCNPlane,
                      let image = node.geometry?.firstMaterial?.diffuse.contents as? UIImage else { return }
                images.append(image)
            }
            XCTAssertEqual(images.count, 1, "Expected one actual front cover material for \(edition.id)")
            let image = try XCTUnwrap(images.first)
            return try XCTUnwrap(image.pngData(), "Cover material had no pixels for \(edition.id)")
        }

        func coverData() throws -> [String: Data] {
            try Dictionary(uniqueKeysWithValues: BookEdition.shelf.map { edition in
                (edition.id, try coverData(for: edition))
            })
        }

        func close() {
            view.scene?.rootNode.enumerateChildNodes { node, _ in node.removeAllActions() }
            view.isPlaying = false
            view.rendersContinuously = false
            view.scene = nil
        }
    }
}
