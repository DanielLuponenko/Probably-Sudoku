# App Store screenshots — version 1.0 (7)

**Release status:** the five iPhone images were accepted by App Store Connect.
The three iPad images are retained as version 7 baselines only: **do not upload
these baseline files**. The scoped iPad fixes have now been verified with a
fresh native capture pass in [version 8](version-8/CAPTURE-MANIFEST.md).
The two additional diagnostic images listed below are not store screenshots.

Captured on 2026-09-06 from the native, full application. These are unmodified
`xcrun simctl io <device> screenshot <path>` PNGs, not hosted XCTest views,
mockups, composites, crops, or resized images. The top HUD and book surfaces
are rendered by the application. No QA banners, ads, or debug panels are shown.

Source app:
`/tmp/numberclub-onboarding-derived/Build/Products/Debug-iphonesimulator/ProbablySudoku.app`

The installed bundle reports `CFBundleShortVersionString = 1.0` and
`CFBundleVersion = 7`. The release owner supplied this stable build; no app
source or build configuration was changed for capture.

## Devices and files

Both screenshot devices were newly created, isolated simulators running
iOS 26.3 (23D8133). Existing playtest simulators and physical devices were not
used. Status-bar overrides were scoped to these two devices only.

- iPhone 14 Plus: `A063BEFC-8547-46BF-8642-5F490F8FD711`, **1284 × 2778**.
- iPad Pro 12.9-inch (6th generation):
  `4F6E1C10-92FC-4D4A-986B-CC1932676D38`, **2048 × 2732**.

| Repository file | Native capture original |
| --- | --- |
| `iphone-6.5/01-book-rack.png` | `/tmp/numberclub-appstore-screenshots/01-book-rack.png` |
| `iphone-6.5/02-selected-book.png` | `/tmp/numberclub-appstore-screenshots/02-selected-book.png` |
| `iphone-6.5/03-puzzle-gameplay.png` | `/tmp/numberclub-appstore-screenshots/03-puzzle-gameplay.png` |
| `iphone-6.5/04-next-puzzle.png` | `/tmp/numberclub-appstore-screenshots/04-next-puzzle.png` |
| `iphone-6.5/05-shop.png` | `/tmp/numberclub-appstore-screenshots/05-shop.png` |
| `ipad-12.9/01-puzzle-gameplay.png` | `/tmp/numberclub-appstore-screenshots/ipad/01-puzzle-gameplay.png` |
| `ipad-12.9/03-shop.png` | `/tmp/numberclub-appstore-screenshots/ipad/03-shop.png` |
| `ipad-12.9/04-book-rack.png` | `/tmp/numberclub-appstore-screenshots/ipad/04-book-rack.png` |

## Reproduction

Debug-only navigation prepared real application pages and item instances; it
did not substitute screenshot-only artwork or view trees. The seed was
`APPSTORE7`.

- Rack: launch with `-bookRack`; tap the first cover for selected-book view.
- Puzzle: `-skipStartScreen -seed APPSTORE7 -loadout`. Using only the visible
  Sudoku board, place 9 in row 4 column 2, then 4 in row 4 column 3 and tap
  End Turn. The captured state has 290 points and Turn 2/10.
- Next puzzle: `-skipStartScreen -seed APPSTORE7 -briefing -loadout`.
- In-run shop: `-skipStartScreen -seed APPSTORE7 -shop -loadout`. Sell Peek
  through its native inventory action, then wait for the sale feedback to
  disappear. The captured state has 6 coins and a free Buff slot.

All eight selected images were visually inspected at their native dimensions.
The PNGs contain an alpha channel, but every pixel is fully opaque. Original
PNG bytes were preserved; no alpha flattening or color conversion was applied.

## iPad issues found during capture

These are real application layout findings, not corrected in the screenshots:

1. The next-puzzle route cards become very wide on iPad. Regular board
   previews remain small while the Boss ink board stretches horizontally;
   the Clipping card also has excessive empty space. Evidence:
   `/tmp/numberclub-appstore-screenshots/ipad/02-next-puzzle.png`.
2. The selected-book benefit plaque falls below the iPad viewport and is
   covered by the Open the Book button. Evidence:
   `/tmp/numberclub-appstore-screenshots/ipad/05-selected-book.png`.

Neither evidence image is included in the eight-file store set. They remain
separate evidence for release review; omitting them does not resolve the
underlying iPad layouts.
