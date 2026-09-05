import Foundation
import Observation

/// A local first-visit decision, deliberately outside player/cloud progress.
@MainActor
@Observable
final class OnboardingStore {
    enum Resolution: String, CaseIterable, Sendable {
        case experienced, skipped, completed
    }

    static let resolutionKey = "numberclub.onboarding.v1.resolution"
    private(set) var resolution: Resolution?
    var isResolved: Bool { resolution != nil }
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resolution = defaults.string(forKey: Self.resolutionKey).flatMap(Resolution.init(rawValue:))
    }

    /// Opening the question or beginning practice is not a completed decision.
    /// Repeated exit callbacks cannot overwrite the original choice.
    func resolve(as resolution: Resolution) {
        guard !isResolved else { return }
        defaults.set(resolution.rawValue, forKey: Self.resolutionKey)
        self.resolution = resolution
    }
}
