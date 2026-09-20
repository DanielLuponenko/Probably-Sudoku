# Game-owned motion preference

19 September 2026. The player requested full animations by default, independently of iOS Reduce Motion, with a saved in-game Reduced motion option.

## Implementation

- `GameMotionPreferences` supplies the saved `settings.reducedMotion` value above `ContentView`. Its default is false for both new and existing installations. No OS setting or historical preference is imported.
- The intro, SceneKit bookstore, Book/page transitions, gameplay feedback and paper panels read the shared `gameReduceMotion` environment value. iOS's read-only Reduce Motion environment remains untouched.
- Settings uses the existing paper toggle design. Changes apply live; open nested panels refresh their copied environment without replacing their owners. The choice persists across relaunches.
- Dynamic Type, VoiceOver, Haptics, Background motion and existing low-power/thermal handling remain independent. The change does not alter run data or gameplay rules.
- Settled effects are not replayed when motion is restored; subsequent events use the current choice.

## Automated verification

Two focused runs passed **113 tests, zero failures** on isolated simulator `9C12E469-F20B-4728-9887-72F94459B081`:

- 59 tests: new preference/default/remount tests; live nested panel updates and identity preservation; normal and AX5 Settings readability; rack gestures, intro camera, Book transition playback, page flips and paper-panel ownership.
- 54 tests: all boss board visual/lifecycle tests; background/thermal render policies; inventory drag cancellation and exactly-once sales; marker hold/tap/resource preservation; real mid-animation margin-text rendering. The latter no longer skips based on the unrelated OS setting.

Hosted tests deliberately inject the writable game environment, not a simulated OS value. Actual OS-on behavior is checked separately in native QA.

Logs:

- `/tmp/nc-game-motion-preference-tests.log`
- `/tmp/nc-game-motion-regressions.log`

Results:

- `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_22-16-05-+0300.xcresult`
- `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_22-17-41-+0300.xcresult`

The first attempted implementation tried writing Apple's read-only environment key and failed compilation. It was replaced by the explicit game-owned key before either passing run. No failed build was installed.

Independent source review found no remaining production reads of `accessibilityReduceMotion` or `UIAccessibility.isReduceMotionEnabled`, no live host bypass, and no state-identity or persistence blocker. Candidate executable SHA-256: `66d77b757bd71c649f5c537223a443de73ba1e04c2087fd0d5416381c0308532`.

The actual Debug application code is in `ProbablySudoku.debug.dylib`, SHA-256 `e6974a469751a49a1b057872d05da7b57840e02d6948bcdeca59a3d612bf1afb`. Both passing runs and the frozen native candidate contain that same code.

## Native verification

An independent agent tested the frozen candidate on isolated iPhone 17 Pro `D04D3836-357E-4E92-811D-6D14E3BA1E01` with actual iOS Reduce Motion enabled:

- With the game preference absent, the intro, bookstore camera approach, rack rotation and Book pullout still animated.
- The in-game switch changed live. Board/card identities, score, coins and turn remained unchanged across both toggle directions.
- Reduced motion stayed on after process termination and relaunch. Switching it off also survived relaunch while the OS setting remained on; native capture includes intermediate curled page frames.
- Native rack evidence uses the Next Book control. Physical flick velocity is covered by the rack gesture tests; a computer-use drag did not reliably establish that gesture.
- The tester restored the original OS Reduce Motion setting (off), stopped the app and restored all eight original Support/Preferences files byte-for-byte, then rebooted the isolated device without launching the game to avoid preference cache races. The SE and user's simulator were not used for these mutations.

Captures and the independent report are in [motion-preference](motion-preference/). Actual Debug application code matches both automated runs.

## User simulator handoff

The verified build is open normally on the user's iPhone 17 Pro `223A4227-A28E-4939-BB5E-3AAB820EB635`, showing Play. No QA flags or system-setting changes were applied there.

A fresh backup was made at `/tmp/NumberClub-game-motion-user-backup-20260919-223021`. All backed-up Support/Preferences files were byte-identical after installation and after normal launch, including the saved Book and profile. The new preference remains absent, so full animations are the default. Preservation evidence: `/tmp/nc-game-motion-user-install.json`.
