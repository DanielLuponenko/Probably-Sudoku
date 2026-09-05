import SceneKit
import SwiftUI
import UIKit
import ProbablySudokuEngine

/// SceneKit's field of view is vertical; horizontal framing falls out of
/// vertical FOV combined with the view's aspect ratio, not its point width.
/// A viewport that is merely smaller while keeping the baseline's aspect
/// ratio (iPhone mini-class devices) must not be widened just because its
/// width in points is smaller than the baseline's.
enum ShopCameraFraming {
    static let baselineViewport = CGSize(width: 402, height: 874)
    static let baselineFieldOfView: CGFloat = 42

    private static var baselineAspect: CGFloat {
        baselineViewport.width / baselineViewport.height
    }

    /// Widens `heightAdjustedFieldOfView` (the pose after the existing
    /// short-height overlay-clearance term has already run) only enough to
    /// keep the horizontal field of view at least as wide as the baseline's,
    /// when the live usable aspect ratio is narrower than baseline. Wider or
    /// equal aspects, including baseline itself, pass through unchanged.
    /// `usableWidth` is the horizontal span actually available for the shop
    /// composition; callers should subtract any fixed horizontal overlay
    /// insets from the raw viewport width before calling, rather than
    /// branching on device identity.
    static func aspectAwareFieldOfView(
        heightAdjustedFieldOfView: CGFloat,
        usableWidth: CGFloat,
        viewportHeight: CGFloat,
        ceiling: CGFloat = 58
    ) -> CGFloat {
        guard usableWidth > 0, viewportHeight > 0 else {
            return min(heightAdjustedFieldOfView, ceiling)
        }
        let liveAspect = usableWidth / viewportHeight
        guard liveAspect < baselineAspect else {
            return min(heightAdjustedFieldOfView, ceiling)
        }
        let baselineHalfV = baselineFieldOfView * .pi / 360
        let baselineHorizontalHalfTan = baselineAspect * tan(baselineHalfV)
        let neededHalfV = atan(baselineHorizontalHalfTan / liveAspect)
        let neededFieldOfView = neededHalfV * 360 / .pi
        return min(max(heightAdjustedFieldOfView, neededFieldOfView), ceiling)
    }
}

/// Stable keys for the finite catalog of baked shop sample textures.
enum ShopSampleTextureCacheKey {
    static func paperStock(skinID: String, label: String, size: CGSize) -> String {
        "\(skinID)|\(label)|\(Int(size.width))x\(Int(size.height))"
    }

    static func gridRule(skinID: String, size: CGSize) -> String {
        "\(skinID)|\(Int(size.width))x\(Int(size.height))"
    }
}

@MainActor
final class BookstoreSceneCoordinator: NSObject, UIGestureRecognizerDelegate {
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let cameraTarget = SCNNode()
    private let standRoot = SCNNode()
    private let shopRoot = SCNNode()
    private let shopWallRoot = SCNNode()
    private let roomAmbientLight = SCNLight()
    private let roomWarmLight = SCNLight()
    private let standKeyLight = SCNLight()
    private let roomCoolFillLight = SCNLight()
    private var practicalLights: [SCNLight] = []
    private let shopPendantLight = SCNLight()
    private let focusedBookLight = SCNLight()
    private let focusedBookLightNode = SCNNode()
    private let editions: [BookEdition]
    private var editionNodes: [String: SCNNode] = [:]
    private var editionBookNodes: [String: SCNNode] = [:]
    private var coverMaterials: [String: SCNMaterial] = [:]
    private var obstacleTabNodes: [String: [Int: SCNNode]] = [:]
    private var obstacleTabMaterialCache: [String: SCNMaterial] = [:]
    private var sharedMaterials: [String: SCNMaterial] = [:]
    private var shelfSpineMaterials: [String: SCNMaterial] = [:]
    private var shelfBookGeometries: [String: SCNGeometry] = [:]
    private var shopDrawerNodes: [CosmeticCategory: SCNNode] = [:]
    private var shopSampleNodes: [CosmeticCategory: SCNNode] = [:]
    private var shopTurntableNodes: [CosmeticCategory: SCNNode] = [:]
    private var shopTurntableRingMaterials: [CosmeticCategory: SCNMaterial] = [:]
    private var shopSampleBasePositions: [CosmeticCategory: SCNVector3] = [:]
    private var shopPriceMaterials: [CosmeticCategory: SCNMaterial] = [:]
    private var shopDrawerLabelMaterials: [CosmeticCategory: SCNMaterial] = [:]
    private var shopNeighborMaterials: [SCNMaterial] = []
    private var shopNeighborNodes: [SCNNode] = []
    private var shopPaperMaterial: SCNMaterial?
    private var shopPaperBandMaterial: SCNMaterial?
    private var shopPaperTopMaterial: SCNMaterial?
    private var shopPaperStackNode: SCNNode?
    private var shopPaperRollNode: SCNNode?
    private var shopPaperRollMaterial: SCNMaterial?
    private var shopPaperIsUtilityRoll = false
    private var shopBoardMaterial: SCNMaterial?
    private var shopBoardRuleMaterial: SCNMaterial?
    private var shopBoardInternalRules: [SCNNode] = []
    private var shopNumberGlyphNodes: [SCNNode] = []
    private var shopNumberGlyphMaterials: [SCNMaterial] = []
    private var shopNumberEffectParticles: SCNParticleSystem?
    private var shopNumberEffectEmitterNode: SCNNode?
    private var shopNumberFlameNodes: [SCNNode] = []
    private var shopNumberFinish: NumberFinish = .press
    private var shopBoardFinish: BoardFinish = .printed
    private var shopMeshyTurntablePrototype: SCNNode?
    private var didLoadShopMeshyTurntable = false
    private var shopMeshyBoardPrototypes: [String: SCNNode] = [:]
    private var shopMeshyPropPrototypes: [String: SCNNode] = [:]
    private var shopMeshyPendantPrototype: SCNNode?
    private var shopMeshyPictureLightPrototype: SCNNode?
    private var shopPictureLights: [SCNLight] = []
    // Audited directly from the authored Meshy meshes. Emitter coordinates
    // are in each fixture's mesh1 object space.
    private let meshyPendantBulbCenter = SCNVector3(0, -0.857, 0.020)
    private let meshyPendantBulbHalfExtents = SCNVector3(0.135, 0.105, 0.115)
    private let meshyPendantLightOrigin = SCNVector3(0, -0.946, 0.020)
    private let meshyPictureLightDiffuserCenter = SCNVector3(0, 0, 0.183)
    private let meshyPictureLightDiffuserHalfExtents = SCNVector3(0.685, 0.075, 0.035)
    private let meshyPictureLightOrigin = SCNVector3(0, 0, 0.220)
    private weak var importedShopCounter: SCNNode?
    private weak var shopBoardShelfNode: SCNNode?
    private weak var shopBoardDisplayNode: SCNNode?
    private var shopBoardDisplayHomePosition: SCNVector3?
    private var shopBoardDisplayTargetSize: Float = 0
    // Approved shop dressing, captured from the placement pass. These values
    // deliberately live in source: they are not per-device preferences.
    private let approvedBoardShelfOffset = SCNVector3(0, 0.048, 0)
    private let approvedBoardShelfScale: Float = 0.38
    private let approvedBoardPlaqueOffset = SCNVector3(0.016, 0.040, 0)
    private var importedShopCounterSourceBounds: MeshyAssetBounds?
    private var importedShopCounterBasePosition: SCNVector3?
    private var appliedCounterYaw: Double?
    private var appliedCounterForward: Double?
    private var appliedCounterSide: Double?
    private var appliedCameraForward: Double?
    private var appliedCameraSide: Double?
    private var cameraForwardOffset: Double = 0
    private var cameraSideOffset: Double = 0
    private var shopFlameCrownTextureCache: UIImage?
    private var shopPaperStockTextureCache: [String: UIImage] = [:]
    private var shopGridRuleTextureCache: [String: UIImage] = [:]
    private var shopBoardLabelTextureCache: [String: UIImage] = [:]
    private var shopDustSystem: SCNParticleSystem?
    private var shopDustEmitterNode: SCNNode?
    private weak var sceneView: SCNView?

    private var currentPhase: BookstoreScenePhase?
    private var lastTurnSerial = -1
    private var lastFocusSerial = -1
    private var lastReturnFocusSerial = -1
    private var selectedIndex = 0
    private var panStartAngle: Float = 0
    private var boardPanStartAngle: Float = 0
    private var shopPanStartTransform = SCNMatrix4Identity
    private var reduceMotion = false
    private var selectedObstacle: Obstacle = .none
    private var unlockedObstacleRawValue = Obstacle.none.rawValue
    private var onSelectEdition: ((String) -> Void)?
    private var onRequestBookFocus: ((String) -> Void)?
    private var onSelectObstacle: ((Obstacle) -> Void)?
    private var onShowObstacleInfo: ((Obstacle) -> Void)?
    private var onSelectShopCategory: ((CosmeticCategory) -> Void)?
    private var onStepShopItem: ((Int) -> Void)?
    private var onBuyOrEquipShopItem: (() -> Void)?
    private var onBookFocusChanged: ((BookstoreBookFocus) -> Void)?
    private var onTransitionFinished: ((BookstoreScenePhase) -> Void)?
    private var focusedBook: FocusedBook?
    // A Book leaves the stand during the focus transition. Lock its rotation
    // from the first tap through the return animation so the remaining Books
    // never turn behind the selected cover.
    private var isStandRotationLocked = false
    private var focusGeneration = 0
    private var cameraGeneration = 0
    private var selectedShopCategory: CosmeticCategory = .paper
    private var selectedShopItemID: String?
    private var selectedShopPresentation: BookstoreShopPresentation?
    private var appliedShopDragOffset: CGFloat?
    private var viewportSize = CGSize.zero

    private struct FocusedBook {
        let id: String
        let book: SCNNode
        let originParent: SCNNode
        let originTransform: simd_float4x4
    }

    private struct CameraPose {
        let position: SCNVector3
        let target: SCNVector3
        let fieldOfView: CGFloat
    }

    private struct MeshyAssetBounds {
        let minimum: SCNVector3
        let maximum: SCNVector3

        var width: Float { maximum.x - minimum.x }
        var height: Float { maximum.y - minimum.y }
        var depth: Float { maximum.z - minimum.z }
        var centerX: Float { (minimum.x + maximum.x) * 0.5 }
    }

    // The shop remains a counter on the right side of the same aisle. Its
    // wider arrival pose frames the complete imported stand, rather than
    // cropping it into a product close-up.
    private let storePose = CameraPose(
        position: SCNVector3(0, 4.79, 13.65),
        target: SCNVector3(0, 2.44, -7.15),
        fieldOfView: 42
    )
    private let standPose = CameraPose(
        position: SCNVector3(1.65, 5.59, 1.10),
        target: SCNVector3(0, 3.12, -7.55),
        fieldOfView: 37
    )
    private let shopPose = CameraPose(
        // The reference is a portrait merchandising composition: the pendant
        // nearly touches the top edge and the cabinet feet finish just above
        // the bottom edge. A tighter vertical field of view gives the real 3D
        // fixture that same presence without scaling or flattening the asset.
        position: SCNVector3(1.55, 3.62, 13.23),
        target: SCNVector3(3.62, 1.95, 8.62),
        fieldOfView: 39.25
    )
    private let standHomeAngle = Float(atan2(1.65, 8.65))
    // Four faces, each with a published Book in all three pockets.
    // Keep the same tier/face ordering so extraction uses the correct path.
    private let pocketSlots: [[Int?]] = [
        [0, 4, 8],
        [1, 5, 9],
        [2, 6, 10],
        [3, 7, 11]
    ]
    private let shelfTitles = [
        "QUIET GRID", "NINE ROOMS", "MISTAKES", "PUZZLES", "SEVEN",
        "LOGIC", "CERTAINTY", "FIGURES", "SQUARES", "NUMBERS",
        "MARGINS", "PENCIL", "ORDER", "GUESSES", "EMPTY CELL",
        "SUNDAY", "NUMBER CLUB", "METHODS", "ALMOST", "BOXES"
    ]

    init(editions: [BookEdition]) {
        self.editions = editions
        super.init()
        buildScene()
    }

    func install(in view: SCNView) {
        sceneView = view
        view.scene = scene
        view.pointOfView = cameraNode
        view.isOpaque = false
        view.backgroundColor = .clear
        // Native 3x output already resolves the small brass/grid edges well.
        // 4x MSAA made this full-screen 3D shop shade four samples per pixel;
        // 2x preserves edge quality while materially reducing fill cost.
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        #if DEBUG
        // Opt-in only: capture authoritative SceneKit FPS/draw-call/triangle
        // evidence without shipping a diagnostic overlay to players.
        view.showsStatistics = ProcessInfo.processInfo.arguments.contains("-shopPerfHUD")
        #endif
        // This scene mixes SceneKit transactions, physical light changes and
        // SwiftUI overlays. SceneKit does not reliably schedule the first or
        // intermediate frames for that combination when on-demand rendering
        // is enabled, which produced a black aisle and stepped camera travel.
        view.rendersContinuously = true
        view.isPlaying = true
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.accessibilityElementsHidden = true
        Task { @MainActor in
            await Task.yield()
            view.play(nil)
            view.setNeedsDisplay()
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
    }

    func updateViewport(_ size: CGSize) {
        guard size.width >= 100, size.height >= 100 else { return }
        guard abs(size.width - viewportSize.width) > 0.5
                || abs(size.height - viewportSize.height) > 0.5 else { return }
        viewportSize = size

        // The approved 402x874 composition is the baseline. Short phones keep
        // the exact overlay anchors, so widen only the physical camera enough
        // to keep the samples and their price cards clear of those controls.
        if currentPhase == .shopping {
            apply(resolvedShopPose)
        } else if currentPhase == .transitioningToShop {
            animateCamera(to: resolvedShopPose, destination: .shopping)
        }
    }

    func update(
        phase: BookstoreScenePhase,
        selectedEditionID: String,
        selectedObstacle: Obstacle,
        unlockedObstacleRawValue: Int,
        turnCommand: BookstoreTurnCommand,
        focusCommand: BookstoreFocusCommand,
        returnFocusCommand: BookstoreReturnFocusCommand,
        isLiveBookPresented: Bool,
        shopCategory: CosmeticCategory,
        shopItem: CosmeticItem?,
        shopPresentation: BookstoreShopPresentation,
        shopDragOffset: CGFloat?,
        counterYaw: Double,
        counterForward: Double,
        counterSide: Double,
        cameraForward: Double,
        cameraSide: Double,
        reduceMotion: Bool,
        debugCameraPosition: BookstoreDebugCameraPosition?,
        onSelectEdition: @escaping (String) -> Void,
        onRequestBookFocus: @escaping (String) -> Void,
        onSelectObstacle: @escaping (Obstacle) -> Void,
        onShowObstacleInfo: @escaping (Obstacle) -> Void,
        onSelectShopCategory: @escaping (CosmeticCategory) -> Void,
        onStepShopItem: @escaping (Int) -> Void,
        onBuyOrEquipShopItem: @escaping () -> Void,
        onBookFocusChanged: @escaping (BookstoreBookFocus) -> Void,
        onTransitionFinished: @escaping (BookstoreScenePhase) -> Void
    ) {
        let motionPreferenceChanged = self.reduceMotion != reduceMotion
        self.reduceMotion = reduceMotion
        shopDustSystem?.birthRate = reduceMotion ? 0 : 3
        self.onSelectEdition = onSelectEdition
        self.onRequestBookFocus = onRequestBookFocus
        self.onSelectObstacle = onSelectObstacle
        self.onShowObstacleInfo = onShowObstacleInfo
        self.onSelectShopCategory = onSelectShopCategory
        self.onStepShopItem = onStepShopItem
        self.onBuyOrEquipShopItem = onBuyOrEquipShopItem
        self.onBookFocusChanged = onBookFocusChanged
        self.onTransitionFinished = onTransitionFinished

        if self.selectedObstacle != selectedObstacle
            || self.unlockedObstacleRawValue != unlockedObstacleRawValue {
            self.selectedObstacle = selectedObstacle
            self.unlockedObstacleRawValue = unlockedObstacleRawValue
            updateObstacleTabs()
        }

        if let index = editions.firstIndex(where: { $0.id == selectedEditionID }) {
            selectedIndex = index
            updateBookHighlight(selectedID: selectedEditionID)
        }

        let shopSelectionChanged = selectedShopCategory != shopCategory || selectedShopItemID != shopItem?.id
        if shopSelectionChanged {
            selectedShopCategory = shopCategory
            selectedShopItemID = shopItem?.id
            updateShopSelection(category: shopCategory, item: shopItem, animated: currentPhase != nil)
        }
        if shopSelectionChanged || selectedShopPresentation != shopPresentation {
            selectedShopPresentation = shopPresentation
            if let shopItem {
                updateShopPresentation(category: shopCategory, item: shopItem, state: shopPresentation)
            }
        }
        if appliedShopDragOffset != shopDragOffset {
            let shouldSnap = appliedShopDragOffset != nil && shopDragOffset == nil
            appliedShopDragOffset = shopDragOffset
            updateShopDragOffset(shopDragOffset, shouldSnap: shouldSnap)
        }
        if appliedCounterYaw != counterYaw {
            appliedCounterYaw = counterYaw
            importedShopCounter?.eulerAngles.y = Float(counterYaw)
        }
        if appliedCounterForward != counterForward || appliedCounterSide != counterSide {
            appliedCounterForward = counterForward
            appliedCounterSide = counterSide
            if let basePosition = importedShopCounterBasePosition {
                importedShopCounter?.position = SCNVector3(
                    basePosition.x + Float(counterSide),
                    basePosition.y,
                    basePosition.z + Float(counterForward)
                )
            }
        }
        if appliedCameraForward != cameraForward {
            appliedCameraForward = cameraForward
            cameraForwardOffset = cameraForward
            if currentPhase == .shopping { apply(resolvedShopPose) }
        }
        if appliedCameraSide != cameraSide {
            appliedCameraSide = cameraSide
            cameraSideOffset = cameraSide
            if currentPhase == .shopping { apply(resolvedShopPose) }
        }

        if let debugCameraPosition {
            cameraNode.removeAllActions()
            setCamera(debugCameraPosition)
            currentPhase = phase
        } else if currentPhase != phase {
            currentPhase = phase
            react(to: phase)
        }

        if lastTurnSerial != turnCommand.serial {
            let shouldAnimate = lastTurnSerial >= 0
            lastTurnSerial = turnCommand.serial
            if phase == .store || phase == .transitioningToStore {
                orientStandForStore(animated: shouldAnimate && !reduceMotion)
            } else if focusedBook != nil {
                returnFocusedBook { [weak self] in
                    guard let self else { return }
                    self.rotateStand(to: turnCommand.selectedIndex, animated: shouldAnimate && !self.reduceMotion)
                }
            } else {
                rotateStand(to: turnCommand.selectedIndex, animated: shouldAnimate && !reduceMotion)
            }
        }

        if lastFocusSerial != focusCommand.serial {
            let shouldFocus = lastFocusSerial >= 0
            lastFocusSerial = focusCommand.serial
            if shouldFocus, phase == .choosingBook, focusedBook == nil {
                focusBook(id: focusCommand.editionID)
            }
        }
        if lastReturnFocusSerial != returnFocusCommand.serial {
            let shouldReturn = lastReturnFocusSerial >= 0
            lastReturnFocusSerial = returnFocusCommand.serial
            if shouldReturn {
                returnFocusedBook()
            }
        }
        // Hide the physical print only in the same SwiftUI update that installs
        // the matching interactive cover. It stays visible for the whole lift.
        focusedBook?.book.isHidden = isLiveBookPresented
        if motionPreferenceChanged {
            updateShopShowcaseMotion()
            if reduceMotion {
                // Birth rate alone leaves already-emitted sparks and the
                // 7±2-second dust motes moving, so clear both immediately.
                if let emitterNode = shopNumberEffectEmitterNode,
                   let sparks = shopNumberEffectParticles {
                    emitterNode.removeAllParticleSystems()
                    emitterNode.addParticleSystem(sparks)
                }
                if let dustEmitterNode = shopDustEmitterNode,
                   let dust = shopDustSystem {
                    dustEmitterNode.removeAllParticleSystems()
                    dustEmitterNode.addParticleSystem(dust)
                }
            }
        }
    }

    private func react(to phase: BookstoreScenePhase) {
        updateShopShowcaseMotion()
        switch phase {
        case .store:
            setRoomLighting(shopFocused: false, animated: false)
            apply(storePose)
            orientStandForStore(animated: false)
        case .choosingBook:
            setRoomLighting(shopFocused: false, animated: false)
            apply(standPose)
        case .transitioningToStand:
            setRoomLighting(shopFocused: false, animated: true)
            animateCamera(to: standPose, destination: .choosingBook)
            rotateStand(to: selectedIndex, animated: !reduceMotion)
        case .transitioningToStore:
            // Invalidate a physical tap still rotating toward its pocket.
            focusGeneration += 1
            if focusedBook == nil { isStandRotationLocked = false }
            let finish = { [weak self] in
                guard let self else { return }
                self.animateCamera(to: self.storePose, destination: .store)
                self.orientStandForStore(animated: !self.reduceMotion)
            }
            if focusedBook != nil { returnFocusedBook(completion: finish) }
            else { finish() }
        case .transitioningToShop:
            setRoomLighting(shopFocused: true, animated: true)
            setShopProductFocusLighting(false, animated: true)
            animateCamera(to: resolvedShopPose, destination: .shopping)
        case .shopping:
            setRoomLighting(shopFocused: true, animated: false)
            setShopProductFocusLighting(false, animated: false)
            apply(resolvedShopPose)
        case .transitioningShopToStore:
            setRoomLighting(shopFocused: false, animated: true)
            animateCamera(to: storePose, destination: .store)
            orientStandForStore(animated: !reduceMotion)
        }
    }

    private func setRoomLighting(shopFocused: Bool, animated: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated && !reduceMotion ? 1.2 : 0.01
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        // The shop's practical fixtures need highlight roll-off at the bulb,
        // brass trim and vellum instead of the hard white clipping produced by
        // the non-HDR room camera. Bloom is only the camera response around the
        // emissive fixture meshes; all illumination still comes from the three
        // fixture-mounted SCNLight children below.
        cameraNode.camera?.wantsHDR = shopFocused
        cameraNode.camera?.exposureOffset = shopFocused ? -0.12 : 0
        cameraNode.camera?.averageGray = shopFocused ? 0.20 : 0.18
        cameraNode.camera?.whitePoint = shopFocused ? 2.35 : 1.0
        cameraNode.camera?.bloomIntensity = shopFocused ? 0.10 : 0.12
        // Only the authored bulb/diffuser emitters cross this threshold. Gold
        // lettering and brass trim stay crisp instead of blooming like lamps.
        cameraNode.camera?.bloomThreshold = shopFocused ? 1.45 : 1.0
        cameraNode.camera?.bloomBlurRadius = shopFocused ? 6 : 6
        // Product focus is handled separately, so browsing opens bright.
        roomAmbientLight.intensity = shopFocused ? 330 : 285
        roomWarmLight.intensity = shopFocused ? 55 : 55
        roomCoolFillLight.intensity = shopFocused ? 24 : 80
        standKeyLight.intensity = shopFocused ? 15 : 30
        for practical in practicalLights {
            practical.intensity = shopFocused ? 7 : 8
        }
        SCNTransaction.commit()
    }

    private func setShopProductFocusLighting(_ focused: Bool, animated: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated && !reduceMotion ? 0.30 : 0.01
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        // Browsing uses the bright, warm shop composition. Selecting a board
        // transitions only the close-up to the quieter pool of light.
        roomAmbientLight.intensity = focused ? 230 : 330
        roomWarmLight.intensity = focused ? 38 : 55
        roomCoolFillLight.intensity = focused ? 18 : 24
        shopPendantLight.intensity = focused ? 22 : 34
        for pictureLight in shopPictureLights {
            pictureLight.intensity = focused ? 8 : 12
        }
        SCNTransaction.commit()
    }

    private func animateCamera(to pose: CameraPose, destination phase: BookstoreScenePhase) {
        cameraNode.removeAction(forKey: "bookstore-camera")
        cameraGeneration += 1
        let generation = cameraGeneration
        guard !reduceMotion else {
            apply(pose)
            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, self.cameraGeneration == generation else { return }
                self.onTransitionFinished?(phase)
            }
            return
        }

        // Begin from the pixels currently on screen. A second destination can
        // interrupt this transaction without snapping to the old model-layer
        // endpoint or exposing an unlit frame.
        cameraNode.position = cameraNode.presentation.position
        cameraTarget.position = cameraTarget.presentation.position
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.55
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = { [weak self] in
            Task { @MainActor in
                guard let self, self.cameraGeneration == generation else { return }
                self.onTransitionFinished?(phase)
            }
        }
        cameraNode.position = pose.position
        cameraTarget.position = pose.target
        cameraNode.camera?.fieldOfView = pose.fieldOfView
        SCNTransaction.commit()
    }

    private func apply(_ pose: CameraPose) {
        cameraNode.position = pose.position
        cameraTarget.position = pose.target
        cameraNode.camera?.fieldOfView = pose.fieldOfView
    }

    private func setCamera(_ debugPosition: BookstoreDebugCameraPosition) {
        switch debugPosition {
        case .stand(let progress):
            apply(interpolate(from: storePose, to: standPose, amount: CGFloat(progress)))
        case .shop(let progress):
            apply(interpolate(from: storePose, to: resolvedShopPose, amount: CGFloat(progress)))
        }
    }

    private var resolvedShopPose: CameraPose {
        guard viewportSize.height >= 100 else { return shopPose }
        let shortfall = max(0, 760 - viewportSize.height)
        let heightAdjustedFieldOfView = min(58, shopPose.fieldOfView + shortfall * 0.11)
        let fieldOfView = ShopCameraFraming.aspectAwareFieldOfView(
            heightAdjustedFieldOfView: heightAdjustedFieldOfView,
            usableWidth: viewportSize.width,
            viewportHeight: viewportSize.height
        )
        return CameraPose(
            position: cameraPosition(forwardOffset: cameraForwardOffset, sideOffset: cameraSideOffset),
            target: shopPose.target,
            fieldOfView: fieldOfView
        )
    }

    private func cameraPosition(forwardOffset: Double, sideOffset: Double) -> SCNVector3 {
        let direction = SCNVector3(
            shopPose.target.x - shopPose.position.x,
            shopPose.target.y - shopPose.position.y,
            shopPose.target.z - shopPose.position.z
        )
        let length = max(0.001, sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z))
        let amount = Float(forwardOffset) / length
        let horizontalLength = max(0.001, sqrt(direction.x * direction.x + direction.z * direction.z))
        // Keep the look target fixed while moving along the camera's horizontal
        // right axis, so the player can inspect either side of the counter.
        let sideAmount = Float(sideOffset) / horizontalLength
        return SCNVector3(
            shopPose.position.x + direction.x * amount + direction.z * sideAmount,
            shopPose.position.y + direction.y * amount,
            shopPose.position.z + direction.z * amount - direction.x * sideAmount
        )
    }

    private func interpolate(from start: CameraPose, to end: CameraPose, amount: CGFloat) -> CameraPose {
        let t = min(1, max(0, amount))
        return CameraPose(
            position: interpolate(start.position, end.position, t),
            target: interpolate(start.target, end.target, t),
            fieldOfView: start.fieldOfView + (end.fieldOfView - start.fieldOfView) * t
        )
    }

    private func interpolate(_ start: SCNVector3, _ end: SCNVector3, _ amount: CGFloat) -> SCNVector3 {
        let t = Float(min(1, max(0, amount)))
        return SCNVector3(
            start.x + (end.x - start.x) * t,
            start.y + (end.y - start.y) * t,
            start.z + (end.z - start.z) * t
        )
    }

    private func rotateStand(to index: Int, animated: Bool, completion: (() -> Void)? = nil) {
        guard !editions.isEmpty else { return }
        selectedIndex = wrapped(index)
        // Books never relocate. Selection turns the rigid carousel to the
        // face containing the edition in the mockup's fixed pocket table.
        let face = face(containing: selectedIndex) ?? 0
        let angle = standHomeAngle - Float(face) * (.pi / 2)
        standRoot.removeAction(forKey: "stand-turn")
        if animated {
            let current = standRoot.presentation.eulerAngles.y
            standRoot.eulerAngles.y = current
            let nearest = nearestEquivalent(angle, to: current)
            // A tap on a Book already facing the camera used to wait through
            // an invisible 0.42-second turn before the focus move began.
            guard abs(nearest - current) > 0.008 else {
                standRoot.eulerAngles.y = nearest
                updateBookHighlight(selectedID: editions[selectedIndex].id)
                completion?()
                return
            }
            let turn = SCNAction.rotateTo(x: 0, y: CGFloat(nearest), z: 0, duration: 0.42, usesShortestUnitArc: true)
            turn.timingMode = .easeInEaseOut
            standRoot.runAction(turn, forKey: "stand-turn") {
                Task { @MainActor in completion?() }
            }
        } else {
            standRoot.eulerAngles.y = angle
            completion?()
        }
        updateBookHighlight(selectedID: editions[selectedIndex].id)
    }

    private func orientStandForStore(animated: Bool) {
        // The wide aisle camera is centred, so the fourth face is square to
        // it. The x-offset correction used by the close camera must not leak
        // into this view or an adjacent book peeks into the empty pocket.
        // The approved home composition shows Volumes 1, 5 and 9 facing the
        // aisle from the first rendered frame.
        let angle: Float = 0
        standRoot.removeAction(forKey: "stand-turn")
        guard animated else {
            standRoot.eulerAngles.y = angle
            return
        }
        let current = standRoot.presentation.eulerAngles.y
        standRoot.eulerAngles.y = current
        let destination = nearestEquivalent(angle, to: current)
        let turn = SCNAction.rotateTo(x: 0, y: CGFloat(destination), z: 0,
                                      duration: 0.72, usesShortestUnitArc: true)
        turn.timingMode = .easeInEaseOut
        standRoot.runAction(turn, forKey: "stand-turn")
    }

    private func nearestEquivalent(_ target: Float, to current: Float) -> Float {
        var result = target
        while result - current > .pi { result -= 2 * .pi }
        while result - current < -.pi { result += 2 * .pi }
        return result
    }

    private func updateBookHighlight(selectedID: String) {
        for (_, node) in editionNodes {
            node.removeAction(forKey: "selection")
            // Selection is ink/light, not a spatial rearrangement. Every book
            // remains bolted into the same wire pocket for the entire scene.
            let scale = CGFloat(1)
            let action = SCNAction.scale(to: scale, duration: reduceMotion ? 0.01 : 0.2)
            action.timingMode = .easeOut
            node.runAction(action, forKey: "selection")
        }
    }

    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        switch currentPhase {
        case .choosingBook:
            guard focusedBook == nil, !isStandRotationLocked else { return }
            handleBookStandPan(gesture)
        case .shopping:
            handleShopProductPan(gesture)
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if currentPhase == .choosingBook, gestureRecognizer is UIPanGestureRecognizer {
            return focusedBook == nil && !isStandRotationLocked
        }
        if currentPhase == .shopping,
           let pan = gestureRecognizer as? UIPanGestureRecognizer {
            if let board = shopBoardDisplayNode, !board.isHidden {
                return true
            }
            let velocity = pan.velocity(in: pan.view)
            // UIKit can report zero before a slow drag establishes direction;
            // admit that case, but reject gestures already known to be vertical.
            guard abs(velocity.x) > 0.5 || abs(velocity.y) > 0.5 else { return true }
            return abs(velocity.x) > abs(velocity.y)
        }
        return true
    }

    private func handleBookStandPan(_ gesture: UIPanGestureRecognizer) {
        guard !editions.isEmpty, focusedBook == nil, !isStandRotationLocked else { return }
        switch gesture.state {
        case .began:
            standRoot.removeAction(forKey: "stand-turn")
            panStartAngle = standRoot.presentation.eulerAngles.y
            standRoot.eulerAngles.y = panStartAngle
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            standRoot.eulerAngles.y = panStartAngle + Float(translation.x) * 0.009
        case .ended, .cancelled, .failed:
            let faceStep = Float.pi / 2
            // Fast physical swipes may be coalesced into began + ended with
            // no changed callbacks. Derive the destination from the final
            // translation rather than whichever model angle happened to be
            // committed during intermediate frames.
            let finalAngle = panStartAngle + Float(gesture.translation(in: gesture.view).x) * 0.009
            let rawFace = Int(round((standHomeAngle - finalAngle) / faceStep))
            let face = wrappedFace(rawFace)
            if let index = firstEdition(on: face) {
                onSelectEdition?(editions[index].id)
                rotateStand(to: index, animated: !reduceMotion)
            }
        default:
            break
        }
    }

    private func handleShopProductPan(_ gesture: UIPanGestureRecognizer) {
        if let board = shopBoardDisplayNode, !board.isHidden {
            switch gesture.state {
            case .began:
                board.removeAction(forKey: "board-auto-spin")
                boardPanStartAngle = board.presentation.eulerAngles.y
                board.eulerAngles.y = boardPanStartAngle
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                if abs(translation.x) >= abs(translation.y) {
                    board.eulerAngles.y = boardPanStartAngle + Float(translation.x) * 0.012
                }
            case .ended, .cancelled, .failed:
                startBoardAutoRotation()
            default:
                break
            }
            return
        }

        guard let sample = shopSampleNodes[selectedShopCategory],
              let base = shopSampleBasePositions[selectedShopCategory]
        else { return }

        switch gesture.state {
        case .began:
            sample.removeAction(forKey: "shop-snap")
            sample.transform = sample.presentation.transform
            shopPanStartTransform = sample.transform
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            let clamped = max(-72, min(72, translation.x))
            sample.position = SCNVector3(
                shopPanStartTransform.m41 + Float(clamped) * 0.0032,
                shopPanStartTransform.m42,
                shopPanStartTransform.m43
            )
            sample.eulerAngles.z = -Float(clamped) * 0.0022
        case .ended, .cancelled, .failed:
            let translation = gesture.translation(in: gesture.view).x
            let velocity = gesture.velocity(in: gesture.view).x
            // A decisive flick wins over the shorter translation accumulated
            // before release; otherwise use the distance threshold.
            if abs(velocity) > 430 {
                onStepShopItem?(velocity < 0 ? 1 : -1)
            } else if abs(translation) > 34 {
                onStepShopItem?(translation < 0 ? 1 : -1)
            }
            let move = SCNAction.move(
                to: SCNVector3(base.x, base.y + 0.16, base.z),
                duration: reduceMotion ? 0.01 : 0.24
            )
            move.timingMode = .easeOut
            let rotate = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: reduceMotion ? 0.01 : 0.24, usesShortestUnitArc: true)
            rotate.timingMode = .easeOut
            sample.runAction(.group([move, rotate]), forKey: "shop-snap")
        default:
            break
        }
    }

    /// SwiftUI owns the transparent merchandise hit band so its visible
    /// controls remain reliable. Mirror that drag into the selected SceneKit
    /// sample so the physical object still follows the finger and snaps home.
    private func updateShopDragOffset(_ offset: CGFloat?, shouldSnap: Bool) {
        guard currentPhase == .shopping,
              let sample = shopSampleNodes[selectedShopCategory],
              let base = shopSampleBasePositions[selectedShopCategory]
        else { return }

        sample.removeAction(forKey: "shop-snap")
        if let offset {
            let clamped = max(-72, min(72, offset))
            sample.position = SCNVector3(
                base.x + Float(clamped) * 0.0032,
                base.y + 0.16,
                base.z
            )
            sample.eulerAngles.z = -Float(clamped) * 0.0022
        } else if shouldSnap {
            let move = SCNAction.move(
                to: SCNVector3(base.x, base.y + 0.16, base.z),
                duration: reduceMotion ? 0.01 : 0.24
            )
            move.timingMode = .easeOut
            let rotate = SCNAction.rotateTo(
                x: 0,
                y: 0,
                z: 0,
                duration: reduceMotion ? 0.01 : 0.24,
                usesShortestUnitArc: true
            )
            rotate.timingMode = .easeOut
            sample.runAction(.group([move, rotate]), forKey: "shop-snap")
        }
    }

    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        guard let view = sceneView else { return }
        let point = gesture.location(in: view)
        switch currentPhase {
        case .choosingBook:
            handleBookTap(at: point, in: view)
        case .shopping:
            handleShopTap(at: point, in: view)
        default:
            break
        }
    }

    private func handleBookTap(at point: CGPoint, in view: SCNView) {
        for result in view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue]) {
            var node: SCNNode? = result.node
            while let candidate = node {
                if let name = candidate.name,
                   let (editionID, obstacle) = obstacleHit(from: name),
                   focusedBook?.id == editionID {
                    if obstacle.rawValue <= unlockedObstacleRawValue {
                        onSelectObstacle?(obstacle)
                    } else {
                        onShowObstacleInfo?(obstacle)
                    }
                    return
                }
                if let name = candidate.name, name.hasPrefix("edition:"),
                   let index = editions.firstIndex(where: { name == "edition:\($0.id)" }) {
                    let id = editions[index].id
                    if focusedBook?.id == id {
                        returnFocusedBook()
                        return
                    }
                    guard focusedBook == nil, !isStandRotationLocked else { return }
                    isStandRotationLocked = true
                    focusGeneration += 1
                    let generation = focusGeneration
                    onSelectEdition?(id)
                    rotateStand(to: index, animated: !reduceMotion) { [weak self] in
                        guard let self, self.currentPhase == .choosingBook,
                              self.focusGeneration == generation else { return }
                        // SwiftUI resolves the saved obstacle before issuing the
                        // focus command, just as the accessible Select button does.
                        self.onRequestBookFocus?(id)
                    }
                    return
                }
                node = candidate.parent
            }
        }

        // A focused Book is a selection, not a modal screen. Tapping any
        // non-interactive part of the shop returns it to its exact pocket.
        // SwiftUI controls above the scene consume their own taps first, so
        // Back, arrows, obstacle ribbons, Open, settings, and popups retain
        // their existing actions.
        if focusedBook != nil {
            returnFocusedBook()
        }
    }

    private func handleShopTap(at point: CGPoint, in view: SCNView) {
        if let displayBoard = shopBoardDisplayNode, !displayBoard.isHidden {
            dismissShopBoard(displayBoard)
            return
        }
        for result in view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue]) {
            var node: SCNNode? = result.node
            while let candidate = node {
                if let name = candidate.name,
                   name.hasPrefix("shop-board-shelf:") {
                    configureShopBoardDisplay(from: candidate)
                    presentShopBoard()
                    return
                }
                if candidate.name == "shop-board-shelf" {
                    // The empty shelf backing is not merchandise. Only a hit
                    // on one of the eight real board bodies opens the plinth.
                    return
                }
                if candidate.name == "shop-action" {
                    onBuyOrEquipShopItem?()
                    return
                }
                if let name = candidate.name,
                   name.hasPrefix("shop-step:"),
                   let direction = Int(name.split(separator: ":").last ?? "0"), direction != 0 {
                    onStepShopItem?(direction)
                    return
                }
                if let name = candidate.name,
                   name.hasPrefix("shop-category:"),
                   let raw = name.split(separator: ":").last,
                   let category = CosmeticCategory(rawValue: String(raw)) {
                    onSelectShopCategory?(category)
                    return
                }
                node = candidate.parent
            }
        }
    }

    private func obstacleHit(from nodeName: String) -> (editionID: String, obstacle: Obstacle)? {
        let parts = nodeName.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3,
              parts[0] == "obstacle",
              let rawValue = Int(parts[2]),
              let obstacle = Obstacle(rawValue: rawValue)
        else { return nil }
        return (parts[1], obstacle)
    }

    private func focusBook(id: String) {
        guard currentPhase == .choosingBook,
              focusedBook == nil,
              let book = editionBookNodes[id],
              let originParent = book.parent,
              let view = sceneView,
              let cover = book.childNodes.first(where: {
                  $0.geometry is SCNPlane && $0.eulerAngles.y == 0
              }),
              let plane = cover.geometry as? SCNPlane
        else { return }

        isStandRotationLocked = true
        focusGeneration += 1
        let generation = focusGeneration

        let originTransform = book.simdTransform
        let pocketTransform = originParent.simdWorldTransform
        let worldTransform = book.simdWorldTransform
        // Measure the tilted Book's lowest corner in its actual wire pocket.
        // A larger/taller lower-tier volume needs more lift than the top one.
        let bounds = book.boundingBox
        let lowestPoint = [bounds.min.x, bounds.max.x].flatMap { x in
            [bounds.min.y, bounds.max.y].flatMap { y in
                [bounds.min.z, bounds.max.z].map { z in
                    book.convertPosition(SCNVector3(x, y, z), to: originParent).y
                }
            }
        }.min() ?? bounds.min.y
        let lift = BookstoreExtractionPath.liftDistance(lowestPoint: lowestPoint)
        let up = originParent.simdConvertVector(SIMD3<Float>(0, 1, 0), to: nil)
        let outward = originParent.simdConvertVector(SIMD3<Float>(0, 0, 1), to: nil)
        book.removeFromParentNode()
        scene.rootNode.addChildNode(book)
        book.simdWorldTransform = worldTransform
        setFocusCategory(on: book, enabled: true)

        focusedBook = FocusedBook(
            id: id,
            book: book,
            originParent: originParent,
            originTransform: originTransform
        )
        // Project the exact LiveBook canvas into the camera plane. Both views
        // use this destination, rather than a guessed shelf scale/offset.
        let layout = BookstoreSelectionLayout(viewport: viewportSize)
        let camera = cameraNode.presentation
        let depth = view.projectPoint(camera.convertPosition(SCNVector3(0, 0, -3), to: nil)).z
        let center = view.unprojectPoint(SCNVector3(
            Float(layout.coverCenter.x), Float(layout.coverCenter.y), depth
        ))
        let right = view.unprojectPoint(SCNVector3(
            Float(layout.coverCenter.x + layout.canvasSize.width * 0.5),
            Float(layout.coverCenter.y), depth
        ))
        let centerPosition = SIMD3<Float>(center.x, center.y, center.z)
        let rightPosition = SIMD3<Float>(right.x, right.y, right.z)
        let targetScale = SIMD3<Float>(repeating:
            2 * simd_distance(centerPosition, rightPosition) / Float(plane.width))
        let targetOrientation = camera.simdWorldOrientation
        let targetPosition = centerPosition
            - targetOrientation.act(cover.simdPosition * targetScale)
        let startPosition = book.simdPosition
        let startScale = book.simdScale
        let startOrientation = book.simdOrientation
        let path = BookstoreExtractionPath(
            origin: startPosition,
            lifted: startPosition + up * lift,
            destination: targetPosition,
            outward: outward,
            up: up
        )
        let tier = editions.firstIndex(where: { $0.id == id }).flatMap { index in
            pocketSlots.lazy.compactMap { $0.firstIndex(of: index) }.first
        } ?? 0
        var targetPose = BookstoreExtractionPose(transform: worldTransform)
        targetPose.position = targetPosition
        targetPose.orientation = targetOrientation
        targetPose.scale = targetScale
        let lowerPath = tier > 0 ? BookstoreLowerPocketPath(
            origin: BookstoreExtractionPose(transform: originTransform),
            destination: BookstoreExtractionPose(transform: simd_inverse(pocketTransform) * targetPose.transform),
            minimum: SIMD3(bounds.min.x, bounds.min.y, bounds.min.z),
            maximum: SIMD3(bounds.max.x, bounds.max.y, bounds.max.z)
        ) : nil
        let finish = { [weak self] in
            guard let self, self.focusGeneration == generation,
                  self.focusedBook?.id == id else { return }
            self.notifyBookFocus(.presented(id), generation: generation)
        }
        if reduceMotion {
            book.simdPosition = targetPosition
            book.simdScale = targetScale
            book.simdOrientation = targetOrientation
            finish()
        } else {
            notifyBookFocus(.extracting(id), generation: generation)
            let duration = lowerPath == nil ? BookstoreExtractionPath.duration : BookstoreLowerPocketPath.duration
            let extraction = SCNAction.customAction(duration: duration) { node, elapsed in
                let progress = Float(elapsed / duration)
                if let lowerPath {
                    node.simdWorldTransform = pocketTransform * lowerPath.pose(at: progress).transform
                    return
                }
                let presenting = path.presentationProgress(at: progress)
                node.simdPosition = path.position(at: progress)
                node.simdScale = simd_mix(startScale, targetScale, SIMD3(repeating: presenting))
                node.simdOrientation = simd_slerp(startOrientation, targetOrientation, presenting)
            }
            book.runAction(extraction, forKey: "book-extraction") {
                Task { @MainActor in finish() }
            }
        }
        setLighting(focused: true, bookID: id)
    }

    private func notifyBookFocus(_ focus: BookstoreBookFocus, generation: Int) {
        // Focus can begin in updateUIView (the accessible Select button).
        // Publishing synchronously there loses SwiftUI state updates and can
        // leave the physical book hidden with no interactive cover at all.
        Task { @MainActor [weak self] in
            guard let self, self.focusGeneration == generation else { return }
            self.onBookFocusChanged?(focus)
        }
    }

    private func returnFocusedBook(completion: (() -> Void)? = nil) {
        guard let focus = focusedBook else {
            isStandRotationLocked = false
            completion?()
            return
        }

        // Cancellation is synchronous: no queued extraction completion may
        // recreate a selected cover after Back or a background tap.
        focusGeneration += 1
        notifyBookFocus(.shelf, generation: focusGeneration)
        focus.book.removeAction(forKey: "book-extraction")
        focus.book.isHidden = false
        focus.book.removeFromParentNode()
        focus.originParent.addChildNode(focus.book)
        focus.book.simdTransform = focus.originTransform
        setFocusCategory(on: focus.book, enabled: false)
        focusedBookLightNode.constraints = nil
        focusedBook = nil
        isStandRotationLocked = false
        setLighting(focused: false, bookID: focus.id)
        completion?()
    }

    private func setLighting(focused: Bool, bookID: String) {
        // The aisle stays open, warm and readable. Only a selected Book lowers
        // the room rig; a real, broad SceneKit light follows that physical Book.
        // Exposure and texture intensity stay fixed so neither the room nor the
        // cover jumps into a dark, saturated grade during the move.
        roomAmbientLight.intensity = focused ? 125 : 285
        roomWarmLight.intensity = focused ? 20 : 55
        standKeyLight.intensity = focused ? 10 : 30
        roomCoolFillLight.intensity = focused ? 30 : 80
        for practical in practicalLights {
            practical.intensity = focused ? 3 : 8
        }
        focusedBookLight.intensity = focused ? 120 : 0
        cameraNode.camera?.exposureOffset = 0
        for (id, cover) in coverMaterials {
            cover.diffuse.intensity = focused && id != bookID ? 0.34 : 1
        }
    }

    private func setFocusCategory(on book: SCNNode, enabled: Bool) {
        let category = enabled ? 5 : 1 // room light (1) + focused Book light (4)
        book.categoryBitMask = category
        book.enumerateChildNodes { node, _ in
            node.categoryBitMask = category
        }
    }

    private func wrapped(_ index: Int) -> Int {
        (index % editions.count + editions.count) % editions.count
    }

    private func face(containing editionIndex: Int) -> Int? {
        pocketSlots.firstIndex { $0.contains { $0 == editionIndex } }
    }

    private func firstEdition(on face: Int) -> Int? {
        pocketSlots[wrappedFace(face)].compactMap { $0 }.first { $0 < editions.count }
    }

    private func wrappedFace(_ face: Int) -> Int {
        (face % pocketSlots.count + pocketSlots.count) % pocketSlots.count
    }

    // MARK: Scene construction

    private func buildScene() {
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(cameraTarget)

        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear = 0.08
        camera.zFar = 90
        camera.wantsHDR = false
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = 0
        camera.bloomIntensity = 0.12
        camera.bloomThreshold = 1.0
        camera.bloomBlurRadius = 6
        camera.screenSpaceAmbientOcclusionIntensity = 0.18
        camera.screenSpaceAmbientOcclusionRadius = 4
        camera.screenSpaceAmbientOcclusionBias = 0.025
        camera.screenSpaceAmbientOcclusionDepthThreshold = 0.08
        camera.screenSpaceAmbientOcclusionNormalThreshold = 0.24
        cameraNode.camera = camera
        cameraNode.position = storePose.position
        let look = SCNLookAtConstraint(target: cameraTarget)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]
        scene.rootNode.addChildNode(cameraNode)


        scene.fogColor = UIColor(red: 0.063, green: 0.047, blue: 0.035, alpha: 1)
        scene.fogStartDistance = 12
        scene.fogEndDistance = 32
        scene.fogDensityExponent = 1.35

        addRoom()
        addLighting()
        addStand()
        addShop()
        apply(storePose)
    }
    private func addRoom() {
        // Build the detailed room once. Geometry and materials are shared by
        // every repeated book variant so the first Metal frame does not have
        // to compile hundreds of effectively identical meshes.
        let firstRoomNode = scene.rootNode.childNodes.count
        let walnut = woodMaterial(color: rgb(0x2B160D), roughness: 0.74, repeatX: 3, repeatY: 9)
        let walnutLit = woodMaterial(color: rgb(0x4A2817), roughness: 0.67, repeatX: 2, repeatY: 8)
        let walnutEdge = woodMaterial(color: rgb(0x1A0C07), roughness: 0.82, repeatX: 2, repeatY: 7)
        // The mockup finishes on warm polished hardwood, not a blue-black
        // graphic strip. Keep the existing modeled planks and runner, but let
        // their real roughness and grain respond to the room practicals.
        let floorMaterial = woodMaterial(color: rgb(0x4A2818), roughness: 0.58, repeatX: 4, repeatY: 14)
        let runnerMaterial = material(color: rgb(0x24382F), roughness: 0.84)
        let brass = material(color: rgb(0x8B5C19), roughness: 0.38, metalness: 0.72)

        let floor = node(box: SCNVector3(12.4, 0.14, 30), material: floorMaterial)
        floor.position = SCNVector3(0, -0.09, 2)
        floor.castsShadow = true
        scene.rootNode.addChildNode(floor)

        for x in stride(from: -5.7 as Float, through: 5.7, by: 0.72) {
            let seam = node(box: SCNVector3(0.025, 0.012, 30), material: walnutEdge)
            seam.position = SCNVector3(x, 0.005, 2)
            scene.rootNode.addChildNode(seam)
        }

        let runner = node(box: SCNVector3(2.55, 0.025, 27.5), material: runnerMaterial)
        runner.position = SCNVector3(0, 0.005, 3.05)
        scene.rootNode.addChildNode(runner)
        for x: Float in [-1.31, 1.31] {
            let edge = node(box: SCNVector3(0.035, 0.018, 27.5), material: brass)
            edge.position = SCNVector3(x, 0.025, 3.05)
            scene.rootNode.addChildNode(edge)
        }
        for x: Float in stride(from: -0.96, through: 0.96, by: 0.24) {
            let weave = node(box: SCNVector3(0.008, 0.006, 27.2), material: material(color: rgb(0x315047), roughness: 0.96))
            weave.position = SCNVector3(x, 0.021, 3.05)
            weave.opacity = 0.38
            scene.rootNode.addChildNode(weave)
        }

        let ceiling = node(box: SCNVector3(12.4, 0.24, 30), material: walnutEdge)
        ceiling.position = SCNVector3(0, 6.25, 2)
        scene.rootNode.addChildNode(ceiling)
        for z in stride(from: -11 as Float, through: 14, by: 3.4) {
            let beam = node(box: SCNVector3(12.4, 0.24, 0.22), material: walnutLit)
            beam.position = SCNVector3(0, 6.02, z)
            scene.rootNode.addChildNode(beam)
        }
        for x: Float in [-3.1, 3.1] {
            let beam = node(box: SCNVector3(0.2, 0.25, 30), material: walnut)
            beam.position = SCNVector3(x, 6.01, 2)
            scene.rootNode.addChildNode(beam)
        }
        let ceilingPanel = material(color: rgb(0x343829), roughness: 0.92)
        for z in stride(from: -9.3 as Float, through: 12.3, by: 3.4) {
            for x: Float in [-1.55, 1.55] {
                let inset = node(box: SCNVector3(2.78, 0.055, 2.92), material: ceilingPanel, chamfer: 0.025)
                inset.position = SCNVector3(x, 6.09, z)
                scene.rootNode.addChildNode(inset)
                let pin = node(box: SCNVector3(2.62, 0.022, 0.025), material: brass)
                pin.position = SCNVector3(x, 6.055, z - 1.38)
                scene.rootNode.addChildNode(pin)
            }
        }

        addSideShelves(side: -1, walnut: walnut, trim: walnutLit, dark: walnutEdge)
        addSideShelves(side: 1, walnut: walnut, trim: walnutLit, dark: walnutEdge)
        addBackShelves(walnut: walnut, trim: walnutLit, dark: walnutEdge)
        let roomRoot = SCNNode()
        let roomNodes = Array(scene.rootNode.childNodes.dropFirst(firstRoomNode))
        for roomNode in roomNodes {
            roomNode.removeFromParentNode()
            roomRoot.addChildNode(roomNode)
        }
        // Preserve the individual printed spine planes. `flattenedClone()`
        // drops or depth-merges many of these very thin surfaces on the iOS
        // renderer, leaving the reference's dense shelves looking empty.
        // The room is still built once and remains a single static subtree.
        roomRoot.name = "bookstore-room"
        scene.rootNode.addChildNode(roomRoot)
    }

    private func addSideShelves(side: Float, walnut: SCNMaterial, trim: SCNMaterial, dark: SCNMaterial) {
        // SceneKit's narrow phone projection needs the aisle compressed in x
        // to reproduce the reference framing (the WebGL mockup used a square
        // projection before CSS cropping). The relative shelf depth stays the
        // same, but the cases remain visible as converging side walls.
        let wallX = side * 3.40
        if side > 0 {
            // Recess the shop into the right bookcase. The old continuous
            // backing sat in front of half the counter, which made the stand
            // look like a flat picture pushed behind the shelf.
            for run in [(center: -3.35 as Float, length: 18.30 as Float),
                        (center: 14.90 as Float, length: 3.20 as Float)] {
                let back = node(box: SCNVector3(0.28, 5.75, run.length), material: walnut)
                back.position = SCNVector3(3.62, 2.9, run.center)
                scene.rootNode.addChildNode(back)
            }
            let alcoveBack = node(box: SCNVector3(0.28, 5.75, 7.50), material: trim)
            alcoveBack.position = SCNVector3(4.45, 2.9, 9.55)
            scene.rootNode.addChildNode(alcoveBack)
            for z: Float in [5.80, 13.30] {
                let returnWall = node(box: SCNVector3(0.98, 5.75, 0.18), material: walnut)
                returnWall.position = SCNVector3(4.03, 2.9, z)
                scene.rootNode.addChildNode(returnWall)
            }
        } else {
            let back = node(box: SCNVector3(0.28, 5.75, 29), material: walnut)
            back.position = SCNVector3(-3.62, 2.9, 2)
            scene.rootNode.addChildNode(back)
        }

        for z in stride(from: -11.2 as Float, through: 14.0, by: 3.15) {
            if side > 0, z > 5.7, z < 13.4 { continue }
            let upright = node(box: SCNVector3(0.62, 5.9, 0.17), material: trim)
            upright.position = SCNVector3(wallX, 2.95, z)
            scene.rootNode.addChildNode(upright)
        }

        if side > 0 {
            for z: Float in [5.80, 13.30] {
                let upright = node(box: SCNVector3(0.62, 5.9, 0.17), material: trim)
                upright.position = SCNVector3(wallX, 2.95, z)
                scene.rootNode.addChildNode(upright)
            }
        }

        // The Club Shop occupies a real alcove in the near-right bookcase.
        // Split the long shelf/lip/rail meshes around it so the Shop camera
        // never looks through a 29-point shelf that crosses the counter.
        let shelfRuns: [(center: Float, length: Float)] = side > 0
            ? [(-3.35, 18.30), (14.90, 3.20)]
            : [(2.0, 29.0)]

        let shelfLevels: [Float] = [0.18, 1.3, 2.42, 3.54, 4.66, 5.73]
        for y in shelfLevels {
            for run in shelfRuns {
                let shelf = node(box: SCNVector3(1.12, 0.12, run.length), material: trim)
                shelf.position = SCNVector3(side * 3.16, y, run.center)
                scene.rootNode.addChildNode(shelf)

                let lip = node(box: SCNVector3(0.10, 0.20, run.length), material: dark, chamfer: 0.018)
                lip.position = SCNVector3(side * 2.72, y + 0.025, run.center)
                scene.rootNode.addChildNode(lip)

                let rail = node(box: SCNVector3(0.025, 0.028, run.length), material: material(color: rgb(0x79501C), roughness: 0.42, metalness: 0.56))
                rail.position = SCNVector3(side * 2.66, y + 0.10, run.center)
                rail.opacity = 0.72
                scene.rootNode.addChildNode(rail)
            }
        }

        let colors = [0x5A2A25, 0x2B4438, 0x26374B, 0x86602D, 0x7A6A4D, 0x493129, 0x4E3A57]
        for bay in 0..<8 {
            let bayZ = 12.2 - Float(bay) * 3.15
            if side > 0, bayZ > 5.7, bayZ < 13.4 { continue }
            for level in 0..<5 {
                let y = 0.76 + Float(level) * 1.12
                for book in 0..<7 {
                    let width = 0.22 + Float((bay + level + book) % 3) * 0.045
                    let height = 0.76 + Float((book * 2 + level) % 4) * 0.06
                    let paletteIndex = (bay + level + book) % colors.count
                    let title = shelfTitles[(bay * 7 + level * 3 + book) % shelfTitles.count]
                    let root = SCNNode()
                    root.position = SCNVector3(side * 2.90, y, bayZ - 0.92 + Float(book) * 0.29)
                    if (bay + level + book).isMultiple(of: 6) {
                        root.eulerAngles.x = side * 0.055
                    }

                    let geometry = shelfBookGeometry(
                        width: 0.48,
                        height: height,
                        length: width,
                        paletteIndex: paletteIndex,
                        roughness: 0.84,
                        chamfer: 0.015
                    )
                    let bookNode = SCNNode(geometry: geometry)
                    root.addChildNode(bookNode)

                    let printedSpine = makeShelfSpine(
                        paletteIndex: paletteIndex,
                        title: title,
                        width: width * 0.88,
                        height: height * 0.88
                    )
                    printedSpine.position = SCNVector3(-side * 0.245, 0, 0)
                    printedSpine.eulerAngles.y = -side * (.pi / 2)
                    root.addChildNode(printedSpine)

                    if (bay + level + book).isMultiple(of: 4) {
                        let band = node(box: SCNVector3(0.018, 0.055, width * 0.72), material: material(color: rgb(0xB18A4D), roughness: 0.62, metalness: 0.2))
                        band.position = SCNVector3(-side * 0.245, -height * 0.13, 0)
                        band.opacity = 0.75
                        root.addChildNode(band)
                    }
                    scene.rootNode.addChildNode(root)
                }

                if (bay + level).isMultiple(of: 5) {
                    for stack in 0..<3 {
                        let stacked = node(box: SCNVector3(0.50, 0.095, 0.66 - Float(stack) * 0.06), material: material(color: rgb(colors[(bay + level + stack + 2) % colors.count]), roughness: 0.86), chamfer: 0.012)
                        stacked.position = SCNVector3(side * 2.92, 0.29 + Float(level) * 1.12 + Float(stack) * 0.105, bayZ + 0.90)
                        scene.rootNode.addChildNode(stacked)
                    }
                }
            }
        }

        if side > 0 {
            addShopAisleFramingBay(walnut: walnut, trim: trim, dark: dark)
        }


        for z in stride(from: -10.8 as Float, through: 13.6, by: 3.15) {
            let labelZ = z + 1.35
            if side > 0, labelZ > 5.7, labelZ < 13.4 { continue }
            let label = node(box: SCNVector3(0.035, 0.22, 0.74), material: material(color: rgb(0x8A652E), roughness: 0.5, metalness: 0.38), chamfer: 0.025)
            label.position = SCNVector3(side * 2.65, 5.57, labelZ)
            label.opacity = 0.78
            scene.rootNode.addChildNode(label)
        }

        for run in shelfRuns {
            let crown = node(box: SCNVector3(0.85, 0.23, run.length), material: dark)
            crown.position = SCNVector3(wallX, 5.93, run.center)
            scene.rootNode.addChildNode(crown)
        }
    }

    /// The approved shop is still visibly inside the aisle: a slim run of the
    /// right bookcase crosses the near-left edge of the shop view. Keep this
    /// bay narrow and behind the cabinet so it supplies depth without putting
    /// a shelf through the merchandise.
    private func addShopAisleFramingBay(walnut: SCNMaterial, trim: SCNMaterial,
                                       dark: SCNMaterial) {
        let centerZ: Float = 6.45
        let length: Float = 1.75
        let back = node(box: SCNVector3(0.24, 5.72, length), material: walnut)
        back.position = SCNVector3(3.54, 2.90, centerZ)
        scene.rootNode.addChildNode(back)

        for z in [centerZ - length / 2, centerZ + length / 2] {
            let upright = node(box: SCNVector3(0.54, 5.86, 0.15), material: trim)
            upright.position = SCNVector3(3.35, 2.95, z)
            scene.rootNode.addChildNode(upright)
        }

        let shelfLevels: [Float] = [0.18, 1.30, 2.42, 3.54, 4.66, 5.73]
        let railMaterial = material(color: rgb(0x79501C), roughness: 0.42, metalness: 0.56)
        for y in shelfLevels {
            let shelf = node(box: SCNVector3(1.02, 0.11, length), material: trim)
            shelf.position = SCNVector3(3.10, y, centerZ)
            scene.rootNode.addChildNode(shelf)

            let lip = node(box: SCNVector3(0.09, 0.18, length), material: dark, chamfer: 0.016)
            lip.position = SCNVector3(2.70, y + 0.025, centerZ)
            scene.rootNode.addChildNode(lip)

            let rail = node(box: SCNVector3(0.022, 0.026, length), material: railMaterial)
            rail.position = SCNVector3(2.65, y + 0.095, centerZ)
            rail.opacity = 0.72
            scene.rootNode.addChildNode(rail)
        }

        let colors = [0x5A2A25, 0x2B4438, 0x26374B, 0x86602D, 0x7A6A4D, 0x493129, 0x4E3A57]
        for level in 0..<5 {
            let y = 0.76 + Float(level) * 1.12
            for book in 0..<10 {
                let thickness = 0.13 + Float((level + book) % 3) * 0.022
                let height = 0.76 + Float((book * 2 + level) % 4) * 0.06
                let paletteIndex = (level * 2 + book + 3) % colors.count
                let bookRoot = SCNNode()
                bookRoot.position = SCNVector3(2.86, y, centerZ - 0.78 + Float(book) * 0.17)
                if (level + book).isMultiple(of: 6) { bookRoot.eulerAngles.x = 0.045 }

                let geometry = shelfBookGeometry(
                    width: 0.46,
                    height: height,
                    length: thickness,
                    paletteIndex: paletteIndex,
                    roughness: 0.84,
                    chamfer: 0.014
                )
                bookRoot.addChildNode(SCNNode(geometry: geometry))

                let spine = makeShelfSpine(
                    paletteIndex: paletteIndex,
                    title: shelfTitles[(level * 7 + book + 9) % shelfTitles.count],
                    width: thickness * 0.88,
                    height: height * 0.88
                )
                spine.position = SCNVector3(-0.235, 0, 0)
                spine.eulerAngles.y = -.pi / 2
                bookRoot.addChildNode(spine)
                scene.rootNode.addChildNode(bookRoot)
            }
        }

    }

    private func addBackShelves(walnut: SCNMaterial, trim: SCNMaterial, dark: SCNMaterial) {
        let backing = node(box: SCNVector3(5.2, 5.9, 0.35), material: walnut)
        backing.position = SCNVector3(0, 2.95, -12.1)
        scene.rootNode.addChildNode(backing)

        for x in stride(from: -2.5 as Float, through: 2.5, by: 1.25) {
            let upright = node(box: SCNVector3(0.14, 5.9, 0.55), material: trim)
            upright.position = SCNVector3(x, 2.95, -11.84)
            scene.rootNode.addChildNode(upright)
        }
        for y: Float in [0.2, 1.35, 2.5, 3.65, 4.8, 5.8] {
            let shelf = node(box: SCNVector3(5.2, 0.13, 0.62), material: trim)
            shelf.position = SCNVector3(0, y, -11.82)
            scene.rootNode.addChildNode(shelf)
        }
        let colors = [0x5A2A25, 0x2B4438, 0x26374B, 0x86602D, 0x7A6A4D]
        for level in 0..<5 {
            for book in 0..<15 {
                let width: Float = 0.25 + Float((book + level) % 3) * 0.035
                let height: Float = 0.78 + Float((book + level * 2) % 4) * 0.055
                let paletteIndex = (book + level) % colors.count
                let title = shelfTitles[(level * 15 + book) % shelfTitles.count]
                let root = SCNNode()
                root.position = SCNVector3(-2.28 + Float(book) * 0.33,
                                           0.78 + Float(level) * 1.15, -11.48)
                if (book + level).isMultiple(of: 7) {
                    root.eulerAngles.z = Float(book.isMultiple(of: 2) ? -1 : 1) * 0.018
                }
                let geometry = shelfBookGeometry(
                    width: width,
                    height: height,
                    length: 0.42,
                    paletteIndex: paletteIndex,
                    roughness: 0.85,
                    chamfer: 0.012
                )
                let bookNode = SCNNode(geometry: geometry)
                root.addChildNode(bookNode)
                let printedSpine = makeShelfSpine(
                    paletteIndex: paletteIndex,
                    title: title,
                    width: width * 0.88,
                    height: height * 0.88
                )
                printedSpine.position = SCNVector3(0, 0, 0.235)
                root.addChildNode(printedSpine)
                if (book + level).isMultiple(of: 5) {
                    let band = node(box: SCNVector3(width * 0.72, 0.05, 0.018), material: material(color: rgb(0xB18A4D), roughness: 0.62, metalness: 0.2))
                    band.position = SCNVector3(0, -height * 0.13, 0.225)
                    band.opacity = 0.7
                    root.addChildNode(band)
                }
                scene.rootNode.addChildNode(root)
            }
        }
        let crown = node(box: SCNVector3(5.5, 0.24, 0.65), material: dark)
        crown.position = SCNVector3(0, 5.93, -11.82)
        scene.rootNode.addChildNode(crown)
    }

    private func addLighting() {
        roomAmbientLight.type = .ambient
        roomAmbientLight.color = UIColor(red: 0.55, green: 0.48, blue: 0.42, alpha: 1)
        roomAmbientLight.intensity = 285
        roomAmbientLight.categoryBitMask = 1
        let ambientNode = SCNNode()
        ambientNode.light = roomAmbientLight
        scene.rootNode.addChildNode(ambientNode)

        roomWarmLight.type = .omni
        roomWarmLight.color = UIColor(red: 1, green: 0.90, blue: 0.78, alpha: 1)
        roomWarmLight.intensity = 55
        roomWarmLight.attenuationStartDistance = 2
        roomWarmLight.attenuationEndDistance = 15
        roomWarmLight.categoryBitMask = 1
        // Deferred light shadows intermittently invalidate SceneKit's render
        // pass on the current iOS renderer, producing a completely black home
        // aisle. Geometry still receives the neutral room and focused lights;
        // contact depth is supplied by the modeled shelf/book forms.
        roomWarmLight.castsShadow = false
        let warmNode = SCNNode()
        warmNode.light = roomWarmLight
        warmNode.position = SCNVector3(-1.2, 5.55, -3.5)
        scene.rootNode.addChildNode(warmNode)

        standKeyLight.type = .spot
        standKeyLight.color = UIColor(red: 1, green: 0.94, blue: 0.84, alpha: 1)
        standKeyLight.intensity = 30
        standKeyLight.attenuationStartDistance = 2
        standKeyLight.attenuationEndDistance = 18
        standKeyLight.spotInnerAngle = 48
        standKeyLight.spotOuterAngle = 92
        standKeyLight.categoryBitMask = 1
        let standKeyNode = SCNNode()
        standKeyNode.light = standKeyLight
        standKeyNode.position = SCNVector3(1.8, 5.7, -2.2)
        let standKeyTarget = SCNNode()
        standKeyTarget.position = SCNVector3(0, 2.7, -7.55)
        scene.rootNode.addChildNode(standKeyTarget)
        let keyLook = SCNLookAtConstraint(target: standKeyTarget)
        keyLook.isGimbalLockEnabled = true
        standKeyNode.constraints = [keyLook]
        scene.rootNode.addChildNode(standKeyNode)

        roomCoolFillLight.type = .omni
        roomCoolFillLight.color = UIColor(red: 0.46, green: 0.57, blue: 0.54, alpha: 1)
        roomCoolFillLight.intensity = 80
        roomCoolFillLight.attenuationStartDistance = 2
        roomCoolFillLight.attenuationEndDistance = 11
        roomCoolFillLight.categoryBitMask = 1
        let coolFillNode = SCNNode()
        coolFillNode.light = roomCoolFillLight
        coolFillNode.position = SCNVector3(-3.4, 3.2, 3.5)
        scene.rootNode.addChildNode(coolFillNode)

        for z: Float in [4.25, 0.85, -2.55, -5.95, -9.35] {
            let practical = SCNLight()
            practical.type = .omni
            practical.color = UIColor(red: 1, green: 0.91, blue: 0.79, alpha: 1)
            practical.intensity = 8
            practical.attenuationStartDistance = 1
            practical.attenuationEndDistance = 9
            practical.categoryBitMask = 1
            practicalLights.append(practical)
            let lightNode = SCNNode()
            lightNode.light = practical
            lightNode.position = SCNVector3(0, 5.55, z)
            scene.rootNode.addChildNode(lightNode)
        }

        focusedBookLight.type = .spot
        focusedBookLight.color = UIColor(red: 1, green: 0.98, blue: 0.93, alpha: 1)
        focusedBookLight.intensity = 0
        focusedBookLight.categoryBitMask = 4
        focusedBookLight.attenuationStartDistance = 1.5
        focusedBookLight.attenuationEndDistance = 9
        focusedBookLight.spotInnerAngle = 82
        focusedBookLight.spotOuterAngle = 124
        focusedBookLight.castsShadow = false
        focusedBookLightNode.light = focusedBookLight
        scene.rootNode.addChildNode(focusedBookLightNode)
    }

    // MARK: Physical Club Shop

    private func addShop() {
        let counterWood = woodMaterial(color: rgb(0x51331F), roughness: 0.70, repeatX: 2, repeatY: 6)
        let counterEdge = woodMaterial(color: rgb(0x8A6040), roughness: 0.58, repeatX: 2, repeatY: 4)
        let shopWallTrim = woodMaterial(color: rgb(0x604027), roughness: 0.70, repeatX: 2, repeatY: 5)
        let counterGreen = material(color: rgb(0x263D35), roughness: 0.65, metalness: 0.05)
        let brass = material(color: rgb(0x9B6D2E), roughness: 0.34, metalness: 0.72)
        let darkMetal = material(color: rgb(0x242625), roughness: 0.34, metalness: 0.72)

        shopRoot.name = "club-shop-root"
        shopRoot.position = SCNVector3(3.62, 0.16, 8.62)
        shopRoot.eulerAngles.y = -0.62
        // Preserve real-world proportions. Framing belongs to the camera, not
        // a non-uniform scene transform.
        shopRoot.scale = SCNVector3(0.70, 0.70, 0.70)
        scene.rootNode.addChildNode(shopRoot)

        // Counter-only proof: the user's textured Meshy counter is the
        // complete shop fixture.  Do not layer our old procedural facade,
        // products, turntables, or sales cards over it.
        if let importedCounter = makeMeshyShopCounter() {
            importedCounter.name = "meshy-club-shop-counter"
            // Put the high rear cabinet against the alcove wall and keep the
            // selling face toward the aisle. The room and camera path remain
            // fixed; only the imported fixture is oriented for its real use.
            importedCounter.eulerAngles.y = 0.20
            importedShopCounter = importedCounter
            importedShopCounterBasePosition = importedCounter.position
            shopRoot.addChildNode(importedCounter)
            addShopBackdropDressing(to: importedCounter)
            addCounterFacade(to: importedCounter)
            addBoardHeader(to: importedCounter)
            addBoardShelf(to: importedCounter)
            addImportedShopPendant(to: importedCounter)
            shopRoot.enumerateChildNodes { node, _ in
                // Category 2 is illuminated only by the three Meshy fixtures.
                // The room rig is category 1, so it cannot create a detached
                // highlight on the product row or selling platform.
                node.categoryBitMask = 2
                node.castsShadow = true
            }
            return
        }

        // The recessed bookshelf remains part of the room. The shop's own
        // backing and printed fixtures are children of shopRoot below.
        shopWallRoot.name = "club-shop-wall-shelf"
        shopWallRoot.position = SCNVector3(4.30, 0.16, 8.62)
        shopWallRoot.eulerAngles.y = -.pi / 2
        shopWallRoot.scale = SCNVector3(0.70, 0.70, 0.70)
        scene.rootNode.addChildNode(shopWallRoot)
        addShopWallBox(SCNVector3(5.90, 0.14, 0.68),
                       at: SCNVector3(0, 5.46, 0.32),
                       material: shopWallTrim, chamfer: 0.025)
        // Continue the high shelf into the receding aisle. The native alcove
        // previously stopped at the frame edge, leaving a black void where the
        // approved composition has another dense run of books.
        addShopWallBox(SCNVector3(4.45, 0.14, 0.68),
                       at: SCNVector3(-4.94, 5.46, 0.32),
                       material: shopWallTrim, chamfer: 0.025)
        let wallBookColors = [0x5A2A25, 0x2B4438, 0x26374B, 0x86602D, 0x493129, 0x4E3A57]
        var recedingBookX: Float = -6.96
        for index in 0..<15 {
            let width = 0.23 + Float((index + 1) % 3) * 0.035
            let height = 0.62 + Float((index * 2 + 1) % 5) * 0.075
            let paletteIndex = (index + 4) % wallBookColors.count
            let geometry = shelfBookGeometry(
                width: width,
                height: height,
                length: 0.36,
                paletteIndex: paletteIndex,
                roughness: 0.84,
                chamfer: 0.012
            )
            let book = SCNNode(geometry: geometry)
            book.position = SCNVector3(recedingBookX + width / 2, 5.56 + height / 2, 0.22)
            if index.isMultiple(of: 6) { book.eulerAngles.z = -0.028 }
            shopWallRoot.addChildNode(book)

            let spine = makeShelfSpine(
                paletteIndex: paletteIndex,
                title: shelfTitles[(index + 2) % shelfTitles.count],
                width: width * 0.84,
                height: height * 0.84
            )
            spine.position = SCNVector3(recedingBookX + width / 2, 5.56 + height / 2, 0.415)
            shopWallRoot.addChildNode(spine)
            recedingBookX += width + 0.035
        }
        var wallBookX: Float = -2.72
        for index in 0..<18 {
            let width = 0.23 + Float(index % 3) * 0.035
            let height = 0.62 + Float((index * 3) % 5) * 0.075
            let geometry = shelfBookGeometry(
                width: width,
                height: height,
                length: 0.36,
                paletteIndex: index % wallBookColors.count,
                roughness: 0.82,
                chamfer: 0.012
            )
            let book = SCNNode(geometry: geometry)
            book.position = SCNVector3(wallBookX + width / 2, 5.56 + height / 2, 0.22)
            if index.isMultiple(of: 7) { book.eulerAngles.z = 0.035 }
            shopWallRoot.addChildNode(book)
            let spine = makeShelfSpine(
                paletteIndex: index % wallBookColors.count,
                title: shelfTitles[(index + 7) % shelfTitles.count],
                width: width * 0.84,
                height: height * 0.84
            )
            spine.position = SCNVector3(wallBookX + width / 2, 5.56 + height / 2, 0.415)
            shopWallRoot.addChildNode(spine)
            wallBookX += width + 0.035
        }
        let previewSurfaceMaterial = counterEdge.copy() as! SCNMaterial

        // Keep the approved right edge, but carry the cabinet farther left so
        // the oblique camera never exposes the detached end of the aisle bay.
        addShopBox(SCNVector3(4.15, 3.95, 0.42),
                   at: SCNVector3(-0.25, 2.25, -0.35),
                   material: counterWood, chamfer: 0.018)
        for x in stride(from: Float(-2.05), through: 1.55, by: 0.52) {
            addShopBox(SCNVector3(0.018, 2.45, 0.018),
                       at: SCNVector3(x, 2.22, -0.125),
                       material: counterEdge)
        }
        for y: Float in [1.18, 3.25] {
            addShopBox(SCNVector3(4.00, 0.026, 0.025),
                       at: SCNVector3(-0.25, y, -0.116),
                       material: counterEdge)
        }
        for x: Float in [-2.15, 1.66] {
            for y: Float in [1.16, 3.28] {
                let screw = SCNSphere(radius: 0.035)
                screw.firstMaterial = brass
                let screwNode = SCNNode(geometry: screw)
                screwNode.position = SCNVector3(x, y, -0.09)
                shopRoot.addChildNode(screwNode)
            }
        }

        let previewSurface = addShopBox(
            SCNVector3(3.98, 0.24, 1.18),
            at: SCNVector3(0, 1.10, 0.08),
            material: previewSurfaceMaterial,
            chamfer: 0.055
        )
        addShopBox(SCNVector3(3.74, 1.18, 0.92), at: SCNVector3(0, 0.43, 0.02), material: counterWood, chamfer: 0.025)
        addShopBox(SCNVector3(3.62, 0.08, 0.82), at: SCNVector3(0, 0.97, 0.08), material: brass)

        let sign = printedShopPlane(
            width: 3.22,
            height: 0.94,
            image: shopSignTexture(),
            // SceneKit depth-tests the panel grooves against coplanar decals;
            // pull the sign forward just enough to keep its face uninterrupted.
            position: SCNVector3(0, 3.63, -0.08)
        )
        sign.opacity = 1
        sign.renderingOrder = 2
        sign.geometry?.firstMaterial?.readsFromDepthBuffer = false
        sign.geometry?.firstMaterial?.writesToDepthBuffer = false
        shopRoot.addChildNode(sign)

        let notice = printedShopPlane(
            width: 1.20,
            height: 0.45,
            image: shopNoticeTexture(),
            position: SCNVector3(-0.93, 2.63, -0.09)
        )
        notice.eulerAngles.z = -0.035
        notice.opacity = 0.90
        notice.renderingOrder = 3
        notice.geometry?.firstMaterial?.readsFromDepthBuffer = false
        notice.geometry?.firstMaterial?.writesToDepthBuffer = false
        shopRoot.addChildNode(notice)

        let hanging: [(String, String, String, UIColor, UIColor)] = [
            ("IVORY", "laid stock", "✦", rgb(0xD8CDB4), rgb(0x51483C)),
            ("MANILA", "files nicely", "II", rgb(0xC8AA78), rgb(0x52432D)),
            ("LEDGER", "keeps count", "+", rgb(0x8EA7AE), rgb(0x30464D))
        ]
        for (index, sample) in hanging.enumerated() {
            let paper = printedShopPlane(
                width: 0.38,
                height: 0.55,
                image: hangingSampleTexture(title: sample.0, note: sample.1, mark: sample.2,
                                            paper: sample.3, ink: sample.4),
                position: SCNVector3(0.52 + Float(index) * 0.46, 2.50, -0.085)
            )
            paper.eulerAngles.z = Float(index - 1) * 0.045
            paper.opacity = 0.94
            paper.renderingOrder = 3
            paper.geometry?.firstMaterial?.readsFromDepthBuffer = false
            paper.geometry?.firstMaterial?.writesToDepthBuffer = false
            shopRoot.addChildNode(paper)
            let clip = addShopBox(SCNVector3(0.12, 0.07, 0.04),
                                  at: SCNVector3(0.52 + Float(index) * 0.46, 2.79, -0.045),
                                  material: brass)
            clip.opacity = 0.92
        }

        let categories = CosmeticCategory.allCases
        let drawerXPositions: [Float] = [-1.18, 0, 1.18]
        let productXPositions: [Float] = [-1.05, 0, 1.05]
        for (index, category) in categories.enumerated() {
            let drawer = SCNNode()
            drawer.name = "shop-category:\(category.rawValue)"
            shopRoot.addChildNode(drawer)
            shopDrawerNodes[category] = drawer

            // Each category is a real shallow sales-counter drawer. The whole
            // drawer moves forward on selection; the printed label is mounted
            // on its face rather than floating over the cabinet.
            let drawerFace = node(
                box: SCNVector3(0.82, 0.30, 0.055),
                material: counterEdge,
                chamfer: 0.014
            )
            drawerFace.position = SCNVector3(drawerXPositions[index], 0.35, 0.478)
            drawer.addChildNode(drawerFace)

            let drawerLabelMaterial = SCNMaterial()
            drawerLabelMaterial.lightingModel = .constant
            drawerLabelMaterial.diffuse.contents = shopDrawerTexture(category.title.uppercased(), selected: category == .paper)
            drawerLabelMaterial.isDoubleSided = true
            shopDrawerLabelMaterials[category] = drawerLabelMaterial
            let drawerLabelPlane = SCNPlane(width: 0.72, height: 0.23)
            drawerLabelPlane.firstMaterial = drawerLabelMaterial
            let drawerLabel = SCNNode(geometry: drawerLabelPlane)
            drawerLabel.name = "shop-category:\(category.rawValue)"
            drawerLabel.position = SCNVector3(drawerXPositions[index], 0.45, 0.505)
            drawerLabel.castsShadow = false
            drawer.addChildNode(drawerLabel)

            let pull = node(box: SCNVector3(0.22, 0.026, 0.026), material: brass, chamfer: 0.01)
            pull.position = SCNVector3(drawerXPositions[index], 0.24, 0.55)
            drawer.addChildNode(pull)
            for postX: Float in [-0.09, 0.09] {
                let post = node(box: SCNVector3(0.024, 0.07, 0.035), material: brass, chamfer: 0.008)
                post.position = SCNVector3(drawerXPositions[index] + postX, 0.27, 0.53)
                drawer.addChildNode(post)
            }

            let sample = SCNNode()
            sample.name = "shop-category:\(category.rawValue)"
            let basePosition = SCNVector3(productXPositions[index], 1.22, 0.23)
            sample.position = basePosition
            shopSampleBasePositions[category] = basePosition
            shopSampleNodes[category] = sample
            shopRoot.addChildNode(sample)

            if let authoredPlinth = makeMeshyShopTurntable() {
                sample.addChildNode(authoredPlinth)
            } else {
                let plinth = SCNCylinder(radius: 0.38, height: 0.10)
                plinth.firstMaterial = category == .board
                    ? material(color: rgb(0x718069), roughness: 0.67, metalness: 0.03)
                    : counterGreen
                let plinthNode = SCNNode(geometry: plinth)
                plinthNode.position.y = 0.02
                plinthNode.castsShadow = true
                sample.addChildNode(plinthNode)
            }

            let turntableColor: UIColor
            switch category {
            case .paper: turntableColor = rgb(0x6A5941)
            case .board: turntableColor = rgb(0x73806C)
            case .numbers: turntableColor = rgb(0x343B38)
            }
            let turntableTop = SCNCylinder(radius: 0.33, height: 0.035)
            turntableTop.firstMaterial = material(
                color: turntableColor,
                roughness: 0.50,
                metalness: 0.08
            )
            let turntableTopNode = SCNNode(geometry: turntableTop)
            turntableTopNode.position.y = 0.087
            turntableTopNode.castsShadow = true
            sample.addChildNode(turntableTopNode)

            // A restrained illuminated brass register ring is the shop's
            // signature detail: it makes the samples read as working display
            // turntables without introducing arcade-like glow elsewhere.
            let ringMaterial = brass.copy() as! SCNMaterial
            ringMaterial.emission.contents = UIColor.black
            shopTurntableRingMaterials[category] = ringMaterial
            let ring = SCNTorus(ringRadius: 0.33, pipeRadius: 0.014)
            ring.firstMaterial = ringMaterial
            let ringNode = SCNNode(geometry: ring)
            ringNode.position.y = 0.108
            ringNode.castsShadow = false
            sample.addChildNode(ringNode)
            for angle in stride(from: Float(0), to: Float.pi * 2, by: Float.pi / 2) {
                let tick = node(
                    box: SCNVector3(0.050, 0.012, 0.018),
                    material: ringMaterial,
                    chamfer: 0.004
                )
                tick.position = SCNVector3(cos(angle) * 0.33, 0.112, sin(angle) * 0.33)
                tick.eulerAngles.y = -angle
                tick.castsShadow = false
                sample.addChildNode(tick)
            }

            // Keep merchandise rotation isolated from the plinth and price
            // card. The outer sample node still owns lift, scale and swipe
            // tilt; this inner pivot owns only the showroom turn.
            let turntable = SCNNode()
            turntable.name = "shop-merchandise:\(category.rawValue)"
            shopTurntableNodes[category] = turntable
            sample.addChildNode(turntable)

            switch category {
            case .paper: addPaperSample(to: turntable)
            case .board: addBoardSample(to: turntable)
            case .numbers: addNumberSample(to: turntable, metal: darkMetal)
            }

            let startingPrice = CosmeticCatalog.items(in: category).first?.price ?? 0
            let tagMaterial = SCNMaterial()
            tagMaterial.lightingModel = .constant
            tagMaterial.diffuse.contents = shopPriceTexture(price: startingPrice)
            tagMaterial.isDoubleSided = true
            shopPriceMaterials[category] = tagMaterial
            let tagPlane = SCNPlane(width: 0.62, height: 0.20)
            tagPlane.firstMaterial = tagMaterial
            let tag = SCNNode(geometry: tagPlane)
            tag.position = SCNVector3(0, 0.02, 0.42)
            tag.eulerAngles.x = -0.28
            tag.castsShadow = false
            sample.addChildNode(tag)

        }

        addShopLamp(brass: brass, darkMetal: darkMetal)

        // The environment stays in the room rig. Only the work surface,
        // merchandise and neighboring cards enter the pendant's category,
        // so the product receives the brightest, cleanest light.
        shopRoot.enumerateChildNodes { node, _ in node.categoryBitMask = 1 }
        shopWallRoot.enumerateChildNodes { node, _ in node.categoryBitMask = 1 }
        previewSurface.categoryBitMask = 3
        for sample in shopSampleNodes.values {
            sample.enumerateChildNodes { node, _ in node.categoryBitMask = 3 }
            sample.categoryBitMask = 3
        }
        for neighbor in shopNeighborNodes { neighbor.categoryBitMask = 3 }
    }

    /// Loads the user's retextured USDZ as the complete physical shop stand.
    /// The asset is centered on the alcove and its lowest vertex is aligned to
    /// the existing floor so its feet retain contact shadows.
    private func makeMeshyShopCounter() -> SCNNode? {
        if !didLoadShopMeshyTurntable {
            didLoadShopMeshyTurntable = true
            if let url = Bundle.main.url(forResource: "ClubTurntable", withExtension: "usdz"),
               let authoredScene = try? SCNScene(url: url) {
                let prototype = SCNNode()
                for child in authoredScene.rootNode.childNodes {
                    prototype.addChildNode(child.clone())
                }
                let (minimum, maximum) = prototype.boundingBox
                importedShopCounterSourceBounds = MeshyAssetBounds(minimum: minimum, maximum: maximum)
                let footprint = max(maximum.x - minimum.x, maximum.z - minimum.z)
                if footprint > 0.0001 {
                    // This compact one-bay stand intentionally occupies half
                    // the old three-bay counter width, leaving room around it
                    // for the player-controlled camera framing.
                    let scale = 2.65 / footprint
                    prototype.scale = SCNVector3(scale, scale, scale)
                    prototype.position = SCNVector3(
                        -(minimum.x + maximum.x) * 0.5 * scale,
                        -minimum.y * scale,
                        -(minimum.z + maximum.z) * 0.5 * scale
                    )
                }
                prototype.enumerateChildNodes { node, _ in
                    node.castsShadow = true
                    node.geometry?.materials.forEach { material in
                        material.lightingModel = .physicallyBased
                        // Meshy's counter albedo already contains the mockup's
                        // bottle-green leather inserts and walnut surround.
                        // Preserve that authored color under the fixture rig:
                        // the provider's very strong baked occlusion otherwise
                        // crushes the lower door to black on the phone display.
                        material.diffuse.intensity = 1.14
                        material.ambientOcclusion.intensity = 0.68
                        material.normal.intensity = 1.04
                        material.roughness.intensity = max(0.32, material.roughness.intensity)
                        self.configureImportedTextureSampling(material)
                    }
                }
                shopMeshyTurntablePrototype = prototype
            }
        }
        return shopMeshyTurntablePrototype?.clone()
    }

    /// Covers the visibly warped lower face of the original all-in-one shop
    /// mesh with a dedicated, low-poly Meshy cabinet whose rails, panels and
    /// legs were generated from a straight-on orthographic reference. The
    /// original counter remains the structural upper display and tabletop;
    /// this child occupies only the lower-front depth layer.
    private func addCounterFacade(to counter: SCNNode) {
        guard let bounds = importedShopCounterSourceBounds,
              let facade = makeMeshyShopProp(
                resourceName: "MeshyShopCounterFacade",
                targetLargestDimension: 1
              )
        else { return }

        let (minimum, maximum) = facade.boundingBox
        let sourceWidth = maximum.x - minimum.x
        let sourceHeight = maximum.y - minimum.y
        let sourceDepth = maximum.z - minimum.z
        guard sourceWidth > 0.0001,
              sourceHeight > 0.0001,
              sourceDepth > 0.0001
        else { return }

        let targetWidth = bounds.width * 0.995
        let targetHeight = bounds.height * 0.45
        let targetDepth = bounds.depth * 0.10
        let xScale = targetWidth / sourceWidth
        let yScale = targetHeight / sourceHeight
        let zScale = targetDepth / sourceDepth
        let targetFrontZ = bounds.maximum.z + max(bounds.depth * 0.055, 0.025)

        facade.name = "meshy-shop-counter-facade"
        facade.scale = SCNVector3(xScale, yScale, zScale)
        facade.position = SCNVector3(
            bounds.centerX - (minimum.x + maximum.x) * 0.5 * xScale,
            bounds.minimum.y - minimum.y * yScale,
            targetFrontZ - maximum.z * zScale
        )
        facade.enumerateChildNodes { node, _ in
            node.categoryBitMask = 2
            node.castsShadow = true
            node.geometry?.materials.forEach { material in
                material.diffuse.intensity = 0.98
                material.ambientOcclusion.intensity = 0.82
                material.normal.intensity = 1.08
                material.roughness.intensity = max(0.38, material.roughness.intensity)
                self.configureImportedTextureSampling(material)
            }
        }
        counter.addChildNode(facade)
    }

    private func makeMeshyShopBoard(resourceName: String, targetLargestDimension: Float) -> SCNNode? {
        if shopMeshyBoardPrototypes[resourceName] == nil {
            if let url = Bundle.main.url(forResource: resourceName, withExtension: "usdz"),
               let authoredScene = try? SCNScene(url: url) {
                let prototype = SCNNode()
                for child in authoredScene.rootNode.childNodes {
                    prototype.addChildNode(child.clone())
                }
                prototype.enumerateChildNodes { node, _ in
                    node.castsShadow = true
                    node.geometry?.materials.forEach { material in
                        material.lightingModel = .physicallyBased
                        material.isDoubleSided = true
                        material.readsFromDepthBuffer = true
                        material.writesToDepthBuffer = true
                        self.configureImportedTextureSampling(material)
                    }
                }
                shopMeshyBoardPrototypes[resourceName] = prototype
            }
        }
        guard let board = shopMeshyBoardPrototypes[resourceName]?.clone() else { return nil }
        let (minimum, maximum) = board.boundingBox
        let largest = max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
        guard largest > 0.0001 else { return board }
        let scale = targetLargestDimension / largest
        board.scale = SCNVector3(scale, scale, scale)
        board.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -minimum.y * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )
        return board
    }

    /// Loads one of the authored Meshy shop props, preserves its textured
    /// materials, and returns a uniformly scaled clone centered on its visible
    /// bounds.  Callers own placement; no billboard or screen-space offsets
    /// are involved, so every prop participates in the same real depth and
    /// three-light pass as the imported counter.
    private func makeMeshyShopProp(resourceName: String,
                                   targetLargestDimension: Float) -> SCNNode? {
        if shopMeshyPropPrototypes[resourceName] == nil,
           let url = Bundle.main.url(forResource: resourceName, withExtension: "usdz"),
           let authoredScene = try? SCNScene(url: url) {
            let prototype = SCNNode()
            for child in authoredScene.rootNode.childNodes {
                prototype.addChildNode(child.clone())
            }
            prototype.enumerateChildNodes { node, _ in
                node.castsShadow = true
                node.geometry?.materials.forEach { material in
                    material.lightingModel = .physicallyBased
                    material.isDoubleSided = true
                    material.readsFromDepthBuffer = true
                    material.writesToDepthBuffer = true
                    material.roughness.intensity = max(0.28, material.roughness.intensity)
                    self.configureImportedTextureSampling(material)
                }
            }
            shopMeshyPropPrototypes[resourceName] = prototype
        }

        guard let prop = shopMeshyPropPrototypes[resourceName]?.clone() else { return nil }
        let (minimum, maximum) = prop.boundingBox
        let largest = max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
        guard largest > 0.0001 else { return prop }
        let scale = targetLargestDimension / largest
        prop.scale = SCNVector3(scale, scale, scale)
        prop.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -(minimum.y + maximum.y) * 0.5 * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )
        return prop
    }

    private func configureImportedTextureSampling(_ material: SCNMaterial) {
        let properties = [
            material.diffuse,
            material.normal,
            material.roughness,
            material.metalness,
            material.ambientOcclusion,
            material.emission
        ]
        for property in properties {
            property.minificationFilter = .linear
            property.magnificationFilter = .linear
            property.mipFilter = .linear
            property.maxAnisotropy = 16
        }
    }

    /// Preserve Meshy's authored maps while making their fine engraving and
    /// leather/paper relief survive the small on-shelf presentation. This is
    /// a material-response adjustment only; no generated pattern or flat
    /// replacement artwork is introduced.
    private func enhanceShopBoardMaterials(_ board: SCNNode) {
        board.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach { material in
                // Preserve the 4K albedo/normal detail instead of letting the
                // warm practicals bleach ivory, brass and porcelain into the
                // same white square. Higher roughness gives the mockup's soft
                // hand-finished highlights while the real mesh relief remains.
                material.diffuse.intensity = 0.84
                material.normal.intensity = 1.22
                material.ambientOcclusion.intensity = 1.20
                material.roughness.intensity = 1.15
                material.metalness.intensity = 0.85
            }
        }
    }

    /// Fits the actual Meshy board to one exact physical box. Every catalog
    /// asset therefore has the same width, height and thickness even when the
    /// provider exported different source bounds.
    private func fitShopBoardComponent(_ component: SCNNode,
                                       physicalSize: Float,
                                       physicalDepth: Float) -> Bool {
        let (minimum, maximum) = component.boundingBox
        let sourceWidth = maximum.x - minimum.x
        let sourceHeight = maximum.y - minimum.y
        let sourceDepth = maximum.z - minimum.z
        guard sourceWidth > 0.0001,
              sourceHeight > 0.0001,
              sourceDepth > 0.0001
        else { return false }

        let xScale = physicalSize / sourceWidth
        let yScale = physicalSize / sourceHeight
        let zScale = physicalDepth / sourceDepth
        component.scale = SCNVector3(xScale, yScale, zScale)
        component.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * xScale,
            -(minimum.y + maximum.y) * 0.5 * yScale,
            -(minimum.z + maximum.z) * 0.5 * zScale
        )
        return true
    }

    /// Builds every merchandised board through one geometry path. There is no
    /// shared green holder or backing card: the real Meshy asset itself fills
    /// the complete square and is normalized to the same 3D dimensions.
    private func makeUniformShopBoardMerchandise(resourceName: String,
                                                 title: String,
                                                 subtitle: String,
                                                 frameSize: Float,
                                                 counterDepth: Float) -> SCNNode? {
        guard let surface = makeMeshyShopProp(
            resourceName: resourceName,
            targetLargestDimension: frameSize
        )
        else { return nil }

        let uniformDepth = frameSize * 0.055
        guard fitShopBoardComponent(
            surface,
            physicalSize: frameSize,
            physicalDepth: uniformDepth
        ) else { return nil }

        let mountingZ = counterDepth * 0.020
        surface.name = "meshy-shop-board-physical-body"
        surface.position.z += mountingZ
        enhanceShopBoardMaterials(surface)
        surface.enumerateChildNodes { node, _ in
            // These boards sit almost flush to the cabinet backing. Their
            // tiny relief shadows are invisible at shelf scale but previously
            // replayed hundreds of thousands of triangles into every shadow
            // map. The selected full-size clone re-enables shadows below.
            node.castsShadow = false
        }

        let physicalBody = SCNNode()
        physicalBody.name = "shop-board-physical-body"
        physicalBody.addChildNode(surface)

        let product = SCNNode()
        product.name = "shop-board-shelf:\(resourceName)"
        product.addChildNode(physicalBody)

        #if DEBUG
        let physicalBounds = physicalBody.boundingBox
        let physicalWidth = physicalBounds.max.x - physicalBounds.min.x
        let physicalHeight = physicalBounds.max.y - physicalBounds.min.y
        let physicalThickness = physicalBounds.max.z - physicalBounds.min.z
        assert(abs(physicalWidth - frameSize) < 0.0005,
               "Every shop board must have the same physical width")
        assert(abs(physicalHeight - frameSize) < 0.0005,
               "Every shop board must have the same physical height")
        assert(abs(physicalThickness - uniformDepth) < 0.0005,
               "Every shop board must have the same physical thickness")
        #endif

        let label = makeShopBoardLabel(
            title: title,
            subtitle: subtitle,
            width: frameSize * 0.94
        )
        label.position = SCNVector3(
            0,
            -frameSize * 0.70,
            counterDepth * 0.028
        )
        product.addChildNode(label)
        return product
    }

    /// Builds the mockup's lower merchandising tier from a real Meshy product
    /// box plus a real, uniformly fitted board preview. A hidden full-size
    /// board body remains attached to the merchandise node solely as the
    /// canonical object promoted to the selling platform; the visible shelf
    /// presentation is the authored bottle-green package, not a fake backing
    /// card or a second exposed board row.
    private func makeBoxedShopBoardMerchandise(resourceName: String,
                                               title: String,
                                               subtitle: String,
                                               boardPhysicalSize: Float,
                                               boxWidth: Float,
                                               boxHeight: Float,
                                               counterDepth: Float) -> SCNNode? {
        guard let boardSurface = makeMeshyShopProp(
            resourceName: resourceName,
            targetLargestDimension: boardPhysicalSize
        ) else { return nil }

        let uniformDepth = boardPhysicalSize * 0.055
        guard fitShopBoardComponent(
            boardSurface,
            physicalSize: boardPhysicalSize,
            physicalDepth: uniformDepth
        ) else { return nil }
        enhanceShopBoardMaterials(boardSurface)

        // This source body is never shown on the shelf. Keeping it at the
        // same exact dimensions as the four upper boards guarantees that a
        // lower-tier selection arrives on the plinth at the canonical size.
        let physicalBody = SCNNode()
        physicalBody.name = "shop-board-physical-body"
        // Opacity keeps the canonical body out of the shelf render while
        // preserving its transformed bounding box for debug invariants and
        // platform fitting. SceneKit reports an empty/unstable aggregate box
        // for a hidden parent during scene construction.
        physicalBody.opacity = 0
        physicalBody.categoryBitMask = 0
        physicalBody.addChildNode(boardSurface)

        let product = SCNNode()
        product.name = "shop-board-shelf:\(resourceName)"
        product.addChildNode(physicalBody)

        let boxDepth = boxWidth * 0.12
        guard let box = makeMeshyShopProp(
            resourceName: "MeshyShopProductBox",
            targetLargestDimension: boxHeight
        ) else { return nil }
        let (boxMinimum, boxMaximum) = box.boundingBox
        let sourceWidth = boxMaximum.x - boxMinimum.x
        let sourceHeight = boxMaximum.y - boxMinimum.y
        let sourceDepth = boxMaximum.z - boxMinimum.z
        guard sourceWidth > 0.0001,
              sourceHeight > 0.0001,
              sourceDepth > 0.0001
        else { return nil }
        box.scale = SCNVector3(
            boxWidth / sourceWidth,
            boxHeight / sourceHeight,
            boxDepth / sourceDepth
        )
        box.position = SCNVector3(
            -(boxMinimum.x + boxMaximum.x) * 0.5 * box.scale.x,
            -(boxMinimum.y + boxMaximum.y) * 0.5 * box.scale.y,
            -(boxMinimum.z + boxMaximum.z) * 0.5 * box.scale.z
        )
        box.name = "meshy-shop-product-box:\(resourceName)"
        box.enumerateChildNodes { node, _ in
            node.categoryBitMask = 2
            node.castsShadow = true
            node.geometry?.materials.forEach { material in
                // Preserve the package's leather grain and aged-brass piping
                // while avoiding the pale mint cast of the raw provider render.
                material.multiply.contents = UIColor(
                    red: 0.50,
                    green: 0.58,
                    blue: 0.50,
                    alpha: 1
                )
                material.diffuse.intensity = 0.72
                material.normal.intensity = 1.18
                material.roughness.intensity = 1.22
                material.metalness.intensity = 0.82
            }
        }
        product.addChildNode(box)

        // Reuse the exact selected board geometry for the inset preview, then
        // fit every preview to one shared window. Source-export dimensions can
        // no longer make one catalog item appear physically larger than another.
        let preview = physicalBody.clone()
        preview.name = "shop-box-board-preview"
        preview.opacity = 1
        preview.categoryBitMask = 2
        let previewSize = boxWidth * 0.54
        let previewScale = previewSize / boardPhysicalSize
        preview.scale = SCNVector3(previewScale, previewScale, previewScale)
        preview.position = SCNVector3(
            0,
            boxHeight * 0.075,
            boxDepth * 0.57 + counterDepth * 0.006
        )
        preview.enumerateChildNodes { node, _ in
            node.categoryBitMask = 2
            node.castsShadow = false
        }
        product.addChildNode(preview)

        let copy = makeShopBoxLabel(
            title: title,
            subtitle: subtitle,
            width: boxWidth * 0.53
        )
        copy.name = "shop-product-box-copy:\(title.lowercased())"
        copy.position = SCNVector3(
            0,
            -boxHeight * 0.355,
            boxDepth * 0.58 + counterDepth * 0.008
        )
        product.addChildNode(copy)

        #if DEBUG
        let physicalBounds = physicalBody.boundingBox
        assert(abs((physicalBounds.max.x - physicalBounds.min.x) - boardPhysicalSize) < 0.0005,
               "Boxed shop boards must retain the canonical physical width")
        assert(abs((physicalBounds.max.y - physicalBounds.min.y) - boardPhysicalSize) < 0.0005,
               "Boxed shop boards must retain the canonical physical height")
        assert(abs((physicalBounds.max.z - physicalBounds.min.z) - uniformDepth) < 0.0005,
               "Boxed shop boards must retain the canonical physical thickness")
        #endif
        return product
    }

    /// The mockup is framed by a real bookstore, not a flat brown void. The
    /// tall Meshy bookcases stay recessed behind the counter while separately
    /// authored lamp and globe props occupy the narrow visible side margins.
    /// Keeping these pieces independent avoids exposing an oversized bookcase
    /// post merely to make one small prop visible.
    private func addShopBackdropDressing(to counter: SCNNode) {
        guard let bounds = importedShopCounterSourceBounds else { return }

        let backdrop = SCNNode()
        backdrop.name = "meshy-shop-library-backdrop"
        counter.addChildNode(backdrop)

        let libraryHeight = bounds.height * 0.88
        let libraryRearZ = bounds.minimum.z - max(bounds.depth * 0.15, 0.075)
        let libraryCenterY = bounds.minimum.y + bounds.height * 0.51

        if let leftLibrary = makeMeshyShopProp(
            resourceName: "MeshyShopLibraryLeft",
            targetLargestDimension: libraryHeight
        ) {
            let fixture = SCNNode()
            fixture.name = "meshy-shop-library-left"
            fixture.position = SCNVector3(
                bounds.centerX - bounds.width * 0.70,
                libraryCenterY,
                libraryRearZ
            )
            fixture.addChildNode(leftLibrary)
            backdrop.addChildNode(fixture)
        }

        if let rightLibrary = makeMeshyShopProp(
            resourceName: "MeshyShopLibraryRight",
            targetLargestDimension: libraryHeight
        ) {
            let fixture = SCNNode()
            fixture.name = "meshy-shop-library-right"
            fixture.position = SCNVector3(
                bounds.centerX + bounds.width * 0.70,
                libraryCenterY,
                libraryRearZ
            )
            fixture.addChildNode(rightLibrary)
            backdrop.addChildNode(fixture)
        }

        // These are real Meshy meshes, not composited decorations. Their
        // lower halves tuck behind the cabinet stiles so the lamp and globe
        // appear to rest on furniture just outside the central display bay.
        let sidePropY = bounds.minimum.y + bounds.height * 0.66
        let sidePropZ = bounds.minimum.z - max(bounds.depth * 0.07, 0.035)
        if let lamp = makeMeshyShopProp(
            resourceName: "MeshyShopSideLamp",
            targetLargestDimension: bounds.height * 0.18
        ) {
            let fixture = SCNNode()
            fixture.name = "meshy-shop-side-lamp"
            fixture.position = SCNVector3(
                bounds.centerX - bounds.width * 0.54,
                sidePropY,
                sidePropZ
            )
            fixture.addChildNode(lamp)
            backdrop.addChildNode(fixture)
        }

        if let globe = makeMeshyShopProp(
            resourceName: "MeshyShopSideGlobe",
            targetLargestDimension: bounds.height * 0.16
        ) {
            let fixture = SCNNode()
            fixture.name = "meshy-shop-side-globe"
            fixture.position = SCNVector3(
                bounds.centerX + bounds.width * 0.56,
                sidePropY,
                sidePropZ
            )
            fixture.addChildNode(globe)
            backdrop.addChildNode(fixture)
        }
    }

    private func makeMeshyShopPendant(targetLargestDimension: Float) -> SCNNode? {
        if shopMeshyPendantPrototype == nil,
           let url = Bundle.main.url(forResource: "MeshyShopPendant", withExtension: "usdz"),
           let authoredScene = try? SCNScene(url: url) {
            let prototype = SCNNode()
            for child in authoredScene.rootNode.childNodes {
                prototype.addChildNode(child.clone())
            }
            prototype.enumerateChildNodes { node, _ in
                node.castsShadow = true
                node.renderingOrder = 4
                node.geometry?.materials.forEach { material in
                    // Preserve Meshy's authored PBR response. The bulb mask
                    // below only powers the emitter region; the shade and
                    // brass still respond to the physical scene lighting.
                    material.lightingModel = .physicallyBased
                    material.roughness.intensity = max(0.46, material.roughness.intensity)
                    material.isDoubleSided = true
                    material.readsFromDepthBuffer = true
                    material.writesToDepthBuffer = true
                    self.configureImportedTextureSampling(material)
                }
            }
            prototype.enumerateChildNodes { node, _ in
                guard node.geometry != nil else { return }
                self.applyMeshyBulbEmissiveMask(
                    to: node,
                    objectSpaceCenter: self.meshyPendantBulbCenter,
                    objectSpaceHalfExtents: self.meshyPendantBulbHalfExtents,
                    emissiveColor: SCNVector3(1.0, 0.60, 0.20)
                )
            }
            shopMeshyPendantPrototype = prototype
        }

        guard let pendant = shopMeshyPendantPrototype?.clone() else { return nil }
        let (minimum, maximum) = pendant.boundingBox
        let largest = max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
        guard largest > 0.0001 else { return pendant }

        let scale = targetLargestDimension / largest
        pendant.scale = SCNVector3(scale, scale, scale)
        pendant.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -(minimum.y + maximum.y) * 0.5 * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )
        return pendant
    }

    private func makeMeshyShopPictureLight(targetLargestDimension: Float) -> SCNNode? {
        if shopMeshyPictureLightPrototype == nil,
           let url = Bundle.main.url(forResource: "MeshyShopPictureLight", withExtension: "usdz"),
           let authoredScene = try? SCNScene(url: url) {
            let prototype = SCNNode()
            for child in authoredScene.rootNode.childNodes {
                prototype.addChildNode(child.clone())
            }
            prototype.enumerateChildNodes { node, _ in
                node.castsShadow = true
                node.renderingOrder = 4
                node.geometry?.materials.forEach { material in
                    // Keep the authored brass/diffuser PBR maps so the fixture
                    // has the same material depth as the illuminated cabinet.
                    material.lightingModel = .physicallyBased
                    material.diffuse.intensity = 1.10
                    material.ambientOcclusion.intensity = 0.62
                    material.normal.intensity = 1.08
                    material.metalness.intensity = 1.10
                    material.roughness.intensity = max(0.38, material.roughness.intensity)
                    // A spotlight cannot illuminate geometry behind its own
                    // optical axis. Feed a restrained amount of the authored
                    // brass albedo back into the fixture surface so the real
                    // housing reflects its powered diffuser instead of reading
                    // as a black rectangle. The actual scene illumination still
                    // comes exclusively from the three SCNLight children.
                    material.emission.contents = material.diffuse.contents
                    material.emission.intensity = 0.055
                    material.isDoubleSided = true
                    material.readsFromDepthBuffer = true
                    material.writesToDepthBuffer = true
                    self.configureImportedTextureSampling(material)
                }
            }
            prototype.enumerateChildNodes { node, _ in
                guard node.geometry != nil else { return }
                self.applyMeshyBulbEmissiveMask(
                    to: node,
                    objectSpaceCenter: self.meshyPictureLightDiffuserCenter,
                    objectSpaceHalfExtents: self.meshyPictureLightDiffuserHalfExtents,
                    emissiveColor: SCNVector3(1.0, 0.68, 0.28)
                )
            }
            shopMeshyPictureLightPrototype = prototype
        }

        guard let pictureLight = shopMeshyPictureLightPrototype?.clone() else { return nil }
        let (minimum, maximum) = pictureLight.boundingBox
        let largest = max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
        guard largest > 0.0001 else { return pictureLight }

        let scale = targetLargestDimension / largest
        pictureLight.scale = SCNVector3(scale, scale, scale)
        pictureLight.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -(minimum.y + maximum.y) * 0.5 * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )
        return pictureLight
    }

    private func addBoardHeader(to counter: SCNNode) {
        guard let bounds = importedShopCounterSourceBounds else { return }

        let frontZ = bounds.maximum.z + max(bounds.depth * 0.055, 0.025)
        let headerY = bounds.minimum.y + bounds.height * 0.85

        // Mount the audited Meshy bottle-green plaque inside the counter's
        // existing architectural surround. The imported counter's native
        // center is nearly black; this real shallow plaque supplies the green
        // leather/enamel field, beveled walnut and brass lip seen in the
        // reference while the counter remains the structural frame.
        if let plaque = makeMeshyShopProp(
            resourceName: "MeshyShopHeaderPlaque",
            targetLargestDimension: bounds.width * 0.64
        ) {
            plaque.name = "meshy-shop-board-header-plaque"
            plaque.position = SCNVector3(
                bounds.centerX,
                headerY,
                frontZ + bounds.depth * 0.018
            )
            plaque.scale.y *= 0.84
            plaque.enumerateChildNodes { node, _ in
                node.castsShadow = true
                node.geometry?.materials.forEach { material in
                    // Preserve the authored walnut, brass and bottle-green
                    // separation while softening the nearby practicals.
                    material.multiply.contents = UIColor(white: 0.58, alpha: 1)
                    material.diffuse.intensity = 0.68
                    material.normal.intensity = 0.90
                    material.ambientOcclusion.intensity = 0.88
                    material.roughness.intensity = 1.35
                    material.metalness.intensity = 0.45
                }
            }
            counter.addChildNode(plaque)
        }

        // Product names are permitted dynamic copy. A high-resolution print
        // layer is sharper and much cheaper than an extruded SCNText mesh, and
        // it cannot flare white under the pendant specular highlight.
        let titleFormat = UIGraphicsImageRendererFormat()
        titleFormat.opaque = false
        titleFormat.scale = 1
        let titleImage = UIGraphicsImageRenderer(
            size: CGSize(width: 1024, height: 300),
            format: titleFormat
        ).image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            shadow.shadowBlurRadius = 8
            shadow.shadowOffset = CGSize(width: 0, height: 4)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Georgia-Bold", size: 190)
                    ?? .boldSystemFont(ofSize: 190),
                .foregroundColor: UIColor(red: 0.88, green: 0.61, blue: 0.21, alpha: 1),
                .paragraphStyle: paragraph,
                .shadow: shadow,
            ]
            NSAttributedString(string: "Board", attributes: attributes).draw(
                in: CGRect(x: 0, y: 30, width: 1024, height: 240)
            )
        }
        let titleMaterial = SCNMaterial()
        titleMaterial.lightingModel = .constant
        titleMaterial.diffuse.contents = titleImage
        titleMaterial.diffuse.minificationFilter = .linear
        titleMaterial.diffuse.magnificationFilter = .linear
        titleMaterial.diffuse.mipFilter = .linear
        titleMaterial.transparencyMode = .aOne
        titleMaterial.isDoubleSided = true
        titleMaterial.readsFromDepthBuffer = true
        titleMaterial.writesToDepthBuffer = false

        let titlePlane = SCNPlane(
            width: CGFloat(bounds.width * 0.19),
            height: CGFloat(bounds.width * 0.056)
        )
        titlePlane.firstMaterial = titleMaterial
        let title = SCNNode(geometry: titlePlane)
        title.name = "shop-header-title"
        title.renderingOrder = 31
        title.position = SCNVector3(
            bounds.centerX,
            headerY,
            frontZ + bounds.depth * 0.060
        )
        title.castsShadow = false
        counter.addChildNode(title)
    }

    private func addBoardShelf(to counter: SCNNode) {
        guard let bounds = importedShopCounterSourceBounds else { return }

        // The shop camera looks along the counter's local +Z axis. The old
        // implementation mounted this row behind `minimum.z` and then forced
        // it through the cabinet with depth testing disabled. Mount it on the
        // actual front face so the board meshes enter SceneKit's light pass.
        let frontZ = bounds.maximum.z + max(bounds.depth * 0.055, 0.025)
        let shelf = SCNNode()
        shelf.name = "shop-board-shelf"
        let rowCenterY = bounds.minimum.y + bounds.height * 0.745
        shelf.position = SCNVector3(
            bounds.centerX,
            rowCenterY,
            frontZ
        )
        // Each visible item remains its authored Meshy board, but every source
        // is fitted to the same physical box below. This keeps the artwork and
        // real bevels while removing source-export size differences.
        let topBoardResources = [
            "MeshyShopClassicV3",
            "MeshyShopStargazerEdition",
            "MeshyShopBotanicaEdition",
            "MeshyShopScribesEdition"
        ]
        let topBoardLabels = [
            ("CLASSIC", "IVORY & BRASS"),
            ("STARGAZER", "MIDNIGHT BLUE"),
            ("BOTANICA", "BOTTLE GREEN"),
            ("SCRIBES", "MANUSCRIPT")
        ]
        let lowerBoardResources = [
            "MeshyShopMidnightV3",
            "MeshyShopGoldenV3",
            "MeshyShopNeonV3",
            "MeshyShopPorcelainV2"
        ]
        let lowerBoardLabels = [
            ("MIDNIGHT", "LUNAR OBSIDIAN"),
            ("GOLDEN", "BOTANICAL BRASS"),
            ("NEON", "MALACHITE INLAY"),
            ("PORCELAIN", "COBALT & IVORY")
        ]
        // Four equal centers across the real inner cabinet opening. At this
        // spacing the outside frame edges remain symmetric with the visible
        // left and right stiles instead of bunching near the middle.
        let spacing = bounds.width * 0.190
        let frameSize = bounds.width * 0.165
        let merchandiseDepth = bounds.depth * 0.018
        for (index, resourceName) in topBoardResources.enumerated() {
            guard let board = makeUniformShopBoardMerchandise(
                resourceName: resourceName,
                title: topBoardLabels[index].0,
                subtitle: topBoardLabels[index].1,
                frameSize: frameSize,
                counterDepth: bounds.depth
            ) else { continue }
            board.position = SCNVector3(
                (Float(index) - 1.5) * spacing,
                0,
                merchandiseDepth
            )
            shelf.addChildNode(board)
        }

        // Match the mockup's product hierarchy: four framed boards above and
        // four boxed editions below. The package is real Meshy geometry and
        // each inset is a normalized clone of the corresponding real board.
        let productRowY = bounds.minimum.y + bounds.height * 0.575 - rowCenterY
        let boxWidth = frameSize * 0.90
        let boxHeight = frameSize * 1.24
        for (index, resourceName) in lowerBoardResources.enumerated() {
            let x = (Float(index) - 1.5) * spacing
            guard let product = makeBoxedShopBoardMerchandise(
                resourceName: resourceName,
                title: lowerBoardLabels[index].0,
                subtitle: lowerBoardLabels[index].1,
                boardPhysicalSize: frameSize,
                boxWidth: boxWidth,
                boxHeight: boxHeight,
                counterDepth: bounds.depth
            ) else { continue }
            product.position = SCNVector3(x, productRowY, merchandiseDepth)
            shelf.addChildNode(product)
        }

        if let lowerShelf = makeMeshyShopProp(
            resourceName: "MeshyShopDisplayShelf",
            targetLargestDimension: bounds.width * 0.75
        ) {
            let lowerShelfFixture = SCNNode()
            lowerShelfFixture.name = "meshy-shop-lower-display-shelf"
            lowerShelfFixture.position = SCNVector3(
                0,
                bounds.minimum.y + bounds.height * 0.505 - rowCenterY,
                bounds.depth * 0.008
            )
            // Meshy's shelf includes realistic front-to-back mass, but the
            // counter needs the mockup's slim display rail. Keep the authored
            // mesh and material while fitting that rail to this cabinet bay.
            lowerShelfFixture.scale = SCNVector3(1, 0.42, 0.16)
            lowerShelfFixture.addChildNode(lowerShelf)
            shelf.addChildNode(lowerShelfFixture)
        }

        counter.addChildNode(shelf)
        shopBoardShelfNode = shelf

        // The platform starts truly empty. This stable container receives a
        // clone of the exact physical board the player taps; there is no
        // generic or duplicated display-board asset hiding here.
        let displayBoard = SCNNode()
        displayBoard.name = "shop-board-display"
        let displayPosition = SCNVector3(
            // The board sits forward of the turntable face. Compensate for
            // the shop's fixed oblique camera so its visual center lands on
            // the center of the selling platform.
            bounds.centerX + bounds.width * 0.017,
            bounds.minimum.y + bounds.height * 0.52,
            frontZ + bounds.depth * 0.10
        )
        displayBoard.position = displayPosition
        displayBoard.isHidden = true
        counter.addChildNode(displayBoard)
        shopBoardDisplayNode = displayBoard
        shopBoardDisplayHomePosition = displayBoard.position
        shopBoardDisplayTargetSize = bounds.width * 0.24
    }

    /// Promotes the tapped physical shelf board to the selling platform. The
    /// label stays mounted on the shelf; only the real Meshy board body moves
    /// into the close-up, preserving that product's geometry and PBR maps.
    private func configureShopBoardDisplay(from merchandise: SCNNode) {
        guard let display = shopBoardDisplayNode,
              let sourceBody = merchandise.childNode(
                withName: "shop-board-physical-body",
                recursively: false
              )
        else { return }

        display.childNodes.forEach { $0.removeFromParentNode() }
        let body = sourceBody.clone()
        body.name = "shop-board-selected-physical-body"
        body.isHidden = false
        body.opacity = 1
        body.categoryBitMask = 2
        let (minimum, maximum) = body.boundingBox
        let width = maximum.x - minimum.x
        let height = maximum.y - minimum.y
        let largest = max(width, height)
        guard largest > 0.0001 else { return }

        let scale = shopBoardDisplayTargetSize / largest
        body.scale = SCNVector3(scale, scale, scale)
        body.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -(minimum.y + maximum.y) * 0.5 * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )
        body.enumerateChildNodes { node, _ in
            node.categoryBitMask = 2
            node.castsShadow = true
        }
        display.addChildNode(body)
    }

    private func makeShopBoardLabel(title: String, subtitle: String, width: Float) -> SCNNode {
        let label = SCNNode()
        label.name = "shop-board-label:\(title.lowercased())"

        if let plate = makeMeshyShopProp(
            resourceName: "MeshyShopNameplate",
            targetLargestDimension: width
        ) {
            plate.enumerateChildNodes { node, _ in
                node.geometry?.materials.forEach { material in
                    // The reference uses restrained bottle-green plaques with
                    // thin brass edges; the typography, not the whole plate,
                    // should carry the visual highlight.
                    material.diffuse.intensity = 0.52
                    material.multiply.contents = UIColor(white: 0.42, alpha: 1)
                    material.emission.contents = UIColor.black
                    material.emission.intensity = 0
                    material.roughness.intensity = 1.28
                    material.metalness.intensity = 0.65
                }
            }
            label.addChildNode(plate)
        }

        // Product names/descriptions are allowed dynamic copy, but the old
        // extruded glyphs intersected Meshy's irregular green inset and showed
        // the plate through their faces. A transparent two-line print layer
        // keeps the real Meshy brass plate underneath while producing the
        // crisp gold typography seen in the reference.
        let copyMaterial = SCNMaterial()
        // The plate and its brass fasteners remain physically lit. Keep the
        // printed copy color-managed so the two tiny lines retain the same
        // legibility as the reference at phone scale instead of disappearing
        // in the plaque's shadow.
        copyMaterial.lightingModel = .constant
        copyMaterial.diffuse.contents = shopBoardLabelTexture(
            title: title,
            subtitle: subtitle
        )
        copyMaterial.diffuse.minificationFilter = .linear
        copyMaterial.diffuse.magnificationFilter = .linear
        copyMaterial.diffuse.mipFilter = .linear
        copyMaterial.transparencyMode = .aOne
        copyMaterial.isDoubleSided = true
        copyMaterial.readsFromDepthBuffer = true
        copyMaterial.writesToDepthBuffer = false

        let copyPlane = SCNPlane(
            width: CGFloat(width * 0.88),
            height: CGFloat(width * 0.235)
        )
        copyPlane.firstMaterial = copyMaterial
        let copy = SCNNode(geometry: copyPlane)
        copy.name = "shop-board-label-copy"
        copy.renderingOrder = 30
        copy.position = SCNVector3(0, -width * 0.004, width * 0.325)
        label.addChildNode(copy)
        return label
    }

    private func shopBoardLabelTexture(title: String, subtitle: String) -> UIImage {
        let key = "\(title)|\(subtitle)"
        if let cached = shopBoardLabelTextureCache[key] { return cached }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 1024, height: 256),
            format: format
        ).image { _ in
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            let titleFont = UIFont(name: "Georgia-Bold", size: 128)
                ?? .boldSystemFont(ofSize: 128)
            let subtitleFont = UIFont(name: "AvenirNext-DemiBold", size: 72)
                ?? .systemFont(ofSize: 72, weight: .semibold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor(red: 0.97, green: 0.76, blue: 0.34, alpha: 1),
                .paragraphStyle: centered,
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor(red: 0.88, green: 0.68, blue: 0.31, alpha: 1),
                .paragraphStyle: centered,
                .kern: 1.5,
            ]
            NSAttributedString(string: title, attributes: titleAttributes).draw(
                in: CGRect(x: 0, y: 2, width: 1024, height: 142)
            )
            NSAttributedString(string: subtitle, attributes: subtitleAttributes).draw(
                in: CGRect(x: 0, y: 142, width: 1024, height: 92)
            )
        }
        shopBoardLabelTextureCache[key] = image
        return image
    }

    private func makeShopBoxLabel(title: String, subtitle: String, width: Float) -> SCNNode {
        let label = SCNNode()

        func makeLine(_ string: String,
                      font: UIFont,
                      targetWidth: Float,
                      y: Float) -> SCNNode {
            let geometry = SCNText(string: string, extrusionDepth: 0.0012)
            geometry.font = font
            geometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            geometry.flatness = 0.15
            let material = SCNMaterial()
            material.lightingModel = .constant
            let gold = UIColor(red: 0.84, green: 0.61, blue: 0.23, alpha: 1)
            material.diffuse.contents = gold
            material.readsFromDepthBuffer = true
            material.writesToDepthBuffer = true
            geometry.materials = Array(repeating: material, count: 5)

            let node = SCNNode(geometry: geometry)
            node.renderingOrder = 30
            let bounds = geometry.boundingBox
            let textWidth = max(bounds.max.x - bounds.min.x, 0.001)
            let scale = targetWidth / textWidth
            node.scale = SCNVector3(scale, scale, scale)
            node.position = SCNVector3(
                -(bounds.min.x + bounds.max.x) * 0.5 * scale,
                y - (bounds.min.y + bounds.max.y) * 0.5 * scale,
                0
            )
            return node
        }

        label.addChildNode(makeLine(
            title,
            font: UIFont(name: "Georgia-Bold", size: 1) ?? .boldSystemFont(ofSize: 1),
            targetWidth: width,
            y: width * 0.10
        ))
        label.addChildNode(makeLine(
            subtitle,
            font: UIFont(name: "AvenirNext-DemiBold", size: 1) ?? .systemFont(ofSize: 1, weight: .semibold),
            targetWidth: width * 0.88,
            y: -width * 0.10
        ))
        return label
    }

    private func presentShopBoard() {
        guard let shelfBoard = shopBoardShelfNode, let displayBoard = shopBoardDisplayNode else { return }
        setShopProductFocusLighting(true, animated: true)
        // Inspection is a focus state inside the shop, not a modal replacement
        // scene. Keep the complete collection in the background so the player
        // never loses context when a board moves to the plinth.
        shelfBoard.isHidden = false
        shelfBoard.removeAllActions()
        shelfBoard.runAction(
            // Keep every catalog item fully present during inspection. The
            // fixture rig supplies the quieter focus state; fading the shelf
            // itself made products look as if they had disappeared.
            .fadeOpacity(to: 1, duration: reduceMotion ? 0.01 : 0.24),
            forKey: "board-shelf-focus"
        )
        displayBoard.isHidden = false
        displayBoard.opacity = 0
        displayBoard.runAction(.fadeIn(duration: reduceMotion ? 0.01 : 0.22), forKey: "board-reveal")
        focusCameraOnBoardDisplay()
        startBoardAutoRotation()
    }

    private func dismissShopBoard(_ displayBoard: SCNNode) {
        guard let shelfBoard = shopBoardShelfNode else { return }
        setShopProductFocusLighting(false, animated: true)
        displayBoard.removeAllActions()
        displayBoard.position = shopBoardDisplayHomePosition ?? displayBoard.position
        displayBoard.eulerAngles = SCNVector3Zero
        displayBoard.isHidden = true
        shelfBoard.isHidden = false
        shelfBoard.removeAllActions()
        shelfBoard.runAction(
            .fadeOpacity(to: 1, duration: reduceMotion ? 0.01 : 0.18),
            forKey: "board-shelf-return"
        )

        let pose = resolvedShopPose
        cameraNode.position = cameraNode.presentation.position
        cameraTarget.position = cameraTarget.presentation.position
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0.01 : 0.30
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraTarget.position = pose.target
        cameraNode.camera?.fieldOfView = pose.fieldOfView
        SCNTransaction.commit()
    }

    private func focusCameraOnBoardDisplay() {
        let pose = resolvedShopPose
        cameraNode.position = cameraNode.presentation.position
        cameraTarget.position = cameraTarget.presentation.position
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0.01 : 0.30
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        // Keep the same camera position and scene orientation. A modestly
        // narrower field of view and a lower target put the platform and its
        // board in the visual center rather than altering the shop's rig.
        cameraTarget.position = SCNVector3(pose.target.x, pose.target.y - 0.32, pose.target.z)
        cameraNode.camera?.fieldOfView = max(31.5, pose.fieldOfView - 6.5)
        SCNTransaction.commit()
    }

    private func startBoardAutoRotation() {
        guard let displayBoard = shopBoardDisplayNode else { return }
        displayBoard.removeAction(forKey: "board-auto-spin")
        guard !reduceMotion else { return }
        let turn = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 18)
        displayBoard.runAction(.repeatForever(turn), forKey: "board-auto-spin")
    }

    // Kept only for the unreachable procedural fallback below. The
    // counter-only path returns before that legacy product construction.
    private func makeMeshyShopTurntable() -> SCNNode? {
        makeMeshyShopCounter()
    }

    /// Marks a bounded region of an already-imported Meshy mesh's own
    /// authored surface as a powered light emitter. This is a material
    /// shader mask applied to the mesh's existing single material; it adds
    /// no procedural overlay geometry. The mask runs entirely in the
    /// fragment stage: SceneKit's Metal backend does not wire an ad hoc
    /// `varying` declared in a `.geometry` shader modifier through to a
    /// `.fragment` modifier (it compiles but leaves the identifier
    /// undeclared at the Metal Shading Language level), so this recovers
    /// the fragment's own object-space position by inverse-transforming
    /// SceneKit's built-in per-fragment `_surface.position` (view space)
    /// with the standard `u_inverseModelViewTransform` uniform SceneKit
    /// always provides, instead of interpolating a custom varying.
    /// `objectSpaceCenter` and `objectSpaceHalfExtents` are expressed in
    /// the mesh's own authored (object-space) coordinates, matching the
    /// fixture-local offsets already used to anchor the real SCNLight.
    private func applyMeshyBulbEmissiveMask(to node: SCNNode,
                                             objectSpaceCenter: SCNVector3,
                                             objectSpaceHalfExtents: SCNVector3,
                                             emissiveColor: SCNVector3) {
        func literal(_ value: Float) -> String { String(format: "%.6f", value) }
        let fragmentModifier = """
        vec3 meshyBulbObjectSpacePosition = (u_inverseModelViewTransform * vec4(_surface.position, 1.0)).xyz;
        vec3 meshyBulbCenter = vec3(\(literal(objectSpaceCenter.x)), \(literal(objectSpaceCenter.y)), \(literal(objectSpaceCenter.z)));
        vec3 meshyBulbHalfExtents = vec3(\(literal(objectSpaceHalfExtents.x)), \(literal(objectSpaceHalfExtents.y)), \(literal(objectSpaceHalfExtents.z)));
        vec3 meshyBulbDelta = abs(meshyBulbObjectSpacePosition - meshyBulbCenter);
        vec3 meshyBulbFalloff = vec3(
            1.0 - smoothstep(meshyBulbHalfExtents.x * 0.7, meshyBulbHalfExtents.x, meshyBulbDelta.x),
            1.0 - smoothstep(meshyBulbHalfExtents.y * 0.7, meshyBulbHalfExtents.y, meshyBulbDelta.y),
            1.0 - smoothstep(meshyBulbHalfExtents.z * 0.7, meshyBulbHalfExtents.z, meshyBulbDelta.z)
        );
        float meshyBulbMask = meshyBulbFalloff.x * meshyBulbFalloff.y * meshyBulbFalloff.z;
        vec3 meshyBulbColor = vec3(\(literal(emissiveColor.x)), \(literal(emissiveColor.y)), \(literal(emissiveColor.z)));
        _output.color.rgb = mix(_output.color.rgb, meshyBulbColor, meshyBulbMask);
        _output.color.rgb += meshyBulbColor * meshyBulbMask * 0.6;
        """
        node.geometry?.materials.forEach { material in
            material.shaderModifiers = [.fragment: fragmentModifier]
        }
    }

    private func addImportedShopPendant(to counter: SCNNode) {
        guard let bounds = importedShopCounterSourceBounds else { return }

        let pendantSize = bounds.height * 0.15
        guard let pendant = makeMeshyShopPendant(targetLargestDimension: pendantSize)
        else { return }

        let frontZ = bounds.maximum.z + max(bounds.depth * 0.055, 0.025)

        // All shop lighting now lives in counter-local space. The fixture,
        // its bulb anchor, its SceneKit light and its target therefore share
        // one stable transform and follow the counter as a single assembly.
        let lightRig = SCNNode()
        lightRig.name = "shop-three-fixture-light-rig"
        counter.addChildNode(lightRig)

        // The featured board is physically mounted forward of the imported
        // counter face. Aim at that exact presentation depth; targeting the
        // recessed backing made the beam cross and overexpose the header before
        // it ever reached the platform.
        let platformPresentationZ = frontZ + bounds.depth * 0.12

        let platformTarget = SCNNode()
        platformTarget.name = "shop-pendant-platform-target"
        platformTarget.position = SCNVector3(
            bounds.centerX,
            bounds.minimum.y + bounds.height * 0.48,
            platformPresentationZ
        )
        lightRig.addChildNode(platformTarget)

        let pendantFixture = SCNNode()
        pendantFixture.name = "meshy-shop-pendant-fixture"
        pendantFixture.position = SCNVector3(
            bounds.centerX,
            bounds.minimum.y + bounds.height * 1.01,
            frontZ + bounds.depth * 0.08
        )
        pendantFixture.addChildNode(pendant)
        lightRig.addChildNode(pendantFixture)

        guard let pendantEmitterMesh = pendant.childNode(withName: "mesh1", recursively: true)
        else { return }
        let bulbAnchor = SCNNode()
        bulbAnchor.name = "meshy-shop-pendant-bulb-anchor"
        // Convert the audited bulb point out of Meshy's internal mesh space.
        // The anchor belongs to the stable fixture node so its look-at
        // orientation cannot inherit USD mesh rotation or normalization.
        bulbAnchor.position = pendantFixture.convertPosition(
            meshyPendantLightOrigin,
            from: pendantEmitterMesh
        )
        pendantFixture.addChildNode(bulbAnchor)

        shopPendantLight.type = .spot
        shopPendantLight.color = UIColor(red: 1, green: 0.86, blue: 0.67, alpha: 1)
        shopPendantLight.intensity = 34
        shopPendantLight.attenuationStartDistance = 0.15
        shopPendantLight.attenuationEndDistance = 7.6
        // The pendant carries the central product/platform pool. Keep enough
        // falloff at the edge to reveal the cabinet without clipping the wood.
        shopPendantLight.spotInnerAngle = 86
        shopPendantLight.spotOuterAngle = 132
        shopPendantLight.categoryBitMask = 2
        shopPendantLight.castsShadow = true
        shopPendantLight.shadowMode = .forward
        shopPendantLight.shadowRadius = 4
        shopPendantLight.shadowSampleCount = 4
        shopPendantLight.shadowMapSize = CGSize(width: 1024, height: 1024)
        shopPendantLight.shadowBias = 0.004
        shopPendantLight.shadowColor = UIColor.black.withAlphaComponent(0.12)

        bulbAnchor.light = shopPendantLight
        let pendantAim = SCNLookAtConstraint(target: platformTarget)
        pendantAim.localFront = SCNVector3(0, 0, -1)
        pendantAim.isGimbalLockEnabled = true
        bulbAnchor.constraints = [pendantAim]

        addImportedShopPictureLights(to: lightRig, bounds: bounds, frontZ: frontZ)

        #if DEBUG
        let mountedSpotlights = lightRig.childNodes(passingTest: { node, _ in
            node.light?.type == .spot
        })
        assert(mountedSpotlights.count == 3, "The shop must contain exactly three fixture-mounted spotlights")
        assert(bulbAnchor.parent === pendantFixture,
               "The pendant spotlight anchor must belong to its stable fixture node")
        #endif
    }

    private func addImportedShopPictureLights(to lightRig: SCNNode,
                                               bounds: MeshyAssetBounds,
                                               frontZ: Float) {
        let fixtureSize = bounds.width * 0.18
        let xOffsets: [Float] = [-0.22, 0.22]
        // Match the front depth used by the board/label meshes in
        // `addBoardShelf`; this keeps each bar's optical axis on the products.
        let productPresentationZ = frontZ + bounds.depth * 0.045
        shopPictureLights.removeAll()
        for xOffset in xOffsets {
            guard let fixture = makeMeshyShopPictureLight(
                targetLargestDimension: fixtureSize
            ) else { continue }

            let fixtureNode = SCNNode()
            fixtureNode.name = xOffset < 0
                ? "meshy-shop-picture-light-left-fixture"
                : "meshy-shop-picture-light-right-fixture"
            fixtureNode.position = SCNVector3(
                bounds.centerX + bounds.width * xOffset,
                bounds.minimum.y + bounds.height * 0.94,
                frontZ + bounds.depth * 0.045
            )
            fixtureNode.addChildNode(fixture)
            lightRig.addChildNode(fixtureNode)

            let target = SCNNode()
            target.name = xOffset < 0
                ? "shop-picture-light-left-product-target"
                : "shop-picture-light-right-product-target"
            target.position = SCNVector3(
                bounds.centerX + bounds.width * xOffset * 0.90,
                bounds.minimum.y + bounds.height * 0.665,
                productPresentationZ
            )
            lightRig.addChildNode(target)

            let source = SCNLight()
            source.type = .spot
            source.color = UIColor(red: 1, green: 0.88, blue: 0.70, alpha: 1)
            source.intensity = 12
            source.attenuationStartDistance = 0.12
            source.attenuationEndDistance = 6.8
            // Each bar is a real, fixture-owned product light. A controlled
            // cone keeps its energy on the two merchandise rows instead of
            // blowing out the header bevel above them.
            source.spotInnerAngle = 50
            source.spotOuterAngle = 84
            source.categoryBitMask = 2
            // The pendant owns the one soft hero shadow. Running the entire
            // multi-million-triangle cabinet through two additional picture-
            // light shadow maps added no readable contact detail at phone size
            // and was the dominant browse-frame cost.
            source.castsShadow = false

            let bulbAnchor = SCNNode()
            bulbAnchor.name = xOffset < 0
                ? "meshy-shop-picture-light-left-bulb-anchor"
                : "meshy-shop-picture-light-right-bulb-anchor"
            guard let diffuserMesh = fixture.childNode(withName: "mesh1", recursively: true)
            else { continue }
            // Preserve the authored Meshy emitter location, but move the
            // anchor into the stable fixture coordinate system before aiming.
            bulbAnchor.position = fixtureNode.convertPosition(
                meshyPictureLightOrigin,
                from: diffuserMesh
            )
            bulbAnchor.light = source
            fixtureNode.addChildNode(bulbAnchor)

            let barAim = SCNLookAtConstraint(target: target)
            barAim.localFront = SCNVector3(0, 0, -1)
            barAim.isGimbalLockEnabled = true
            bulbAnchor.constraints = [barAim]
            shopPictureLights.append(source)

            #if DEBUG
            assert(bulbAnchor.parent === fixtureNode,
                   "Each picture-light anchor must belong to its stable fixture node")
            #endif
        }
    }

    @discardableResult
    private func addShopBox(_ size: SCNVector3, at position: SCNVector3,
                            material: SCNMaterial, chamfer: CGFloat = 0) -> SCNNode {
        let box = node(box: size, material: material, chamfer: chamfer)
        box.position = position
        shopRoot.addChildNode(box)
        return box
    }

    @discardableResult
    private func addShopWallBox(_ size: SCNVector3, at position: SCNVector3,
                                material: SCNMaterial, chamfer: CGFloat = 0) -> SCNNode {
        let box = node(box: size, material: material, chamfer: chamfer)
        box.position = position
        shopWallRoot.addChildNode(box)
        return box
    }

    private func addShopNeighborCards() {
        let paper = material(color: rgb(0xD9CDB4), roughness: 0.88)
        for side in [-1 as Float, 1] {
            let card = SCNNode()
            card.name = "shop-step:\(Int(side))"
            card.position = SCNVector3(side * 1.13, 1.73, 0.47)
            card.eulerAngles.y = side * -0.16
            card.eulerAngles.z = side * -0.025
            card.opacity = 0.68
            shopRoot.addChildNode(card)
            shopNeighborNodes.append(card)

            let backing = node(box: SCNVector3(0.58, 0.72, 0.045), material: paper, chamfer: 0.025)
            backing.castsShadow = true
            card.addChildNode(backing)

            let faceMaterial = SCNMaterial()
            faceMaterial.lightingModel = .constant
            faceMaterial.isDoubleSided = true
            faceMaterial.diffuse.contents = neighborSampleTexture(item: nil, direction: Int(side))
            shopNeighborMaterials.append(faceMaterial)
            let face = SCNPlane(width: 0.54, height: 0.68)
            face.firstMaterial = faceMaterial
            let faceNode = SCNNode(geometry: face)
            faceNode.position.z = 0.026
            faceNode.castsShadow = false
            card.addChildNode(faceNode)
        }
    }

    private func neighborSampleTexture(item: CosmeticItem?, direction: Int) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 440, height: 560)).image { context in
            rgb(0xE7DDC9).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 440, height: 560))
            let cg = context.cgContext
            cg.setStrokeColor(rgb(0xA47A3A).cgColor)
            cg.setLineWidth(10)
            cg.stroke(CGRect(x: 18, y: 18, width: 404, height: 524))

            let colour: UIColor
            if let item {
                switch item.category {
                case .paper: colour = UIColor(CosmeticCatalog.paper(item.id).page)
                case .board: colour = UIColor(CosmeticCatalog.board(item.id).given)
                case .numbers: colour = UIColor(CosmeticCatalog.numbers(item.id).givenInk)
                }
            } else {
                colour = rgb(0x82745E)
            }
            colour.setFill()
            context.fill(CGRect(x: 48, y: 62, width: 344, height: 250))
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.20).cgColor)
            cg.setLineWidth(5)
            cg.stroke(CGRect(x: 48, y: 62, width: 344, height: 250))

            drawCentered(item?.name.uppercased() ?? "NEXT SAMPLE",
                         in: CGRect(x: 38, y: 340, width: 364, height: 52),
                         font: .systemFont(ofSize: 29, weight: .bold), color: rgb(0x342E27), kern: 1.2)
            drawCentered(direction < 0 ? "‹  PREVIOUS" : "NEXT  ›",
                         in: CGRect(x: 38, y: 420, width: 364, height: 48),
                         font: .systemFont(ofSize: 24, weight: .semibold), color: rgb(0x9A4E43), kern: 2)
        }
    }

    private func printedShopPlane(width: CGFloat, height: CGFloat, image: UIImage,
                                  position: SCNVector3) -> SCNNode {
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.diffuse.mipFilter = .linear
        material.diffuse.intensity = 1
        // The printed face is mounted on modeled wood/brass backing which
        // receives the real light and casts its contact shadow. Keeping ink
        // print-lit preserves legibility without turning the whole fixture
        // into a flat self-lit panel.
        material.lightingModel = .constant
        material.isDoubleSided = true
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial = material
        let result = SCNNode(geometry: plane)
        result.position = position
        // Printed cards are paper-thin and sit close to the backing. Let the
        // modeled clips, plinths and merchandise cast the lamp shadows; plane
        // shadows become hard opaque rectangles in SceneKit's forward pass.
        result.castsShadow = false
        return result
    }

    /// Builds a paper/brass cabinet fixture with actual thickness. The
    /// returned node is the printed face so its texture can be updated as the
    /// selected product or ownership state changes.
    private func physicalShopCard(width: CGFloat, height: CGFloat, image: UIImage,
                                  position: SCNVector3, paper: SCNMaterial,
                                  brass: SCNMaterial) -> SCNNode {
        let root = SCNNode()
        root.position = position
        shopRoot.addChildNode(root)

        let backing = node(box: SCNVector3(Float(width + 0.05), Float(height + 0.05), 0.055),
                           material: paper, chamfer: 0.018)
        backing.castsShadow = true
        root.addChildNode(backing)

        let faceMaterial = SCNMaterial()
        faceMaterial.lightingModel = .constant
        faceMaterial.diffuse.contents = image
        faceMaterial.diffuse.mipFilter = .linear
        faceMaterial.isDoubleSided = true
        let facePlane = SCNPlane(width: width, height: height)
        facePlane.firstMaterial = faceMaterial
        let face = SCNNode(geometry: facePlane)
        face.position.z = 0.031
        face.castsShadow = false
        root.addChildNode(face)

        for x: Float in [-Float(width) / 2 + 0.07, Float(width) / 2 - 0.07] {
            let pin = SCNSphere(radius: 0.018)
            pin.firstMaterial = brass
            let pinNode = SCNNode(geometry: pin)
            pinNode.position = SCNVector3(x, Float(height) / 2 - 0.07, 0.044)
            root.addChildNode(pinNode)
        }
        return face
    }

    private func addPaperSample(to sample: SCNNode) {
        let paperMaterial = material(color: rgb(0xD8CDB4), roughness: 0.90)
        shopPaperMaterial = paperMaterial
        let stack = SCNNode()
        shopPaperStackNode = stack
        sample.addChildNode(stack)
        for pageIndex in 0..<6 {
            let page = node(box: SCNVector3(0.58, 0.025, 0.72), material: paperMaterial, chamfer: 0.008)
            page.position = SCNVector3(pageIndex.isMultiple(of: 2) ? -0.006 : 0.006,
                                       0.12 + Float(pageIndex) * 0.035, 0)
            page.eulerAngles.y = (Float(pageIndex) - 2.5) * 0.015
            stack.addChildNode(page)
        }
        let bandMaterial = material(color: rgb(0x806D50), roughness: 0.74)
        shopPaperBandMaterial = bandMaterial
        let band = node(box: SCNVector3(0.16, 0.23, 0.75), material: bandMaterial)
        band.position.y = 0.23
        stack.addChildNode(band)

        let topMaterial = SCNMaterial()
        topMaterial.lightingModel = .constant
        topMaterial.isDoubleSided = true
        topMaterial.diffuse.contents = paperStockTexture(
            skin: CosmeticCatalog.paper("pp_ivory"),
            label: "IVORY",
            size: CGSize(width: 520, height: 640)
        )
        shopPaperTopMaterial = topMaterial
        let topPage = SCNPlane(width: 0.52, height: 0.64)
        topPage.firstMaterial = topMaterial
        let topPageNode = SCNNode(geometry: topPage)
        topPageNode.eulerAngles.x = -0.82
        topPageNode.position = SCNVector3(0, 0.50, 0.02)
        topPageNode.castsShadow = false
        stack.addChildNode(topPageNode)

        let roll = SCNNode()
        roll.isHidden = true
        shopPaperRollNode = roll
        sample.addChildNode(roll)
        let rollMaterial = material(color: rgb(0xF3F0E6), roughness: 0.94)
        shopPaperRollMaterial = rollMaterial
        let tube = SCNTube(innerRadius: 0.075, outerRadius: 0.255, height: 0.48)
        tube.radialSegmentCount = 48
        tube.heightSegmentCount = 3
        tube.firstMaterial = rollMaterial
        let tubeNode = SCNNode(geometry: tube)
        tubeNode.eulerAngles.z = .pi / 2
        tubeNode.position = SCNVector3(0, 0.42, 0)
        tubeNode.castsShadow = true
        roll.addChildNode(tubeNode)

        let tail = SCNPlane(width: 0.44, height: 0.46)
        tail.firstMaterial = topMaterial
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(0, 0.25, 0.245)
        tailNode.eulerAngles.x = -0.10
        tailNode.castsShadow = false
        roll.addChildNode(tailNode)
    }

    private func addBoardSample(to sample: SCNNode) {
        let boardMaterial = material(color: rgb(0xE5DCC9), roughness: 0.88)
        let ruleMaterial = material(color: rgb(0x38342E), roughness: 0.67)
        shopBoardMaterial = boardMaterial
        shopBoardRuleMaterial = ruleMaterial
        let board = node(box: SCNVector3(0.68, 0.68, 0.08), material: boardMaterial, chamfer: 0.015)
        board.position.y = 0.42
        sample.addChildNode(board)

        // Four independent outside edges. They remain children of the sample,
        // so no camera or selection transform can drop an edge behind it.
        let border: Float = 0.04
        let edges: [(SCNVector3, SCNVector3)] = [
            (SCNVector3(0.68, border, 0.016), SCNVector3(0, 0.76, 0.052)),
            (SCNVector3(0.68, border, 0.016), SCNVector3(0, 0.08, 0.052)),
            (SCNVector3(border, 0.68, 0.016), SCNVector3(-0.34, 0.42, 0.052)),
            (SCNVector3(border, 0.68, 0.016), SCNVector3(0.34, 0.42, 0.052))
        ]
        for edge in edges {
            let edgeNode = node(box: edge.0, material: ruleMaterial)
            edgeNode.position = edge.1
            sample.addChildNode(edgeNode)
        }
        // Bake the shared gameplay renderer so the showroom has the real 9x9
        // rule spacing, box weights, dashes and optical finish instead of a
        // symbolic pair of bars.
        let gridMaterial = SCNMaterial()
        gridMaterial.lightingModel = .constant
        gridMaterial.isDoubleSided = true
        gridMaterial.diffuse.contents = gridRuleTexture(
            skin: CosmeticCatalog.board("bd_printed"),
            size: CGSize(width: 640, height: 640)
        )
        gridMaterial.transparency = 1
        gridMaterial.transparencyMode = .aOne
        gridMaterial.blendMode = .alpha
        gridMaterial.writesToDepthBuffer = false
        let gridPlane = SCNPlane(width: 0.60, height: 0.60)
        gridPlane.firstMaterial = gridMaterial
        let gridPlaneNode = SCNNode(geometry: gridPlane)
        gridPlaneNode.position = SCNVector3(0, 0.42, 0.045)
        gridPlaneNode.castsShadow = false
        sample.addChildNode(gridPlaneNode)
        shopBoardInternalRules = [gridPlaneNode]

        let givens: [(String, Float, Float)] = [
            ("7", -0.19, 0.61), ("2", 0.19, 0.61),
            ("4", 0, 0.42), ("9", -0.19, 0.23), ("6", 0.19, 0.23)
        ]
        for (digit, x, y) in givens {
            let glyphMaterial = SCNMaterial()
            glyphMaterial.lightingModel = .constant
            glyphMaterial.diffuse.contents = shopGlyphTexture(digit, ink: rgb(0x3B3832))
            glyphMaterial.isDoubleSided = true
            let glyph = SCNPlane(width: 0.105, height: 0.105)
            glyph.firstMaterial = glyphMaterial
            let glyphNode = SCNNode(geometry: glyph)
            glyphNode.position = SCNVector3(x, y, 0.061)
            glyphNode.castsShadow = false
            sample.addChildNode(glyphNode)
        }
    }

    private func addNumberSample(to sample: SCNNode, metal: SCNMaterial) {
        // The merchandise is the number itself. Three freestanding, extruded
        // glyphs replace the former typewriter/keycap prop, which falsely sold
        // a machine instead of the in-game numeral treatment.
        let rail = node(box: SCNVector3(0.66, 0.055, 0.16), material: metal, chamfer: 0.018)
        rail.position = SCNVector3(0, 0.14, 0)
        sample.addChildNode(rail)

        // One cached flame texture is shared by every glyph. The turntable is
        // only the fixture; the merchandise remains the literal digit.
        let flameMaterial = SCNMaterial()
        flameMaterial.lightingModel = .constant
        flameMaterial.diffuse.contents = flameCrownTexture(size: CGSize(width: 200, height: 240))
        flameMaterial.isDoubleSided = true
        flameMaterial.transparency = 1
        flameMaterial.transparencyMode = .aOne
        flameMaterial.blendMode = .add
        flameMaterial.writesToDepthBuffer = false

        var lastGlyphTop: Float = 0
        for (index, digit) in ["2", "7", "9"].enumerated() {
            let glyphMaterial = material(color: rgb(0x34312B), roughness: 0.42, metalness: 0.08)
            glyphMaterial.emission.contents = UIColor.black
            shopNumberGlyphMaterials.append(glyphMaterial)

            let glyph = SCNText(string: digit, extrusionDepth: 2.8)
            glyph.font = numberUIFont(for: .press, size: 100)
            glyph.flatness = 0.12
            glyph.chamferRadius = 0.65
            glyph.chamferProfile = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 1, height: 1))
            glyph.materials = [glyphMaterial]

            let glyphNode = SCNNode(geometry: glyph)
            glyphNode.scale = SCNVector3(0.0035, 0.0035, 0.0035)
            glyphNode.position = SCNVector3(-0.22 + Float(index) * 0.22, 0.19, 0.01)
            glyphNode.castsShadow = true
            centerShopGlyph(glyphNode)
            sample.addChildNode(glyphNode)
            shopNumberGlyphNodes.append(glyphNode)

            let (glyphMin, glyphMax) = glyphNode.boundingBox
            let glyphTop = glyphNode.position.y + (glyphMax.y - glyphMin.y) * glyphNode.scale.y
            lastGlyphTop = glyphTop
            let flamePlane = SCNPlane(width: 0.22, height: 0.30)
            flamePlane.firstMaterial = flameMaterial
            let flameNode = SCNNode(geometry: flamePlane)
            flameNode.position = SCNVector3(
                glyphNode.position.x,
                glyphTop + 0.03,
                glyphNode.position.z + 0.045
            )
            flameNode.renderingOrder = 5
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            flameNode.constraints = [billboard]
            flameNode.castsShadow = false
            flameNode.isHidden = true
            sample.addChildNode(flameNode)
            shopNumberFlameNodes.append(flameNode)
        }

        let sparks = SCNParticleSystem()
        sparks.birthRate = 0
        sparks.particleLifeSpan = 0.6
        sparks.particleLifeSpanVariation = 0.22
        sparks.particleVelocity = 0.13
        sparks.particleVelocityVariation = 0.05
        sparks.spreadingAngle = 16
        sparks.particleSize = 0.012
        sparks.particleSizeVariation = 0.006
        sparks.particleColor = rgb(0xFF8A32)
        sparks.particleColorVariation = SCNVector4(0.08, 0.12, 0.03, 0.14)
        sparks.blendMode = .additive
        sparks.emitterShape = SCNBox(width: 0.5, height: 0.03, length: 0.03, chamferRadius: 0)
        let emitter = SCNNode()
        emitter.position = SCNVector3(0, lastGlyphTop + 0.14, 0.05)
        emitter.addParticleSystem(sparks)
        sample.addChildNode(emitter)
        shopNumberEffectParticles = sparks
        shopNumberEffectEmitterNode = emitter
    }

    private func numberUIFont(for finish: NumberFinish, size: CGFloat) -> UIFont {
        switch finish {
        case .press, .woodType, .flame:
            return UIFont(name: "Georgia-Bold", size: size)
                ?? .systemFont(ofSize: size, weight: .bold)
        case .typewriter, .laser:
            return .monospacedSystemFont(ofSize: size, weight: .semibold)
        case .graphite, .neon:
            let descriptor = UIFont.systemFont(ofSize: size, weight: .semibold)
                .fontDescriptor.withDesign(.rounded)
            return descriptor.map { UIFont(descriptor: $0, size: size) }
                ?? .systemFont(ofSize: size, weight: .semibold)
        case .stencil:
            return UIFont(name: "AvenirNextCondensed-DemiBold", size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: .semibold)
        }
    }

    private func centerShopGlyph(_ node: SCNNode) {
        let (minimum, maximum) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (minimum.x + maximum.x) * 0.5,
            minimum.y,
            (minimum.z + maximum.z) * 0.5
        )
    }

    private func addShopLamp(brass: SCNMaterial, darkMetal: SCNMaterial) {
        let shadeMaterial = material(color: rgb(0x29483C), roughness: 0.54, metalness: 0.12)
        shadeMaterial.isDoubleSided = true
        let shade = SCNCone(topRadius: 0.18, bottomRadius: 0.58, height: 0.44)
        shade.firstMaterial = shadeMaterial
        let shadeNode = SCNNode(geometry: shade)
        shadeNode.position = SCNVector3(0.45, 4.72, 1.18)
        shadeNode.castsShadow = true
        shopRoot.addChildNode(shadeNode)

        let rimGeometry = SCNTorus(ringRadius: 0.58, pipeRadius: 0.028)
        rimGeometry.firstMaterial = brass
        let rim = SCNNode(geometry: rimGeometry)
        rim.position = SCNVector3(0.45, 4.50, 1.18)
        shopRoot.addChildNode(rim)

        let cord = SCNCylinder(radius: 0.012, height: 3.76)
        cord.firstMaterial = darkMetal
        let cordNode = SCNNode(geometry: cord)
        cordNode.position = SCNVector3(0.45, 6.82, 1.18)
        shopRoot.addChildNode(cordNode)

        let canopy = SCNCylinder(radius: 0.18, height: 0.10)
        canopy.firstMaterial = brass
        let canopyNode = SCNNode(geometry: canopy)
        canopyNode.position = SCNVector3(0.45, 8.70, 1.18)
        shopRoot.addChildNode(canopyNode)

        let bulb = SCNSphere(radius: 0.12)
        let bulbMaterial = SCNMaterial()
        bulbMaterial.lightingModel = .constant
        bulbMaterial.diffuse.contents = rgb(0xFFEFD3)
        bulb.firstMaterial = bulbMaterial
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(0.45, 4.48, 1.18)
        shopRoot.addChildNode(bulbNode)

        let target = SCNNode()
        target.position = SCNVector3(0, 1.05, 0.08)
        shopRoot.addChildNode(target)
        let lamp = SCNLight()
        lamp.type = .spot
        lamp.color = UIColor(red: 1, green: 0.97, blue: 0.90, alpha: 1)
        lamp.intensity = 100
        lamp.attenuationStartDistance = 1
        lamp.attenuationEndDistance = 9
        lamp.spotInnerAngle = 26
        lamp.spotOuterAngle = 70
        // Forward shadows are stable on the current iOS renderer (the older
        // deferred path could invalidate the entire frame) and still ground
        // the raised samples on the physical counter.
        lamp.castsShadow = true
        lamp.shadowMode = .forward
        lamp.shadowRadius = 6
        lamp.shadowSampleCount = 8
        lamp.shadowBias = 0.006
        lamp.shadowColor = UIColor.black.withAlphaComponent(0.14)
        lamp.categoryBitMask = 2
        let lampNode = SCNNode()
        lampNode.light = lamp
        lampNode.position = SCNVector3(0.45, 4.48, 1.18)
        let look = SCNLookAtConstraint(target: target)
        look.isGimbalLockEnabled = true
        lampNode.constraints = [look]
        shopRoot.addChildNode(lampNode)

        // A restrained front fill belongs only to category 2, so the hero
        // sample remains readable without lifting the sign or back wall.
        let fillTarget = SCNNode()
        fillTarget.position = SCNVector3(0, 1.62, 0.46)
        shopRoot.addChildNode(fillTarget)
        let fill = SCNLight()
        fill.type = .spot
        fill.color = UIColor(red: 1, green: 0.985, blue: 0.94, alpha: 1)
        fill.intensity = 14
        fill.attenuationStartDistance = 1.2
        fill.attenuationEndDistance = 6.5
        fill.spotInnerAngle = 38
        fill.spotOuterAngle = 78
        fill.categoryBitMask = 2
        fill.castsShadow = false
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(0, 2.70, 3.20)
        let fillLook = SCNLookAtConstraint(target: fillTarget)
        fillLook.isGimbalLockEnabled = true
        fillNode.constraints = [fillLook]
        shopRoot.addChildNode(fillNode)

        // The pendant also throws a broad reflected wash across the bookstore
        // wall. This is real scene light, so the counter stays integrated with
        // its alcove instead of sitting in front of a black backdrop.
        let wallTarget = SCNNode()
        wallTarget.position = SCNVector3(0, 3.45, 0.02)
        shopWallRoot.addChildNode(wallTarget)
        let wallWash = SCNLight()
        wallWash.type = .spot
        wallWash.color = UIColor(red: 1, green: 0.93, blue: 0.84, alpha: 1)
        wallWash.intensity = 12
        wallWash.attenuationStartDistance = 1.0
        wallWash.attenuationEndDistance = 8.0
        wallWash.spotInnerAngle = 56
        wallWash.spotOuterAngle = 104
        wallWash.categoryBitMask = 1
        wallWash.castsShadow = false
        let wallWashNode = SCNNode()
        wallWashNode.light = wallWash
        wallWashNode.position = SCNVector3(0.35, 5.42, 2.20)
        let wallLook = SCNLookAtConstraint(target: wallTarget)
        wallLook.isGimbalLockEnabled = true
        wallWashNode.constraints = [wallLook]
        shopWallRoot.addChildNode(wallWashNode)

        let dust = SCNParticleSystem()
        dust.birthRate = reduceMotion ? 0 : 3
        dust.particleLifeSpan = 7
        dust.particleLifeSpanVariation = 2
        dust.particleSize = 0.012
        dust.particleSizeVariation = 0.006
        dust.particleColor = UIColor(red: 1, green: 0.93, blue: 0.81, alpha: 0.42)
        dust.particleColorVariation = SCNVector4(0.02, 0.02, 0.02, 0.16)
        dust.particleImage = UIImage(systemName: "circle.fill")
        dust.particleVelocity = 0.018
        dust.particleVelocityVariation = 0.012
        dust.spreadingAngle = 18
        dust.acceleration = SCNVector3(0, 0.006, 0)
        dust.birthDirection = .random
        dust.birthLocation = .volume
        dust.emitterShape = SCNCone(topRadius: 0.10, bottomRadius: 1.35, height: 3.10)
        dust.blendMode = .additive
        dust.isLocal = true
        dust.loops = true
        let dustNode = SCNNode()
        dustNode.position = SCNVector3(0.45, 2.78, 0.78)
        dustNode.addParticleSystem(dust)
        shopRoot.addChildNode(dustNode)
        shopDustSystem = dust
        shopDustEmitterNode = dustNode
    }

    private func updateShopShowcaseMotion() {
        let isShopActive = currentPhase == .transitioningToShop || currentPhase == .shopping

        for (category, turntable) in shopTurntableNodes {
            let isSelected = category == selectedShopCategory
            let shouldSpin = isShopActive && isSelected && !reduceMotion
            shopTurntableRingMaterials[category]?.emission.contents = isShopActive && isSelected
                ? rgb(0x7A5827)
                : UIColor.black

            if shouldSpin {
                guard turntable.action(forKey: "shop-turntable-spin") == nil else { continue }
                let visibleYaw = turntable.presentation.eulerAngles.y
                turntable.removeAction(forKey: "shop-turntable-settle")
                turntable.eulerAngles.y = visibleYaw
                if category == .paper && shopPaperIsUtilityRoll {
                    // The roll is cylindrical; a full turn never exposes an
                    // edge-only or blank proof face.
                    let revolution = SCNAction.rotateBy(
                        x: 0,
                        y: CGFloat.pi * 2,
                        z: 0,
                        duration: 10.5
                    )
                    revolution.timingMode = .linear
                    turntable.runAction(.repeatForever(revolution),
                                        forKey: "shop-turntable-spin")
                } else {
                    // Flat proof plates, sheet stacks and readable glyphs use
                    // a showroom sweep rather than exposing a blank edge/back.
                    let left = SCNAction.rotateTo(x: 0, y: -0.38, z: 0,
                                                  duration: 2.8,
                                                  usesShortestUnitArc: true)
                    let right = SCNAction.rotateTo(x: 0, y: 0.38, z: 0,
                                                   duration: 3.4,
                                                   usesShortestUnitArc: true)
                    left.timingMode = .easeInEaseOut
                    right.timingMode = .easeInEaseOut
                    turntable.runAction(.repeatForever(.sequence([left, right])),
                                        forKey: "shop-turntable-spin")
                }
                continue
            }

            if turntable.action(forKey: "shop-turntable-spin") != nil {
                let visibleYaw = turntable.presentation.eulerAngles.y
                turntable.removeAction(forKey: "shop-turntable-spin")
                turntable.eulerAngles.y = visibleYaw
            }

            let restingYaw: Float = isShopActive && isSelected && reduceMotion ? 0.14 : 0
            turntable.removeAction(forKey: "shop-turntable-settle")
            if isShopActive && !reduceMotion {
                let settle = SCNAction.rotateTo(
                    x: 0,
                    y: CGFloat(restingYaw),
                    z: 0,
                    duration: 0.34,
                    usesShortestUnitArc: true
                )
                settle.timingMode = .easeInEaseOut
                turntable.runAction(settle, forKey: "shop-turntable-settle")
            } else {
                turntable.eulerAngles.y = restingYaw
            }
        }

        let numberEffectActive = isShopActive && selectedShopCategory == .numbers
            && shopNumberFinish.isAnimated
        let numberPulseDuration = shopNumberFinish == .flame ? 0.30 : 0.88
        for glyph in shopNumberGlyphNodes {
            if numberEffectActive && !reduceMotion {
                if glyph.action(forKey: "shop-number-pulse") == nil {
                    let dim = SCNAction.fadeOpacity(to: 0.78, duration: numberPulseDuration)
                    dim.timingMode = .easeInEaseOut
                    let bright = SCNAction.fadeOpacity(to: 1, duration: numberPulseDuration * 0.82)
                    bright.timingMode = .easeInEaseOut
                    glyph.runAction(.repeatForever(.sequence([dim, bright])),
                                    forKey: "shop-number-pulse")
                }
            } else {
                glyph.removeAction(forKey: "shop-number-pulse")
                glyph.opacity = 1
            }
        }
        // Flame remains attached at rest; only the flicker stops under Reduce
        // Motion or when Hot Type is not the active selected finish.
        let flameEffectActive = numberEffectActive && shopNumberFinish == .flame
        for flame in shopNumberFlameNodes {
            if flameEffectActive && !flame.isHidden && !reduceMotion {
                if flame.action(forKey: "shop-flame-pulse") == nil {
                    let dim = SCNAction.group([
                        .fadeOpacity(to: 0.74, duration: 0.36),
                        .scale(to: 0.92, duration: 0.36)
                    ])
                    dim.timingMode = .easeInEaseOut
                    let bright = SCNAction.group([
                        .fadeOpacity(to: 1, duration: 0.28),
                        .scale(to: 1.06, duration: 0.28)
                    ])
                    bright.timingMode = .easeInEaseOut
                    flame.runAction(.repeatForever(.sequence([dim, bright])),
                                    forKey: "shop-flame-pulse")
                }
            } else {
                flame.removeAction(forKey: "shop-flame-pulse")
                flame.opacity = 1
                flame.scale = SCNVector3(1, 1, 1)
            }
        }
        for material in shopNumberGlyphMaterials {
            material.emission.intensity = numberEffectActive
                ? (reduceMotion ? 0.48 : 0.82)
                : (shopNumberFinish.glowColor == nil ? 0 : 0.18)
        }
        shopNumberEffectParticles?.birthRate = numberEffectActive
            && shopNumberFinish == .flame && !reduceMotion ? 7 : 0

        let boardEffectActive = isShopActive && selectedShopCategory == .board
            && shopBoardFinish == .laser
        for rule in shopBoardInternalRules {
            if boardEffectActive && !reduceMotion {
                if rule.action(forKey: "shop-grid-pulse") == nil {
                    let dim = SCNAction.fadeOpacity(to: 0.52, duration: 0.9)
                    dim.timingMode = .easeInEaseOut
                    let bright = SCNAction.fadeOpacity(to: 1, duration: 1.12)
                    bright.timingMode = .easeInEaseOut
                    rule.runAction(.repeatForever(.sequence([dim, bright])),
                                   forKey: "shop-grid-pulse")
                }
            } else {
                rule.removeAction(forKey: "shop-grid-pulse")
                rule.opacity = 1
            }
        }
        shopBoardRuleMaterial?.emission.intensity = boardEffectActive
            ? (reduceMotion ? 0.42 : 0.74)
            : (shopBoardFinish.glowColor == nil ? 0 : 0.14)
    }

    private func animateShopProductRefresh(category: CosmeticCategory, animated: Bool) {
        guard let turntable = shopTurntableNodes[category] else { return }
        turntable.removeAction(forKey: "shop-product-refresh")
        turntable.opacity = 1
        turntable.scale = SCNVector3(1, 1, 1)
        guard animated, !reduceMotion else { return }

        let tuck = SCNAction.group([
            .fadeOpacity(to: 0.74, duration: 0.08),
            .scale(to: 0.94, duration: 0.08)
        ])
        tuck.timingMode = .easeIn
        let reveal = SCNAction.group([
            .fadeOpacity(to: 1, duration: 0.26),
            .scale(to: 1, duration: 0.26)
        ])
        reveal.timingMode = .easeOut
        turntable.runAction(.sequence([tuck, reveal]), forKey: "shop-product-refresh")
    }

    private func updateShopSelection(category: CosmeticCategory, item: CosmeticItem?, animated: Bool) {
        let duration = reduceMotion || !animated ? 0.01 : 0.24
        for (candidate, drawer) in shopDrawerNodes {
            let destination = SCNVector3(0, 0, candidate == category ? 0.13 : 0)
            let action = SCNAction.move(to: destination, duration: duration)
            action.timingMode = .easeOut
            drawer.runAction(action, forKey: "drawer-selection")
            shopDrawerLabelMaterials[candidate]?.diffuse.contents = shopDrawerTexture(
                candidate.title.uppercased(), selected: candidate == category
            )
        }
        for (candidate, sample) in shopSampleNodes {
            guard let base = shopSampleBasePositions[candidate] else { continue }
            let selected = candidate == category
            sample.isHidden = false
            // All four physical departments remain on the sales counter like
            // the reference. Selection raises one sample and its drawer; it
            // never replaces the counter with a single floating hero card.
            let destination = selected
                ? SCNVector3(base.x, base.y + 0.16, base.z)
                : base
            let move = SCNAction.move(to: destination,
                                      duration: duration)
            move.timingMode = .easeOut
            let scale = SCNAction.scale(to: selected ? 1.08 : 0.95, duration: duration)
            scale.timingMode = .easeOut
            sample.runAction(.group([move, scale]), forKey: "sample-selection")
            sample.runAction(.fadeOpacity(to: 1, duration: duration),
                             forKey: "sample-emphasis")
        }
        guard let item else { return }
        updateShopSample(category: category, item: item)
        animateShopProductRefresh(category: category, animated: animated)
        shopPriceMaterials[category]?.diffuse.contents = shopPriceTexture(price: item.price)
        updateShopShowcaseMotion()
    }

    private func updateShopPresentation(category: CosmeticCategory, item: CosmeticItem,
                                        state _: BookstoreShopPresentation) {
        // Price stays attached to the physical sample. Product copy and the
        // buy/equip state belong to the approved SwiftUI paper ticket.
        shopPriceMaterials[category]?.diffuse.contents = shopPriceTexture(price: item.price)
    }

    private func updateNeighborCards(category: CosmeticCategory, item: CosmeticItem) {
        let items = CosmeticCatalog.items(in: category)
        guard items.count > 1, let current = items.firstIndex(of: item), shopNeighborMaterials.count == 2 else {
            shopNeighborNodes.forEach { $0.opacity = 0 }
            return
        }
        let previous = items[(current - 1 + items.count) % items.count]
        let next = items[(current + 1) % items.count]
        shopNeighborMaterials[0].diffuse.contents = neighborSampleTexture(item: previous, direction: -1)
        shopNeighborMaterials[1].diffuse.contents = neighborSampleTexture(item: next, direction: 1)
        for node in shopNeighborNodes { node.opacity = 0.62 }
    }

    private func updateShopSample(category: CosmeticCategory, item: CosmeticItem) {
        switch category {
        case .paper:
            let skin = CosmeticCatalog.paper(item.id)
            let isUtilityRoll = skin.treatment == .utilityRoll
            shopPaperIsUtilityRoll = isUtilityRoll
            shopPaperStackNode?.isHidden = isUtilityRoll
            shopPaperRollNode?.isHidden = !isUtilityRoll
            shopPaperMaterial?.diffuse.contents = UIColor(skin.page)
            shopPaperBandMaterial?.diffuse.contents = UIColor(skin.edge)
            shopPaperRollMaterial?.diffuse.contents = UIColor(skin.page)
            shopPaperTopMaterial?.diffuse.contents = paperStockTexture(
                skin: skin,
                label: item.name.uppercased(),
                size: CGSize(width: 520, height: 640)
            )
        case .board:
            let skin = CosmeticCatalog.board(item.id)
            shopBoardFinish = skin.finish
            shopBoardMaterial?.diffuse.contents = UIColor(skin.given.mixed(with: skin.selected, by: 0.12))
            shopBoardRuleMaterial?.diffuse.contents = UIColor(skin.bold)
            shopBoardRuleMaterial?.emission.contents = skin.finish.glowColor.map(UIColor.init) ?? UIColor.black
            shopBoardRuleMaterial?.emission.intensity = skin.finish == .laser ? 0.72 : 0.18
            for rule in shopBoardInternalRules {
                (rule.geometry as? SCNPlane)?.firstMaterial?.diffuse.contents = gridRuleTexture(
                    skin: skin,
                    size: CGSize(width: 640, height: 640)
                )
            }
        case .numbers:
            let skin = CosmeticCatalog.numbers(item.id)
            shopNumberFinish = skin.finish
            let emission = skin.finish.glowColor.map(UIColor.init) ?? UIColor.black
            for material in shopNumberGlyphMaterials {
                material.diffuse.contents = UIColor(skin.ink)
                material.emission.contents = emission
                material.emission.intensity = skin.finish.glowColor == nil ? 0 : 0.78
                material.roughness.contents = skin.finish == .laser ? 0.18 : 0.46
                material.metalness.contents = skin.finish == .laser ? 0.28 : 0.08
            }
            for glyphNode in shopNumberGlyphNodes {
                (glyphNode.geometry as? SCNText)?.font = numberUIFont(for: skin.finish, size: 100)
                centerShopGlyph(glyphNode)
            }
            for flameNode in shopNumberFlameNodes {
                flameNode.isHidden = skin.finish != .flame
            }
            shopNumberEffectParticles?.particleColor = skin.finish == .flame
                ? rgb(0xFF8A32)
                : UIColor.clear
        }
    }

    private func shopSignTexture() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 768, height: 224)).image { context in
            let cg = context.cgContext
            cg.setFillColor(rgb(0x24372F).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: 768, height: 224))
            cg.setStrokeColor(rgb(0xA77B3D).cgColor)
            cg.setLineWidth(8)
            cg.stroke(CGRect(x: 12, y: 12, width: 744, height: 200))
            drawCentered("CLUB SHOP", in: CGRect(x: 0, y: 44, width: 768, height: 72),
                         font: .systemFont(ofSize: 57, weight: .bold), color: rgb(0xEFE4CF))
            drawCentered("THINGS FOR YOUR NEXT BOOK", in: CGRect(x: 0, y: 124, width: 768, height: 32),
                         font: .systemFont(ofSize: 21, weight: .semibold), color: rgb(0xB8C2AA), kern: 2)
        }
    }

    private func shopNoticeTexture() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 192)).image { context in
            rgb(0xDDD2B8).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 192))
            let cg = context.cgContext
            cg.setStrokeColor(rgb(0x9A6D49).cgColor)
            cg.setLineWidth(7)
            cg.stroke(CGRect(x: 12, y: 12, width: 488, height: 168))
            drawCentered("SAMPLES", in: CGRect(x: 0, y: 42, width: 512, height: 46),
                         font: .systemFont(ofSize: 37, weight: .bold), color: rgb(0x4B4337))
            drawCentered("Try them on the page.", in: CGRect(x: 0, y: 94, width: 512, height: 40),
                         font: .italicSystemFont(ofSize: 29), color: rgb(0x4B4337))
        }
    }

    private func hangingSampleTexture(title: String, note: String, mark: String,
                                      paper: UIColor, ink: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 320, height: 440)).image { context in
            paper.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 440))
            let cg = context.cgContext
            cg.setStrokeColor(ink.cgColor)
            cg.setLineWidth(8)
            cg.stroke(CGRect(x: 16, y: 16, width: 288, height: 408))
            drawCentered(title, in: CGRect(x: 0, y: 56, width: 320, height: 58),
                         font: .systemFont(ofSize: 51, weight: .bold), color: ink)
            drawCentered(note, in: CGRect(x: 0, y: 118, width: 320, height: 48),
                         font: .italicSystemFont(ofSize: 37), color: ink)
            drawCentered(mark, in: CGRect(x: 0, y: 198, width: 320, height: 112),
                         font: .systemFont(ofSize: 92, weight: .bold), color: ink.withAlphaComponent(0.55))
            cg.setStrokeColor(ink.withAlphaComponent(0.5).cgColor)
            cg.setLineWidth(5)
            for y in stride(from: 340 as CGFloat, through: 402, by: 24) {
                cg.move(to: CGPoint(x: 45, y: y))
                cg.addLine(to: CGPoint(x: 275, y: y))
            }
            cg.strokePath()
        }
    }

    private func shopDrawerTexture(_ label: String, selected: Bool) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 384, height: 112)).image { context in
            (selected ? rgb(0xE1D5BD) : rgb(0x49301F)).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 384, height: 112))
            let cg = context.cgContext
            cg.setStrokeColor((selected ? rgb(0xA77B3D) : rgb(0x9A7447)).cgColor)
            cg.setLineWidth(selected ? 9 : 5)
            cg.stroke(CGRect(x: 8, y: 8, width: 368, height: 96))
            drawCentered(label, in: CGRect(x: 0, y: 34, width: 384, height: 42),
                         font: .systemFont(ofSize: 31, weight: .bold),
                         color: selected ? rgb(0x302A22) : rgb(0xD8C8AA), kern: 2)
            if selected {
                cg.setFillColor(rgb(0xA77B3D).cgColor)
                cg.fill(CGRect(x: 116, y: 91, width: 152, height: 5))
            }
        }
    }

    private func shopPriceTexture(price: Int) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 320, height: 104)).image { context in
            rgb(0xE1D5BD).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 104))
            let cg = context.cgContext
            cg.setStrokeColor(rgb(0x8F7B59).cgColor)
            cg.setLineWidth(5)
            cg.stroke(CGRect(x: 7, y: 7, width: 306, height: 90))
            let label = price == 0 ? "INCLUDED" : "\(price) STAMPS"
            drawCentered(label, in: CGRect(x: 0, y: 33, width: 320, height: 40),
                         font: .systemFont(ofSize: price == 0 ? 28 : 31, weight: .bold),
                         color: rgb(0x40382E), kern: 1)
        }
    }

    private func drawCentered(_ text: String, in rect: CGRect, font: UIFont,
                              color: UIColor, kern: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .kern: kern,
            .paragraphStyle: paragraph
        ])
    }

    private func addStand() {
        standRoot.position = SCNVector3(0, 0, -7.55)
        scene.rootNode.addChildNode(standRoot)

        let blackMetal = material(color: rgb(0x111313), roughness: 0.28, metalness: 0.88)
        let edgeMetal = material(color: rgb(0x353A39), roughness: 0.22, metalness: 0.92)

        let base = SCNCone(topRadius: 1.46, bottomRadius: 1.76, height: 0.34)
        base.firstMaterial = blackMetal
        let baseNode = SCNNode(geometry: base)
        baseNode.position.y = 0.20
        standRoot.addChildNode(baseNode)

        let bearing = SCNCylinder(radius: 0.23, height: 0.42)
        bearing.firstMaterial = blackMetal
        let bearingNode = SCNNode(geometry: bearing)
        bearingNode.position.y = 0.40
        standRoot.addChildNode(bearingNode)

        let foot = SCNCone(topRadius: 0.92, bottomRadius: 1.34, height: 0.24)
        foot.firstMaterial = edgeMetal
        let footNode = SCNNode(geometry: foot)
        footNode.position.y = 0.32
        standRoot.addChildNode(footNode)

        let pole = SCNCylinder(radius: 0.055, height: 5.75)
        pole.firstMaterial = edgeMetal
        let poleNode = SCNNode(geometry: pole)
        poleNode.position.y = 2.70
        standRoot.addChildNode(poleNode)

        // Mockup ring centres: [-.94, .42, 1.78] above its rack origin,
        // translated to this floor coordinate system.
        let tierLevels: [Float] = [1.23, 2.76, 4.12]
        for level in tierLevels {
            let outerRing = SCNTorus(ringRadius: 1.29, pipeRadius: 0.017)
            outerRing.firstMaterial = blackMetal
            let outerNode = SCNNode(geometry: outerRing)
            outerNode.position.y = level
            standRoot.addChildNode(outerNode)

            for spoke in 0..<4 {
                let angle = Float(spoke) * .pi / 2
                let rod = SCNCylinder(radius: 0.018, height: 1.18)
                rod.firstMaterial = blackMetal
                let rodNode = SCNNode(geometry: rod)
                rodNode.eulerAngles.z = .pi / 2
                rodNode.eulerAngles.y = angle
                rodNode.position = SCNVector3(sin(angle) * 0.59, level - 0.01, cos(angle) * 0.59)
                standRoot.addChildNode(rodNode)
            }
        }

        addStandSign()
        addEditionBooks()
        addFillerBooks()
    }

    private func addStandSign() {
        // The mast/header is stationary; only the book pockets rotate. A sign
        // attached to standRoot disappears edge-on and shows a blank back.
        let header = SCNNode()
        header.name = "stand-title-plaque"
        header.position = SCNVector3(standRoot.position.x, 5.60, standRoot.position.z)
        header.eulerAngles.y = standHomeAngle
        scene.rootNode.addChildNode(header)

        let plaqueMaterial = self.material(color: rgb(0x20251F), roughness: 0.72, metalness: 0.18)
        let plaque = node(box: SCNVector3(1.54, 0.48, 0.08), material: plaqueMaterial, chamfer: 0.04)
        // Mount the entire plaque in FRONT of the pole (radius 0.055).
        // Its old printed face at z=0.052 was cut through by the metal shaft.
        plaque.position.z = 0.105
        header.addChildNode(plaque)

        let plateMaterial = SCNMaterial()
        plateMaterial.diffuse.contents = signTexture()
        plateMaterial.lightingModel = .constant
        plateMaterial.diffuse.mipFilter = .linear
        let plate = SCNPlane(width: 1.40, height: 0.37)
        plate.firstMaterial = plateMaterial
        let plateNode = SCNNode(geometry: plate)
        plateNode.name = "stand-title-print"
        plateNode.position.z = 0.157
        header.addChildNode(plateNode)
    }

    private func signTexture() -> UIImage {
        // Match the physical 1.40:0.37 face exactly. The old 512:256 texture
        // stretched every letter almost twice as wide, flattening the title.
        let size = CGSize(width: 1008, height: 1008 * 0.37 / 1.40)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.setFillColor(rgb(0x242A23).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setStrokeColor(rgb(0xA9B797).cgColor)
            cg.setLineWidth(4)
            let border = UIBezierPath(roundedRect:
                CGRect(origin: .zero, size: size).insetBy(dx: 14, dy: 14), cornerRadius: 8)
            cg.addPath(border.cgPath)
            cg.strokePath()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            ("PROBABLY" as NSString).draw(
                in: CGRect(x: 36, y: 48, width: size.width - 72, height: 148),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 126, weight: .heavy),
                    .foregroundColor: rgb(0xFFF8E9),
                    .kern: 2,
                    .paragraphStyle: paragraph
                ]
            )
            ("SUDOKU BOOKS" as NSString).draw(
                in: CGRect(x: 36, y: 187, width: size.width - 72, height: 66),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 48, weight: .semibold),
                    .foregroundColor: rgb(0xD0DABB),
                    .kern: 6,
                    .paragraphStyle: paragraph
                ]
            )
        }
    }

    private func addEditionBooks() {
        guard !editions.isEmpty else { return }
        // Volumes 1/5/9 face front, then 2/6/10, 3/7/11, and 4/8/12.
        let levels: [Float] = [4.76, 3.40, 1.87]
        for face in pocketSlots.indices {
            for tier in pocketSlots[face].indices {
                guard let index = pocketSlots[face][tier], index < editions.count else { continue }
                let edition = editions[index]
                let angle = Float(face) * (.pi / 2)
                let parent = SCNNode()
                parent.position = SCNVector3(sin(angle) * 1.18, levels[tier], cos(angle) * 1.18)
                parent.eulerAngles.y = angle
                parent.name = "edition:\(edition.id)"

                let book = makeEditionBook(edition, index: index)
                book.name = "edition:\(edition.id)"
                book.eulerAngles.x = -0.10
                if tier == 2 {
                    // SceneKit's narrower phone projection foreshortens the
                    // lowest pocket more than the reference WebGL camera.
                    // This compensates only that renderer difference.
                    book.scale = SCNVector3(1, 1.15, 1)
                }
                parent.addChildNode(book)

                addPocket(around: parent)
                standRoot.addChildNode(parent)
                editionNodes[edition.id] = parent
                editionBookNodes[edition.id] = book
            }
        }
    }

    private func makeEditionBook(_ edition: BookEdition, index: Int) -> SCNNode {
        let width = 0.89 + CGFloat(index % 3) * 0.025
        // Keep the shelf object at the same stout 1:1.4 proportion as
        // LiveBook.  The focused view is no longer a differently-shaped
        // replacement for the copy in the wire pocket.
        let height = width * 1.4
        let thickness = 0.14 + CGFloat(index % 4) * 0.012
        let root = SCNNode()

        let pages = SCNBox(width: width - 0.055, height: height - 0.055,
                           length: thickness, chamferRadius: 0.025)
        pages.firstMaterial = material(color: pageColor(for: edition), roughness: 0.78)
        root.addChildNode(SCNNode(geometry: pages))

        let cloth = material(color: UIColor(edition.accent), roughness: 0.62)
        for z in [-(thickness / 2 + 0.018), thickness / 2 + 0.018] {
            let board = SCNBox(width: width, height: height, length: 0.036, chamferRadius: 0.03)
            board.firstMaterial = cloth
            let boardNode = SCNNode(geometry: board)
            boardNode.position.z = Float(z)
            root.addChildNode(boardNode)
        }

        let spine = SCNBox(width: 0.09, height: height, length: 0.13, chamferRadius: 0.025)
        spine.firstMaterial = cloth
        let spineNode = SCNNode(geometry: spine)
        spineNode.position.x = Float(-width / 2 + 0.035)
        root.addChildNode(spineNode)

        // LiveBook deliberately lets the page block and sewn bookmarks extend
        // beyond the fore-edge.  Give its rendered face that same extra space
        // instead of reconstructing a second, approximate set of 3D tabs.
        let coverPlane = SCNPlane(
            width: width * 1.20,
            height: height + width * 0.045
        )
        coverPlane.firstMaterial = coverMaterial(for: edition)
        let coverNode = SCNNode(geometry: coverPlane)
        coverNode.position = SCNVector3(
            Float(width * 0.10),
            Float(-width * 0.022),
            Float(thickness / 2 + 0.052)
        )
        coverNode.renderingOrder = 2
        coverNode.name = "edition:\(edition.id)"
        root.addChildNode(coverNode)

        // The cover plane is an ImageRenderer capture of LiveBook, including
        // its actual page block and bookmarks.  Keeping it as one source of
        // truth means the book on the shelf and the book after selection use
        // the same construction, rather than swapping from SceneKit boxes to
        // a different SwiftUI object half-way through the gesture.

        let backPlane = SCNPlane(width: width - 0.085, height: height - 0.075)
        let backMaterial = SCNMaterial()
        backMaterial.diffuse.contents = UIColor(edition.accent)
        backMaterial.lightingModel = .constant
        backMaterial.isDoubleSided = true
        backPlane.firstMaterial = backMaterial
        let backNode = SCNNode(geometry: backPlane)
        backNode.eulerAngles.y = .pi
        backNode.position = SCNVector3(0.025, 0, Float(-(thickness / 2 + 0.052)))
        backNode.renderingOrder = 1
        root.addChildNode(backNode)
        return root
    }

    private func addObstacleTabs(
        to book: SCNNode,
        edition: BookEdition,
        width: CGFloat,
        height: CGFloat,
        thickness: CGFloat
    ) {
        // Keep the shelf construction aligned with LiveBook: a 10.6%-wide
        // tab starts beneath the fore-edge, so only the small labeled pull is
        // visible outside the boards. It is a bookmark sewn into the pages,
        // not a detached control beside the cover.
        let tabWidth = width * 0.106
        let tabHeight = height * 0.088
        let firstY = height * 0.40
        let step = height * 0.10
        var nodes: [Int: SCNNode] = [:]

        for obstacle in Obstacle.allCases {
            let unlocked = obstacle.rawValue <= unlockedObstacleRawValue
            let selected = obstacle == selectedObstacle
            let geometry = SCNBox(
                width: tabWidth,
                height: tabHeight,
                length: 0.020,
                chamferRadius: min(tabHeight * 0.13, 0.012)
            )
            geometry.firstMaterial = obstacleTabMaterial(
                slot: obstacle.rawValue,
                unlocked: unlocked,
                selected: selected
            )

            let node = SCNNode(geometry: geometry)
            node.name = "obstacle:\(edition.id):\(obstacle.rawValue)"
            let baseX = Float(width / 2 + width * 0.008)
            node.position = SCNVector3(
                baseX + (selected ? Float(width * 0.030) : 0),
                Float(firstY - CGFloat(obstacle.rawValue - 1) * step),
                Float(thickness / 2 + 0.041)
            )
            node.setValue(baseX, forKey: "obstacleBaseX")
            node.castsShadow = true
            book.addChildNode(node)
            nodes[obstacle.rawValue] = node
        }

        obstacleTabNodes[edition.id] = nodes
    }

    private func updateObstacleTabs() {
        for edition in editions {
            guard let material = coverMaterials[edition.id] else { continue }
            material.diffuse.contents = liveBookTexture(for: edition)
        }
    }

    private func obstacleTabMaterial(slot: Int, unlocked: Bool, selected: Bool) -> SCNMaterial {
        let key = "\(slot):\(unlocked):\(selected)"
        if let cached = obstacleTabMaterialCache[key] { return cached }

        let result = SCNMaterial()
        result.diffuse.contents = obstacleTabTexture(
            slot: slot,
            unlocked: unlocked,
            selected: selected
        )
        result.diffuse.mipFilter = .linear
        result.lightingModel = .constant
        result.isDoubleSided = true
        obstacleTabMaterialCache[key] = result
        return result
    }

    private func obstacleTabTexture(slot: Int, unlocked: Bool, selected: Bool) -> UIImage {
        let size = CGSize(width: 96, height: 44)
        return UIGraphicsImageRenderer(size: size).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let shape = UIBezierPath(
                roundedRect: bounds,
                byRoundingCorners: [.topRight, .bottomRight],
                cornerRadii: CGSize(width: 10, height: 10)
            )
            let base = ObstacleRibbon.colour(forSlot: slot)
            let colour = unlocked
                ? UIColor(base)
                : UIColor(base.mixed(with: Color(hex: 0x292622), by: 0.76))
            colour.setFill()
            shape.fill()

            let cg = context.cgContext
            cg.saveGState()
            shape.addClip()
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.white.withAlphaComponent(0.22).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0, 1]
            )
            if let gradient {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width / 2, y: 0),
                    end: CGPoint(x: size.width / 2, y: size.height),
                    options: []
                )
            }
            cg.restoreGState()

            UIColor.black.withAlphaComponent(0.20).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 2, height: size.height)).fill()

            if unlocked {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                ("\(slot)" as NSString).draw(
                    in: CGRect(x: 38, y: 9, width: 48, height: 28),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 22, weight: .black),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.96),
                        .paragraphStyle: paragraph
                    ]
                )
            } else if let lock = UIImage(
                systemName: "lock.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
            )?.withTintColor(UIColor.white.withAlphaComponent(0.52), renderingMode: .alwaysOriginal) {
                lock.draw(in: CGRect(x: 55, y: 12, width: 17, height: 20))
            }

        }
    }

    private func addPocket(around parent: SCNNode) {
        let wire = material(color: rgb(0x111313), roughness: 0.25, metalness: 0.9)
        let p: (Float, Float, Float) -> SCNVector3 = { SCNVector3($0, $1, $2) }
        let segments: [(SCNVector3, SCNVector3, CGFloat)] = [
            (p(-0.59, -0.60, 0.24), p(0.59, -0.60, 0.24), 0.021),
            (p(-0.59, -0.39, 0.25), p(0.59, -0.39, 0.25), 0.023),
            (p(-0.59, -0.60, 0.24), p(-0.59, 0.23, 0.19), 0.021),
            (p(0.59, -0.60, 0.24), p(0.59, 0.23, 0.19), 0.021),
            (p(-0.59, 0.23, 0.19), p(-0.52, 0.30, -0.20), 0.019),
            (p(0.59, 0.23, 0.19), p(0.52, 0.30, -0.20), 0.019),
            (p(-0.52, 0.30, -0.20), p(0.52, 0.30, -0.20), 0.018),
            (p(-0.59, -0.60, 0.24), p(-0.52, -0.60, -0.22), 0.018),
            (p(0.59, -0.60, 0.24), p(0.52, -0.60, -0.22), 0.018)
        ]
        for (start, end, radius) in segments {
            parent.addChildNode(rodBetween(start, end, radius: radius, material: wire))
        }
        for x: Float in [-0.35, 0, 0.35] {
            parent.addChildNode(rodBetween(
                p(x, -0.60, 0.23),
                p(x, -0.60, -0.22),
                radius: 0.012,
                material: wire
            ))
        }
    }

    private func addFillerBooks() {
        let levels: [Float] = [4.76, 3.40, 1.87]
        for face in 0..<4 {
            for tier in 0..<3 {
                guard pocketSlots[face][tier] == nil else { continue }
                let angle = Float(face) * .pi / 2
                let holder = SCNNode()
                holder.position = SCNVector3(sin(angle) * 1.18, levels[tier], cos(angle) * 1.18)
                holder.eulerAngles.y = angle
                addPocket(around: holder)
                standRoot.addChildNode(holder)
            }
        }
    }

    private func rodBetween(
        _ start: SCNVector3,
        _ end: SCNVector3,
        radius: CGFloat,
        material: SCNMaterial
    ) -> SCNNode {
        let delta = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let length = sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
        let geometry = SCNCylinder(radius: radius * 0.72, height: CGFloat(length))
        geometry.firstMaterial = material
        let result = SCNNode(geometry: geometry)
        result.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        result.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: SIMD3<Float>(delta.x, delta.y, delta.z) / length)
        result.castsShadow = true
        return result
    }

    private func coverMaterial(for edition: BookEdition) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = liveBookTexture(for: edition)
        result.diffuse.mipFilter = .linear
        // Preserve the authored print colours. The physical cloth boards,
        // page block and obstacle ribbons receive the room/focus lighting;
        // running the already-colour-managed cover texture through SceneKit's
        // PBR tonemapper clips the pale paper and changes the approved artwork.
        result.lightingModel = .constant
        result.isDoubleSided = true
        coverMaterials[edition.id] = result
        return result
    }

    /// A small, static shelf face made by the exact LiveBook view that takes
    /// over during selection.  Its buttons are intentionally inert here: the
    /// pocket only selects a book, while the full-size LiveBook owns obstacle
    /// interaction after it has been brought forward.
    private func liveBookTexture(for edition: BookEdition) -> UIImage? {
        let bookWidth: CGFloat = 480
        let bookHeight = bookWidth * 1.4
        let canvas = CGSize(width: bookWidth * 1.20, height: bookHeight + bookWidth * 0.045)
        let renderer = ImageRenderer(content:
            ZStack(alignment: .topLeading) {
                LiveBook(
                    edition: edition,
                    ribbons: LiveBook.RibbonStrip(
                        levels: Obstacle.allCases,
                        selected: selectedObstacle,
                        isUnlocked: { [unlockedObstacleRawValue] obstacle in
                            obstacle.rawValue <= unlockedObstacleRawValue
                        },
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
        return renderer.uiImage
    }

    private func pageColor(for edition: BookEdition) -> UIColor {
        let cloth = UIColor(edition.accent)
        let paper = rgb(0xE6DFCF)
        var clothRed: CGFloat = 0
        var clothGreen: CGFloat = 0
        var clothBlue: CGFloat = 0
        var clothAlpha: CGFloat = 0
        var paperRed: CGFloat = 0
        var paperGreen: CGFloat = 0
        var paperBlue: CGFloat = 0
        var paperAlpha: CGFloat = 0
        cloth.getRed(&clothRed, green: &clothGreen, blue: &clothBlue, alpha: &clothAlpha)
        paper.getRed(&paperRed, green: &paperGreen, blue: &paperBlue, alpha: &paperAlpha)
        let paperShare: CGFloat = 0.42
        return UIColor(
            red: clothRed * (1 - paperShare) + paperRed * paperShare,
            green: clothGreen * (1 - paperShare) + paperGreen * paperShare,
            blue: clothBlue * (1 - paperShare) + paperBlue * paperShare,
            alpha: 1
        )
    }

    private func makeShelfSpine(paletteIndex: Int, title: String,
                                width: Float, height: Float) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        plane.cornerRadius = min(CGFloat(width) * 0.08, 0.012)
        plane.firstMaterial = shelfSpineMaterial(paletteIndex: paletteIndex, title: title)
        let result = SCNNode(geometry: plane)
        result.castsShadow = false
        return result
    }

    private func shelfBookGeometry(
        width: Float,
        height: Float,
        length: Float,
        paletteIndex: Int,
        roughness: CGFloat,
        chamfer: CGFloat
    ) -> SCNGeometry {
        let key = String(
            format: "%.3f:%.3f:%.3f:%d:%.3f:%.3f",
            width, height, length, paletteIndex, roughness, chamfer
        )
        if let cached = shelfBookGeometries[key] { return cached }

        let palette = [0x5A2A25, 0x2B4438, 0x26374B, 0x86602D, 0x7A6A4D, 0x493129, 0x4E3A57]
        let box = SCNBox(
            width: CGFloat(width),
            height: CGFloat(height),
            length: CGFloat(length),
            chamferRadius: chamfer
        )
        box.firstMaterial = material(
            color: rgb(palette[paletteIndex % palette.count]),
            roughness: roughness
        )
        shelfBookGeometries[key] = box
        return box
    }

    private func shelfSpineMaterial(paletteIndex: Int, title: String) -> SCNMaterial {
        let index = paletteIndex % 7
        let key = "\(index):\(title)"
        if let cached = shelfSpineMaterials[key] { return cached }

        let result = SCNMaterial()
        result.diffuse.contents = shelfSpineTexture(paletteIndex: index, title: title)
        result.diffuse.mipFilter = .linear
        result.lightingModel = .constant
        result.isDoubleSided = true
        shelfSpineMaterials[key] = result
        return result
    }

    private func shelfSpineTexture(paletteIndex: Int, title: String) -> UIImage {
        let palette = [0x5A2A25, 0x2B4438, 0x26374B, 0x86602D, 0x7A6A4D, 0x493129, 0x4E3A57]
        let base = rgb(palette[paletteIndex])
        let size = CGSize(width: 128, height: 512)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.setFillColor(base.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            // Linen grain and stamped rules make the words only just legible,
            // as they are in the reference—not crisp UI labels on scenery.
            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.16).cgColor)
            cg.setLineWidth(1)
            for y in stride(from: 4 as CGFloat, through: 508, by: 9) {
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: 128, y: y + 1.5))
            }
            cg.strokePath()

            let ink = rgb(0xD8C59D)
            cg.setFillColor(ink.withAlphaComponent(0.72).cgColor)
            cg.fill(CGRect(x: 13, y: 42, width: 102, height: 5))
            cg.fill(CGRect(x: 24, y: 462, width: 80, height: 4))
            cg.fillEllipse(in: CGRect(x: 54, y: 72, width: 20, height: 20))
            drawCentered("N", in: CGRect(x: 0, y: 68, width: 128, height: 28),
                         font: .systemFont(ofSize: 17, weight: .black), color: rgb(0x2B2117))

            cg.saveGState()
            cg.translateBy(x: 64, y: 274)
            cg.rotate(by: -.pi / 2)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            (title as NSString).draw(
                in: CGRect(x: -190, y: -16, width: 380, height: 34),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 21, weight: .semibold),
                    .foregroundColor: ink.withAlphaComponent(0.80),
                    .kern: 2.1,
                    .paragraphStyle: paragraph
                ]
            )
            cg.restoreGState()
        }
    }

    private func node(box size: SCNVector3, material: SCNMaterial, chamfer: CGFloat = 0) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: chamfer)
        geometry.firstMaterial = material
        let result = SCNNode(geometry: geometry)
        result.castsShadow = true
        return result
    }

    private func material(color: UIColor, roughness: CGFloat, metalness: CGFloat = 0) -> SCNMaterial {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let key = String(format: "%.3f-%.3f-%.3f-%.3f-%.3f-%.3f",
                         red, green, blue, alpha, roughness, metalness)
        if let cached = sharedMaterials[key] { return cached }

        let result = SCNMaterial()
        result.lightingModel = .physicallyBased
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.metalness.contents = metalness
        sharedMaterials[key] = result
        return result
    }

    private func woodMaterial(color: UIColor, roughness: CGFloat,
                              repeatX: Float, repeatY: Float) -> SCNMaterial {
        let result = material(color: color, roughness: roughness)
        if result.diffuse.contents is UIColor {
            result.diffuse.contents = woodTexture(base: color)
            result.diffuse.wrapS = .repeat
            result.diffuse.wrapT = .repeat
            result.diffuse.mipFilter = .linear
            result.diffuse.contentsTransform = SCNMatrix4MakeScale(repeatX, repeatY, 1)
        }
        return result
    }

    private func woodTexture(base: UIColor) -> UIImage {
        let size = CGSize(width: 96, height: 96)
        return UIGraphicsImageRenderer(size: size).image { context in
            base.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let cg = context.cgContext
            cg.setLineCap(.round)
            for line in 0..<22 {
                let y = CGFloat(line) * 4.55
                let path = UIBezierPath()
                path.move(to: CGPoint(x: -4, y: y))
                for step in 0...12 {
                    let x = CGFloat(step) * 8.5
                    let wave = sin(CGFloat(step) * 0.78 + CGFloat(line) * 0.47) * 1.35
                    path.addLine(to: CGPoint(x: x, y: y + wave))
                }
                let light = line.isMultiple(of: 3)
                (light ? UIColor.white : UIColor.black)
                    .withAlphaComponent(light ? 0.045 : 0.075)
                    .setStroke()
                path.lineWidth = light ? 0.55 : 0.8
                path.stroke()
            }

            cg.setStrokeColor(UIColor.black.withAlphaComponent(0.06).cgColor)
            cg.setLineWidth(0.45)
            for x in stride(from: 7 as CGFloat, through: 92, by: 17) {
                cg.strokeEllipse(in: CGRect(x: x, y: 32 + sin(x) * 8, width: 12, height: 4))
            }
        }
    }

    /// Bakes the exact page renderer into the physical shop sample. Illustrated
    /// stocks, onion skin, fibres and perforations therefore cannot diverge
    /// from the page the player actually buys.
    private func paperStockTexture(skin: PaperSkin, label: String, size: CGSize) -> UIImage {
        let cacheKey = ShopSampleTextureCacheKey.paperStock(
            skinID: skin.id, label: label, size: size
        )
        if let cached = shopPaperStockTextureCache[cacheKey] { return cached }

        var loadout = EquippedCosmetics.starting
        loadout.paperID = skin.id
        let theme = CosmeticCatalog.theme(for: loadout)
        let stockRenderer = ImageRenderer(content:
            ZStack {
                Rectangle().fill(skin.page)
                PaperGrain(opacity: skin.grain, seed: 5)
                PaperStockOverlay(treatment: skin.treatment)
            }
            .environment(\.cosmeticTheme, theme)
            .frame(width: size.width / 2, height: size.height / 2)
        )
        stockRenderer.scale = 2
        let stockImage = stockRenderer.uiImage
        let ink = UIColor(skin.edge.mixed(with: Color.black, by: 0.42))

        let image = UIGraphicsImageRenderer(size: size).image { context in
            if let stockImage {
                stockImage.draw(in: CGRect(origin: .zero, size: size))
            } else {
                UIColor(skin.page).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            let cg = context.cgContext
            cg.setStrokeColor(ink.withAlphaComponent(0.46).cgColor)
            cg.setLineWidth(7)
            cg.stroke(CGRect(x: 22, y: 22, width: 476, height: 596))
            drawCentered("NUMBER CLUB STOCK", in: CGRect(x: 34, y: 70, width: 452, height: 36),
                         font: .systemFont(ofSize: 22, weight: .semibold),
                         color: ink.withAlphaComponent(0.72), kern: 3)
            drawCentered(label, in: CGRect(x: 34, y: 142, width: 452, height: 66),
                         font: .systemFont(ofSize: 44, weight: .bold), color: ink, kern: 1)
            cg.setStrokeColor(ink.withAlphaComponent(0.32).cgColor)
            cg.setLineWidth(3)
            for y in stride(from: 282 as CGFloat, through: 520, by: 54) {
                cg.move(to: CGPoint(x: 68, y: y))
                cg.addLine(to: CGPoint(x: 452, y: y))
                cg.strokePath()
            }
            drawCentered("PAPER SAMPLE", in: CGRect(x: 34, y: 552, width: 452, height: 30),
                         font: .systemFont(ofSize: 18, weight: .semibold),
                         color: ink.withAlphaComponent(0.70), kern: 2.4)
        }
        shopPaperStockTextureCache[cacheKey] = image
        return image
    }

    /// The real 9x9 gameplay rule renderer, baked once per selected finish for
    /// a transparent SceneKit face.
    private func gridRuleTexture(skin: BoardSkin, size: CGSize) -> UIImage {
        let cacheKey = ShopSampleTextureCacheKey.gridRule(skinID: skin.id, size: size)
        if let cached = shopGridRuleTextureCache[cacheKey] { return cached }

        let renderer = ImageRenderer(content:
            CosmeticGridRules(
                skin: skin,
                side: size.width / 2,
                cell: size.width / 2 / 9,
                includesBorder: false,
                forcesStaticRendering: true
            )
            .frame(width: size.width / 2, height: size.height / 2)
        )
        renderer.scale = 2
        let image = renderer.uiImage ?? UIImage()
        shopGridRuleTextureCache[cacheKey] = image
        return image
    }

    /// The shared Hot Type flame treatment is constant art, so the SceneKit
    /// bridge renders and caches it only once.
    private func flameCrownTexture(size: CGSize) -> UIImage {
        if let cached = shopFlameCrownTextureCache { return cached }
        let renderer = ImageRenderer(content:
            FlameCrown(size: size.width / 2, intensity: 1)
                .frame(width: size.width / 2, height: size.height / 2)
        )
        renderer.scale = 2
        let image = renderer.uiImage ?? UIImage()
        shopFlameCrownTextureCache = image
        return image
    }

    private func shopGlyphTexture(_ glyph: String, ink: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 160, height: 160)).image { _ in
            drawCentered(glyph, in: CGRect(x: 0, y: 14, width: 160, height: 132),
                         font: .monospacedDigitSystemFont(ofSize: 112, weight: .bold), color: ink)
        }
    }

    private func rgb(_ value: Int) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

private struct BookstoreCoverTexture: View {
    let edition: BookEdition

    var body: some View {
        ZStack {
            if edition.id == "genuinely" {
                genuinelyCover
            } else if edition.id.hasPrefix("future-") {
                futureCover
            } else {
                CoverFace(design: edition.design)
            }
            if edition.id == BookEdition.first.id {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    coverNote("Mistakes\nare proof\nyou’re\ntrying.", color: Color(hex: 0xEFA064))
                        .frame(width: w * 0.26, height: h * 0.16)
                        .rotationEffect(.degrees(-5.2))
                        .position(x: w * 0.22, y: h * 0.16)
                    coverNote("One square\nat a time.", color: Color(hex: 0xF1E3A8))
                        .frame(width: w * 0.25, height: h * 0.12)
                        .rotationEffect(.degrees(3))
                        .position(x: w * 0.82, y: h * 0.13)
                }
            }
        }
    }

    private var genuinelyCover: some View {
        ZStack {
            Color(hex: 0xE6DFEA)
            Rectangle().strokeBorder(Color(hex: 0x302936).opacity(0.28), lineWidth: 2).padding(9)
            VStack(spacing: 3) {
                Image(systemName: "sun.max")
                    .font(.system(size: 25, weight: .light))
                    .foregroundStyle(Color(hex: 0x987EAD))
                    .padding(.top, 28)
                Spacer(minLength: 0)
                Text("Good Luck,")
                    .font(.system(size: 33, weight: .black))
                    .foregroundStyle(Color(hex: 0x302936))
                Text("Genuinely")
                    .font(.custom("MarkerFelt-Wide", size: 40))
                    .foregroundStyle(Color(hex: 0x51435D))
                    .rotationEffect(.degrees(-2))
                Capsule().fill(Color(hex: 0x987EAD)).frame(width: 112, height: 3)
                Spacer(minLength: 0)
                Text("A SUDOKU BOOK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: 0xE6DFEA))
                    .frame(width: 144, height: 21)
                    .background(Color(hex: 0x51435D))
                Text("VOLUME 5")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Color(hex: 0x302936).opacity(0.75))
                    .padding(.bottom, 22)
            }
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0xE6DFEA))
                        .frame(width: 25, height: 28)
                        .background(Color(hex: 0x302936).opacity(0.86))
                }
                Spacer()
            }
            .padding(8)
        }
    }

    private var futureCover: some View {
        ZStack {
            Color(hex: 0x303328)
            Rectangle().strokeBorder(Color(hex: 0xE0DFD0).opacity(0.25), lineWidth: 2).padding(9)
            Rectangle().strokeBorder(Color(hex: 0x8C946C).opacity(0.5), lineWidth: 1).padding(15)
            VStack(spacing: 0) {
                Spacer()
                Text("Not\nWritten")
                    .font(.system(size: 35, weight: .heavy))
                    .foregroundStyle(Color(hex: 0xE0DFD0))
                    .multilineTextAlignment(.center)
                Text("Yet")
                    .font(.custom("MarkerFelt-Wide", size: 43))
                    .foregroundStyle(Color(hex: 0x8C946C))
                Capsule().fill(Color(hex: 0x8C946C)).frame(width: 88, height: 2)
                    .padding(.top, 5)
                Text(edition.shelfLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: 0xE0DFD0).opacity(0.65))
                    .padding(.top, 11)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xE0DFD0).opacity(0.52))
                    .padding(.bottom, 23)
            }
        }
    }

    private func coverNote(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium, design: .serif).italic())
            .foregroundStyle(Color(hex: 0x6B624D))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}
