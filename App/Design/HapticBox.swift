import Foundation

#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// Owns the Taptic engine used by the app-level haptic vocabulary. The engine
/// is deliberately separate from the game rules so Simulator builds can fall
/// back safely and gameplay never depends on hardware availability.
@MainActor
final class HapticBox {
    static let shared = HapticBox()

    enum Event {
        case transient(at: TimeInterval, intensity: Float, sharpness: Float)
        case continuous(at: TimeInterval, duration: TimeInterval,
                        intensity: Float, sharpness: Float)
    }

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    #endif

    private init() {}

    func prepare() {
        #if canImport(CoreHaptics)
        guard supportsHaptics else { return }
        start()
        #endif
    }

    func play(_ events: [Event], fallback: () -> Void) {
        #if canImport(CoreHaptics)
        guard supportsHaptics, let pattern = pattern(from: events) else {
            fallback()
            return
        }
        start()
        guard let engine else {
            fallback()
            return
        }
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // An interruption or background transition is never a gameplay
            // error. Use the one-shot fallback and leave the next event free
            // to restart the engine.
            fallback()
        }
        #else
        fallback()
        #endif
    }

    #if canImport(CoreHaptics)
    private func start() {
        if engine == nil {
            let created = try? CHHapticEngine()
            created?.playsHapticsOnly = true
            created?.isAutoShutdownEnabled = true
            created?.resetHandler = { [weak self] in
                Task { @MainActor in self?.start() }
            }
            engine = created
        }
        try? engine?.start()
    }

    private func pattern(from events: [Event]) -> CHHapticPattern? {
        let patternEvents = events.map { event -> CHHapticEvent in
            switch event {
            case let .transient(time, intensity, sharpness):
                return CHHapticEvent(eventType: .hapticTransient,
                                     parameters: parameters(intensity, sharpness),
                                     relativeTime: time)
            case let .continuous(time, duration, intensity, sharpness):
                return CHHapticEvent(eventType: .hapticContinuous,
                                     parameters: parameters(intensity, sharpness),
                                     relativeTime: time,
                                     duration: duration)
            }
        }
        return try? CHHapticPattern(events: patternEvents, parameters: [])
    }

    private func parameters(_ intensity: Float, _ sharpness: Float) -> [CHHapticEventParameter] {
        [
            CHHapticEventParameter(parameterID: .hapticIntensity,
                                   value: min(max(intensity, 0), 1)),
            CHHapticEventParameter(parameterID: .hapticSharpness,
                                   value: min(max(sharpness, 0), 1)),
        ]
    }
    #endif
}
