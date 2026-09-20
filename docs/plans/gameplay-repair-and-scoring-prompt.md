# Gameplay repair and scoring implementation prompt

## Goal

Deliver a coherent, fully playable Probably Sudoku loop from Book opening through briefing, puzzle, results and Shop. Make skips discoverable, Clues reliable, inventory dragging freeform, and every in-run screen consistent with the approved fullscreen ivory/linen design. Implement Balatro's ordered scoring principles through an explicitly documented Sudoku adaptation. Finish only after automated regression checks and independent agents' actual QA-menu playtests pass, with reproducible evidence and no unresolved confirmed defect in this scope.

## Working context

Work in `/Users/daniel/NumberClub`. Preserve existing work, original artwork, rollback evidence, saved runs and earned rewards. Read applicable repository instructions. Do not restore the retired Club Shop. Preserve the Book shelf, selection and opening/closing experience; the in-run screens should fill the screen. Use custom paper controls and panels, not generic iOS menus, alerts or sheets.

Use the approved reference at `docs/qa/gameplay-redesign/reference.png` and the user's four latest screenshots as evidence. Earlier verification is a baseline, not proof that these newly reported interactions work. Reproduce the normal player route as well as QA fixtures. Do not silently discard a saved run to make a fresh-start test pass.

## 1. Book opening and visible skip decisions

Investigate why the user's opening enters live gameplay. A fresh Book currently intends to open at briefing; reopening a Book with an active save resumes its puzzle, and debug launch flags can bypass briefing. Reproduce these separately.

- Make Start Book and Resume Book unambiguous. New ordinary puzzles must expose Play and the named skip reward/effect before dealing. Resume an active puzzle without resetting its board, progress or rewards.
- Keep unlimited ordinary-puzzle skips across every chapter and mandatory bosses.
- Preserve stable deterministic offers through overlays, Shop navigation and save/resume without advancing board, Pool, Shop or boss random streams.
- Preserve the two-slot Buff inventory, explicit replacement/cancellation, distinct duplicate identities, one skipped puzzle per reward and atomic exactly-once saves.
- Preserve historical Clipping effects and history. Award no new Clipping bonus or retroactive replacement Buffs.

## 2. Clue interaction

Implement one coherent player flow: select/activate the available Clue or Peek item, select a specific number from the hand, then see its legal destination. The player places that card on the indicated square. Do not automatically place the number or unexpectedly use a previously selected card.

- Remove the redundant bottom action-row Clue button.
- Keep Clues from every source reachable, including Peek, Book rules, Puzzle Corner and saved charges. Removing a button must not strand charges or create extra Buff capacity.
- Specify ownership and consumption precisely: entering selection or dismissing a panel must not spend a clue accidentally; an invalid card or missing legal destination must preserve the charge. Resolve by exact hand-card identity, including duplicates.
- Ensure the real Buff-panel dismissal transfers control into targeting correctly. Make armed, cancelled, unavailable and revealed states legible.
- Verify Paywall, Buffborger, restricted squares, duplicate digits, overlays, backgrounding, save/resume and repeated taps. Preserve explicitly intended clue scoring rules in the new scoring specification.

## 3. Freeform inventory dragging and removal

Bookmarks and Buffs must follow the finger in both axes throughout diagonal and curved paths. Lift the actual item above the row in screen coordinates, without clipping or snapping its vertical position to the inventory row.

- Expose a clear trash/sell target while dragging, showing the applicable refund.
- Commit only when the exact item is released inside the target. Dropping elsewhere, cancellation, navigation or backgrounding must leave inventory and coins unchanged.
- Sell/remove exactly once, using durable item identity rather than a shifted index. Retain duplicate Buff identities and valid inventory capacity.
- Support intentional Bookmark reordering for order-sensitive scoring; do not confuse reorder, inspection, use and trash gestures. Provide accessible alternatives to dragging.

## 4. Remove the Pool indicator

Remove the visible Pool label/badge and unwanted spacing. Its current frame also anchors return animations, so give Toss, Redraw and wrong-placement feedback a deliberate unobtrusive destination. Preserve card identity, conservation and stable board/hand geometry.

## 5. Fullscreen consistency, Results and Shop

Audit every in-run screen and transition: briefing, live puzzle, success, failure/rescue, Keep Filling, final Book result, Shop, item details, inventory, Help and Settings.

- Remove old book-edge chrome and inset page boundaries from in-run screens. Preserve safe-area controls and working page transitions/capture geometry.
- Reuse the updated five Bookmark/two Buff inventory appearance, spacing, states and interactions throughout the run, including Results and Shop.
- Results must prominently display the actual board as played, with the same ivory wells, sage rails, digits, markers and relevant state as gameplay. Do not substitute an old-style miniature Sudoku print or a newly generated/solved board. Distinguish retained board state from transient interactive effects.
- Fit score, payout and a substantial square board intentionally; keep decisions visible. Compact phones and large text may scroll meaningful content without clipping or making actions unreachable.
- Bring Shop materials, items, purchased states, inventory and custom detail panels into the same visual system. Preserve purchase, replacement, sale and marker-placement handoffs.
- Inspect actual compact/large iPhone and iPad captures. Check long names, large numbers, empty/full inventory, duplicate items, overflow hands, large text, Reduce Motion and modal input/accessibility.

## 6. Balatro scoring adapted to Sudoku

Research Balatro's actual scoring sequence before changing formulas. Start with its [official overview](https://www.playbalatro.com/faq), then verify detailed activation order from authoritative material or direct gameplay. Distinguish verified Balatro behavior from our Sudoku-specific decisions. Do not claim identical behavior merely because a formula contains multiplication.

Write a versioned scoring specification with worked examples first. Use one Sudoku Turn as the scoring batch, numeric points as Chips, Bookmarks as ordered passive modifiers and Buffs as consumable effects. Adapt scoring events to digit placements, row/column/box clears and full-board clears. Keep coins and score separate.

- Distinguish Points additions, additive `+Mult`, multiplicative `×Mult`, direct score payouts, zeroing and scoped effects.
- Define event order, visible Bookmark slot order, held-card effects, growth timing, retriggers versus score doublers, modifier scope, penalties, rounding and large-value handling.
- Make `+Mult` versus `×Mult` order observable and strategic. As an arithmetic acceptance example, starting with 50 Points and Mult 1: `+1` then `×3` yields 300; `×3` then `+1` yields 200.
- Document how every current Bookmark, Marker, Buff and boss maps to the new model. Decide explicitly where Fresh Ink, Rose, Sashimi, Double Down, Second Print, Onyx, Morning Edition and Evening Edition apply. Preserve an item's documented behavior unless its changed rule and text are intentionally specified together.
- Emit one deterministic engine-owned scoring ledger with each operation's source identity, trigger, before/after values and final amount. Preview, animation, explanation, banked score and persistence must agree. Animation only presents the ledger; it cannot reapply gameplay effects or rewards.
- Show understandable activation order and running totals. Reordering or selling an item must not silently rewrite already-earned score; define the point at which ownership/order is locked for a scoring batch.
- Assess target progression and economy against the adapted formula rather than importing poker numbers blindly.
- Version or explicitly migrate in-progress scoring state. Preserve historical banked scores, coins, earned Clipping effects, inventories and skip records; do not silently recalculate old rewards or double-bank a resumed Turn.

## 7. Multi-agent QA and regression proof

Use multiple agents with separate bounded responsibilities. Coordinate Simulator ownership so agents do not interfere with the same device or interrupt automated tests.

1. Flow/Clue tester: fresh Book, resume, briefing, skipping, real inventory-to-Clue targeting, overlays and persistence.
2. Inventory/effects tester: every Buff, Bookmark and Marker through the QA menu and real player controls; duplicate copies, cancellation, capacity, freeform dragging, selling, reordering and boss restrictions.
3. Scoring tester: independently calculated expected arithmetic, operation ordering, combinations, multiple simultaneous clears, fractional values, penalties, direct payouts, no-effect cases, end-of-turn bank, Keep Filling and payout consistency.
4. Final independent reviewer: after implementation and focused checks, play the complete loop and audit cross-screen appearance. Have this reviewer re-test all discovered defects after fixes.

Use QA only to arrange a reproducible state, then exercise actual player inputs. Record scenario, seed/setup, actions, expected outcome, observed outcome and evidence. Include smoke coverage of every catalogue item, targeted combinations and every boss, with deeper interaction tests for changed behavior. Model calls alone do not count as proof of the touch flow.

Run appropriate Engine and app regression suites. Keep tests meaningful; update old-rule assertions only with the documented rule change. Test rapid repeats, delayed transitions, navigation, background preparation, background/resume and complete saved snapshots. Keep original failure evidence, add regressions for confirmed defects, and re-run affected checks after each fix.

## Completion gate

The normal fresh-start and resume routes are clear and correct; every ordinary briefing offers the stable skip decision; Clue targeting works from the actual inventory; freeform inventory gestures and exact-item commits work; no Pool badge remains; Results and Shop share the fullscreen visual system and Results shows the real board prominently. Scoring matches the documented ordered model and its independent arithmetic fixtures, with consistent UI receipts and persistence. All required automated checks and assigned manual scenarios pass, every confirmed in-scope review finding is fixed and rechecked, and no blocked/unperformed check is mislabeled as passed. Deliver the evidence report and reopen the latest tested simulator for the user.
