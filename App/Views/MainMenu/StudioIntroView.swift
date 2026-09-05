import SwiftUI

/// Keep the alternate entry point on the same approved studio identity.
struct StudioIntroView: View {
    var onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        StudioSplashView(reduceMotion: reduceMotion, onFinished: onFinish)
    }
}
