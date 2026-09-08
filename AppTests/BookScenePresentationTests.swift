import XCTest
import SwiftUI
import UIKit
import SceneKit
import Metal
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookScenePresentationTests: XCTestCase {
    func testBookstoreSceneryGatesDoNotHideInteractiveSceneWhenMotionIsDisabled() {
        for visible in [false, true] {
            for active in [false, true] {
                for covered in [false, true] {
                    let sceneVisible = BookstoreMotionPolicy.isSceneVisible(
                        isVisible: visible, sceneIsActive: active, isCovered: covered)
                    XCTAssertEqual(sceneVisible, visible && active && !covered)
                    for preference in [false, true] {
                        for reduced in [false, true] {
                            for lowPower in [false, true] {
                                XCTAssertEqual(BookstoreMotionPolicy.animatesScenery(
                                    isSceneVisible: sceneVisible, preference: preference,
                                    reduceMotion: reduced, lowPower: lowPower),
                                    visible && active && !covered && preference && !reduced && !lowPower)
                            }
                        }
                    }
                }
            }
        }
    }

    func testBookstoreRenderPolicyThrottlesOnlySettledStore() {
        XCTAssertEqual(BookstoreRenderPolicy.preferredFramesPerSecond(
            phase: .store, hasReportedFirstFrame: true, awaitingFrame: false), 30)
        for phase in [BookstoreScenePhase.transitioningToStand,
                      .choosingBook, .transitioningToStore,
                      .transitioningToShop, .shopping, .transitioningShopToStore] {
            XCTAssertEqual(BookstoreRenderPolicy.preferredFramesPerSecond(
                phase: phase, hasReportedFirstFrame: true, awaitingFrame: false), 60,
                           "\(phase) must retain full-rate rendering")
        }
        XCTAssertEqual(BookstoreRenderPolicy.preferredFramesPerSecond(
            phase: .store, hasReportedFirstFrame: false, awaitingFrame: false), 60)
        XCTAssertEqual(BookstoreRenderPolicy.preferredFramesPerSecond(
            phase: .store, hasReportedFirstFrame: true, awaitingFrame: true), 60)
    }

    func testThermalPressureCapsEveryScenePhaseAndRecoversWithoutChangingNormalCadence() {
        for phase in [BookstoreScenePhase.store, .transitioningToStand, .choosingBook,
                      .transitioningToStore, .transitioningToShop, .shopping,
                      .transitioningShopToStore] {
            for ready in [false, true] {
                for awaitingFrame in [false, true] {
                    for thermalState in [ProcessInfo.ThermalState.serious, .critical] {
                        XCTAssertEqual(BookstoreRenderPolicy.preferredFramesPerSecond(
                            phase: phase, hasReportedFirstFrame: ready,
                            awaitingFrame: awaitingFrame, thermalState: thermalState), 30)
                    }
                    let normal = phase == .store && ready && !awaitingFrame ? 30 : 60
                    for thermalState in [ProcessInfo.ThermalState.nominal, .fair] {
                        XCTAssertEqual(BookstoreRenderPolicy.preferredFramesPerSecond(
                            phase: phase, hasReportedFirstFrame: ready,
                            awaitingFrame: awaitingFrame, thermalState: thermalState), normal)
                    }
                }
            }
        }
    }

    @MainActor
    func testTitleSceneTexturesUseLogicalPixelBudgets() {
        let coordinator = BookstoreSceneCoordinator(editions: BookEdition.shelf)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        coordinator.install(in: view)

        var dimensions = Set<String>()
        view.scene?.rootNode.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] {
                guard let image = material.diffuse.contents as? UIImage,
                      let cgImage = image.cgImage else { continue }
                dimensions.insert("\(cgImage.width)x\(cgImage.height)")
            }
        }
        XCTAssertTrue(dimensions.contains { $0.hasPrefix("1008x") }, "sign must stay at its logical width")
        XCTAssertTrue(dimensions.contains("128x512"), "spines must not inherit device 3x scale")
        XCTAssertTrue(dimensions.contains("96x96"), "wood texture must use its logical canvas")
        // The live shelf bakes its obstacle strip into the cover image. The
        // separate tab material is lazy and is not installed in this scene.
    }

    func testStationaryStandSignSwapsBookabilityWithoutDuplicatingOrMovingParent() throws {
        let coordinator = BookstoreSceneCoordinator(editions: BookEdition.shelf)
        let printNode = try XCTUnwrap(coordinator.standTitlePrintNodeForTesting)
        let initialParentTransform = try XCTUnwrap(printNode.parent?.simdWorldTransform)
        let initialImage = try XCTUnwrap(printNode.geometry?.firstMaterial?.diffuse.contents as? UIImage)
        XCTAssertEqual(coordinator.standTitleContentKeyForTesting, "identity")
        XCTAssertEqual(coordinator.standTitleTextureCountForTesting, 1)
        let initialTwoLines = (printNode.geometry?.firstMaterial?.value(forKey: "standTitleTwoLines") as? NSNumber)?.floatValue
        XCTAssertEqual(initialTwoLines, 1)

        func update(phase: BookstoreScenePhase, selected: BookEdition, live: Bool,
                    reduceMotion: Bool = true) {
            coordinator.update(
                phase: phase, selectedEditionID: selected.id, selectedObstacle: .none,
                unlockedObstaclesByBookID: [:],
                turnCommand: BookstoreTurnCommand(serial: -1, selectedIndex: 0),
                focusCommand: BookstoreFocusCommand(serial: -1, editionID: selected.id),
                returnFocusCommand: BookstoreReturnFocusCommand(serial: -1),
                isLiveBookPresented: live, shopCategory: .paper, shopItem: nil,
                shopPresentation: BookstoreShopPresentation(currentIndex: 0, itemCount: 0,
                                                             stampBalance: 0, owned: false,
                                                             equipped: false, affordable: false,
                                                             message: nil),
                shopDragOffset: nil, counterYaw: 0, counterForward: 0, counterSide: 0,
                cameraForward: 0, cameraSide: 0, reduceMotion: reduceMotion,
                ambientMotionEnabled: false, debugCameraPosition: nil,
                onSelectEdition: { _ in }, onRequestBookFocus: { _ in },
                onSelectObstacle: { _ in }, onShowObstacleInfo: { _ in },
                onSelectShopCategory: { _ in }, onStepShopItem: { _ in },
                onBuyOrEquipShopItem: {}, onBookFocusChanged: { _ in },
                onTransitionFinished: { _ in })
        }

        let edition = BookEdition.shelf[8]
        update(phase: .choosingBook, selected: edition, live: true)
        let benefitImage = try XCTUnwrap(printNode.geometry?.firstMaterial?.diffuse.contents as? UIImage)
        XCTAssertEqual(coordinator.standTitleContentKeyForTesting, "benefit|\(edition.id)")
        XCTAssertEqual(coordinator.standTitleTextureCountForTesting, 2)
        XCTAssertFalse(benefitImage === initialImage)
        XCTAssertEqual(benefitImage.cgImage?.width, 1008)
        XCTAssertEqual(benefitImage.cgImage?.height, initialImage.cgImage?.height)
        XCTAssertEqual(printNode.parent?.simdWorldTransform, initialParentTransform)
        let benefitTwoLines = (printNode.geometry?.firstMaterial?.value(forKey: "standTitleTwoLines") as? NSNumber)?.floatValue
        XCTAssertEqual(benefitTwoLines, 0)

        let benefitCGImage = try XCTUnwrap(benefitImage.cgImage)
        var pixels = [UInt8](repeating: 0, count: 1008 * benefitCGImage.height * 4)
        let pixelContext = CGContext(data: &pixels, width: 1008, height: benefitCGImage.height,
                                     bitsPerComponent: 8, bytesPerRow: 1008 * 4,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        pixelContext?.draw(benefitCGImage, in: CGRect(x: 0, y: 0,
                                                     width: 1008, height: benefitCGImage.height))
        var subtitleMaximumLuma: UInt8 = 0
        for y in 170..<188 {
            for x in 80..<920 {
                let index = (y * 1008 + x) * 4
                let luma = UInt8((Int(pixels[index]) * 299
                                  + Int(pixels[index + 1]) * 587
                                  + Int(pixels[index + 2]) * 114) / 1000)
                subtitleMaximumLuma = max(subtitleMaximumLuma, luma)
            }
        }
        XCTAssertLessThan(subtitleMaximumLuma, 180,
                          "benefit sign must not retain the explanatory subtitle")
        var titleMinX = 1008
        var titleMaxX = 0
        for y in 25..<145 {
            for x in 80..<920 {
                let index = (y * 1008 + x) * 4
                let luma = (Int(pixels[index]) * 299
                            + Int(pixels[index + 1]) * 587
                            + Int(pixels[index + 2]) * 114) / 1000
                if luma > 180 {
                    titleMinX = min(titleMinX, x)
                    titleMaxX = max(titleMaxX, x)
                }
            }
        }
        XCTAssertGreaterThan(titleMaxX, titleMinX)
        XCTAssertEqual((titleMinX + titleMaxX) / 2, 504, accuracy: 18,
                       "benefit title ink must stay centered on the sign")

        update(phase: .choosingBook, selected: edition, live: true)
        let repeatedImage = try XCTUnwrap(printNode.geometry?.firstMaterial?.diffuse.contents as? UIImage)
        XCTAssertTrue(repeatedImage === benefitImage)
        XCTAssertEqual(coordinator.standTitleTextureCountForTesting, 2)

        update(phase: .transitioningToStore, selected: edition, live: false, reduceMotion: false)
        XCTAssertNotNil(printNode.action(forKey: "stand-title-writing"))
        // A reduced-motion update cancels the in-flight chalk write and
        // commits the latest identity print immediately.
        update(phase: .transitioningToStore, selected: edition, live: false)
        let revertedImage = try XCTUnwrap(printNode.geometry?.firstMaterial?.diffuse.contents as? UIImage)
        XCTAssertTrue(revertedImage === initialImage)
        XCTAssertEqual(coordinator.standTitleContentKeyForTesting, "identity")
        XCTAssertEqual(printNode.parent?.simdWorldTransform, initialParentTransform)
    }

    func testStandSignRevealShaderRendersInkWithoutMagentaAndKeepsIdentityCached() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal is unavailable in this test environment")
        }
        let coordinator = BookstoreSceneCoordinator(editions: BookEdition.shelf)
        let source = try XCTUnwrap(coordinator.standTitlePrintNodeForTesting)
        let sourceImage = try XCTUnwrap(source.geometry?.firstMaterial?.diffuse.contents as? UIImage)
        let isolated = source.clone()
        let isolatedGeometry = try XCTUnwrap(isolated.geometry?.copy() as? SCNGeometry)
        isolated.geometry = isolatedGeometry
        let isolatedMaterial = try XCTUnwrap(isolatedGeometry.firstMaterial?.copy() as? SCNMaterial)
        isolatedGeometry.materials = [isolatedMaterial]
        isolated.position = SCNVector3Zero

        let scene = SCNScene()
        scene.background.contents = UIColor.black
        scene.rootNode.addChildNode(isolated)
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 0.37
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 1)
        scene.rootNode.addChildNode(cameraNode)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode

        func snapshot(reveal: Float) throws -> UIImage {
            isolatedMaterial.setValue(reveal, forKey: "standTitleReveal")
            return renderer.snapshot(atTime: 0,
                                     with: CGSize(width: 256, height: 68),
                                     antialiasingMode: .none)
        }
        func pixels(_ image: UIImage) throws -> [UInt8] {
            let cgImage = try XCTUnwrap(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
            let context = CGContext(data: &bytes, width: cgImage.width, height: cgImage.height,
                                     bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(cgImage, in: CGRect(x: 0, y: 0,
                                              width: cgImage.width, height: cgImage.height))
            return bytes
        }
        func difference(_ lhs: [UInt8], _ rhs: [UInt8]) -> Int {
            stride(from: 0, to: min(lhs.count, rhs.count), by: 4).reduce(into: 0) { count, index in
                if abs(Int(lhs[index]) - Int(rhs[index]))
                    + abs(Int(lhs[index + 1]) - Int(rhs[index + 1]))
                    + abs(Int(lhs[index + 2]) - Int(rhs[index + 2])) > 24 {
                    count += 1
                }
            }
        }
        func magentaPixels(_ bytes: [UInt8]) -> Int {
            stride(from: 0, to: bytes.count, by: 4).reduce(into: 0) { count, index in
                if bytes[index] > 150, bytes[index + 2] > 150, bytes[index + 1] < 100 { count += 1 }
            }
        }

        let blankImage = try snapshot(reveal: 0)
        let midImage = try snapshot(reveal: 0.5)
        let fullImage = try snapshot(reveal: 1)
        for (name, image) in [("erased", blankImage), ("writing", midImage), ("complete", fullImage)] {
            let attachment = XCTAttachment(image: image)
            attachment.name = "chalk-sign-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let blank = try pixels(blankImage)
        let midway = try pixels(midImage)
        let full = try pixels(fullImage)
        XCTAssertLessThan(magentaPixels(blank) + magentaPixels(midway) + magentaPixels(full), 256,
                          "shader failure must not paint the sign magenta")
        let fullChange = difference(blank, full)
        let midChange = difference(blank, midway)
        XCTAssertGreaterThan(fullChange, 100, "fully revealed chalk must differ from the blank board")
        XCTAssertGreaterThan(midChange, 0, "mid-write snapshot must show partial chalk")
        XCTAssertLessThan(midChange, fullChange, "mid-write must remain an intermediate state")
        let afterImage = source.geometry?.firstMaterial?.diffuse.contents as? UIImage
        XCTAssertTrue(sourceImage === afterImage,
                      "isolated reveal rendering must not mutate the cached identity texture")
    }

    func testPostCompletionShelfControlsUseTheSelectedBookTheme() {
        for (index, edition) in BookEdition.shelf.enumerated() {
            let picker = StartBookView(onStart: { _, _ in }, onContinue: {}, initialIndex: index)
            XCTAssertEqual(picker.selectedBookTheme, BookPresentationTheme(book: edition.rule))
        }
    }

    func testPostCompletionShelfIdleKeepsItsExactPhaseAcrossPauseAndResume() {
        var clock = BossMotionClock()
        clock.setRunning(true, at: 100)
        clock.setRunning(false, at: 109)
        let frozen = clock.elapsed(at: 200)
        XCTAssertEqual(BookShelfIdleTiming.bookPhase(at: frozen), 0.5, accuracy: 0.000001)
        XCTAssertEqual(BookShelfIdleTiming.solvingPhase(at: frozen), 9.0 / 7, accuracy: 0.000001)
        clock.setRunning(true, at: 200)
        XCTAssertEqual(clock.elapsed(at: 200), frozen)
        clock.setRunning(false, at: 227)
        XCTAssertEqual(BookShelfIdleTiming.bookPhase(at: clock.elapsed(at: 300)), 0)
        XCTAssertEqual(BookShelfIdleTiming.solvingPhase(at: clock.elapsed(at: 300)), 36.0 / 7,
                       accuracy: 0.000001)
    }

    func testAllTwelveBenefitIllustrationsHaveDifferentShapesNotJustDifferentColors() throws {
        var silhouettes = Set<Data>()
        for book in Book.allCases {
            let image = try render(BookBenefitIllustration(book: book).frame(width: 88, height: 88))
            let bytes = try pixels(image)
            silhouettes.insert(Data(stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }))
        }
        XCTAssertEqual(silhouettes.count, 12,
                       "Changing the hue of the same symbol is not a unique Book illustration")
    }

    func testEveryBookHasVisibleInterludeInkAndItsOwnMovingPart() throws {
        for book in Book.allCases {
            let first = try render(BookInterludeArtwork(book: book, time: 0).frame(width: 360, height: 48))
            let next = try render(BookInterludeArtwork(book: book, time: 1.5).frame(width: 360, height: 48))
            let firstBytes = try pixels(first), nextBytes = try pixels(next)
            let visible = stride(from: 3, to: firstBytes.count, by: 4).filter { firstBytes[$0] > 110 }.count
            XCTAssertGreaterThan(visible, 180,
                                 "\(book.rawValue) must be visible at actual phone size, not almost-transparent edge flecks")
            let changed = stride(from: 0, to: firstBytes.count, by: 4).filter { offset in
                (0..<4).contains { abs(Int(firstBytes[offset + $0]) - Int(nextBytes[offset + $0])) > 12 }
            }.count
            XCTAssertGreaterThan(changed, 12,
                                 "\(book.rawValue)'s illustrated moving part should visibly progress")
            for (image, name) in [(first, "rest"), (next, "moving")] {
                let attachment = XCTAttachment(image: image)
                attachment.name = "book-interlude-\(book.rawValue)-\(name)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testInterludesStayInsideTheirDedicatedWhitespaceAtPhoneAndIPadWidths() throws {
        for width: CGFloat in [240, 328, 700, 1024] {
            for book in Book.allCases {
                // The ten-point clear guard above and below simulates nearby
                // labels. No drawing may leak from the 48-point scene slot.
                let view = VStack(spacing: 0) {
                    Color.clear.frame(height: 10)
                    BookInterludeArtwork(book: book, time: 2).frame(height: 48)
                    Color.clear.frame(height: 10)
                }.frame(width: width)
                let image = try render(view)
                XCTAssertEqual(image.size, CGSize(width: width, height: 68))
                let bytes = try pixels(image)
                let pixelWidth = Int(width)
                for row in Array(0..<9) + Array(59..<68) {
                    XCTAssertTrue((0..<pixelWidth).allSatisfy {
                        bytes[(row * pixelWidth + $0) * 4 + 3] == 0
                    }, "\(book.rawValue) leaks into neighboring print")
                }
            }
        }
    }

    func testSelectionLabelUsesTheSharedPaperSurfaceAndFullBookRule() throws {
        let width: CGFloat = 386
        for edition in BookEdition.shelf {
            let height = SelectedBookBenefitPlaque.height(width: width, showsObstacle: false)
            let label = SelectedBookBenefitPlaque(edition: edition, obstacle: .none)
            let image = try render(label.frame(width: width, height: height))
            XCTAssertEqual(image.size.height, height)
            XCTAssertTrue(label.accessibilitySummary.contains(edition.benefit.detail))
            let attachment = XCTAttachment(image: image)
            attachment.name = "book-benefit-illustrated-\(edition.id)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testPausedArtworkHasDeterministicAppearance() throws {
        for book in Book.allCases {
            let one = try render(BookInterludeArtwork(book: book, time: 2.25).frame(width: 360, height: 48))
            let two = try render(BookInterludeArtwork(book: book, time: 2.25).frame(width: 360, height: 48))
            XCTAssertEqual(one.pngData(), two.pngData(), "A paused scene must not generate fresh randomness")
        }
    }

    private func render<Content: View>(_ content: Content) throws -> UIImage {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, .light))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }

    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4,
                                                 space: colorSpace,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }
}
