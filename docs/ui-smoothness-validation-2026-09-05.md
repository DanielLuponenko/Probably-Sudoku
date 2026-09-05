# UI smoothness audit — 2026-09-05

## Scope

Native book rack, briefing-to-puzzle handoff, gameplay presentation, paper
overlays, achievements, failure and return to the menu. Keep the existing
flexible Metal page, opaque blank reverse, gameplay rules, persistence and
simulator-only QA separation. The preceding board-layout consistency changes
remain in this branch.

## Reproduced causes and changes

- Rack selection repeatedly rasterized unchanged 1152×1387 cover images and
  scheduled scale-to-1 actions for every book. Material print keys now skip
  unchanged work; initial progress is supplied before the first cover bake.
- Starting play generated the puzzle inside the first-frame callback. The
  briefing now prepares a value-copy Game off the main actor. A revision and
  request token must still match before the live deal commits. Skipping,
  cancellation or inventory changes cannot adopt stale state or advance the
  saved RNG. A pending Play cannot turn behind a paper overlay.
- End Turn and clock expiry sometimes changed pages before the view could
  capture the outgoing puzzle. Terminal navigation now uses the same curl;
  foreground and overlay-close reconciliation retry interrupted handoffs.
- Returning from Achievements skipped the page turn. Returning from a failed
  Book bypassed the captured menu-return path and replayed the studio intro.
  Both now use their existing transition owners.
- Duplicate digits were reconciled by value: spending the first matching tile
  could visually remove the other copy. Successful consumption now removes the
  exact card identity; carried cards and Jade returns retain their identities.
- The first score-counter pass corrected wheel identity across carries. The
  high-score follow-up below supersedes those custom wheels after a rendered
  regression exposed independent digit clipping under horizontal compression.
- Paper slips scaled the full-screen dimmer; nested Help retained hidden
  Settings controls. Slips fade without scaling the backdrop; Help replaces
  the Settings card and reveals only its incoming paper. Input and boss time
  remain paused through dismissal. Consumed Buff metadata stays on its outgoing
  slip and cannot be spent twice during its fade.
- Cancelled clipping-arrival tasks stop changing the next ticket. Rolling
  numbers, Help navigation and shared pressed-paper feedback honor Reduce Motion.
- Shop marker placement began behind a dismissing item sheet and was clipped
  to the page, leaving the desk controls exposed. Its handoff now waits for
  native sheet dismissal and uses the shared full-desk modal owner. Marker
  metadata remains attached to the outgoing placement slip.

## Evidence

- Simulator: Probably Sudoku Ad QA, iPhone 17 Pro, iOS 26.3.1.
- Before traces: `/tmp/numberclub-ui-smooth-baseline.trace` and
  `/tmp/numberclub-rack-smooth-baseline.trace`.
- After trace: `/tmp/numberclub-ui-smooth-after.trace` (45.59 seconds, app-only
  Time Profiler; no recorded hangs).
- Actual Play-button recording: `/tmp/numberclub-ui-smooth-after.mov`.
  `/tmp/numberclub-ui-play-frames.png` samples its bend at 50 ms intervals:
  attached print, curved stock, opaque unprinted reverse.
- Rack native regression had 223 assertions fail before its patch. The first
  GREEN run retained image identity and exact pixels; 12 unchanged coordinator
  updates took 0.118 ms, excluding fixture creation and assertions.
- One deterministic boss fixture spent 342 ms generating off-main, then about
  0.060 ms committing the prepared value. This is a model-boundary measurement,
  not the total snapshot/upload/animation duration.
- Focused first gate: 51 app tests passed. Engine gate: 195 tests passed.
  Logs: `/tmp/numberclub-ui-smooth-focused.log`,
  `/tmp/numberclub-ui-smooth-engine.log`.
- Final native Help check shows only Help controls in the full accessibility
  tree. Before the fix it also exposed the hidden Settings actions.
- `/tmp/numberclub-terminal-return-after-frames.png` samples the failed Book
  return at 50 ms intervals: the captured page fades into the rendered aisle,
  without the previous studio-intro interruption or a missing-assets frame.
- Final gates: **183 app tests and 195 engine tests passed**, including all
  board-layout, duplicate-card, preparation, modal-handoff and cancellation
  checks. The first full run caught a new test fixture attempting a legacy Clue
  with zero clues; both legacy fixtures now grant a clue and verify the actual
  board fill and clue consumption, not just unchanged identities.
  Final log: `/tmp/numberclub-ui-smooth-full-app-final.log`.
- Final unsigned generic-iOS Release build passed:
  `/tmp/numberclub-ui-smooth-release-final.log`.
- Final live marker purchase → native sheet dismissal → full-desk placement →
  placement dismissal → Shop continuation passed. The HUD dims with the page,
  and shop controls return after placement. Recording:
  `/tmp/numberclub-marker-handoff-final.mov`; settled screenshot:
  `/tmp/numberclub-marker-placement-final.png`.

## Limits

Simulator Time Profiler has no animation-hitch/SwiftUI cause lanes here. These
recordings do not establish physical-device FPS or prove every possible UI
state hitch-free. No shader/mesh replacement, asynchronous persistence rewrite,
physical-phone installation, commit, merge or release is part of this pass.

## High-score follow-up

The user's physical-phone photo exposed a state the first pass did not test
for printed legibility: score 122,541, target 128,000, queued 495 × 39.75, and a
+6 coin receipt. The board-size tests alone did not detect sliced score glyphs.

- Reproduced the same sliced digits and truncated queued text in native renders
  at a 300-point page-content width. The RED gate had 18 failed assertions:
  ten in score-band tests, eight from truncated failure-page values at the
  largest accessibility text size. Log: `/tmp/numberclub-high-score-red.log`.
  Screenshot: `/tmp/numberclub-high-score-before.png`.
- Replaced independently clipped digit strips with one uniformly fitted Text
  using the native numeric transition. Grouping/signs stay part of the number,
  and Reduce Motion still disables its animation.
- The score/target now have a separate line above the queued points and coin
  receipt. Both lines are reserved even with no receipt, using the original
  header-height budget so the grid cannot shrink or shift after a placement.
- At accessibility sizes the failure score panel uses full-width stacked values
  instead of two narrow columns. Its enclosing page already supports scrolling
  at these sizes; ordinary phone layouts retain the two-column panel.
- The fixed-size, accessibility-hidden “THE END (for now)” paper keeps its
  illustration text size. Its custom handwriting previously enlarged until
  “for now” was clipped; surrounding accessible reading text still scales.
- Added rendered/OCR coverage for complete values, grouping and signs, exact
  photographed rewards, seven-/nine-digit stress cases, results, the coin HUD,
  run information and book completion. Full-page geometry checks now cover real
  Copper coin receipts on four phone sizes at normal and accessibility text.
- First focused GREEN gate: 23 native tests passed; the follow-up nine-digit
  failure panel render also passed at accessibility5 and 300/365-point widths.
  Logs: `/tmp/numberclub-high-score-focused.log`,
  `/tmp/numberclub-high-score-failure-extreme.log`.
  After image: `/tmp/numberclub-high-score-photo-300.png`; full-page fixture:
  `/tmp/numberclub-high-score-full-page.png`.
- Final follow-up gates: **192 app tests and 195 engine tests passed**.
  Logs: `/tmp/numberclub-high-score-full-app.log`,
  `/tmp/numberclub-high-score-engine.log`.
- Unsigned generic-iOS Release build passed:
  `/tmp/numberclub-high-score-release.log`. These follow-up fixes remain local;
  they have not been committed, merged, published or installed on phones.
