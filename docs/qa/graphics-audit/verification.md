# Graphics and Book-completion audit — 19 September 2026

Scope: the core Book loop, page turns, native paper overlays, full-Book completion, permanent per-Book achievements, and the return to the Bookstand. Existing gameplay, saved runs, earned rewards, and the retired Club Shop remain outside the visual changes.

## Confirmed issues fixed

| Issue | Change | Evidence |
| --- | --- | --- |
| The completed Book's next-obstacle banner was clipped on iPhone 17 Pro; several recap elements disappeared on SE. | A measured single-screen celebration reserves space for its text and Close action, then fits the actual final board in the remaining area. | `baseline-17pro-completion-clipped.png`, `baseline-se-completion-clipped.png`, `build1-se-completion.png` |
| No specific permanent award identified the Book just completed. | Twelve stable achievements, one for each engine Book identity, with a matching earned-achievement receipt on the congratulations page. | `BookCompletionAchievementTests`, `AchievementExpansionTests`, `AchievementRegistrationTests` |
| Closing replaced the final page with blank paper. | Capture the exact visible final page, withdraw it into the same print on the Book leaf, then close the cover. | Native closing recording and `BookTransitionPlaybackTests` |
| A studio-logo frame flashed after closing, before a different legacy shelf appeared. | Change the route and remove the cover in one transaction; keep the outgoing pixels until the current 3D Bookstand actually renders. Select the completed volume and its next durably earned obstacle. | `MenuReturnTransitionTests`, `CompletedBookSelectionTests`, native closing recording |
| The first corrected close lingered on a washed-out frame while the Bookstand warmed up. | Retain the closed cover at full contrast until the destination is ready, then dissolve. | Independent native review of the first build, followed by final playback verification |
| Cancelled cover tasks or a queued first page-turn frame could finish late. | Owned opening/closing tasks, scene/view cancellation, exactly-once completion, and a synchronous cancellation latch before page-turn commit. | `BookTransitionPlaybackTests`, `PageFlipTests` |

## Compatibility and limits

- Historical awards are preserved. New per-Book awards are backfilled only from identified completed volumes or obstacles; generic old achievements cannot identify a Book.
- Save/resume and repeated completion remain idempotent. Permanent progress must be durable before the completed receipt can be discarded.
- The twelve new achievements are local catalogue entries and sync with the existing player profile. They are deliberately excluded from Game Center submission until corresponding App Store Connect records exist; the nineteen registered IDs remain unchanged.
- Native visual QA uses isolated iPhone 17 Pro and iPhone SE simulators. Automated rendering also covers larger text and tablet surfaces. This is evidence for the exercised routes, not a claim about every possible device, frame, or external-service state.

## Automated verification

- Existing surface baseline: **64 tests passed**, `/tmp/nc-graphics-baseline.log`.
- New graphics/completion gate: 136 tests executed. 123 tests passed outside the victory rendering suite; two rendering assertions needed correction because they assumed the previous scrolling hierarchy and omitted actual phone safe insets. `/tmp/nc-graphics-test2.log`.
- Victory rendering recheck: **13 tests passed**, with actual safe insets, readable enlarged award text, complete next-obstacle text, and no vertical scroll. `/tmp/nc-graphics-test3.log`.
- Final cover-handoff recheck: **34 tests passed**, including the new normal/Skip contrast test, opening/closing lifetime tests, page-turn ownership, and destination first-frame readiness. `/tmp/nc-graphics-test4.log`.
- **201 distinct focused tests pass across these gates.** Tests were repeated only where a change or failed assertion required a recheck. `git diff --check` passes.

The user's simulator data was backed up before installation at `/tmp/NumberClub-graphics-user-backup-20260919`. Final candidate `/tmp/NumberClub-graphics-build2.app` was installed on the user's iPhone 17 Pro (`223A4227-A28E-4939-BB5E-3AAB820EB635`) and launched normally, without QA flags. All five Application Support files were verified byte-identical through installation and after normal launch. QA uses separate devices and nonpersisting debug launches.

Independent final native evidence: `final-17pro-close.mp4` and `final-close-motion-contact.png` show the exact outgoing page, a contrasted closed cover, and the current Bookstand without the unexpected studio-logo frame. Large-text hosted captures are `automated-17pro-accessibility5.png` and `automated-se-accessibility5.png`. Detailed tested paths and native limitations are in [native-review.md](native-review.md).

Final independent review passed normal Close, immediate accessible Skip, and background/resume on build 2. The SE completion page also fits completely. The user's iPhone 17 Pro window was raised and verified at the normal PLAY screen after installation; no QA flags or test completion were applied to that run.

Native review and final verification status are recorded alongside the captures in this directory.
