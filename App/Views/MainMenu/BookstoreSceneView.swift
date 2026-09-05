import SceneKit
import SwiftUI
import ProbablySudokuEngine

final class BookstoreSCNView: SCNView {
    var onViewportChange: ((CGSize) -> Void)?
    private var onFirstFrame: (() -> Void)?
    private var firstFrameObserver: BookstoreFirstFrameObserver?
    private var hasAppliedSceneUpdate = false
    private var hasReportedFirstFrame = false
    private var isSceneVisible = true

    /// Warm the actual destination once, then stop its hidden render loop while
    /// the studio camera moves. The prepared drawable survives the handoff.
    func updateRenderActivity(isSceneVisible: Bool) {
        self.isSceneVisible = isSceneVisible
        let shouldRender = isSceneVisible || !hasReportedFirstFrame
        isPlaying = shouldRender
        rendersContinuously = shouldRender
    }

    func updateFirstFrameReporting(_ callback: (() -> Void)?) {
        onFirstFrame = callback
        hasAppliedSceneUpdate = true
        guard !hasReportedFirstFrame else { return }
        guard callback != nil || !isSceneVisible else {
            firstFrameObserver?.invalidate()
            firstFrameObserver = nil
            delegate = nil
            return
        }
        if firstFrameObserver == nil {
            let observer = BookstoreFirstFrameObserver { [weak self] in
                guard let self, !self.hasReportedFirstFrame, self.window != nil,
                      self.bounds.width >= 100, self.bounds.height >= 100 else { return }
                self.hasReportedFirstFrame = true
                self.updateRenderActivity(isSceneVisible: self.isSceneVisible)
                self.firstFrameObserver?.invalidate()
                self.firstFrameObserver = nil
                self.delegate = nil
                self.onFirstFrame?()
                self.onFirstFrame = nil
            }
            firstFrameObserver = observer
            delegate = observer
        }
        updateFirstFrameViewport()
    }

    func stopFirstFrameReporting() {
        firstFrameObserver?.invalidate()
        firstFrameObserver = nil
        onFirstFrame = nil
        delegate = nil
        onViewportChange = nil
    }

    private func updateFirstFrameViewport() {
        let eligible = hasAppliedSceneUpdate && window != nil
            && bounds.width >= 100 && bounds.height >= 100
        firstFrameObserver?.updateViewport(eligible ? bounds.size : .zero)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let screen = window?.screen {
            // SceneKit can retain the 1x drawable created during the initial
            // SwiftUI sizing pass. Force the Metal surface to native device
            // scale once the view reaches its real window.
            contentScaleFactor = screen.scale
        }
        updateFirstFrameViewport()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onViewportChange?(bounds.size)
        updateFirstFrameViewport()
    }
}

/// SceneKit invokes its delegate on its render thread. Keep the small readiness
/// state behind a lock; UIKit and the final SwiftUI callback stay on MainActor.
private final class BookstoreFirstFrameObserver: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let onReady: @MainActor () -> Void
    private var viewport = CGSize.zero
    private var generation = 0
    private var firstRenderedTime: TimeInterval?
    private var awaitingCompletion = false
    private var finished = false
    private var invalidated = false

    init(onReady: @escaping @MainActor () -> Void) {
        self.onReady = onReady
    }

    func updateViewport(_ size: CGSize) {
        lock.lock()
        defer { lock.unlock() }
        guard !invalidated, size != viewport else { return }
        viewport = size
        generation += 1
        firstRenderedTime = nil
        awaitingCompletion = false
        finished = false
    }

    func invalidate() {
        lock.lock()
        invalidated = true
        generation += 1
        lock.unlock()
    }

    func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene,
                  atTime time: TimeInterval) {
        lock.lock()
        guard !invalidated, !finished, !awaitingCompletion,
              viewport.width >= 100, viewport.height >= 100 else {
            lock.unlock()
            return
        }
        if renderer.commandQueue != nil {
            guard let texture = renderer.currentRenderPassDescriptor.colorAttachments[0].texture,
                  texture.width >= Int(viewport.width), texture.height >= Int(viewport.height) else {
                lock.unlock()
                return
            }
        }
        guard let firstRenderedTime else {
            self.firstRenderedTime = time
            lock.unlock()
            return
        }
        guard time > firstRenderedTime else {
            lock.unlock()
            return
        }
        awaitingCompletion = true
        let token = generation
        lock.unlock()

        // SCNSceneRenderer does not expose its current MTLCommandBuffer. Wait
        // for a following real frame before submitting a marker to its serial
        // queue: the prior full-sized scene frame is then already submitted.
        // Completion fences that frame without sleeping or blocking a thread.
        if let queue = renderer.commandQueue {
            guard let marker = queue.makeCommandBuffer() else {
                completed(token: token, succeeded: false)
                return
            }
            marker.label = "Bookstore first-frame readiness"
            marker.addCompletedHandler { [weak self] commandBuffer in
                self?.completed(token: token, succeeded: commandBuffer.status == .completed)
            }
            marker.commit()
        } else {
            // A non-Metal renderer has no GPU completion API. Its completed
            // render delegate is still a real frame, never a layout callback.
            completed(token: token, succeeded: true)
        }
    }

    private func completed(token: Int, succeeded: Bool) {
        lock.lock()
        guard !invalidated, !finished, token == generation else {
            lock.unlock()
            return
        }
        guard succeeded else {
            firstRenderedTime = nil
            awaitingCompletion = false
            lock.unlock()
            return
        }
        finished = true
        lock.unlock()

        Task { @MainActor [weak self] in
            guard let self, self.isCurrent(token: token) else { return }
            self.onReady()
        }
    }

    private func isCurrent(token: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !invalidated && finished && token == generation
    }
}

struct BookstoreSceneView: UIViewRepresentable {
    var phase: BookstoreScenePhase
    var editions: [BookEdition]
    var selectedEditionID: String
    var selectedObstacle: Obstacle
    var unlockedObstacleRawValue: Int
    var turnCommand: BookstoreTurnCommand
    var focusCommand: BookstoreFocusCommand
    var returnFocusCommand: BookstoreReturnFocusCommand
    var isLiveBookPresented: Bool
    var shopCategory: CosmeticCategory
    var shopItem: CosmeticItem?
    var shopPresentation: BookstoreShopPresentation
    var shopDragOffset: CGFloat?
    var counterYaw: Double
    var counterForward: Double
    var counterSide: Double
    var cameraForward: Double
    var cameraSide: Double
    var reduceMotion: Bool
    var debugCameraPosition: BookstoreDebugCameraPosition?
    var onSelectEdition: (String) -> Void
    var onRequestBookFocus: (String) -> Void
    var onSelectObstacle: (Obstacle) -> Void
    var onShowObstacleInfo: (Obstacle) -> Void
    var onSelectShopCategory: (CosmeticCategory) -> Void
    var onStepShopItem: (Int) -> Void
    var onBuyOrEquipShopItem: () -> Void
    var onBookFocusChanged: (BookstoreBookFocus) -> Void
    var onTransitionFinished: (BookstoreScenePhase) -> Void
    var onFirstFrame: (() -> Void)? = nil
    var isSceneVisible = true

    func makeCoordinator() -> BookstoreSceneCoordinator {
        BookstoreSceneCoordinator(editions: editions)
    }

    func makeUIView(context: Context) -> SCNView {
        // A zero-sized CAMetalLayer can keep a zero drawable after SwiftUI's
        // first layout pass on current iOS runtimes. Seed a real drawable; the
        // GeometryReader immediately resizes it to the device bounds.
        let view = BookstoreSCNView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.onViewportChange = { [weak coordinator = context.coordinator] size in
            coordinator?.updateViewport(size)
        }
        context.coordinator.install(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.updateViewport(view.bounds.size)
        (view as? BookstoreSCNView)?.updateRenderActivity(isSceneVisible: isSceneVisible)
        view.setNeedsDisplay()
        context.coordinator.update(
            phase: phase,
            selectedEditionID: selectedEditionID,
            selectedObstacle: selectedObstacle,
            unlockedObstacleRawValue: unlockedObstacleRawValue,
            turnCommand: turnCommand,
            focusCommand: focusCommand,
            returnFocusCommand: returnFocusCommand,
            isLiveBookPresented: isLiveBookPresented,
            shopCategory: shopCategory,
            shopItem: shopItem,
            shopPresentation: shopPresentation,
            shopDragOffset: shopDragOffset,
            counterYaw: counterYaw,
            counterForward: counterForward,
            counterSide: counterSide,
            cameraForward: cameraForward,
            cameraSide: cameraSide,
            reduceMotion: reduceMotion,
            debugCameraPosition: debugCameraPosition,
            onSelectEdition: onSelectEdition,
            onRequestBookFocus: onRequestBookFocus,
            onSelectObstacle: onSelectObstacle,
            onShowObstacleInfo: onShowObstacleInfo,
            onSelectShopCategory: onSelectShopCategory,
            onStepShopItem: onStepShopItem,
            onBuyOrEquipShopItem: onBuyOrEquipShopItem,
            onBookFocusChanged: onBookFocusChanged,
            onTransitionFinished: onTransitionFinished
        )
        (view as? BookstoreSCNView)?.updateFirstFrameReporting(onFirstFrame)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: BookstoreSceneCoordinator) {
        (view as? BookstoreSCNView)?.stopFirstFrameReporting()
        view.isPlaying = false
        view.rendersContinuously = false
    }
}
