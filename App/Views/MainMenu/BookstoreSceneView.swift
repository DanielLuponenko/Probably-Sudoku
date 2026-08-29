import SceneKit
import SwiftUI
import ProbablySudokuEngine

private final class BookstoreSCNView: SCNView {
    var onViewportChange: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onViewportChange?(bounds.size)
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
    var onSelectObstacle: (Obstacle) -> Void
    var onShowObstacleInfo: (Obstacle) -> Void
    var onSelectShopCategory: (CosmeticCategory) -> Void
    var onStepShopItem: (Int) -> Void
    var onBuyOrEquipShopItem: () -> Void
    var onBookFocusChanged: (String?) -> Void
    var onTransitionFinished: (BookstoreScenePhase) -> Void

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
        view.isPlaying = true
        view.setNeedsDisplay()
        context.coordinator.update(
            phase: phase,
            selectedEditionID: selectedEditionID,
            selectedObstacle: selectedObstacle,
            unlockedObstacleRawValue: unlockedObstacleRawValue,
            turnCommand: turnCommand,
            focusCommand: focusCommand,
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
            onSelectObstacle: onSelectObstacle,
            onShowObstacleInfo: onShowObstacleInfo,
            onSelectShopCategory: onSelectShopCategory,
            onStepShopItem: onStepShopItem,
            onBuyOrEquipShopItem: onBuyOrEquipShopItem,
            onBookFocusChanged: onBookFocusChanged,
            onTransitionFinished: onTransitionFinished
        )
    }
}
