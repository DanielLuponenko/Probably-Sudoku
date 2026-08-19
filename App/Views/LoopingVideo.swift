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
