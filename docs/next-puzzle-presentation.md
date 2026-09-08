# Living Book route

The Next Puzzle page uses **Easy → Easy but hard → Boss** above three square
boards. The active ordinary board is dark with a gold underline. Boss identity
and the real power appear below its ink-stained board. Bookmarks remain tucked
behind the physical page; this change does not replace the page-curl renderer.

## Gameplay and persistence

- Route illustrations use legal Sudoku subsets and the selected Book's actual
  clue counts. They do not reveal or regenerate a future deal. The engine
  retains its existing seeded generation, progressively fewer clues, increasing
  targets, and Boss-specific rules.
- Tik Tak starts new encounters with 240 seconds. A resumed encounter preserves
  its stored remaining budget, including saves from the previous 180-second rule.
- Tapping anywhere on a coupon runs an 800 ms pinned-corner swing and gravity
  fall. Only after that presentation is finished does the engine apply its
  existing atomic skip/reward action.
- A claim belongs to one model instance and one game revision. Repeated claims,
  stale offers, or claims passed to another Book session are rejected.
- Backgrounding, opening a slip, leaving the page, or another page flip cancels
  an uncommitted coupon. Request-scoped cleanup restores controls without
  cancelling a newer tap. Reduced Motion uses a short fade instead.

## Color and motion

The existing twelve Book cover colors are the source of all in-run primary
button hues. Filled button ink is darkened within that hue to retain at least
4.5:1 contrast with its cream label. Quiet controls retain their paper fill and
use Book-colored ink. Destructive, disabled, rarity and Marker colors retain
their semantic meaning.

Each Book has its own pencil motif in the margins of briefing, Shop and results
pages, plus a visible illustrated interlude between the route and coupon and on
successful results. The twelve benefit illustrations use different shapes and
moving parts, not the same icon recolored twelve times. Selection labels use
the same Book ink as the run's controls and a small perforated comparison ticket.
Every Boss has a distinct fixed ink seal and rule-linked animated perimeter signature,
shared between its route artwork and gameplay. Number glyphs, grid geometry,
hidden Marker data and touch targets are not animated or modified by these
decorative effects. Existing restriction outlines still follow actual state.

Ambient updates stay inside their own Canvas/TimelineView, never in GameModel
or a per-frame environment value. They stop for covered pages, inactive scenes,
Reduced Motion and Low Power Mode.

Settings now has three independent audio sliders, a short accessibility section,
and compact links to help, practice, Achievements, and privacy/support. The
Achievements collection stays available offline and returns to Settings without
unpausing a covered puzzle. Book details are collapsed; abandoning requires a
separate confirmation. QA remains restricted to Debug simulator builds.

Background motion also gates the bookstore's scenery and the post-completion
picker. Turning it off does not cancel a player-driven rack flick or extraction.
Shop item sheets pause the underlying marginalia until their actual dismissal.

## Audio

Four new original Suno tracks join the existing Bookshop track: two contrasting
Book moods, a regular Boss suite, and a final Boss suite. Books intentionally
share these five cues; this is not twelve separately composed soundtracks.
Music selection observes only presentation state and never advances the RNG.
Crossfades are bounded to two players, including rapid changes, and both voices
stop for backgrounding, mute, ads, interruptions, and disconnected headphones.

The ten short procedural effects use dry wood, paper and mallet-like transients
instead of hollow sustained sine tones. They have silence-safe edges, limited
peaks and no external sound-effects licence dependency. Track provenance and
commercial-use evidence are recorded in `AUDIO_ASSETS.md`.

## Additional rule audit

- Obstacle/Handy Dandy restrictions retain one mechanically playable card when
  a fresh hand would otherwise be entirely barred. Legacy repair is limited to
  untouched opening hands; resuming a spent hand cannot grant another move.
- Selling before a sleeping Bookmark rebases its index rather than putting the
  wrong Bookmark to sleep.
- Valid coin debt produces zero interest, never an extra negative-interest fee.
- The app-level matrix checks all twelve independent obstacle ladders, twelve
  final receipts and 108 Book/Obstacle ad-rescue saves with actual inventory.
- The engine matrix checks 2,052 Book/Boss/Obstacle combinations, plus real Boss
  deals and targeted regression cases. This is broad coverage, not a claim to
  exhaust every possible inventory permutation.

## Performance evidence

A 20.59-second Debug iPad-simulator trace of animated Boss briefing had no hangs.
A separate 35.59-second first-puzzle transition trace found one 440 ms microhang:
53 of 194 sampled main-thread stacks were in run saving, 8 in profile saving,
112 in first-view SwiftUI metadata/rendering, and 21 elsewhere. These traces did
not contain Animation Hitches or SwiftUI cause-graph lanes, so they do not prove
a frame-rate target or physical-device smoothness.

Puzzle preparation now performs discard-only encoding on its existing detached
worker, warming the confirmed cold Codable path. It does not save a future deal,
change the live Book or delay the accepted commit's synchronous durable save.
The warm-up alone is not evidence that the whole microhang disappeared.

A subsequent 40.58-second optimized Release iPad-simulator trace recorded zero
hangs while taking both clippings and opening the first Boss puzzle through the
normal Book rack flow. This is a different build configuration and seed, not a
controlled before/after benchmark. Its Animation Hitches lane was also absent;
it supports responsiveness in that session, not a guaranteed frame rate or
physical-device smoothness. Trace: `/tmp/numberclub-release-route-polish.trace`.

## Regression coverage

- `RouteDifficultyTests`: every Book/level, increasing route pressure, legal
  unique generated puzzles, saved-state compatibility.
- `RoutePresentationTests`: names, square geometry, legal clue illustrations,
  exactly-once and cross-session coupon protection, cancellation and fall poses.
- `BriefingBoundsTests`: phone/tablet bounds, known Boss metadata, readable offers.
- `BookPresentationThemeTests`: twelve distinct motifs/hues, contrast, motion
  gates and a fully transparent center.
- `BossBoardVisualTests`: nineteen signatures, static accessible previews,
  safe number regions and no hidden-state leakage.
- Existing Tik Tak clock, puzzle preparation, page flip, result rendering and
  rescued-run persistence tests remain part of the integration gate.

Initial route gate, September 6, 2026: 232 Engine tests and 109 focused app tests passed;
Debug test build and Release simulator build passed. Phone/tablet pages were
inspected. On the phone simulator, double-tapping used only one skip, opening
Settings during the swing cancelled without consuming a skip, and Play opened
the prepared puzzle after the coupon completed. The coupon motion was recorded
and inspected frame by frame. Physical-device installs and Apple submissions
were not changed by this implementation.

Final-polish live Release check: entered through the title and rack, opened
Probably, claimed Circulation and Coupon, and opened The Editor. After a full
app termination/relaunch and reopening that Book, the app restored the same
13 coins, Boss, zero score / 2,000 target, hand (9, 1, 2, 1, 7, 4), four Tosses
and Turn 1/10. Release Settings showed no QA section. Native audio sliders
render correctly; their mix/state policies are covered by unit tests. CUA's
slider dragging did not produce a reliable input result, so this session does
not claim a physical touch or speaker-balance check.

Final validation, September 6, 2026:

- Engine: 240 tests passed, zero failures.
- App: 459 tests passed, zero failures or skips, including all Boss-label
  renders at 280, 300, 327 and 365 points. The OCR test excludes the decorative
  seal region, while checking all rule text and the entire rendered ink bounds.
- Optimized Release simulator build and unsigned Production iOS build passed.
- `git diff --check` passed. No commit, device install, or upload performed.
- Final app result bundle: `/tmp/numberclub-production-polish-verified.xcresult`.
- Final phone route still: `/tmp/numberclub-final-route-phone.png`.
- Final coupon/marginalia clip: `/tmp/numberclub-coupon-preview.mp4`.
  A ten-frame-per-second contact sheet confirms the corner swing, release,
  downward fall and single replacement offer; this is visual inspection, not
  an animation-performance measurement.

## Current-tree recheck — September 7, 2026

The focused route gate passed **54 app tests, zero failures or skips**:
`/tmp/numberclub-living-route-final-check-20260907.xcresult`. It covers route
labels and square geometry, exactly-once coupon claims, all twelve Book hues
and animated compositions, phone/iPad briefing bounds, and the four-minute
Tik Tak clock including interruption and save/resume. The separate Engine
`swift test --filter RouteDifficultyTests` gate passed **2 tests**, including
the actual generated difficulty ladder and unique solutions.

The latest Boss visual gate separately passed **21 tests**, zero failures or
skips: `/tmp/numberclub-false-boss-markings-after.xcresult`. This includes the
correction that keeps Handy Dandy/Censor decoration from resembling additional
blocked board squares. Native per-Boss retesting and full ordinary Book
playthroughs remain distinct from this automated evidence.

Current rendered phone briefings and the twelve-scene contact sheet are in
`/tmp/numberclub-living-route-final-check-attachments/`. The later native iPad
coupon/Book-scene recording is
`/tmp/numberclub-skip-and-living-scene-preview.mp4`; it shows the purple
Genuinely theme, its moving cards/clover, the pinned coupon departure, and the
fixed route/Play positions. These are simulator visual checks, not a physical
device frame-rate guarantee. No device deployment, commit or upload was made
by this recheck.
