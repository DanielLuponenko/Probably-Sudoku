import Observation
import UIKit

/// Keeps the outgoing pixels intact while the replacement scene draws.
/// Tokens prevent a late render or animation completion from ending a newer return.
@MainActor @Observable
final class MenuReturnTransition {
    private(set) var snapshot: UIImage?
    private(set) var opacity: Double = 0
    private(set) var token: UUID?
    private var hasRenderedDestination = false

    var isActive: Bool { snapshot != nil }

    @discardableResult
    func begin(snapshot: UIImage?) -> UUID? {
        cancel()
        guard let snapshot else { return nil }
        self.snapshot = snapshot
        opacity = 1
        token = UUID()
        return token
    }

    @discardableResult
    func destinationDidRender(token: UUID) -> Bool {
        guard self.token == token, isActive, !hasRenderedDestination else { return false }
        hasRenderedDestination = true
        opacity = 0
        return true
    }

    func finish(token: UUID) {
        guard self.token == token, hasRenderedDestination else { return }
        cancel()
    }

    func cancel() {
        snapshot = nil
        token = nil
        opacity = 0
        hasRenderedDestination = false
    }

    static func captureCurrentScreen() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: \.isKeyWindow),
              window.bounds.width > 1, window.bounds.height > 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.preferredRange = .standard
        format.opaque = true
        var succeeded = false
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(window.bounds)
            succeeded = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        return succeeded ? image : nil
    }
}
