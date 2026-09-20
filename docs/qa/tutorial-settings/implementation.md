# Tutorial and Settings refresh

## Shipped behavior

- The practice tutorial keeps its real engine and 24 guarded steps, with six chapter markers and progress based on the 15 actions the player actually completes. Short instructions and result receipts replace repeated explanation.
- The practice board uses the game's sage and paper materials. Its Hand stays below the board and remains visible after placement and banking. Live Points × Mult examples teach the current scoring model. Ordinary skips, Buff rewards and mandatory bosses are included in the final Book explanation.
- Settings groups Sound, Play your way, and Learn & explore in the existing custom paper panel. Preference labels, checks and destination rows share spacing, enlarged text behavior and touch targets. The saved game-owned Reduced motion preference is preserved.
- Master, Music and Sound effects have custom sage rails, ivory thumbs and visible percentage/mute readings. Track taps and horizontal drags seek in 5% steps. Vertical starts do not write a volume value. VoiceOver exposes one adjustable element per channel with 5% increments.
- Existing volume keys, legacy migration, master/channel mixing, Silent Mode, audio interruption handling and Resume audio behavior are retained. Reading Settings or replaying practice does not change the saved Book.

## Automated evidence

The functional and final focused gates cover 82 distinct test methods, all passing in their latest run: 22 audio, 5 audio preferences, 6 slider, 8 Settings, 7 custom panel, 3 game motion, 16 tutorial session, 5 tutorial presentation, 3 tutorial replay, 4 onboarding store and 3 onboarding eligibility.

- Functional gate: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_22-53-54-+0300.xcresult`.
- Final 18-method visual/slider recheck, zero failures: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_23-05-15-+0300.xcresult`.
- Final seven-method panel/welcome gate, zero failures: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_23-10-57-+0300.xcresult`. The welcome check accepts Vision's exact I/l ambiguity in “I've played before”; it still verifies the complete rendered choice bounds at normal and largest text sizes.
- Native enlarged-text QA found that switching normal → accessibility text size dismissed an open tutorial. A new nested-panel regression reproduced it with four failed assertions. `SettingsNavigationHost` now owns destinations above the reflowing article in both menu and in-Book Settings. The final 18-method Settings/panel/replay gate passes, including the same session, selection and progress surviving text-size changes: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_23-18-18-+0300.xcresult`.
- The patched native SE also preserved step 3, selected number 2 and 1/15 accepted actions through normal → AX3 → normal. The next placement advanced once to 2/15 and +65, confirming the lesson remained live rather than only preserving its picture.
- The first visual gate found undersized highlighted Hand tiles and soft numeral shadows; both were fixed. Retained-Hand proof measures the actual rendered complete card rims and printed ink, because whole-row OCR omitted a clearly visible isolated 5.
- Normal phone, compact phone, iPad and accessibility text renderings cover visible controls, text growth, complete Hand cards, and scroll reachability. Native UIKit slider rendering is checked separately from SwiftUI ImageRenderer, which does not flatten UIKit controls.
- Independent review found that an already-open custom panel did not refresh its captured VoiceOver environment. The panel now observes that OS value. A hosted regression verifies that environment refresh preserves the same live practice session, selection, engine snapshot, progress and panel identity. Actual OS VoiceOver switching was source-reviewed but was not tested natively.

Native evidence and simulator limitations are recorded in [native-review.md](native-review.md). The final plain app build succeeded; handoff candidate is `/tmp/NumberClub-tutorial-settings-handoff.app`, executable SHA-256 `ffedc210836fdf3a46f6cfae7d933afe4066c83b20e4199f772505647f5dd521`. This is a local simulator build; no App Store release was performed.

## User simulator handoff

Installed the verified candidate on the user's iPhone 17 Pro (`223A4227-A28E-4939-BB5E-3AAB820EB635`) and launched normally, without QA arguments. Fresh data backup: `/tmp/NumberClub-tutorial-settings-user-backup-20260919-232327`. Preservation record: `/tmp/nc-tutorial-settings-user-install.json`.

All existing Application Support and Preferences files matched before and after installation and launch. Opened the redesigned Settings for the user; its existing Master/Music/Effects values remain Muted/45%/70%, and game Reduced motion remains off. Replay tutorial is visible and ready to use.

The later check after opening Settings found only Game Center's sign-in banner date/count had changed (`GKSignInBannerPresentationDataKey`). Game preferences and saved Books remained unchanged.
