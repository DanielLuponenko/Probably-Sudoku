import SwiftUI

/// One compact index shared by the bookstore and a paused Book. Preferences
/// stay inline; longer reading pages get a destination, not another long block
/// of text in Settings. These routes own no game state and cannot advance play.
enum SettingsDestination: String, CaseIterable, Identifiable {
    case guide, practice, achievements, privacy

    var id: String { rawValue }
    var title: String {
        switch self {
        case .guide: "How to play"
        case .practice: "Replay tutorial"
        case .achievements: "Achievements"
        case .privacy: "Privacy & support"
        }
    }
    var detail: String {
        switch self {
        case .guide: "Rules, scoring and real examples"
        case .practice: "A 90-second practice Book; your run is safe"
        case .achievements: "Your collection and Game Center"
        case .privacy: "Privacy policy, ad choices and help"
        }
    }
    var symbol: String {
        switch self {
        case .guide: "book"
        case .practice: "arrow.counterclockwise"
        case .achievements: "rosette"
        case .privacy: "hand.raised"
        }
    }
    var accessibilityID: String {
        switch self {
        case .guide: "learning-how-to-play"
        case .practice: "learning-replay-tutorial"
        case .achievements: "settings.achievements"
        case .privacy: "settings.privacyAndSupport"
        }
    }
}

struct SettingsCommonContent: View {
    @AppStorage(AppPreferences.Key.haptics) private var haptics = true
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cosmeticTheme) private var theme
    @State private var destination: SettingsDestination?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AudioSettingsSection()

            SlipSection(title: "Feel & accessibility") {
                SlipToggle(label: "Haptics", note: "Tactile feedback for buttons and the board.", isOn: $haptics)
                SlipToggle(label: "Background motion",
                           note: reduceMotion ? "Paused by iOS Reduce Motion."
                               : "Bookstore scenery and quiet page animations.",
                           isOn: $ambientMotion)
                Text("Follows iOS text size, VoiceOver and Reduce Motion.")
                    .font(Print.body(11.5))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SlipSection(title: "Explore") {
                ForEach(SettingsDestination.allCases) { item in
                    SettingsNavigationRow(destination: item) { destination = item }
                }
            }
        }
        .onChange(of: haptics) { Haptics.preferencesChanged() }
        .fullScreenCover(item: $destination) { destination in
            SettingsDestinationPresentation(destination: destination)
        }
    }
}

struct SettingsNavigationRow: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    let destination: SettingsDestination
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 11) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.title).font(Print.body(14 * textScale))
                    Text(destination.detail).font(Print.body(11 * textScale))
                        .foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.paper.softInk)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(theme.paper.ink)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(destination.title)
        .accessibilityHint(destination.detail)
        .accessibilityIdentifier(destination.accessibilityID)
    }
}

/// The presenter remains Settings throughout, so dismissing an achievement or
/// guide returns to the same slip/scroll position and leaves an active timer
/// paused. No book-page mutation and no automatic Game Center sign-in.
struct SettingsDestinationPresentation: View {
    let destination: SettingsDestination
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cosmeticTheme) private var theme

    var body: some View {
        switch destination {
        case .guide:
            HelpSlip { dismiss() }
                .background(theme.paper.warm.ignoresSafeArea())
        case .practice:
            TutorialView(presentation: .replay) { _ in dismiss() }
        case .achievements:
            AchievementsPageView(backLabel: "Back to Settings", showsGameCenter: true) { dismiss() }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.paper.page.ignoresSafeArea())
                .accessibilityIdentifier("settings.achievementsPage")
        case .privacy:
            PaperSlip(title: "Privacy & support", subtitle: nil,
                      closeLabel: "Back to Settings", maximumWidth: 540,
                      onClose: { dismiss() }) {
                VStack(alignment: .leading, spacing: 0) {
                    AppSupportSection()
                    AdsPrivacySection()
                    SlipSection(title: "About") {
                        LeaderRow(label: "Studio", value: "DlA")
                        LeaderRow(label: "Version", value: Self.version)
                    }
                }
            }
            .background(theme.paper.warm.ignoresSafeArea())
        }
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
