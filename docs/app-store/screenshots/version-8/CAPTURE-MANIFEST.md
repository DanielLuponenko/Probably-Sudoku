# Native iPad recapture — version 1.0 (8)

Captured 2026-09-06 after the iPad briefing and selected-book layout fixes.
Next Puzzle was recaptured after the final 280-point wide-screen ticket cap;
the earlier build 8 native original remains at
`/tmp/numberclub-appstore-screenshots-v8/ipad/02-next-puzzle.png` as evidence.
The release owner reviewed these three images and uploaded them to App Store
Connect's iPad 13-inch slot on 2026-09-06. Apple displays **3 of 10 Screenshots**
and accepted the native 2048 × 2732 files. Version 7 originals remain unchanged
in the parent folder and were not used for this upload.

## Source and device

- App: `/tmp/numberclub-appstore-ads-proof.IRjCj4/DerivedData/Build/Products/Debug-iphonesimulator/ProbablySudokuAppStore.app`
- Bundle: `com.numberclub.app`, version 1.0, build 8 (bundle metadata checked).
- SDK-free Debug build supplied by the release team, launched as the normal
  full app, without an XCTest runner or hosted screenshot fixture.
- iPad Pro 12.9-inch (6th generation), iOS 26.3, native **2048 × 2732**.
- Isolated simulator: `4F6E1C10-92FC-4D4A-986B-CC1932676D38`.
- Installed in place; no data reset or player progress changes for unlocks.

## Store candidates

| File | Native original |
| --- | --- |
| `ipad-12.9/01-puzzle-gameplay.png` | `/tmp/numberclub-appstore-screenshots-v8/ipad/01-puzzle-gameplay.png` |
| `ipad-12.9/02-next-puzzle.png` | `/tmp/numberclub-appstore-screenshots-v8-final/ipad/02-next-puzzle.png` |
| `ipad-12.9/05-selected-book.png` | `/tmp/numberclub-appstore-screenshots-v8/ipad/05-selected-book.png` |

All are original full-screen `simctl` PNG captures. No resizing, cropping,
compositing, alpha conversion, or artwork changes were performed. Copies were
compared byte-for-byte with their native originals. Navigation and real
gameplay preparation follow the version 7 manifest (`APPSTORE7`, native
inventory items, real 9/4 placements and End Turn, resulting in 290 points).

## Native verification

- Next Puzzle: the regular cards and Boss ink board retain their proportions;
  the clipping ticket is capped at 280 points within a centered page column.
  The extra room is plain page below the ticket; the header, route, and Play
  button retain their positions. All text, action labels, and page number are
  visible in the final native recapture.
- Selected Book: top, middle, and bottom shelf editions were selected. The
  complete benefit plaque stays above the separate Open the Book button.
  Volume 9 displays the full `45 → 60` badge and its two-line description.
- Gameplay: full grid and hand remain visible; two correct placements and
  End Turn produce score 290 and Turn 2/10.
- Selection/return: all three shelf tiers returned and the next cover could
  be selected. The recorded 30 Hz frame samples show the stationary plaque
  fade followed by the reverse shelf path, without a missing-book frame or
  visible jump in those samples. This is not a physical-device FPS claim.
- Only obstacle I was available in this isolated simulator's existing normal
  progress. Higher obstacles were not artificially unlocked for capture.

Additional QA evidence (not store candidates):

- `/tmp/numberclub-appstore-screenshots-v8/ipad/qa-middle-selected.png`
- `/tmp/numberclub-appstore-screenshots-v8/ipad/qa-bottom-selected.png`
- `/tmp/numberclub-appstore-screenshots-v8/ipad/selection-return-check.mov`
- `/tmp/numberclub-appstore-screenshots-v8/ipad/qa-top-return-frames.jpg`
- `/tmp/numberclub-appstore-screenshots-v8/ipad/qa-middle-return-frames.jpg`
- `/tmp/numberclub-appstore-screenshots-v8/ipad/qa-bottom-return-frames.jpg`

The original version 7 iPad defects are retained in its manifest as baseline
evidence; these native captures verify the two scoped fixes.
