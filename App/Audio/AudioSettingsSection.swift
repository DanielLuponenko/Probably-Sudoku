import SwiftUI

/// The same persisted mix is available from the bookstore and the live Book.
struct AudioSettingsSection: View {
    @AppStorage(AppPreferences.Key.masterVolume) private var master = AppPreferences.audioMix().master
    @AppStorage(AppPreferences.Key.musicVolume) private var music = AppPreferences.audioMix().music
    @AppStorage(AppPreferences.Key.effectsVolume) private var effects = AppPreferences.audioMix().effects
    private let audio = GameAudio.shared

    private var mix: AudioMix { AudioMix(master: master, music: music, effects: effects) }

    var body: some View {
        SlipSection(title: "Sound", note: "Zero mutes. The iPhone’s Silent Mode is always respected.") {
            VolumeSlider(title: "Master", value: $master)
            VolumeSlider(title: "Music", value: $music)
            VolumeSlider(title: "Sound effects", value: $effects)
            if audio.needsUserResume {
                PaperButton(title: "Resume audio", kind: .quiet) { audio.resumeAudio() }
            }
        }
        .onChange(of: mix, initial: true) { audio.refreshVolumes() }
    }
}

private struct VolumeSlider: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    let title: String
    @Binding var value: Double

    private var valueLabel: String {
        value <= 0 ? "Muted" : "\(Int((min(1, max(0, value)) * 100).rounded()))%"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Print.body(14 * textScale))
                Spacer(minLength: 8)
                Text(valueLabel).font(Print.caption(11 * textScale)).monospacedDigit()
            }
            .foregroundStyle(theme.paper.ink)
            .accessibilityHidden(true)
            Slider(value: $value, in: 0...1, step: 0.05)
                .tint(theme.paper.ink)
                .frame(minHeight: 44)
                .accessibilityLabel("\(title) volume")
                .accessibilityValue(valueLabel)
                .accessibilityHint("Set to zero to mute.")
        }
    }
}
