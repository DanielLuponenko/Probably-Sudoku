# Game Center configuration — Probably Sudoku

Source audit: 2026-09-06. App: `com.numberclub.app`, Apple ID `6808968186`.

**Current server state:** three leaderboard and nineteen achievement drafts
created and localized in English (U.S.), all **Prepare for Submission**.
All nineteen achievements were reopened individually to confirm saved settings
and processed artwork. Nothing was added for review, enabled for an app version or
published. The separate task tab was `433378159`; other metadata tabs were not
used. [Observed Game Center inventory](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter).

**Resolved identifier blocker:** Apple rejected the original source ID
`com.numberclub.app.highest-puzzle-score` with “Only alphanumeric characters,
periods, and underscores are allowed”. That form was canceled without creating
a record. The release owner then authorized the coordinated external-ID-only
hyphen-to-underscore correction. Source IDs below were confirmed patched before
the corresponding drafts were completed; no local achievement identity changed.

Game Center is optional: local play, saves and the achievement page continue
without authentication. Failed submissions stay queued locally. This graceful
fallback does not make draft Game Center records a verified leaderboard
or achievement integration. Finish configuration and verify the integration
before public release; do not describe remote rankings as already verified.

## Leaderboards

Exact IDs come from `App/Model/GameCenterService.swift:15`. Display names and
suffixes below are saved English (U.S.) draft metadata.
The source sends integer values, retains the maximum queued value, and never
resets a season: **Classic**, **Integer**, **Best Score**, **High to Low** fit
the implementation for all three. Use English (U.S.) localization initially.
Avoid an arbitrary score ceiling: valid scores outside a configured range are
discarded by Game Center. [Apple leaderboard properties](https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards)

| Exact leaderboard ID | Saved display/reference name | Actual submitted value | Saved singular / plural suffix |
| --- | --- | --- | --- |
| `com.numberclub.app.highest_puzzle_score` | Highest Puzzle Score | Highest positive integer puzzle score reported on entry to results, excluding the pending `outOfTurns` rescue phase. This can include a failed puzzle's score, not only wins. | ` point` / ` points` |
| `com.numberclub.app.highest_level_reached` | Highest Level Reached | Puzzle level, normally 1–9, when a puzzle begins and when results are shown. It is not the number of puzzles completed. | ` level` / ` levels` |
| `com.numberclub.app.books_completed` | Books Completed | Number of distinct completed Book IDs, normally 1–12. Repeating a Book or completing its harder obstacle does not add another distinct Book. | ` book` / ` books` |

### Saved draft records and proof

All three detail pages confirmed Integer, Best Score and High to Low; their
final inventory rows confirmed Classic (Single) and Prepare for Submission.
Optional score range, image, localized format override, properties, activity
and challenge associations were left empty. Hidden remained No. Apple
automatically made the first-created Highest Puzzle Score board the Default;
no manual default or ordering change was made.

| Draft / server record UUID | Saved English description |
| --- | --- |
| [Highest Puzzle Score — `ac3e3c21-a1ee-4e29-9e3b-fc261e34ce6b`](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/leaderboards/ac3e3c21-a1ee-4e29-9e3b-fc261e34ce6b) | Your highest score in a single puzzle. |
| [Highest Level Reached — `65ee9ab9-5ab8-4ff9-976b-af248c29f351`](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/leaderboards/65ee9ab9-5ab8-4ff9-976b-af248c29f351) | The highest level you have reached in a Book. |
| [Books Completed — `ca2496e0-90c5-4d57-b188-b438594a6b31`](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/leaderboards/ca2496e0-90c5-4d57-b188-b438594a6b31) | The number of different Books you have completed. |

Evidence:

- `GameModel.swift:933–935`: result score/level submission.
- `GameModel.swift:1113–1115`: level submission on puzzle start.
- `GameModel.swift:254–258`: completed-Book submission after recording completion.
- `RunStore.swift:140–144,158–170,186`: distinct Book identity/count.
- `GameCenterService.swift:100–105,144–149`: positive values only, maximum queued
  value, `GKLeaderboard.submitScore`, `context = 0`.

No recurring schedule, monetary format, fractional multiplier format,
leaderboard set, default leaderboard or challenge metadata is specified in code.
No new gameplay mode was invented by the draft configuration.

### Local delivery-queue compatibility

`GameCenterService.init(defaults:)` forward-normalizes only known former
external aliases in the existing `game-center.pending-scores.v1` dictionary
and `game-center.pending-achievements.v1` array. Colliding scores keep their
maximum; achievements use set union; unknown IDs remain unchanged. Local
catalog IDs, earned-award IDs, profile/cloud data and queue storage shapes stay
unchanged. Older builds can still read these v1 shapes and may re-add old
aliases; upgrading again normalizes them safely. No old server records existed
to migrate. This preserves pending delivery, not proof of authenticated delivery.

SDK-free migration gate: **33 tests passed, 0 failures** (8 ID migration,
15 Book completion progress, 2 distribution metadata, 8 ad configuration).
Log: `/tmp/numberclub-appstore-ads-proof.IRjCj4/game-center-id-migration-tests.log`.
Result: `/tmp/numberclub-appstore-ads-proof.IRjCj4/GameCenterIDMigrationTests.xcresult`.

## Achievements — all 19

Exact titles and current in-app descriptions below come from
`App/Model/Achievements.swift:92–133`. The full external ID is constructed at
line 86 by replacing hyphens only in its external suffix. Local IDs remain
hyphenated. Category counts: Progress 6, Mastery 5, Economy 4, Character 4.

| Category | Exact Game Center achievement ID | Display name | Current in-app description |
| --- | --- | --- | --- |
| Progress | `com.numberclub.app.achievement.finish_book` | Cover to Cover | Finish a Book. |
| Progress | `com.numberclub.app.achievement.finish_every_book` | The Whole Shelf | Finish all 12 Books. |
| Progress | `com.numberclub.app.achievement.reach_level_5` | Getting Serious | Reach Level 5 in a Book. |
| Progress | `com.numberclub.app.achievement.reach_level_7` | Still Here | Reach Level 7 in a Book. |
| Progress | `com.numberclub.app.achievement.reach_level_9` | Last Chapter | Reach Level 9 in a Book. |
| Progress | `com.numberclub.app.achievement.beat_ten_bosses` | Regular Visitor | Beat 10 Bosses. |
| Mastery | `com.numberclub.app.achievement.full_clear` | All Inked | Fill every square in a Puzzle. |
| Mastery | `com.numberclub.app.achievement.three_way_clear` | Triple Entry | Clear a row, column, and box with one placement. |
| Mastery | `com.numberclub.app.achievement.hundred_thousand` | Six Figures | Score 100,000 points in one Puzzle. |
| Mastery | `com.numberclub.app.achievement.flawless_boss` | No Red Pencil | Beat a Boss without a wrong placement. |
| Mastery | `com.numberclub.app.achievement.no_clue` | Read the Room | Finish a Puzzle without using a Clue. |
| Economy | `com.numberclub.app.achievement.hold_thirty_coins` | Deep Pockets | Hold 30 coins in a Book. |
| Economy | `com.numberclub.app.achievement.buy_subscription` | Paperwork | Buy a Subscription. |
| Economy | `com.numberclub.app.achievement.five_bookmarks` | Well Marked | Own five Bookmarks at once. |
| Economy | `com.numberclub.app.achievement.same_shop_sale` | Buyer’s Remorse | Sell an item back in the Shop where you bought it. |
| Character | `com.numberclub.app.achievement.obstacle_three_book` | Against the Grain | Finish a Book on Obstacle III. |
| Character | `com.numberclub.app.achievement.last_turn_win` | Down to the Wire | Finish a Puzzle on its last Turn. |
| Character | `com.numberclub.app.achievement.two_skips` | Editorial Control | Take both skips in one Book. |
| Character | `com.numberclub.app.achievement.keep_filling_full_clear` | One More Page | Keep Filling until you Full Clear a Puzzle. |

### Saved achievement draft defaults and reporting semantics

The release owner authorized reversible preparation defaults: **50 points per
achievement (950 total; 50 of Apple's 1,000-point allowance remaining)**,
**Hidden: No**, **Achievable More Than Once: No**, English (U.S.), source-exact
titles and pre-earned descriptions, and truthful earned text below. Every
localization uses the existing app icon as **temporary shared artwork**, not
final bespoke achievement art. No activities or optional properties were added.

- Local awards are one-time Set membership, saved before queuing Game Center
  (`PlayerProfileStore.swift:179–188`). The SDK receives only `percentComplete = 100`,
  not incremental progress (`GameCenterService.swift:182–189`). The saved
  **Achievable More Than Once: No** setting matches this behavior.
- Unearned in-app entries are visible (`AchievementsPageView.swift:3–5,15–19`);
  **Hidden: No** matches that presentation.
- **Point values are not defined in source.** The 50-point draft allocation is
  configuration only, not puzzle score, currency, or a new local reward. Approve
  the final allocation before publication; points cannot change once live.
- There is one source `detail` string per achievement, not separate pre-earned
  and earned descriptions. Drafts use the exact detail for pre-earned text and
  the earned wording recorded below. At least one localization and an image
  must be supplied; every draft now has both. Once live, achievement point
  values cannot be changed. [Apple achievement properties](https://developer.apple.com/help/app-store-connect/reference/game-center/achievements),
  [creation and lifecycle](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-achievements/).
- `Against the Grain` currently requires **exactly** Obstacle III, not III or
  higher (`PlayerProfileStore.swift:223`). `Regular Visitor` counts unique
  seed/level/boss encounter keys (`GameModel.swift:962–965`).
- Existing copy/implementation discrepancy to resolve deliberately, not hide
  in server metadata: `Buyer’s Remorse` currently checks a sold Bookmark's
  **purchase level**, not an exact Shop identity; Buffs supply no purchase level
  (`GameModel.swift:1169–1176`, `PlayerProfileStore.swift:265–267`). This audit
  does not change that existing achievement or gameplay.

### Saved achievement records / English earned text

All links below were returned by App Store Connect after creation. Each record
was verified to retain 50 points, Hidden No, repeatable No, English (U.S.),
processed `icon.png`, a disabled Save button and Prepare for Submission status.

| Saved record | Earned description |
| --- | --- |
| [Cover to Cover](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/db12f6c6-80e5-4c1b-a7b6-38d797fde375) | You finished a Book. |
| [The Whole Shelf](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/e1b4963e-d19b-4c0d-856d-6b6b54e30ad7) | You finished all 12 Books. |
| [Getting Serious](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/b3b9f3a7-f756-4b75-a231-a060275b4dab) | You reached Level 5 in a Book. |
| [Still Here](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/6ba4c924-92b6-4a58-8f67-193a7181ffa9) | You reached Level 7 in a Book. |
| [Last Chapter](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/8ed07a68-61b7-41a9-93b1-d75e5b5ecfa6) | You reached Level 9 in a Book. |
| [Regular Visitor](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/c5835116-3b83-4625-a46f-f90514c0f3ab) | You beat 10 Bosses. |
| [All Inked](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/1a36a9b4-4d8f-4001-91ec-f7ef0f26d033) | You filled every square in a Puzzle. |
| [Triple Entry](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/a960b002-0988-4bcb-906c-825e9509cbec) | You cleared a row, column, and box with one placement. |
| [Six Figures](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/ca5da166-7b0b-4636-8895-6927cf6e99e2) | You scored 100,000 points in one Puzzle. |
| [No Red Pencil](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/a9eb4d2b-cd3b-452f-8073-57b1bab72564) | You beat a Boss without a wrong placement. |
| [Read the Room](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/f60deb92-414e-4af1-9010-3263f4dd285d) | You finished a Puzzle without using a Clue. |
| [Deep Pockets](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/a640051e-01fa-4d35-bd15-0c22201efee0) | You held 30 coins in a Book. |
| [Paperwork](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/79f7aa6b-73f4-4050-be39-81575158e1c8) | You bought a Subscription. |
| [Well Marked](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/0b7d187d-f44f-42f1-ba55-2accd5f27540) | You owned five Bookmarks at once. |
| [Buyer’s Remorse](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/e118eab3-7c9b-4a53-a05c-30478289928d) | You earned Buyer’s Remorse. |
| [Against the Grain](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/d14c7128-eed3-4aef-b244-180f231624f6) | You finished a Book on Obstacle III. |
| [Down to the Wire](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/aa93deae-f009-4b1b-a87f-00b1a0a6cb19) | You finished a Puzzle on its last Turn. |
| [Editorial Control](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/2234dcdf-2de0-465f-adb7-66f53eab1ab4) | You took both skips in one Book. |
| [One More Page](https://appstoreconnect.apple.com/apps/6808968186/distribution/gamecenter/achievements/c08f4cc4-fbf4-489c-8102-a12edbafbff4) | You kept filling until you Full Cleared a Puzzle. |

## Existing images and upload suitability

No dedicated per-achievement or per-leaderboard raster set exists. The local
achievement page uses the runtime SF Symbols `seal` / `checkmark.seal.fill`,
not uploadable image assets (`AchievementsPageView.swift:73`).

Apple currently specifies JPEG/PNG, **1024 × 1024**, **at least 72 ppi**, RGB for
achievement images; leaderboard images use the same format but are optional.
[Achievement image specification](https://developer.apple.com/help/app-store-connect/reference/game-center/achievements),
[leaderboard image specification](https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards).

The following existing files were checked with `sips`; all are PNG, RGB,
1024 × 1024 at 72 ppi:

| Existing file | Alpha channel | Suitability / limitation |
| --- | --- | --- |
| `App/Assets.xcassets/AppIcon.appiconset/icon.png` | No | Owner-authorized temporary shared artwork, uploaded unchanged to all 19 achievement drafts. Correct metadata; not bespoke achievement art. |
| `Artwork/app-icon-light.png` | Yes | Original icon source; prefer the already-opaque app icon above if using this design. |
| `Artwork/studio-mark-1024.png` | Yes | Correct dimensions but archived studio branding, not a specific achievement. |
| `Artwork/studio-mark-mono-on-light-1024.png` | Yes | Same archived-brand limitation. |

`Artwork/studio-mark-512.png` is only 512 × 512 and the horizontal logo is
2200 × 900: neither is ready for the current square image requirement. No
image was generated, resized or recolored. Only the existing app icon was
uploaded unchanged under the release owner's authorization. File-format suitability
is not confirmation of App Review approval or a substitute for choosing
appropriate achievement imagery.

## Remaining configuration gate

The three leaderboard and nineteen achievement drafts are complete. Approve
the final point allocation, earned text and temporary shared artwork (or replace
it with approved final art) before publication; include the components
in the appropriate Game Center/app release; then verify authenticated score
and achievement delivery. Keep offline/local behavior unchanged. Public App
Store submission has not occurred. See [release checklist](RELEASE-CHECKLIST.md).
