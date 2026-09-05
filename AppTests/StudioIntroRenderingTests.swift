import XCTest
import Metal
import SceneKit
import UIKit
@testable import ProbablySudoku

/// Exercise the real first-frame observer and render-activity gate with a tiny
/// scene. No bookstore assets, navigation state, fixed sleeps, or FPS targets.
@MainActor
final class StudioIntroRenderingTests: XCTestCase {
    func testCoveredSceneWarmsOncePausesThenResumesWithoutRepeatingReadiness() async throws {
        let fixture = try SceneFixture()
        defer { fixture.close() }
        let view = fixture.view
        let ready = expectation(description: "Covered destination completed its first GPU-ready frame")
        ready.assertForOverFulfill = true
        var callbackCount = 0
        var wasPausedBeforeCallback = false

        view.updateRenderActivity(isSceneVisible: false)
        view.updateFirstFrameReporting {
            callbackCount += 1
            wasPausedBeforeCallback = !view.isPlaying && !view.rendersContinuously
            // The owner's covered-state update must also be safe from inside
            // the callback, not restart an already-warmed destination.
            view.updateRenderActivity(isSceneVisible: false)
            ready.fulfill()
        }
        XCTAssertTrue(view.isPlaying, "A covered scene still needs its initial real draw")
        XCTAssertTrue(view.rendersContinuously)
        XCTAssertEqual(callbackCount, 0, "Registration and layout are not rendered frames")

        let firstFrames = FrameRelay(forwardingTo: try XCTUnwrap(view.delegate))
        view.delegate = firstFrames
        fixture.mount()
        await fulfillment(of: [ready], timeout: 10)

        XCTAssertEqual(callbackCount, 1)
        XCTAssertGreaterThanOrEqual(firstFrames.distinctFrameCount, 2)
        XCTAssertTrue(firstFrames.sawMetalQueue, "This test must exercise GPU completion, not the fallback")
        XCTAssertTrue(wasPausedBeforeCallback)
        XCTAssertFalse(view.isPlaying)
        XCTAssertFalse(view.rendersContinuously)
        XCTAssertNil(view.delegate, "The one-shot readiness observer must be released")
        XCTAssertTrue(view.scene === fixture.scene, "Pausing must retain the prepared destination")
        XCTAssertTrue(view.pointOfView === fixture.camera)

        for _ in 0..<3 {
            view.updateRenderActivity(isSceneVisible: false)
            view.updateFirstFrameReporting { callbackCount += 1 }
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
        XCTAssertFalse(view.isPlaying, "Unrelated covered updates must not restart the loop")
        XCTAssertFalse(view.rendersContinuously)
        XCTAssertEqual(callbackCount, 1)
        XCTAssertNil(view.delegate)

        let resumed = expectation(description: "The same prepared scene renders again when revealed")
        let resumedFrames = FrameRelay(fulfilling: resumed, afterFrames: 3)
        view.delegate = resumedFrames
        fixture.uncover()
        view.updateRenderActivity(isSceneVisible: true)
        XCTAssertTrue(view.isPlaying)
        XCTAssertTrue(view.rendersContinuously)
        await fulfillment(of: [resumed], timeout: 10)

        XCTAssertGreaterThanOrEqual(resumedFrames.distinctFrameCount, 3)
        XCTAssertEqual(callbackCount, 1, "Revealing the destination cannot replay its first-frame callback")
        XCTAssertTrue(view.scene === fixture.scene)
        view.updateRenderActivity(isSceneVisible: false)
        XCTAssertFalse(view.isPlaying)
        XCTAssertFalse(view.rendersContinuously)
    }

    func testStoppingReportingInvalidatesStaleFrameCallbacksAndAllowsFreshWarmup() async throws {
        let fixture = try SceneFixture()
        defer { fixture.close() }
        let view = fixture.view
        var cancelledCallbackCount = 0
        var viewportCallbackCount = 0
        view.onViewportChange = { _ in viewportCallbackCount += 1 }
        view.updateRenderActivity(isSceneVisible: false)
        view.updateFirstFrameReporting { cancelledCallbackCount += 1 }
        let cancelledObserver = try XCTUnwrap(view.delegate)

        view.stopFirstFrameReporting()
        XCTAssertNil(view.delegate)
        XCTAssertNil(view.onViewportChange)
        XCTAssertTrue(view.scene === fixture.scene)

        // Forward genuine subsequent frames to the old observer as if render
        // callbacks were already queued at teardown. Invalidation must make
        // them harmless, even while that observer is still retained here.
        let subsequentFrames = expectation(description: "Frames continue after cancelling the old observer")
        let staleRelay = FrameRelay(forwardingTo: cancelledObserver,
                                    fulfilling: subsequentFrames, afterFrames: 3)
        view.delegate = staleRelay
        view.updateRenderActivity(isSceneVisible: true)
        fixture.mount()
        await fulfillment(of: [subsequentFrames], timeout: 10)
        XCTAssertEqual(cancelledCallbackCount, 0)
        XCTAssertEqual(viewportCallbackCount, 0)
        XCTAssertTrue(staleRelay.sawMetalQueue)

        let freshReady = expectation(description: "A new registration completes its own warmup")
        freshReady.assertForOverFulfill = true
        var freshCallbackCount = 0
        view.updateRenderActivity(isSceneVisible: false)
        view.updateFirstFrameReporting {
            freshCallbackCount += 1
            freshReady.fulfill()
        }
        await fulfillment(of: [freshReady], timeout: 10)
        XCTAssertEqual(cancelledCallbackCount, 0)
        XCTAssertEqual(freshCallbackCount, 1)
        XCTAssertFalse(view.isPlaying)
        XCTAssertFalse(view.rendersContinuously)
        XCTAssertTrue(view.scene === fixture.scene)

        view.stopFirstFrameReporting()
        view.stopFirstFrameReporting()
        XCTAssertNil(view.delegate)
        XCTAssertNil(view.onViewportChange)
        XCTAssertFalse(view.isPlaying)
        XCTAssertFalse(view.rendersContinuously)
    }

    @MainActor
    private final class SceneFixture {
        let scene = SCNScene()
        let camera = SCNNode()
        let view = BookstoreSCNView(frame: CGRect(x: 12, y: 80, width: 160, height: 180))
        private let window: UIWindow
        private weak var previousKeyWindow: UIWindow?
        private let cover = UIView()

        init() throws {
            try XCTSkipIf(MTLCreateSystemDefaultDevice() == nil, "A Metal-capable test host is required")
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windowScene = try XCTUnwrap(
                scenes.first { $0.activationState == .foregroundActive } ?? scenes.first,
                "Hosted rendering tests require a UIWindowScene"
            )
            previousKeyWindow = windowScene.windows.first { $0.isKeyWindow }
            window = UIWindow(windowScene: windowScene)
            window.frame = windowScene.coordinateSpace.bounds
            window.windowLevel = .alert + 1
            let controller = UIViewController()
            controller.view = UIView(frame: window.bounds)
            controller.view.backgroundColor = .black
            window.rootViewController = controller

            camera.camera = SCNCamera()
            camera.position = SCNVector3(0, 0, 4)
            scene.rootNode.addChildNode(camera)
            let geometry = SCNBox(width: 1, height: 1, length: 0.2, chamferRadius: 0)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.orange
            geometry.firstMaterial = material
            scene.rootNode.addChildNode(SCNNode(geometry: geometry))
            view.scene = scene
            view.pointOfView = camera
            view.backgroundColor = .black
            view.antialiasingMode = .none
            controller.view.addSubview(view)
            cover.frame = view.frame
            cover.backgroundColor = .black
            controller.view.addSubview(cover)
        }

        func mount() {
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            view.layoutIfNeeded()
            view.setNeedsDisplay()
        }

        func uncover() {
            cover.removeFromSuperview()
        }

        func close() {
            view.stopFirstFrameReporting()
            view.isPlaying = false
            view.rendersContinuously = false
            view.scene = nil
            view.pointOfView = nil
            view.removeFromSuperview()
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
    }

    /// SceneKit delivers this on its render thread. Forward to the production
    /// observer while collecting only event counts, never a timing/FPS target.
    private final class FrameRelay: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private let downstream: (any SCNSceneRendererDelegate)?
        private let expectation: XCTestExpectation?
        private let requiredFrames: Int
        private var previousTime: TimeInterval?
        private var frameCount = 0
        private var metalQueueSeen = false
        private var fulfilled = false

        init(forwardingTo downstream: (any SCNSceneRendererDelegate)? = nil,
             fulfilling expectation: XCTestExpectation? = nil, afterFrames: Int = 0) {
            self.downstream = downstream
            self.expectation = expectation
            requiredFrames = afterFrames
        }

        var distinctFrameCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return frameCount
        }

        var sawMetalQueue: Bool {
            lock.lock()
            defer { lock.unlock() }
            return metalQueueSeen
        }

        func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene,
                      atTime time: TimeInterval) {
            lock.lock()
            if previousTime != time {
                previousTime = time
                frameCount += 1
            }
            metalQueueSeen = metalQueueSeen || renderer.commandQueue != nil
            let shouldFulfill = expectation != nil && !fulfilled && frameCount >= requiredFrames
            if shouldFulfill { fulfilled = true }
            lock.unlock()

            downstream?.renderer?(renderer, didRenderScene: scene, atTime: time)
            if shouldFulfill { expectation?.fulfill() }
        }
    }
}
