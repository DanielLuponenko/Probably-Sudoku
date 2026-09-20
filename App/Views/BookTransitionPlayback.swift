import SwiftUI

/// One mounted cover owns its animation and completion. View tasks supply the
/// lifetime; a token also rejects waits that finish after an explicit cancel.
@MainActor @Observable
final class BookTransitionPlayback {
    enum Direction { case opening, closing }
    struct Request: Equatable {
        let isSceneActive: Bool
        let reduceMotion: Bool
        let skip: Bool
    }

    private(set) var angle: Double
    private(set) var zoom = 0.0
    private(set) var wash = 0.0
    private(set) var hasWithdrawnPage = false
    private(set) var hasFinished = false
    @ObservationIgnored private var token: UUID?
    private let direction: Direction

    init(direction: Direction) {
        self.direction = direction
        angle = direction == .opening ? 0 : -172
    }

    func cancel() { token = nil }

    func play(_ request: Request,
              hasOutgoingPage: Bool = false,
              wait: (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
              haptic: @MainActor () -> Void = { Haptics.pageTurn() },
              onFinish: () -> Void) async {
        guard request.isSceneActive, !hasFinished, !Task.isCancelled else { return }
        let current = UUID()
        token = current
        defer { if token == current { token = nil } }

        func isCurrent() -> Bool { token == current && !hasFinished && !Task.isCancelled }
        func finish() {
            guard isCurrent() else { return }
            hasFinished = true
            onFinish()
        }

        if request.reduceMotion { finish(); return }
        do {
            if request.skip {
                withAnimation(.easeIn(duration: 0.16)) {
                    switch direction {
                    case .opening:
                        wash = 1
                    case .closing:
                        // Leave a finished, readable cover for the stand's
                        // first-frame handoff, including a skipped closing.
                        angle = 0
                        if hasOutgoingPage { zoom = 1; hasWithdrawnPage = true }
                    }
                }
                try await wait(.milliseconds(160))
                finish()
                return
            }

            haptic()
            switch direction {
            case .opening:
                let swing = 1.05, handover = 0.30
                withAnimation(.timingCurve(0.32, 0, 0.32, 1, duration: swing)) { angle = -172 }
                try await wait(.seconds(swing * 0.55))
                guard isCurrent() else { return }
                withAnimation(.easeIn(duration: swing * 0.45 + handover)) { zoom = 1 }
                try await wait(.seconds(swing * 0.45))
                guard isCurrent() else { return }
                withAnimation(.easeIn(duration: handover)) { wash = 1 }
                try await wait(.seconds(handover))
            case .closing:
                if hasOutgoingPage, !hasWithdrawnPage {
                    withAnimation(.easeInOut(duration: 0.28)) { zoom = 1 }
                    try await wait(.milliseconds(280))
                    guard isCurrent() else { return }
                    hasWithdrawnPage = true
                }
                let swing = 0.9
                withAnimation(.timingCurve(0.32, 0, 0.32, 1, duration: swing)) { angle = 0 }
                try await wait(.seconds(swing * 0.7))
                guard isCurrent() else { return }
                // Keep the closed cover fully contrasted while the stand
                // warms. Its captured pixels bridge the renderer handoff.
                try await wait(.seconds(swing * 0.3))
            }
            finish()
        } catch {
            // Disappearance/backgrounding is not permission to finish early.
            // A later active view task may resume this same cover safely.
        }
    }
}
