import AVFAudio
import Foundation

@MainActor
final class AVGameAudioPlayback: GameAudioPlayback {
    private let bundle: Bundle
    private let session: AVAudioSession
    private var music: AVAudioPlayer?
    private var musicCue: GameMusicCue?
    private var preparedMusic: (cue: GameMusicCue, player: AVAudioPlayer)?
    private var retiringMusic: AVAudioPlayer?
    private var retirementTask: Task<Void, Never>?
    private var effects: [GameSound: [AVAudioPlayer]] = [:]
    private let sessionQueue = DispatchQueue(label: "com.numberclub.audio-session", qos: .userInitiated)
    private var effectsPreparationGeneration = 0

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

    func activateOffMain(cue: GameMusicCue,
                         completion: @escaping @MainActor (Error?) -> Void) {
        let session = self.session
        effectsPreparationGeneration &+= 1
        let preparationGeneration = effectsPreparationGeneration
        let shouldPrepareEffects = effects.isEmpty
        let musicURL = music == nil || musicCue != cue ? cue.url(in: bundle) : nil
        sessionQueue.async {
            do {
                try session.setCategory(.ambient, mode: .default)
                try session.setActive(true)
                let preparedEffects = shouldPrepareEffects ? Self.makeEffectPool() : nil
                let preparedMusic: AVAudioPlayer?
                if let musicURL {
                    preparedMusic = try? Self.makeMusicPlayer(url: musicURL)
                } else {
                    preparedMusic = nil
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.effectsPreparationGeneration == preparationGeneration else { return }
                    if self.effects.isEmpty, let preparedEffects {
                        self.effects = preparedEffects
                    }
                    if let preparedMusic {
                        self.preparedMusic = (cue, preparedMusic)
                    }
                    completion(nil)
                }
            } catch {
                Task { @MainActor [weak self] in
                    guard let self,
                          self.effectsPreparationGeneration == preparationGeneration else { return }
                    completion(error)
                }
            }
        }
    }

    func deactivate() {
        invalidatePendingEffectPreparation()
        pauseMusic()
        stopEffects()
        sessionQueue.sync {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func deactivateOffMain() {
        invalidatePendingEffectPreparation()
        pauseMusic()
        stopEffects()
        sessionQueue.async { [session] in
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func resumeMusic(_ cue: GameMusicCue, volume: Float) throws {
        guard volume > 0 else { pauseMusic(); return }
        if music == nil || musicCue != cue {
            guard let url = cue.url(in: bundle) else { throw PlaybackError.musicAssetMissing }
            let player: AVAudioPlayer
            if let preparedMusic, preparedMusic.cue == cue {
                player = preparedMusic.player
                self.preparedMusic = nil
            } else {
                // A cue can change while activation is preparing. Do not keep
                // the now-unused prewarm alive while synchronously recovering
                // the newly selected cue.
                self.preparedMusic = nil
                player = try Self.makeMusicPlayer(url: url)
            }
            // Bound the crossfade to two voices, including rapid Book changes.
            retirementTask?.cancel()
            retiringMusic?.stop()
            retiringMusic = nil
            guard player.play() else { throw PlaybackError.couldNotPlay }
            let outgoing = music
            retiringMusic = outgoing
            music = player
            musicCue = cue
            outgoing?.setVolume(0, fadeDuration: 0.65)
            retirementTask = Task { @MainActor [weak self, weak outgoing] in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                outgoing?.stop()
                if self?.retiringMusic === outgoing { self?.retiringMusic = nil }
            }
        }
        guard let music else { return }
        if !music.isPlaying {
            music.volume = 0
            guard music.play() else { throw PlaybackError.couldNotPlay }
        }
        music.setVolume(volume, fadeDuration: 0.65)
    }

    func setMusicVolume(_ volume: Float) {
        music?.setVolume(volume, fadeDuration: volume == 0 ? 0 : 0.1)
        if let retiringMusic {
            // A slider change must bound the outgoing voice too. Never lift
            // its fading level when the user raises the new track's volume.
            retiringMusic.volume = min(retiringMusic.volume, volume)
            retiringMusic.setVolume(0, fadeDuration: volume == 0 ? 0 : 0.18)
        }
    }

    func pauseMusic() {
        retirementTask?.cancel()
        retirementTask = nil
        retiringMusic?.stop()
        retiringMusic = nil
        music?.pause()
    }

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
        invalidatePendingEffectPreparation()
        pauseMusic()
        music = nil
        musicCue = nil
        preparedMusic = nil
        effects.removeAll()
    }

    private func prepareEffects() {
        effects = Self.makeEffectPool()
    }

    /// AVAudioPlayer construction and prepareToPlay can synchronously decode
    /// each WAV. Keep that bounded work on the same serial queue as session
    /// activation, then publish the finished pool on the main actor.
    private nonisolated static func makeEffectPool() -> [GameSound: [AVAudioPlayer]] {
        var prepared: [GameSound: [AVAudioPlayer]] = [:]
        for effect in GameSound.allCases {
            let data = ProceduralSound.wavData(for: effect)
            // Two short voices accommodate quick number/menu taps; all
            // other cues use one player. The pool is fixed, not allocated per tap.
            let count = effect == .tilePlace || effect == .menuTap ? 2 : 1
            prepared[effect] = (0..<count).compactMap { _ in
                guard let player = try? AVAudioPlayer(data: data) else { return nil }
                player.prepareToPlay()
                return player
            }
        }
        return prepared
    }

    private nonisolated static func makeMusicPlayer(url: URL) throws -> AVAudioPlayer {
        let player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        return player
    }

    private func invalidatePendingEffectPreparation() {
        effectsPreparationGeneration &+= 1
        preparedMusic = nil
    }

    private enum PlaybackError: Error, LocalizedError {
        case musicAssetMissing, couldNotPlay
        var errorDescription: String? {
            switch self {
            case .musicAssetMissing: "The selected bundled music asset is unavailable."
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
