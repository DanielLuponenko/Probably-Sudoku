import SwiftUI

private struct GameReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var gameReduceMotion: Bool {
        get { self[GameReduceMotionKey.self] }
        set { self[GameReduceMotionKey.self] = newValue }
    }
}

/// The game owns its animation preference independently of iOS. Keeping this
/// above ContentView gives the intro, SceneKit stand, gameplay and paper panels
/// one live value without replacing their state when the player changes it.
struct GameMotionPreferences: ViewModifier {
    @AppStorage(AppPreferences.Key.reducedMotion) private var reducedMotion = false

    func body(content: Content) -> some View {
        content.environment(\.gameReduceMotion, reducedMotion)
    }
}
