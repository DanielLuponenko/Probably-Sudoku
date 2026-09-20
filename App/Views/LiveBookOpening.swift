import SwiftUI
import ProbablySudokuEngine

/// Opening the Book.
///
/// Not a clip. A recorded opening is one Book, one size and one light: every
/// volume would need its own, the app would grow by a film per title, and the
/// cut from the shelf to the film is always visible because the desk in the
/// film is not the desk you were just looking at.
///
/// Here it is the same desk and the same Book, and the front board simply
/// swings on its joint.
struct LiveBookOpening: View {
    var edition: BookEdition
    var obstacle: Obstacle
    var reduceMotion: Bool
    var onFinish: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    /// Drawn once, when the Book is opened — not per frame, or the page would
    /// change its mind while you were reading it.
    @State private var epigraph = Jokes.random()
    @State private var playback = BookTransitionPlayback(direction: .opening)
    @State private var skipRequested = false

    private var playbackRequest: BookTransitionPlayback.Request {
        .init(isSceneActive: scenePhase == .active, reduceMotion: reduceMotion, skip: skipRequested)
    }

    var body: some View {
        Button { skipRequested = true } label: {
            ZStack {
                ShelfBackdrop(book: edition)

                GeometryReader { proxy in
                    LiveBook(edition: edition, openAngle: playback.angle,
                             selectedObstacle: obstacle, epigraph: epigraph)
                        .frame(width: proxy.size.width * 0.72)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1 + playback.zoom * 1.35, anchor: .center)
                        .offset(y: -proxy.size.height * 0.02 * playback.zoom)
                }

                Paper.page.opacity(playback.wash).ignoresSafeArea()
            }
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .background(Paper.deskDark)
        .statusBarHidden()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .task(id: playbackRequest) {
            await playback.play(playbackRequest, onFinish: onFinish)
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.cancel() } }
        .onDisappear { playback.cancel() }
        .accessibilityLabel("Opening the book")
        .accessibilityHint("Double tap to skip")
        .accessibilityAction(named: "Skip book opening") { skipRequested = true }
    }
}
