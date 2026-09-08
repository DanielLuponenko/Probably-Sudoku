# Simulator confidence follow-up — 7 September 2026

Evidence root: `/tmp/numberclub-simulator-confidence-20260907.Yycbst`.
One booted iPhone simulator, one app/profile/test session at a time, two build
workers, native app-host unit tests only. No NumberClubUIDriver or whole-Book
automation was used. No App Store upload or review change.

## Confirmed changes

- Shelf sign, decorative spines, wood and obstacle-tab renderers now specify
  1x logical pixels instead of inheriting the device's 3x display scale. The
  previous 3024×800 sign and 384×1536 spine explain corresponding large images
  in the earlier physical-device allocation trace. Covers retain their existing
  explicit 1.5x scale. Viewport-sized Metal/compositor surfaces are a separate
  allocation and are not claimed fixed by this change.
- The native shelf selector exposes adjustable, Next Book and Previous Book
  actions and announces Volume/title. Actual simulator accessibility actions
  reached all twelve editions and wrapped to Volume 1, without selecting them.
- Unlocked obstacle details now respond to their named accessibility action.
  The actual Obstacle I popup was verified. Further cleanup groups decorative
  cover fragments into one title heading and hides underlying shelf controls
  while a paper overlay is open.
- The user's 20:12:47 screenshot exposed uneven Book/benefit/Open spacing. The
  initial lower-label layout was superseded by their follow-up direction:
  remove that label and put benefits on the existing stationary shelf sign.
  Center the complete Book-and-bookmark silhouette; place the compact, raised
  Open action directly below it, with no selection dimming.

## Optimized simulator observation

Release configuration, iOS 26.3, `Book UI Regression Gate` simulator. Existing
simulator save resumed in the gameplay Shop; this was not a new completed Book.
The 300.61-second app-only Time Profiler recording covered all twelve native
shelf browse actions, Book selection, an obstacle-details popup, opening/resuming,
Shop details and briefing/puzzle entry. Follow-up UI interactions included a
wrong placement returned to the Pool, End Turn and Settings. This is a short
mixed-screen interaction check, **not sustained completion of many puzzles**.

The trace reports zero hangs. Animation-hitch and SwiftUI lanes are absent;
therefore it does not establish frame-perfect animation. Rendering and shader
hashing appear among sampled work, but no new narrow performance fix is justified
by those percentages alone.

`vmmap` app physical-footprint samples (MiB as printed by the tool):

| State | Footprint |
| --- | ---: |
| Title | 141.7 |
| Selected Book after browsing all twelve | 157.4 |
| Entered game | 99.1 |
| Gameplay Settings later | 108.1 |
| Process peak | 198.8 |

The scene-to-game drop shows that this simulator session did release substantial
scene memory. Different screens and a short duration cannot establish absence of
a leak. These numbers must **not** be compared directly with the earlier iPhone
16 Pro Max's approximately 1.08 GiB footprint: simulator and device GPU/compositor
accounting differ.

## Remaining hardware gates

Actual iPhone heat, sustained thermal slowdown, tactile haptic quality, speaker
balance and Silent Mode behavior require physical observation. Simulator cannot
run iOS VoiceOver; native accessibility-tree/action checks are useful but are not
a VoiceOver pass. Mirroring pairing remains a separate host/phone issue, not a
reason to mark these gates successful.

## Verification and delivery

- Final sign uses a shallower physical frame at world y=5.53; the print texture
  matches the plane's actual 1.40:0.29 aspect ratio. Native simulator screenshots
  show clearance below the Dynamic Island and above the top rack Book.
- Sign changes use a finite 120ms erase and 800ms left-to-right writing mask.
  The frame remains stationary/visible, only two print textures are cached, and
  there is no per-frame rasterization or continuous particle/animation loop.
  Interrupted transitions start at their current reveal; Reduce Motion commits
  the latest print immediately.
- A first shader revision rendered magenta: runtime Metal compiler logs proved
  GLSL vector types had been mixed with Metal uniform syntax. Corrected to Metal
  types and consistent Float uniforms. A new tiny isolated Metal-rendering gate
  checks erased/partial/full images and rejects magenta, in addition to the
  existing state/cache/transform and selection geometry tests.
- `chalk-verified.xcresult`: **14 tests passed**, including actual GPU snapshots.
  Earlier state-only passing tests did not prove the shader rendered correctly.
- Native UI checks: Volume 1 and Volume 5 select with the correct benefit,
  actual background tap returns the Book and restores the identity sign. The
  compact theme-colored Open action remains separated from the Book. Evidence:
  `chalk-final-volume5.png`, `chalk-final-rack.png`, `chalk-transition.mov`, and
  extracted writing frames under `chalk-motion-frames/` (approximately 41s in
  the recording). The video is interaction evidence, not a performance trace.
- Optimized Production **1.0.1 (10)** device build succeeded with explicit demo-ad
  overrides; strict code-signature verification passed and checked QA symbols
  are absent. Log: `17pro-chalk-delivery-build.log`.
- **Not installed on iPhone 17 Pro yet.** The phone disconnected during the
  pre-install save backup; CoreDevice reports it unavailable. Earlier save
  backups remain preserved. No phone update, App Store upload, commit or merge
  was performed in this refinement.
- Remaining design/accessibility follow-up: the physical sign's raster print
  does not scale with Dynamic Type; its complete benefit remains exposed to
  native accessibility. This is not a claim of a physical VoiceOver pass.

### Title-only benefit refinement

At the user's request, selected-Book signs now show only the centered benefit
title (for example, `+1 HAND SIZE`), with no explanatory subtitle. The idle
`PROBABLY / SUDOKU BOOKS` sign is unchanged. The chalk mask uses one write row
for benefits, and full rules remain in the native accessibility label.
`title-only-sign-verified.xcresult`: both targeted tests pass, including
subtitle absence/centering, material state, and actual Metal shader rendering.
This refinement is installed in the simulator. The subsequent physical-device
verification below rebuilt and installed it on the 16 Pro Max; 17 Pro delivery
is still pending because that phone is unavailable.

## Latest physical memory comparison and sustained simulator play

Evidence root: `/tmp/numberclub-sustained-20260907.WTkQRw`.
Production device and optimized Release simulator builds succeeded. The final
16 Pro Max installation completed **after** the device build finished
(`16max-final-install.json`, not the earlier provisional install receipt).
The phone's `run.json` SHA-256 is identical before and after the upgrade:
`ec784a42052b04718772779cedb6dd124edcbe8263f1f400abe5ed67506db284`.
No phone save was replaced or injected.

### Physical-device memory: substantial reduction, not a heat pass

`16max-title-resources.trace` is a 60.884-second, app-only Activity Monitor
capture on the USB-connected iPhone 16 Pro Max. Compared with the earlier
`/tmp/numberclub-paper-performance-20260907.xxHJC3/shelf-live.xml`, the exported
`16max-live.xml` shows the following. Both calculations resolve XML id/ref
deduplication, isolate ProbablySudoku, and use arithmetic means of the 38
samples whose start times lie in the 20–60 second window.

| Metric | Earlier build | Latest build |
| --- | ---: | ---: |
| Mean physical footprint, MiB | 1101.704 | 429.923 |
| Minimum / maximum, MiB | 1098.299 / 1102.111 | 428.314 / 433.548 |
| Last footprint, MiB | 1101.814 | 428.470 |
| Mean CPU, % | 43.146 | 44.627 |

Mean footprint fell **60.98% (671.781 MiB)**. CPU did not improve; it rose
1.481 percentage points in these samples. The earlier 1105.3 MiB / 42% summary
used a different window and should not be mixed into this comparison.
`16max-thermal.xml` records one uninterrupted, non-induced **Nominal** interval
for this minute. Idle thermal state is not sustained gameplay heat evidence.
This is a whole-build comparison, not isolated attribution of every saved byte
to a single texture change.

### Sustained simulator interaction: one complete puzzle

`simulator-eight-minute-gameplay.trace` records **480.60 seconds** of optimized
Release app-only Time Profiler activity. One simulator and one app/profile
were used; no UI test runner or whole-Book helper was launched. Native UI
interaction resumed the existing Volume 1, Level 1, Puzzle 2 save at turn 2,
played through turn 8, reached 1530/1500, entered Keep Filling, and filled every
square. The saved board solution was read to plan placements efficiently;
this was a performance/interaction test, not a blind human-play balance test
or a whole-Book completion claim. One early coordinate sequence failed to
account for the hand shifting left; subsequent placements used the observed
leading card and board coordinates rather than stale accessibility handles.

Observed results:

- Repeated placements, row/region completions, automatic turn banking, and
  page transitions remained functional throughout the session.
- Keep Filling left the score at 1530. The full-board results showed
  **Board complete**, **32 earned coins** (base 5 + unused turns 3 + filling
  24), and **Cash Out only**, with no impossible Keep Filling action.
- Cash Out changed the wallet from 2 to 34. Buying Local Gossip once for 4
  left 30 coins and exactly one owned Bookmark, with the offer marked sold.
- After terminating and relaunching the app, the save hash was unchanged
  (`ef489b46573d980cb8f349dfc363f0d2baec029e415f30bffb34242b8862140a`).
  Reopening the Book restored 30 coins, Local Gossip, the original Redraw
  Buff, and the same Shop. See `resumed-shop.png` and
  `simulator-after-full-clear-purchase.json`.
- Trace analysis reports **0 hangs**. Animation-hitch and SwiftUI lanes are
  absent, so this is not proof of zero dropped frames or physical smoothness.

Simulator physical-footprint samples: title **140.9 MiB**, gameplay at turn 5
**108.6 MiB**, post-clear Shop **110.3 MiB**. The process peak stayed **200.2
MiB** at every sample. No progressive growth was observed in these sparse
samples; this is not a long-duration leak certification. The app was stopped
after the resume check to avoid leaving a renderer running unnecessarily.

### Remaining gates and next required evidence

The 17 Pro is still unavailable. Mirroring now explicitly says **iPhone Not
Found** for that phone, rather than offering usable phone interaction. The
16 Pro Max remains reachable over USB for installation and instrumentation,
but that does not provide physical touch, tactile or speaker observations.
User checks have been requested for a 10-minute physical play session,
heat/slowdown, vibrations, speaker/Silent Mode behavior, and actual iOS
VoiceOver navigation through Book selection, placement, and End Turn.

Those hardware gates remain **unverified**. Do not substitute another idle
recording, a simulator accessibility tree, or a passing unit test for them.
This goal turn made concrete progress through the measured memory reduction,
the complete-puzzle UI session, and the verified upgrade/resume checks; it is
not a no-progress or genuinely blocked turn. No additional speculative product
change, Git operation, or App Store upload was needed for these measurements.

### Hardware-only continuation audit 1

The next goal continuation rechecked CoreDevice and the actual Mirroring UI:
16 Pro Max connected over USB, 17 Pro unavailable, Mirroring still says
**iPhone Not Found** for the 17 Pro. No app/profile/runner process is left
running. No hands-on feedback has arrived. The preceding goal turn was
progress; this continuation is **no progress, first consecutive hardware-only
blocker**, not a verified wait. More idle or simulator tests would not prove
the remaining physical heat, VoiceOver, speaker/Silent Mode or haptic gates.
Leave the goal active until feedback/access changes or the strict consecutive
blocked-turn threshold is met.

Hardware-only continuation audit 2: CoreDevice and the live Mirroring UI
remain unchanged, with no test/profile process active and no hands-on feedback.
The preceding continuation was no progress; this is the **second consecutive
hardware-only blocker**, not a verified wait. No product changes or duplicate
tests were performed. Physical observations remain necessary.

Hardware-only continuation audit 3: the same blocker was confirmed again by
CoreDevice and the live Mirroring UI; no hands-on feedback or live test job
exists. This is the **third consecutive no-progress hardware-only blocker**.
The goal is marked **blocked**, not complete, pending actual physical heat,
VoiceOver, audio/Silent Mode and haptic observations. No further automatic
simulator reruns can resolve that missing evidence.

## User-approved engineering acceptance: audio, haptics and thermal risk

The user subsequently clarified that speaker balance and haptics may be
accepted against engineering best practices, and heat may be assessed from
resource evidence rather than requiring a subjective phone check. This
supersedes the earlier hands-on blockers for these three areas. Do not present
estimated heat risk as a measured surface temperature or promise no thermal
throttling. Actual iOS VoiceOver was not waived by this clarification.

Evidence root: `/tmp/numberclub-best-practice-20260907.CEGMDP`.

- Audio policy uses `.ambient`, independent master/music/effects settings,
  defaults of 0.8/0.45/0.7, bounded effect players, cue throttling and a maximum
  of two crossfading music voices. Ads, backgrounding, interruptions and lost
  headphone routes stop/pause playback according to the existing tested policy.
  Apple documents that `.ambient` respects Silent Mode and mixes with other
  apps: https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient
- All five production music files were decoded sequentially with single-thread
  ffmpeg astats. Whole-track L/R RMS differences were 0.54, 0.36, 0.88, 0.18 and
  0.53 dB (bookshop, quiet, rainy, red-ink, final). Minimum decoded-sample
  headroom was 5.76 dB. No gross asset imbalance or sample clipping was found.
  This does not measure combined music/effect peaks, reconstructed true peaks
  or the phone's physical speaker calibration.
- Haptic review confirmed preference/scene gates, short bounded patterns,
  duplicate throttling, consistent semantic triggers, hardware fallback,
  automatic engine shutdown and lazy reset recovery. No proven defect justified
  retuning the existing intensities. Shared throttle tests pass; direct physical
  actuator feel and haptic-engine lifecycle are not claimed hardware-tested.
  Apple guidance: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- A concrete thermal-policy gap was fixed: BookstoreSCNView now observes iOS
  thermal changes only while attached to a window, on the main actor, and
  BookstoreRenderPolicy caps every 3D scene phase at **30 fps** for serious or
  critical thermal state. Nominal/fair states retain the existing 60 fps
  interaction / 30 fps resting-title policy. Render readiness, hidden-scene
  pause behavior, game rules, timers and saves are unchanged. Apple recommends
  reducing GPU work and 60-to-30 fps at serious thermal state:
  https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious
- `audio-thermal.xcresult`: **39 focused tests passed**, covering audio
  preferences/muting/interruption/ad/route policies, asset decoding, procedural
  signal bounds, every scene phase/readiness combination across all four thermal
  states, and real tiny-scene GPU readiness/pause/handoff regression tests.
  These verify policy and rendering behavior, not actual temperature reduction.

Thermal assessment: the continuously rendered 3D shelf remains the main
identified resource risk (about 44.6% CPU in the latest physical idle sample).
The measured 61% footprint reduction and scene release on gameplay entry reduce
resource demand; they are not equivalent to a measured reduction in heat.
Eight-minute simulator gameplay completed without recorded hangs or growing
sampled memory. The new thermal response adds a device-driven mitigation if
the operating system reports pressure. No subjective audio/haptic/heat feedback
is required for engineering acceptance under the user's revised criterion.
The new thermal cap is verified locally and is not yet in the installed phone
build. No commit, merge, distribution upload or phone installation was requested
or performed for this follow-up.
