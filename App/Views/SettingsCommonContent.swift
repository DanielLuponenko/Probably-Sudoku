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
        case .guide: "Rules and scoring, at a glance"
        case .practice: "Learn by playing a practice Book"
        case .achievements: "Your collection and milestones"
        case .privacy: "Ad choices, policy and help"
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

/// Destination ownership stays above PaperSlip's compact/enlarged article
/// layouts. Reflowing the preferences must not dismiss an open practice Book.
struct SettingsNavigationHost<Content: View, Panel: View>: View {
    @State private var destination: SettingsDestination?
    @ViewBuilder var content: (Binding<SettingsDestination?>) -> Content
    @ViewBuilder var panel: (SettingsDestination) -> Panel

    init(@ViewBuilder content: @escaping (Binding<SettingsDestination?>) -> Content,
         @ViewBuilder panel: @escaping (SettingsDestination) -> Panel) {
        self.content = content
        self.panel = panel
    }

    var body: some View {
        content($destination)
            .paperPanel(item: $destination, content: panel)
    }
}

extension SettingsNavigationHost where Panel == SettingsDestinationPresentation {
    init(@ViewBuilder content: @escaping (Binding<SettingsDestination?>) -> Content) {
        self.content = content
        self.panel = { SettingsDestinationPresentation(destination: $0) }
    }
}

struct SettingsCommonContent: View {
    @AppStorage(AppPreferences.Key.haptics) private var haptics = true
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true
    @AppStorage(AppPreferences.Key.reducedMotion) private var reducedMotion = false
    @Binding var destination: SettingsDestination?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AudioSettingsSection()

            SettingsSection(title: "Play your way") {
                SlipToggle(label: "Haptics", note: nil, isOn: $haptics)
                    .accessibilityIdentifier("settings.haptics")
                SlipToggle(label: "Reduced motion",
                           note: "Gentler transitions and game effects.",
                           isOn: $reducedMotion)
                    .accessibilityIdentifier("settings.reducedMotion")
                SlipToggle(label: "Background motion",
                           note: reducedMotion ? "Paused while Reduced motion is on."
                               : "Scenery and quiet page details.",
                           isOn: $ambientMotion)
                    .accessibilityIdentifier("settings.backgroundMotion")
            }

            SettingsSection(title: "Learn & explore") {
                ForEach(SettingsDestination.allCases) { item in
                    SettingsNavigationRow(destination: item) { destination = item }
                }
            }
        }
        .onChange(of: haptics) { Haptics.preferencesChanged() }
    }
}

/// Settings has a short reading hierarchy, separate from the small printed
/// labels on receipts. All of its headings and explanations enlarge together.
struct SettingsSection<Content: View>: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .headline) private var headingSize: CGFloat = 17
    @ScaledMetric(relativeTo: .footnote) private var noteSize: CGFloat = 12
    let title: String
    var note: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: headingSize, weight: .semibold, design: .serif))
                .foregroundStyle(theme.paper.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 8)
            content
            if let note {
                Text(note)
                    .font(Print.body(noteSize))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 16)
    }
}

struct SettingsNavigationRow: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    let destination: SettingsDestination
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 11) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: destination.symbol)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(theme.paper.accentInk)
                        .frame(width: 34, height: 36)
                        .background(theme.paper.accentInk.opacity(0.07), in: .rect(cornerRadius: 4))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.title).font(Print.caption(14 * textScale))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(destination.detail).font(Print.body(11.5 * textScale))
                        .foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.paper.softInk)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(theme.paper.ink)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.paper.ruleInk.opacity(0.35)).frame(height: 0.5)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
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
    @Environment(\.paperPanelDismiss) private var dismiss
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
