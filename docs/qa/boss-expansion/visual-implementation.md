# Boss presentation implementation

Status: source implementation complete; central test/render/native verification is recorded separately in `verification.md`.

## Authoritative state and lifecycle

All boss visuals read the committed puzzle state or an actual score operation. `GameModel.bossEntranceID` exists only for a newly begun encounter or an explicit QA boss change. Resumed and frozen models have no entrance ID. A model-owned, in-memory consumed-event ledger prevents replay when SwiftUI remounts an object or an overlay closes. No animation awards points, draws cards, advances turns, or saves a second gameplay action.

Entrances defer while the page curl covers the board, settle on cancellation/background, and are skipped by the saved in-game Reduced motion option. A new committed key is independent of an earlier key even if SwiftUI retains the same view instance. Ambient Fog is a local 30 Hz Canvas clock, gated by scene visibility, background motion, Reduced motion and Low Power Mode; it never drives the cells or engine.

## Current encounters

- Tik Tak: 32/36 pt monospaced `MM:SS`, reading the existing active-play clock; 60/30/10-second warning states, one brief pulse at 30/10 and VoiceOver threshold announcements while visible. No second timer or queued hidden warning.
- Fog: two soft drifting strata across the board, between recessed wells and crisp cell content. Its drawing receives no marker map, solution, selection or touch information. Hidden marker inspection and highlights retain their existing privacy guards. Results disperse the encounter atmosphere.
- The Garrys: existing authored clay bricks, individually staggered drops, short settling/dust, old blockers lifted before the new turn's bricks. Only actual engine-barred blanks are covered.
- The Shredder: actual saved foul squares keep a settled wet-ink pool; committed new fouls get one falling droplet and spreading impact. Overlapping two-turn entries retain their own saved lifetime. Initial entry waits for the page to reveal.
- Censor/Mirror/Budget Cut: the actual zero or final multiplier operation is shown as a crossed/stamped or cut score receipt. A preview does not replay Budget Cut's bank effect.
- Editor/Deadline/Erratum/Paywall/Fine Print: a removed-slot fold, cut turn-label margins, crossed Toss tab, Clue seal and exact Buff-slot seals occupy the existing controls. Disabled Buff details explain the actual boss restriction.
- Sleeping Bookmark: a folded corner and subdued paper on the exact sleeping copy; waking removes the fold. Passive-upgrade accessibility wording remains accurate. Collateral suspension stays a separate whole-puzzle status.
- Collector: only the engine's saved `suppressedInterest` is crossed to zero in the existing payout line. Base coins, other rewards, and total are unchanged; old receipts default to zero suppressed interest.
- Final Draft: a real first entrance briefly transforms the pre-multiplied target to the authoritative fourfold target. Saved/frozen targets display the final target directly.

## Expanded encounters

- Hand rail, bracket, packet and seal treatments retain crisp number glyphs and exact Hand-copy identities; each committed encounter entrance is consumed once.
- Bindery stitches the existing Bookmark row and moves a small needle only along actual owned Bookmark receipt sources. The engine remains the authority on forward/reverse order and pinned inventory.
- Back Page flips only its actual scoring ticket; Chain Stitcher threads its halving receipt; Word Count marks its actual deduction with a measuring edge; Orphan Line tears the actual debit; Serial Publisher shows actual settlement and saved carry; Rival Column underlines the fee-adjusted score. No board or whole-screen flips.
- Dry Press shows a tiny inked/dry pad, and Review Board marks saved Row/Column/Box approvals inside the existing boss header allocation.
- Royalty Contract tucks the exact committed target increase into the target number. Publicist's exact-copy paid stamp now also has an accessible paid status; other effects remain active.

## Focused evidence prepared

`BossPhysicalPresentationTests` covers timer formatting/thresholds and compact OCR, Fog drift/static gates and hidden-map pixel invariance, real foul overlap/expiry, impact poses, real scoring receipts, saved ink-pad/approval states, event-ledger idempotence, exact saved interest, unchanged restored targets, and unchanged control allocations. `BossBoardVisualTests` checks crisp numeral ink under Fog and all boss identity symbols. The gallery capture fixture now enumerates all 39 bosses; its shared-loadout comparison images are not a claim of valid new-boss eligibility. Root owns separate valid gameplay captures.

No Simulator interaction or build was performed by this presentation implementation pass. Native timings, touch behavior and performance must be judged from the central candidate and captured evidence.
