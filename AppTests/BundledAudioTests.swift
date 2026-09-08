import AVFAudio
import AudioToolbox
import XCTest
@testable import ProbablySudoku

final class BundledAudioTests: XCTestCase {
    func testAllFiveMusicCuesAreDistinctBundledStereoAACAndDecodeAcrossTheirDuration() throws {
        var resources = Set<URL>()
        var fileContents = Set<Data>()
        for cue in GameMusicCue.allCases {
            let url = try XCTUnwrap(cue.url(in: .main),
                                   "Missing \(cue.rawValue). A cue must never silently reuse the old theme.")
            resources.insert(url)
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 32_000, cue.rawValue)
            fileContents.insert(data)
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertFalse(player.isPlaying, "Metadata checks must not activate speakers")
            XCTAssertEqual(player.numberOfChannels, 2, cue.rawValue)
            XCTAssertGreaterThan(player.duration, 30, cue.rawValue)
            XCTAssertLessThan(player.duration, 600, cue.rawValue)

            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatMPEG4AAC,
                           cue.rawValue)
            XCTAssertEqual(file.processingFormat.channelCount, 2, cue.rawValue)
            XCTAssertEqual(file.processingFormat.sampleRate, 44_100, accuracy: 1, cue.rawValue)
            let frameCount = AVAudioFrameCount(file.processingFormat.sampleRate)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                       frameCapacity: frameCount))
            for position in [AVAudioFramePosition(0), file.length / 2,
                             max(0, file.length - AVAudioFramePosition(frameCount))] {
                file.framePosition = position
                try file.read(into: buffer, frameCount: frameCount)
                XCTAssertGreaterThan(buffer.frameLength, 0, "\(cue.rawValue) failed decode at \(position)")
                let channels = try XCTUnwrap(buffer.floatChannelData)
                for channel in 0..<Int(buffer.format.channelCount) {
                    let decoded = UnsafeBufferPointer(start: channels[channel], count: Int(buffer.frameLength))
                    XCTAssertTrue(decoded.allSatisfy(\.isFinite), "\(cue.rawValue) decoded a nonfinite sample")
                }
            }
            XCTAssertFalse(player.isPlaying)
        }
        XCTAssertEqual(resources.count, 5)
        XCTAssertEqual(fileContents.count, 5,
                       "Different filenames must not disguise copies of the same music")
    }

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
