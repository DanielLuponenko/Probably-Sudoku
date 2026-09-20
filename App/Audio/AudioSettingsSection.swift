import SwiftUI

/// The same persisted mix is available from the bookstore and the live Book.
struct AudioSettingsSection: View {
    @AppStorage(AppPreferences.Key.masterVolume) private var master = AppPreferences.audioMix().master
    @AppStorage(AppPreferences.Key.musicVolume) private var music = AppPreferences.audioMix().music
    @AppStorage(AppPreferences.Key.effectsVolume) private var effects = AppPreferences.audioMix().effects
    private let audio = GameAudio.shared

    private var mix: AudioMix { AudioMix(master: master, music: music, effects: effects) }

    var body: some View {
        SettingsSection(title: "Sound", note: mix.master == 0
                        ? "Master is muted. Silent Mode is respected."
                        : "Silent Mode is respected.") {
            PaperVolumeSlider(title: "Master", value: $master)
            PaperVolumeSlider(title: "Music", value: $music)
            PaperVolumeSlider(title: "Sound effects", value: $effects)
            if audio.needsUserResume {
                PaperButton(title: "Resume audio", kind: .quiet) { audio.resumeAudio() }
            }
        }
        .onChange(of: mix, initial: true) { audio.refreshVolumes() }
    }
}
