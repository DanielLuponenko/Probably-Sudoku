import XCTest
@testable import ProbablySudoku

final class AudioPreferencesTests: XCTestCase {
    func testMixClampsInputsAndMultipliesMasterIntoBothChannels() {
        XCTAssertEqual(AudioMix(master: -1, music: 2, effects: .infinity),
                       AudioMix(master: 0, music: 1, effects: 0))
        XCTAssertEqual(AudioMix(master: .nan, music: 1, effects: 1).musicGain, 0)
        let mix = AudioMix(master: 0.5, music: 0.4, effects: 0.8)
        XCTAssertEqual(mix.musicGain, 0.2, accuracy: 0.0001)
        XCTAssertEqual(mix.effectsGain, 0.4, accuracy: 0.0001)
    }

    func testFreshDefaultsAndAllThreeIndependentVolumesPersist() throws {
        try withDefaults { defaults in
            XCTAssertEqual(AppPreferences.audioMix(in: defaults), .init(master: 0.8, music: 0.45, effects: 0.7))
            defaults.set(0.25, forKey: AppPreferences.Key.masterVolume)
            defaults.set(0, forKey: AppPreferences.Key.musicVolume)
            defaults.set(1, forKey: AppPreferences.Key.effectsVolume)
            XCTAssertEqual(AppPreferences.audioMix(in: defaults), .init(master: 0.25, music: 0, effects: 1))
            let restored = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
            XCTAssertEqual(AppPreferences.audioMix(in: restored), .init(master: 0.25, music: 0, effects: 1))
        }
    }

    func testLegacyMutedChannelsRemainMutedUntilTheirSliderChanges() throws {
        try withDefaults { defaults in
            defaults.set(false, forKey: AppPreferences.Key.music)
            defaults.set(false, forKey: AppPreferences.Key.sound)
            XCTAssertEqual(AppPreferences.audioMix(in: defaults), .init(master: 0.8, music: 0, effects: 0))
            defaults.set(0.6, forKey: AppPreferences.Key.musicVolume)
            XCTAssertEqual(AppPreferences.audioMix(in: defaults), .init(master: 0.8, music: 0.6, effects: 0))
        }
    }

    func testMalformedOrOutOfRangePersistedVolumesUseSafeBounds() throws {
        try withDefaults { defaults in
            defaults.set("bad", forKey: AppPreferences.Key.masterVolume)
            defaults.set(2, forKey: AppPreferences.Key.musicVolume)
            defaults.set(-3, forKey: AppPreferences.Key.effectsVolume)
            XCTAssertEqual(AppPreferences.audioMix(in: defaults), .init(master: 0.8, music: 1, effects: 0))
        }
    }

    func testFeedbackThrottleHasIndependentKeysAndRecoversFromClockReset() {
        var throttle = FeedbackThrottle()
        XCTAssertTrue(throttle.allows("menu", at: 1, interval: 0.1))
        XCTAssertFalse(throttle.allows("menu", at: 1.05, interval: 0.1))
        XCTAssertTrue(throttle.allows("paper", at: 1.05, interval: 0.1))
        XCTAssertTrue(throttle.allows("menu", at: 1.11, interval: 0.1))
        XCTAssertTrue(throttle.allows("menu", at: 0.5, interval: 0.1))
        throttle.reset()
        XCTAssertTrue(throttle.allows("menu", at: 0.5, interval: 0.1))
    }

    private let defaultsSuite = "NumberClub.AudioPreferencesTests.\(UUID().uuidString)"

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        try body(defaults)
    }
}
