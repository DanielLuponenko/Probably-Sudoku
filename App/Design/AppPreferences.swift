import Foundation

/// The switches and audio mix that belong to the app rather than one Book.
///
/// `UserDefaults` directly rather than an object: these are read from
/// `Haptics`, which is a free function away from any view hierarchy, and
/// written from either settings slip. Both sides agree on the keys and nothing has
/// to be injected anywhere.
enum AppPreferences {
    enum Key {
        static let haptics = "settings.haptics"
        static let ambientMotion = "settings.ambientMotion"
        static let sound = "settings.sound"
        static let music = "settings.music"
        static let masterVolume = "settings.audio.masterVolume"
        static let musicVolume = "settings.audio.musicVolume"
        static let effectsVolume = "settings.audio.effectsVolume"
    }

    private static func flag(_ key: String, default fallback: Bool = true) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    static var hapticsEnabled: Bool { flag(Key.haptics) }
    static var ambientMotionEnabled: Bool { flag(Key.ambientMotion) }
    static var soundEnabled: Bool { flag(Key.sound) }
    static var musicEnabled: Bool { flag(Key.music) }

    static func audioMix(in defaults: UserDefaults = .standard) -> AudioMix {
        func value(_ key: String, fallback: Double) -> Double {
            guard let number = defaults.object(forKey: key) as? NSNumber,
                  number.doubleValue.isFinite else { return fallback }
            return min(1, max(0, number.doubleValue))
        }
        // Respect the old on/off choices until a player moves the new slider.
        let musicDefault = defaults.object(forKey: Key.music) as? Bool == false ? 0.0 : 0.45
        let effectsDefault = defaults.object(forKey: Key.sound) as? Bool == false ? 0.0 : 0.7
        return AudioMix(master: value(Key.masterVolume, fallback: 0.8),
                        music: value(Key.musicVolume, fallback: musicDefault),
                        effects: value(Key.effectsVolume, fallback: effectsDefault))
    }
}
