# Achievement expansion — next release

Status: implemented locally; **not uploaded and not registered with Apple**.
The local catalog now contains 31 achievements: 19 existing awards plus the
12 below. Existing earned IDs, profile decoding and iCloud union are preserved.
No new counters or save schema are required.

## New metadata inventory

Game Center IDs are reserved by the code's existing namespace, but they must
not be sent to Apple until corresponding achievement records are configured.

| Local ID | Proposed Game Center ID | Title | Description |
| --- | --- | --- | --- |
| `first-correct-placement` | `com.numberclub.app.achievement.first_correct_placement` | Ink Happens | Place a correct number in a Puzzle. |
| `first-line-clear` | `com.numberclub.app.achievement.first_line_clear` | One Good Line | Complete a row, column, or box. |
| `first-boss` | `com.numberclub.app.achievement.first_boss` | Management Meeting | Beat your first Boss. |
| `finish-three-books` | `com.numberclub.app.achievement.finish_three_books` | Shelf Improvement | Finish three different Books. |
| `double-clear` | `com.numberclub.app.achievement.double_clear` | Two for One | Complete at least two of a row, column, and box with one placement. |
| `half-million` | `com.numberclub.app.achievement.half_million` | A Bit Excessive | Bank 500,000 points in one Puzzle. |
| `double-target` | `com.numberclub.app.achievement.double_target` | Overqualified | Bank at least twice the target score in one Puzzle. |
| `five-turns-spare` | `com.numberclub.app.achievement.five_turns_spare` | Ahead of Schedule | Finish a Puzzle with at least five Turns remaining. |
| `buy-marker` | `com.numberclub.app.achievement.buy_marker` | Colour Commitment | Buy a Marker with coins in the Shop. |
| `use-buff` | `com.numberclub.app.achievement.use_buff` | Helpful Footnote | Use a Buff that takes effect. |
| `no-outside-help` | `com.numberclub.app.achievement.no_outside_help` | No Outside Help | Finish a Puzzle without a wrong placement, Clue, or Toss. |
| `obstacle-nine-book` | `com.numberclub.app.achievement.obstacle_nine_book` | Glutton for Punishment | Finish a Book on Obstacle IX. |

## Paperwork correction

- Preserve local ID `buy-subscription` and existing Game Center ID
  `com.numberclub.app.achievement.buy_subscription` so previously earned awards survive.
- Keep title **Paperwork**.
- Replace **Buy a Subscription.** with **Buy a Bookmark with coins in the Shop.**
- Eligibility is now a successful coin purchase of a Bookmark. The old
  Subscription item kind describes legacy run-scoped coin upgrades; the live
  Shop does not stock them. The game does not sell paid subscriptions.
- The local wording is corrected. Apple's existing localization still needs
  the corresponding update during preparation of the next release.

## Apple registration follow-up

1. Create the 12 Game Center records with their exact IDs, localized metadata,
   point values and artwork for the next release.
2. Update Paperwork's existing localization without replacing its identity.
3. Only after registration, add the new local IDs to
   `AchievementCatalog.registeredGameCenterLocalIDs`. Historical backfill will
   then mirror already-earned local awards on authentication.
4. Verify registered receipt delivery before including that configuration in a
   submitted release. Do not alter build 9's existing review submission.

Until then the new awards are available in-game and survive normal profile/
iCloud merging. Game Center delivery filters them out of both live and historical
batches. Unfamiliar old queue entries are preserved but never sent alongside
Apple's registered awards.

## Eligibility safeguards

- Placement awards use real successful engine outcomes; previews and tutorial
  practice cannot earn them.
- Resumed games can earn facts proven by the current engine state (score,
  current placement, Boss victory). Unknown earlier action history does not
  grant flawless, no-Clue or No Outside Help awards.
- Finishing on the last Turn leaves **zero** remaining after the engine banks
  and advances its Turn counter. Down to the Wire now uses that actual boundary;
  one remaining is a penultimate-Turn win, and five remaining qualifies for
  Ahead of Schedule.
- Different Books are counted by known volume identity, not repeat obstacles
  or unknown future IDs. Boss encounters retain existing idempotent identities.

Focused proof lives in `AchievementExpansionTests`, `AchievementRegistrationTests`,
`GameCenterIDMigrationTests`, `GameCenterServiceTests` and `ShopSaleAchievementTests`.
