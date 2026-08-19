import SwiftUI
import AVFoundation

/// The desk behind the cover.
///
/// A loop plays when there is one and conditions allow it; otherwise the still
/// drifts. The still is always underneath, so the first frame is painted before
/// any video decoder has started and there is never a black flash.
struct CoverBackground: View {
    var reduceMotion: Bool

    private var usesVideo: Bool {
        !reduceMotion
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && CoverLoop.url != nil
    }

    var body: some View {
        ZStack {
            CoverStill(drifts: !reduceMotion && !usesVideo)

            if usesVideo, let url = CoverLoop.url {
                LoopingVideo(url: url)
                    .transition(.opacity)
            }

            CoverLighting()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private enum CoverLoop {
    /// Absent until the loop is added to the bundle, which is what makes the
    /// still a fallback rather than a placeholder.
    static let url = Bundle.main.url(forResource: "cover-loop", withExtension: "mp4")
}

/// The photograph, drifting. Slow enough that it is never the thing you are
/// looking at — about a percent of the frame over half a minute.
private struct CoverStill: View {
    var drifts: Bool
    @State private var drifted = false

    var body: some View {
        GeometryReader { proxy in
            Image("Cover")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(drifted ? 1.075 : 1.02, anchor: .center)
                .offset(x: drifted ? 7 : -7, y: drifted ? -10 : 8)
                .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            guard drifts else { return }
            withAnimation(.easeInOut(duration: 34).repeatForever(autoreverses: true)) {
                drifted = true
            }
        }
    }
}

/// The lamp, up and to the left — the same one the desk and the page turn are
/// lit by — and a gradient that keeps the type legible over whatever the
/// photograph happens to be doing underneath it.
private struct CoverLighting: View {
    @State private var lamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RadialGradient(
                    colors: [Color(hex: 0xFFD9A0).opacity(lamped ? 0.20 : 0.11), .clear],
                    center: .init(x: 0.12, y: 0.06),
                    startRadius: 10,
                    endRadius: proxy.size.height * 0.85
                )
                .blendMode(.plusLighter)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .black.opacity(0.12), location: 0.32),
                        .init(color: .black.opacity(0.30), location: 0.62),
                        .init(color: .black.opacity(0.88), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            // Off the drift's rhythm, so the two never pulse together.
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                lamped = true
            }
        }
    }
}

/// A muted, gapless loop. `AVPlayerLooper` splices the item back to back on the
/// queue player, which is what avoids the stutter you get from seeking to zero
/// on `didPlayToEndTime`.
private struct LoopingVideo: UIViewRepresentable {
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
