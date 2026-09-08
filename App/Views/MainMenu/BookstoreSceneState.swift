import Foundation

/// Decorative scenery and user-driven rack motion have separate switches.
/// Disabling background motion must not turn a swipe into a hard page change.
enum BookstoreMotionPolicy {
    static func isSceneVisible(isVisible: Bool, sceneIsActive: Bool, isCovered: Bool) -> Bool {
        isVisible && sceneIsActive && !isCovered
    }

    static func animatesScenery(isSceneVisible: Bool, preference: Bool,
                               reduceMotion: Bool, lowPower: Bool) -> Bool {
        isSceneVisible && preference && !reduceMotion && !lowPower
    }
}

enum BookstoreScenePhase: Equatable {
    case store
    case transitioningToStand
    case choosingBook
    case transitioningToStore
    case transitioningToShop
    case shopping
    case transitioningShopToStore

    var showsHomeControls: Bool { self == .store }
    var showsSelectionControls: Bool { self == .choosingBook }
    var showsShopControls: Bool { self == .shopping }
}

/// SceneKit remains continuous for reliable intermediate frames, but a resting
/// bookstore aisle does not need the same cadence as user-driven motion.
enum BookstoreRenderPolicy {
    static let interactiveFramesPerSecond = 60
    static let restingStoreFramesPerSecond = 30

    static func preferredFramesPerSecond(phase: BookstoreScenePhase,
                                         hasReportedFirstFrame: Bool,
                                         awaitingFrame: Bool,
                                         thermalState: ProcessInfo.ThermalState = .nominal) -> Int {
        // Keep controls and frame-readiness handoffs alive while reducing GPU
        // demand when iOS reports thermal pressure. No timing or game rule changes.
        if thermalState == .serious || thermalState == .critical {
            return restingStoreFramesPerSecond
        }
        guard hasReportedFirstFrame, !awaitingFrame else {
            return interactiveFramesPerSecond
        }
        return phase == .store ? restingStoreFramesPerSecond : interactiveFramesPerSecond
    }
}

struct BookstoreTurnCommand: Equatable {
    let serial: Int
    let selectedIndex: Int
}

/// Requests the same physical focus move as tapping a cover. Keeping this as
/// an explicit command lets the unobtrusive SwiftUI selection affordance and
/// debug routes remain accessible without duplicating any Book presentation.
struct BookstoreFocusCommand: Equatable {
    let serial: Int
    let editionID: String
}

/// A dedicated return command avoids relying on a tap passing through the
/// selected Book's interactive bookmark view to reach SceneKit underneath.
struct BookstoreReturnFocusCommand: Equatable {
    let serial: Int
}

/// Read-only presentation facts for the physical Club Shop counter. The
/// SceneKit coordinator renders these values but never owns currency or makes
/// a purchase; PlayerProfileStore remains the sole economy authority.
struct BookstoreShopPresentation: Equatable {
    let currentIndex: Int
    let itemCount: Int
    let stampBalance: Int
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    let message: String?
}

enum BookstoreDebugDestination {
    case normal
    case halfwayToStand
    case stand
    case halfwayToShop
    case shop

    static var current: BookstoreDebugDestination {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-bookstoreHalfway") { return .halfwayToStand }
        if arguments.contains("-bookstoreStand") || arguments.contains("-bookRack") { return .stand }
        #endif
        return .normal
    }
}

enum BookstoreDebugCameraPosition: Equatable {
    case stand(progress: Double)
    case shop(progress: Double)
}
