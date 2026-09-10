# Build 13 App Store screenshot capture

Captured September 10, 2026 (Asia/Jerusalem) from the current native app, version **1.0.1 (13)**. All twelve images are fresh captures; earlier screenshot sets remain preserved.

## Source and devices

- App: `com.numberclub.app`, `ProbablySudoku.app`, Debug simulator build from the final build 13 source merged into `main` at `d3233edd47ab484de2d0e9a3002d4ebdbf330aee` (implementation commit `b5ae7fa`).
- Installed binary: `/Users/daniel/Downloads/ProbablySudoku-Build13-20260910/DerivedData/Build/Products/Debug-iphonesimulator/ProbablySudoku.app`.
- `ProbablySudoku.debug.dylib` SHA-256: `03e63b63bcaa48c50e7f5f3405b60d20b754fc541947c39cf75590326ba98f64`.
- Existing simulator navigation arguments prepare real game state using the normal game engine and normal app views. No screenshot fixture views or replacement artwork were used.

| Source directory | Device | Simulator UUID | Native portrait dimensions |
| --- | --- | --- | --- |
| `iphone-6.5` | iPhone 14 Plus | `A063BEFC-8547-46BF-8642-5F490F8FD711` | 1284 × 2778 |
| `ipad-12.9` | iPad Pro 12.9-inch, 6th generation | `4F6E1C10-92FC-4D4A-986B-CC1932676D38` | 2048 × 2732 |

Both devices used runtime `com.apple.CoreSimulator.SimRuntime.iOS-26-3` (26.3.1, build 23D8133). The dedicated devices are named “Probably Sudoku App Store Screenshots” and “Probably Sudoku App Store iPad”.

## Capture method and preservation

Each screenshot was written directly with `xcrun simctl io <device-uuid> screenshot <path>.png`. The PNGs have not been cropped, resized, composited, retouched, or converted. Actual production UI remains visible; there are no QA banners or debug overlays. Native status-bar overrides set 9:41 and full battery/network indicators during capture.

Before installing the current app in place, the entire existing app data container on each dedicated simulator was backed up with `ditto` under:

- `/Users/daniel/Downloads/ProbablySudoku-Build13-20260910/store-capture-backups/iphone-data`
- `/Users/daniel/Downloads/ProbablySudoku-Build13-20260910/store-capture-backups/ipad-data`

No app uninstall, simulator erase, or repository asset replacement was performed. The backups remain available; capture state remains on the dedicated devices. After capture, status-bar overrides were cleared, the app was terminated, and both dedicated simulators were shut down.

## Reproduction and pictured state

The same scenes and real UI actions were used on both devices.

| Original filename | Preparation and pictured state |
| --- | --- |
| `01-puzzle-gameplay.png` | Launch with `-skipStartScreen -seed APPSTORE7 -loadout`. Select 9 and place it in row 4, column 2; select 4 and place it in row 4, column 3; tap End Turn. Shows settled score 290, Turn 2 of 10, 29% progress, the refilled seven-number Hand, the current HUD, board, items, Toss, and End Turn. The loadout contains Morning Edition, Evening Edition, Local Gossip, Peek, and Fresh Ink. |
| `02-book-rack.png` | Launch with `-bookRack`. Shows the current unselected Book rack and native cover artwork, with volumes 1, 5, and 9 at the front of the first shelf. |
| `03-shop.png` | Launch with `-skipStartScreen -seed APPSTORE7 -shop`, without `-loadout`. Shows the real first Shop, five coins, free item slots, current prices and affordability states, and Continue. Offers are Front Page Splash (6), Op-Ed Column (5), Sapphire Marker (6), Crimson Marker (9), and Paper Crane (3). |
| `04-interactive-tutorial.png` | Open Settings → Replay tutorial through the actual app UI. Continue to Practice 2 of 24, “Start with a number.” Shows the highlighted 2 in the Hand above the board before the learner selects it. Uses the shipped tutorial seed `probably-sudoku-onboarding-v1`. |
| `05-multipliers-and-items.png` | Continue the actual tutorial: select and place 2 at row 4, column 9; End Turn banks 65 points; continue into the practice Shop; buy Local Gossip (4), Op-Ed Column (5), Golden Marker (5), and Fresh Ink (4); attach the marker to row 1, column 8; select and place 9 there. Practice 14 of 24, “See your combination,” shows `265 queued base × 2 mult = 530 points to bank` alongside the owned Bookmarks, Marker, and Buffs. This is the shipped guided scenario reached through its real controls. |
| `06-selected-book-benefit-sign.png` | From the Book rack, select the first cover, “You've Got This, Probably,” and let the transition settle. The benefit `+1 HAND SIZE` appears directly on the physical green sign above the Book. The retired lower benefit banner is absent. The cover, obstacle tabs, and Open the Book button are visible. |

The iPad tutorial retains its normal centered reading column and native surrounding paper space. Neither tutorial screenshot uses autoplay, a simulated control, or a hosted test view.

## App Store gallery order

Original source filenames above are preserved because they have already been linked in the release conversation. Byte-identical upload copies have separate names to put the current Book benefit sign near the beginning of the gallery.

Upload copies are under `/Users/daniel/Downloads/ProbablySudoku-Build13-20260910/AppStoreUpload/`, with one `iphone-6.5` and one `ipad-12.9` subdirectory. The following mapping applies to both:

| Gallery order | Original source filename | Upload filename |
| --- | --- | --- |
| 1 | `01-puzzle-gameplay.png` | `01-puzzle-gameplay.png` |
| 2 | `06-selected-book-benefit-sign.png` | `02-selected-book-benefit-sign.png` |
| 3 | `03-shop.png` | `03-shop.png` |
| 4 | `02-book-rack.png` | `04-book-rack.png` |
| 5 | `04-interactive-tutorial.png` | `05-interactive-tutorial.png` |
| 6 | `05-multipliers-and-items.png` | `06-multipliers-and-items.png` |

## Verification

- Six iPhone PNGs are exactly 1284 × 2778; six iPad PNGs are exactly 2048 × 2732.
- All images are fully opaque. The native RGBA PNGs have alpha-channel extrema `(255, 255)`; no transparency conversion was applied.
- SHA-256 comparison confirms all twelve ordered upload copies are byte-identical to their corresponding native originals.
- Independent visual review passed all twelve originals: important text and controls are visible, no QA/debug overlays are present, and both selected Book screenshots show `+1 HAND SIZE` on the physical top sign with no old lower banner.
- Machine-readable dimensions, opacity, hashes, and source-to-upload mapping are preserved in `/Users/daniel/Downloads/ProbablySudoku-Build13-20260910/AppStoreUpload/verification.json`.

This manifest records image capture and local validation. The final App Store upload and submission status is recorded separately in `docs/app-store/BUILD-13-DELIVERY.md`.
