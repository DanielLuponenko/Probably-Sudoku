import SwiftUI

/// The studio card is a moment between the system launch screen and the club
/// room. It uses the approved KAN-31 lockup at a deliberate, readable size;
/// neither the game title nor its controls appear until the card is gone.
struct StudioSplashView: View {
    var reduceMotion: Bool
    var onFinished: () -> Void

    @State private var opacity = 0.0
    @State private var scale: CGFloat = 0.94
    @State private var hasFinished = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // The studio moment is an autonomous card, not an instruction
                // screen. A clean black stage makes the unchanged studio mark
                // appear before the game room without a bright flash.
                Color.black

                Image("StudioLogoOnBlack")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: min(proxy.size.width * 0.78, 420),
                           maxHeight: proxy.size.height * 0.68)
                    .opacity(opacity)
                    .scaleEffect(scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("DannyLovesAnna Game Studio. Continue to Probably Sudoku")
        .onAppear { enter() }
    }

    private func enter() {
        #if DEBUG
        // A photographable launch card for UI QA. A normal launch still uses
        // the short production timing below; the production card has no tap
        // affordance or interactive dismissal.
        if ProcessInfo.processInfo.arguments.contains("-holdStudioSplash") {
            opacity = 1
            scale = 1
            return
        }
        #endif

        guard reduceMotion else {
            withAnimation(.easeOut(duration: 0.32)) {
                opacity = 1
                scale = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.55))
                finish()
            }
            return
        }

        opacity = 1
        scale = 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            finish()
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        if reduceMotion {
            onFinished()
        } else {
            withAnimation(.easeIn(duration: 0.20)) { opacity = 0 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(210))
                onFinished()
            }
        }
    }
}

#Preview {
    StudioSplashView(reduceMotion: false, onFinished: {})
}
