import Foundation

/// Original, short sound effects synthesized from noise and damped tones.
/// These are not music and contain no samples from external recordings.
enum ProceduralSound {
    static let sampleRate = 22_050

    static func samples(for sound: GameSound) -> [Int16] {
        let duration: Double
        switch sound {
        case .paperTurn: duration = 0.24
        case .tilePlace: duration = 0.085
        case .toss: duration = 0.19
        case .win: duration = 0.58
        case .error: duration = 0.14
        case .menuTap: duration = 0.055
        }
        let count = Int(duration * Double(sampleRate))
        var random: UInt64 = UInt64(GameSound.allCases.firstIndex(of: sound)! + 1) * 7919
        var lowNoise = 0.0
        var samples = [Int16]()
        samples.reserveCapacity(count)
        for index in 0..<count {
            let time = Double(index) / Double(sampleRate)
            let position = Double(index) / Double(max(1, count - 1))
            random = random &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double(random >> 11) / Double(UInt64(1) << 53) * 2 - 1
            lowNoise += 0.18 * (noise - lowNoise)
            let envelope = sin(.pi * position)
            let value: Double
            switch sound {
            case .paperTurn:
                let folds = 0.55 + 0.45 * pow(sin(.pi * 2.5 * position), 2)
                value = (noise * 0.08 + lowNoise * 0.45) * envelope * folds
            case .toss:
                value = (noise - lowNoise) * 0.18 * pow(envelope, 1.4) * (1 - position * 0.35)
            case .tilePlace, .menuTap:
                let frequency = sound == .tilePlace ? 470.0 : 820.0
                let tone = sin(2 * .pi * frequency * time) + 0.28 * sin(2 * .pi * frequency * 2.7 * time)
                value = (tone * 0.27 + noise * 0.07) * exp(-time * 58) * min(1, time / 0.002) * envelope
            case .win:
                let notes = [(523.25, 0.0), (659.25, 0.085), (783.99, 0.17)]
                value = notes.reduce(0.0) { total, note in
                    let age = time - note.1
                    guard age >= 0 else { return total }
                    let onset = min(1, age / 0.006)
                    let tone = sin(2 * .pi * note.0 * age) + 0.13 * sin(2 * .pi * note.0 * 2 * age)
                    return total + tone * exp(-age * 12) * onset * 0.15
                } * min(1, (duration - time) / 0.025)
            case .error:
                value = (sin(2 * .pi * 115 * time) * 0.32 + lowNoise * 0.1)
                    * exp(-time * 27) * min(1, time / 0.004) * envelope
            }
            samples.append(Int16((min(0.6, max(-0.6, value)) * Double(Int16.max)).rounded()))
        }
        return samples
    }

    static func wavData(for sound: GameSound) -> Data {
        let samples = samples(for: sound)
        let byteCount = UInt32(samples.count * MemoryLayout<Int16>.size)
        var data = Data()
        func word<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        word(UInt32(36) + byteCount)
        data.append(contentsOf: "WAVEfmt ".utf8)
        word(UInt32(16))
        word(UInt16(1)) // PCM
        word(UInt16(1)) // Mono
        word(UInt32(sampleRate))
        word(UInt32(sampleRate * 2))
        word(UInt16(2))
        word(UInt16(16))
        data.append(contentsOf: "data".utf8)
        word(byteCount)
        for sample in samples { word(sample) }
        return data
    }
}
