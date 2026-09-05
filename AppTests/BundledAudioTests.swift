import AVFAudio
import AudioToolbox
import XCTest
@testable import ProbablySudoku

final class BundledAudioTests: XCTestCase {
    func testBundledThemeIsStereoAACThatAppleCanDecodeWithoutPlayback() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "bookshop-theme", withExtension: "m4a")
                ?? Bundle.main.url(forResource: "bookshop-theme", withExtension: "m4a", subdirectory: "Audio"),
            "The app bundle must include the licensed, transcoded theme."
        )
        let player = try AVAudioPlayer(contentsOf: url)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.numberOfChannels, 2)
        XCTAssertEqual(player.duration, 105.8, accuracy: 1)

        // Read PCM from the file decoder, never prepare/start a player or
        // activate AVAudioSession. Metadata alone would not prove decoding.
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatMPEG4AAC)
        XCTAssertEqual(file.processingFormat.channelCount, 2)
        XCTAssertEqual(file.processingFormat.sampleRate, 44_100, accuracy: 1)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 1_024))
        try file.read(into: buffer)
        XCTAssertGreaterThan(buffer.frameLength, 0)
        XCTAssertFalse(player.isPlaying)
    }

    func testEveryProceduralWaveCanOpenWithoutPlayback() throws {
        for sound in GameSound.allCases {
            let player = try AVAudioPlayer(data: ProceduralSound.wavData(for: sound))
            XCTAssertFalse(player.isPlaying, sound.rawValue)
            XCTAssertEqual(player.numberOfChannels, 1, sound.rawValue)
            let expectedDuration = Double(ProceduralSound.samples(for: sound).count) / Double(ProceduralSound.sampleRate)
            XCTAssertEqual(player.duration, expectedDuration, accuracy: 1 / Double(ProceduralSound.sampleRate), sound.rawValue)
        }
    }
}
