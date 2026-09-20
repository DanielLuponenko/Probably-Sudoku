# Independent gameplay review

Independent reviewer: separate agent from the implementation authors. Reviewed the full gameplay brief, current source, focused regression tests, and exercised the installed app on the SE-test simulator using CUA. This report distinguishes direct interaction from automated coverage.

## Findings raised during review

1. Accountant's new top-bar fee label remained indefinitely because `lastCoinCharge` is retained by the model. The original timed receipt had been replaced by plain text. Fixed with a shared timed receipt and scoped expiry. In the final build, an actual placement charged five coins down to four and the stale fee label was absent after six seconds. Tool latency prevented independently capturing the brief initial label; its duration and expiry identity also have focused automated regression coverage. Evidence: `independent-se-accountant-expired-final.png`.
2. On compact briefing, the offer effect could be below the scroll viewport while the coupon header was tappable. Fixed with acceptance only through a dedicated CTA after the effect. Final runtime verification: header tap was inert, scrolling exposed the effect and footer, cancellation preserved the same offer and inventory, and double-clicking a replacement committed once. Before-fix evidence: `independent-se-clipped-offer-before-fix.png`; final panel: `independent-se-custom-skip-final.png`.
3. Litmus matches and mismatches used color alone. Fixed with visible dark check/cross symbols in addition to accessible values. In the final build, both symbols were clear at SE size, and tapping a checked square placed the selected two, consumed the intended card, and cleared the armed effect. Before-fix evidence: `independent-se-litmus-before-fix.png`; final evidence: `independent-se-litmus-final.png`.

No additional actionable correctness defect found in the reviewed skip transaction, legacy-save decoding, Buff instance identity, hand identity reconciliation, RNG separation, exact cell/card geometry, Fog guards, or stable capture host.

## Direct interaction verified

- Opened arrangement menu and used Ascending, Descending, and Random. The selected card retained its UUID through sorting.
- Selected the second of two fives after sorting. Toss removed that exact UUID (`056AD996…`), preserved the other five (`DD9E74C7…`), reduced the Toss budget from four to three, and kept the same turn.
- Activated Clue, selected the retained five, observed an empty destination at row 2, column 8, and verified the card remained in hand until the destination was tapped. Clues decreased from two to one; the resulting clue five scored zero and consumed the intended card. Evidence: `independent-se-sorted-clue.png`.
- Random arrangement remained unchanged after Help, marker inspection, and return. Covered gameplay controls were absent from the accessibility tree.
- Opened Fresh Ink from a full inventory, cancelled without consuming it, reopened and used it. Its inventory slot emptied; multiplier increased by two and remained armed across End Turn.
- End Turn banked queued score, retained surviving hand IDs, appended new cards, and applied a new Gray the Garry restricted row. Board placement remained stable; existing digits were not covered.
- Full-inventory skip cancellation preserved the ordinary puzzle, Peek, and Fresh Ink. Explicitly replacing Fresh Ink awarded Litmus, preserved Peek, advanced one puzzle, and kept the coin balance at five. Evidence: `independent-se-skip-replaced.png`.
- Terminated/relaunched the persisted test run, then traversed the normal shelf, Book selection, and opening. Resumed at the second ordinary puzzle with Peek and Litmus and the same Bird Seed offer.
- Replaced Peek with Bird Seed, advancing to the mandatory Tik Tak boss. No skip control remained. Run information recorded two skips and both rewards.
- Opened Tik Tak, observed its countdown, held Help open during review, and returned. About forty seconds elapsed during the review while the displayed countdown fell only six seconds across the before/open/close tool overhead.
- Consumed Litmus, selected two, inspected its accessible match/mismatch values and visible fills, then placed a matching two. The armed effect cleared after placement; the card was consumed and the queued score increased.
- In the persisted run, randomized the remaining six cards, recorded their ordered UUIDs, terminated/relaunched, and traversed the normal shelf/Book opening. The resumed ordered UUID array matched exactly; the played cell and remaining boss time persisted.
- Used the existing QA target staging action, then the real End Turn. The fullscreen puzzle transitioned into Book results and unlocked. Cash Out added the displayed fourteen-coin payout (five to nineteen) and entered the gameplay Shop.
- Continued from Shop into chapter two. Despite two previous skips, an ordinary-puzzle offer remained available. Accepted Second Print into the available slot: advanced round one to round two, retained Bird Seed, awarded one Second Print, and kept nineteen coins. The next Lucky Dip offer appeared. Evidence: `independent-se-third-skip-after-shop.png`.

## Environment note

The first simulator session had stale/incorrect coordinate routing and no iOS accessibility tree. No functional claim is based on those failed attempts. After the main agent restarted Simulator with only SE-test visible, full iOS accessibility returned and the verified interactions above used actual named controls.

The overflow fixture's CUA accessibility dump reported a truncated root container (`showing 0–111 of 124 items`). After scrolling the hand, some hand/action nodes were omitted from that dump even though the controls remained visible and worked. This is not classified as a confirmed application defect: no matching accessibility-hiding logic exists, arranging restored the visible card nodes, and the final-card selection and Toss were verified through the visible controls. The report does not claim a full VoiceOver traversal of every overflowing card.

## Final custom-panel and accessibility pass

The final installed panel build was tested independently after the implementation author's focused gate passed. The following were actual interactions on SE-test, not source-only assertions:

- Resumed the earlier persisted run at chapter two, round two with nineteen coins, Bird Seed, Second Print, and the same Lucky Dip offer. The ticket header was inert; scrolling exposed the offer effect and dedicated skip footer.
- Opened the custom replacement panel; underlying gameplay controls disappeared from its accessibility tree. Cancel restored the same puzzle, offer, and both Buffs. Reopened and double-clicked Replace Second Print. Only one Lucky Dip was awarded, Bird Seed remained, coins stayed nineteen, round two advanced to the mandatory Gray boss, and run history increased from three to four skips. No boss skip was offered.
- Settings → How to play → Topics displayed a third-level custom panel. Choosing Toss & End Turn updated the guide. Watch a turn displayed the movie above the guide. Closing successively recovered the guide, Settings, and the unchanged game.
- Opened the new hand arrangement panel and applied Ascending. Individual UUIDs were retained. Opened Lucky Dip's custom Buff panel and used it; one owned copy disappeared and new cards were drawn.
- Entered results and Cash Out, inspected the Golden Marker Shop offer in a custom panel, and bought it. The offer dismissed before the marker placement panel appeared. Tapping R1C1 placed the marker, returned to Shop, reduced coins from thirty-five to thirty, and marked the offer sold.
- With the twelve-card fixture, swiped the horizontal hand to its last card. Selected the final one, sorted Ascending, and verified that selected UUID `A5839875…` moved into view at the start. Toss removed that card only, reduced four Tosses to three, and retained turn one. The board did not shift. Evidence: `independent-se-overflow-sorted-final.png`.
- Enabled actual iOS Reduce Motion through Settings → Accessibility → Motion, confirming the switch value was one. Gray bricks displayed in their settled state. End Turn moved the restriction from row nine to the exact eligible blanks in row three; the visible blocks matched disabled cell labels. Help → Crimson Marker inspection → close retained the same restriction state and selected hand. Target staging followed by results and Cash Out reached an interactive Shop under Reduce Motion. Restored the original system setting to off, confirming value zero. Evidence: `independent-se-reduce-motion-final.png`.
- Handy Dandy had blocked eight UUID `CD393E6E…` and blocked four UUID `3CD1FBF9…`. Descending arrangement preserved those exact blocked copies. Selecting the blocked eight disabled Toss. Selecting the other eight UUID `E305DA05…` enabled Toss; Toss removed only the unblocked eight, retained the blocked copy, reduced the allowance from four to three, and kept turn one.

The three review findings are resolved in the final inspected build. No further confirmed gameplay or custom-panel defect remains from this independent review. Full all-chapter skip stress, historical-save compatibility, RNG separation, transaction races, and the large-device layout matrix remain separately recorded in the main agent's automated verification and screenshots; they are not claimed here as manually played end-to-end.
