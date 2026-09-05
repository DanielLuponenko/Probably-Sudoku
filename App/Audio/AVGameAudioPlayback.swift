import AVFAudio
import Foundation

@MainActor
final class AVGameAudioPlayback: GameAudioPlayback {
    private let bundle: Bundle
    private let session: AVAudioSession
    private var music: AVAudioPlayer?
    private var effects: [GameSound: [AVAudioPlayer]] = [:]

    init(bundle: Bundle = .main, session: AVAudioSession = .sharedInstance()) {
        self.bundle = bundle
        self.session = session
    }

    func activate() throws {
        // Ambient obeys the hardware Silent switch and screen lock, and lets
        // the player's own music continue. No background-audio capability.
        try session.setCategory(.ambient, mode: .default)
        try session.setActive(true)
        if effects.isEmpty { prepareEffects() }
    }

    func deactivate() {
        pauseMusic()
        stopEffects()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func resumeMusic(volume: Float) throws {
        guard volume > 0 else { pauseMusic(); return }
        if music == nil {
            guard let url = musicURL else { throw PlaybackError.musicAssetMissing }
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            music = player
        }
        guard let music else { return }
        if !music.isPlaying {
            music.volume = 0
            guard music.play() else { throw PlaybackError.couldNotPlay }
        }
        music.setVolume(volume, fadeDuration: 0.35)
    }

    func setMusicVolume(_ volume: Float) {
        music?.setVolume(volume, fadeDuration: volume == 0 ? 0 : 0.1)
    }

    func pauseMusic() { music?.pause() }

    func playEffect(_ effect: GameSound, volume: Float) throws {
        guard volume > 0, let players = effects[effect],
              let player = players.first(where: { !$0.isPlaying }) ?? players.first else { return }
        player.currentTime = 0
        player.volume = volume
        guard player.play() else { throw PlaybackError.couldNotPlay }
    }

    func setEffectsVolume(_ volume: Float) {
        for player in effects.values.joined() { player.volume = volume }
    }

    func stopEffects() {
        for player in effects.values.joined() { player.stop(); player.currentTime = 0 }
    }

    func reset() {
        music = nil
        effects.removeAll()
    }

    private var musicURL: URL? {
        for ext in ["m4a", "wav", "mp3"] {
            if let url = bundle.url(forResource: "bookshop-theme", withExtension: ext)
                ?? bundle.url(forResource: "bookshop-theme", withExtension: ext, subdirectory: "Audio") {
                return url
            }
        }
        return nil
    }

    private func prepareEffects() {
        for effect in GameSound.allCases {
            let data = ProceduralSound.wavData(for: effect)
            // Two short voices accommodate quick number/menu taps; all
            // other cues use one player. This is a fixed eight-player pool.
            let count = effect == .tilePlace || effect == .menuTap ? 2 : 1
            effects[effect] = (0..<count).compactMap { _ in
                guard let player = try? AVAudioPlayer(data: data) else { return nil }
                player.prepareToPlay()
                return player
            }
        }
    }

    private enum PlaybackError: Error, LocalizedError {
        case musicAssetMissing, couldNotPlay
        var errorDescription: String? {
            switch self {
            case .musicAssetMissing: "The bundled bookshop-theme music asset is unavailable."
            case .couldNotPlay: "Audio playback could not start."
            }
        }
    }
}

/// System events stay at the platform boundary; the policy above accepts
/// plain values and is tested with silent, in-memory playback fakes.
@MainActor
final class AudioSystemEvents {
    private var observers: [NSObjectProtocol] = []
    private let center: NotificationCenter

    init(audio: GameAudio, center: NotificationCenter = .default) {
        self.center = center
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak audio] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue:
                note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor in
                if type == .began { audio?.interruptionBegan() }
                else { audio?.interruptionEnded(shouldResume: options.contains(.shouldResume)) }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: nil, queue: .main) { [weak audio] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in audio?.outputWasDisconnected() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: nil, queue: .main) { [weak audio] _ in
            Task { @MainActor in audio?.mediaServicesReset() }
        })
    }

    deinit { for observer in observers { center.removeObserver(observer) } }
}
