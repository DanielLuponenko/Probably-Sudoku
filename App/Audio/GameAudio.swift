import Foundation
import Observation

@MainActor
protocol GameAudioPlayback: AnyObject {
    func activate() throws
    func activateOffMain(completion: @escaping @MainActor (Error?) -> Void)
    func activateOffMain(cue: GameMusicCue, completion: @escaping @MainActor (Error?) -> Void)
    func deactivate()
    func deactivateOffMain()
    func resumeMusic(_ cue: GameMusicCue, volume: Float) throws
    func setMusicVolume(_ volume: Float)
    func pauseMusic()
    func playEffect(_ effect: GameSound, volume: Float) throws
    func setEffectsVolume(_ volume: Float)
    func stopEffects()
    func reset()
}

extension GameAudioPlayback {
    func activateOffMain(cue: GameMusicCue, completion: @escaping @MainActor (Error?) -> Void) {
        activateOffMain(completion: completion)
    }

    /// Test doubles and non-AV implementations retain the synchronous policy.
    /// The production AV backend overrides this to keep session negotiation off
    /// SwiftUI's first main-actor transaction.
    func activateOffMain(completion: @escaping @MainActor (Error?) -> Void) {
        do {
            try activate()
            completion(nil)
        } catch {
            completion(error)
        }
    }

    func deactivateOffMain() { deactivate() }
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
    @ObservationIgnored private var activationInFlight = false
    @ObservationIgnored private var activationGeneration = 0
    @ObservationIgnored private var throttle = FeedbackThrottle()
    private(set) var musicCue: GameMusicCue = .bookshop

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

    func selectMusic(_ cue: GameMusicCue) {
        guard musicCue != cue else { return }
        musicCue = cue
        // A cue may change while backgrounded or under an ad. Reconcile
        // records the selection without starting playback in either case.
        reconcile()
    }

    func resumeAudio() {
        needsUserResume = false
        reconcile()
    }

    func play(_ effect: GameSound) {
        guard mayPlay else { return }
        let volume = preferences().effectsGain
        guard volume > 0, throttle.allows(effect.rawValue, at: now(), interval: effect.minimumInterval) else { return }
        guard !activationInFlight else { return }
        guard !sessionActive else {
            do { try playback.playEffect(effect, volume: volume) }
            catch { lastError = error.localizedDescription }
            return
        }
        let generation = activationGeneration &+ 1
        activationGeneration = generation
        activationInFlight = true
        playback.activateOffMain(cue: musicCue) { [weak self] error in
            guard let self else { return }
            guard self.activationGeneration == generation else { return }
            self.activationInFlight = false
            guard error == nil else {
                self.lastError = error?.localizedDescription
                return
            }
            self.sessionActive = true
            self.reconcile()
            let currentEffectsGain = self.preferences().effectsGain
            guard self.mayPlay, self.sessionActive, currentEffectsGain > 0 else { return }
            do { try self.playback.playEffect(effect, volume: currentEffectsGain) }
            catch { self.lastError = error.localizedDescription }
        }
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
        let hadPendingSessionWork = activationInFlight || sessionActive
        activationGeneration &+= 1
        activationInFlight = false
        sessionActive = false
        if hadPendingSessionWork { playback.deactivateOffMain() }
        playback.reset()
        reconcile()
    }

    private var mayPlay: Bool { active && !adPresented && !interrupted && !needsUserResume }

    private func reconcile() {
        let mix = preferences()
        playback.setMusicVolume(mix.musicGain)
        playback.setEffectsVolume(mix.effectsGain)
        guard mayPlay, mix.master > 0, mix.musicGain > 0 || mix.effectsGain > 0 else {
            activationGeneration &+= 1
            playback.pauseMusic()
            playback.stopEffects()
            if sessionActive || activationInFlight {
                playback.deactivateOffMain()
                sessionActive = false
                activationInFlight = false
            }
            return
        }
        do {
            guard !sessionActive else {
                if mix.musicGain > 0 { try playback.resumeMusic(musicCue, volume: mix.musicGain) }
                else { playback.pauseMusic() }
                if mix.effectsGain == 0 { playback.stopEffects() }
                lastError = nil
                return
            }
            guard !activationInFlight else { return }
            activationGeneration &+= 1
            let generation = activationGeneration
            activationInFlight = true
            playback.activateOffMain(cue: musicCue) { [weak self] error in
                guard let self else { return }
                guard self.activationGeneration == generation else { return }
                self.activationInFlight = false
                guard error == nil else {
                    self.lastError = error?.localizedDescription
                    return
                }
                self.sessionActive = true
                self.reconcile()
            }
        } catch { lastError = error.localizedDescription }
    }
}
