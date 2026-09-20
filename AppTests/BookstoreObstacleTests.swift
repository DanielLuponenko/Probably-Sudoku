import XCTest
import SceneKit
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookstoreObstacleTests: XCTestCase {
    func testObstacleInfoUsesPerBookUnlockStateAndNamesThePrecedingObstacle() {
        XCTAssertTrue(ObstacleInfoPopup.lockedState(obstacle: .shortHandedAndBlocked,
                                                    unlockedThrough: Obstacle.shortHanded.rawValue))
        XCTAssertFalse(ObstacleInfoPopup.lockedState(obstacle: .shortHandedAndBlocked,
                                                     unlockedThrough: Obstacle.shortHandedAndBlocked.rawValue))

        let locked = ObstacleInfoPopup(obstacle: .shortHandedAndBlocked, isLocked: true, onClose: {})
        XCTAssertEqual(locked.statusText, "LOCKED")
        XCTAssertEqual(locked.detailFooter,
                       "Finish Obstacle II in this Book to unlock Obstacle III.")

        let available = ObstacleInfoPopup(obstacle: .shortHandedAndBlocked, isLocked: false, onClose: {})
        XCTAssertEqual(available.statusText, "AVAILABLE")
        XCTAssertEqual(available.detailFooter, "Ready to play in this Book.")
    }

    func testObstacleInfoCloseKeepsVisibleIconButProvidesAccessibleHitTarget() {
        XCTAssertEqual(ObstacleInfoPopup.closeIconSize, 28)
        XCTAssertGreaterThanOrEqual(ObstacleInfoPopup.closeHitTarget, 44)
    }

    func testObstaclePopupFitsNormalPaperAndKeepsEnlargedCloseAboveScrollableCopy() async throws {
        let viewport = CGSize(width: 375, height: 667)
        var normalPaperHeight: CGFloat = 0
        var dismissals = 0
        for type in [DynamicTypeSize.large, .accessibility5] {
            let popup = ObstacleInfoPopup(obstacle: .finalEdition, isLocked: true,
                                          onClose: { dismissals += 1 })
                .background(Color.black)
                .environment(\.dynamicTypeSize, type)
                .environment(\.gameReduceMotion, true)
                .environment(\.colorScheme, .light)
                .environment(\.locale, Locale(identifier: "en_US"))
                .transaction { $0.disablesAnimations = true }
            let host = UIHostingController(rootView: popup)
            host.safeAreaRegions = []
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previousKey = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: viewport)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer {
                window.isHidden = true
                window.rootViewController = nil
                previousKey?.makeKey()
            }
            try await Task.sleep(for: .milliseconds(100))
            window.layoutIfNeeded()
            func capture(_ suffix: String) -> UIImage {
                let image = UIGraphicsImageRenderer(size: viewport).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "obstacle-popup-\(type)-\(suffix)"
                attachment.lifetime = .keepAlways
                add(attachment)
                return image
            }
            let image = capture("top")
            let paper = try obstaclePaperBounds(in: image)
            XCTAssertGreaterThanOrEqual(paper.minY, 19)
            XCTAssertLessThanOrEqual(paper.maxY, viewport.height - 19)
            let rows = try obstacleTextRows(in: image)
            XCTAssertTrue(rows.contains { $0.contains("obstacle") },
                          "The word OBSTACLE must not split across lines: \(rows)")
            XCTAssertTrue(rows.joined(separator: " ").contains("locked"), "\(rows)")
            let close = CGRect(x: paper.maxX - 50, y: paper.minY + 30, width: 20, height: 20)
            XCTAssertGreaterThan(try obstacleInkPixels(in: image, within: close), 8,
                                 "The close glyph must stay inside the visible paper header")
            if type == .large {
                normalPaperHeight = paper.height
                XCTAssertLessThan(paper.height, 360,
                                  "A short normal explanation must not paint a nearly full-screen card")
                XCTAssertTrue(rows.joined(separator: " ").contains("tosses"), "\(rows)")
                XCTAssertTrue(rows.joined(separator: " ").contains("unlock"), "\(rows)")
            } else {
                XCTAssertGreaterThan(paper.height, normalPaperHeight * 1.3)
                func scrolls(_ view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap(scrolls)
                }
                let scroll = try XCTUnwrap(scrolls(host.view).max { $0.bounds.height < $1.bounds.height })
                XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height,
                                     "The full AX5 explanation must enlarge and scroll, not shrink or truncate")
                let maxOffset = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                scroll.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: false)
                try await Task.sleep(for: .milliseconds(50))
                window.layoutIfNeeded()
                let bottom = capture("bottom")
                let bottomRows = try obstacleTextRows(in: bottom).joined(separator: " ")
                XCTAssertTrue(bottomRows.contains("unlock"), bottomRows)
                XCTAssertGreaterThan(try obstacleInkPixels(in: bottom, within: close), 8,
                                     "Scrolling the explanation must leave Close visible")
            }
        }
        XCTAssertEqual(dismissals, 0)
    }

    private func obstacleTextRows(in image: UIImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string.lowercased() }
    }

    private func obstaclePixels(in image: UIImage) throws -> (data: [UInt8], width: Int, height: Int, scale: CGFloat) {
        let cg = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try pixels.withUnsafeMutableBytes { data in
            let context = try XCTUnwrap(CGContext(data: data.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return (pixels, cg.width, cg.height, CGFloat(cg.width) / image.size.width)
    }

    private func obstaclePaperBounds(in image: UIImage) throws -> CGRect {
        let pixels = try obstaclePixels(in: image)
        var left = pixels.width, right = -1, top = pixels.height, bottom = -1
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let p = (y * pixels.width + x) * 4
                if pixels.data[p] > 210, pixels.data[p + 1] > 205, pixels.data[p + 2] > 190 {
                    left = min(left, x); right = max(right, x)
                    top = min(top, y); bottom = max(bottom, y)
                }
            }
        }
        XCTAssertGreaterThan(right, left)
        return CGRect(x: CGFloat(left) / pixels.scale, y: CGFloat(top) / pixels.scale,
                      width: CGFloat(right - left + 1) / pixels.scale,
                      height: CGFloat(bottom - top + 1) / pixels.scale)
    }

    private func obstacleInkPixels(in image: UIImage, within area: CGRect) throws -> Int {
        let pixels = try obstaclePixels(in: image)
        var count = 0
        for y in max(0, Int(area.minY * pixels.scale))..<min(pixels.height, Int(area.maxY * pixels.scale)) {
            for x in max(0, Int(area.minX * pixels.scale))..<min(pixels.width, Int(area.maxX * pixels.scale)) {
                let p = (y * pixels.width + x) * 4
                if pixels.data[p] < 160, pixels.data[p + 1] < 160, pixels.data[p + 2] < 160 { count += 1 }
            }
        }
        return count
    }

    func testEveryBookUsesItsOwnSuppliedCeilingIncludingNormalDebugLaunches() {
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
                               "First-book access must use the same per-book policy")
                for edition in BookEdition.shelf.dropFirst() {
                    XCTAssertEqual(edition.availableObstacle(selected, progressUnlockedThrough: progress),
                                   preview.rawValue <= progress ? preview : .none,
                                   "Preview \(preview) carried into \(edition.id)")
                }
            }
        }
    }

    func testExplicitSamplerDoesNotPromoteSavedOrCloudProgress() throws {
        // Decode a real legacy save envelope in memory; never touch RunStore's
        // disk-backed progress or resume files from a rendering test.
        let data = Data(#"{"unlockedObstacle":4,"booksCompleted":3}"#.utf8)
        let progress = try JSONDecoder().decode(RunStore.Progress.self, from: data)
        var achievements = AchievementProgress()
        achievements.merge(localProgress: progress)
        let before = achievements
        let sampler = BookEdition.obstacleUnlocks(for: achievements, arguments: ["-previewFirstBookObstacles"])
        #if DEBUG && targetEnvironment(simulator)
        XCTAssertEqual(sampler[Book.probably.rawValue], 9)
        #else
        XCTAssertEqual(sampler[Book.probably.rawValue], 2)
        #endif
        XCTAssertEqual(sampler[Book.slightlyHarder.rawValue], 2)
        XCTAssertEqual(sampler[Book.bites.rawValue], 1)
        XCTAssertEqual(achievements, before)
        let restored = try JSONDecoder().decode(RunStore.Progress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored.unlockedObstacle, 4)
        XCTAssertEqual(restored.booksCompleted, 3)
        XCTAssertEqual(restored.completedBooks, progress.completedBooks)
        XCTAssertEqual(restored.unlockedObstacle(for: .probably), .shortHanded)
        XCTAssertEqual(restored.unlockedObstacle(for: .bites), .none)
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
        let rack = Rack(progressByBookID: [Book.probably.rawValue: 9])
        defer { rack.close() }
        let original = try rack.coverData()

        rack.selectedObstacle = .finalEdition
        rack.focusSerial = 1
        rack.update()
        try assertMaterial(rack, edition: .first,
                           unlockedThrough: 9,
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

        // An explicit all-books QA fixture still prints each keyed value.
        rack.progressByBookID = nil
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

    func testSamplerRequiresExplicitArgumentAndIsExcludedFromReleaseAndDevices() {
        let progress = AchievementProgress()
        for edition in BookEdition.shelf {
            XCTAssertEqual(BookEdition.obstacleUnlocks(for: progress, arguments: [])[edition.rule.rawValue], 1)
        }
        let sampler = BookEdition.obstacleUnlocks(for: progress, arguments: ["-previewFirstBookObstacles"])
        #if DEBUG && targetEnvironment(simulator)
        XCTAssertEqual(sampler[Book.probably.rawValue], 9)
        #else
        XCTAssertEqual(sampler[Book.probably.rawValue], 1)
        #endif
        for book in Book.allCases where book != .probably { XCTAssertEqual(sampler[book.rawValue], 1) }
    }

    func testCompletedBookKeepsItsOwnMaterialUnlockAfterSelectionReturnAndAnotherBookCompletion() throws {
        // Start from the real persisted shape, including an old global QA
        // ceiling. The material must use only the identified completion.
        let legacy = Data(#"{"unlockedObstacle":9,"booksCompleted":0}"#.utf8)
        var completion = try JSONDecoder().decode(RunStore.Progress.self, from: legacy)
        XCTAssertTrue(completion.recordCompletion(of: .probably, obstacle: .none))
        completion = try JSONDecoder().decode(RunStore.Progress.self,
                                              from: JSONEncoder().encode(completion))
        var profile = PlayerProfile()
        profile.achievementProgress.merge(localProgress: completion)
        var cloudCopy = PlayerProfile()
        cloudCopy.merge(remote: try JSONDecoder().decode(PlayerProfile.self,
                                                        from: JSONEncoder().encode(profile)))
        var achievements = cloudCopy.achievementProgress
        let rack = Rack(progressByBookID: achievements.unlockedObstaclesByBookID)
        defer { rack.close() }
        for edition in BookEdition.shelf {
            try assertMaterial(rack, edition: edition, unlockedThrough: edition.rule == .probably ? 2 : 1)
        }

        rack.selectedObstacle = .shortHanded
        rack.focusSerial = 1
        rack.update()
        rack.isLiveBookPresented = true
        rack.update()
        try assertMaterial(rack, edition: .first, unlockedThrough: 2, selected: .shortHanded)
        rack.returnSerial = 1
        rack.isLiveBookPresented = false
        rack.update()
        rack.selectedIndex = 1
        rack.selectedObstacle = BookEdition.second.availableObstacle(.shortHanded,
                                                                     progressByBookID: achievements.unlockedObstaclesByBookID)
        XCTAssertEqual(rack.selectedObstacle, .none, "The first Book's II cannot carry into an uncompleted Book")
        rack.focusSerial = 2
        rack.turnSerial = 1
        rack.update()
        for edition in BookEdition.shelf {
            try assertMaterial(rack, edition: edition, unlockedThrough: edition.rule == .probably ? 2 : 1)
        }
        let beforeSecondWin = try rack.coverImages()
        achievements.recordBookCompleted(.slightlyHarder, obstacle: .shortHanded)
        rack.progressByBookID = achievements.unlockedObstaclesByBookID
        rack.update()
        for edition in BookEdition.shelf {
            try assertMaterial(rack, edition: edition,
                               unlockedThrough: edition.rule == .probably ? 2 : edition.rule == .slightlyHarder ? 3 : 1)
            XCTAssertEqual(try rack.coverImage(for: edition) === beforeSecondWin[edition.id], edition != .second,
                           "Only the newly completed Book's unlock artwork should be regenerated")
        }
    }

    func testBrowsingKeepsIdenticalCoverImagesAndDoesNotScheduleNoOpScaleActions() throws {
        let rack = Rack()
        defer { rack.close() }
        let original = try rack.coverImages()
        var updateDuration = Duration.zero

        for index in BookEdition.shelf.indices {
            rack.selectedIndex = index
            rack.turnSerial += 1
            let started = ContinuousClock.now
            rack.update()
            updateDuration += started.duration(to: .now)
            let current = try rack.coverImages()
            for edition in BookEdition.shelf {
                XCTAssertTrue(current[edition.id] === original[edition.id],
                              "Browsing must not rasterize unchanged \(edition.id) artwork again")
            }
            rack.view.scene?.rootNode.enumerateChildNodes { node, _ in
                XCTAssertNil(node.action(forKey: "selection"),
                             "An unchanged pocket scale must not start another animation")
            }
        }
        let components = updateDuration.components
        let milliseconds = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
        print("Rack browse: 12 real coordinator updates took \(milliseconds) ms (excludes fixture and assertions)")
    }

    func testCoverInvalidationTracksActualPrintedObstacleAndEffectiveUnlockCeiling() throws {
        let rack = Rack()
        defer { rack.close() }
        rack.selectedIndex = 1
        rack.update()
        let original = try rack.coverImages()

        rack.selectedObstacle = .shortHanded
        rack.update()
        let preview = try rack.coverImages()
        for edition in BookEdition.shelf {
            XCTAssertEqual(preview[edition.id] === original[edition.id], edition != .second,
                           "Only the selected book's changed obstacle should be reprinted")
        }
        rack.update()
        XCTAssertTrue(try rack.coverImage(for: .second) === preview[BookEdition.second.id])

        rack.selectedIndex = 2
        rack.selectedObstacle = .none
        rack.update()
        let returned = try rack.coverImages()
        XCTAssertFalse(returned[BookEdition.second.id] === preview[BookEdition.second.id])
        XCTAssertTrue(returned[BookEdition.third.id] === original[BookEdition.third.id],
                      "The newly selected book still has its original unselected-obstacle artwork")
        try assertMaterials(rack, equalTo: original.mapValues { try XCTUnwrap($0.pngData()) },
                            stage: "preview returned to its shelf")

        rack.progressUnlockedThrough = 4
        rack.update()
        let progressed = try rack.coverImages()
        for (index, edition) in BookEdition.shelf.enumerated() {
            let unchanged = expectedCeiling(isFirstBook: index == 0, progress: 1)
                == expectedCeiling(isFirstBook: index == 0, progress: 4)
            XCTAssertEqual(progressed[edition.id] === returned[edition.id], unchanged,
                           "Reprint only when \(edition.id)'s effective unlock artwork changes")
        }
    }

    func testInitialProgressAndSelectionArePrintedOnceBeforeTheFirstSceneUpdate() throws {
        for (index, obstacle, progress) in [(1, Obstacle.smallerHand, 4), (11, .finalEdition, 9)] {
            let rack = Rack(selectedIndex: index, selectedObstacle: obstacle,
                            progressUnlockedThrough: progress, appliesInitialUpdate: false)
            defer { rack.close() }
            let original = try rack.coverImages()
            for (position, edition) in BookEdition.shelf.enumerated() {
                try assertMaterial(rack, edition: edition,
                                   unlockedThrough: expectedCeiling(isFirstBook: position == 0, progress: progress),
                                   selected: position == index ? obstacle : .none)
            }

            rack.update()

            let updated = try rack.coverImages()
            for edition in BookEdition.shelf {
                XCTAssertTrue(updated[edition.id] === original[edition.id],
                              "First update must not replace the already-correct \(edition.id) print")
            }
        }
    }

    /// Clamp independently of the production helper; there is no automatic sampler.
    private func expectedCeiling(isFirstBook: Bool, progress: Int) -> Int {
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
        // The production shelf prints this 480pt canvas at 1.5×. Different
        // raster scales cannot produce equal PNGs even with identical locks.
        // Keep the obstacle threshold independent and compare every pixel.
        renderer.scale = 1.5
        let image = try XCTUnwrap(renderer.uiImage, "Expected cover did not render: \(edition.id)")
        return try XCTUnwrap(image.pngData())
    }

    /// No window or screenshot renderer is needed: inspect the very UIImage
    /// assigned to each production SCNPlane material after real update calls.
    @MainActor
    private final class Rack {
        let coordinator: BookstoreSceneCoordinator
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        var selectedIndex = 0
        var selectedObstacle: Obstacle = .none
        var progressUnlockedThrough = 1
        var progressByBookID: [String: Int]?
        private var resolvedProgress: [String: Int] {
            progressByBookID ?? Dictionary(uniqueKeysWithValues: Book.allCases.map { ($0.rawValue, progressUnlockedThrough) })
        }
        var focusSerial = 0
        var returnSerial = 0
        var turnSerial = 0
        var isLiveBookPresented = false

        init(selectedIndex: Int = 0, selectedObstacle: Obstacle = .none,
             progressUnlockedThrough: Int = 1, progressByBookID: [String: Int]? = nil,
             appliesInitialUpdate: Bool = true) {
            self.selectedIndex = selectedIndex
            self.selectedObstacle = selectedObstacle
            self.progressUnlockedThrough = progressUnlockedThrough
            self.progressByBookID = progressByBookID
            coordinator = BookstoreSceneCoordinator(
                editions: BookEdition.shelf,
                selectedEditionID: BookEdition.shelf[selectedIndex].id,
                selectedObstacle: selectedObstacle,
                unlockedObstaclesByBookID: progressByBookID
                    ?? Dictionary(uniqueKeysWithValues: Book.allCases.map { ($0.rawValue, progressUnlockedThrough) })
            )
            coordinator.install(in: view)
            coordinator.updateViewport(view.bounds.size)
            if appliesInitialUpdate { update() }
        }

        func update() {
            let editionID = BookEdition.shelf[selectedIndex].id
            coordinator.update(
                phase: .choosingBook,
                selectedEditionID: editionID,
                selectedObstacle: selectedObstacle,
                unlockedObstaclesByBookID: resolvedProgress,
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

        func coverImage(for edition: BookEdition) throws -> UIImage {
            let scene = try XCTUnwrap(view.scene)
            var images: [UIImage] = []
            scene.rootNode.enumerateChildNodes { node, _ in
                guard node.name == "edition:\(edition.id)", node.geometry is SCNPlane,
                      let image = node.geometry?.firstMaterial?.diffuse.contents as? UIImage else { return }
                images.append(image)
            }
            XCTAssertEqual(images.count, 1, "Expected one actual front cover material for \(edition.id)")
            return try XCTUnwrap(images.first)
        }

        func coverImages() throws -> [String: UIImage] {
            try Dictionary(uniqueKeysWithValues: BookEdition.shelf.map { edition in
                (edition.id, try coverImage(for: edition))
            })
        }

        func coverData(for edition: BookEdition) throws -> Data {
            try XCTUnwrap(coverImage(for: edition).pngData(),
                          "Cover material had no pixels for \(edition.id)")
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
