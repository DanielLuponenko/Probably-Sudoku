# Flow and Clue actual Simulator playtest

Date: 2026-09-19. Tester: route_clue_scope. Device: SE-test, iOS 26.3, simulator `60D48736-12BA-4D48-ADCB-DC2DBB834730`. Started with build8, installed build12 only at an agreed safe point after the first Peek placement. All player interactions used the actual app through Simulator accessibility/touch controls. Normal runs were launched without debug arguments; QA menu controls only arranged item/boss/target setups. No save files were edited.

Simulator ownership returned to the parent after the final replacement check. Current app is build12, normal seed `6C4C3`, Level 1 boss briefing, 16 coins, Puzzle Corner, held Peek and Paper Crane. The original SE app container was backed up before installation at `/tmp/nc-clue-qa-original-20260919-013540`. Other booted simulators were shut down only to isolate accessibility routing; their data was not changed.

## Results

| Actual interaction | Observed result | Evidence |
| --- | --- | --- |
| Normal Play → shelf → Open with an unfinished run | Custom Resume/Start new choice. Resume kept the existing active puzzle rather than creating a new run. Entire saved JSON unchanged. | `flow-snapshots/01-before-resume.json`; `se-resume-settings.png` |
| Explicit normal Start new, build8 | New run opened at briefing with Insurance name/effect and visible Skip + Buff. Found first-briefing persistence defect: there was no run.json before an action. Parent fixed it. | `se-fresh-skip-briefing.png` |
| Build12 fresh start, no action, quit and normal Resume | Seed `6C4C3`, Lucky Dip offer, slot 0, no puzzle dealt and empty history persisted immediately. Resume showed the same offer. Entire saved JSON equal. | `flow-snapshots/07-initial-briefing-before-any-action.json`, `08-initial-briefing-after-resume.json`; `se-initial-briefing-build12.png` |
| Insurance skip rapid repeated activation | Exactly one skip and one Insurance copy, coins still 5, next ordinary slot. | `flow-snapshots/02-first-skip.json` |
| Next offer after overlay and quit/Resume | Bird Seed offer and Insurance inventory survived. Accepting Bird Seed advanced to mandatory boss with exactly two held Buffs/history entries, coins still 5. No boss skip action. | `flow-snapshots/03-boss-after-two-skips.json`; `se-mandatory-boss.png` |
| QA Peek → actual inventory panel → Choose number after preselecting 1 | Panel closed, old card selection cleared, pending instruction appeared and hand accepted touches. Peek stayed held while armed and saved JSON was unchanged. | `flow-snapshots/04-before-peek.json`; `se-peek-armed.png` |
| Armed Peek cancelled using top control, Run information overlay, and Home/background | Each cancelled targeting and retained the same Peek copy. Returning from Home showed normal unarmed gameplay. | Actual AX observations; snapshot 04 is original state |
| Re-arm Peek → specifically select second duplicate 8 | R1C2 highlighted and row/column instruction shown. Peek consumed once; zero charges, hand unchanged. Selected 3 then second 8 again: paid destination restored at zero charges. | `flow-snapshots/05-peek-revealed.json`; `se-peek-revealed.png` |
| Explicit placement at R1C2 | Only selected second-8 UUID disappeared; first-8 UUID stayed. Hand `[1,3,8,5,4]`, clue provenance, queued base 0. | `flow-snapshots/06-peek-placed.json`; `se-peek-placed.png` |
| QA Puzzle Corner before starting a puzzle | Top lightbulb/count resource appeared with 1 charge, without occupying a Buff slot or bottom action. | Later source use below; actual AX observations |
| QA Paywall → inventory Peek → Choose number | Visible “The Paywall has disabled Clues”; panel remained open, exact Peek UUID retained, no reveal. | `flow-snapshots/09-paywall-peek-retained.json`; `se-paywall-peek.png` |
| QA The Fine Print (`buffborger`) → Peek → Choose number | Visible “This Boss has disabled Buffs”; exact Peek copy retained. Inventory displayed unavailable state. | Actual AX observations; retained copy in snapshot 10 |
| Under The Fine Print, select 5 then top Puzzle Corner Clue → select 5 again | Old selection cleared on arming. Explicit second selection revealed R1C8; charge reduced 1→0, Peek retained. | `flow-snapshots/10-puzzle-corner-reveal-buffborger.json`; `se-puzzle-corner-reveal.png` |
| Quit with paid R1C8 reveal, normal Resume → select 5 | Same card UUID and paid destination restored with zero charges. Explicit placement succeeded without consuming Peek. | Actual AX observations; later saved board and Results screenshot |
| QA Meet target → actual Results → Cash Out → Shop | Results showed actual played clue 5 and remaining blanks; fullscreen paper and consistent inventory. Cash Out paid once, 5→20 coins. Shop retained inventory. | `se-results-clue-board.png` |
| Shop buy Overtime → Continue | 20→16 coins, second slot held Overtime, next ordinary briefing offered Paper Crane and its effect. | `flow-snapshots/11-full-inventory-before-skip.json` |
| Full inventory Skip → Cancel | Slot, both item UUIDs, coins and every other saved field unchanged. | Snapshots 11 and `12-full-inventory-after-cancel.json` are JSON-equal |
| Full inventory Skip → quit while choice pending → normal Resume | Same Paper Crane offer; original Peek/Overtime retained, no progression or history. Entire saved JSON equal to pre-decision. | `flow-snapshots/13-full-inventory-after-pending-relaunch.json`; `se-full-inventory-skip.png` |
| Repeat Skip → replace Overtime in slot 2 | Kept exact Peek UUID, replaced exact Overtime UUID with offered Paper Crane UUID, capacity remained 2, 16 coins unchanged, progressed one ordinary puzzle to boss, one history entry. | `flow-snapshots/14-full-inventory-replacement-committed.json`; `se-full-inventory-replacement-committed.png` |

## Defects found and resolved during this pass

- **First briefing was not saved until an action.** Confirmed in build8 normal Start new flow; parent added the explicit startingBook persistence factory. Actual untouched save/relaunch/Resume regression passed in build12 with equal JSON snapshots 07/08.
- **Run information still exposed exact hidden Pool counts.** Reported during overlay check; parent removed that tally for design consistency. No Pool/conservation logic was changed. The visible hand Pool badge is absent in all gameplay screenshots. Exact Run information removal was code/build-confirmed by parent; it was not separately reopened after build12 in this pass.

## Scope boundaries

- Native QA lists are test-only setup tools. Normal Settings, Buff, replacement, Book replacement and Shop item panels exercised here are custom paper UI.
- The Results board is substantially larger and uses gameplay styling. On SE its initial viewport shows only the upper part because the page content is scrollable above pinned decisions. This pass checked actual clue provenance/blanks and no old book frame; it did not separately touch-scroll the Results page to inspect the lower rows.
- A first rapid AX skip activation caused a transient scrolled header. Later direct-coordinate skip preserved layout. This was not reproduced as an app defect; AX may scroll an element into view before activation.
- Before-reveal cancellation was proven via explicit cancel, unrelated overlay and Home/background. **Process kill while Peek is armed was not separately performed.** Paid-reveal process restart and pending-skip replacement process restart were performed.
- Handy Dandy, Fog, no-legal-target edge cases, all-chapter repeated skips, duplicate Buff copies, curved trash gestures and every catalogue effect were not claimed as actual touch passes here. Model/engine tests and other agents own those checks. The repeated 8 test proves duplicate **hand-card** identity, not duplicate Buff identity.
- Target completion used QA “Meet the target”; the resulting payout, Shop purchase, Continue, skip and replacement used real player controls. This is not an independent proof of scoring arithmetic.
