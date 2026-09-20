# Independent review

## Engine and roster

`BossRosterRedesignReviewTests` contains 11 test methods. The latest isolated run passed all 11 in 39.4 seconds (`/tmp/nc-boss-roster-independent4.log`).

The checks cover:

- The exact 22 active encounters,16 regular plus 6 final, and nine unique announcements across each of 12 seeded Books.
- All 39 historical active boss IDs and saved mechanics round-trip with missing roster-version/history fields; legacy set/dictionary order is compared semantically.
- Collateral reserves and returns the same physical card once, including duplicate digits, save/resume and Redraw; a rejected duplicate pledge changes nothing.
- Pledge+2 Mult precedes Bookmark operators and previewing the bank repeatedly is pure.
- Invalid placement/edition input changes nothing. An accepted Toss closes boss preparation choices.
- Split Edition routes ordinary and direct awards into the selected target, requires both targets, and cannot use Full Clear to bypass the second edition.
- Last Edition's manual and automatic banks enforce one bank, reject Overtime, prohibit Keep Filling/rewarded rescue, and preserve the terminal result through resume.
- 72 finite-pool probes across all 6 final encounters, three seeds and four real catalogue builds. These use a solution-aware placement policy; they are mechanical attainability checks, not human win-rate estimates. See `final-balance.md`.

## Visual pass

Reviewed all 22 compact 375×667 ready-state screenshots, all 3 new bosses at Accessibility 3, and selected/committed states at 375×667 and 402×874. Screenshots come from the real SwiftUI gameplay view, not a mockup.

No board, numeral, Hand/action-row or bottom-control clipping was found in those reviewed states. Bookends' extreme-card bands, Dry Press's ink pad, Royalty's three entitlement seals, Review Board's three unit stamps, and Executive Editor's sleeping copy communicate distinct state.

Findings sent to the implementation owner:

1. Split Edition's selected B target truncated at Accessibility 3 because its pin occupied the target text row.
2. Disabled A/B buttons faded their still-relevant target information; committed Collateral faded its active pledge and +2 seal.
3. Accountant's full title truncated at both phone sizes; Mirror's secondary line truncated at 375.
4. Briefing's target fallback used the old integer boss multiplier and could show the wrong Collateral/Last Edition target until board preparation completed.
5. The Last Edition press used a success check for any spent bank, including failure. Changed to a neutral printed mark.

Refreshed captures confirm fixes for 1–3: both exact Split targets remain visible at Accessibility3 with the pin above the text, committed Split/Collateral status retains contrast, and Accountant/Mirror no longer truncate. Source review confirms the central target fallback fix for 4. Last Edition now shows the actual printed 480 receipt and a neutral dash, correcting 5. Split failure content shows both targets so an overfunded A/unfinished B is understandable. The final hosted failure screenshots at 375×667 and 402×874 show the complete board, both edition targets, explanation and New book control within one screen. The additional one-complete Split screenshot confirms that A keeps its completion seal while B is selected.

## Recorded action review

Independently inspected before/action/settled frames from the final production-view recordings of Collateral, Split Edition, Last Edition, Accountant, Mirror, Royalty Contract, Executive Editor, Bindery, Publicist and Garry the Gray. The clips are in `docs/qa/boss-expansion/animations`; `animation-clips.json` identifies the real action times and fixture limitations. All ten reviewed clips have the final recording timestamps beginning 1789898.

Observed effects agree with the recorded engine actions:

- Collateral removes the selected 1 from the Hand, closes the envelope with its +2 seal, scores 90×3, and returns the 1 after the 270 bank. Engine identity tests separately establish that the returned UUID is the same physical copy.
- Split moves the destination clip to B, banks 200 into B only, then moves to A on the next turn and banks 280 into A. Totals remain distinct; no completion seal appears for either unfinished 300 target.
- Last Edition keeps its single print available while preparing Fresh Ink and two fills, then prints the actual 680 receipt once. The press changes to a neutral printed state.
- Accountant charges 50→49 and prints a −1 coin receipt for the accepted fill. Mirror prints the denied 45→0 line bonus while retaining the 10-point fill.
- Royalty consumes the actual Buff, fills one entitlement seal and raises the target from 2,000 to 2,100; the subsequent fill uses Fresh Ink's real Mult.
- Executive Editor moves its sleeping copy from slot 1 to slot 3 on the next turn. Bindery pins the actual two owned copies, changes read direction at the bank, and visibly changes the resulting Mult from 6 to 4.
- Publicist stamps Local Gossip after its first +30 payment. The next fill leaves the stamp in place and adds only the 10 digit points.
- Garry replaces the old blocked box after the turn changes. Close frame samples show sequential falling bricks, brief impact detail and settlement inside the target cells; the given digits remain visible in the settled box.

No additional clipping, duplicate visual award, or false completion cue was found in these reviewed frames. This review uses actual recorded actions and selected motion frames; the reviewer did not control the simulator. The Last Edition showcase tail remains on terminal gameplay instead of showing the normal results transition, so it is evidence for the print and receipt, not a complete production navigation demonstration. Mechanical balance probes also use solution knowledge and do not establish human difficulty or fun.
