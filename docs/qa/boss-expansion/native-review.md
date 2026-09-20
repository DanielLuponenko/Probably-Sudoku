# Native boss playtest — 20 September 2026

Device: isolated “Book Playtest A — iPhone 17 Pro”, iOS 26.3, UDID D04D3836-357E-4E92-811D-6D14E3BA1E01. No user-device/save interaction. Root installed the candidates and launched with isolated cloud transport. QA setup was done through the actual in-game Settings → QA tools → Force Boss/loadout controls; normal placements, Toss and End Turn used the ordinary player controls.

Builds: compile6 for initial Tik Tak, Fog and Garry checks; compile7 for Shredder, Hand restrictions and the uninterrupted timer run; compile8 for the final rail/seal and accessibility recheck. Reduced motion was Off, background motion On, sound muted (existing QA preferences). No preference changes in this pass.

## Observed behavior

- **Tik Tak:** large fixed-width `04:00` is readable beside the score, with no board movement. The live clock ticks down. The pause recording shows approximately `03:22` before Settings, about 24 seconds behind Settings, then `03:21` on return and normal ticking afterward. A second uninterrupted real 240-second run was recorded: the style changes to amber at 01:00, red/“Urgent” at 00:30 and “Final 10” at 00:10, then transitions once to Book over with an “Out of time” receipt. The failure page stays stable afterward; its played board and New book action are fully visible. No clock setter, save editing, speed change or fabricated elapsed time was used.
- **Fog:** the actual board has slowly moving gray/ivory density under crisp numbers. A QA-owned Crimson marker at the first blank (r1c1) is not drawn or exposed as an Inspect marker accessibility action. Selecting Hand 1 and placing it at r1c4 succeeded through normal input and produced a live 10-point calculation; the subsequent real bank produced score 10. No hidden information popup appeared. Physical long-press cancellation is not claimed: the current CUA API does not expose a dependable held-touch duration.
- **Garry the Gray:** the recorded real Turn change lifts/fades the old blockers, then drops the new bricks one at a time. Only the actual blank cells in the selected box receive bricks; all its givens remain visible. Impact settles quickly and the board/controls remain stationary. The 8 fps contact sheet records the changing airborne and landed poses.
- **Shredder:** Turn 1 has three physical ink pools. A real End Turn carries all three and adds three new fouls. Turn 3 releases the original r3c5, r4c2 and r7c1 squares; all three become Available in accessibility and visibly clear, while the current six fouls remain unavailable. Ink is confined to actual blank cells. The turn-2/turn-3 screenshots and recording retain the states.
- **Handy Dandy:** exactly two owned Hand copies (1 and 9 in this seed) were sealed; other cards, including both distinct 7 UUIDs, remained available. Selecting the sealed 1 disabled Toss. Attempting an ordinary blank placement left the board, score, Hand and Turn unchanged.
- **Galley Queue:** the first two eligible copies were playable, later copies waited with an explicit reason. Tossing the exact waiting 8 succeeded, reduced Toss allowance from 4 to 3, preserved all other card UUIDs/order, and retained two distinct copies of 7.

## Native findings and fixes

1. **Hand cue alignment — fixed and verified:** brass rails were centered by the intrinsic-height overlay and crossed the printed numbers. `BossHandTreatmentView` now fills the existing tile allocation and aligns only its physical cues at the lower edge. The new render regression compares the protected numeral pixels for all eight treatment variants and passed the central focused gate. `native/galley-before-rail-alignment.png` is the reproducer. On compile8, Galley Queue's rails sit below its playable 6 and 4; Handy Dandy's seals sit below the exact barred 6 and first 8. Every digit is unobstructed. Final evidence: `native/galley-final-rail-alignment.png` and `native/handy-final-seals.png`.
2. **Blocked-card accessibility hint — fixed and verified:** after selecting a Handy Dandy sealed card, an empty square still advertised “Places number 1”, although the engine correctly refused the action. `GridView` now uses the selected card’s actual restriction text, preserving Release Note exceptions. The focused selected-barred/playable regression passed. On compile8, selecting card `706425E5-D61C-6683-3045-4A46963D0920` (6) makes the empty r1c1 hint say “Barred by Handy Dandy. Cannot be played or Tossed this Turn.” An actual tap leaves r1c1 empty, score 0, all seven card IDs intact and Turn 1/10 unchanged. Selecting the available 4 restores its normal placement/conflict hint and enables Toss. The second 8 remains playable while the first 8 is sealed, confirming copy-specific identity.
3. **Timer accessibility grammar:** the countdown now uses singular “1 minute” and “1 second”; the formatter regression covers 61 seconds.

## Evidence

Short clips: `native/tik-tak-pause-proof.mp4`, `native/fog-drift.mp4`, `native/garry-turn-change.mp4`, `native/shredder-new-ink.mp4`, and `native/tik-tak-last-minute-expiry.mp4`.

Stills/contact sheets: `native/tik-tak-live.png`, `native/timer-contact.png`, `native/tik-tak-warning-expiry-contact.png`, `native/tik-tak-expired.png`, `native/fog-correct-placement.png`, `native/garry-turn2.png`, `native/garry-impact-contact.png`, `native/shredder-turn2.png`, `native/shredder-turn3.png`, `native/shredder-impact-contact.png`, `native/handy-exact-card-seals.png`, and the pre-fix Galley screenshot above.

Raw recordings are retained alongside the short clips for exact timing review. No claims of haptic/audio quality, Low Power performance, physical-device performance, all 39 encounters played to completion, or a persisted save/resume are made from this bounded native pass. Central state, rendering, lifecycle and eligibility tests cover additional paths separately.

## Handoff

The bounded native pass is complete. The isolated compile8 game is resting on Handy Dandy, with no selected card or open panel. No recorder is running. CUA is released to the parent. No device settings were changed, no persistent launch was used, and the user simulator and its saved Book were not accessed.
