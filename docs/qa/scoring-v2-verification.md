# Ordered scoring verification — 19 September 2026

The implementation contract is [scoring-v2.md](../scoring-v2.md). Detailed activation evidence comes from the linked Steamodded integration documentation/source; the Turn batch, Sudoku event mapping, wrong-placement penalty and retained direct payouts are explicit adaptation decisions. This report covers engine arithmetic and presentation projections. The main gameplay QA report records Simulator play and visual checks separately.

## Independent arithmetic

`OrderedScoringTests` uses expected constants and fixed order, rather than calculating expected values through the production resolver. `IndependentOrderedScoringTests` was written by a different agent using separate Latin-board fixtures and expected arithmetic.

| Case | Expected result |
|---|---|
| 50 Points; Op-Ed +1, then Stop the Presses ×3 | `50 × ((1 + 1) × 3) = 300` |
| Same items reversed | `50 × ((1 × 3) + 1) = 200` |
| 45 Points at Mult 1.5, plus Morning/Evening payouts | `floor(45 × 1.5) + 100 + 300 = 467` |
| Two 45-Point events at Mult 1.5 | Bank once: `floor(90 × 1.5) = 135` |
| Ink/Rose seed, ordered Bookmarks and Sashimi | Seed operations occur first; Sashimi halves the final Mult exactly once |
| Independent local Points/ordered Mult fixture | 1,040 local Points, 6,240 banked; coins are not multiplied |
| Simultaneous row/column/box and full-board fixture | Independent 9,520 banked result; a doubler does not duplicate hooks |

The suites also cover duplicate item UUIDs, locked order through reorder/sale/save-resume, disabled duplicate identity, growth timing, pure preview, no RNG movement, clues/Onyx, Censor/Mirror, penalty absorption and Insurance, Keep Filling/cash-out exactly once, finite saturation, historical scores above the new ceiling, and old pending Turns retaining version-1 arithmetic until banked.

## Findings repaired during the independent review

- A last held card with zero Points could fail a full board before automatic End Turn and prevent a printed direct payout. Win/failure resolution now follows bank; independent final Clue and Censor cases award Morning Edition once.
- A legal finite saved Paper Crane modifier such as `1e20` could trap during conversion to `Int`. The value is bounded before conversion; the independent regression asserts the exact ceiling and encodable ledger.
- Bird Seed's consumed UUID was present in memory but missing from the explicit Run encoder. The independent save-resume test reproduced the provenance loss. The encoder now persists it across Puzzles within the Level.
- The committed engine correctly reset the queue while the banking animation still displayed multiplier beats, causing the HUD to show `0 × 1` during them. Presentation now carries the original queue and each engine-ledger Mult snapshot; the app regression asserts `1 → 2 → 6 → 1`, with the last reset occurring at BANKED. The engine state remains committed throughout.
- The old presentation put printed direct payouts before one combined BANKED stamp. It now projects the engine order unchanged: modifier operations, the actual Points × Mult bank, then each direct payout. Each score beat carries its own saved `after.score`, including the final snapshot used with Reduce Motion.

The first two findings were established by source inspection and subsequently verified by regressions; no pre-fix failing execution is claimed. The Bird Seed failure is retained in `/tmp/nc-scoring-v2-engine-final.log` (289 tests, one failure) and the independent review log. Those logs are local diagnostics, not repository artifacts.

## Gates

- Earlier full engine gate: 279 tests passed in `/tmp/nc-scoring-v2-engine-full.log`.
- All 10 independent engine tests passed after the persistence repair in `/tmp/nc-independent-scoring-final.log`; the original failed provenance test remains in `/tmp/nc-independent-scoring-bird-seed-failure.log`.
- A subsequent 289-test gate passed gameplay assertions but compiled before Crimson's copy change, while reading the updated reference document; its one stale-reference failure is in `/tmp/nc-scoring-v2-engine-verified.log`. Both source and reference now say “Placement Points ×4.”
- Final full engine gate with the synchronized catalogue: **289 tests, zero failures**, completed at 01:37:02 in 120.82 seconds. Log: `/tmp/nc-scoring-v2-engine-final-green.log`. This includes catalogue/reference checks, all new arithmetic/provenance regressions, inventory reorder, skip/legacy save protections and the 18-scenario balance probe.
- New app projection sources passed Swift syntax parsing. App build, XCTest and Simulator results are reported by the root QA workstream, not inferred from an engine pass.

## Economy and target limits

[The 18-scenario deterministic probe](scoring-v2-balance.md) covers ordinary/boss targets in Chapters 1, 5 and 9 with no Bookmarks, a two-item ordered build, and a five-slot scaling build. It preserves card conservation and verifies unchanged coins in each case. It deliberately uses an oversized full-board hand and disables boss restrictions to isolate the formula; it is an upper-bound arithmetic probe, not a human playthrough or an acquisition/win-rate simulation.

Late targets cannot be reached by the unmodified or simple two-item upper bounds, while ideal scaling builds greatly exceed them. Correctly ordered pure Bookmark modifiers generally retain the prior best-order ceiling; moving persistent Ink/Rose +Mult before multipliers makes those combinations stronger by design. No coin source, price, target or acquisition probability was changed on this evidence alone. Normal-run difficulty still needs the separately requested Simulator playtests.
