import Foundation

/// Original, short sound effects synthesized from noise and damped tones.
/// These are not music and contain no samples from external recordings.
enum ProceduralSound {
    static let sampleRate = 22_050

    static func samples(for sound: GameSound) -> [Int16] {
        let duration: Double
        switch sound {
        case .paperTurn: duration = 0.46
        case .tilePlace: duration = 0.11
        case .toss: duration = 0.25
        case .win: duration = 0.72
        case .error: duration = 0.17
        case .menuTap: duration = 0.075
        case .scoreTick, .scoreTickHigh: duration = 0.09
        case .scoreMultiply: duration = 0.19
        case .scoreBank: duration = 0.23
        }
        let count = Int(duration * Double(sampleRate))
        var random: UInt64 = UInt64(GameSound.allCases.firstIndex(of: sound)! + 1) * 7919
        var lowNoise = 0.0
        var midNoise = 0.0
        var sheet = PaperSheet()
        var samples = [Int16]()
        samples.reserveCapacity(count)
        for index in 0..<count {
            let time = Double(index) / Double(sampleRate)
            let position = Double(index) / Double(max(1, count - 1))
            random = random &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double(random >> 11) / Double(UInt64(1) << 53) * 2 - 1
            lowNoise += 0.18 * (noise - lowNoise)
            midNoise += 0.57 * (noise - midNoise)
            let fibre = midNoise - lowNoise
            let envelope = sin(.pi * position)
            // A dry object has a fast contact transient and several unequal,
            // quickly damped modes—not one sine tone behind a slow fade-in.
            func woodenStrike(age: Double, pitch: Double, weight: Double = 1) -> Double {
                guard age >= 0 else { return 0 }
                let attack = min(1, age / 0.0008)
                let body = sin(2 * .pi * pitch * age) * exp(-age * 55)
                    + 0.51 * sin(2 * .pi * pitch * 2.31 * age) * exp(-age * 92)
                    + 0.22 * sin(2 * .pi * pitch * 4.07 * age) * exp(-age * 145)
                return weight * attack * (body * 0.30 + fibre * exp(-age * 150) * 0.38)
            }
            let value: Double
            switch sound {
            case .paperTurn:
                value = sheet.sample(noise: noise, time: time)
            case .toss:
                let shuffle = pow(sin(.pi * 5 * position), 8)
                value = fibre * envelope * (0.23 + 0.55 * shuffle)
                    + woodenStrike(age: time - 0.17, pitch: 370, weight: 0.48)
            case .tilePlace, .menuTap:
                value = woodenStrike(age: time, pitch: sound == .tilePlace ? 510 : 760,
                                     weight: sound == .tilePlace ? 0.85 : 0.57)
            case .win:
                let notes = [(523.25, 0.0), (659.25, 0.08), (783.99, 0.16), (1046.5, 0.27)]
                value = notes.reduce(0.0) { total, note in
                    let age = time - note.1
                    guard age >= 0 else { return total }
                    let onset = min(1, age / 0.006)
                    let tone = sin(2 * .pi * note.0 * age) * exp(-age * 10)
                        + 0.18 * sin(2 * .pi * note.0 * 2.76 * age) * exp(-age * 24)
                    return total + tone * onset * 0.16
                } * min(1, (duration - time) / 0.025)
            case .error:
                value = woodenStrike(age: time, pitch: 340, weight: 0.65)
                    + woodenStrike(age: time - 0.067, pitch: 275, weight: 0.45)
            case .scoreTick, .scoreTickHigh, .scoreMultiply, .scoreBank:
                switch sound {
                case .scoreTick: value = woodenStrike(age: time, pitch: 680, weight: 0.65)
                case .scoreTickHigh: value = woodenStrike(age: time, pitch: 1020, weight: 0.7)
                case .scoreMultiply:
                    value = woodenStrike(age: time, pitch: 680, weight: 0.6)
                        + woodenStrike(age: time - 0.055, pitch: 1020, weight: 0.7)
                default:
                    // Rubber stamp contact, brief paper compression, then lift.
                    value = woodenStrike(age: time, pitch: 280, weight: 1.0)
                        + fibre * exp(-pow((time - 0.035) / 0.022, 2)) * 0.24
                        + woodenStrike(age: time - 0.11, pitch: 730, weight: 0.2)
                }
            }
            let tail = min(1, max(0, (duration - time - 1 / Double(sampleRate)) / 0.008))
            let onset = min(1, time / 0.0005)
            samples.append(Int16((min(0.7, max(-0.7, value * onset * tail)) * Double(Int16.max)).rounded()))
        }
        return samples
    }

    /// A flexible sheet, not repeated bursts of bright white-noise grit.
    /// Cascaded low-pass stages round the fibres before any envelope is
    /// applied; slow subtraction removes DC without introducing a tone.
    private struct PaperSheet {
        private var body = [Double](repeating: 0, count: 2)
        private var crease = [Double](repeating: 0, count: 3)
        private var contact = [Double](repeating: 0, count: 2)
        private var bodyFloor = 0.0
        private var creaseFloor = 0.0
        private var contactFloor = 0.0

        private static func coefficient(_ frequency: Double) -> Double {
            1 - exp(-2 * .pi * frequency / Double(ProceduralSound.sampleRate))
        }
        private let bodyRate = coefficient(1_050)
        private let bodyFloorRate = coefficient(180)
        private let creaseRate = coefficient(1_850)
        private let creaseFloorRate = coefficient(620)
        private let contactRate = coefficient(480)
        private let contactFloorRate = coefficient(90)

        mutating func sample(noise: Double, time: Double) -> Double {
            body[0] += bodyRate * (noise - body[0])
            body[1] += bodyRate * (body[0] - body[1])
            bodyFloor += bodyFloorRate * (body[1] - bodyFloor)
            crease[0] += creaseRate * (noise - crease[0])
            crease[1] += creaseRate * (crease[0] - crease[1])
            crease[2] += creaseRate * (crease[1] - crease[2])
            creaseFloor += creaseFloorRate * (crease[2] - creaseFloor)
            contact[0] += contactRate * (noise - contact[0])
            contact[1] += contactRate * (contact[0] - contact[1])
            contactFloor += contactFloorRate * (contact[1] - contactFloor)

            // Smooth, unequal pressure gestures: lift, sheet flex, two small
            // folds, then the page settles onto the stack. No oscillator,
            // pitch sweep, sharp gate, or sustained high-frequency layer.
            let lift = Self.pressure(time, from: 0.012, to: 0.160)
            let flex = Self.pressure(time, from: 0.075, to: 0.335)
            let folds = Self.pressure(time, from: 0.052, to: 0.095)
                + 0.72 * Self.pressure(time, from: 0.190, to: 0.248)
            let settle = Self.pressure(time, from: 0.325, to: 0.450)
            return (body[1] - bodyFloor) * (0.58 * lift + 0.72 * flex)
                + (crease[2] - creaseFloor) * folds * 0.28
                + (contact[1] - contactFloor) * settle * 0.80
        }

        private static func pressure(_ time: Double, from start: Double, to end: Double) -> Double {
            guard time > start, time < end else { return 0 }
            let phase = (time - start) / (end - start)
            let arc = sin(.pi * phase)
            return arc * arc
        }
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
