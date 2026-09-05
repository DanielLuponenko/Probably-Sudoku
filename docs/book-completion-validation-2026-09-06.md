# Book completion and independent obstacle progression

## Scope

- Five named major bosses are reserved for Level 9, Puzzle 3. Collector stays in the regular pool.
- The final earned win settles once and presents a dedicated congratulations leaf, not a Shop or another Cash Out choice.
- Completion is attributed to the actual Book and obstacle, never a global unlock counter.

## Implementation

The five final encounters are The Final Draft (target ×4), The Executive Editor
(a Bookmark sleeps each Turn), The Fine Print (no Buffs), The Budget Cut
(halved score multipliers), and The Shredder (three fouled squares each Turn).
Their saved IDs remain unchanged. Already-active legacy encounters are preserved;
undealt invalid final/regular pool choices are repaired before dealing.

`GameModel.showResults()` and live resume settle only a genuinely won final boss.
Frozen page snapshots do not settle on construction. Normal wins keep their
Cash Out/Keep Filling choices. Completed receipts now survive storage/relaunch
until Close Book acknowledges them; old paid final-board/Shop saves can reach
the same completion route without a second payout. Failures remain excluded.

The new paper congratulations leaf prints the actual partial final board rather
than inventing a solved Sudoku. It shows Book identity, defeated final boss,
9/9 levels and bosses, best score, and the next obstacle in this Book only.
Obstacle IX completion does not invent Obstacle X. Compact layouts fit a phone;
accessibility text sizes use a bounded scrolling fallback. Close Book uses the
selected obstacle's binding and returns to the completed volume on the shelf.
There is no second congratulations modal obscuring the closing animation.

Progress uses stable Book IDs through local saves, cloud profile merging, and
each rack cover's material/hit-test policy. Startup migration is saved locally
before cloud reception, then the merged profile is published, avoiding a
pre-merge overwrite of another device's completion facts.

## Verification

- All 207 Engine tests passed: `/tmp/numberclub-final-boss-recheck-full-engine.log`.
- App verification covers every Book's I→II progression, cloud/save round-trips,
  select/return/select rack materials, final-vs-ordinary routing, legacy/current
  completion receipts, visual OCR/bounds, accessibility scrolling, and page flips.
- The other 57 focused regression tests passed in
  `/tmp/numberclub-completion-verified.log`. The 10 victory rendering tests were
  rerun after correcting the accessibility heading and handwriting layout;
  final results are in `/tmp/numberclub-victory-final.log` and its `.xcresult`.
- Read-only board rendering is checked against an explicitly filled visual
  control. OCR Roman numeral ambiguity is limited to two human-verified
  contexts and paired with exact title checks for every obstacle.
- iPhone Release compile log: `/tmp/numberclub-completion-release-final.log`.
- Only the isolated `Probably Sudoku Onboarding QA` simulator is used. The
  paused full-book playtest simulator and all physical phones remain untouched.
- No production ads enabled; no commit, push, TestFlight upload, or device install.
