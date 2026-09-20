import XCTest
import SwiftUI
import UIKit
import SceneKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Repeated production host/scene teardown. Weak references identify retained
/// owners; allocator residency and shared graphics caches are not leak tests.
@MainActor
final class MemoryHostLifecycleTests: XCTestCase {
    func testRepeatedPuzzleHostsReleaseModelCaptureAnchorAndMetalRenderer() async throws {
        for cycle in 0..<4 {
            let references = try await removedPuzzleHost(cancelDuringTurn: cycle.isMultiple(of: 2))
            await drainUntilReleased(references)
            XCTAssertNil(references.model, "Puzzle model survived host removal in cycle \(cycle)")
            XCTAssertNil(references.flipper, "Page turn owner survived host removal in cycle \(cycle)")
            XCTAssertNil(references.renderer, "Metal renderer survived canvas dismantling in cycle \(cycle)")
            XCTAssertNil(references.anchor, "The weak capture anchor must not preserve its page hierarchy")
            XCTAssertNil(references.controller)
        }
    }

    func testNestedPaperHostRemovalReleasesPanelEnvironmentAndGame() async throws {
        for _ in 0..<4 {
            let references = try await removedPaperHost()
            await drainUntilReleased(references)
            XCTAssertNil(references.model)
            XCTAssertNil(references.panelPresenter,
                         "Cancelling the paper stack must break content/environment ownership")
            XCTAssertNil(references.controller)
        }
    }

    func testDismantledStandReleasesCoordinatorSceneAndFrameCallbacks() async throws {
        for _ in 0..<3 {
            let references = try await dismantledStand()
            await drainUntilReleased(references)
            XCTAssertNil(references.sceneCoordinator)
            XCTAssertNil(references.scene, "A stopped extraction must not retain its old scene graph")
            XCTAssertNil(references.sceneView)
            XCTAssertNil(references.callbackOwner, "First-frame completion must be removed at teardown")
        }
    }

    func testCompletedAndCancelledReturnSnapshotsDoNotAccumulateImages() throws {
        let transition = MenuReturnTransition()
        for cycle in 0..<20 {
            weak var released: UIImage?
            try autoreleasepool {
                let image = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 240)).image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 160, height: 240))
                }
                released = image
                let token = try XCTUnwrap(transition.begin(snapshot: image))
                if cycle.isMultiple(of: 2) {
                    XCTAssertTrue(transition.destinationDidRender(token: token))
                    transition.finish(token: token)
                } else {
                    transition.cancel()
                }
                XCTAssertNil(transition.snapshot)
            }
            XCTAssertNil(released)
        }
    }

    func testPreparedAndTimedGamesReleaseAfterTheirOwnerIsRetired() async throws {
        for cycle in 0..<6 {
            let references = await retiredPreparedGame(seed: "lifetime-preparation-\(cycle)")
            await drainUntilReleased(references)
            XCTAssertNil(references.model, "The prepared result cannot retain its model after cancellation")
        }
        var run = RunState(seed: "lifetime-timed-boss")
        run.slot = .boss
        run.pendingBoss = .tikTak
        var game = Game(run: run)
        try game.startPuzzle()
        weak var released: GameModel?
        autoreleasepool {
            let model = GameModel(resuming: game, savesProgress: false)
            let instant = ContinuousClock.now
            model.setClockRunning(true, at: instant)
            model.tickClock(at: instant.advanced(by: .seconds(1)))
            XCTAssertTrue(model.isClockRunning)
            XCTAssertTrue(model.abandonRun())
            XCTAssertFalse(model.isClockRunning)
            released = model
        }
        XCTAssertNil(released, "The boss clock must not introduce an independently retained timer")
    }

    private func removedPuzzleHost(cancelDuringTurn: Bool) async throws -> MemoryOwnerReferences {
        let game = try QAScoringFixture.modifierPreview.makeGame()
        let model = GameModel(resuming: game, savesProgress: false)
        let flipper = PageFlipper()
        // Prepare through the production API; the turn below explicitly
        // exercises motion without modifying the simulator's accessibility preference.
        flipper.prepareRenderer()
        let presenter = MarkerInspectionPresenter()
        let controller = UIHostingController(rootView: AnyView(
            MemoryPuzzleHost(model: model, flipper: flipper, presenter: presenter)
            .paperPanelHost()
            .environment(\.scenePhase, .active)))
        controller.safeAreaRegions = []
        let (window, previousKey) = try mount(controller, size: CGSize(width: 402, height: 874))
        defer { close(window, previousKey: previousKey) }
        await settle(window)
        let renderer = try XCTUnwrap(flipper.renderer, "The production host must mount the real Metal canvas")
        let anchor = try XCTUnwrap(flipper.captureAnchor)
        let references = MemoryOwnerReferences()
        references.model = model
        references.flipper = flipper
        references.renderer = renderer
        references.anchor = anchor
        references.controller = controller

        // Exercise score playback and native board touch coordinators before
        // leaving, rather than only mounting an inert rectangle.
        model.place(handIndex: 0, at: Square(3))
        XCTAssertEqual(model.liveScoreCalculation.total, 960)
        await settle(window)
        let turn = Task { @MainActor in
            await flipper.flip(from: model, reduceMotion: false) {}
        }
        for _ in 0..<20 {
            if flipper.isFlipping { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(flipper.isFlipping)
        if cancelDuringTurn {
            controller.rootView = AnyView(Color.clear)
            await settle(window)
            XCTAssertFalse(flipper.isFlipping, "Removing BookView must cancel the active display link")
            // Avoid leaving a continuation hanging if that assertion regresses.
            flipper.cancel()
            await turn.value
        } else {
            await turn.value
            XCTAssertFalse(flipper.isFlipping)
            controller.rootView = AnyView(Color.clear)
            await settle(window)
        }
        XCTAssertNil(flipper.capturedPageSize)
        XCTAssertNil(presenter.session)
        return references
    }

    private func removedPaperHost() async throws -> MemoryOwnerReferences {
        let model = GameModel(frozen: Game(seed: "memory-paper"), page: .briefing)
        let references = MemoryOwnerReferences()
        references.model = model
        let ready = expectation(description: "Nested content reached the shared paper presenter")
        let controller = UIHostingController(rootView: AnyView(
            Color.clear
                .paperPanel(isPresented: .constant(true)) {
                    Color.clear
                        .paperPanel(isPresented: .constant(true)) {
                            MemoryPaperProbe(model: model) { presenter in
                                references.panelPresenter = presenter
                                ready.fulfill()
                            }
                        }
                }
                .paperPanelHost()))
        references.controller = controller
        controller.safeAreaRegions = []
        let (window, previousKey) = try mount(controller, size: CGSize(width: 375, height: 667))
        defer { close(window, previousKey: previousKey) }
        await fulfillment(of: [ready], timeout: 3)
        XCTAssertEqual(references.panelPresenter?.entries.count, 2)
        controller.rootView = AnyView(Color.clear)
        await settle(window)
        XCTAssertTrue(references.panelPresenter?.entries.isEmpty ?? true)
        return references
    }

    private func dismantledStand() async throws -> MemoryOwnerReferences {
        let references = MemoryOwnerReferences()
        let coordinator = BookstoreSceneCoordinator(editions: BookEdition.shelf)
        let view = BookstoreSCNView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let controller = UIViewController()
        controller.view = view
        let (window, previousKey) = try mount(controller, size: view.bounds.size)
        defer { close(window, previousKey: previousKey) }
        let callbackOwner = NSObject()
        coordinator.install(in: view)
        coordinator.updateViewport(view.bounds.size)
        for focusSerial in 0...1 {
            coordinator.update(
                phase: .choosingBook, selectedEditionID: BookEdition.shelf[0].id,
                selectedObstacle: .none, unlockedObstaclesByBookID: [:],
                turnCommand: .init(serial: 0, selectedIndex: 0),
                focusCommand: .init(serial: focusSerial, editionID: BookEdition.shelf[0].id),
                returnFocusCommand: .init(serial: 0), isLiveBookPresented: false,
                shopCategory: .paper, shopItem: nil,
                shopPresentation: .init(currentIndex: 0, itemCount: 0, stampBalance: 0,
                                        owned: false, equipped: false, affordable: false, message: nil),
                shopDragOffset: nil, counterYaw: 0, counterForward: 0, counterSide: 0,
                cameraForward: 0, cameraSide: 0, reduceMotion: false,
                ambientMotionEnabled: false, debugCameraPosition: nil,
                onSelectEdition: { _ in }, onRequestBookFocus: { _ in },
                onSelectObstacle: { _ in }, onShowObstacleInfo: { _ in },
                onSelectShopCategory: { _ in }, onStepShopItem: { _ in },
                onBuyOrEquipShopItem: {}, onBookFocusChanged: { _ in },
                onTransitionFinished: { _ in })
        }
        view.updateFirstFrameReporting { _ = callbackOwner.hash }
        references.sceneCoordinator = coordinator
        references.scene = view.scene
        references.sceneView = view
        references.callbackOwner = callbackOwner
        // Real representable teardown occurs after the view has entered a
        // window. An SCNView that never entered UIKit's window lifecycle
        // is not equivalent to a removed menu on screen.
        await settle(window)
        view.reportNextRenderedFrame { _ = callbackOwner.hash }
        BookstoreSceneView.dismantleUIView(view, coordinator: coordinator)
        controller.view = UIView()
        await settle(window)
        XCTAssertFalse(view.isPlaying)
        XCTAssertFalse(view.rendersContinuously)
        XCTAssertNil(view.delegate)
        return references
    }

    private func retiredPreparedGame(seed: String) async -> MemoryOwnerReferences {
        let model = GameModel(resuming: Game(seed: seed), savesProgress: false)
        let references = MemoryOwnerReferences()
        references.model = model
        let ready = await model.prepareUpcomingPuzzle()
        XCTAssertNotNil(ready)
        XCTAssertTrue(model.hasPreparedPuzzle)
        XCTAssertTrue(model.abandonRun())
        XCTAssertFalse(model.hasPreparedPuzzle)
        return references
    }

    private func mount(_ controller: UIViewController, size: CGSize) throws -> (UIWindow, UIWindow?) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return (window, previousKey)
    }

    private func close(_ window: UIWindow, previousKey: UIWindow?) {
        window.isHidden = true
        window.rootViewController = nil
        previousKey?.makeKey()
    }

    private func settle(_ window: UIWindow) async {
        for _ in 0..<4 {
            window.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func drainUntilReleased(_ references: MemoryOwnerReferences) async {
        for _ in 0..<50 {
            if references.allReleased { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}

@MainActor
private final class MemoryOwnerReferences {
    weak var model: GameModel?
    weak var flipper: PageFlipper?
    weak var renderer: PageCurlRenderer?
    weak var anchor: UIView?
    weak var controller: UIViewController?
    weak var panelPresenter: PaperPanelPresenter?
    weak var sceneCoordinator: BookstoreSceneCoordinator?
    weak var scene: SCNScene?
    weak var sceneView: BookstoreSCNView?
    weak var callbackOwner: NSObject?

    var allReleased: Bool {
        model == nil && flipper == nil && renderer == nil && anchor == nil && controller == nil
            && panelPresenter == nil && sceneCoordinator == nil && scene == nil
            && sceneView == nil && callbackOwner == nil
    }
}

private struct MemoryPaperProbe: View {
    let model: GameModel
    let ready: (PaperPanelPresenter) -> Void
    @Environment(\.paperPanelPresenter) private var presenter

    var body: some View {
        Text(model.run.seed)
            .onAppear { if let presenter { ready(presenter) } }
    }
}

private struct MemoryPuzzleHost: View {
    @Bindable var model: GameModel
    let flipper: PageFlipper
    let presenter: MarkerInspectionPresenter

    var body: some View {
        BookView(flipper: flipper, showsChrome: false) {
            GameplayShell(model: model, controls: [], onTapBuff: { _ in },
                          inspectionPresenter: presenter) {
                if let puzzle = model.puzzle {
                    PuzzlePageView(model: model, puzzle: puzzle, isClockRunning: true)
                }
            }
        }
    }
}
