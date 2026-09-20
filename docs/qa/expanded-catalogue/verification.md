# Expanded catalogue verification

Source: the supplied local catalogue at `http://127.0.0.1:62593/`, archived unchanged in `docs/catalogue/2026-09-20/`. Runtime contains 50 Bookmarks, 50 Markers and 40 Buffs, with item-specific prices, rarity, supplied illustrations and rules.

## Engine

`swift test --package-path Engine` passed **411 tests, zero failures** in `/tmp/nc-expanded-catalogue-tests-8.log`.

Coverage includes catalogue metadata, ordered scoring, eligibility and per-Turn/Puzzle/Book limits, all new effect families, separate duplicate identities, deterministic independent item randomness, finite Pool conservation, saved pending choices, cancel/commit/replay behavior, legacy saves and skip offers, Shop pricing and discounts, inventory capacity changes, and ordinary/Boss progression.

Final audit fixes include exact-copy draw and coin receipts; Forecast expiry after actual draws; Clean Finish eligibility; atomic Shop departure; Pocket Insert removal after explicit capacity resolution; delayed Shop/inventory/navigation callbacks blocked while saved choices exist; and Auction Notices pricing when ownership changes during a visit.

## iOS verification

The broad iOS regression run and focused correction gates now pass all **815 current Debug app tests**. The audit records the latest result for every current test method; three tests compiled only in the separate ad-free configuration are excluded. Test audit: `/tmp/nc-expanded-final-test-audit.json`. The final inventory status gate passed 15 tests with zero failures.

The gates cover long-copy layouts, all 140 compact Shop cards, all 40 skip offers and accessible details, saved/cancelled choices, 24 tutorial cases, Fog privacy, exact-copy sales and receipts, and stationary pinned decision controls. The final plain simulator build passed after these changes.

The supplied illustration contact sheet and two-/three-Buff inventory render checks cover all 140 item images at 320, 375 and 402-point widths. Saved digit, square and long-choice panels are rendered on small/typical phones and at AX5, checking readable scroll content, pinned confirmation and unchanged game bytes.

## Independent native playtest

See [Marker verification](marker-verification.md) for the isolated iPhone 17 Pro playtest, including screenshots. Actual inputs exercised Fork's saved choice, Pledge acceptance/decline, Exchange's separate duplicate cards, and Rebind cancellation/relocation/scoring. The native QA fixtures intentionally do not persist; save/resume and repeated commits are verified by engine and app state tests.

The playtest identified an ambiguous second selection step for Rebind. Rebind, Transposition and Fair Exchange now show a concise source/destination instruction instead of repeating the same rule paragraph.

The root agent also completed the full native replay tutorial: bought Local Gossip, Front Page Splash, Golden Marker and Fresh Ink at their catalogue prices; reached 310 × 3 = 930, then 310 × 5 = 1,550; sold Local Gossip for 2 and Overtime for 3; banked 1,550 and collected the 14-coin payout; finished all 15 practice actions and returned to Settings. Paper Crane showed all nine selectable digits, and cancelling after selecting 3 preserved the Buff, all Hand identities, coins and Turn. Screenshots are stored beside this report.

A final native Shop visit bought Type Case and Collateral at their real prices, resolved Type Case’s opening digit choice, and committed Collateral against that exact owned Bookmark. The Buff was consumed and the item remained owned. The resulting visual audit added a dimmed/crossed-out state and “Suspended for this Puzzle” accessibility description; cancellation and exact-instance rendering pass a focused regression test.

The final independent review also found and fixed hidden Marker names in Fog choice headings, missing sale-achievement receipts for the combined Pocket Insert sale, and the incorrect Recycled Insert reopen label.

## Compatibility and interpretation

Old earned Clippings and old skip reward tables remain intact. New Books use the expanded deterministic reward catalogue. Source files and the pre-change source backup remain available.

The source's Finale description conflicts with its short description/limit. Runtime follows the full effect: +800 for each of up to two distinct completed digits, maximum +1,600. See [interpretation notes](../../catalogue/2026-09-20/implementation-decisions.md).
