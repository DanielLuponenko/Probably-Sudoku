# Living-paper polish verification — 7 September 2026

This follows the earlier route work in `next-puzzle-presentation.md`. No phones,
App Store submissions, Git commits or remote branches were changed in this pass.

## Confirmed issues and fixes

- **Skip layout jump:** inserting a receipt squeezed the flexible route grids;
  the Boss decision also introduced a second, large Boss board. Route, living
  scene and decision now have stable page-derived slots. The receipt and Play
  action have permanent footer space. The Boss rule replaces the coupon in its
  slot; only one Boss board remains. Short-page spacing was checked against the
  actual rendered coupon edge, not only text recognition. Oversized content can
  scroll without changing the Book/HUD bounds.
- **Unnoticeable background animation:** replaced tiny repeated suns with twelve
  authored paper scenes and asymmetric edge stationery. Scenes use cover ink and
  have multiple objects and a visible action, not a recolored central symbol.
  Successful-result scenes are 88pt high. Clocks remain local, monotonic and
  paused under covered/inactive/Reduced Motion/Low Power conditions.
- **Score banner:** removed the receipt from the handwriting band above the Hand.
  Source and value now occupy the scoreboard's existing queue line. Board,
  Hand, score and target geometry are unchanged; Bookmark/grid reactions remain.
- **Shop touch area:** the complete paper face, including artwork, text, blank
  space and decorative border, is inside the inspection Button's content shape.
  Decorations do not intercept taps. The separate Buy action remains guarded.
- **Grainy page sound:** replaced the high-frequency noise-heavy page cue with
  lower sheet-flex, restrained crease and landing components. Energy above 3kHz
  fell from 55.38% to 2.79%; peak sample jump from 0.502 to 0.119. The other nine
  effect waveforms remain byte-identical. This is signal/test evidence, not a
  claim about subjective sound quality on every iPhone speaker.
- **Boss rule defects:** Shredder and both Gray Bosses now leave at least one
  mechanically unbarred blank at a new turn, instead of indefinitely locking the
  final square. Executive Editor sleeps only triggered Bookmarks; passive
  upgrades remain awake and the copy says so. Mirror now has an actual last-cell
  Full Clear regression with simultaneous zeroed line bonuses. See the full
  nineteen-row rule/animation matrix in `boss-verification-matrix.md`.

## Twelve living scenes

| Book (saved ID) | Paper action |
| --- | --- |
| `probably` | Seventh card deals from a Book into a fan |
| `slightlyHarder` | Coin rolls from a receipt toward a savings saucer |
| `noPressure` | Desk lamp follows a pencil working a clue |
| `bites` | Paper clock ticks beside a bitten ticket |
| `genuinely` | Number cards toss around a lucky clover |
| `snackBreak` | Tea steams beside a small completed grid |
| `trustMe` | Eraser follows a wandering pencil scribble |
| `overthinking` | Pencil revises overlapping drafts |
| `smallVictories` | A completed row rises between laurels on a paper podium |
| `rainyDay` | Umbrella shelters a Book and its savings |
| `secondThoughts` | A crossed-out draft gives way to a fresh sheet |
| `wellEarned` | Biscuit tips toward tea; crumbs settle |

## Actual checks

- Full Engine: **251 tests, zero failures**, 120.556s. Includes the 2,052
  Book/Boss/Obstacle combination matrix and eleven new Boss restriction/action
  regressions. The new deadlock tests failed against the original rules before
  the guard was added.
- Full app: **472 tests, zero failures**, `/tmp/numberclub-living-paper-full-app.xcresult`.
- Final Boss-copy/compact-rule gate: **29 tests, zero failures**,
  `/tmp/numberclub-final-boss-copy.xcresult`. Includes the newly added longest-rule
  compact briefing test. This focused count overlaps the full-suite count.
- Optimized Release simulator build succeeded in
  `/tmp/numberclub-living-release.acYn92`. The final two shorthand-copy changes
  were subsequently compiled/tested in the Debug focused gate; they do not
  change the profiled render structure or gameplay.
- Native Shop touch check on the phone simulator: artwork, description, blank
  lower corner, Marker accent edge, wide Buff whitespace and Sold stamp all
  opened the corresponding details. Balance stayed at 5 while inspecting;
  buying Insurance spent exactly 3, left 2 and disabled a second purchase.
- Native Release tablet flow: opened Volume 5 normally, accepted both real
  Circulation offers, reached The Deadline and flipped into its actual puzzle.
  Video/contact-sheet review showed route and Play stayed fixed through both
  skips. The clipping swung from its pinned corner and fell out of its slot.
- 45.58s optimized Time Profiler capture of the living scene and both skips:
  **zero hangs**, 6,809ms sampled CPU. No Animation Hitches or SwiftUI cause-graph
  lane was available; this is not a frame-rate guarantee or physical-device proof.

## Local evidence

- Raw tablet recording: `/tmp/numberclub-living-paper-ipad.mp4`.
- Cropped, real-time eight-second skip/scene excerpt:
  `/tmp/numberclub-living-page-demo.mp4` (no added animation or artificial frames).
- Full-size phone before/after renders: `/tmp/numberclub-final-route-frames/`.
- Twelve-scene contact sheet: exported by `BookLivingSceneTests`.
- Trace: `/tmp/numberclub-living-paper-optimized.trace`; report:
  `/tmp/numberclub-living-paper-optimized-analysis.md`.
- Page sound preview: `/tmp/numberclub-page-sound-new.ouQ1Wt/paperTurn.wav`.

## Limits

All nineteen Boss rule paths and animations were audited and have automated
coverage; nineteen full manual Book playthroughs were not performed. The Bosses
use distinct procedural paper/ink signatures and real rule-state feedback, not
nineteen separate 3D cutscenes. Near-full safeguards leave a square mechanically
available; they do not promise the current Hand contains its correct digit.
Physical-device touch latency, frame pacing and speaker sound were not measured.
An extra live scoring capture was prevented by the native automation's tablet
window-position error; source/value rendering and score lifecycle are covered
by the passing app tests. The unused static capture is not scoring evidence.

## Final route acceptance and button-ink correction

The final read-only audit confirmed every Book theme and all nineteen Boss
signature mappings are connected. Route difficulty increases through fewer
givens and higher targets; Medium does not promise a harder solving technique
than Easy for every individual seed. New Tik Tak encounters receive 240 seconds;
stored three-minute encounters keep their actual remaining time.

The audit found two remaining presentation gaps, fixed without changing layout
or gameplay: Shop Reroll now uses the selected Book's ink/border, and small
button subtitles no longer fade below readable contrast. The shared Book ink
is checked against the warmer quiet-button stock, not only the lighter primary
label. Two new tests cover the actual warm/dark backgrounds and 96 real button
renders across twelve Books, checking subtitle glyph opacity as well as color.

After these final changes, the focused app gate passed **41 tests, zero failures**:
`/tmp/numberclub-theme-final-check.xcresult`. It covers Book themes, Shop card
geometry, route/claim behavior, phone/tablet briefing bounds and Tik Tak saves.
A fresh route/production-rule Engine gate also passed **8 tests, zero failures**.
These counts overlap the earlier full suites; no new full-suite total is claimed.
No commit, physical-device install or Apple upload was performed.

## Physical frontend pass — 7 September 2026

Production-configured 1.0.1 (10), development-signed with Google test ads, was
installed only on the iPhone 17 Pro and iPhone 16 Pro Max. Direct Mirror on the
17 Pro confirmed Guide vertical scrolling moved the real board, Next navigated
to 2/9 and reset article offset, and Close returned to Settings. Rack flick
rotation settled; Volume 5 middle-cover extraction kept its banner stable, and
background-tap reverse returned to the same pocket. Settings scrolling worked
physically; Mirror's no-effect result is a tooling limitation, not a product
bug. Haptic feel remains unverified.

The standalone 90-second scrolling probe failed initialization on both devices
(17 Pro authentication error 12; 16 Pro Max automation-mode timeout), so no
test method ran and no pass is claimed. Both startup comparisons were recorded
on the **16 Pro Max**: its previously installed build measured 580.54 ms for
BookstoreSceneView creation; the current source before this fix measured
590.86 ms. (The 17 Pro's previously installed version was 1.0 (7), but those
startup numbers are not from that phone.) The lazy bookstore
regression suite passed 12/12:
`/tmp/numberclub-lazy-bookstore-regression-20260907.xcresult`. No App Store
submission or commit was made in this pass.

### Measured optimization and remaining limits

- Existing shop construction is now deferred until its first shop phase, with
  one-time installation and cached state reapplied. No retired shop UI was
  restored, and the normal bookstore/rack appearance was retained.
- The optimized Production-configured build was installed in place on both
  allowed phones. The 20-second 16 Pro Max capture at
  `/tmp/numberclub-16promax-optimized-startup-20260907.trace` reduced the largest
  startup SwiftUI update to **482.46 ms**, versus **590.86 ms** immediately
  before the fix (18.3%). Instruments still reports **one 231.06 ms startup
  hang**. Startup is improved, not certified hitch-free.
- Direct Mirror on the optimized 17 Pro also checked bottom-shelf Volume 9
  extraction, its +15 Clear Score banner, and reverse return to the same pocket.
  A bounded 40-second app-only trace was recorded during rack interaction:
  `/tmp/numberclub-17pro-rack-interaction-20260907.trace`. Its largest recorded
  SwiftUI update was **849.75 microseconds**. Hangs/Hitches show “No Graphs” on
  this iOS 27 beta trace; that is not treated as proof of zero dropped frames.
- Physical Settings scrolling is user-confirmed; subjective haptic feel and
  comprehensive physical frame pacing remain unverified. No further UI-driver
  repairs were attempted after the two initialization failures. No save reset,
  app uninstall, new full Book completion, or App Store submission occurred.

## Focused simulator gameplay UI pass — 2026-09-07

Used the isolated iPhone 17 Pro simulator `Book UI Regression Gate`
(`9C12E469-F20B-4728-9887-72F94459B081`), with one app/test process at a time,
two build jobs, and parallel testing disabled. No UI-driver runner, physical
phone installation, App Store change, or additional full Book completion.
Its pre-pass Documents and Preferences were copied to
`/tmp/numberclub-gameplay-ui-save.BWKmcr`; the unrelated user simulator was untouched.

### Confirmed issues fixed

- A short Fresh Ink decision occupied a nearly full-height sheet, with a large
  empty gap between Use and Keep it. Buff slips now fit their content; longer
  content retains a scrolling fallback and the close decision stays outside it.
  The height constraint is outside the paper background so unused space is not
  painted as a full page. Verified the actual revised popup and Use dismissal.
- Paper Crane's nine unique hand choices previously shared a single row,
  compressing their touch targets. They now wrap into adaptive columns with a
  44-point minimum width and 46-point height. Rendered all nine at 375×667.
- A late Clue action could still reach the model after a puzzle became won,
  failed, or cashed out. It now shares the playing/Keep Filling input guard;
  regression coverage checks that game state, selection and error text stay unchanged.

### Observed interaction and visual coverage

- Real hand taps and two legal placements completed the first row: 175 queued
  points, then Morning Edition's separate +100, then 275 banked on End Turn.
  The 9×9 board stayed at the same screen bounds before/after placement and
  hand refill. Recorded `/tmp/numberclub-gameplay-ui-scoring-20260907.mov` and
  inspected full-screen and scoring-detail contact sheets.
- Tik Tak's live timer, boss instructions, board, hand and footer fit together;
  opening/closing Settings retained the layout. Clock pause/resume/save behavior
  is covered separately by the focused clock tests, not inferred from screenshots.
- Opened the full Redraw description from its shortened Shop card and bought
  it: balance changed from 5 to 2, one Buff appeared, and the offer became sold.
- Entered Keep Filling from the won-results page and confirmed the full-sized
  playable grid returned. The results page still has generous empty vertical
  space; this is a visual-polish observation, not a blocked control.
- Exhausted a fixture through normal End Turn actions; checked the optional
  rescue and separate End Book controls. End Book showed the terminal page;
  New Book completed the return to the opening menu. No ad was watched.
- Inspected rendered high-score evidence for the reported 122,541 / 128,000
  case, +495 × 39.75 queued, +6 coins at 300-point content width: no overlap.
  Also inspected the full Marker placement grid and footer on compact phone.

The final focused result bundle is
`/tmp/numberclub-gameplay-ui-verified-20260907.xcresult`: **49 tests passed,
zero failures**, 35.5 seconds of test execution. It includes Buff presentation,
Settings presentation, Tik Tak clocks, selection/terminal input, high-score
rendering, hand-capacity board stability, and failure-page rendering.
Earlier iterations
retain their evidence: numeral OCR misread visible choices, so the nine-choice
test now checks rendered label ink in each expected two-row cell instead.
These checks do not establish physical-device frame pacing or subjective haptic
quality, and do not increase the normal-play Book completion count.

## Paper-panel design pass — 2026-09-07

The reported Fresh Ink screen was the consumable Buff confirmation. Its short
copy was being treated as a long page, separating Use and Keep it with a large
empty region. This pass extends the earlier geometry fix into the existing
paper-and-ink visual language rather than introducing another UI theme.

- All Buff confirmations now include their existing item illustration, the
  canonical effect, rarity imprint and a small tear rule. Both decisions remain
  together. Paper Crane keeps its wrapping, minimum-44-point number choices;
  consuming a Buff still preserves its outgoing identity during dismissal.
- Content-fitting is now the shared PaperSlip default, including Settings,
  Help, privacy and Run Information. Long articles use a capped ScrollView;
  Close and guide navigation remain outside the article.
- Successful puzzle results show the actual read-only played board on phones
  as well as tablets, a Target Met / Full Clear imprint and a compact payout
  receipt. Fixed, modest spacing replaces flexible empty gaps. No new idle
  animation or texture asset was added; the previous results interlude loop
  was removed. Keep Filling, Cash Out, final-Book and failure routing are unchanged.
- The live native Shop sheet exposed an additional defect that inline renders
  did not: fitted NavigationStack sizing left a tall sheet with dark empty
  bands. Its detent now follows measured article height plus its toolbar;
  long copy scrolls on paper while Close remains in the toolbar.

Visual evidence includes the revised live Fresh Ink panel at
`/tmp/numberclub-fresh-ink-designed-live-20260907.png` and rendered phone/iPad
results in `/tmp/numberclub-paper-design-attachments-20260907`.
Fresh Ink was also inspected at the largest iOS accessibility text size; its
effect wrapped without clipping and both decisions remained visible. The
simulator text-size preference was restored to its original `large` value.

Only the isolated Book UI Regression Gate simulator was used. This pass does
not install a build on physical phones, change App Store submissions, or prove
physical haptic quality/frame pacing. Native CUA swipes did not move Settings
or Help in this session; this is recorded separately from rendered-content and
hosted UIKit scroll checks, not counted as a successful gesture check.

Final validation: `/tmp/numberclub-paper-design-final-20260907.xcresult`
contains **32 passing tests, zero failures**, 33.5 seconds of test execution.
The added long-article test finds the real enabled UIScrollView, checks its
content exceeds its viewport, scrolls to the end and verifies the final paragraph
and Close in the rendered image. The native Shop-sheet test presents a real
402×874 sheet and verifies height below 500 points plus complete purchase copy.
Afterward the live simulator confirmed the compact sheet, then bought Redraw:
5 coins became 2, exactly one Buff appeared and the offer became sold.
Live purchase-sheet evidence:
`/tmp/numberclub-offer-designed-live-20260907.png`.
The inspected phone/tablet result prints remain read-only and regression tests
cover their unchanged Keep Filling / Cash Out availability and persisted state.
