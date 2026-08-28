import SceneKit
import SwiftUI
import UIKit
import ProbablySudokuEngine

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
    private var shopSampleBasePositions: [CosmeticCategory: SCNVector3] = [:]
    private var shopPriceMaterials: [CosmeticCategory: SCNMaterial] = [:]
    private var shopDrawerLabelMaterials: [CosmeticCategory: SCNMaterial] = [:]
    private var shopProductNameText: SCNText?
    private weak var shopProductNameNode: SCNNode?
    private var shopProductDetailText: SCNText?
    private weak var shopProductDetailNode: SCNNode?
    private var shopBrowseText: SCNText?
    private weak var shopBrowseNode: SCNNode?
    private var shopPriceText: SCNText?
    private weak var shopPriceNode: SCNNode?
    private var shopActionText: SCNText?
    private weak var shopActionNode: SCNNode?
    private var shopActionDetailText: SCNText?
    private weak var shopActionDetailNode: SCNNode?
    private var shopActionButtonMaterial: SCNMaterial?
    private var shopCounterSurfaceMaterial: SCNMaterial?
    private weak var shopCounterSurfaceNode: SCNNode?
    private var shopNeighborMaterials: [SCNMaterial] = []
    private var shopNeighborNodes: [SCNNode] = []
    private var shopDeskMaterial: SCNMaterial?
    private var shopDeskLabelMaterial: SCNMaterial?
    private var shopDeskGrainNodes: [SCNNode] = []
    private var shopDeskSeamNodes: [SCNNode] = []
    private var shopPaperMaterial: SCNMaterial?
    private var shopPaperBandMaterial: SCNMaterial?
    private var shopPaperTopMaterial: SCNMaterial?
    private var shopBoardMaterial: SCNMaterial?
    private var shopBoardRuleMaterial: SCNMaterial?
    private var shopBoardInternalRules: [SCNNode] = []
    private var shopNumberBodyMaterial: SCNMaterial?
    private var shopNumberSpecimenMaterial: SCNMaterial?
    private weak var sceneView: SCNView?

    private var currentPhase: BookstoreScenePhase?
    private var lastTurnSerial = -1
    private var lastFocusSerial = -1
    private var selectedIndex = 0
    private var panStartAngle: Float = 0
    private var shopPanStartTransform = SCNMatrix4Identity
    private var reduceMotion = false
    private var selectedObstacle: Obstacle = .none
    private var unlockedObstacleRawValue = Obstacle.none.rawValue
    private var onSelectEdition: ((String) -> Void)?
    private var onSelectObstacle: ((Obstacle) -> Void)?
    private var onShowObstacleInfo: ((Obstacle) -> Void)?
    private var onSelectShopCategory: ((CosmeticCategory) -> Void)?
    private var onStepShopItem: ((Int) -> Void)?
    private var onBuyOrEquipShopItem: (() -> Void)?
    private var onBookFocusChanged: ((String?) -> Void)?
    private var onTransitionFinished: ((BookstoreScenePhase) -> Void)?
    private var focusedBook: FocusedBook?
    private var focusGeneration = 0
    private var cameraGeneration = 0
    private var selectedShopCategory: CosmeticCategory = .desk
    private var selectedShopItemID: String?
    private var selectedShopPresentation: BookstoreShopPresentation?

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

    // The shop pose turns right from the same open aisle. It keeps the near
    // shelf outside the frustum while preserving the room around the counter.
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
        // Elevated three-quarter view from the approved mockup. The camera
        // stops at the customer edge of the sales counter. The counter now
        // fills the lower frame like furniture in the room instead of reading
        // as a small merchandise stand viewed from across the aisle.
        position: SCNVector3(-0.15, 4.60, 12.10),
        target: SCNVector3(3.72, 2.55, 8.62),
        fieldOfView: 54
    )
    private let standHomeAngle = Float(atan2(1.65, 8.65))
    // Exact fixed pocket map from the approved spinner mockup. Each inner
    // array is one 90-degree face, ordered top-to-bottom.
    private let pocketSlots: [[Int?]] = [
        [0, 4, 8],
        [1, 5, nil],
        [2, 6, nil],
        [3, 7, nil]
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
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
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
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
    }

    func update(
        phase: BookstoreScenePhase,
        selectedEditionID: String,
        selectedObstacle: Obstacle,
        unlockedObstacleRawValue: Int,
        turnCommand: BookstoreTurnCommand,
        focusCommand: BookstoreFocusCommand,
        shopCategory: CosmeticCategory,
        shopItem: CosmeticItem?,
        shopPresentation: BookstoreShopPresentation,
        reduceMotion: Bool,
        debugCameraPosition: BookstoreDebugCameraPosition?,
        onSelectEdition: @escaping (String) -> Void,
        onSelectObstacle: @escaping (Obstacle) -> Void,
        onShowObstacleInfo: @escaping (Obstacle) -> Void,
        onSelectShopCategory: @escaping (CosmeticCategory) -> Void,
        onStepShopItem: @escaping (Int) -> Void,
        onBuyOrEquipShopItem: @escaping () -> Void,
        onBookFocusChanged: @escaping (String?) -> Void,
        onTransitionFinished: @escaping (BookstoreScenePhase) -> Void
    ) {
        self.reduceMotion = reduceMotion
        self.onSelectEdition = onSelectEdition
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
    }

    private func react(to phase: BookstoreScenePhase) {
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
            let finish = { [weak self] in
                guard let self else { return }
                self.animateCamera(to: self.storePose, destination: .store)
                self.orientStandForStore(animated: !self.reduceMotion)
            }
            if focusedBook != nil { returnFocusedBook(completion: finish) }
            else { finish() }
        case .transitioningToShop:
            setRoomLighting(shopFocused: true, animated: true)
            animateCamera(to: shopPose, destination: .shopping)
        case .shopping:
            setRoomLighting(shopFocused: true, animated: false)
            apply(shopPose)
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
        roomAmbientLight.intensity = shopFocused ? 230 : 285
        roomWarmLight.intensity = shopFocused ? 46 : 55
        roomCoolFillLight.intensity = shopFocused ? 60 : 80
        standKeyLight.intensity = shopFocused ? 15 : 30
        for practical in practicalLights {
            practical.intensity = shopFocused ? 7 : 8
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
            apply(interpolate(from: storePose, to: shopPose, amount: CGFloat(progress)))
        }
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
            handleBookStandPan(gesture)
        case .shopping:
            handleShopProductPan(gesture)
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // A pan's initial velocity is often exactly zero for a deliberate slow
        // touch (and for simulator drags). Rejecting that value made valid shop
        // swipes fail before `.changed` could establish direction. The shop has
        // no vertical scrolling, so let its pan recognizer begin and consume
        // only horizontal translation in `handleShopProductPan`.
        if currentPhase == .shopping,
           gestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return true
    }

    private func handleBookStandPan(_ gesture: UIPanGestureRecognizer) {
        guard !editions.isEmpty else { return }
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
            if abs(translation) > 34 || abs(velocity) > 430 {
                onStepShopItem?(translation < 0 || velocity < -430 ? 1 : -1)
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
                    guard focusedBook == nil else { return }
                    onSelectEdition?(id)
                    rotateStand(to: index, animated: !reduceMotion) { [weak self] in
                        self?.focusBook(id: id)
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
        for result in view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue]) {
            var node: SCNNode? = result.node
            while let candidate = node {
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
                   let category = CosmeticCategory(rawValue: String(raw)),
                   category != .marker {
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
              let originParent = book.parent
        else { return }

        let originTransform = book.simdTransform
        let worldTransform = book.simdWorldTransform
        book.removeFromParentNode()
        scene.rootNode.addChildNode(book)
        book.simdWorldTransform = worldTransform
        setFocusCategory(on: book, enabled: true)

        let cameraPosition = cameraNode.presentation.simdWorldPosition
        let lookPosition = cameraTarget.presentation.simdWorldPosition
        let forward = simd_normalize(lookPosition - cameraPosition)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let centeredTargetPosition = cameraPosition + forward * 5.55
        let centeredFacingZ = simd_normalize(cameraPosition - centeredTargetPosition)
        let cameraRight = simd_normalize(simd_cross(worldUp, centeredFacingZ))
        // The tabs make the combined silhouette wider on the right. Offset
        // the whole physical Book slightly left, then scale it uniformly so
        // the cover and all nine tabs fill the screen without distortion.
        let targetPosition = centeredTargetPosition + cameraRight * 0.04
        let facingZ = simd_normalize(cameraPosition - targetPosition)
        let facingX = simd_normalize(simd_cross(worldUp, facingZ))
        let facingY = simd_cross(facingZ, facingX)
        let targetOrientation = simd_quatf(simd_float3x3(columns: (facingX, facingY, facingZ)))
        let targetScale = book.simdScale * SIMD3<Float>(repeating: 1.58)

        focusedBookLightNode.simdPosition = cameraPosition
            - cameraRight * 0.22
            + worldUp * 0.72
            + forward * 0.80
        let focusedLook = SCNLookAtConstraint(target: book)
        focusedLook.isGimbalLockEnabled = true
        focusedBookLightNode.constraints = [focusedLook]

        focusedBook = FocusedBook(
            id: id,
            book: book,
            originParent: originParent,
            originTransform: originTransform
        )
        focusGeneration += 1
        let generation = focusGeneration

        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0.08 : 0.58
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.82, 0.20, 1)
        SCNTransaction.completionBlock = { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.focusGeneration == generation,
                      self.focusedBook?.id == id
                else { return }
                self.onBookFocusChanged?(id)
            }
        }
        book.simdPosition = targetPosition
        book.simdOrientation = targetOrientation
        book.simdScale = targetScale
        setLighting(focused: true, bookID: id)
        SCNTransaction.commit()
    }

    private func returnFocusedBook(completion: (() -> Void)? = nil) {
        guard let focus = focusedBook else {
            completion?()
            return
        }

        // Move the same physical Book back and invalidate any pending
        // focus-completion callback.
        focusGeneration += 1
        onBookFocusChanged?(nil)

        // If the player taps the scenery before the focus move finishes,
        // return from the currently rendered transform instead of jumping to
        // the focus animation's model-layer destination first.
        focus.book.simdWorldTransform = focus.book.presentation.simdWorldTransform
        let targetWorldTransform = focus.originParent.simdWorldTransform * focus.originTransform
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0.08 : 0.46
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = { [weak self] in
            Task { @MainActor in
                guard let self, self.focusedBook?.id == focus.id else { return }
                focus.book.removeFromParentNode()
                focus.originParent.addChildNode(focus.book)
                focus.book.simdTransform = focus.originTransform
                self.setFocusCategory(on: focus.book, enabled: false)
                self.focusedBookLightNode.constraints = nil
                self.focusedBook = nil
                completion?()
            }
        }
        focus.book.simdTransform = targetWorldTransform
        setLighting(focused: false, bookID: focus.id)
        SCNTransaction.commit()
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
        camera.bloomIntensity = 0.03
        camera.bloomThreshold = 1.15
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
        let floorMaterial = woodMaterial(color: rgb(0x121116), roughness: 0.76, repeatX: 4, repeatY: 14)
        let runnerMaterial = material(color: rgb(0x0D2D28), roughness: 0.9)
        // These approved graphic surfaces are intentionally print-lit. Their
        // appearance must not change when the physical focus light is added.
        floorMaterial.lightingModel = .constant
        runnerMaterial.lightingModel = .constant
        let brass = material(color: rgb(0x8B5C19), roughness: 0.38, metalness: 0.72)

        let floor = node(box: SCNVector3(12.4, 0.14, 30), material: floorMaterial)
        floor.position = SCNVector3(0, -0.09, 2)
        floor.castsShadow = false
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
        let ambientNode = SCNNode()
        ambientNode.light = roomAmbientLight
        scene.rootNode.addChildNode(ambientNode)

        roomWarmLight.type = .omni
        roomWarmLight.color = UIColor(red: 1, green: 0.90, blue: 0.78, alpha: 1)
        roomWarmLight.intensity = 55
        roomWarmLight.attenuationStartDistance = 2
        roomWarmLight.attenuationEndDistance = 15
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
        let ivory = material(color: rgb(0xD8CDB4), roughness: 0.90)
        let darkMetal = material(color: rgb(0x242625), roughness: 0.34, metalness: 0.72)

        shopRoot.name = "club-shop-root"
        shopRoot.position = SCNVector3(3.62, 0.16, 8.62)
        shopRoot.eulerAngles.y = -0.62
        // Preserve real-world proportions. The previous x-only compression
        // flattened every sample, drawer and lamp into a billboard. Framing
        // belongs to the camera, not a non-uniform scene transform.
        shopRoot.scale = SCNVector3(0.70, 0.70, 0.70)
        scene.rootNode.addChildNode(shopRoot)

        // Printed shop furniture belongs to the existing recessed bookstore
        // wall, not to the angled counter. Keeping this root wall-aligned
        // prevents the entire shop from reading as a rotated imported booth.
        shopWallRoot.name = "club-shop-wall-fixtures"
        shopWallRoot.position = SCNVector3(4.30, 0.16, 8.62)
        shopWallRoot.eulerAngles.y = -.pi / 2
        shopWallRoot.scale = SCNVector3(0.70, 0.70, 0.70)
        scene.rootNode.addChildNode(shopWallRoot)
        addShopWallBox(SCNVector3(5.90, 0.14, 0.68),
                       at: SCNVector3(0, 5.46, 0.32),
                       material: shopWallTrim, chamfer: 0.025)
        let wallBookColors = [0x5A2A25, 0x2B4438, 0x26374B, 0x86602D, 0x493129, 0x4E3A57]
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
        shopCounterSurfaceMaterial = previewSurfaceMaterial
        let previewSurface = addShopBox(
            SCNVector3(3.98, 0.24, 1.18),
            at: SCNVector3(0, 1.10, 0.08),
            material: previewSurfaceMaterial,
            chamfer: 0.055
        )
        shopCounterSurfaceNode = previewSurface
        addShopBox(SCNVector3(3.74, 1.18, 0.92), at: SCNVector3(0, 0.43, 0.02), material: counterWood, chamfer: 0.025)
        addShopBox(SCNVector3(3.62, 0.08, 0.82), at: SCNVector3(0, 0.97, 0.08), material: brass)

        addShopWallBox(SCNVector3(3.36, 1.08, 0.08),
                       at: SCNVector3(0, 4.55, 0.025),
                       material: shopWallTrim, chamfer: 0.025)
        let sign = printedShopPlane(
            width: 3.22,
            height: 0.94,
            image: shopSignTexture(),
            position: SCNVector3(0, 4.55, 0.075)
        )
        sign.opacity = 0.98
        shopWallRoot.addChildNode(sign)

        let notice = printedShopPlane(
            width: 1.20,
            height: 0.45,
            image: shopNoticeTexture(),
            position: SCNVector3(-0.91, 3.18, 0.05)
        )
        notice.eulerAngles.z = -0.035
        notice.opacity = 0.90
        shopWallRoot.addChildNode(notice)
        addShopWallBox(SCNVector3(3.45, 0.032, 0.035),
                       at: SCNVector3(0, 3.56, 0.06), material: brass)

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
                position: SCNVector3(0.39 + Float(index) * 0.46, 3.10, 0.06)
            )
            paper.eulerAngles.z = Float(index - 1) * 0.045
            paper.opacity = 0.94
            shopWallRoot.addChildNode(paper)
            let clip = addShopWallBox(SCNVector3(0.10, 0.06, 0.04),
                                      at: SCNVector3(0.39 + Float(index) * 0.46, 3.39, 0.09),
                                      material: brass)
            clip.opacity = 0.92
        }

        let categories: [CosmeticCategory] = [.desk, .paper, .board, .numbers]
        let drawerXPositions: [Float] = [-1.37, -0.46, 0.46, 1.37]
        let productXPositions: [Float] = [-1.28, -0.43, 0.43, 1.28]
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
            drawerFace.position = SCNVector3(drawerXPositions[index], 0.22, 0.478)
            drawer.addChildNode(drawerFace)

            let drawerLabelMaterial = SCNMaterial()
            drawerLabelMaterial.lightingModel = .constant
            drawerLabelMaterial.diffuse.contents = shopDrawerTexture(category.title.uppercased(), selected: category == .desk)
            drawerLabelMaterial.isDoubleSided = true
            shopDrawerLabelMaterials[category] = drawerLabelMaterial
            let drawerLabelPlane = SCNPlane(width: 0.72, height: 0.23)
            drawerLabelPlane.firstMaterial = drawerLabelMaterial
            let drawerLabel = SCNNode(geometry: drawerLabelPlane)
            drawerLabel.name = "shop-category:\(category.rawValue)"
            drawerLabel.position = SCNVector3(drawerXPositions[index], 0.20, 0.505)
            drawerLabel.castsShadow = false
            drawer.addChildNode(drawerLabel)

            let pull = node(box: SCNVector3(0.22, 0.026, 0.026), material: brass, chamfer: 0.01)
            pull.position = SCNVector3(drawerXPositions[index], 0.36, 0.55)
            drawer.addChildNode(pull)
            for postX: Float in [-0.09, 0.09] {
                let post = node(box: SCNVector3(0.024, 0.07, 0.035), material: brass, chamfer: 0.008)
                post.position = SCNVector3(drawerXPositions[index] + postX, 0.33, 0.53)
                drawer.addChildNode(post)
            }

            let sample = SCNNode()
            sample.name = "shop-category:\(category.rawValue)"
            let basePosition = SCNVector3(productXPositions[index], 1.22, 0.23)
            sample.position = basePosition
            shopSampleBasePositions[category] = basePosition
            shopSampleNodes[category] = sample
            shopRoot.addChildNode(sample)

            let plinth = SCNCylinder(radius: 0.38, height: 0.10)
            plinth.firstMaterial = category == .board
                ? material(color: rgb(0x718069), roughness: 0.67, metalness: 0.03)
                : counterGreen
            let plinthNode = SCNNode(geometry: plinth)
            plinthNode.position.y = 0.02
            plinthNode.castsShadow = true
            sample.addChildNode(plinthNode)

            switch category {
            case .desk: addDeskSample(to: sample)
            case .paper: addPaperSample(to: sample)
            case .board: addBoardSample(to: sample)
            case .numbers: addNumberSample(to: sample, ivory: ivory, metal: darkMetal)
            case .marker: break
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

        // The cabinet itself is the interface. Raised type and a register key
        // replace the oversized printed cards that made the room look like a
        // background image with another screen pasted over it.
        addShopCabinetInterface(counterGreen: counterGreen, brass: brass, ivory: ivory)

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
                case .desk: colour = UIColor(CosmeticCatalog.desk(item.id).light)
                case .paper: colour = UIColor(CosmeticCatalog.paper(item.id).page)
                case .board: colour = UIColor(CosmeticCatalog.board(item.id).given)
                case .numbers: colour = UIColor(CosmeticCatalog.numbers(item.id).givenInk)
                case .marker: colour = rgb(0x6A6051)
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

    private func addShopCabinetInterface(counterGreen: SCNMaterial, brass: SCNMaterial,
                                         ivory: SCNMaterial) {
        let cream = rgb(0xE8DDC5)
        let muted = rgb(0xBCA98A)

        let name = raisedShopText("WALNUT", color: cream, scale: 0.22,
                                  position: SCNVector3(-0.72, 0.76, 0.515))
        shopProductNameText = name.text
        shopProductNameNode = name.node

        let detail = raisedShopText("OWNED · EQUIPPED", color: muted, scale: 0.085,
                                    position: SCNVector3(-0.72, 0.55, 0.518))
        shopProductDetailText = detail.text
        shopProductDetailNode = detail.node

        let browse = raisedShopText("‹  1 OF 4 · SWIPE  ›", color: muted, scale: 0.075,
                                    position: SCNVector3(-0.72, 0.39, 0.518))
        shopBrowseText = browse.text
        shopBrowseNode = browse.node

        let actionMaterial = counterGreen.copy() as! SCNMaterial
        shopActionButtonMaterial = actionMaterial
        let action = addShopBox(
            SCNVector3(0.88, 0.54, 0.11),
            at: SCNVector3(0.98, 0.64, 0.575),
            material: actionMaterial,
            chamfer: 0.035
        )
        action.name = "shop-action"
        for x: Float in [-0.37, 0.37] {
            for y: Float in [-0.20, 0.20] {
                let pin = SCNSphere(radius: 0.016)
                pin.firstMaterial = brass
                let pinNode = SCNNode(geometry: pin)
                pinNode.position = SCNVector3(x, y, 0.063)
                action.addChildNode(pinNode)
            }
        }
        let actionTitle = raisedShopText("EQUIPPED", color: cream, scale: 0.13,
                                         position: SCNVector3(0.98, 0.68, 0.648))
        shopActionText = actionTitle.text
        shopActionNode = actionTitle.node
        let actionDetail = raisedShopText("PERMANENT", color: muted, scale: 0.065,
                                          position: SCNVector3(0.98, 0.49, 0.650))
        shopActionDetailText = actionDetail.text
        shopActionDetailNode = actionDetail.node
    }

    private func raisedShopText(_ value: String, color: UIColor, scale: Float,
                                position: SCNVector3) -> (node: SCNNode, text: SCNText) {
        let text = SCNText(string: value, extrusionDepth: 0.025)
        text.font = UIFont(name: "AvenirNextCondensed-DemiBold", size: 1)
            ?? .systemFont(ofSize: 1, weight: .semibold)
        text.flatness = 0.025
        let face = material(color: color, roughness: 0.58, metalness: 0.04)
        text.materials = [face]
        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(scale, scale, scale)
        node.position = position
        centerShopTextNode(node)
        node.castsShadow = false
        shopRoot.addChildNode(node)
        return (node, text)
    }

    private func setShopText(_ value: String, text: SCNText?, node: SCNNode?) {
        guard let text, let node else { return }
        text.string = value
        centerShopTextNode(node)
    }

    private func centerShopTextNode(_ node: SCNNode) {
        let bounds = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (bounds.min.x + bounds.max.x) * 0.5,
            (bounds.min.y + bounds.max.y) * 0.5,
            0
        )
    }

    private func addDeskSample(to sample: SCNNode) {
        let sampleMaterial = material(color: rgb(0x7B5137), roughness: 0.72).copy() as! SCNMaterial
        sampleMaterial.diffuse.contents = woodTexture(base: rgb(0x7B5137))
        sampleMaterial.diffuse.wrapS = .repeat
        sampleMaterial.diffuse.wrapT = .repeat
        sampleMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(1.15, 1.8, 1)
        shopDeskMaterial = sampleMaterial
        let slab = node(box: SCNVector3(0.57, 0.74, 0.13), material: sampleMaterial, chamfer: 0.025)
        slab.position.y = 0.44
        slab.eulerAngles.z = -0.08
        sample.addChildNode(slab)

        let grainMaterial = material(color: rgb(0x2D1A12), roughness: 0.82)
        for (index, y) in [-0.24 as Float, -0.12, 0, 0.12, 0.24].enumerated() {
            let grain = node(box: SCNVector3(index.isMultiple(of: 2) ? 0.49 : 0.42, 0.012, 0.008),
                             material: grainMaterial)
            grain.position = SCNVector3(index.isMultiple(of: 2) ? -0.012 : 0.025, y, 0.071)
            grain.opacity = 0.22
            slab.addChildNode(grain)
            shopDeskGrainNodes.append(grain)
        }
        let seamMaterial = material(color: rgb(0xAFC1B0), roughness: 0.95)
        for x: Float in [-0.19, 0, 0.19] {
            let seam = node(box: SCNVector3(0.010, 0.62, 0.008), material: seamMaterial)
            seam.position = SCNVector3(x, 0, 0.071)
            seam.opacity = 0
            slab.addChildNode(seam)
            shopDeskSeamNodes.append(seam)
        }
    }

    private func addPaperSample(to sample: SCNNode) {
        let paperMaterial = material(color: rgb(0xD8CDB4), roughness: 0.90)
        shopPaperMaterial = paperMaterial
        for pageIndex in 0..<6 {
            let page = node(box: SCNVector3(0.58, 0.025, 0.72), material: paperMaterial, chamfer: 0.008)
            page.position = SCNVector3(pageIndex.isMultiple(of: 2) ? -0.006 : 0.006,
                                       0.12 + Float(pageIndex) * 0.035, 0)
            page.eulerAngles.y = (Float(pageIndex) - 2.5) * 0.015
            sample.addChildNode(page)
        }
        let bandMaterial = material(color: rgb(0x806D50), roughness: 0.74)
        shopPaperBandMaterial = bandMaterial
        let band = node(box: SCNVector3(0.16, 0.23, 0.75), material: bandMaterial)
        band.position.y = 0.23
        sample.addChildNode(band)

        let topMaterial = SCNMaterial()
        topMaterial.lightingModel = .constant
        topMaterial.isDoubleSided = true
        topMaterial.diffuse.contents = paperSampleTexture(name: "IVORY", paper: rgb(0xF1EBDD), ink: rgb(0x51483C))
        shopPaperTopMaterial = topMaterial
        let topPage = SCNPlane(width: 0.52, height: 0.64)
        topPage.firstMaterial = topMaterial
        let topPageNode = SCNNode(geometry: topPage)
        topPageNode.eulerAngles.x = -0.82
        topPageNode.position = SCNVector3(0, 0.50, 0.02)
        topPageNode.castsShadow = false
        sample.addChildNode(topPageNode)
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
        for line in 0..<2 {
            let offset = (Float(line) - 0.5) * 0.186
            let vertical = node(box: SCNVector3(0.018, 0.56, 0.012), material: ruleMaterial)
            vertical.position = SCNVector3(offset, 0.42, 0.050)
            vertical.name = "shop-grid-vertical"
            sample.addChildNode(vertical)
            shopBoardInternalRules.append(vertical)

            let horizontal = node(box: SCNVector3(0.56, 0.018, 0.012), material: ruleMaterial)
            horizontal.position = SCNVector3(0, 0.42 + offset, 0.050)
            horizontal.name = "shop-grid-horizontal"
            sample.addChildNode(horizontal)
            shopBoardInternalRules.append(horizontal)
        }

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

    private func addNumberSample(to sample: SCNNode, ivory: SCNMaterial, metal: SCNMaterial) {
        let bodyMaterial = metal.copy() as? SCNMaterial ?? metal
        shopNumberBodyMaterial = bodyMaterial
        let body = node(box: SCNVector3(0.72, 0.30, 0.54), material: bodyMaterial, chamfer: 0.045)
        body.position.y = 0.23
        sample.addChildNode(body)
        let keyMaterial = ivory.copy() as? SCNMaterial ?? ivory
        keyMaterial.lightingModel = .constant
        keyMaterial.diffuse.contents = rgb(0xE7DDC8)
        for row in 0..<2 {
            for column in 0..<3 {
                let keycap = SCNCylinder(radius: 0.072, height: 0.052)
                keycap.firstMaterial = keyMaterial
                let key = SCNNode(geometry: keycap)
                key.eulerAngles.x = .pi / 2
                key.position = SCNVector3(-0.21 + Float(column) * 0.21,
                                           0.34 + Float(row) * 0.14, 0.29)
                sample.addChildNode(key)

                let digit = String(row * 3 + column + 1)
                let digitMaterial = SCNMaterial()
                digitMaterial.lightingModel = .constant
                digitMaterial.diffuse.contents = shopGlyphTexture(digit, ink: rgb(0x38342E))
                digitMaterial.isDoubleSided = true
                let digitPlane = SCNPlane(width: 0.082, height: 0.082)
                digitPlane.firstMaterial = digitMaterial
                let digitNode = SCNNode(geometry: digitPlane)
                digitNode.position = SCNVector3(key.position.x, key.position.y, 0.323)
                digitNode.castsShadow = false
                sample.addChildNode(digitNode)
            }
        }
        let specimenMaterial = SCNMaterial()
        specimenMaterial.lightingModel = .constant
        specimenMaterial.diffuse.contents = numberSpecimenTexture(itemID: "nb_press", ink: rgb(0x34312B))
        specimenMaterial.isDoubleSided = true
        shopNumberSpecimenMaterial = specimenMaterial
        let specimen = SCNPlane(width: 0.62, height: 0.28)
        specimen.firstMaterial = specimenMaterial
        let specimenNode = SCNNode(geometry: specimen)
        specimenNode.position = SCNVector3(0, 0.65, 0.04)
        specimenNode.eulerAngles.x = -0.16
        sample.addChildNode(specimenNode)
    }

    private func addShopLamp(brass: SCNMaterial, darkMetal: SCNMaterial) {
        let shadeMaterial = material(color: rgb(0x29483C), roughness: 0.54, metalness: 0.12)
        shadeMaterial.isDoubleSided = true
        let shade = SCNCone(topRadius: 0.18, bottomRadius: 0.58, height: 0.44)
        shade.firstMaterial = shadeMaterial
        let shadeNode = SCNNode(geometry: shade)
        shadeNode.position = SCNVector3(0.65, 5.82, 1.18)
        shadeNode.castsShadow = true
        shopRoot.addChildNode(shadeNode)

        let rimGeometry = SCNTorus(ringRadius: 0.58, pipeRadius: 0.028)
        rimGeometry.firstMaterial = brass
        let rim = SCNNode(geometry: rimGeometry)
        rim.position = SCNVector3(0.65, 5.60, 1.18)
        shopRoot.addChildNode(rim)

        let cord = SCNCylinder(radius: 0.012, height: 3.13)
        cord.firstMaterial = darkMetal
        let cordNode = SCNNode(geometry: cord)
        cordNode.position = SCNVector3(0.65, 7.145, 1.18)
        shopRoot.addChildNode(cordNode)

        let canopy = SCNCylinder(radius: 0.18, height: 0.10)
        canopy.firstMaterial = brass
        let canopyNode = SCNNode(geometry: canopy)
        canopyNode.position = SCNVector3(0.65, 8.70, 1.18)
        shopRoot.addChildNode(canopyNode)

        let bulb = SCNSphere(radius: 0.12)
        let bulbMaterial = SCNMaterial()
        bulbMaterial.lightingModel = .constant
        bulbMaterial.diffuse.contents = rgb(0xFFEFD3)
        bulb.firstMaterial = bulbMaterial
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(0.65, 5.58, 1.18)
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
        lampNode.position = SCNVector3(0.65, 5.58, 1.18)
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
        fill.intensity = 38
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
        wallWash.color = UIColor(red: 1, green: 0.86, blue: 0.70, alpha: 1)
        wallWash.intensity = 50
        wallWash.attenuationStartDistance = 1.0
        wallWash.attenuationEndDistance = 8.0
        wallWash.spotInnerAngle = 90
        wallWash.spotOuterAngle = 140
        wallWash.categoryBitMask = 1
        wallWash.castsShadow = false
        let wallWashNode = SCNNode()
        wallWashNode.light = wallWash
        wallWashNode.position = SCNVector3(0.35, 5.42, 2.20)
        let wallLook = SCNLookAtConstraint(target: wallTarget)
        wallLook.isGimbalLockEnabled = true
        wallWashNode.constraints = [wallLook]
        shopWallRoot.addChildNode(wallWashNode)

        // A prior cone-shell volumetric effect rendered as an opaque shape on
        // iOS. Keep the trace physical: illuminated merchandise and the soft
        // forward shadow, with no screen-space or particle decoration.
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
            let scale = SCNAction.scale(to: selected ? 1.12 : 0.94, duration: duration)
            scale.timingMode = .easeOut
            sample.runAction(.group([move, scale]), forKey: "sample-selection")
            sample.runAction(.fadeOpacity(to: 1, duration: duration),
                             forKey: "sample-emphasis")
        }
        guard let item else { return }
        updateShopCounterPreview(category: category, item: item)
        updateShopSample(category: category, item: item)
        shopPriceMaterials[category]?.diffuse.contents = shopPriceTexture(price: item.price)
    }

    private func updateShopPresentation(category: CosmeticCategory, item: CosmeticItem,
                                        state: BookstoreShopPresentation) {
        let title: String
        if state.equipped { title = "EQUIPPED" }
        else if state.owned { title = "EQUIP" }
        else if state.affordable { title = "BUY" }
        else { title = "NEED \(max(0, item.price - state.stampBalance))" }
        let enabled = !state.equipped && (state.owned || state.affordable)

        let ownership: String
        if state.equipped { ownership = "OWNED · EQUIPPED · PERMANENT" }
        else if state.owned { ownership = "OWNED · READY TO EQUIP" }
        else if state.affordable { ownership = "\(state.stampBalance) → \(state.stampBalance - item.price) STAMPS" }
        else { ownership = "NEED \(max(0, item.price - state.stampBalance)) MORE STAMPS" }

        setShopText(item.name.uppercased(), text: shopProductNameText, node: shopProductNameNode)
        setShopText(ownership, text: shopProductDetailText, node: shopProductDetailNode)
        setShopText("‹  \(state.currentIndex + 1) OF \(max(state.itemCount, 1)) · SWIPE  ›",
                    text: shopBrowseText, node: shopBrowseNode)
        setShopText("\(item.price) STAMPS", text: shopPriceText, node: shopPriceNode)

        let visibleAction = state.message == nil ? title : "ADDED"
        let actionScale: Float = visibleAction.count > 11 ? 0.075 : (visibleAction.count > 8 ? 0.095 : 0.13)
        shopActionNode?.scale = SCNVector3(actionScale, actionScale, actionScale)
        setShopText(visibleAction, text: shopActionText, node: shopActionNode)
        let actionDetail: String
        if state.message != nil { actionDetail = "EQUIPPED" }
        else if !state.owned && !state.affordable { actionDetail = "MORE STAMPS" }
        else { actionDetail = enabled ? "PERMANENT" : "CURRENT SAMPLE" }
        setShopText(actionDetail,
                    text: shopActionDetailText, node: shopActionDetailNode)
        shopActionButtonMaterial?.diffuse.contents = enabled ? rgb(0x58705D) : rgb(0x4B4B43)
    }

    private func updateShopCounterPreview(category: CosmeticCategory, item: CosmeticItem) {
        guard let surface = shopCounterSurfaceMaterial else { return }
        if category == .desk {
            let skin = CosmeticCatalog.desk(item.id)
            surface.diffuse.contents = item.id == "dk_baize"
                ? UIColor(skin.light)
                : woodTexture(base: UIColor(skin.light))
            surface.roughness.contents = item.id == "dk_baize" ? 0.94 : 0.70
        } else {
            surface.diffuse.contents = woodTexture(base: rgb(0x8A6040))
            surface.roughness.contents = 0.66
        }
        surface.diffuse.wrapS = .repeat
        surface.diffuse.wrapT = .repeat
        surface.diffuse.contentsTransform = SCNMatrix4MakeScale(2.2, 3.2, 1)
        if !reduceMotion, let node = shopCounterSurfaceNode {
            node.removeAction(forKey: "counter-finish-change")
            node.opacity = 0.72
            let settle = SCNAction.fadeOpacity(to: 1, duration: 0.24)
            settle.timingMode = .easeOut
            node.runAction(settle, forKey: "counter-finish-change")
        }
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
        case .desk:
            let skin = CosmeticCatalog.desk(item.id)
            let isBaize = item.id == "dk_baize"
            let colour = UIColor(skin.light)
            shopDeskMaterial?.diffuse.contents = isBaize ? colour : woodTexture(base: colour)
            shopDeskLabelMaterial?.diffuse.contents = deskSampleLabelTexture(name: item.name.uppercased())
            shopDeskGrainNodes.forEach { $0.opacity = isBaize ? 0 : 0.22 }
            shopDeskSeamNodes.forEach { $0.opacity = isBaize ? 0.42 : 0 }
        case .paper:
            let skin = CosmeticCatalog.paper(item.id)
            shopPaperMaterial?.diffuse.contents = UIColor(skin.page)
            shopPaperBandMaterial?.diffuse.contents = UIColor(skin.edge)
            shopPaperTopMaterial?.diffuse.contents = paperSampleTexture(
                name: item.name.uppercased(),
                paper: UIColor(skin.page),
                ink: UIColor(skin.edge.mixed(with: Color.black, by: 0.42))
            )
        case .board:
            let skin = CosmeticCatalog.board(item.id)
            shopBoardMaterial?.diffuse.contents = UIColor(skin.given.mixed(with: skin.selected, by: 0.12))
            shopBoardRuleMaterial?.diffuse.contents = UIColor(skin.bold)
            let width = Float(max(0.012, min(0.034, skin.hairWidth * 0.018)))
            for rule in shopBoardInternalRules {
                if rule.name == "shop-grid-vertical" {
                    rule.scale.x = width / 0.018
                } else {
                    rule.scale.y = width / 0.018
                }
            }
        case .numbers:
            let skin = CosmeticCatalog.numbers(item.id)
            shopNumberBodyMaterial?.diffuse.contents = UIColor(skin.givenInk)
            shopNumberSpecimenMaterial?.diffuse.contents = numberSpecimenTexture(
                itemID: item.id,
                ink: UIColor(skin.ink)
            )
        case .marker:
            break
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

    private func shopProductInfoTexture(item: CosmeticItem, category: CosmeticCategory,
                                        state: BookstoreShopPresentation) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 320)).image { context in
            rgb(0xE7DDC9).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1024, height: 320))
            let cg = context.cgContext
            cg.setStrokeColor(rgb(0x9A7447).cgColor)
            cg.setLineWidth(8)
            cg.stroke(CGRect(x: 10, y: 10, width: 1004, height: 300))
            cg.setFillColor(rgb(0xA64F43).cgColor)
            cg.fill(CGRect(x: 36, y: 34, width: 8, height: 252))

            drawShopText("\(category.title.uppercased()) SAMPLE",
                         rect: CGRect(x: 70, y: 30, width: 640, height: 36),
                         font: .systemFont(ofSize: 25, weight: .bold),
                         color: rgb(0xA64F43), kern: 3)
            drawShopText(item.name,
                         rect: CGRect(x: 70, y: 68, width: 650, height: 67),
                         font: .systemFont(ofSize: 53, weight: .semibold),
                         color: rgb(0x302A22))
            drawShopText(item.blurb,
                         rect: CGRect(x: 70, y: 139, width: 650, height: 82),
                         font: .italicSystemFont(ofSize: 28),
                         color: rgb(0x625B50))

            let page = "‹  \(state.currentIndex + 1) OF \(max(state.itemCount, 1))  ›"
            drawCentered(page, in: CGRect(x: 730, y: 67, width: 274, height: 48),
                         font: .monospacedSystemFont(ofSize: 27, weight: .bold),
                         color: rgb(0x3C4D3B), kern: 2)
            drawCentered("SWIPE OR TAP", in: CGRect(x: 736, y: 122, width: 260, height: 36),
                         font: .systemFont(ofSize: 20, weight: .semibold),
                         color: rgb(0x706654), kern: 2)

            let ownership: String
            if state.equipped { ownership = "OWNED · EQUIPPED · PERMANENT" }
            else if state.owned { ownership = "OWNED · READY TO EQUIP" }
            else if state.affordable { ownership = "\(state.stampBalance) → \(state.stampBalance - item.price) STAMPS" }
            else { ownership = "NEED \(max(0, item.price - state.stampBalance)) MORE STAMPS" }
            drawShopText(ownership,
                         rect: CGRect(x: 70, y: 265, width: 900, height: 32),
                         font: .systemFont(ofSize: 21, weight: .bold),
                         color: rgb(0x556B55), kern: 1.4)
        }
    }

    private func shopActionTexture(title: String, enabled: Bool, message: String?) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 420, height: 344)).image { context in
            let fill = message == nil
                ? (enabled ? rgb(0x687D67) : rgb(0x5B574E))
                : rgb(0x687D67)
            fill.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 420, height: 344))
            let cg = context.cgContext
            cg.setStrokeColor(rgb(0xB5843C).cgColor)
            cg.setLineWidth(9)
            cg.stroke(CGRect(x: 12, y: 12, width: 396, height: 320))
            if message == nil {
                drawCentered(enabled ? "PRESS" : "STATUS",
                             in: CGRect(x: 0, y: 72, width: 420, height: 40),
                             font: .systemFont(ofSize: 22, weight: .semibold),
                             color: rgb(0xDED3BD), kern: 4)
            }
            let actionPointSize: CGFloat = title.count > 8 ? 34 : (title.count > 6 ? 42 : 50)
            drawCentered(message ?? title,
                         in: CGRect(x: 22, y: message == nil ? 128 : 106, width: 376, height: 116),
                         font: .systemFont(ofSize: message == nil ? actionPointSize : 33, weight: .bold),
                         color: rgb(0xFFF7E7), kern: 1.2)
        }
    }

    private func drawShopText(_ text: String, rect: CGRect, font: UIFont,
                              color: UIColor, kern: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: [.font: font, .foregroundColor: color,
                                             .kern: kern, .paragraphStyle: paragraph], context: nil)
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

    private func numberSpecimenTexture(itemID: String, ink: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 176)).image { context in
            rgb(0xE5DCC9).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 176))
            let cg = context.cgContext
            cg.setStrokeColor(rgb(0x847A69).cgColor)
            cg.setLineWidth(7)
            cg.stroke(CGRect(x: 12, y: 12, width: 488, height: 152))

            let font: UIFont
            switch itemID {
            case "nb_typewriter": font = .monospacedSystemFont(ofSize: 82, weight: .bold)
            case "nb_schoolbook": font = .italicSystemFont(ofSize: 88)
            case "nb_oldstyle": font = .systemFont(ofSize: 86, weight: .heavy)
            case "nb_stencil": font = .monospacedSystemFont(ofSize: 78, weight: .black)
            case "nb_neon":
                cg.setShadow(offset: .zero, blur: 14, color: ink.withAlphaComponent(0.85).cgColor)
                font = .systemFont(ofSize: 82, weight: .bold)
            default: font = .systemFont(ofSize: 84, weight: .bold)
            }
            drawCentered("2  7  9", in: CGRect(x: 0, y: 42, width: 512, height: 96),
                         font: font, color: ink, kern: itemID == "nb_stencil" ? 5 : 0)
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
        let brass = material(color: rgb(0x8B5C19), roughness: 0.34, metalness: 0.78)

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

        let topCap = SCNCylinder(radius: 0.16, height: 0.14)
        topCap.firstMaterial = brass
        let topCapNode = SCNNode(geometry: topCap)
        topCapNode.position.y = 5.68
        standRoot.addChildNode(topCapNode)

        addStandSign()
        addEditionBooks()
        addFillerBooks()
    }

    private func addStandSign() {
        let plaqueMaterial = self.material(color: rgb(0x252525), roughness: 0.32, metalness: 0.88)
        let plaque = node(box: SCNVector3(1.54, 0.48, 0.08), material: plaqueMaterial, chamfer: 0.04)
        plaque.position = SCNVector3(0, 5.60, 0)
        standRoot.addChildNode(plaque)

        let plateMaterial = SCNMaterial()
        plateMaterial.diffuse.contents = signTexture()
        plateMaterial.lightingModel = .constant
        plateMaterial.isDoubleSided = true
        let plate = SCNPlane(width: 1.40, height: 0.37)
        plate.firstMaterial = plateMaterial
        let plateNode = SCNNode(geometry: plate)
        plateNode.position = SCNVector3(0, 5.60, 0.052)
        standRoot.addChildNode(plateNode)
    }

    private func signTexture() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.setFillColor(rgb(0x262525).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setStrokeColor(rgb(0xA5977D).cgColor)
            cg.setLineWidth(8)
            cg.stroke(CGRect(x: 12, y: 12, width: 488, height: 232))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            ("PROBABLY" as NSString).draw(
                in: CGRect(x: 0, y: 55, width: 512, height: 82),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 68, weight: .heavy),
                    .foregroundColor: rgb(0xEFE8D9),
                    .paragraphStyle: paragraph
                ]
            )
            ("SUDOKU BOOKS" as NSString).draw(
                in: CGRect(x: 0, y: 145, width: 512, height: 48),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 29, weight: .semibold),
                    .foregroundColor: rgb(0x9EAF90),
                    .paragraphStyle: paragraph
                ]
            )
        }
    }

    private func addEditionBooks() {
        guard !editions.isEmpty else { return }
        // Fixed pockets, matching the reference spinner's slot table exactly:
        // 1/5/9 on the front, 2/6/empty on the next face, and so on.
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
        let height = 1.16 + CGFloat(index % 2) * 0.035
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

        let coverPlane = SCNPlane(width: width - 0.085, height: height - 0.075)
        coverPlane.firstMaterial = coverMaterial(for: edition)
        let coverNode = SCNNode(geometry: coverPlane)
        coverNode.position = SCNVector3(0.025, 0, Float(thickness / 2 + 0.052))
        coverNode.renderingOrder = 2
        coverNode.name = "edition:\(edition.id)"
        root.addChildNode(coverNode)

        // The obstacle bookmarks belong to the physical Book. They are built
        // once here and remain attached while the carousel turns and while
        // this exact node moves toward the camera.
        addObstacleTabs(
            to: root,
            edition: edition,
            width: width,
            height: height,
            thickness: thickness
        )

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
        // Match LiveBook's established ribbon strip: nine small, square-ended
        // tabs spanning the fore-edge. Only the selected ribbon stands farther
        // out; its colour, shape and numeral do not change in the carousel.
        let tabWidth = width * 0.132
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
            let baseX = Float(width / 2 + tabWidth * 0.30)
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
        for tabs in obstacleTabNodes.values {
            for (slot, node) in tabs {
                guard let obstacle = Obstacle(rawValue: slot) else { continue }
                node.geometry?.firstMaterial = obstacleTabMaterial(
                    slot: slot,
                    unlocked: slot <= unlockedObstacleRawValue,
                    selected: obstacle == selectedObstacle
                )
                if let baseX = node.value(forKey: "obstacleBaseX") as? NSNumber {
                    node.position.x = baseX.floatValue + (obstacle == selectedObstacle ? 0.030 : 0)
                }
            }
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
        let renderer = ImageRenderer(content: BookstoreCoverTexture(edition: edition).frame(width: 240, height: 340))
        renderer.scale = 2
        result.diffuse.contents = renderer.uiImage ?? UIColor(edition.accent)
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

    private func deskSampleLabelTexture(name: String) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 420, height: 130)).image { context in
            rgb(0xE4D8BC).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 420, height: 130))
            let cg = context.cgContext
            cg.setStrokeColor(rgb(0x8D6A38).cgColor)
            cg.setLineWidth(8)
            cg.stroke(CGRect(x: 10, y: 10, width: 400, height: 110))
            drawCentered(name, in: CGRect(x: 18, y: 26, width: 384, height: 45),
                         font: .systemFont(ofSize: 31, weight: .bold), color: rgb(0x3B3024), kern: 1.2)
            drawCentered("DESK SAMPLE", in: CGRect(x: 18, y: 74, width: 384, height: 24),
                         font: .systemFont(ofSize: 16, weight: .semibold), color: rgb(0x8D4D42), kern: 2)
        }
    }

    private func paperSampleTexture(name: String, paper: UIColor, ink: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 520, height: 640)).image { context in
            paper.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 520, height: 640))
            let cg = context.cgContext
            cg.setStrokeColor(ink.withAlphaComponent(0.46).cgColor)
            cg.setLineWidth(7)
            cg.stroke(CGRect(x: 22, y: 22, width: 476, height: 596))
            drawCentered("NUMBER CLUB STOCK", in: CGRect(x: 34, y: 70, width: 452, height: 36),
                         font: .systemFont(ofSize: 22, weight: .semibold), color: ink.withAlphaComponent(0.72), kern: 3)
            drawCentered(name, in: CGRect(x: 34, y: 142, width: 452, height: 66),
                         font: .systemFont(ofSize: 44, weight: .bold), color: ink, kern: 1)
            cg.setStrokeColor(ink.withAlphaComponent(0.32).cgColor)
            cg.setLineWidth(3)
            for y in stride(from: 282 as CGFloat, through: 520, by: 54) {
                cg.move(to: CGPoint(x: 68, y: y))
                cg.addLine(to: CGPoint(x: 452, y: y))
                cg.strokePath()
            }
            drawCentered("PAPER SAMPLE", in: CGRect(x: 34, y: 552, width: 452, height: 30),
                         font: .systemFont(ofSize: 18, weight: .semibold), color: ink.withAlphaComponent(0.70), kern: 2.4)
        }
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
