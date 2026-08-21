import SwiftUI
import UIKit

/// A short, skippable studio credit. It lives before the room so the menu
/// remains ready for input the moment the credit leaves.
struct StudioIntroView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var hasFinished = false

    var body: some View {
        Button(action: finish) {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x11100F), Color(hex: 0x2A2119)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    studioLogo
                        .frame(maxWidth: 330)
                        .opacity(revealed ? 1 : 0)
                        .scaleEffect(revealed ? 1 : 0.94)

                    Text("PRESENTS")
                        .font(Print.caption(12))
                        .tracking(2.4)
                        .foregroundStyle(Color(hex: 0xFFF4D7).opacity(0.72))
                        .opacity(revealed ? 1 : 0)
                }
                .padding(32)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Danny Loves Anna Game Studio")
        .accessibilityHint("Double tap to skip the studio intro")
        .task {
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 0.24)) { revealed = true }
            try? await Task.sleep(for: reduceMotion ? .milliseconds(220) : .milliseconds(1_450))
            finish()
        }
    }

    @ViewBuilder
    private var studioLogo: some View {
        if let logo = UIImage(named: "studio-logo-horizontal") {
            Image(uiImage: logo)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Text("DANNYLOVESANNA\nGAME STUDIO")
                .font(Print.clubTitle(30))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: 0xFFF4D7))
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}
