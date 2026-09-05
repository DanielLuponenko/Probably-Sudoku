# Larger puzzle board — 2026-09-06

## Request and layout contract

Make the live Sudoku board larger by compacting the title/score area, including
all Boss puzzles. Preserve the paper styling, game rules, page curl, readable
score receipts and reachable controls. Release all pending game work as build 7.

The old layout reserved a tall three-line, two-column Boss stamp even on ordinary
puzzles, plus a separate score/level row and oversized score-counter allowance.
The shared page now uses a smaller title with Level/progress alongside it, a
full-width two-line Boss annotation, a compact score receipt and tighter spacing.
The board takes priority; its square hit-test geometry remains GridView's own.
Bosses, changing scores, payouts, notes, Hand capacity and Clues cannot resize it.
Toss/End Turn remain at least 44 points high. No scrolling was added.

Palette and type follow the existing book: warm paper, charcoal ink, sage green,
thin pencil rules, heavy compact headings and handwritten marginalia. No new
assets or unrelated UI surfaces were introduced for this layout change.

## Hosted measurements

Same production BookmarkRow/BookView/PageSurface geometry, explicit safe areas:

| Viewport | Previous board side | New board side | Available page width |
| --- | ---: | ---: | ---: |
| 375 × 667 (SE) | 177.85 pt | 242.01 pt | 300 pt |
| 375 × 812 | 196.36 pt | 283.63 pt | 300 pt |
| 402 × 874 (17 Pro) | 240.36 pt | 327 pt | 327 pt |
| 440 × 956 (Pro Max) | 322.36 pt | 365 pt | 365 pt |

The Pro grid is 36% wider; the Pro Max grid is 13% wider. Full 27-stage and Boss
roster checks retain the same side, top position and horizontal center (1-point
tolerance). Tests now reject a consistently tiny board instead of only requiring
it to be nonzero. Final-Boss fixtures explicitly use Level 9 and assert the
requested Boss was actually dealt.

## Verification

- First focused pass caught undersized SE/375 layouts; moving Level/progress
  into the title row recovered the remaining space.
- Second focused pass: 7 tests passed, including full hosted geometry/state
  coverage and score OCR through nine digits with queued points and coin receipts.
  `/tmp/numberclub-larger-board-pass2.xcresult`
- Screenshot review: normal 402-point page, long-name Accountant on 440-point
  page, compact SE, and accessibility text. This also exposed handwritten notes
  growing out of their band at accessibility sizes. MarginNoteView now receives
  its actual height budget and fits its two lines with a width/angle-derived
  rotation gutter. The original 38/46-point handwriting bands were retained;
  the compact page recovers space through inter-section spacing instead.
- Full Engine suite: 207 tests passed.
  `/tmp/numberclub-build7-engine.log`

The full-app sweep also found old Boss visual fixtures requesting final bosses
on Level 1; the production pool correctly substituted ordinary bosses. Those
fixtures now explicitly use Level 9 and assert the requested Boss was dealt.
All distinct-treatment and live-rule assertions remain unchanged.

Final verification covers all **287 app tests**: the full sweep plus the focused
rerun of the corrected 9 Boss-visual tests and 2 annotation tests. Production
source was unchanged during those final reruns. Two visually verified OCR
ambiguities (Erratum's zero and a handwritten line-leading i) have narrow,
documented recognition corrections; no ellipsis or ink-containment assertion
was relaxed.

- Full sweep: `/tmp/numberclub-build7-all-app.xcresult`.
- Corrected Boss fixtures: `/tmp/numberclub-build7-final-regressions.xcresult`.
- Final annotation suite: `/tmp/numberclub-build7-annotations-final.xcresult`.
- Final normal/large-text images: `/tmp/numberclub-build7-final-images/`.

The earlier full-book playtest remains paused and its separate simulator/run was
not modified. These checks are layout/regression verification, not a claim of
another complete playthrough or physical-device frame-rate measurement.

## Release safety

Standard `ProbablySudoku` / `Release`, version 1.0 (7), retains test-ad IDs and
excludes simulator-only QA entry points/Obstacle overrides. No TestFlight upload,
live-ad rollout, uninstall or player-data reset is part of this request.

Signed archive: `/Users/daniel/Downloads/ProbablySudoku-Build7-Final.xcarchive`.
Executable SHA-256:
`b18f825d069d218ca38b165b2a48defb91ed7626146f0b21bf985cd95bbaf933`.
Signature/provisioning validated for all three registered phones. The initial
archive is retained as rollback evidence, not used for installation.
