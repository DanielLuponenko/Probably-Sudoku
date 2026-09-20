# Native graphics and animation audit

Date: 2026-09-19. Independent reviewer: graphics_native_qa.

Devices: isolated Book Playtest A iPhone 17 Pro (D04D3836-357E-4E92-811D-6D14E3BA1E01) and SE-test (60D48736-12BA-4D48-ADCB-DC2DBB834730), iOS 26.3. The player's iPhone 17 Pro (223A…) was not used. All game fixtures were launched without `-persistQA`; no original Book was abandoned, replaced, or completed.

## Confirmed baseline findings

1. **Book completion overflow:** iPhone 17 Pro clipped the Obstacle II unlock message to a narrow line. SE clipped the boss name, completion statistics, congratulations sentence, and unlock message. See `baseline-17pro-completion-clipped.png` and `baseline-se-completion-clipped.png`.
2. **Closing flashed the studio intro:** after Close Book, the cover faded toward ivory, then the black DIA launch logo appeared briefly before the old flat shelf. No process relaunch occurred during Close Book. See `baseline-17pro-completion.mp4` and `baseline-close-turn.png` (37.7 seconds onward).
3. **Final board disappeared on close:** the completion screen abruptly became a 3D Book with blank inside pages. Same closing evidence above.

## Baseline checks without a visual failure

- 17 Pro: ordinary briefing → puzzle, puzzle → results, Cash Out → Shop, Shop → briefing; full outgoing content curls and the receiving board is stationary. `baseline-17pro-loop.mp4`, `baseline-play-turn.png`.
- 17 Pro: Shop Buff detail sheet, purchase, sold offer, updated inventory and next briefing. The custom sheet fits, obscures the underlying controls, and dismisses cleanly.
- SE: ordinary briefing, results, Shop, and Book-over page all fit the screen without scrolling or clipped controls. `baseline-se-briefing.png`, `baseline-se-results.png`, `baseline-se-shop.png`, `baseline-se-failure.png`.
- SE genuine system Reduce Motion: enabled through Settings, verified Value 1, then automatic briefing → puzzle changed without the page curl. `baseline-se-reduce-motion.mp4`. Reduce Motion restored to original off and verified Value 0.

## Build 1 verification

Candidate: `/tmp/NumberClub-graphics-build1.app`.

- Updated Book completion fits on 17 Pro and SE with full board, Congratulations, the Volume 1 achievement, statistics, Obstacle II unlock, and Close Book. `build1-17pro-completion.png`, `build1-se-completion.png`.
- The actual completed page now shrinks into the Book before the cover closes. No visible screenshot handoff jump during native playback. `build1-17pro-close.mp4`, `build1-close-motion-contact.png` (10 seconds onward).
- Normal close returns to the current 3D Book stand, with Volume 1 selected, and no DIA flash. `build1-17pro-return-stand.png`.
- Remaining issue reported: closed cover became heavily ivory and held for roughly 1.6 seconds before stand readiness. Root scheduled a build 2 correction.
- Immediate “Skip book closing” accessibility action reached the 3D stand. First attempt from separate tool calls missed the short-lived action; successful attempt read the actual action and invoked it in the same call.
- Home during closing, then resuming via the app icon, reached the stand. The first resumed frame was solid ivory while accessibility still said Closing. Reported for the same wash-state correction.

## Limits

- Native drag attempts on SE had inconsistent CUA coordinate mapping; they selected unrelated board squares rather than reliably initiating inventory drag. No drag pass or game defect is inferred from those attempts. No item or coin was lost. `baseline-se-drag-overlay.mp4` is retained as attempted evidence only.
- Actual rewarded-ad presentation, native largest accessibility text size, all twelve Book completion titles, and real achievement durability across relaunch were not established by this visual-only fixture pass. The root's focused automated checks cover separate state/geometry concerns.
- Simulator video records changed frames at a variable rate. Contact sheets are resampled illustrations; the original videos are the animation evidence. Relaunch clips include the expected operating-system launch and studio sequence; only the uninterrupted Close Book sequence was used to diagnose the unexpected studio flash.

## Final build 2 verification

Candidate: `/tmp/NumberClub-graphics-build2.app`, installed on D04 and SE.

- Normal closing preserves the actual final page, shrinks it into the printed leaf, closes the cover, retains full cover contrast while the destination prepares, then briefly crossfades into the 3D stand. No blank leaf, ivory stall, or DIA flash. `final-17pro-close.mp4`; `final-close-motion-contact.png` starts at 12.95 seconds, excluding launch.
- Immediate accessible Skip during closing reaches the same 3D stand. The skip action was obtained from the current accessibility tree and invoked immediately, rather than reusing an expired element index.
- Home during closing, followed by a normal app-icon resume, first shows the closed cover at full contrast, then the 3D stand. The previous solid-ivory resumed frame is gone. `final-17pro-interruption.mp4` includes both Skip and a separate relaunched background/resume case. `final-17pro-return-stand.png` shows the settled destination.
- All three routes select Volume 1, matching the completed fixture. These nonpersistent fixtures intentionally do not earn a real profile unlock, so durable Obstacle II selection is not claimed from native QA.
- Final-build SE completion was relaunched and captured independently; all content and the action fit in one screen (`final-se-completion.png`).
- No additional confirmed graphics defect remains in the exercised routes. Original QA Books were not changed; only nonpersistent fixtures were used. SE system Reduce Motion remains restored off. The player's 223A device was untouched by this reviewer.
- Both isolated QA processes were terminated after verification so their nonpersistent fixtures cannot be mistaken for normal resumed Books. No simulator recording is left running.
