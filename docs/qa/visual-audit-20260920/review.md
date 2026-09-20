# NumberClub visual and interaction audit

20 September 2026. Reviewed the current production SwiftUI screens on isolated iPhone 17 Pro and SE simulators, then checked enlarged text and 320-point display-zoom-equivalent hosted layouts. Three independent review areas covered gameplay/layout, settings/learning, and accessibility/catalogue language. Existing unfinished work was preserved.

## Findings and corrections

| Priority | Finding | Correction | Verification |
|---|---|---|---|
| P2 | Help taught the old board, item art, Queued scoring and obsolete offers. | Replaced four native captures and the turn movie; aligned crops, captions and spoken descriptions. Added concise Clue and marker-inspection instructions. | Guide render/media tests; actual Help playback; independent image review. |
| P2 | Item descriptions exposed implementation terms and instructions. | Reworded 66 full descriptions and one summary at the shared Swift/JSON catalogue source. | All 140 runtime definitions match metadata; reference and copy checks pass. Rules, IDs, prices, timing and limits preserved. |
| P2 | Continue text had insufficient contrast on its pale green card. | Darkened only home action stock; kept the compact card size. | Calculated title contrast 2.88→5.60:1; secondary detail 2.59→4.76:1; fresh native capture and enlarged-text render. |
| P2 | Extra hand tiles could appear absent after the system scroll indicator faded. | Persistent small chevrons appear only at edges containing offscreen cards, outside tile hit regions. | Native Last Edition capture and geometry tests, including both ends and elastic overscroll. |
| P2 | Enlarging text removed the ordinary briefing’s upcoming boss. | Reading layout retains the exact announced boss and power. | Six hosted cases at xLarge/AX5 with three bosses; normal layout unchanged. |
| P2 | Collateral/Split Edition controls retained tiny text at accessibility sizes. | Full-width readable choice row in the existing fixed HUD budget; enlarged Last Edition status. | Eight ready/committed AX5 renders at 320/375 points; native Split choice B activation. |
| P2 | Some visible controls did not own their full 44-point target. Arrange could overlap the next card row. | Corrected Split A/B, reservation cancellation, home Settings and shelf selector targets. Reserved a separate 44-point Arrange band. | Geometry and Shop render tests; no overlap or additional normal Shop scrolling. |
| P2 | Obstacle details did not adapt to large text or support Escape consistently. | Scaled, bounded reading layout; fixed Close; Escape; transition respects the game’s Reduced Motion preference. | Native normal/AX5 plus hosted scrolling/Close tests. An oversized-paper regression caught during review was fixed before delivery. |
| P2 | Tutorial cards used different item glyphs from live inventory/Shop. | Reused the same ItemArtwork renderer. | Tutorial action/AX5 render checks and independent review. |
| P3 | Replaying a completed Book falsely announced a newly earned achievement. | Neutral “Book achievement” wording; unlock behavior unchanged. | Completion render/OCR checks. |
| P3 | Chapter/Level wording and Settings accessibility roles were inconsistent. | Player-facing Help/abandon copy uses Chapter; navigation and accessible score controls explicitly expose button traits. | Source review and native accessibility tree checks. |

The compact result and normal Shop screens already fit correctly; they were verified again rather than described as unfixed old screenshot defects. Their complete boards, five offers, prices and primary controls remain visible without catalogue scrolling. The reservation state also fits its longer item examples.

## Evidence

- [Home, after](after/home-17pro.png), [before](before/home-17pro.png)
- [Current result page](after/results-17pro.png), [Shop](after/shop-17pro.png), [next puzzle](after/briefing-17pro.png)
- [Reserved Shop, SE](after/shop-one-screen-SE-five-reserved.png)
- [Last Edition extra hand cue](after/last-edition-hand-se.png)
- [Native Split Edition at AX5](after/split-edition-ax5-se.png)
- [Obstacle, normal](after/obstacle-se.png), [AX5](after/obstacle-ax5-se.png), [complete article after scrolling, hosted](after/obstacle-popup-accessibility5-bottom.png)
- [Tutorial current artwork](after/tutorial-current-art.png), [current Help example](after/help-current-art.png)
- [Native page-turn recording](after/results-shop-briefing.mp4): results → Shop → briefing → puzzle. This is a non-saving QA fixture; its winning score is explicitly prepared for presentation testing. Recording includes idle inspection time and retains actual animation speed.
- [Catalogue copy review, all changed IDs](catalogue-copy-review.md)
- [Independent native interaction review and six screenshots](native-playtest.md)

## Verification

- Initial app pass: **84 tests passed**, zero failures.
- Final follow-up after popup/hand/HUD refinements: **18 tests passed**, zero failures. Some recheck the initial set; these are execution counts, not 102 distinct test methods.
- Catalogue/reference: **3 tests passed**, zero failures.
- Final build-for-testing succeeded. `git diff --check` passed.
- Native flow: Book focus/locked obstacle; compact and AX5 obstacle rendering; Help topic navigation and movie playback; Buff details/buy/sold inventory update; results → Shop → next briefing → puzzle; accessible boss destination selection.
- Independently reviewed all supplied final captures; no remaining concrete regression identified in those views. A separate native SE playtest passed Arrange/selection preservation, marker inspection/dismissal, Settings roles, Help return navigation, live placement scoring and one-time turn banking. [Evidence and limits](native-playtest.md).
- Updated build installed on the normal iPhone 17 Pro. `run.json`, `profile.json`, and `discarded-runs.json` remained byte-identical to the pre-install backup at `/tmp/NumberClub-visual-audit-player-backup`. The separate Book Playtest A simulator was not altered.

Results: `/tmp/NumberClub-visual-audit-20260920.xcresult` and `/tmp/NumberClub-visual-audit-final-20260920.xcresult`. Build/test logs: `/tmp/nc-visual-audit-*.log`; catalogue log `/tmp/nc-player-copy-gate.log`.

## Guidelines and limits

The audit used [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) for readable text and meaningful interaction, [Apple layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout) for screen/text-size adaptation, and the [W3C contrast calculation](https://www.w3.org/WAI/WCAG22/Techniques/general/G18.html) for the measured home label pairs. The retained ivory/ink/sage custom controls implement these principles without introducing system-style menus.

This is a scoped audit, not a claim of universal accessibility certification. Physical-device Display Zoom, perceived haptic strength, sustained frame-rate/thermal performance, complete VoiceOver traversal, and touch-driven freeform sell dragging still need device testing. Hosted zoom-equivalent geometry and accessibility trees are useful evidence but do not replace those checks. Full animations remain the default and the game’s own Reduced Motion preference remains independent of the OS setting, as requested.
