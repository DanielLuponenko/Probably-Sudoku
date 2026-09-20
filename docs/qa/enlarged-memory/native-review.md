# Enlarged display and native interaction audit

2026-09-19. Independent native reviewer: graphics_native_qa. This report distinguishes simulator-native settings from hosted reduced-viewport tests.

## Environment and original settings

- Isolated iPhone 17 Pro D04D3836-357E-4E92-811D-6D14E3BA1E01, iOS 26.3. Baseline candidate `/tmp/NumberClub-graphics-build2.app`.
- Original D04 Dynamic Type: `large`; Larger Accessibility Sizes off; slider 50% in the standard range. Bold Text off.
- Simulator screenshots are 1206 × 2622 pixels. This is not by itself proof of Display Zoom's logical bounds or safe areas.
- The exposed Settings app does not contain Display & Brightness or Display Zoom. The Accessibility Vision section contains Hover Text, Display & Text Size, Motion, and Spoken Content; no magnification Zoom row. Neither genuine Display Zoom nor system magnification can be claimed as tested through those unavailable simulator controls.
- Actual AX5 was enabled through the supported `simctl ui content_size accessibility-extra-extra-extra-large` interface and verified in Settings: Largest Accessibility Sizes on, slider 100%, native Settings body visibly enlarged. `17pro-settings-ax5.png`.
- Bold Text was separately enabled through the actual Settings switch, verified Value 1, then combined with AX5. `17pro-settings-ax5-bold.png`. No player save was used; game fixtures omit `-persistQA`.

## Baseline findings and checks

1. **Briefing important text does not grow at AX5.** Same seed and route, same running process, default versus AX5 screenshots show unchanged tiny route and reward copy. Files: `baseline-17pro-briefing-default.png`, `baseline-17pro-briefing-ax5.png`. The fixed `Print` fonts in PuzzleBriefingView explain the behavior. A layout that merely fits without growing is not a successful enlarged-text result.
2. **Redraw purchase initially below the article viewport; not a confirmed defect.** Launch `-skipStartScreen -shop -seed enlarged-baseline`, open Buff slot 4. Full-size effect fills the available article, while price, availability, and Buy begin below pinned Close. `baseline-17pro-ax5-redraw-buy-hidden.png`; combined Bold Text case `baseline-17pro-ax5-bold-redraw.png`. CUA targeted scrolling was inconclusive. Root's independent hosted scroll-to-bottom verification established that Buy is reachable, so this observation does not establish a missing scroll fallback. A separate confirmed issue is a very long pinned heading starving the article viewport at 320-point width; root is fixing and testing that geometry.
3. **Hand arrangement menu:** actual AX5 grows the three choices substantially and all remain visible; Ascending successfully sorted the hand and dismissed the menu.
4. **Settings:** actual AX5 grows audio labels and accessibility control descriptions. Content scrolls; pinned Close stays visible and returns safely to the unchanged puzzle. No clipped/unreachable Close found.
5. **Live board:** the complete grid and hand/actions remain visible at actual AX5. The game uses compact HUD typography instead of growing all labels; this is not proof that every gameplay label honors text enlargement.
6. **Bold Text:** visibly applied to the long Redraw effect and its controls in the existing process. It did not fix or materially worsen the hidden-purchase presentation.
7. **SE AX5:** original content category was `large`; genuine system AX5 was applied through the supported simulator interface. Dense showcase (large score, boss, Clue target, full inventory), ordinary results, and their controls fit. Results body copy remains small; reported as the same fixed-copy accessibility gap. `baseline-se-ax5-results.png`.
8. **SE marker inspection:** Jade produces a genuinely enlarged article, keeps Dismiss visible, and the first scroll moves the article. CUA scrolling a named accessibility element can first reposition that element; further attempts are not reliable proof of reaching the bottom. This limitation also applies to the Redraw scrolling attempt above. No additional missing-scroll defect is concluded from CUA alone. `baseline-se-ax5-jade.png`.

## Native cycles for memory sampling

Root captured baseline memory for D04 PID 9412. This reviewer performed two batches of 15 cycles without process relaunch: close Redraw → open game Settings → close Settings → reopen Redraw slot 4. Every action used a newly read accessibility tree. All 120 actions completed; no stuck overlay, crash, duplicate purchase, or coin change occurred. The process returned to the same Redraw detail with 20 coins after each batch, then remained stationary for root's memory captures. Leak/retention findings belong to the root's runtime and lifecycle analysis, not this visual observation.

## Candidate verification

- Candidate1, actual D04 AX5 plus Bold: Peek briefing now enlarges its entire effect and keeps both full-width choices visible. SE AX5 does the same, reducing the read-only preview to the remaining space. Evidence: `candidate1-17pro-ax5-bold-briefing.png`, `candidate1-se-ax5-briefing.png`.
- SE AX5 arrangement now shows all three complete labels. Descending activated successfully and preserved all seven card UUIDs in the new order. `candidate1-se-ax5-arrange.png`.
- SE AX5 result payout explanation and Keep Filling hint now grow; board and both actions fit. Cash Out delivered 15 coins and reached Shop. `candidate1-se-ax5-results.png`.
- SE AX5 Evening Edition detail: heading scrolls away with article, two native scrolls expose the complete Buy button and its price, Close remains pinned. Actual purchase succeeded once (20 to 15 coins, Bookmark added, offer Sold). This is positive native scrolling/activation evidence. `candidate1-se-ax5-shop-detail-bottom.png`.
- Candidate2 SE AX5 dense boss showcase: full grid, seven cards, large score, complete inventory, Clue destination and larger Toss/End Turn controls fit. End Turn advanced once to Turn 2. `candidate2-se-ax5-denseboard.png`.

## Persistent QA navigation

Before opting into persistence, all five files in D04 Application Support were copied to `/tmp/NumberClub-enlarged-native-D04-original`, with SHA256 manifest. Only then was a `-persistQA` fixture started. Terminating that app, installing candidate2 and launching normally preserved the Book. Play, Volume 1, Open, Resume Book returned to the same board, five coins, Turn 1 and hand. The intentional product route has no Save/Exit button; closing the app preserves progress.

Keep Playing in the Abandon confirmation returned without changing the seven hand UUIDs, coins, score or Turn. Confirmed Abandon returned directly to the 3D bookstore; the run file was absent after the return settled. `candidate2-abandon-menu.mp4` and contact sheets record the transition. Parent's hosted lifetime tests provide ownership evidence; this native check validates the resulting visible route.

## New issues found while retesting

- Actual D04 AX5 plus Bold: settled Book cover notes expand into narrow word fragments and cover the title; the checklist hangs below Open Book. `candidate2-17pro-ax5-bold-cover-notes.png`. Parent is scoping authored text size to decorative cover artwork, with controls left outside.
- The same settings expose two-column Abandon confirmation buttons as KEEP/PLAY/ING and ABA/NDO/N, with tiny confirmation copy. `candidate2-17pro-ax5-bold-abandon-confirmation.png`. Reported for stacked accessible controls and readable explanation.

## Candidate3 native recheck

- D04 AX5 plus Bold cover fix passed: decorative notes and checklist keep authored proportions, title is clear, and Open remains unobscured. `candidate3-17pro-ax5-bold-cover.png`. Opening this Book after the earlier abandonment starts a fresh Book without a stale Resume choice.
- D04 AX5 plus Bold Abandon fix passed: explanation is enlarged and readable; vertically stacked Keep Playing and Abandon retain whole words. Keep Playing returned to the same five-coin briefing and Insurance offer. `candidate3-17pro-ax5-bold-abandon.png`.
- SE AX5 full Buff inventory: new replacement panel grows its complete explanation and choice effects, scrolls through the content, and keeps Cancel pinned. Cancel preserved the Easy puzzle, Peek/Fresh Ink inventory and five coins. Reopening and choosing slot 2 advanced one ordinary puzzle to Easy but hard, retained five coins, and displayed two Peek copies in the inventory. `candidate3-se-ax5-replacement-bottom.png`.
- Further score-ledger check found fixed small explanatory text below an enlarged title despite ample available space. Reported to parent for the same readable-text correction. `candidate2-se-ax5-score-details.png`. Close remained accessible and did not alter Turn 2 or its score.

## Restoration

D04 app was terminated before restoring Application Support. All five original files now match the pre-test SHA256 manifest exactly. Synthetic test state was retained separately in `/tmp/NumberClub-enlarged-native-D04-test-state`; original backup remains untouched. No normal app launch was performed after restoration.

D04 system preferences are restored and verified in actual Settings: Bold Text off, Larger Accessibility Sizes off, slider 50% in the standard range. `simctl ui content_size` confirms `large`. `restored-17pro-text-settings.png`. User device 223A was not used or changed by this reviewer.

SE's app was terminated after its final check. Original `content_size large` was restored and rechecked. Actual Settings shows Bold Text off, Reduce Motion off, Larger Accessibility Sizes off and standard slider 50%. The original SE content category was captured; its original size-range toggle was not separately recorded, so no byte-for-byte original-settings claim is made for that toggle. `restored-se-text-settings.png`. SE only ran nonpersisting fixtures during this audit; its normal Book was not opened.

## Final ledger check and disposition

Candidate4 on actual SE AX5 passed. The populated ledger's factors, gain explanation, source, operation, running Mult and footer now grow; scrolling reveals every line of the source and the complete footer. Close remains pinned. Closing the panel preserved score 122541, preview gain 19676, 957 coins, two Clues and Turn 1. Compare `candidate3-se-ax5-ledger-before.png` with `candidate4-se-ax5-ledger-top.png` and `candidate4-se-ax5-ledger-bottom.png`.

All confirmed native issues reported in this audit have been independently rechecked after their fixes. Native coverage is limited to the isolated iOS 26.3 simulator devices/settings described above. Genuine Display Zoom, system magnification and physical-device memory behavior were unavailable/not tested; parent-owned hosted reduced-viewports, render tests and app-scoped runtime sampling are separate evidence. CUA was released to the parent after this final check, with no recording or QA game process left running.
