import SwiftUI
import ProbablySudokuEngine

/// The Book's final movement uses the same constructed cover as its opening:
/// it closes only after the reader dismisses the congratulations page.
struct LiveBookClosing: View {
    var edition: BookEdition
    var obstacle: Obstacle = .none
    var reduceMotion: Bool
    var outgoingPage: UIImage? = nil
    var onFinish: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    @State private var playback = BookTransitionPlayback(direction: .closing)
    @State private var skipRequested = false

    private var playbackRequest: BookTransitionPlayback.Request {
        .init(isSceneActive: scenePhase == .active, reduceMotion: reduceMotion, skip: skipRequested)
    }

    var body: some View {
        Button { skipRequested = true } label: {
            ZStack {
                ShelfBackdrop(book: edition)
                GeometryReader { proxy in
                    LiveBook(edition: edition, openAngle: playback.angle, selectedObstacle: obstacle,
                             pageImage: outgoingPage)
                        .frame(width: proxy.size.width * 0.72)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    if let outgoingPage {
                        let page = BookClosingPageGeometry(viewport: proxy.size, imageSize: outgoingPage.size)
                        let rect = page.frame(at: playback.zoom)
                        // These are the exact visible pixels the player just
                        // closed, shrinking into the same image on the leaf.
                        Image(uiImage: outgoingPage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .opacity(playback.hasWithdrawnPage ? 0 : 1)
                            .accessibilityHidden(true)
                    }
                }
                Paper.page.opacity(playback.wash).ignoresSafeArea()
            }
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .background(Paper.deskDark)
        .statusBarHidden()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Closing \(edition.title)")
        .accessibilityHint("Double tap to skip")
        .accessibilityAction(named: "Skip book closing") { skipRequested = true }
        .task(id: playbackRequest) {
            await playback.play(playbackRequest, hasOutgoingPage: outgoingPage != nil, onFinish: onFinish)
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.cancel() } }
        .onDisappear { playback.cancel() }
    }
}

/// Fits the screenshot without stretching it. The target matches LiveBook's
/// printed leaf: 1.4-height stock, its inset, and its small case offset.
struct BookClosingPageGeometry {
    let initial: CGRect
    let leaf: CGRect

    init(viewport: CGSize, imageSize: CGSize) {
        initial = Self.fit(imageSize, in: CGRect(origin: .zero, size: viewport))
        let width = viewport.width * 0.72
        let height = width * 1.4
        let inset = width * 0.035
        let printArea = CGRect(x: (viewport.width - width) / 2 + width * 0.016 + inset,
                               y: (viewport.height - height) / 2 + width * 0.020 + inset,
                               width: width - inset * 2, height: height - inset * 2)
        leaf = Self.fit(imageSize, in: printArea)
    }

    func frame(at progress: Double) -> CGRect {
        if progress <= 0 { return initial }
        if progress >= 1 { return leaf }
        let progress = CGFloat(min(1, max(0, progress)))
        return CGRect(x: initial.minX + (leaf.minX - initial.minX) * progress,
                      y: initial.minY + (leaf.minY - initial.minY) * progress,
                      width: initial.width + (leaf.width - initial.width) * progress,
                      height: initial.height + (leaf.height - initial.height) * progress)
    }

    private static func fit(_ imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}
