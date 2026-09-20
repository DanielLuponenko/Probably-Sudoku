# Independent run-menu review

QA device only: Book Playtest A — iPhone 17 Pro, D04D3836-357E-4E92-811D-6D14E3BA1E01. The user's separate iPhone 17 Pro (223A…) was not used for this audit. Production scope assigned to this reviewer: SettingsView.swift only; ContentView and persistence changes belong to the parent team.

## Confirmed on the previously installed score-modifiers build 3

- Settings → Abandon Book presents an inline confirmation describing loss of the current Book. The action is not committed when the confirmation appears.
- Selecting KEEP PLAYING cancels that confirmation but leaves Settings open. Another CLOSE tap is required before gameplay. This is a reproducible label/destination mismatch.
- The narrow Settings fix now clears the confirmation and calls its existing onClose callback. It adds stable identifiers `settings.keepPlaying` and `settings.confirmAbandon`. Parser and diff checks pass. **The installed build did not yet contain this fix; final native recheck remains pending.**
- QA Fail the Puzzle → close Settings → Book over presents New book, without Continue or Keep Filling. New book returns to the main 3D aisle in one tap.
- A nonpersistent `-completeBookNow` setup reaches the completed-Book result. Close the Book returns to the older flat StartBookView shelf, visually different from the 3D aisle/stand used for normal selection and failure return. Evidence: completed-book-legacy-shelf.png.
- That shelf displayed a preexisting saved D04 run after the nonpersistent completion fixture closed. This is expected fixture isolation, **not** evidence that a completed run became resumable or that unlocks were lost.

## Read-only code findings

- StartBookView's direct Continue originally invoked RunStore.resumeRun without checking local/cloud conflict, unlike normal book opening. Parent is unifying it through continueSavedRun with a conflict recheck.
- RunStore excludes terminal failed saves and retains completed receipts; GameModel resumes playing/Keep Filling to the puzzle, won/cashed-out/terminal states to results, Shop states to Shop, and an unstarted puzzle to briefing.
- Existing SettingsPresentationTests exercise hosted layout/scroll reachability, not actual SwiftUI button activation. MenuReturnTransitionTests cover stale render/completion tokens; RunPersistenceLifecycleTests cover retired preparation, skip claims, and clock callbacks. Those do not prove the complete UI navigation paths by themselves.
- Lack of an in-game Save and Exit button is a product improvement opportunity, not classified as a bug in this scope; no such feature was added.

## Native checklist prepared before candidate installation

1. Abandon confirmation → Keep Playing returns directly to the unchanged board; reopening Settings shows unarmed Abandon Book.
2. Confirmed abandon returns to menu once and cannot revive the ended Book on relaunch or after delayed callbacks.
3. A normally persisted QA Book reopens through Continue with exact route, board, Hand, inventory identities, score, and progress intact, rather than starting a replacement.
4. Resume-versus-new decision cancellation preserves the saved Book; a completed receipt offers final-page viewing; failed Books never appear as playable Continue targets.
5. Reach the shelf conflict route if feasible with isolated local/remote fixtures; otherwise distinguish the parent test coverage from native evidence.

All destructive actions so far concerned nonpersistent QA fixtures. Preserve the D04 Application Support backup before the planned persistent QA checks. Do not claim the parent fixes have passed native testing before installing the final build.

## Installed candidate build 1: native results

Candidate `/tmp/NumberClub-run-lifecycle-build1.app`, QA D04 only, normal launch with no debug arguments. The existing QA save (seed `39FA8`, Volume 1 / Level 1 / Puzzle 1) was backed up before testing.

- **PASS — replacement cancellation:** OPEN THE BOOK offered Resume Book / Start new Book. Back to the shelf returned to the selected cover and left `run.json` byte-identical (SHA-256 `55d93e272ddce9ccb03871a1cfef69f7ca4fec8b5190e1720e5d7b51d2065384`). See replacement-decision.png and replacement-cancelled.png.
- **PASS — unstarted resume:** Resume Book returned to Next puzzle with the named Bird Seed offer, matching the existing save's absent puzzle and Shop. It did not replace the run or start play automatically.
- **PASS — playing resume:** Played that puzzle normally, captured the saved state, terminated/relaunched normally, selected the same Book and Resume Book. The entire saved JSON compared equal before/after resume, including all board and stream data. Native AX confirmed identical seven Hand UUIDs and order, score 0/1000 and Turn 1/10. See persisted-puzzle-before.png and persisted-puzzle-resumed.png.
- **PASS — Keep Playing:** Settings → Abandon Book → KEEP PLAYING dismissed Settings directly to that unchanged puzzle. All seven card identities remained intact. See abandon-confirmation.png and keep-playing-returns-board.png. The old label/destination bug is closed in this candidate.

Paused after these cases for parent build 2, which adds atomic replacement / cover-animation durability fixes. Remaining native cases: won/Keep Filling/cash-out/Shop/Continue, shelf conflict cancellation, confirmed abandonment and normal relaunch, explicit replacement with interruption during opening.

## Final candidate build 2: native results

Installed `/tmp/NumberClub-run-lifecycle-build2.app` on D04. Parent reports the matching final gate passed 137 tests with zero failures. All following user actions used CUA and the actual Simulator UI; simctl only installed, launched, terminated, and captured.

- **PASS — shelf conflict:** Launch with the isolated `-shelfPage 0 -presentRunConflict` setup. Continue the Book showed WHICH COPY STAYS OPEN? instead of silently resuming a copy. DECIDE LATER returned to the shelf. The complete real seed `39FA8` saved run remained JSON-identical to the pre-test playing save. No synthetic conflict copy was accepted. See shelf-continue-conflict.png.
- **PASS — Settings state reset:** After Keep Playing, reopen Settings. It showed ordinary ABANDON BOOK; the prior confirmation was no longer armed.
- **PASS — win continuation:** QA Meet the target was used only to establish won state on the preserved board. The normal Keep Filling action returned to that board with score 1,000 frozen, Turn 1/10. Ten normal End Turn actions reached Puzzle Complete with Cash Out and no unusable Keep Filling. Cash Out opened Shop, coins 5→10 (all unused-turn bonuses spent). Continue opened the second ordinary briefing, target 1,500, named Second Print reward, Play/Skip available. Saved state advanced exactly slot 0→1, stayed Level 1, coins 10 and Shop visit count 1, with no old puzzle or Shop. See target-met-decisions.png, cash-out-shop.png, shop-continue-second-briefing.png.
- **PASS — confirmed abandon and relaunch:** From second briefing, Settings → Abandon Book → ABANDON returned directly to main menu. `run.json` was absent and a discarded-run receipt recorded seed `39FA8`. Normal relaunch kept the run absent. Opening the same cover began a new Book directly, with no old Resume choice. See abandon-return-main-menu.png.
- **PASS — new-Book opening interruption:** After that first new cover began opening, terminated the process and relaunched normally. Newly accepted seed `27PXM`, Level 1 / slot 0 / coins 5, no puzzle/Shop, already existed durably. The next case checks explicit replacement separately.

- **PASS — explicit replacement durability and resume:** From the real Resume or Start decision for seed `27PXM`, accepted Start new Book. AX reported Opening the book; then the process was terminated and relaunched normally. Saved replacement seed `3O4UP` already existed at Level 1 / slot 0 / coins 5 with no puzzle/Shop, and the full JSON remained equal after relaunch. Resume Book was available for this replacement. The accepted old seed did not return. Native timing establishes immediate post-acceptance interruption, without claiming a particular animation frame. Automated storage tests separately cover write failure and interrupted receipt finalization; ContentView saves the new model before assigning its opening state.

No new native blocker was found in the final candidate. The completed-receipt durability path is covered by the parent final tests; this reviewer did not perform a persistent full-Book completion on the user's data.

Replacement Resume Book reached the first Next puzzle briefing (Litmus reward, Paywall boss). See replacement-resumed-briefing.png. After the audit, the D04 process was terminated, post-audit Application Support preserved at `/var/folders/18/_8lxcbd15yj0wtcg4k2zn8zr0000gn/T/NumberClub-D04-post-lifecycle-33e7nchq/Application Support`, and the original pre-audit Application Support restored. Original profile/run checksums were verified. The user simulator was never used for these tests.
