import SwiftUI
import AVFoundation
import UIKit

/// A muted, gapless loop. `AVPlayerLooper` splices the item back to back on the
/// queue player, which is what avoids the stutter you get from seeking to zero
/// on `didPlayToEndTime`.
struct LoopingVideo: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.load(url: url)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var observers: [NSObjectProtocol] = []

        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        func load(url: URL) {
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer()
            player.isMuted = true
            // The cover must never interrupt anything the player is listening to.
            player.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: item)

            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            self.player = player
            player.play()

            // Backgrounding pauses an AVPlayer and it does not resume itself.
            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.player?.play() })
        }

        func stop() {
            player?.pause()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            looper?.disableLooping()
            playerLayer.player = nil
            player = nil
        }
    }
}

/// Plays a clip once and says when it is done. Used for the Book opening, which
/// is a transition rather than a backdrop.
struct OneShotVideo: UIViewRepresentable {
    var url: URL
    var onFinished: () -> Void

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.play(url: url, onFinished: onFinished)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {}

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.stop()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        private var player: AVPlayer?
        private var observers: [NSObjectProtocol] = []
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        func play(url: URL, onFinished: @escaping () -> Void) {
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .pause

            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            self.player = player

            // Decode the opening frames before playing, so the cut from the
            // shelf into the clip has something to show immediately.
            player.automaticallyWaitsToMinimizeStalling = false

            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: item, queue: .main
            ) { _ in onFinished() })
            // Backgrounding mid-transition would otherwise strand the player.
            observers.append(center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.player?.play() })

            player.play()
        }

        func stop() {
            player?.pause()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            playerLayer.player = nil
            player = nil
        }
    }
}

/// Opening a Book: the cover swings open, then the page blurs and whitens out,
/// and the first Puzzle is already there behind it.
///
/// The blur starts before the clip ends so the two movements overlap — cutting
/// to a blur after the video has stopped reads as two separate things
/// happening, which is exactly what a page turn should not feel like.
struct BookOpening: View {
    var url: URL
    /// Painted underneath, so the first thing on screen is the Book the player
    /// just tapped rather than black while the decoder gets going.
    var poster: String?
    var reduceMotion: Bool
    var onFinish: () -> Void

    @State private var frost: Double = 0
    @State private var wash: Double = 0
    @State private var finished = false

    private let handover = 0.75

    var body: some View {
        ZStack {
            Color(hex: 0x120D0A).ignoresSafeArea()

            if let poster {
                GeometryReader { proxy in
                    Image(poster)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            }

            OneShotVideo(url: url) { finish() }
                .ignoresSafeArea()

            // A material rather than .blur(): blurring a live 1604x2868 layer
            // forces a full offscreen pass every frame, which is what made the
            // hand-over stutter. A material is the same effect done by the
            // compositor.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(frost)
                .ignoresSafeArea()

            Paper.page.opacity(wash).ignoresSafeArea()
        }
        .task {
            guard !reduceMotion else { finish(); return }
            Haptics.pageTurn()

            let total = await Self.duration(of: url) ?? 3.2
            try? await Task.sleep(for: .seconds(max(0, total - handover)))
            withAnimation(.easeIn(duration: handover)) {
                frost = 1
                wash = 1
            }
            try? await Task.sleep(for: .seconds(handover))
            finish()
        }
        .accessibilityLabel("Opening the book")
    }

    /// Guards against the clip's end notification and the timed hand-over both
    /// firing, which would deal two Puzzles.
    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }

    private static func duration(of url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let seconds = try? await asset.load(.duration).seconds,
              seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }
}
