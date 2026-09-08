# Seven-area release verification — 7 September 2026

Scope: the user's requested interruption recovery, updated device UI, crowded
layouts, Book/Boss interactions, performance, accessibility/audio, and final
distribution configuration. Fix confirmed defects only. Preserve all existing
work and saves; no commit, upload, public release or App Store submission is
part of this pass.

## Resource and data boundaries

- One app/test/profiling session at a time; two build jobs; no parallel UI-test
  drivers or whole-Book replay harness.
- Allowed physical devices only: iPhone 17 Pro and iPhone 16 Pro Max. The
  connected iPhone 16 Pro is excluded.
- Device backups/evidence: `/tmp/numberclub-release-gate-20260907.IIZFCf`.
- Production-configured device testing uses an explicit Google demo-ID build
  override. The live-ad candidate configuration is checked separately. Do not
  watch/click real inventory for test purposes.
- Simulator fixtures and hosted tests are not counted as human playthroughs or
  subjective physical haptic/speaker observations.

## Acceptance record

| Area | Required evidence | Status |
| --- | --- | --- |
| Interruption recovery | Exact Book, board, hand, inventory, currency and once-only rescue survive scoring/ad/Keep Filling/purchase relaunch | Tested states passed; precise mid-animation kill timing remains unverified |
| Updated device UI | In-place install and save preservation; real taps, dismissals, scroll and repeated input on both allowed phones; iPad layout evidence | Both installed; 17 Pro interaction and iPad evidence collected; 16 Pro Max mirroring failed |
| Crowded screens | Maximum Hand/inventory, large scores, long Boss text, overlapping trigger states, largest text size | Focused layout tests and representative rendered frames passed; not every combination manually exercised |
| Book/Boss interactions | Actual restriction/activation cues and input handling, countdown expiry and nearly full board | Focused automated/rendered coverage passed; exhaustive physical interaction pass incomplete |
| Performance | Diagnose prior 231 ms startup hang; bounded app-only startup/sustained capture with resource trend | Latest launch captured no hangs/hitches; footprint improved 6% but remains high; sustained gameplay/heat unverified |
| Accessibility/audio | Real VoiceOver navigation where available; Silent Mode/interruption behavior; distinguish signal evidence from subjective feel/balance | Policy/assets tests passed; actual VoiceOver and subjective hardware checks outstanding |
| Distribution | Optimized QA-free build, save compatibility, validated ad IDs and consent/failure paths | Production archive and in-place upgrades verified; real production consent still unverified; nothing uploaded |

## Baseline facts

The preceding panel pass passed 32 focused tests and visually verified compact
Buff/Shop details and phone/tablet result prints. One native Book (Volume 9) is
completed. The fast engine matrix covers 12 Books × 9 obstacles × 19 Bosses;
neither fact replaces this release gate's real touch/lifecycle checks.

The existing optimized startup trace is retained. Its parser export failed, so
no mixed simulator stack is treated as the cause of the physical 231 ms hang.
Fresh app-only physical evidence is required before changing startup code.

## Evidence collected in this pass

- Built optimized `Production` locally with explicit Google demo-ad metadata
  overrides, then installed in place on both permitted phones at approximately
  17:19. This is version 1.0.1 (10), not a new TestFlight upload. Relevant QA
  symbols are absent from the optimized executable.
- Backed up each app's Application Support and preferences first. After the
  upgrade, the 17 Pro's profile and the 16 Pro Max's run, profile and progress
  files matched their original SHA-256 hashes byte-for-byte. The 17 Pro had no
  local run initially; its existing remote Book 11 was resumed through the
  normal UI, without replacing it with a selected different Book.
- 17 Pro mirroring: tested Settings opening/closing, rapid Book selection,
  background dismissal and return to the correct rack pocket. Settings did not
  scroll through Mirroring; the user's earlier direct-phone swipe confirmation
  is retained, not substituted with an automated scrolling pass. Mirroring
  subsequently reported iPhone in Use and the device tunnel became unavailable.
- iPad simulator: opened the redesigned Fresh Ink slip, double-clicked Use,
  confirmed exactly one copy was spent, placed numbers and completed a row,
  banked the turn, terminated the app and reopened through Play → selected Book
  → Open the Book. Verified score 505, Turn 2, the completed row, seven-number
  Hand, three Bookmarks and remaining Peek. The stored run stayed byte-identical
  through relaunch. The kill occurred after banking; it is not evidence of an
  interruption at a precisely measured animation frame.
- Fresh 16 Pro Max, app-only 20-second SwiftUI trace: one 240.22 ms main-thread
  stall at 1.528 seconds, with AVAudioSession category setup waiting on a
  synchronous AVFAudio/XPC reply. No evidence links it to bookstore meshes or
  the engine. Analysis: `physical-startup-analysis.md` in the evidence directory.
  The narrow patch moves AVAudioSession negotiation onto one serial background
  queue, with activation-generation checks across background/ad/media resets.
  Post-fix device measurement is still required.
- Attempted 17 Pro sustained capture did not record useful data: first attach
  by app name failed, and attach by its observed PID then timed out waiting for
  the unavailable device. Neither attempt counts as sustained-play evidence.
- iPad real Google demo ad: launched the existing simulator exhaustion fixture,
  watched until the SDK displayed **Reward granted**, and terminated **before
  dismissing the ad**. `ipad-earned-ad-before-close.json` contains phase playing,
  Turn 11/13, rewardedRescueUsed true. The complete save was byte-identical after
  relaunch, and normal Book selection reopened the same board/Hand with the
  three earned turns. No real ad inventory was watched or clicked.
- iPad Shop: the existing direct-Shop fixture offered Sports Section for four
  coins. A rapid double-click bought one copy, changed coins 5 → 1, and marked
  one offer sold with the correct Shop-visit provenance. Termination/relaunch
  preserved the complete saved file (`ipad-after-purchase.json`).
- iPad Keep Filling: used the existing target-met fixture, entered Keep Filling
  with rapid double-click input, then terminated/relaunched. The complete save
  remained byte-identical: keepFilling, score 1000, Turn 1, coins 5, no early
  payout (`ipad-keep-filling.json`). These two last checks validate disk/relaunch
  preservation, not an additional manual playthrough after selecting the Book.
- Focused app-host gate: 169 tests in 132 seconds; 168 passed. The sole failure
  was an audio-policy fixture that set music to zero while expecting music to
  resume. Restored its audible fixture, and hardened the new asynchronous audio
  activation against stale callbacks, media resets, and effects-to-music-only
  mix changes. Final audio/ad rerun: **62 tests passed**, including 19 GameAudio
  tests. Result bundles: `focused-release.xcresult` and `audio-final.xcresult`.
  No parallel native test driver was used.
- Crowded-board geometry passed for the supported phone widths, all stage/Boss
  variants, nine-card capacity, nine-digit scores, queued multipliers and the
  largest Dynamic Type category. Inspected exported high-score frames for 402pt
  and 440pt phones. Boss cue, sleeping Bookmark, hidden Marker, timer lifecycle,
  compact slip, Settings and consent/error cases are automated/rendered proof;
  they are not a manual touch pass of every combination.

## Final device and performance evidence

- Reconnected 17 Pro Mirroring and continued the existing **Book 11 / Second
  Thoughts**, obstacle I, through normal selection. Double-clicking the selected
  number's empty square placed it once and consumed one card. End Turn banked
  ten points. Force-terminated the app, relaunched, then installed the final
  update in place. `17pro-banked-kill.json` and
  `17pro-final-upgraded-run.json` are byte-identical: Book secondThoughts,
  obstacle 1, Level 1, slot 0, coins 5, score 10, Turn 2, Hand [4,1,1,5,3,2],
  and the placed 1 in the first cell. This deliberately advanced one real turn;
  no reset or replacement save was injected on a phone.
- Installed the final optimized audio/render build on **both** allowed phones.
  Successful final install records: `17pro-final-pool-install.json` and
  `16max-final-pool-install.json`. Physical test builds still use Google demo
  IDs; no live ad impression or click was used as a test.
- Attempted switching Mirroring to Daniel's iPhone (16 Pro Max). macOS reported
  **Unable to Connect to iPhone**, so there is no 16 Pro Max touch/scroll pass.
  USB installation and profiling success do not imply UI automation access.
  Desktop & Dock subsequently showed **Pairing in progress** with the device
  selector disabled, preventing restoration of the previous 17 Pro target.
  Requested a direct-phone pairing check; no access revocation, service reset,
  preference-file override or contact with the excluded 16 Pro was attempted.
- The intermediate 320.44 ms trace was subsequently symbolicated using the
  matching dSYM and exported successfully. Its main-thread stack implicated
  effect-pool preparation and initial music setup; separate first-scene work
  included synchronous SceneKit texture conversion. The older analysis file's
  export limitation is superseded by this successful symbolicated export.
- Moved the fixed-size effect pool's WAV generation and AVAudioPlayer
  preparation onto the serial audio queue. Finished players are published on
  MainActor only after a generation check; backgrounding, ad presentation and
  media reset invalidate stale work. No per-tap player allocation was added.
- Final 16 Pro Max startup capture, `16promax-startup-final.trace`: one
  **100.59 ms** main-thread unresponsiveness event (initial music file/player
  setup), plus a separate **616.72 ms display hitch** during scene construction.
  This is an improvement over the 240.22 ms initial / 320.44 ms intermediate
  audio events, **not a zero-hitch startup result**. Music initialization and
  first-scene preparation remain performance follow-ups.
- Introduced a narrow rendering policy: the settled, idle bookstore title
  renders at 30 fps; first-frame preparation, transition/readiness phases and
  interactive rack animation remain at 60 fps. Hidden scenes still stop.
  Continuous SceneKit rendering was retained to avoid the known black-aisle
  and stepped-camera regressions from on-demand rendering.
- Same-device 60-second idle captures: mean CPU fell **63.50% → 42.02%**
  (about 34% relative reduction); late-window averages were 65.02% → 43.23%.
  Physical footprint remained around **1.15 GiB**, with peaks around 1.25 GiB.
  No continuing growth appeared in these short idle samples, but the footprint
  is still high and these are **not** sustained-gameplay, leak, thermal or heat
  acceptance evidence. Traces: `16promax-idle-resources.trace` and
  `16promax-idle-throttled.trace`.
- The render/readiness/rack/audio rerun passed **38 tests**, including real GPU
  first-frame checks (`render-policy.xcresult`). Counts across reruns overlap;
  they must not be presented as one unique test total. The last backend-only
  effect preparation move was compiled into the final builds and measured on
  device; it did not alter the already-regated GameAudio policy.

## Final distribution artifact

- Built `ProbablySudoku-Production.xcarchive`, version **1.0.1 (10)**, using
  the unmodified live-ad Production configuration, supporting iPhone and iPad.
  `production-archive.log` reports ARCHIVE SUCCEEDED. This is a local archive,
  not a newly numbered build or an App Store/TestFlight upload.
- Verified the signed archive with `codesign --verify --deep --strict`.
  Relevant QA panel/helper symbols were absent. App, Google Mobile Ads and UMP
  privacy manifests are present. Metadata declares `NumberClubAdMode=live`
  and the project's production app/rewarded-unit IDs.
- Signing/archive checks do not replace an App Store export validation,
  production-region consent check, App Privacy declaration review or Apple's
  review. Existing Apple submissions and remote Git branches were untouched.

## Follow-up: shared paper UI and startup (same day)

Evidence directory: `/tmp/numberclub-paper-performance-20260907.xxHJC3`.
The entries below supersede earlier measurements where explicitly stated.

- Unified the benefit label, unfinished/conflicting Book decisions, Buff/Marker
  details, native Shop inspection and Settings around shared paper surfaces.
  Benefits use a 72pt reference label (112pt with obstacle), smaller illustration,
  no repeated number badge and the physical Book width. Larger text earns height
  and can scroll above the Open action. Documented reuse in `docs/PAPER_UI.md`.
- Shared buttons wrap Dynamic Type content and retain a 52pt minimum touch area.
  The unfinished-Book slip uses one primary Continue action, explicit destructive
  replacement wording and one close action. Mandatory Marker placement cannot
  be dismissed through the shared accessibility escape action.
- Moved initial music-file/player preparation off the main thread onto the
  existing serial audio queue. Generation guards prevent stale publication
  after backgrounding, ad display or media resets. Prepared players for an
  obsolete cue are released. Music remains capped to the existing crossfade pair.
- Shelf cover raster scale changed from 2x to 1.5x for its 12 small static covers;
  the selected live Book stays native SwiftUI. No added per-frame image creation.
- Fresh **16 Pro Max** app-only 20.84-second SwiftUI capture
  (`startup-music-raster.trace`) recorded **zero potential hangs and zero display
  hitches**. This supersedes the preceding 100.59ms/616.72ms startup observations
  for this launch, not for every possible launch or sustained gameplay.
- Fresh 60-second title-idle capture (`shelf-resources-raster-valid.trace`):
  late footprint averaged **1,105.3 MiB** versus **1,176.8 MiB** previously,
  approximately **71.5 MiB / 6.1% lower**. CPU averaged **42.00%** versus **42.02%**.
  Peak decreased from about 1.25GiB to 1.16GiB. The footprint remains high.
  This idle capture does not certify sustained play, heat or absence of leaks.
  A preceding trace with a mistyped bundle identifier failed to launch and is
  explicitly excluded from the measurements.
- Source audit found no obvious coordinator retention cycle or title-time
  Meshy/Shop asset load. The Book scene branch is removed during gameplay; its
  coordinator's view reference is weak. Remaining memory attribution requires
  runtime evidence, not a speculative cache or navigation rewrite.
- Live iPad simulator check: the smaller benefit sits flush with the physical
  Book width, with no badge; selected obstacle labels and full benefit copy are
  in the accessibility tree. A deduced nine at row8/column1 accepted rapid double
  input once and consumed one card in the existing Keep Filling fixture. This is
  a focused interaction check, not a new Book completion or sustained-play run.
- The first 63-test gate exposed a genuinely clipped iPad Marker footer. Reduced
  only its tablet grid cap from 400pt to 360pt to preserve the footer. Other initial
  failures were verified OCR column/glyph artifacts and an overly tight new
  large-text button-height expectation; complete-copy assertions were retained.
- macOS still displays **iPhone Pairing in progress** with no selectable target.
  The 16 Pro Max remains USB-installable/profileable, but native Mirroring access
  is not restored. No security-setting reset or phone data replacement was used.
- A new actual-view Settings regression initially found no visible native scroll
  container, but also reproduced that failure with an explicit ScrollView. It
  was inspecting visibility before the arrival fade finished. Corrected its
  settling interval and removed the speculative product workaround; this
  initial result is not valid evidence of a Settings scrolling defect.
  The corrected native-scroll checks passed for both Settings variants on phone
  and iPad, with positive scroll range and visible lower actions/Close. The
  simulator gesture-injection observation remains separate.
- At the largest accessibility text size, the benefit obstacle label now stacks
  above its full-width rule and the illustration is capped at 48pt. This removes
  the excessively narrow paragraph column without shrinking essential text.
- Final focused results: the 61-test combined gate passed 59, with the two final
  failures addressed/rechecked separately. All 3 benefit-label tests then passed,
  and all 6 Settings tests passed after proper arrival settling. Thus all 61
  focused cases have passing final evidence across these reruns (not 61 new
  independent tests per run). Earlier 9 theme and 5 crowded-board geometry checks
  also passed. Result bundles: `paper-ui-final-rerun.xcresult`,
  `settings-plaque-fixed.xcresult`, and `settings-native-scroll.xcresult`.
- Built the final optimized Production-configured demo-ad update and installed
  it on the 17 Pro and 16 Pro Max at 19:40. Both `run.json` files remained byte-identical
  before/after installation (SHA-256 comparison). Verified its signature and
  absence of QA panel/driver symbols. This remains local version 1.0.1 (10), with
  demo IDs for safe testing; it is not a new live-ad archive or Apple upload.
- Shut down the dedicated iPad test simulator after the gate. No parallel
  UI-driver or whole-Book replay harness ran during this follow-up.
- One final 30-second Game Memory capture (`final-memory-attribution.trace`)
  identifies substantial Metal render surfaces: a 1,320×2,868 RGBA16Float resource
  at 41.20 MiB, a display drawable at 14.84 MiB, a 3,024×800 texture at 13.86 MiB,
  and a cover-sized 864×1,041 texture at 5.34 MiB. The trace does not reliably map
  anonymous resources back to source symbols or fully explain the idle footprint.
  Do not call this proof of a leak or claim the high-memory gate is resolved.

## Remaining gates — do not mark release-ready

1. Repeat the clean startup under more conditions and attribute/reduce the
   remaining approximately 1.08 GiB idle footprint. The latest single launch is
   clean; the earlier startup hitches are not counted as still reproduced.
2. Capture sustained interactive gameplay and its memory/thermal trend; the
   current one-minute idle comparison is insufficient.
3. Complete 16 Pro Max touch/scroll/dismissal checks when its mirroring or
   direct-device access works. Settings scrolling through 17 Pro Mirroring is
   still not evidence of direct-phone scrolling; the user's earlier successful
   physical swipe report is explicitly separate.
4. Actual VoiceOver navigation, perceived haptics, speaker balance, hardware
   Silent Mode and real call/audio interruption need direct-device verification.
   Automated accessibility/audio policy checks are not a substitute.
5. Verify the app-specific production consent flow on-device without generating
   invalid ad traffic. The real SDK demo reward flow and consent/failure unit
   cases passed; live production consent/fill is not asserted.
6. Precisely timed interruption during scoring, and remaining manual Boss
   restriction/near-full-board combinations, are not fully covered by this
   pass's after-bank kills and rendered/rules tests.
