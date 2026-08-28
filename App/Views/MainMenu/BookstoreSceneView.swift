import SceneKit
import SwiftUI
import ProbablySudokuEngine

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
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        context.coordinator.install(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
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
