import SwiftUI

/// The handful of switches that are about the app rather than about a Book.
///
/// `UserDefaults` directly rather than an object: these are read from
/// `Haptics`, which is a free function away from any view hierarchy, and
/// written from one paper slip. Both sides agree on the keys and nothing has
/// to be injected anywhere.
enum AppPreferences {
    enum Key {
        static let haptics = "settings.haptics"
        static let ambientMotion = "settings.ambientMotion"
        static let sound = "settings.sound"
        static let music = "settings.music"
    }

    private static func flag(_ key: String, default fallback: Bool = true) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    static var hapticsEnabled: Bool { flag(Key.haptics) }
    static var ambientMotionEnabled: Bool { flag(Key.ambientMotion) }
    static var soundEnabled: Bool { flag(Key.sound) }
    static var musicEnabled: Bool { flag(Key.music) }
}
