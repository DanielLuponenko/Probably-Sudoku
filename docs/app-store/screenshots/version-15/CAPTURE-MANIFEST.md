# Probably Sudoku 1.1.0 (15): App Store screenshots

Captured 20 September 2026 from the current native simulator app. Ten replacement screenshots were uploaded and saved: five iPhone and five iPad, ordered by their numbered filenames. They are included in version 1.1.0 (15), submitted to App Review on 20 September 2026 at 15:25 Asia/Jerusalem and confirmed Waiting for Review. See the [delivery receipt](../../BUILD-15-DELIVERY.md) for the submission record.

## Native source and exact dimensions

| Folder | Dedicated capture device | Simulator UUID | Portrait pixels | App Store category |
| --- | --- | --- | --- | --- |
| `iphone` | iPhone 14 Plus, “Probably Sudoku App Store Screenshots” | `A063BEFC-8547-46BF-8642-5F490F8FD711` | 1284 × 2778 | iPhone 6.5-inch |
| `ipad` | iPad Pro 12.9-inch, sixth generation, “Probably Sudoku App Store iPad” | `4F6E1C10-92FC-4D4A-986B-CC1932676D38` | 2048 × 2732 | iPad 13-inch accepted size |

These are the same devices and native dimensions documented in `docs/app-store/screenshots/version-13/CAPTURE-MANIFEST.md`. Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), checked on capture day, list 1284 × 2778 for iPhone 6.5-inch and 2048 × 2732 for iPad 13-inch.

Installed app: `/tmp/NumberClub-boss-verification2/Build/Products/Debug-iphonesimulator/ProbablySudoku.app`, bundle `com.numberclub.app`, reported version **1.1.0 (15)**.

- `ProbablySudoku` SHA-256: `7c17bcdecc9de34b39d5450003782e940719f3c104a749188a86741f2dc74d1d`
- `ProbablySudoku.debug.dylib` SHA-256: `94c64c085f7d088bc5c513ab3ebc8d3e0f57ea5acfa7b7b32401df7142a4f5de`
- Release source at capture: `025defbbfb7d55cbdb528f3f337092be00e9a8c5`; parent release workflow reports PR 123 merged to main `3de344e`. The capture binary was built before a final Volume 5 achievement punctuation correction; no photographed UI changed in that correction. The binary hash, rather than a claimed embedded source revision, is the authoritative capture identity.

## Gallery order, captions and reproduction

Both device folders contain the same five filenames and scenes.

| File | Suggested caption | Actual pictured state / preparation |
| --- | --- | --- |
| `01-gameplay.png` | Build your score with Bookmarks and Buffs | `-skipStartScreen -seed visual-audit -loadout`. Through native controls, open Fresh Ink and choose Use, then select Hand number 1 and place it at row 1, column 6. Live score is +120 from 40 × 3: the normal 10 placement points plus 30 from Local Gossip, multiplied by the active Fresh Ink multiplier. The Buff is consumed and its slot is empty; Peek remains owned. No score was directly edited. |
| `02-boss-bricks.png` | Face bosses that change the board | `-skipStartScreen -seed visual-audit -gameplayFixture fullinventory -qaBoss garryTheGray`. Current active-roster Garry the Gray engine rule and rendering: one box locked each Turn, visible red bricks on its empty positions, five Bookmarks and two Buffs. Captured after brick entry animations settled. Score 0, Turn 1, normal current game view. |
| `03-shop.png` | Choose your next combination | `-skipStartScreen -seed visual-audit -shop`. The native Shop reached through normal begin, target-met, cash-out and open-Shop actions. Twenty coins; Local Gossip 5, Auction Notices 8, Sapphire Marker 7, Echo Marker 7 and Inventory Count 3. All offers and Continue fit in the native screen. |
| `04-next-puzzle.png` | Play the puzzle or skip for a Buff | `-skipStartScreen -seed visual-audit -briefing`. Real Chapter 1 preview, target 1,000, ten Turns, The Mirror announced ahead, and deterministic Careful Cut skip offer with its effect. Both Skip + Buff and Play puzzle are visible. |
| `05-choose-book.png` | Open a Book and choose your challenge | `-bookRack -focusBook`. Native first Book selection, “You've Got This, Probably,” physical +1 HAND SIZE sign, obstacle tabs, current cover artwork and Open the Book action. |

All launch routes additionally used `-isolateCloudQA -resetProfile`. Debug launch state stays nonpersistent; the normal game views and engine are rendered. No QA panels, simulator chrome, fake interface, compositing, crops, resizing or retouching were added.

## Capture, preservation and verification

- Every image was written directly by `xcrun simctl io <uuid> screenshot <path>.png` at full device resolution.
- Existing app data containers were backed up before installation to sibling `store-capture-backups/iphone-data` and `store-capture-backups/ipad-data` using `ditto`. No uninstall, erase, or save reset was performed. The player's iPhone 17 Pro `223A4227…` and Book Playtest A `D04D3836…` were untouched.
- Native status-bar overrides set 9:41, Wi-Fi and full battery for the session; the app normally hides its status bar. Overrides were cleared after capture, both apps terminated, and both dedicated capture devices shut down.
- All ten images were opened and visually reviewed. Current artwork is centered, current live scoring is shown, required actions remain visible, and there are no QA/debug overlays or transition frames.
- Machine verification confirms all five iPhone files are 1284 × 2778 and all five iPad files are 2048 × 2732. Each native RGBA PNG is fully opaque: alpha extrema 255–255. No conversion was needed.
- `verification.json` records every image's exact dimensions, byte size, alpha range and SHA-256, plus source app identity.

The iPad screenshots intentionally retain the application's actual tablet layout and surrounding paper space; no enlargement or composition was applied to disguise that layout.
