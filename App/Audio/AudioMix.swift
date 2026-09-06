import Foundation

struct AudioMix: Equatable, Sendable {
    let master: Double
    let music: Double
    let effects: Double

    init(master: Double, music: Double, effects: Double) {
        func clamp(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
        self.master = clamp(master)
        self.music = clamp(music)
        self.effects = clamp(effects)
    }

    var musicGain: Float { Float(master * music) }
    var effectsGain: Float { Float(master * effects) }
}

/// Coalesces duplicate UI callbacks without adding delays to a real action.
struct FeedbackThrottle {
    private var lastPlayed: [String: TimeInterval] = [:]

    mutating func allows(_ key: String, at time: TimeInterval, interval: TimeInterval) -> Bool {
        if let last = lastPlayed[key], time >= last, time - last < interval { return false }
        lastPlayed[key] = time
        return true
    }

    mutating func reset() { lastPlayed.removeAll(keepingCapacity: true) }
}

enum GameSound: String, CaseIterable, Sendable {
    case paperTurn, tilePlace, toss, win, error, menuTap
    case scoreTick, scoreTickHigh, scoreMultiply, scoreBank

    var minimumInterval: TimeInterval {
        switch self {
        case .paperTurn: 0.12
        case .tilePlace, .menuTap: 0.055
        case .toss: 0.12
        case .win: 0.65
        case .error: 0.15
        case .scoreTick, .scoreTickHigh, .scoreMultiply, .scoreBank: 0.08
        }
    }
}
