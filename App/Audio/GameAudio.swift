import Foundation
import Observation

@MainActor
protocol GameAudioPlayback: AnyObject {
    func activate() throws
    func deactivate()
    func resumeMusic(volume: Float) throws
    func setMusicVolume(_ volume: Float)
    func pauseMusic()
    func playEffect(_ effect: GameSound, volume: Float) throws
    func setEffectsVolume(_ volume: Float)
    func stopEffects()
    func reset()
}

/// Small playback policy, separate from AVFoundation so interruption, mute and
/// advertisement transitions can be proved without touching audio hardware.
@MainActor
@Observable
final class GameAudio {
    static let shared = GameAudio(playback: AVGameAudioPlayback(), observeSystemEvents: true)

    private(set) var needsUserResume = false
    private(set) var lastError: String?
    @ObservationIgnored private let playback: any GameAudioPlayback
    @ObservationIgnored private let preferences: () -> AudioMix
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private var systemEvents: AudioSystemEvents?
    @ObservationIgnored private var active = false
    @ObservationIgnored private var adPresented = false
    @ObservationIgnored private var interrupted = false
    @ObservationIgnored private var sessionActive = false
    @ObservationIgnored private var throttle = FeedbackThrottle()

    init(playback: any GameAudioPlayback,
         preferences: @escaping () -> AudioMix = { AppPreferences.audioMix() },
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         observeSystemEvents: Bool = false) {
        self.playback = playback
        self.preferences = preferences
        self.now = now
        if observeSystemEvents { systemEvents = AudioSystemEvents(audio: self) }
    }

    func setSceneActive(_ isActive: Bool) {
        guard active != isActive else { return }
        active = isActive
        // Some interruptions suspend the app without an ended notification.
        // Returning to the app is a new opportunity to activate its session.
        if isActive { interrupted = false }
        else { throttle.reset() }
        reconcile()
    }

    func setAdPresented(_ presented: Bool) {
        guard adPresented != presented else { return }
        adPresented = presented
        reconcile()
    }

    func refreshVolumes() { reconcile() }

    func resumeAudio() {
        needsUserResume = false
        reconcile()
    }

    func play(_ effect: GameSound) {
        guard mayPlay else { return }
        let volume = preferences().effectsGain
        guard volume > 0, throttle.allows(effect.rawValue, at: now(), interval: effect.minimumInterval) else { return }
        do {
            try activateIfNeeded()
            try playback.playEffect(effect, volume: volume)
        } catch { lastError = error.localizedDescription }
    }

    func interruptionBegan() {
        interrupted = true
        reconcile()
    }

    func interruptionEnded(shouldResume: Bool) {
        interrupted = false
        if !shouldResume { needsUserResume = true }
        reconcile()
    }

    func outputWasDisconnected() {
        needsUserResume = true
        reconcile()
    }

    func mediaServicesReset() {
        sessionActive = false
        playback.reset()
        reconcile()
    }

    private var mayPlay: Bool { active && !adPresented && !interrupted && !needsUserResume }

    private func activateIfNeeded() throws {
        guard !sessionActive else { return }
        try playback.activate()
        sessionActive = true
    }

    private func reconcile() {
        let mix = preferences()
        playback.setMusicVolume(mix.musicGain)
        playback.setEffectsVolume(mix.effectsGain)
        guard mayPlay, mix.master > 0, mix.musicGain > 0 || mix.effectsGain > 0 else {
            playback.pauseMusic()
            playback.stopEffects()
            if sessionActive { playback.deactivate(); sessionActive = false }
            return
        }
        do {
            try activateIfNeeded()
            if mix.musicGain > 0 { try playback.resumeMusic(volume: mix.musicGain) }
            else { playback.pauseMusic() }
            if mix.effectsGain == 0 { playback.stopEffects() }
            lastError = nil
        } catch { lastError = error.localizedDescription }
    }
}
