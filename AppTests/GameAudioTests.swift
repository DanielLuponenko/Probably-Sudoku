import XCTest
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

    func activate() throws {
        if activationFails { throw NSError(domain: "SilentAudioTest", code: 1) }
        activations += 1
    }
    func deactivate() { deactivations += 1; musicPlaying = false }
    func resumeMusic(volume: Float) { musicVolume = volume; musicPlaying = true }
    func setMusicVolume(_ volume: Float) { musicVolume = volume }
    func pauseMusic() { musicPlaying = false }
    func playEffect(_ effect: GameSound, volume: Float) { effects.append(effect); effectVolume = volume }
    func setEffectsVolume(_ volume: Float) { effectVolume = volume }
    func stopEffects() {}
    func reset() { resets += 1; musicPlaying = false }
}
