import XCTest
import SceneKit
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookstoreRackGestureTests: XCTestCase {
    func testShopSubtreeInstallsOnDemandAndIsNotRebuiltOnLaterUpdates() throws {
        let rack = Rack()
        defer { rack.close() }

        XCTAssertNil(rack.view.scene?.rootNode.childNode(withName: "club-shop-root",
                                                        recursively: false))

        rack.update(phase: .shopping)
        let first = try XCTUnwrap(rack.view.scene?.rootNode.childNode(
            withName: "club-shop-root", recursively: false))

        rack.update(phase: .shopping)
        let second = try XCTUnwrap(rack.view.scene?.rootNode.childNode(
            withName: "club-shop-root", recursively: false))
        XCTAssertTrue(first === second, "The authored shop subtree must install only once")
    }

    func testDecorativeSceneDoesNotVendThousandsOfAutomationMeshes() throws {
        let rack = Rack()
        defer { rack.close() }
        XCTAssertTrue(rack.view.accessibilityElementsHidden)
        XCTAssertNotNil(rack.view.automationElements,
                        "nil lets SceneKit enumerate every decorative mesh")
        XCTAssertTrue(try XCTUnwrap(rack.view.automationElements).isEmpty)
        XCTAssertTrue(rack.view.isUserInteractionEnabled,
                      "Ordinary touch selection and rack flicks stay enabled")
        XCTAssertNotNil(try rack.stand())
    }

    func testCoalescedFastPanAppliesItsFinalTranslationAndKeepsCoasting() throws {
        for direction: CGFloat in [-1, 1] {
            let rack = Rack()
            defer { rack.close() }
            let stand = try rack.stand()
            let original = stand.eulerAngles.y

            rack.pan(.began, translation: 15 * direction)
            // Real fast swipes can skip .changed entirely.
            rack.pan(.ended, translation: 145 * direction, velocity: 1_200 * direction)

            XCTAssertEqual(stand.eulerAngles.y, original + Float(145 * direction) * 0.009,
                           accuracy: 0.0001)
            let owner = try XCTUnwrap(rack.node(running: "stand-coast"))
            XCTAssertTrue(owner === stand)
            XCTAssertGreaterThan(try XCTUnwrap(owner.action(forKey: "stand-coast")).duration, 1.05)
            XCTAssertNil(stand.action(forKey: "stand-turn"), "Flicks must not become a short face-snap")
            XCTAssertTrue(rack.selectedEditions.isEmpty,
                          "Selection/cover updates belong at rest, not at release or each spin frame")
        }
    }

    func testCancelledOrFailedPanCannotTurnReportedVelocityIntoMomentum() throws {
        for state in [UIGestureRecognizer.State.cancelled, .failed] {
            let rack = Rack()
            defer { rack.close() }
            let stand = try rack.stand()
            let original = stand.eulerAngles.y
            rack.pan(.began, translation: 0)
            rack.pan(state, translation: 60, velocity: 3_000)

            XCTAssertEqual(stand.eulerAngles.y, original + 60 * 0.009, accuracy: 0.0001)
            // A cancelled drag may gently align with its nearest pocket, but
            // must never inherit the recognizer's stale high release velocity.
            let alignment = try XCTUnwrap(rack.node(running: "stand-coast")?.action(forKey: "stand-coast"))
            XCTAssertEqual(alignment.duration, 1.05, accuracy: 0.0001)
            XCTAssertTrue(rack.selectedEditions.isEmpty)
        }
    }

    func testReduceMotionReleaseAlignsImmediatelyWithoutInertia() throws {
        let rack = Rack(reduceMotion: true)
        defer { rack.close() }
        let stand = try rack.stand()
        let home = stand.eulerAngles.y
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 110, velocity: 3_000)

        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertNil(rack.node(running: "stand-turn"))
        XCTAssertEqual(stand.eulerAngles.y, home + .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(rack.selectedEditions.count, 1)
    }

    func testDisablingBackgroundMotionDoesNotCancelUserDrivenFlickOrBookFocus() throws {
        let rack = Rack()
        defer { rack.close() }
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 100, velocity: 1_200)
        let coast = try XCTUnwrap(rack.node(running: "stand-coast")?.action(forKey: "stand-coast"))

        rack.ambientMotionEnabled = false
        rack.update()

        XCTAssertTrue(rack.node(running: "stand-coast")?.action(forKey: "stand-coast") === coast,
                      "Background scenery is optional; a real flick keeps its physical momentum")
        rack.selectedIndex = 2
        rack.focusSerial += 1
        rack.update()
        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertNotNil(rack.node(running: "stand-turn"),
                        "The user-requested pocket turn still precedes extracting a Book")
        XCTAssertNil(rack.node(running: "book-extraction"))
        XCTAssertFalse(rack.coordinator.gestureRecognizerShouldBegin(rack.gesture))
    }

    func testEnablingReduceMotionStopsAnExistingCoastImmediately() async throws {
        let rack = Rack()
        defer { rack.close() }
        let stand = try rack.stand()
        let home = stand.eulerAngles.y
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 110, velocity: 1_200)
        XCTAssertNotNil(rack.node(running: "stand-coast"))

        rack.reduceMotion = true
        rack.update()

        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertNil(rack.node(running: "stand-turn"))
        XCTAssertEqual(stand.eulerAngles.y, home + .pi / 2, accuracy: 0.0001)
        XCTAssertTrue(rack.selectedEditions.isEmpty, "Do not mutate SwiftUI bindings inside updateUIView")
        await Task.yield()
        XCTAssertEqual(rack.selectedEditions.count, 1)
    }

    func testNewPanGrabsACoastingRackWithoutJumpingBackOrLeavingAnOldAction() throws {
        let rack = Rack()
        defer { rack.close() }
        let stand = try rack.stand()
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 125, velocity: 1_200)
        XCTAssertNotNil(rack.node(running: "stand-coast"))
        let grabbedAngle = stand.eulerAngles.y

        rack.pan(.began, translation: -12)
        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertNil(rack.node(running: "stand-turn"))
        XCTAssertEqual(stand.eulerAngles.y, grabbedAngle - 12 * 0.009, accuracy: 0.0001)
        rack.pan(.changed, translation: -44)
        XCTAssertEqual(stand.eulerAngles.y, grabbedAngle - 44 * 0.009, accuracy: 0.0001)
        XCTAssertTrue(rack.selectedEditions.isEmpty)
    }

    func testHiddenSceneCancelsCoastWithoutPublishingASelection() throws {
        let rack = Rack()
        defer { rack.close() }
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 100, velocity: 1_200)
        let stand = try XCTUnwrap(rack.node(running: "stand-coast"))
        let angle = stand.eulerAngles.y

        rack.coordinator.stopRackMotionWhenHidden()

        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertEqual(stand.eulerAngles.y, angle, accuracy: 0.0001)
        XCTAssertTrue(rack.selectedEditions.isEmpty)
    }

    func testViewTeardownCancelsCoastAndStopsRendering() throws {
        let rack = Rack()
        defer { rack.close() }
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 100, velocity: 1_200)
        XCTAssertNotNil(rack.node(running: "stand-coast"))

        BookstoreSceneView.dismantleUIView(rack.view, coordinator: rack.coordinator)

        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertNil(rack.node(running: "stand-turn"))
        XCTAssertFalse(rack.view.isPlaying)
        XCTAssertFalse(rack.view.rendersContinuously)
        XCTAssertTrue(rack.selectedEditions.isEmpty)
    }

    func testLeavingBookSelectionCancelsCoastAndIgnoresFurtherPanEvents() throws {
        let rack = Rack()
        defer { rack.close() }
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 100, velocity: 1_200)
        XCTAssertNotNil(rack.node(running: "stand-coast"))

        rack.phase = .store
        rack.update()
        let stand = try rack.stand()
        let angle = stand.eulerAngles.y
        XCTAssertNil(rack.node(running: "stand-coast"))
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 200, velocity: 2_000)

        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertEqual(stand.eulerAngles.y, angle, accuracy: 0.0001)
        XCTAssertTrue(rack.selectedEditions.isEmpty)
    }

    func testAccessibleFocusStopsCoastAndFacesTheRequestedPocketBeforeExtraction() throws {
        let rack = Rack()
        defer { rack.close() }
        rack.pan(.began, translation: 0)
        rack.pan(.ended, translation: 100, velocity: 1_200)
        XCTAssertNotNil(rack.node(running: "stand-coast"))

        rack.selectedIndex = 2 // A different face, not the Book currently in front.
        rack.focusSerial += 1
        rack.update()

        XCTAssertNil(rack.node(running: "stand-coast"))
        XCTAssertNotNil(rack.node(running: "stand-turn"))
        XCTAssertNil(rack.node(running: "book-extraction"),
                     "An off-face Book cannot be pulled sideways through its holder")
        XCTAssertFalse(rack.coordinator.gestureRecognizerShouldBegin(rack.gesture),
                       "A second swipe cannot interrupt the protected turn-to-extract operation")
        XCTAssertTrue(rack.selectedEditions.isEmpty)
    }

    /// Feed exactly the same ObjC target/action as UIKit, without inventing a
    /// public production gesture API or relying on a running SceneKit clock.
    @MainActor
    private final class Pan: UIPanGestureRecognizer {
        var reportedState: UIGestureRecognizer.State = .possible
        var reportedTranslation = CGPoint.zero
        var reportedVelocity = CGPoint.zero

        override var state: UIGestureRecognizer.State {
            get { reportedState }
            set { reportedState = newValue }
        }

        override func translation(in view: UIView?) -> CGPoint { reportedTranslation }
        override func velocity(in view: UIView?) -> CGPoint { reportedVelocity }
    }

    /// Synthetic, disk-free presentation facts; no GameModel, RunStore or
    /// PlayerProfileStore instance and no window, render loop or timed waits.
    @MainActor
    private final class Rack {
        let coordinator: BookstoreSceneCoordinator
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let gesture = Pan()
        let unlocks = Dictionary(uniqueKeysWithValues: Book.allCases.map { ($0.rawValue, 1) })
        var selectedIndex = 0
        var focusSerial = 0
        var reduceMotion: Bool
        var ambientMotionEnabled = true
        var phase: BookstoreScenePhase = .choosingBook
        var selectedEditions: [String] = []

        init(reduceMotion: Bool = false) {
            self.reduceMotion = reduceMotion
            coordinator = BookstoreSceneCoordinator(editions: BookEdition.shelf,
                                                    selectedEditionID: BookEdition.first.id,
                                                    unlockedObstaclesByBookID: unlocks)
            coordinator.install(in: view)
            coordinator.updateViewport(view.bounds.size)
            view.isPlaying = false
            view.rendersContinuously = false
            view.addGestureRecognizer(gesture)
            update()
        }

        func pan(_ state: UIGestureRecognizer.State, translation: CGFloat, velocity: CGFloat = 0) {
            gesture.reportedState = state
            gesture.reportedTranslation = CGPoint(x: translation, y: 0)
            gesture.reportedVelocity = CGPoint(x: velocity, y: 0)
            let action = NSSelectorFromString("didPan:")
            XCTAssertTrue(coordinator.responds(to: action))
            _ = coordinator.perform(action, with: gesture)
        }

        func update(phase requestedPhase: BookstoreScenePhase? = nil) {
            let editionID = BookEdition.shelf[selectedIndex].id
            coordinator.update(
                phase: requestedPhase ?? phase,
                selectedEditionID: editionID,
                selectedObstacle: .none,
                unlockedObstaclesByBookID: unlocks,
                turnCommand: .init(serial: 0, selectedIndex: selectedIndex),
                focusCommand: .init(serial: focusSerial, editionID: editionID),
                returnFocusCommand: .init(serial: 0),
                isLiveBookPresented: false,
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
                reduceMotion: reduceMotion,
                ambientMotionEnabled: ambientMotionEnabled,
                debugCameraPosition: nil,
                onSelectEdition: { [weak self] in self?.selectedEditions.append($0) },
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

        func node(running key: String) -> SCNNode? {
            var result: SCNNode?
            view.scene?.rootNode.enumerateChildNodes { node, stop in
                if node.action(forKey: key) != nil {
                    result = node
                    stop.pointee = true
                }
            }
            return result
        }

        func stand() throws -> SCNNode {
            // Inspect the existing physical bearing/base, not private state.
            let roots = try XCTUnwrap(view.scene).rootNode.childNodes
            return try XCTUnwrap(roots.first { node in
                abs(node.position.z + 7.55) < 0.0001 && abs(node.position.y) < 0.0001
                    && node.childNodes.contains(where: { $0.geometry is SCNCone })
            })
        }

        func close() {
            coordinator.stopBookPresentation()
            view.scene?.rootNode.enumerateChildNodes { node, _ in node.removeAllActions() }
            view.isPlaying = false
            view.rendersContinuously = false
            view.scene = nil
        }
    }
}
