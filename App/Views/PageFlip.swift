import SwiftUI
import UIKit
import OSLog

struct PageTurnSnapshot {
    let image: CGImage
    let size: CGSize
    let scale: CGFloat
}

/// Explicit preparation/presentation boundary; lifecycle tests use a manual
/// driver without a GPU or wall-clock delays.
@MainActor protocol PageTurnRendering: AnyObject {
    func prepare(image: CGImage, pageSize: CGSize, scale: CGFloat) -> Bool
    func start(duration: TimeInterval, heldProgress: Double?,
               onFirstFrame: @escaping @MainActor () -> Void,
               completion: @escaping @MainActor () -> Void)
    func cancel()
}

extension PageCurlRenderer: PageTurnRendering {}

/// Owns one turn, not its per-frame progress. The printed side comes from the
/// currently displayed page, never a newly mounted SwiftUI copy of that page.
@MainActor @Observable
final class PageFlipper {
    private static let log = Logger(subsystem: "com.numberclub.app", category: "PageTurn")
    private(set) var isFlipping = false
    private(set) var renderer: PageCurlRenderer?
    @ObservationIgnored weak var captureAnchor: UIView?
    @ObservationIgnored private var turnID: UUID?
    @ObservationIgnored private var didCommit = false
    @ObservationIgnored private var finishWaiting: (() -> Void)?
    @ObservationIgnored private var driver: (any PageTurnRendering)?
    @ObservationIgnored private let snapshotProvider: (() -> PageTurnSnapshot?)?
    private let duration: TimeInterval = 0.72

    init(driver: (any PageTurnRendering)? = nil,
         snapshotProvider: (() -> PageTurnSnapshot?)? = nil) {
        self.driver = driver
        self.snapshotProvider = snapshotProvider
    }

    func prepareRenderer() {
        guard driver == nil else { return }
        renderer = PageCurlRenderer.make()
        driver = renderer
        if renderer == nil { Self.log.error("Page renderer could not be prepared") }
    }

    func flip(from model: GameModel, reduceMotion: Bool,
              _ change: @escaping () -> Void) async {
        guard !isFlipping, !Task.isCancelled else { return }
        guard !reduceMotion else { change(); return }
        guard let driver else {
            Self.log.error("Page turn unavailable: no renderer")
            change()
            return
        }
        guard let snapshot = snapshotProvider?() ?? capturePage() else {
            Self.log.error("Page turn unavailable: no displayed page snapshot")
            change()
            return
        }
        guard driver.prepare(image: snapshot.image, pageSize: snapshot.size,
                             scale: snapshot.scale) else {
            // Accessibility, unavailable GPU, or a detached page must never
            // block navigation. There is no rigid-card animation fallback.
            Self.log.error("Page turn unavailable: texture preparation failed")
            change()
            return
        }

        let id = UUID()
        turnID = id
        didCommit = false
        isFlipping = true
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                finishWaiting = { continuation.resume() }
                driver.start(duration: duration, heldProgress: nil, onFirstFrame: { [weak self] in
                    guard let self, self.turnID == id, !self.didCommit else { return }
                    self.didCommit = true
                    // The complete old page now covers the destination.
                    // Mutating the game cannot alter the printed texture.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { change() }
                    Haptics.pageTurn()
                }, completion: { [weak self] in
                    self?.finish(id: id)
                })
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id: id) }
        }
    }

    /// Navigation/backgrounding and task cancellation both release the leaf.
    /// Stale callbacks cannot finish or mutate a later turn.
    func cancel() {
        guard let id = turnID else { return }
        cancel(id: id)
    }

    private func cancel(id: UUID) {
        guard turnID == id else { return }
        driver?.cancel()
        finish(id: id)
    }

    private func finish(id: UUID) {
        guard turnID == id else { return }
        turnID = nil
        didCommit = false
        isFlipping = false
        let resume = finishWaiting
        finishWaiting = nil
        resume?()
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Deterministic inspection of the same mesh used in normal play.
    func hold(from model: GameModel, at progress: Double,
              _ change: @escaping () -> Void) {
        guard !isFlipping, let driver, let snapshot = snapshotProvider?() ?? capturePage(),
              driver.prepare(image: snapshot.image, pageSize: snapshot.size,
                               scale: snapshot.scale) else { return }
        let id = UUID()
        turnID = id
        didCommit = false
        isFlipping = true
        driver.start(duration: duration, heldProgress: min(1, max(0, progress)),
                       onFirstFrame: { [weak self] in
            guard let self, self.turnID == id, !self.didCommit else { return }
            self.didCommit = true
            change()
        }, completion: { [weak self] in self?.finish(id: id) })
    }
    #endif

    private func capturePage() -> PageTurnSnapshot? {
        guard let anchor = captureAnchor, let window = anchor.window,
              anchor.bounds.width > 1, anchor.bounds.height > 1 else { return nil }
        let rect = anchor.convert(anchor.bounds, to: window)
        guard rect.minX.isFinite, rect.minY.isFinite else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(window.screen.scale, 2)
        // Metal's image loader needs ordinary 8-bit stock, not an extended-
        // range UIKit capture whose half-float pixels it cannot decode.
        format.preferredRange = .standard
        format.opaque = true
        let imageRenderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        var succeeded = false
        let image = imageRenderer.image { context in
            // Capture the existing hierarchy, including current @State,
            // Canvas drawings, environment and presentation state.
            context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
            succeeded = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        guard succeeded, let cgImage = image.cgImage else { return nil }
        return PageTurnSnapshot(image: cgImage, size: rect.size, scale: format.scale)
    }
}

/// Invisible marker defining the displayed leaf's bounds in its real window.
/// It does not host or recreate any SwiftUI content.
struct PageCaptureAnchor: UIViewRepresentable {
    let flipper: PageFlipper

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        flipper.captureAnchor = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        flipper.captureAnchor = view
    }
}
