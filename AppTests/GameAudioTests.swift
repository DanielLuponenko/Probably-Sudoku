import XCTest
import AVFAudio
@testable import ProbablySudoku

final class GameAudioTests: XCTestCase {
    // Policy tests never consult the host app's persisted mix. A player may
    // have legitimately muted either channel before running the test bundle.
    private static let audibleMix = AudioMix(master: 0.8, music: 0.45, effects: 0.7)

    @MainActor
    func testAudioIsDormantUntilForegroundAndStopsWhenInactive() async {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { .init(master: 0.8, music: 0.5, effects: 0.7) })
        audio.play(.tilePlace)
        audio.refreshVolumes()
        XCTAssertEqual(playback.activations, 0)
        XCTAssertTrue(playback.effects.isEmpty)

        audio.setSceneActive(true)
        XCTAssertEqual(playback.activations, 1)
        XCTAssertEqual(playback.musicVolume, 0.4, accuracy: 0.0001)
        XCTAssertTrue(playback.musicPlaying)
        audio.play(.tilePlace)
        XCTAssertEqual(playback.effects, [.tilePlace])
        XCTAssertEqual(playback.effectVolume, 0.56, accuracy: 0.0001)

        audio.setSceneActive(false)
        XCTAssertFalse(playback.musicPlaying)
        XCTAssertEqual(playback.deactivations, 1)
        audio.play(.win)
        XCTAssertEqual(playback.effects, [.tilePlace])
    }

    @MainActor
    func testAdPauseWinsOverForegroundAndDismissalDoesNotResumeInBackground() async {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.setAdPresented(true)
        XCTAssertFalse(playback.musicPlaying)
        XCTAssertEqual(playback.deactivations, 1)
        audio.play(.win)
        audio.setSceneActive(false)
        audio.setSceneActive(true)
        XCTAssertEqual(playback.activations, 1)
        XCTAssertTrue(playback.effects.isEmpty)

        audio.setSceneActive(false)
        audio.setAdPresented(false)
        XCTAssertFalse(playback.musicPlaying)
        XCTAssertEqual(playback.activations, 1)
        audio.setSceneActive(true)
        XCTAssertTrue(playback.musicPlaying)
        XCTAssertEqual(playback.activations, 2)
    }

    @MainActor
    func testMasterAndChannelZeroVolumesMuteImmediatelyAndIndependently() async {
        let playback = SilentAudioPlayback()
        var mix = AudioMix(master: 1, music: 1, effects: 1)
        let audio = GameAudio(playback: playback, preferences: { mix })
        audio.setSceneActive(true)
        mix = AudioMix(master: 1, music: 0, effects: 0.4)
        audio.refreshVolumes()
        XCTAssertFalse(playback.musicPlaying)
        audio.play(.tilePlace)
        XCTAssertEqual(playback.effects, [.tilePlace])
        XCTAssertEqual(playback.effectVolume, 0.4, accuracy: 0.0001)

        mix = AudioMix(master: 1, music: 0.3, effects: 0)
        audio.refreshVolumes()
        XCTAssertTrue(playback.musicPlaying)
        audio.play(.win)
        XCTAssertEqual(playback.effects, [.tilePlace])
        XCTAssertEqual(playback.effectVolume, 0)

        mix = AudioMix(master: 0, music: 1, effects: 1)
        audio.refreshVolumes()
        XCTAssertFalse(playback.musicPlaying)
        XCTAssertEqual(playback.musicVolume, 0)
        XCTAssertEqual(playback.deactivations, 1)
        audio.play(.error)
        XCTAssertEqual(playback.effects, [.tilePlace])
    }

    @MainActor
    func testMutedLaunchAndBackgroundVolumeChangesNeverActivatePlayback() async {
        let playback = SilentAudioPlayback()
        var mix = AudioMix(master: 0, music: 1, effects: 1)
        let audio = GameAudio(playback: playback, preferences: { mix })
        audio.setSceneActive(true)
        audio.play(.menuTap)
        XCTAssertEqual(playback.activations, 0)
        XCTAssertTrue(playback.effects.isEmpty)
        audio.setSceneActive(false)
        mix = AudioMix(master: 0.5, music: 0.6, effects: 0.4)
        audio.refreshVolumes()
        XCTAssertEqual(playback.activations, 0)
        XCTAssertFalse(playback.musicPlaying)
        audio.setSceneActive(true)
        XCTAssertEqual(playback.musicVolume, 0.3, accuracy: 0.0001)
        XCTAssertEqual(playback.effectVolume, 0.2, accuracy: 0.0001)
        XCTAssertEqual(playback.activations, 1)
    }

    @MainActor
    func testRepeatedLifecycleAndAdSignalsAreIdempotent() async {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.setSceneActive(true)
        XCTAssertEqual(playback.activations, 1)
        audio.setAdPresented(true)
        audio.setAdPresented(true)
        audio.refreshVolumes()
        XCTAssertEqual(playback.deactivations, 1)
        XCTAssertFalse(playback.musicPlaying)
        audio.setAdPresented(false)
        audio.setAdPresented(false)
        XCTAssertEqual(playback.activations, 2)
        XCTAssertTrue(playback.musicPlaying)
    }

    @MainActor
    func testDuplicateCuesAreCoalescedWithoutSuppressingDistinctFeedback() async {
        let playback = SilentAudioPlayback()
        var time = 10.0
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix }, now: { time })
        audio.setSceneActive(true)
        audio.play(.tilePlace)
        audio.play(.tilePlace)
        audio.play(.error)
        time += 0.06
        audio.play(.tilePlace)
        XCTAssertEqual(playback.effects, [.tilePlace, .error, .tilePlace])
    }

    @MainActor
    func testInterruptionAndDisconnectedHeadphonesRequireTheCorrectResumePolicy() async {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.interruptionBegan()
        audio.play(.menuTap)
        XCTAssertFalse(playback.musicPlaying)
        XCTAssertTrue(playback.effects.isEmpty)
        audio.interruptionEnded(shouldResume: true)
        XCTAssertTrue(playback.musicPlaying)

        audio.interruptionBegan()
        audio.interruptionEnded(shouldResume: false)
        XCTAssertTrue(audio.needsUserResume)
        XCTAssertFalse(playback.musicPlaying)
        audio.resumeAudio()
        XCTAssertTrue(playback.musicPlaying)

        audio.outputWasDisconnected()
        audio.refreshVolumes()
        XCTAssertFalse(playback.musicPlaying)
        audio.setSceneActive(false)
        audio.setSceneActive(true)
        XCTAssertTrue(audio.needsUserResume)
        XCTAssertFalse(playback.musicPlaying)
        audio.resumeAudio()
        XCTAssertFalse(audio.needsUserResume)
        XCTAssertTrue(playback.musicPlaying)
    }

    @MainActor
    func testMediaResetRebuildsPlaybackButNeverResumesOverAnAd() async {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.setAdPresented(true)
        audio.mediaServicesReset()
        XCTAssertEqual(playback.resets, 1)
        XCTAssertEqual(playback.activations, 1)
        XCTAssertFalse(playback.musicPlaying)
        audio.setAdPresented(false)
        XCTAssertEqual(playback.activations, 2)
        XCTAssertTrue(playback.musicPlaying)
    }

    @MainActor
    func testPlaybackFailureNeverChangesGameStateOrPreventsLaterRetry() async {
        let playback = SilentAudioPlayback()
        playback.activationFails = true
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        XCTAssertNotNil(audio.lastError)
        XCTAssertFalse(playback.musicPlaying)
        playback.activationFails = false
        audio.refreshVolumes()
        XCTAssertNil(audio.lastError)
        XCTAssertTrue(playback.musicPlaying)
    }

    @MainActor
    func testCueSelectedInBackgroundPlaysOnlyTheLatestChoiceWhenReturning() {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.selectMusic(.quietMargins)
        audio.selectMusic(.rainyMargins)
        XCTAssertTrue(playback.musicCues.isEmpty)
        XCTAssertEqual(playback.activations, 0)
        XCTAssertEqual(audio.musicCue, .rainyMargins)

        audio.setSceneActive(true)
        XCTAssertEqual(playback.musicCues, [.rainyMargins])
        audio.setSceneActive(false)
        audio.selectMusic(.finalDraft)
        XCTAssertEqual(playback.musicCues, [.rainyMargins])
        audio.setSceneActive(true)
        XCTAssertEqual(playback.musicCues, [.rainyMargins, .finalDraft])
    }

    @MainActor
    func testCueChangesUnderAnAdNeverStartMusicAndDismissalUsesTheLatestCue() {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.setAdPresented(true)
        audio.selectMusic(.redInk)
        audio.selectMusic(.quietMargins)
        audio.mediaServicesReset()
        XCTAssertEqual(playback.musicCues, [.bookshop])
        XCTAssertFalse(playback.musicPlaying)
        audio.setAdPresented(false)
        XCTAssertEqual(playback.musicCues, [.bookshop, .quietMargins])
        XCTAssertTrue(playback.musicPlaying)
    }

    @MainActor
    func testRapidCueChangesReuseTheAudioSessionAndDuplicateSelectionDoesNothing() {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        for cue in [GameMusicCue.quietMargins, .rainyMargins, .redInk, .finalDraft, .bookshop] {
            audio.selectMusic(cue)
            audio.selectMusic(cue)
        }
        XCTAssertEqual(playback.activations, 1)
        XCTAssertEqual(playback.deactivations, 0)
        XCTAssertEqual(playback.musicCues, [.bookshop, .quietMargins, .rainyMargins, .redInk, .finalDraft, .bookshop])
        XCTAssertEqual(audio.musicCue, .bookshop)
    }

    @MainActor
    func testMusicMuteRecordsCueChangesWithoutSilencingEffectsOrRestartingMusic() {
        let playback = SilentAudioPlayback()
        var mix = AudioMix(master: 1, music: 0.5, effects: 0.5)
        let audio = GameAudio(playback: playback, preferences: { mix })
        audio.setSceneActive(true)
        mix = AudioMix(master: 1, music: 0, effects: 0.5)
        audio.refreshVolumes()
        audio.selectMusic(.finalDraft)
        audio.play(.menuTap)
        XCTAssertEqual(playback.musicCues, [.bookshop])
        XCTAssertFalse(playback.musicPlaying)
        XCTAssertEqual(playback.effects, [.menuTap])
        mix = AudioMix(master: 1, music: 0.3, effects: 0.5)
        audio.refreshVolumes()
        XCTAssertEqual(playback.musicCues, [.bookshop, .finalDraft])
        XCTAssertEqual(playback.musicVolume, 0.3, accuracy: 0.0001)
    }

    @MainActor
    func testCueFailureCanRetryWithoutLosingSelectionOrBlockingEffects() {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        playback.musicFails = true
        audio.selectMusic(.redInk)
        audio.setSceneActive(true)
        XCTAssertEqual(audio.musicCue, .redInk)
        XCTAssertNotNil(audio.lastError)
        XCTAssertFalse(playback.musicPlaying)
        audio.play(.tilePlace)
        XCTAssertEqual(playback.effects, [.tilePlace])
        playback.musicFails = false
        audio.refreshVolumes()
        XCTAssertNil(audio.lastError)
        XCTAssertTrue(playback.musicPlaying)
        XCTAssertEqual(playback.musicCues.last, .redInk)
        XCTAssertEqual(playback.activations, 1)
    }

    @MainActor
    func testDisconnectedHeadphonesAndInterruptedScenesKeepNewCueDormantUntilExplicitResume() {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.outputWasDisconnected()
        audio.selectMusic(.rainyMargins)
        XCTAssertFalse(playback.musicPlaying)
        XCTAssertEqual(playback.musicCues, [.bookshop])
        audio.resumeAudio()
        XCTAssertEqual(playback.musicCues.last, .rainyMargins)
        audio.interruptionBegan()
        audio.selectMusic(.finalDraft)
        XCTAssertFalse(playback.musicPlaying)
        audio.interruptionEnded(shouldResume: false)
        XCTAssertFalse(playback.musicPlaying)
        audio.resumeAudio()
        XCTAssertEqual(playback.musicCues.last, .finalDraft)
    }
    @MainActor
    func testDeferredActivationDoesNotResumeAfterBackgroundTransition() async {
        let playback = SilentAudioPlayback()
        playback.deferActivation = true
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        XCTAssertEqual(playback.activationRequests, 1)
        XCTAssertEqual(playback.activations, 0)
        audio.setSceneActive(false)
        playback.completeDeferredActivation()
        XCTAssertFalse(playback.musicPlaying)
    }

    @MainActor
    func testDeferredActivationPublishesTheLatestCueAfterSelectionChanges() async {
        let playback = SilentAudioPlayback()
        playback.deferActivation = true
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.selectMusic(.quietMargins)
        audio.selectMusic(.rainyMargins)
        XCTAssertEqual(playback.activationCues, [.bookshop])
        playback.completeDeferredActivation()
        XCTAssertEqual(playback.musicCues, [.rainyMargins])
    }

    @MainActor
    func testAdCancellationDropsStaleCueActivationAndUsesLatestCueOnDismissal() async {
        let playback = SilentAudioPlayback()
        playback.deferActivation = true
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.selectMusic(.quietMargins)
        audio.setAdPresented(true)
        playback.completeDeferredActivation()
        XCTAssertTrue(playback.musicCues.isEmpty)

        audio.selectMusic(.finalDraft)
        audio.setAdPresented(false)
        XCTAssertEqual(playback.activationCues, [.bookshop, .finalDraft])
        playback.completeDeferredActivation()
        XCTAssertEqual(playback.musicCues, [.finalDraft])
    }

    @MainActor
    func testDeferredEffectIsDroppedWhenAdAppearsBeforeActivationCompletes() async {
        let playback = SilentAudioPlayback()
        playback.deferActivation = true
        var mix = AudioMix(master: 1, music: 0, effects: 0)
        let audio = GameAudio(playback: playback, preferences: { mix })
        audio.setSceneActive(true)
        mix = AudioMix(master: 1, music: 0, effects: 0.7)
        audio.play(.menuTap)
        audio.setAdPresented(true)
        playback.completeDeferredActivation()
        XCTAssertTrue(playback.effects.isEmpty)
        XCTAssertFalse(playback.musicPlaying)
    }

    @MainActor
    func testDeferredEffectCompletionReconcilesCurrentMusicMix() async {
        let playback = SilentAudioPlayback()
        playback.deferActivation = true
        var mix = AudioMix(master: 1, music: 0, effects: 0)
        let audio = GameAudio(playback: playback, preferences: { mix })
        audio.setSceneActive(true)
        mix = AudioMix(master: 1, music: 0, effects: 0.7)
        audio.play(.menuTap)
        mix = AudioMix(master: 1, music: 0.4, effects: 0)
        audio.refreshVolumes()
        playback.completeDeferredActivation()
        XCTAssertTrue(playback.musicPlaying)
        XCTAssertEqual(playback.musicVolume, 0.4, accuracy: 0.0001)
        XCTAssertTrue(playback.effects.isEmpty)
    }

    @MainActor
    func testMediaResetInvalidatesStaleActivationCompletion() async {
        let playback = SilentAudioPlayback()
        playback.deferActivation = true
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        audio.mediaServicesReset()
        XCTAssertEqual(playback.pendingActivations.count, 2)
        XCTAssertEqual(playback.activationCues, [.bookshop, .bookshop])
        playback.completeDeferredActivation(at: 0)
        XCTAssertFalse(playback.musicPlaying)
        playback.completeDeferredActivation(at: 0)
        XCTAssertTrue(playback.musicPlaying)
    }

    @MainActor
    func testAudioSystemEventsBridgeHandlesSyntheticLifecycleNotifications() async {
        let playback = SilentAudioPlayback()
        let audio = GameAudio(playback: playback, preferences: { Self.audibleMix })
        audio.setSceneActive(true)
        XCTAssertTrue(playback.musicPlaying)

        let center = NotificationCenter()
        let bridge = AudioSystemEvents(audio: audio, center: center)

        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey:
                                AVAudioSession.InterruptionType.began.rawValue])
        await settleNotificationTasks()
        // Repeated begin notifications remain safely paused.
        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey:
                                AVAudioSession.InterruptionType.began.rawValue])
        await settleNotificationTasks()
        XCTAssertFalse(playback.musicPlaying)

        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey:
                                AVAudioSession.InterruptionType.ended.rawValue,
                                AVAudioSessionInterruptionOptionKey:
                                AVAudioSession.InterruptionOptions.shouldResume.rawValue])
        await settleNotificationTasks()
        // A duplicate end is harmless and does not leave the policy paused.
        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey:
                                AVAudioSession.InterruptionType.ended.rawValue,
                                AVAudioSessionInterruptionOptionKey:
                                AVAudioSession.InterruptionOptions.shouldResume.rawValue])
        await settleNotificationTasks()
        XCTAssertTrue(playback.musicPlaying)

        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey:
                                AVAudioSession.InterruptionType.began.rawValue])
        await settleNotificationTasks()
        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey:
                                AVAudioSession.InterruptionType.ended.rawValue])
        await settleNotificationTasks()
        XCTAssertTrue(audio.needsUserResume)
        XCTAssertFalse(playback.musicPlaying)
        audio.resumeAudio()
        XCTAssertTrue(playback.musicPlaying)

        center.post(name: AVAudioSession.routeChangeNotification, object: nil,
                    userInfo: [AVAudioSessionRouteChangeReasonKey:
                                AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        await settleNotificationTasks()
        center.post(name: AVAudioSession.routeChangeNotification, object: nil,
                    userInfo: [AVAudioSessionRouteChangeReasonKey:
                                AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        await settleNotificationTasks()
        XCTAssertTrue(audio.needsUserResume)
        XCTAssertFalse(playback.musicPlaying)

        audio.resumeAudio()
        XCTAssertFalse(audio.needsUserResume)
        XCTAssertTrue(playback.musicPlaying)

        center.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        await settleNotificationTasks()
        XCTAssertEqual(playback.resets, 1)
        // The bridge remains live after reset and handles a later reset too.
        center.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        await settleNotificationTasks()
        XCTAssertEqual(playback.resets, 2)

        _ = bridge
    }

    @MainActor
    private func settleNotificationTasks() async {
        for _ in 0..<4 { await Task.yield() }
    }
}

@MainActor
private final class SilentAudioPlayback: GameAudioPlayback {
    var activations = 0
    var deactivations = 0
    var resets = 0
    var musicPlaying = false
    var musicVolume: Float = 0
    var effectVolume: Float = 0
    var effects: [GameSound] = []
    var activationFails = false
    var musicFails = false
    var deferActivation = false
    var activationRequests = 0
    var activationCues: [GameMusicCue] = []
    var pendingActivations: [(@MainActor (Error?) -> Void)] = []

    func activate() throws {
        if activationFails { throw NSError(domain: "SilentAudioTest", code: 1) }
        activations += 1
    }
    func activateOffMain(completion: @escaping @MainActor (Error?) -> Void) {
        activationRequests += 1
        guard deferActivation else {
            do { try activate(); completion(nil) }
            catch { completion(error) }
            return
        }
        pendingActivations.append(completion)
    }
    func activateOffMain(cue: GameMusicCue,
                         completion: @escaping @MainActor (Error?) -> Void) {
        activationCues.append(cue)
        activateOffMain(completion: completion)
    }
    func completeDeferredActivation() {
        completeDeferredActivation(at: 0)
    }
    func completeDeferredActivation(at index: Int) {
        guard pendingActivations.indices.contains(index) else { return }
        pendingActivations.remove(at: index)(nil)
    }
    func deactivate() { deactivations += 1; musicPlaying = false }
    func deactivateOffMain() { deactivate() }
    var musicCues: [GameMusicCue] = []
    func resumeMusic(_ cue: GameMusicCue, volume: Float) throws {
        if musicFails { throw NSError(domain: "SilentMusicTest", code: 2) }
        musicCues.append(cue); musicVolume = volume; musicPlaying = true
    }
    func setMusicVolume(_ volume: Float) { musicVolume = volume }
    func pauseMusic() { musicPlaying = false }
    func playEffect(_ effect: GameSound, volume: Float) { effects.append(effect); effectVolume = volume }
    func setEffectsVolume(_ volume: Float) { effectVolume = volume }
    func stopEffects() {}
    func reset() { resets += 1; musicPlaying = false }
}
