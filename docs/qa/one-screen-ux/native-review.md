# Independent native review of one-screen UX

Reviewed on 2026-09-19 by the independent `one_screen_review` agent. Native input used CUA only. QA arranged target attainment; real player controls performed placements, banking, cash-out, purchases, continuation and skips. No scrolling was needed on the reviewed Results, Shop or briefing pages.

## Final build and save preservation

Final native checks used the immutable `/tmp/NumberClub-one-screen-build6.app`, implementation dylib SHA-256 `d6534b17dd68106444b71aa1349771b007fab62daa7ea1423a29d335145f60c0`. Devices were SE-test `60D48736-12BA-4D48-ADCB-DC2DBB834730` and Book Playtest A, iPhone 17 Pro `D04D3836-357E-4E92-811D-6D14E3BA1E01`. The user's `223A4227-A28E-4939-BB5E-3AAB820EB635` device was not touched by this reviewer.

Launches used `-skipStartScreen -briefing -seed ONE-SCREEN-UX` without `-persistQA`. Original normal saves were backed up first and remained byte-identical after installations and playtests: [save comparison](native/save-comparison.json). No normal save was replaced by these fixtures.

## Findings and rechecks

| Finding | Evidence | Resolution |
| --- | --- | --- |
| Build 3 collapsed Skip into a narrow empty outline while Play took the entire action row. | [Original SE failure](native/se-briefing-skip-collapsed-build3.png). The normal briefing was unusable visually despite an AX Skip element. | Equal action widths. [Build 4 SE recheck](native/se-briefing-fixed-build4.png) and [final 6 iPhone 17 Pro](native/17pro-briefing-final6.png) show both complete labels and usable targets. Actual Skip taps advanced once and granted the named reward. |
| Briefing did not register its action area with the sale presenter. | Independent source review; Results, Shop and Puzzle registered, briefing did not. | Briefing now registers the same action row, so the target replaces its choices too. Native drag limitation below still applies. |
| Unowned action-frame removal could clear a newer route's target. | Source hardening observation, **not** a reproduced user-visible defect. | Root added owned registration/removal and a regression for stale departing-owner removal. |
| Long boss route names required actual visible wrapping, not merely a complete duplicate name in the lower slip. | Root's hosted review identified the remaining truncation. | Final native [SE](native/se-accountant-final6.png) and [iPhone 17 Pro](native/17pro-accountant-final6.png) show “Natural Born Accountant” on two complete route lines, the BOSS badge, the one-coin rule, full lower description and mandatory Play. No ellipsis. |

## Actual play and screen evidence

| Scenario | Actions and observations | Evidence |
| --- | --- | --- |
| Actual upcoming board | Compared the nine rows and their blanks/givens on briefing with the board after Play. The matching rows are listed below. Final 6 retained the same board; it did not generate a different displayed puzzle when accepted. | [Final briefing](native/17pro-briefing-final6.png), [final gameplay](native/17pro-play-matches-preview-final6.png). |
| Compact Results with actual placements | On SE build 3, placed hand 9 at R9C3, then 6 at R9C8; End Turn banked 195. QA Meet Target arranged the terminal phase without replacing the board. All 81 cells, including both placed digits, score 1,000, payout 14 and both decisions fit immediately. | [SE complete Results](native/se-results-complete-board-build3.png). Results production code was unchanged in the later briefing fixes. |
| Final iPhone 17 Pro Results | Final 6: placed 9 at R9C3 and banked 90 with End Turn. Used QA Meet Target, closed Settings, then inspected Results. Placed 9 remains; R9C8 remains blank. Full board, 1,000/1,000, total 14, Keep Filling and Cash Out are visible together above the safe area. | [Final Results](native/17pro-results-final6.png). |
| Shop initial screen | Actual Cash Out changes 5→19 coins and opens all five stock cards. Paper Route, Syndication, Jade, Silver and Insurance names, concise effects, prices, Reroll and Continue fit without scrolling, on both sizes. | [SE Shop](native/se-shop-all-five-build3.png), [final iPhone 17 Pro Shop](native/17pro-shop-final6.png). Historical six-offer and AX5 coverage belongs to the root's hosted tests, not this native row. |
| Purchase and next-page handoff | Opened custom Paper Route detail and bought for 5: 19→14, Bookmark appeared and offer became Sold. Bought Insurance for 3: 14→11, Buff appeared and offer became Sold. Continue retained both items and showed the medium target/Second Print offer. Accepted Skip through AX on build 3 (the visible-width defect was reported separately): one Second Print was added, coins stayed 11 and the mandatory Tik Tak briefing appeared. | [Post-Shop mandatory boss](native/se-mandatory-boss-after-shop-skip-build3.png). |
| Repaired visible Skip buttons | Build 4 SE after the width repair: tapped the visible Skip + Buff twice. Double Down and Second Print occupied the two Buff slots, coins stayed 5, and the route moved Easy→medium→Tik Tak. Boss had only Play and stated that boss puzzles must be played. | [Fixed action row](native/se-briefing-fixed-build4.png), [boss after two real skips](native/se-boss-mandatory-build4.png), [skip movie](native/se-skip-transition-build4.mov). |
| Long-name boss and duplicate inventory | Final 6 debug setup `-briefing -briefingBoss -seed ACCOUNTANT-5` uses the two real engine skips during setup. Verified actual AX selected Natural Born Accountant. Both identical Lucky Dip copies remain visible in separate slots. Complete boss route/name/rule and entire board fit on SE and iPhone 17 Pro. This row tests the layout, not a new native claim of duplicate UUID persistence. | [SE](native/se-accountant-final6.png), [iPhone 17 Pro](native/17pro-accountant-final6.png). |

Observed ordinary initial-board rows (`.` is a blank):

```text
.974.....
.51...9..
4..5.6...
783...29.
1.....876
9658723.4
.162....8
3.86...2.
27.3584.1
```

## Motion and gesture scope

Recorded actual final 6 Play and Cash Out transitions and inspected frame storyboards. The outgoing full page curls over the destination; no old book-edge chrome, cropped outgoing board or empty destination was observed. These are sampled visual reviews, not exhaustive frame-time performance measurements. Original valid H.264 recordings and codec/duration metadata are preserved:

- [Play movie](native/17pro-play-curl-final6.mov), [motion detail](native/17pro-play-curl-final6-detail.png).
- [Results to Shop movie](native/17pro-results-shop-curl-final6.mov), [motion detail](native/17pro-results-shop-curl-final6-detail.png).
- [Metadata](native/video-metadata.json).

One fresh supported CUA diagonal drag was attempted on iPhone 17 Pro build 5: `drag([326,234],[210,580])` from the observed Double Down inventory tile toward the board. It opened the Buff detail panel as a tap, reproducing the existing input-tool limitation. Keep It dismissed without consuming the Buff or changing the 5 coins/board/hand. No further unsupported event technology was used. **Live held-finger curved motion, its cancel-return flight, and control replacement during a physical drag are not claimed as native passes.** Their coordinate/identity/return-state and rendered hidden/restored-controls coverage is in the root's hosted and model tests. The user's supplied image is direct evidence of their real drag, but not a recheck of this final build.

No unresolved confirmed layout defect was found in the final native screens reviewed above. The physical drag verification limitation remains explicit.
