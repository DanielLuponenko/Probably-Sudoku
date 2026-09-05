# Item action coverage

All 46 purchasable item definitions are explicitly enumerated in
`CatalogActionIntegrationTests.swift`. Set-equality assertions fail when the
catalog adds or removes an item without updating its action expectation.
`CatalogEffectCoverageTests.swift` additionally checks each raw effect hook;
the action matrix catches integration mistakes that a correct hook can hide.

The method labels below refer to these exact `CatalogActionIntegrationTests` methods:

- **Buff**: `testEveryBuffIsConsumedAndItsEffectReachesSavedGameplayState`
- **Marker**: `testEveryMarkerChangesOnlyItsOwnedSquareThroughRealActions`
- **Turn**: `testPlacementAndTurnBookmarkMatrix`
- **Clear / Standing**: `testClearAndStandingBookmarkMatrixCoversTheRestOfTheCatalog`

## Buffs — 11

Every Buff case uses `Game.useBuff`, checks consumption, saves/restores, and
checks conservation. Conditional rejection and activation lifetimes have the
separate regressions listed below.

| Name | Case in Buff method | Saved gameplay effect |
| --- | --- | --- |
| Peek | `bf_peek` | +1 Clue |
| Redraw | `bf_redraw` | Fresh hand, pool RNG advances, no Toss spent |
| Overtime | `bf_overtime` | +2 maximum Turns |
| Double Down | `bf_double_down` | Next-placement flag armed |
| Insurance | `bf_insurance` | Next-wrong-placement flag armed |
| Second Print | `bf_second_print` | Next-clear flag armed |
| Lucky Dip | `bf_lucky_dip` | Hand gains 2 numbers |
| Bird Seed | `bf_bird_seed` | Current-Level activation saved |
| Fresh Ink | `bf_fresh_ink` | Puzzle multiplier gains 2 |
| Litmus | `bf_litmus` | Destination-reveal flag armed |
| Paper Crane | `bf_paper_crane` | Chosen number's +50 survives save and actual placement |

## Markers — 12

Every Marker case performs its actual qualifying placement. A second branch
owns that same Marker on another square and compares its entire placement
outcome, coin balance, hand, and item state against the unmarked baseline.

| Name | Case in Marker method | Owned-square effect |
| --- | --- | --- |
| Crimson Marker | `mk_crimson` | Placement points ×4 |
| Golden Marker | `mk_golden` | Placement points +100 |
| Azure Marker | `mk_azure` | Live coins +1 |
| Ivory Marker | `mk_ivory` | Wrong-placement penalty 0 |
| Emerald Marker | `mk_emerald` | Completed units' points ×2 |
| Onyx Marker | `mk_onyx` | Clue placement regains base points |
| Silver Marker | `mk_silver` | +20 per copy already on the board |
| Sapphire Marker | `mk_sapphire` | Draw 1 after placement |
| Rose Marker | `mk_rose` | Persistent Puzzle multiplier state +1 |
| Copper Marker | `mk_copper` | Live coins +3 per completed unit |
| Violet Marker | `mk_violet` | Placement base becomes 90 |
| Jade Marker | `mk_jade` | Wrong number returns to hand |

## Bookmarks — 23

Turn cases check queued placement points, held multiplier, save/restore, and
the actual banked score. Clear cases resolve a real completing placement.
Standing cases deal a new Puzzle, pay out a win, or perform an actual reroll.

| Name | Method / case | Effect checked |
| --- | --- | --- |
| Morning Edition | Turn / `bm_morning_edition` | +100 at Turn end |
| Evening Edition | Turn / `bm_evening_edition` | +300 at Turn 10 end |
| Local Gossip | Turn / `bm_local_gossip` | +30 placement flat |
| Sports Section | Clear / `bm_sports_section` | Clear points 45 +25 |
| Society Pages | Clear / `bm_society_pages` | Full-clear points 500 +500 |
| Op-Ed Column | Turn / `bm_op_ed` | Held multiplier ×2 |
| Editorial Board | Turn / `bm_editorial_board` | Held multiplier ×3 |
| Front Page Splash | Turn / `bm_front_page_splash` | Counts itself, held multiplier ×2 |
| Letters to the Editor | Turn / `bm_letters_to_the_editor` | Inactive normally; Boss ×4 also banked in conditional action test |
| Rolling Presses | Turn / `bm_rolling_presses` | Real multiple clears grow multiplier; new Puzzle resets it |
| Syndication | Turn / `bm_syndication` | Actual wins grow multiplier; save/new Puzzle retain it, new Book resets it |
| Stop the Presses | Turn / `bm_stop_the_presses` | Held multiplier ×3 |
| The Sunday Supplement | Turn / `bm_the_sunday_supplement` | Normal ×2 and Boss ×3 banked in conditional action test |
| Extra! Extra! | Clear / `bm_extra_extra` | Clears ×3 without multiplying placements |
| Finance Pages | Clear / `bm_finance_pages` | Live coins +1 per clear |
| Paper Route | Standing / `bm_paper_route` | Actual win payout +2 |
| Market Wrap | Standing / `bm_market_wrap` | Actual interest capped at 15 |
| Auction Notices | Standing / `bm_auction_notices` | Free first reroll, next costs 2 |
| Help Wanted | Standing / `bm_help_wanted` | Newly dealt hand +1 |
| Weather Forecast | Standing / `bm_weather_forecast` | New Puzzle Toss allowance +2 |
| Puzzle Corner | Standing / `bm_puzzle_corner` | New Puzzle Clues +1 |
| Late City Final | Standing / `bm_late_city_final` | New Puzzle maximum Turns +1 |
| Crossword Daily | Clear / `bm_crossword_daily` | Draw 1 per completed unit |

## Focused regression scenarios

Additional `CatalogActionIntegrationTests` methods cover conditional positive paths:

- `testBossConditionalBookmarksReachTheActualTurnBank`
- `testRollingPressesGrowsFromRealClearsAndResetsForANewPuzzle`
- `testSyndicationGrowsFromActualWinsAndResetsOnlyForANewBook`

`ShopAndItemRegressionTests` checks:

- Marker stock uniqueness at every Level, across 30 seeds and 4 stock rolls;
  owned Markers still eligible in later stock.
- Accountant correct/wrong debit before bank, negative balance, save before
  bank, no double debit, rejected actions, and netting against Azure coins.
- Bird Seed after consumption and save, across easy/medium/Boss puzzles,
  expiry next Level, held duplicates, and no-effect repeat activation.
- Buff rejection without state mutation in terminal phases, missing Paper
  Crane selection, Paywall Peek, already-armed one-shots, and empty-pool Lucky Dip.
  All 11 Buffs are also checked in Keep Filling: score/protection-only copies
  stay held, while coin, draw, Turn, and destination-reveal effects remain usable.
- Extra! Extra! placement/clear separation, unrelated placements before and
  after, save/restore, additive and multiplicative held bonuses, Full Clear,
  Society Pages, Emerald Marker, and Second Print composition.
- Keep Filling wrong-placement score freeze, preserved Insurance and book
  protection, Jade/Ivory interactions, Accountant cost, conservation, and cash-out.

Existing `RulesTests`, `ScoringTests`, `BossModifierTests`, `BookSidegradeTests`,
and `HandClueTests` cover one-shot consumption, multiple simultaneous clears,
boss suppression, book benefits, and the paid hand-targeted Clue flow.
