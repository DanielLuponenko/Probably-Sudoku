# Live score and anchored sort menu — 19 September 2026

The hand has one Arrange hand button. Its compact ivory menu opens above that button, offers Ascending, Descending and Shuffle hand, then closes on selection or dismissal. It does not dim or move the board. Outside taps are consumed by dismissal. Opening and closing the menu preserves selected card identity and Clue/Peek targeting.

The production HUD now displays Points × Mult = +turn subtotal using one coherent engine ledger. Placement and modifier changes appear immediately while attribution receipts play. Banking retains its captured subtotal until the bank beat, then resets it; direct end-turn bonuses remain separate receipts. Keep Filling displays “Score frozen.” Engine scoring and save formats are unchanged.

## Verification

- 54 focused tests passed, including score presentation, production HUD rendering, hand arrangement, Clue presentation and fixed gameplay geometry. `/tmp/nc-live-menu-test1.log`.
- After the native accessibility correction, the final build and all 16 hand arrangement tests passed. `/tmp/nc-live-menu-test2.log`.
- An independent native iPhone 17 Pro review verified the compact menu, separate accessible choices, duplicate UUID preservation and outside-tap consumption. A first board tap only closed the menu; a second tap placed 2 once and displayed `20 × 1 = +20`. See `native-review.md`.
- Root then pressed End Turn: score became 20, the live subtotal reset to `0 × 1 = +0`, and Turn 2 began. Screenshot: `17pro-after-bank.png`.
- Native iPhone SE verification confirmed the anchored menu fits, Descending sorts and closes it, and all background gameplay accessibility actions disappear while the menu is open. The explicit accessibility modal trait corrected a background-control exposure found during this check. Screenshot: `se-descending-final.png`.
- Normal, fractional, score-cap and historical extreme values were rendered and checked without resizing the board or overlapping the receipt. Representative renders: `hud-live-formula.png`, `hud-score-limit.png`.

The final app `/tmp/NumberClub-live-menu-build2.app` is installed and open on the user's iPhone 17 Pro simulator. Application Support files matched the fresh pre-install backup exactly before launch: `/tmp/NumberClub-live-menu-user-backup-20260919-final`.
