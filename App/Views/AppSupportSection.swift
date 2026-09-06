import SwiftUI

/// Available even in the ad-free edition, independent of advertising consent.
struct AppSupportSection: View {
    @Environment(\.cosmeticTheme) private var theme

    var body: some View {
        SlipSection(title: "Privacy & support", note: "Opens in your browser.") {
            Link("Privacy policy", destination: AppLinks.privacyPolicy)
                .accessibilityIdentifier("settings.privacyPolicy")
            Link("Support", destination: AppLinks.support)
                .accessibilityIdentifier("settings.support")
        }
        .font(Print.body(14))
        .foregroundStyle(theme.paper.ink)
        .buttonStyle(SupportLinkStyle())
    }
}

private struct SupportLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .underline()
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
