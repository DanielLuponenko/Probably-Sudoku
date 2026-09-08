# All-books normal-player playtest ledger — 2026-09-07

## Latest workflow checkpoint — following the user's six-hour concern

- Full native Books completed: **1/12**. Volume **9** is now complete; the
  remaining 11 Books have no final native congratulations proof.
- Stopped further helper-development work. Prioritize actual Book progress;
  preserve the single-runner watchdog and distinguish player mistakes from
  product defects. Never count engine fixtures as normal Book completion.
- C-24 incorrectly burned unchanged full hands through End Turn. This is a
  test-player strategy error: the game correctly retains unused numbers.
  The run reached 1,890/2,000 against The Critic, then offered normal rescue.
- C-25 watched a Test mode ad and restored that same board at Turn 12/14,
  score 1,890, with hand and inventory intact. The proposed follow-up move was
  refused before enqueue by the existing time guard. Player C's log preserves
  exact receipts. C-26–C-50 later brought the current fresh run to **26/27**
  cleared puzzles; C-51 completed Volume 9, leaving **11/12** Books.
- The focused engine gate begun earlier is now terminal: **43 tests passed,
  0 failures, 59.904 seconds** (plus a 5.22-second build). Includes route
  difficulty, 2,052 Book/Boss/Obstacle combinations, final-boss rules,
  completion and rewarded-save recovery. Log:
  `/tmp/numberclub-fast-coverage-2026-09-07.log`. No native runner overlapped it.
  These tests are rule/persistence evidence only, not completed playthroughs.
- A newer fast all-engine verification passed **251 tests, 0 failures** in
  90.941s (92.95s wall), including the full 2,052 Book×Boss×Obstacle matrix
  across all 12 Books and 9 obstacles: `/tmp/numberclub-fast-all-engine-20260907.log`.
  This is engine coverage, not normal-player completion: only Volume 9 is a
  completed native Book (**1/12**). Future work should reuse this fast engine
  matrix plus focused app matrices, reserving bounded native checks for
  uncovered touch/timing behavior; the remaining 11 Books are not silently
  marked complete.

- Final production-start validation passed 108 fresh starts plus 324 turn-rule/
  save-preservation checks in 3.962s (6.54s wall):
  `/tmp/numberclub-fast-108-starts-final-20260907.log`. A separate app gate
  passed 54/55 checks in 167.164s (235.75s wall), covering progression (3),
  bookstore obstacles (10), living Book (6), themes (9), scenes (8), routes
  (7), and briefing (10): `/tmp/numberclub-fast-books-obstacles-app-20260907.xcresult/log`.
  The sole failure is an OCR false negative on Overthinking 375/obstacle 9;
  manual full-PNG inspection confirms the plaque is correct, and a further ROI
  adjustment produced another false failure and was reverted. This does not
  change normal completion (**1/12**).

### Native frontend pass — dedicated iPhone 17 Pro (bounded, read-only gameplay)

- Release UI checks covered title→rack navigation, top/middle/bottom Volume
  selection and return (Volumes 1, 5, 9), endpoint/banner separation, RunInfo
  marker-map opening/closing, Evening Edition offer readability and Sell 2
  label, Settings/Achievements/How To Play navigation, and a physical End Turn
  path. Native video is retained at
  `/tmp/numberclub-native-frontend-endturn-20260907.mov`.
- Reopened Volume 1's old Critic save at Level 1 Puzzle 3, Turn 10/11, score
  330, hand 7. End Turn advanced 330→630 at Turn 11/11; a subsequent End Turn
  failed normally at 630/2,000 with optional ad and End Book visible. Ads were
  neither watched nor clicked, so this is not a full-playthrough claim.
- RunInfo showed Crimson Marker ×4 and exact coordinates; Evening Edition was
  readable and not sold. Scroll/drag commands on RunInfo and Settings did not
  move content through this control method and remain **UNVERIFIED**, not a
  confirmed game bug. Locked Obstacle IX copy (“Finish a Book to unlock it”)
  was observed as potentially misleading about same-Book progression; the
  proposed per-Book copy/AX fix is **verified** in Release: Obstacle IX exposes
  distinct AX title, LOCKED, Close obstacle details, power, and requirement;
  the copy reads “Finish Obstacle VIII in this Book to unlock Obstacle IX.”
  Close was hit and dismissed the popup. Unlocked obstacle details
  secondary-action remains unverified and is not a confirmed locked-state bug.
  Ordinary full-Book count remains **1/12**.

- Scoring-detail frames at 8fps (9.5–12.5s) show Turn points 0, Evening
  Edition +300 with the actual Bookmark +300 tag, BANKED +300, and score
  330→630, with no source-label overlap
  (`/tmp/numberclub-native-frontend-scoring-detail-20260907.png`). A broader
  1fps contact sheet is retained at
  `/tmp/numberclub-native-frontend-endturn-contact-20260907.png`. The focused
  native obstacle popup suite passed 12/12 in 16.214s
  (`/tmp/numberclub-native-popup-regression-20260907.xcresult`); Release rebuild
  succeeded (`/tmp/numberclub-native-popup-release-20260907.log`) and the
  reinstalled native popup copy/AX/Close hit passed. No frame-pacing or
  physical-device haptics claim is made.

## Resource incident — historical pause, bounded testing restored at 09:14

The original parallel/unbounded recipe remains prohibited. The repair evidence
below permits only short, supervised, single-simulator sessions. Book completion
requirements remain unchanged.

The user's resource concern supersedes the playthrough work. Do not restart
the native runners or parallel simulators using the previous recipe.

Confirmed in `/Library/Logs/DiagnosticReports/JetsamEvent-2026-09-07-071253.ips`
(07:12:52.81 local, 16,384-byte pages): the three NumberClubUIDriver-Runner
processes had reported footprints of 25.87, 25.51 and 24.68 GiB, totaling
76.06 GiB on a 48 GiB Mac. The three ProbablySudoku processes in that same
report were approximately 155, 165 and 123 MiB. These are the report's memory
accounting values, not a claim that 76 GiB was simultaneously resident in RAM.

`/Library/Logs/DiagnosticReports/NumberClubUIDriver-Runner_2026-09-07-072154_Daniels-MacBook-Pro.diag`
independently records PID 442 growing from 801.98 MB to 25.28 GB during its
sample interval and about 2.15 GB of file-backed writes during 48 minutes.
This identifies the test harness as the dominant resource consumer, not the
game process. It does not establish that the game is universally leak-free.

The harness runs one long synchronous XCTest command loop, repeatedly reading
the mailbox and capturing screenshots/accessibility hierarchies, without an
explicit per-command autorelease boundary or a memory watchdog. Retained
temporary/test-framework objects are a credible mechanism; the reports do
not identify the exact retained allocations. Three concurrent runners
amplified the unbounded growth. This was an orchestration/resource-budget
failure, not a reason to remove game artwork or animations speculatively.

Containment: no UI runners or xcodebuild processes remain active. The four
task-owned simulators (A, B, C and the focused regression simulator) were shut
down without erasing data. The pre-existing Save Regression simulator was
left untouched. App saves, results and screenshots remain available. The
unbuilt 12-hour driver extension was withdrawn; no replacement runner was
built or launched. The historical timeout is not a verified fix.

Before any future native playthrough: use only one runner, short batches,
an external process-footprint/system-pressure cutoff, and checkpoint-based
heavy captures. Validate memory stability in a small bounded profile first;
do not overlap native playthroughs with build/render gates. No Book-completion
claim changes as a result of this incident.

### Resource repair evidence — final gate completed at 09:13 local

The external test driver now drains an autorelease pool on every mailbox poll,
including idle polls; limits its command loop to 240 seconds and 40 commands;
and enables XCTest's 300-second timeout. A background self-guard checks its
physical footprint and supervisor liveness every 500 ms, exiting only the
runner at a 768 MiB trip threshold or after 270 seconds. The external supervisor
uses `proc_pid_rusage` physical footprint (not RSS), rejects overlapping UI
runners/builds, and stops on abnormal system pressure, missing measurements,
1 GiB runner / 4 GiB watched-process trip thresholds, 256 MiB new artifacts,
or a 300-second wall-clock deadline. These are sampled trip thresholds, not
instantaneous OS-enforced allocation ceilings. No game rules or saves changed.

Seven resource-policy regression checks pass. Both small driver builds passed;
no game build or render gate overlapped a native resource check.

- `/tmp/numberclub-bounded-resource-smoke-01.xcresult.resources.jsonl`:
  108.7 seconds, peak runner footprint 44.10 MiB. Monitoring `/bin/ps` timed out;
  the watchdog failed closed and stopped the runner/build, then shut down C.
  The result is interrupted, not a successful playtest. Its last unstarted
  read-only snapshot was preserved in
  `/tmp/numberclub-resource-stale-snapshot-HfiRYI/`.
- `/tmp/numberclub-bounded-parent-loss-02.xcresult`: deliberately killed only
  the recorded task supervisor PID 16673 after its runner was ready. Runner
  PID 16712 exited itself within 502 ms; xcodebuild 16689 subsequently exited.
  Expected test failure proves the parent-loss fail-safe, not a game failure.
  The stopped supervisor lock was preserved at
  `/tmp/numberclub-bounded-parent-loss-02.stopped-lock`.
- `/tmp/numberclub-bounded-resource-smoke-03.xcresult`: passed one bounded test,
  zero failures, 241.744 seconds. Completed 38 screenshot/AX snapshots plus
  one semantic navigation attempt and one successful coordinate navigation
  (40 commands total). Runner peak was 47.22 MiB, settling near 46.3 MiB;
  system memory pressure remained normal throughout. The loop ended by its
  deadline; the supervisor exited 0 and shut down C. The semantic `notHittable`
  response did not represent an ordinary touch failure: the observed button
  center tap succeeded. All receipts and resource samples remain preserved.

This verifies the scoped resource repair and permits resuming bounded native
gameplay. It does not establish unlimited-duration safety or complete a Book.
The parent-loss failure and early monitoring-timeout failure remain failures
in their test bundles; they are explicit fail-safe checks, not passed game tests.

### Bounded native gameplay resumed — 09:30 local checkpoint

An optimized Release rebuild (two build jobs, no native runner concurrently)
passed and was installed in place on C without resetting data. C now includes
the UI-14 margin fix. Version remains 1.0.1/build 10 locally; nothing was
uploaded to Apple or installed on a physical phone during this work.

- C-04 (`/tmp/numberclub-bounded-book-C-04.xcresult`) completed 27 recorded
  command receipts and exited 0 after 246.9 seconds total supervisor time.
  Runner peak 55.21 MiB; system pressure normal throughout.
- C-05 (`/tmp/numberclub-bounded-book-C-05.xcresult`) completed 30 recorded
  command receipts and exited 0 after 248.7 seconds total supervisor time.
  Runner peak 56.71 MiB; system pressure normal throughout.

The normal Volume 9 selection restored the existing run and Bookmarks. Native
Shop screenshot `1788761955690-f0ac780d-2a32-490a-8ec4-20cbb9e8758b` confirms
UI-14 fixed: the laurel drawing is visible only in the page margins, clear of
offer text/icons. The 55-coin Shop balance includes the previous 15-coin payout;
Peek was bought for 3, leaving 52, and was later activated through ordinary UI.

On the next relaunch, receipt `1788762445389-349bf63f-6220-4748-85f2-5345d6fc29b7`
confirmed all six placed Fog cells and the settled score of 800 on Turn 2/10.
The preceding immediate screenshot showing 0 was an animation capture, not
evidence of lost saved points. After further normal placements and Peek use,
the latest checkpoint is Level 2 Puzzle 3 (The Fog), Turn 5/10; receipt
`1788762625075-8727afae-e8a4-4596-9a99-175caa01e46b` is immediate after End Turn,
so its displayed 1,420 must not be assumed to be the final settled bank total.
Verify the settled/resumed total before the next move.

At this checkpoint no test runner, xcodebuild or ProbablySudoku process is
running; C shut down automatically and the user's pre-existing Save Regression
simulator remains untouched. No pending C commands are known; recheck before
the next supervised launch. Player C's dedicated log contains all gameplay
receipts. The all-12-Books objective remains incomplete; no Book has reached
final congratulations.

### Further bounded continuation — C-06

C-06 exited 0 after 249.0 seconds total supervisor time, with peak runner
footprint 53.96 MiB and normal system memory pressure. Normal reopening
verified settled score 1,860 on Turn 5/10 and the previous Fog placements in
`1788763118250-764eb318-a271-4514-b5ab-92ba6822d3ff`. The last completed
receipt `1788763242554-adb32cbd-2253-4db1-8c7e-7846ef62bdfe` reached Turn 9;
its immediate score display was 2,560. C-07 subsequently verified settled
2,660 on reopening, so these different timestamps are not save-loss evidence.

An unstarted selection command after C-06 ended was preserved, not replayed:
`/tmp/numberclub-C06-unstarted-K1ME96/1788763250477-66cdf842-e47d-443a-9e7b-a80a8660c380.json`.
Both the result and started journal were absent before quarantine; the old
runner/build had exited. No player save was changed.

The external public-UI deduction helper rejected Peek's visible `number 4,
clue` label. The exact receipt above reproduced the parser failure. Adding
`clue` to the existing `given|placed` alternatives restored the public grid
and ordinary deductions; masked/unknown labels still throw. A separate
read-only agent reviewed that the helper never reads saves, RNG or solutions,
never banks/tosses/claims rewards, and stops at a turn boundary. This is a
test-tool repair, not a game defect or a Book-completion claim.

### C-07/C-08 — ad recovery and Level 2 completed normally

C-07 exited 0 after 249.0 seconds total supervisor time, with peak runner
footprint 57.16 MiB and normal memory pressure. The immediate End Turn
capture displayed 3,300, but the settled failure receipt
`1788763703755-372a73b6-614c-4889-9bef-e3e46cb99519` shows 3,660 against
target 4,000. The player opted into the simulator test ad. Snapshot
`1788763793225-09d344d5-9e3f-41a3-ba94-c22eed4d77f6` shows “Reward granted”
and an enabled top-right Close button. The separate disabled outer “Close
Advertisement” element was not the only dismissal affordance; this was not a
confirmed stuck ad. No Get/install action was taken.

The supervised session ended before ad dismissal. C-08's normal Book reopening
restored the earned rescue at Turn 11/13 and score 3,660. Root compared all
81 public cell labels and the six hand cards against the last pre-ad board
receipt: both are identical, with hand 7, 3, 3, 3, 9, 1. The resumed receipt is
`1788763968638-be4a5886-0f1e-4a1e-9512-56809ce73dd7`. Public-deduction play completed
the Fog boss at 4,080/4,000 with two unused turns. Exact settled completion,
cash-out and purchase receipts are in the player-C log. Root also inspected
`1788763991421-5d96803b-2fc0-4213-b8b4-72199021a533` visually. Cashing out
raised coins from 52 to 64; Golden Marker cost 6, leaving 58. C-08 exited 0.
This is six completed puzzles / two levels in the current Volume 9 run, not
a completed Book. The Marker placement/next-puzzle flow is the next checkpoint.

Additional visual observations:

- **UI-15, tablet results spacing:** the iPad successful-results page separates
  its score and payout with an expanding spacer. The hosted real-Book baseline
  reproduced 340/344-point gaps for won/banked states
  (`/tmp/numberclub-results-spacing-before.xcresult`, two expected failures).
  Cap only that upper spacer at 48 points for regular width. The lower spacer
  keeps actions at the foot; compact/phone spacing stays unchanged. After
  verification is recorded below; the page is not otherwise redesigned.
- **UI-16, confirmed tablet placement-layout issue:** purchasing Golden Marker
  exposes a width-sized 9×9 picker in a much shorter scrolling slip. Native
  `1788764107838-0793f232-16c7-4182-ba67-fcd60cadefb6` shows only roughly six
  rows at once; bottom positions/instructions require scrolling. Source
  `MarkerPlacementSlip.swift` lets the square expand to the full tablet width.
  Fixed only at this picker: cap its width at 400 points and center it;
  narrower phones retain their available width. No placement rules, shared
  slip layout, save code or stock changed.

  The first static-render attempt omitted all ScrollView content and is not
  accepted as a product regression (`/tmp/numberclub-marker-fit-before.xcresult`).
  The corrected hosted-window baseline reproduced only the iPad issue: the
  occupied R9C9 cell and both footer phrases were absent; phone checks passed.
  `/tmp/numberclub-marker-fit-before-hosted.xcresult` retains that failure.
  The after-gate passed all 5 tests (BuffSlipPresentationTests plus
  ShopMarkerHandoffTests), zero failures/skips, in
  `/tmp/numberclub-marker-fit-after.xcresult`. Root visually inspected both
  phone and iPad attachments: the complete nine rows, bottom-right occupied
  cell and instructions are visible. The two-job optimized Release rebuild
  passed (`/tmp/numberclub-marker-fit-release.log`) and was installed in place
  on C. C-09's native Marker picker hierarchy places all nine rows and the
  footer inside the visible slip (`1788765196562-731cd811-3198-432c-bfca-62987c866d66`).
  Its matching screenshot still captures the Shop during the arrival fade,
  so the visual proof remains the two inspected hosted-render attachments,
  not that native PNG. The subsequent placement returned normally to Shop.
  No phone/store deployment.

### C-09 — Level 3 reached, resource bounds retained

C-09 exited 0; XCTest reports 218.3 seconds for its bounded command loop.
Peak recorded runner footprint was 58.03 MiB, with normal memory pressure.
The saved run retained 58 coins, Morning Edition, Op-Ed Column and Golden
Marker. One 2-coin reroll, Sports Section for 5 and Emerald Marker for 7
left 44 coins. The player continued to Level 3 Puzzle 1 and made six verified
public-deduction placements. The final completed receipt
`1788765301733-1babd4b1-283b-45c4-8c52-2862b0167dd0` shows Turn 2/10,
score 630. This remains six completed puzzles, not a completed Book.

After the runner terminated, three unstarted commands were retained in a
recoverable `/tmp/numberclub-C09-unstarted-*` folder before the next launch:
`1788765303059-fa2dbf96-add5-420f-b418-c7bac9e1544f`,
`1788765308656-c22029ed-90d0-4ee5-b4a1-9c1f7e5c2279`, and
`1788765359759-ea884d6c-3794-4960-af9e-0f5d9c4c2233`.
Neither result nor started journal existed for those commands; none was
replayed into the resumed game.

C-10 also exited normally, with peak runner footprint 61.64 MiB and normal
memory pressure. Public-only deductions completed Level 3 Puzzle 1 at
4,250/4,000 with six unused turns and a 15-coin payout preview. Root inspected
the settled screenshot `1788765767119-5c927b23-8281-49ba-9160-95ebc280bf8a`:
the 44-coin balance is still pre-cash-out. The post-deadline Cash Out command
`1788765785361-4251e666-35e7-406e-9711-107902382593` has neither a started
journal nor result and was quarantined after terminal exit, not replayed.
This is seven completed puzzles in Volume 9; no full Book is complete yet.

### Results follow-up — UI-15 and UI-17

The first after-gate passed the new iPad spacing checks but exposed a separate
real narrow-phone heading truncation: `PUZZLE COMPL…` in
`/tmp/numberclub-results-spacing-after-attachments/A7BDE425-EA34-4B1D-9FE6-2994E6F98D70.png`.
This is UI-17, not dismissed as an OCR error: root inspected the actual image.
Only the results heading now scales down when its single line needs to fit.
The shared typography, board, other copy and payout/actions are unchanged.

The final gate `/tmp/numberclub-results-spacing-after-02.xcresult` passed all
16 tests, zero failures/skips: BookVictoryRenderingTests, KeepFillingResultsTests,
and the narrow-width large-score results test. Both iPad won/banked pages retain
their exact frozen run while keeping the payout within 120 points of the score
and actions near the bottom. Existing phone actions, full-board Keep Filling
guard, no-double-payout behavior and final-Book routing pass. Root inspected
the fixed phone heading and iPad banked attachment. The two-job, arm64-only
optimized Release rebuild passed (`/tmp/numberclub-results-spacing-release.log`)
and was installed in place on C. Native C-11 receipt
`1788766584755-f700a38a-d912-42a3-9e19-e4dfd7c70e5c` preserved the real
4,250/4,000 win, six unused turns, 15-coin payout preview and 44-coin balance.
Root inspected its PNG: the payout sits below the score and the original
actions remain at the foot. The corresponding AX bounds put Base at y294.8
instead of y538.2; Cash Out remains y1100. No saves/rules changed. These
tests and this retest do not complete a normal Book.

C-11 continued normally: cashing out produced 59 coins, buying Paper Route
for 5 left 54, and 12 public-deduction placements reached Level 3 Puzzle 2,
Turn 3/10. The player's immediate final screenshot showed 800 mid-animation;
root's later read-only stop receipt
`1788766727911-83994b7a-0cde-402c-9013-5639c27f942d` verifies the settled
score is **1,730/6,000**, not 800. There were 37 player commands plus the
root stop (38 total; the extra log receipt is initial readiness), no unresolved actions, and normal exit 0. Peak runner
footprint was 57.71 MiB; system memory pressure stayed normal. No task runner,
build or player simulator remained active after shutdown. Seven puzzles are
complete in the current Book; none of the 12 Books is fully played yet.

### UI-18 — interrupted cash-out receipt fixed (source/hosted and regression evidence)

The new banked fixture also exposed a separate receipt issue, not a duplicated
reward: 5 coins plus an actual 15-coin payout becomes balance 20, but recreating
the banked Results model prints 17 because its fallback preview recalculates
interest from that new balance. The hosted banked attachment preserves the
evidence. `Actions.cashOut` computes before adding coins; `GameModel.lastPayout`
is transient, whereas its game observer persists the cashed-out state. An
interruption before the subsequent Open Shop call can therefore restore to
Results with no saved receipt and the wrong fallback preview.

This is a source-confirmed persistence/display risk with hosted evidence, not
a normal native interruption reproduction. No coins are paid twice in the
existing guard tests. A focused before gate reproduced both failures:
`/tmp/numberclub-banked-receipt-before.xcresult` (2 tests, 2 expected failures).
The original receipt is now stored on `PuzzleState.bankedPayout` in the same
cash-out mutation as the awarded coins. A banked Results preview reads that
receipt, never recalculates interest from post-payment coins, and never pays
again. Normal unpaid previews are unchanged. The optional Codable field keeps
older saves compatible; a legacy paid save has no invented receipt and can
continue to its Shop. Opening the Shop discards the previous puzzle/receipt.

`/tmp/numberclub-banked-receipt-after.xcresult` passes all 15 selected tests:
6 KeepFillingResults, 8 FinalBookRouting, and the all-Books final-receipt
identity matrix. Coverage includes full-clear bank, frozen/resumed receipts,
old paid/unpaid saves, unchanged board/hand/Book/obstacle/RNG, duplicate cash-out
rejection, and final congratulations routing. These are controlled fixtures,
not evidence of a normal native interruption or an end-to-end Book completion.
The two-job arm64-only Release simulator build passed in
`/tmp/numberclub-banked-receipt-release.log` and was installed in place on C
without erasing data. No Apple upload or physical-device installation occurred.

### C-12 — saved gameplay checkpoint and command-count reconciliation

Normal resume restored Level 3 Puzzle 2 at 1,730/6,000. Public deduction play
reached Turn 5, score 3,690/6,000, 54 coins. Root inspected the screenshot
`1788767038999-8567941f-ad11-4e48-b542-3d1890545db9`; the following final
receipt `1788767040340-20584d3c-f3ed-4cbf-8dc4-d0cd511f61e7` is a card
selection, not another confirmed placement. C-12 exited 0 at timestamp
1788767042417. Runner peak 60.66 MiB; system pressure normal throughout.

The driver completed 40 real commands plus its initial ready receipt (41 log
lines). C-09 and C-10 likewise have 40 real commands, not 41. C-11 has 38,
not 39. Two C-12 commands were queued after the cap, neither had a started
journal or result, and neither was replayed. They were moved recoverably to
`/tmp/numberclub-c12-unstarted-Fm88wj/` after runner termination. No save was
changed. The external client now refuses queuing after 36 commands/210 seconds,
reserving a stop window before the driver's unchanged 40-command/240-second
limit. It checks live matching watchdog/runner processes, ready freshness
against the current resource log, and unresolved commands from any session.
All 10 pure Node preflight tests pass. Root also verified a no-runner send is
refused before writing a command. No driver rebuild or relaxed resource cap.

### C-13 — eighth puzzle completed normally

The updated Release restored the existing 3,690/6,000 run. The settled native
result `1788768155936-d58e6f76-cff3-49da-99df-09d1cfc7d6fa` shows 6,200/6,000,
four unused turns, and a 16-coin payout: Base 5, Unused 4, Interest 5, Paper
Route 2. Root inspected the PNG and AX. Cash Out reached the Shop at 70 coins;
Copper Marker cost 5, leaving 65. Its sold state is verified, not yet its exact
board coordinate. Root opened Help Wanted's +1 Hand details at
`1788768252494-db846a07-350f-459c-94ac-688fe90d7efd`, but did not purchase it
before this batch ended. The late stop was refused by preflight without
writing a command; the driver's deadline ended the session normally.

C-13 completed 33 real commands, exit 0 at 1788768285439, no unresolved mailbox
actions. Runner peak 61.71 MiB; app peak 328.22 MiB during shelf opening and
approximately 112 MiB at the ending Shop; system pressure stayed normal.
No timed boss was started. Current normal Volume 9 progress is **8/27 puzzles**.

### C-14 — timed-boss preparation and purchase persistence

Normal reopening retained the Shop's 65 coins and Copper's sold status. Help
Wanted was purchased for 4; native receipt
`1788768447136-30704133-cec5-46b0-b50e-1a354c88e1a9` verifies the fifth
Bookmark and 61 coins. Continuing reached the Level 3 Boss briefing. Root
inspected the successful stop receipt
`1788768496256-a5bed478-7c87-43e4-9561-2078287b3d11`: Round 3/3, Tik Tak,
and both visible/accessible four-minute instructions. No boss clock had begun.
C-14 exited 0 after 10 real commands, no unresolved actions, peak runner
50.49 MiB, normal memory pressure. No book completion is claimed.

Copper evidence correction: C-13 command `1788768191797-96395bba-dafa-4d2e-a193-cfbfbf652655`
was a normal coordinate tap at (.71, .67), not a snapshot. The preceding
picker AX bounds put this inside R9C9. The return to Shop is consistent with
successful placement; the next public board will verify the assigned square.
Do not infer an unplaced/lost marker from the abbreviated player log.

### C-15 — timed boss attempt; player-workflow correction

Volume 9 remains **8/27**, no Book complete. The timed Tik Tak boss was started
normally. Final public receipt
`1788768832345-051f3656-f0db-4490-bcaa-c0c2d2cc39ec` shows Turn 5/10,
900/8,000 and 132 seconds **at capture**, not necessarily at shutdown.
Copper's R9C9 position is now confirmed in native board AX. The supervisor
ended normally at 1788768897797: 27 real commands, no unresolved commands,
peak runner 56.22 MiB, pressure normal.

The player log incorrectly claimed a Toss. Read-only command/AX audit proved
that Toss was tapped before selecting a card, which displayed `Pick one number
to Toss`; selecting 2 afterward did not commit the Toss. End Turn followed,
with the allowance still at 4. Corrected the player log. No app defect is
claimed from this testing mistake or from the helper exhausting its limited
public pencil-deduction repertoire.

### Throughput improvement requested by user

Measured C-15 first queued command to last receipt: **156.282 seconds**;
23.626 seconds waiting for UI commands, **132.656 seconds between commands**
(approximately 85%). Thus agent round trips/decision pauses, not raw game
response, dominated this batch. This is not a device FPS benchmark.

External harness now builds with a bounded `place-card` command (the same two
ordinary UI taps with live public turn/card/cell/geometry validation between
them), optional AX-only intermediate receipts, and action/observation timing.
It still journals before acting and never replays interrupted actions. The
batch counts as two actions against unchanged limits: 36 normal client units,
40 native units, 240 seconds, with independent memory/parent watchdogs.
All 12 preflight, 7 resource-policy and 11 fast-loop tests pass (30 total).
The CLI regression explicitly covers macOS `/tmp` → `/private/tmp` resolution;
its initial import-safe entrypoint had silently skipped CLI execution. Native
validation below also caught a false XCTest `isHittable` result on visible Hand
cards. The batch now uses the already-working normal coordinate taps while
retaining live turn, label, geometry, enabled and post-selection checks.
Neither correction changes app code, game rules, scores, timers or saves.

#### C-16/C-17/C-18 pilot outcomes (not completed Books)

C-16 opened the saved Tik Tak run, then stopped while finishing the harness.
Last public receipt `1788770039932-207a4039-323d-4855-bb2d-5a4676646ef9`
showed 38 seconds remaining; runner peak 52.49 MiB, 7 commands, exit 0.
This preparation still had human/model pauses and is not speedup evidence.

C-17 confirmed two correctly ordered Tosses (allowance 4→3→2) and End Turn
5→6. The old timed attempt then expired during another interaction. Root
inspected `1788770296190-2a8c9fe9-1650-4c0c-bcb0-f9f5b4522db5`: **Book over,
1,000/8,000, Out of time**. No Book completion. The helper stopped and captured
the terminal screen; subsequent loop policy explicitly records phase changes
during actions without retrying. The 8/27 count belongs to this ended attempt.

C-18 reopened Volume 9 normally to a fresh Level 1 run (5 coins, no items),
then stopped at the false `isHittable` guard before any placement. The observed
grid/Hand stayed unchanged. This is a harness pilot failure, not a gameplay bug.
Its supervisor exited 0 with no unresolved command. No diagnostic action was
replayed. The coordinate correction was built only after C-18 was terminal.

#### C-19 — native faster-loop validation passed

Normal resume restored the fresh Volume 9 puzzle. **10 verified placements in
19.181 seconds**, measured first placement enqueue to last placement receipt:
`1788770763546-6c918cfe-c923-490a-b5c0-c5cd78b5c1e1` through
`1788770781146-94b86946-17fd-4121-9952-0dd916a22a51`.
The helper crossed an automatic hand/turn boundary, using only public naked
and hidden singles, with a per-move proof and before/after receipts. No Toss
was needed. Final full screenshot/AX
`1788770782933-bef8ed29-ae69-4567-a213-b491227cd14c` shows Turn 2/10,
330/1,000 banked, +320 queued, Hand 2/7, four Tosses, 5 coins. Root visually
checked this checkpoint. This is throughput proof, not a completed puzzle.

`/tmp/numberclub-bounded-book-C-19.xcresult` exited 0 at 1788770784788:
18 commands / 28 weighted units, 8 screenshots instead of capturing every tap,
**55.83 MiB peak runner**, normal pressure, no unresolved commands. All task
runners were terminal afterward. Preserve the new normal run for continuation.

Use `/tmp/numberclub-ui-driver/visible-turn.mjs puzzle C` by default once an
ordinary puzzle is visibly ready. The loop handles deductions, selected-card
Toss (verifies decrement), and End Turn (verifies transition). It stops before
the session budget, on unknown/masked UI, results, or uncertain transport; it
never retries an uncertain action. Initial/final/phase screens retain full
visual checks. Shops, buffs, clues, purchases, boss strategy, loss/restart and
completion/unlock checks still require deliberate public-UI decisions. Do not
mistake this helper for a full autonomous Book player or hidden-state solver.

### Verified product evidence carried forward during the pause

### C-20/C-21 progress and remaining throughput bottleneck

C-20 added five normal placements, reaching Turn 3, 740/1,000. Its total
144.62 seconds included 123.64 seconds between commands: model/navigation
deliberation, not game animation, remained the dominant bottleneck. Runner
peak 55.42 MiB; normal exit and pressure, no pending commands.

Root batched the ordinary resume in C-21. Three public deductions completed
the fresh attempt's first puzzle: `1788771522028-ecf8447e-492b-48e1-a3ba-5d8772aef9f6`
shows 1,210/1,000, seven unused turns, payout 12, Cash Out available. A next
placement proposed during the delayed win transition was rejected as stale;
it was not retried. Supervisor exit 0, peak 54.88 MiB, normal pressure, no
pending commands. Current run: 1/27 puzzles; completed Books remain 0/12.

### C-22 — one complete puzzle in the faster bounded workflow

The test-only weighted-action cap is now 120, with helper budget 108. Time,
memory, single-runner, receipt-journal and shutdown safeguards are unchanged.
Focused Node gates pass 30/30; external XCTest driver build passed. Historical
40-unit memory validation remains preserved rather than relabeled.

C-22 cashed out, bought The Sunday Supplement and Paper Route from actual
offers, then completed Level 1 Puzzle 2 at 2,040/1,500. Eighteen public-UI
deductions took 33.731 seconds; settled win appeared after 36.429 seconds.
Total session including resume and Shop was 178.75 seconds, 56 weighted
actions, peak runner 58.49 MiB, normal pressure, no pending commands, exit 0.
This proves productive native work above the old 40-unit cap. It does not
prove the full 120-action boundary natively or complete a Book. Current run:
2/27 puzzles, Cash Out pending. Raw win-transition error recorded below.

### C-26–C-36 — reconciled rapid continuation (13/27, no full Book)

- C-26 settled Level 1 Boss/The Critic at 2,490/2,000 in
  `1788774298589-93977d6c-50da-4582-b0ff-844b657a5e5d` (3/27). C-28 settled
  Level 2 Puzzle 1 at 2,460/2,000 in
  `1788774605607-1d08e831-2c49-4233-bfcd-fecf1daae42f` (4/27), after visible
  purchases Morning Edition (4), Puzzle Corner (7), Copper Marker (6), R5C4,
  and Litmus (4).
- C-30 settled Level 2 Puzzle 2 at 3,700/3,000, 7 unused turns, payout 14
  (`1788775152950-89bee4e2-e008-4183-b81e-4adef78aecc2`), then reached the
  Shop at 23 coins (`1788775211490-4fca9684-8c45-4fb3-b425-d4dac010b27f`).
  C-29's 2,180 was intermediate, not a loss.
- C-31 then settled Level 2 Boss/The Deadline at 5,680/4,000, 7 unused,
  payout 13 (`1788775628945-b22cb973-a001-40dd-b4db-a46135ca08df`), cashed
  out 16→29 (`1788775631198-13d63209-dc7d-4810-ab14-c2300b4b2356`), and
  settled Level 3 Puzzle 1 at 5,060/4,000, 8 unused, payout 15
  (`1788775663222-42e6a9aa-63b4-4a57-a726-093bd0ca6069`). Cash Out remained
  pending and was not claimed completed.
- Weighted timing: C-26 56.9s/26, C-27 46.9s/14, C-28 201.2s/87,
  C-29 240.2s/43, C-30 240.1s/12; C-29 and C-30 included roughly 59s and
  164s idle after the last useful UI receipt before wall expiry. C-31 stopped
  explicitly after the settled snapshot at 145.885s active/77 weighted actions
  (57 commands), with 59.60 MiB peak and normal pressure.
  These are puzzle-level wins only; no full Book, unlock, or return/resume
  proof is claimed.

- C-32 resumed at the Level 3 Puzzle 1 Cash Out, settling 29→44 coins in
  `1788775853287-be7662c0-b77d-4763-8874-b97b233a76fa`, sold Morning Edition
  for 2, and bought Rolling Presses for 7 plus Lucky Dip for 3 (36 coins).
  Level 3 Puzzle 2 settled at **13,320/6,000**, 8 unused turns, payout 16
  (`1788775981789-22ce2633-2c78-418a-80a5-e1cf552a55c6`), reaching 8/27.
  Cash Out to 52 coins was `1788775983805-c8b165a5-eef0-42f8-9d87-85018e4e14e7`;
  normal Continue entered Level 3 Boss/The Editor with one fewer hand card at
  `1788775985803-9d9ac9e2-6218-45b6-8993-bb62f5b837bf`. Boss start and the
  confirmed 1@R8C6 placement led to Turn 1/10, score 0/8,000, hand 7,4,1,2
  at `1788776039822-66e2f0cf-114f-4e79-ac22-7630519cc546`. A late 9@R3C4
  attempt coincided with target-reaching animation; it was not confirmed, but
  no error toast or game failure was observed. No full Book proof is claimed.

- C-34 resumed normally and settled Level 3 Boss/The Editor at **10,890/8,000**,
  7 unused turns, payout 17 (`1788776382002-480bcf5f-17dd-45f3-815b-0fb347a6ce6a`),
  then cashed out 52→69. Golden Marker was bought and placed at R5C6
  (`1788776433806-7608b00c-d210-4452-a64f-0cce5c868148`); the public AX
  receipt `1788776503071-bfbe72be-9679-48e9-ae08-b596fa198dd1` confirms
  Copper R5C4, Golden R5C5 and R5C6, and Emerald R5C7. After a reroll, Puzzle
  Corner was sold for 3 and Letters to the Editor bought for 7; Emerald was
  placed at R5C7 (`1788776498301-7d091796-6ee3-4f5c-9b8b-e90e22e9605e`),
  leaving 50 coins.
- C-34 then settled Level 4 Puzzle 1 at **12,690/8,000**, 8 unused turns,
  payout 18 (`1788776531754-235bc264-8985-42ba-9369-06632cfa01af`), reaching
  10/27. It was not cashed out in that batch. C-33's externally interrupted
  expiry produced no gameplay evidence and is not counted. No full Book proof
  or unlock/return/resume proof is claimed.

### UI-20 — rapid input during win transition shows internal error (fixed; native retest passed)

Final screenshot/AX `1788771956090-8c131d9a-cc81-49de-b094-079229ceab3c`
shows Puzzle Complete 2,040/1,500 with a literal `puzzleNotPlayable` toast.
The preceding proposed placement (`1788771953948-b7139b42-c24a-4a7a-82dd-51a3a4d8dd64`)
was sent against the still-visible board while the earned win was settling.
No successful placement is claimed for that command. Unlike C-21's rejected
stale-UI precondition, this event reached the app and exposed an internal
error to the player.

`GameModel.tapSquare` and direct `place` now ignore input outside `.playing`
and `.keepFilling`, before changing game/selection/message state. Active
errors and engine validation remain intact. The direct-place guard deliberately
does not bind/shadow `puzzle`: its post-placement score presentation must read
the new banked score, not a pre-placement value.

New PuzzleSelectionTests cover terminal won/failed/cashedOut no-ops, valid
playing/keepFilling placements, and automatic final-card post-banking score.
The first gate failed to compile a test fixture with an inaccessible setter;
the fixture now uses legitimate public transitions. A later test launch failed
with Simulator Busy, before running tests, and was retried after verifying
the process was terminal and booting the regression simulator normally.

- `/tmp/numberclub-terminal-input-after-02.xcresult`: 27 passing input,
  results and briefing tests before the final score-shadow correction.
- `/tmp/numberclub-terminal-input-score-after-02.xcresult`: 18 passing
  input/results tests including the new post-banking-score regression, on
  the final non-shadowing implementation. No native playthrough overlaps.
- Native C-26 rapid input changed to the results page without the internal
  toast. Settled receipt `1788774298589-93977d6c-50da-4582-b0ff-844b657a5e5d`
  shows 2,490/2,000; C-28 repeated the normal rapid win without that error.
  No Book completion is implied by these puzzle-level checks.

### UI-19 — clipping ticket exposes nested semantic buttons (fixed; native AX retest passed)

Native briefing AX `1788770524900-3e0b4805-e378-48d0-a04a-2d95313ab663`
contains an outer `Take Coupon...` Button and an inner `Clipping on offer...`
Button for the same ticket. `ClippingOfferTicket` wraps a native Button in
an additional accessibility element/button trait. This matches the already
corrected Shop offer pattern. Removed the redundant accessibility element and
button trait, retained the native Button's custom label/hint and added stable
identifier `briefing.clipping`. No visuals/animation/action changed. Existing
BriefingBoundsTests passed in the 27-test gate above. Native C-28 briefing
`1788774562278-600ae0a3-48a6-4265-b3f6-b63b99b6f288` exposes exactly one
`briefing.clipping` Button with the take/skip label; no nested ticket Button.
The optional skip was not taken on this run. VoiceOver interaction is not claimed.

### UI-21 — excessive iPad results whitespace (native pass)

The initial C-26 capture showed excess whitespace, but the settled C-47 Results
capture showed the updated board preview, readable actual blanks, and footer.
UI-21 native visual status passes; no claim is made that every device/layout
has identical spacing.

### UI-22 — overlapping score attribution during fast beats (native attribution pass)

Native C-28 screenshot `1788774736164-0807c525-d1b3-4838-a519-1969ac37990f`
shows “The Sunday Supplement” and “Added to queue” printed over each other,
with their values also overlapping. ScoreMeter's queue spring reaches the
same fixed-height attribution line when a beat replaces another beat/queue.
Root scoped a nil animation transaction to that line only. The staged event
timing, rolling total, progress ruler and score calculation are unchanged.
Read-only review confirms the scope includes both source changes and beat/nil
branch replacement. The Release change was built and installed; C-49's 12-second
native clip/contact sheet shows sampled attribution labels readable as single
lines without overlap. This is not a blanket 60fps or device-performance claim.

UI-14: page marginalia intruded into the Shop offer reading column, visibly
crossing the Paper Route icon/text in native C snapshot
`1788752870710-3ac8faa2-cb80-4c59-8014-13c406623ea1`. The fix confines decoration
to the existing physical page padding, preserving the content layout. The
regression failed before the fix and the after-gate passed all 10 tests:
`/tmp/numberclub-marginalia-column-after.xcresult` (BookPresentationThemeTests
and ShopOfferCardRenderingTests). All 12 Book themes, phone/tablet widths and
two animation times are covered. C was subsequently updated in place, and
the bounded C-04 session above supplied native retest evidence.

UI-12/UI-04 native evidence predating the pause: C bought Paper Crane (43 to
40 coins), showing one sold Shop button and one HUD Buff button in snapshot
`1788752870710-3ac8faa2-cb80-4c59-8014-13c406623ea1`. The ordinary Buff detail
and Use control are in `1788752928061-65626ec2-eb21-41c0-aba2-f4d4e4273d39`;
after Use, the Buff slot cleared in
`1788752935897-3915bb0a-e739-43c3-8d2f-e998e5fd64a5`. This confirms a real
consumable activation, not merely a purchase; it is not an actual VoiceOver
session. C then won Level 2 Puzzle 2 at 3,960/3,000, recorded in
`1788753156083-99c5ad20-2ba9-43d6-9ca7-d2c6240233f0`. No Book is complete.

## Purpose and evidence rule

This is the durable ledger for native, ordinary-UI playthroughs of all 12
Books. A Book is **PLAYED** only when a normal player reaches its final
congratulations leaf in the native UI and evidence records the Book identity.
Engine tests, SwiftUI render tests, deterministic QA fixtures, guide captures,
partial runs, and source changes are not playthrough evidence. No completion is
invented from those sources. Earlier ledgers remain unchanged.

Audit baseline: 2026-09-07. Existing native evidence was inspected read-only:
`docs/full-book-playtest-2026-09-05.md` records one operator-controlled Volume 1
run paused at Level 5, Puzzle 1 (12/27 puzzles); it explicitly says the Book
was not complete. `docs/book-completion-validation-2026-09-06.md` and the
progression/victory tests verify implementation with fixtures and explicitly
state that they are not another full-book playthrough. Focused recordings in
the learning-guide and UI validation docs are feature checks, not full Books.

## 12-Book matrix

| Volume | Book ID / title | Native normal-UI final congratulations | Unlock/return/resume | Status |
|---:|---|---|---|---|
| 1 | `probably` / You’ve Got This, Probably | Not evidenced | Not evidenced | **NOT PLAYED** (partial native run only) |
| 2 | `slightlyHarder` / Slightly Harder, Sorry | Not evidenced | Not evidenced | **NOT PLAYED** |
| 3 | `noPressure` / No Pressure, Obviously | Not evidenced | Not evidenced | **NOT PLAYED** |
| 4 | `bites` / This One Bites | Not evidenced | Not evidenced | **NOT PLAYED** |
| 5 | `genuinely` / Good Luck. Genuinely. | Not evidenced | Not evidenced | **NOT PLAYED** (partial native runs and restarts only) |
| 6 | `snackBreak` / This Calls for Snacks | Not evidenced | Not evidenced | **NOT PLAYED** |
| 7 | `trustMe` / Trust Me, I Guessed | Not evidenced | Not evidenced | **NOT PLAYED** |
| 8 | `overthinking` / Professionally Overthinking | Not evidenced | Not evidenced | **NOT PLAYED** |
| 9 | `smallVictories` / Small Victories, Big Ego | Native complete | Native complete | **COMPLETE** — C-51 final congratulations, 9/9 levels and bosses, Obstacle II ready |
| 10 | `rainyDay` / Panic, But Economically | Not evidenced | Not evidenced | **NOT PLAYED** |
| 11 | `secondThoughts` / On Second Thought, Nope | Not evidenced | Not evidenced | **NOT PLAYED** |
| 12 | `wellEarned` / I Deserve a Biscuit | Not evidenced | Not evidenced | **NOT PLAYED** |

The Book IDs and ordering are the canonical `Book` cases in
`Engine/Sources/NumberClubEngine/Book.swift`. “Not evidenced” is intentional;
it does not mean the implementation is broken.

## Player B preparation (Volumes 5–8)

Public player-facing definitions in `App/Books/BookEdition.swift` and the
catalog are the planning source; no live saves, hidden solutions, or QA
overrides are used.

| Volume | Benefit to plan around | Rational inventory posture |
|---:|---|---|
| 5 — Good Luck. Genuinely. | +1 Toss (5 numbers per puzzle) | Treat the extra toss as flexibility; buy a Bookmark/Buff only when its visible effect helps the current route or boss. |
| 6 — This Calls for Snacks | +1 coin per completed box | Prefer placements that complete boxes when score/board evidence supports them; retain enough coins for essential Buffs/Markers. |
| 7 — Trust Me, I Guessed | First mistake free each puzzle | Do not deliberately spend the protection; use normal deduction and record any genuine wrong placement and its recovery. |
| 8 — Professionally Overthinking | +10 per correct placement | Favor reliable correct placements over speculative spending; document any sale/replacement through the visible hold-drag UI. |

For each assigned Book, player B will log all 27 puzzles, Shops, bosses,
failures/restarts, and the final congratulations leaf. No status changes occur
until root receives native evidence from the confirmed simulator/UI channel.

## Native session 1 — rack/accessibility investigation

Three fresh, isolated simulators received the optimized Release app (1.0.1,
build 10, current working tree), with no launch arguments or QA features:

- A: iPhone 17 Pro, `D04D3836-357E-4E92-811D-6D14E3BA1E01`, Volumes 1–4.
- B: iPhone 16 Pro Max, `E2CF3ABE-C90C-4CEB-99B0-91AC298A9815`, Volumes 5–8.
- C: iPad 11, `A86913BF-BC93-439A-A31B-6D1300899F59`, Volumes 9–12.

All three reached the rack through ordinary onboarding/menu controls. A selected
Volume 1; B and C attempted their visible middle/bottom covers. No puzzle was
completed, and no save data was read or modified to advance a run.

The XCTest screen-reading operation then timed out while inspecting the focused
rack. A's direct screenshot `/tmp/numberclub-player-A-stall.png` shows the Book,
benefit plaque and Open button successfully presented. This is not evidence of
an ordinary animation freeze. The diagnostic sample
`/tmp/numberclub-player-A-ax-sample.txt` (00:50:52, September 7) captured all
2,142 main-thread samples in an accessibility snapshot; SceneKit node frame
projection and its scene mutex dominated. The existing UIKit hidden flag did
not keep decorative SceneKit descendants out of XCTest's hierarchy.

The initial SwiftUI ignore/hide candidate did not prevent the mesh enumeration
and was removed. The verified fix sets the decorative SCNView's public UIKit
`automationElements` to an empty array, retaining its existing accessibility
hidden flag and all native overlay controls and touch behavior. The native menu
snapshot dropped from roughly 2,600 entries to 27; normal book selection and
opening then succeeded without the snapshot timeout. Evidence:
`/tmp/numberclub-ui-A/results/1788732216949-06f3c92a-32e0-4f51-9b26-db6a0992fb8b.txt`
and `/tmp/numberclub-ui-A/results/1788732379854-0aadd6c8-4b52-48ee-92ed-10a2014bd055.{txt,png}`.
The optimized Release rebuild passed; 21 focused rack/selection tests passed
with zero failures in `/tmp/numberclub-rack-accessibility-gate.xcresult`.
Initial failed/interrupted runner evidence remains in
`/tmp/numberclub-native-player-{A,B,C}-01.xcresult` and each
`/tmp/numberclub-ui-{A,B,C}/results` directory. It does not count as gameplay.

The external UI driver now journals started/completed commands, preventing an
uncertain placement or purchase from replaying after a runner restart. This
changes only test tooling; not the game or its saves.

### First actual gameplay, not completed Books

All three players subsequently opened a real first puzzle: Volume 1 on A,
Volume 5 on B and Volume 9 on C. No final congratulations has been reached.
On B, an apparent number-selection/placement failure was traced to inaccurate
test coordinates: one tap hit the given 2 in R7C6. Using the observed card and
cell bounds selected 3 and correctly placed it in R7C5, queuing +30 and spending
that card. Evidence:
`/tmp/numberclub-ui-B/results/1788732790302-7b689f3c-f038-40f3-9879-daef23adfa5e.{txt,png}`.
This is not recorded as a proven ordinary-touch game defect. Semantic XCTest
`notHittable` results remain distinct from actual coordinate-tap behavior.

## Issue ledger

Only observations from actual native interaction are listed as observed. Cause,
fix, and retest remain open until verified in a later native run.

| ID | Observed issue / evidence | Cause | Fix | Retest evidence |
|---|---|---|---|---|
| UI-01 | Non-Boss page exposed unrelated hidden Boss accessibility text (“The Deadline …”) during the paused Volume 1 run. | The old invisible Boss placeholder retained semantics. | Existing `BossStampReservation` uses empty typography with `accessibilityHidden(true)`; no duplicate edit. | Height/render regression exists in BriefingBoundsTests; ordinary C puzzle receipts no longer contain the false Boss. Targeted VoiceOver retest remains open. |
| UI-02 | Paper Crane Shop description visibly truncated (“rest of the Pu…”). | Constrained offer copy lacked an explicit route to the full description. | Existing `OfferDescription` shows full copy where it fits and a visible Details fallback otherwise; catalog copy is intact. | Narrow-width rendering coverage exists. Native iPad Paper Crane offer and sold receipts `1788752846501-acc31829-c831-46a4-876e-a01db28ff157` and `1788752870710-3ac8faa2-cb80-4c59-8014-13c406623ea1` expose full copy. Narrow-phone native retest remains open. |
| UI-03 | Native Item details title appeared white on cream sheet. | Inherited navigation/title styling conflicted with paper. | Existing details navigation styling forces readable paper colors. | Root visually verified default-theme receipt `1788752433182-7f33f356-02f1-445b-a571-d917701f0d95`; dark-game hosted test also exists. Not proof for every cosmetic theme. |
| UI-04 | Sold Shop cards exposed duplicate uppercase and ordinary-case accessibility buttons. | Extra accessibility grouping wrapped an existing native Button. | Directly label the single native offer Button, retaining its whole-paper hit shape. | Eight focused tests passed. Native unsold hierarchy/coordinate details tap verified; C09 `1788765246233-08fe2184-cac7-4573-92fd-b63368b5a326` exposes exactly two sold Buttons for the two sold offers (Sports Section and Emerald Marker), one each. No general VoiceOver audit claimed. |
| UI-05 | Earlier Run Plan preview omitted upcoming Boss name/power from its combined accessibility label; actual Boss briefing did expose them. | Combined route semantics omitted known Boss metadata. | Existing `RunRouteStrip.accessibilitySummary` includes the committed name and full power; every-Boss semantic test exists. | Native ordinary Level 3 briefing `1788765257720-dd6789a9-01e8-4f15-83b0-763885e6710e` announces Tik Tak and “Four minutes for the whole Puzzle” with Current stop: Easy. |
| UI-07 | Level 1 Boss briefing expanded into HUD/Bookmark row on phone (recorded screenshot in prior ledger). | Fixed-height route content overran constrained page bounds. | Existing constrained briefing layout has phone/tablet bounds coverage in BriefingBoundsTests. | Source/tests are present; a targeted updated native phone Boss/HUD overlap retest is still required. |
| UI-08 | Historical asleep-state accessibility omission and a possible “FIRED”/next-sleeping-index timing mismatch. | Current source already exposes the asleep AX value and filters activation by sleeping index; timing still needs an actual encounter. | Existing implementation retained; no duplicate change. | Native sleeping-state/activation timing and actual VoiceOver remain unverified. |
| UI-09 | Historically, selling was not discoverable from owned-item details. | Current source already supplies a visible Sell button, refund, and named accessibility action, guarded against stale inventory. | Existing implementation retained; no duplicate change. | Native C receipts `1788735116267-38eb21db-b8b7-41ab-a213-f0ef100580d5` and `1788734884432-12e1509e-43f8-46f7-8f4d-fa8de4c6b63d` expose Sell Op-Ed / Morning Edition for 2 coins. Current Release sale/refund interaction still requires a rational inventory replacement. |
| UI-10 | Two handwritten teaching sentences visibly overlap during an automatic new hand on Volume 1. Native screenshot: `/tmp/numberclub-ui-A/results/1788732972530-036b2611-0377-4365-81b4-fbac675a3940.png`. | `.id(note.text)` removed the old MarginNoteView and inserted another, running both opacity transitions simultaneously in the same reserved band. | Keep stable handwriting view identity; change text in place while preserving the fixed band and its position/appearance animation. Respect Reduce Motion for the band. | Mid-transition hosted rendering test passed (1 test, 0 failures/skips), `/tmp/numberclub-margin-transition-gate-02.xcresult`; exported frame `/tmp/numberclub-margin-transition-attachments/802C465B-E659-472D-823D-1770F08A1CDF.png`. Full annotation/layout gate passed (8 tests, 0 failures/skips), `/tmp/numberclub-margin-layout-gate.xcresult`. Player binaries still predate this fix. |
| UI-11 | Gray the Garry visibly bars row 3 but also brackets row 5. Native iPad screenshot: `/tmp/numberclub-ui-C/results/1788733752512-c27a0711-fd37-493c-8b52-c2d05e5ffca4.png`. | The generic animated perimeter added fixed-position decorative row/box brackets alongside the actual state-driven restriction outline. On a playable board those decorations misleadingly resemble a second restriction. | Suppress the generic Garry perimeter on gameplay boards only. Keep the true restriction outline and its turn-change transition; preserve animated seals and illustrative route art. | 3 focused visual/state-outline tests passed, 0 failures/skips, `/tmp/numberclub-garry-cue-gate.xcresult`. Pixel regression checks formerly bracketed, now unbarred areas; captures in `/tmp/numberclub-garry-cue-attachments/`. Updated Release build pending. |

## First complete level attempts (not complete Books)

- Volume 1 / A: the active retry completed Puzzle 2 at 1,900/1,500 and
  Handy Dandy at 2,370/2,000 with four unused turns. Boss completion:
  `/tmp/numberclub-ui-A/results/1788734940511-9777add8-a045-4d3f-a076-3fc2638a1c2c.png`.
  Cash-out reached the ordinary Shop; after buying Finance Pages and taking
  Circulation, A reached Level 2, Round 2 with 9 coins. This is one completed
  level, not a completed Book. Full evidence is in Player A's separate log.
- Volume 5 / B: Puzzle 1 won at 1,340/1,000; Puzzle 2 won at
  1,540/1,500. Garry the Gray then lost normally at 590/2,000 after
  Turn 11/11. Failure UI:
  `/tmp/numberclub-ui-B/results/1788734085571-3687a091-c8fd-42f9-b604-b607f9dbd4ae.png`.
  End book reached Book over:
  `/tmp/numberclub-ui-B/results/1788734099427-9b50248f-a709-4f8a-b5a6-a412e5d2daa5.png`.
  Inventory choices and placements are recorded in the separate Player B log.
- Volume 9 / C: Puzzle 1 won at 1,380/1,000; Puzzle 2 won at
  1,670/1,500. Gray the Garry lost normally at 490/2,000 after Turn 10/10.
  Settled failure UI:
  `/tmp/numberclub-ui-C/results/1788734082455-6afef11a-009a-42f7-bebc-4fbf04c4590f.png`.
  Player C purchased Puzzle Corner and Overtime; a purchase alone is not proof
  of activating a consumable. The next attempt must verify actual activation.

Neither loss proves a balance defect. The initial assistants exhausted their
single-only deduction approach; the visible-only helper now also supports
ordinary locked-candidate and pair/triple pencil eliminations. It never guesses,
searches a solution tree, reads the engine/save, or fills the actual board except
through confirmed native taps with available drawn cards. Its arithmetic passed
524 deductions across 24 independently constructed synthetic Sudoku fixtures.
Advanced deduction traces are saved separately under
`/tmp/numberclub-ui-{A,B,C}/deductions/`, tied to the exact observed UI snapshot.
These tool checks are not game playthrough or completion evidence.

## Completion conditions for each future Book

### Fix verification update — 01:55 local

The full Boss visual regression suite passed: 20 tests, no failures/skips,
`/tmp/numberclub-garry-visual-regression-gate.xcresult`. The optimized Release
containing UI-10 and UI-11 was installed in place on B/C after their failed runs
ended, and on A at its Level 2 briefing checkpoint. Existing saves were not
erased. The issue-table binary-status notes above describe the earlier gate
time; these three installations supersede them. Native retesting continues.

UI-12 investigation: the public iPad failure hierarchy exposes two nested
Overtime buttons with the same bounds and label in
`/tmp/numberclub-ui-C/results/1788734393818-e5da5058-ddb6-4aa2-bf8e-f6ce52553810.txt`.
The Buff wrapper and InventoryBookmark each define semantic activation, while
the inner passive-popover binding is constant. The candidate fix gives the
existing inner element the Buff callback and removes the duplicate wrapper
semantics. Gesture handling and named Sell action are unchanged. Focused gate
and native accessibility retest are pending; no general touch-failure claim.

### Per-Book acceptance checklist

Record a timestamp/device/build and native evidence for every condition:

1. Gameplay uses normal visible UI and touch; no QA route, hidden solution,
   saved-run inspection, fixture, or synthetic completion.
2. Inventory use is rationally documented (Bookmarks, Markers, Buffs, rerolls,
   and any sale), including observed balances where available.
3. Any failure is allowed to show the failure UI and the run is restarted from
   the ordinary player flow; no failure is silently converted into a win.
4. The final level/boss reaches the Book-specific congratulations leaf showing
   the actual Book identity, then Close Book returns to that volume.
5. Per-Book unlock, shelf return, and relaunch/resume are verified for that
   Book. Record each as separate evidence; tests alone do not satisfy it.

Until those conditions are met, the matrix must remain NOT PLAYED. Parallel
source edits or passing tests may be linked as implementation context, but may
not change a matrix status.

## Native session restart — 06:27 local

The previous runner processes had finished and all three player simulators
were shut down when inspected. No active runner was interrupted. The three
pending commands listed below had never started and were moved, recoverably,
to `/tmp/numberclub-stale-ui-commands-O7xTMK/` instead of replaying their stale
coordinates after relaunch:

- A: `1788735775228-9921c08d-fdaf-4bff-864d-d3dab369c5cd`
- C: `1788735738930-67f9c95f-8369-45e6-bb6b-c9cddd7ac32f`
- C: `1788735904131-697db3de-4beb-45ad-a757-2e96c157690f`

The UI-12 focused gate passed 9 tests with zero failures/skips:
`/tmp/numberclub-buff-activation-gate.xcresult`. It covers Buff activation once,
unchanged passive Bookmark details, hold generations, outgoing consumed-Buff
metadata and native details layouts. This is not yet a native VoiceOver retest.
An optimized Release build containing the change passed and was installed
in place on all three simulators without erasing data. Fresh native title
snapshots prove the new runners are responding:

- A: `1788751632140-b5351bb3-1684-4687-996d-d4f204f3f451`
- B: `1788751632140-7dcf53d1-d84e-4558-808d-3408874f8b90`
- C: `1788751632141-8c5e5cf0-b456-4c8a-97a1-a9c250fe115a`

Three fresh low-model player agents resume Volumes 1, 5 and 9 through the
ordinary rack and saved-Book flow. The prior A log independently records
successful Level 2/Round 2, 9-coin/Circulation restoration before its runner
expired. C's second attempt reached The Censor after winning the first two
puzzles; Morning Edition and Op-Ed Column are passive Bookmarks, not consumable
Buffs. Their details correctly do not offer Use. No Book-completion status changes.

## Additional native findings — 06:35 local

- **UI-04 reproduced on current offer cards, not only sold ones.**
  `/tmp/numberclub-ui-A/results/1788734951440-9230391e-4a7a-4723-b636-8c7ba188f53a.txt`
  exposes two nested Buttons for Finance Pages and every other offer. The
  candidate fix labels the existing native Button directly instead of adding
  a second accessibility grouping. Full-paper hit shape, details action and
  guarded Buy action are unchanged. Eight rendering/sale-policy tests passed,
  no failures/skips, `/tmp/numberclub-shop-semantics-gate.xcresult`. Native
  hierarchy/tap retest awaits installation at a normal Shop checkpoint.
- **UI-13, false restriction underprints.** Native A Handy Dandy screenshot
  `/tmp/numberclub-ui-A/results/1788751808823-ddc8e01d-5d19-4581-8aef-53af298938b7.png`
  shows a large cross through the middle box although only Hand cards are
  barred. C's Censor screenshot
  `/tmp/numberclub-ui-C/results/1788751812155-dd99b278-bde5-4de6-a820-b4401031f2ef.png`
  has unrelated black bars in row 1, separate from the true underlined 6s.
  Both are fixed-position decorative underprints, not engine restrictions.
  The new regression failed against the old Handy Dandy art with 1,936 marked
  pixels (`/tmp/numberclub-false-boss-markings-before.xcresult`). The candidate
  removes the central cross and the unrelated redactions; animated edge/seal
  signatures, crossed-out Hand cards and actual censored-digit underlines
  remain. Full Boss visual gate is running; native retest remains open.

## Native checkpoint verification — 06:41 local

The latest optimized Release build passed and was installed in place on C at
its ordinary Shop checkpoint. It retained the same 32 coins, Morning Edition,
Op-Ed Column, and five offers; no purchase, reroll or save editing was used.
A/B still have the earlier Release containing UI-10/11/12, pending a natural
checkpoint for the UI-04/13 update.

- **UI-04, unsold offer hierarchy and touch verified:** before the update,
  `1788752271100-6bc67723-ea23-4555-840a-335c16c6cae3` exposed two nested
  Buttons per offer. Afterward,
  `1788752408234-4f003f20-184a-4996-b87c-92b4d5245f12` exposes one Button
  per offer with its label and identifier intact. A coordinate tap in the
  blank lower-right part of Evening Edition opened its details:
  `1788752433182-7f33f356-02f1-445b-a571-d917701f0d95`. Closing without
  buying preserved 32 coins and all offers, final settled snapshot
  `1788752471186-f1bc1a90-5822-4021-bc37-a8d0733acf08`. The semantic
  `tap-id` attempt still returned `notHittable`; this separate driver result
  is not claimed fixed. Native sold-card hierarchy remains unverified.
- **UI-03, current default-theme details contrast verified:** the same open
  Evening Edition sheet visibly has dark, readable Item details and item
  headings on cream paper. This is not a check of every cosmetic theme.
- **UI-13, render regression fixed:** the full Boss visual gate passed
  21 tests, zero failures/skips:
  `/tmp/numberclub-false-boss-markings-after.xcresult`. Gameplay underprints
  no longer invent blocked cells for Handy Dandy or Censor. Real Hand bars,
  censored-digit underlines and the Boss edge/seal signatures remain. C has
  this build; a subsequent native encounter is still needed for live retest.
- **UI-12:** the 9-test gate and installation are complete, but a live
  consumable Buff activation/hierarchy check is still pending. Passive
  Bookmarks cannot substitute for that check.

Ordinary play continues, without changing any Book's completion status:

- A lost Level 2 Handy Dandy at 1,840/4,000, then restarted normally; evidence
  `1788751997817-a550cd9b-a0ea-4b5a-a706-eef6b555aaf8` and
  `1788752009681-50b2df5b-df0b-4b84-ba58-c6ce0b112cdd`.
- B used a simulator test-ad rescue, reached Turn 13, and lost at
  1,190/2,000; evidence
  `1788752023571-28e572a0-4fc5-4385-bd19-f173da8e2cbb`. The normal New
  Book path was then taken. The simulator is configured to use Google's
  demo ad unit, not a production-ad impression.
- C completed Level 1 Censor at 2,140/2,000 with five unused turns and a
  12-coin payout; evidence
  `1788751912153-48aef52a-17b0-494c-a35c-ec4c9134bc3b`. Cashing out reached
  the 32-coin Shop used for the update above. This is one complete level,
  not a completed Book.

All native IDs above are retained under `/tmp/numberclub-ui-A/results`,
`/tmp/numberclub-ui-B/results`, or `/tmp/numberclub-ui-C/results` respectively,
with matching text and screenshot files.

## Historical native session B evidence — preparation only (2026-09-07)

Player B used only the assigned iPhone 16 Pro Max simulator channel B
(`E2CF3ABE-C90C-4CEB-99B0-91AC298A9815`) and the existing XCTest UI driver.
The ready snapshot was captured at
`/tmp/numberclub-ui-B/results/1788731114913-063ef5e3-8107-4531-8a2e-701359c49470.{txt,png}`;
it showed the first-run choices `Yes, I've played` and `No, show me how`.

The exact-label onboarding tap result is retained at
`/tmp/numberclub-ui-B/results/1788731126722-886e77ad-81cc-46b7-aed2-fa1cdd293978.txt`
(with its matching `.png`); it returned a native bookstore transition state.
The first exact `PLAY, Walk over to the book stand` tap returned `notHittable`
at
`/tmp/numberclub-ui-B/results/1788731149539-da62c078-490a-4caf-8982-fa1cdd293978.{txt,png}`.
After waiting, the rack snapshot/point evidence at
`/tmp/numberclub-ui-B/results/1788731231504-a25b3b16-6e23-452a-b4b2-23a83c58aa94.{txt,png}`
showed the visible `edition:genuinely` card. A single normalized point tap was
then submitted; its result remained `pending` under ID
`1788731293556-f6c5b10d-f1ff-4ec8-b279-9bd5c705f414` (subsequent read also
remained pending). This is a driver/result stall; no claim is made about its
cause, and the action was not resubmitted.

That initial preparation session produced no puzzle, Shop, boss, failure,
restart, unlock, resume, or congratulations evidence. Later gameplay is recorded
above and in the dedicated player-B log. The matrix still remains **NOT PLAYED
for all 12 Books** because no full Book has reached final congratulations.
### C-35/C-36 continuation

- C-35 settled Level 4 Puzzle 2 at **19,890/12,000**, 7 unused turns, payout
  18 (`1788776677183-cbc21544-0887-4760-9145-120e45cbd5a5`), cashed out 68→86,
  then settled the Fog Boss at **20,880/16,000**, 7 unused, payout 20
  (`1788776720620-e6a05ba8-abdc-4f4f-a848-359846b249d4`). C-36 cashed out
  86→106 and settled Level 5 Puzzle 1 at **40,290/16,000**, 7 unused, payout
  22 (`1788776935784-d70689cd-8c5b-4dde-add9-599f893a2a41`), then reached
  Level 5 Puzzle 2 Turn 4/10, 20,730/24,000, hand 7,1 at
  `1788776991333-88548b19-0b04-4e87-9504-8f9ad15a8a29`. No purchases were
  made; all four marker positions and five Bookmarks were preserved. Both
  sessions ended by explicit STOP with no pending actions. Current progress is
  **13/27**, still zero full Books.

### UI-23 — late Toss/End Turn puzzleNotPlayable risk (guard tests pass)

New app guards disable Toss and End Turn outside playing/keep-filling. The
focused UI-21/22/23 gate produced 34 unique checks across two runs: 33 passed
and one raw JSON object-key-order assertion failed; the narrow rerun passed
(`/tmp/numberclub-product-ui21-short-after-20260907.xcresult/log`, 1 pass,
2.684s). The Release build succeeded (`/tmp/numberclub-product-ui21-23-release-20260907.log`).
The terminal-input guard tests pass in the focused gate; this does not claim a
deliberate native double-tap proof. The gate produced 34 unique checks across
the original 33/34 run and corrected narrow 1/1 rerun. No broader race or
performance claim is made.

### C-37/C-38 continuation

- C-37 won Level 5 easy-but-hard at **34,590/24,000**, 6 unused turns, payout
  21 (`1788777069159-62b5f060-4793-49c5-b6ac-ff962ae983c6`), then cashed out
  128→149 (`1788777071073-29e97d01-7999-4f34-bc04-6d9c337c53db`). No purchases
  were made. The Deadline followed at 12,600/32,000, Turn 4/8, Toss 0, hand
  9,3,1,2,6,4 (`1788777103558-7db21531-cb1b-42c7-9834-7e766b1b091e`).
  Current progress is **14/27**, still zero full Books.
- C-38 only opened the Litmus popover before compaction; no placements or
  puzzle-count changes occurred, and the session timed out safely. UI-23
  source review passed; native guard/test verification remains pending.

### C-39 continuation

- C-39 won Level 5 Boss/The Deadline at **50,040/32,000**, 2 unused turns,
  payout 17, with 149 coins before cash-out:
  `1788777641724-f0f3c6a1-cabf-465f-8694-77d65cb5cbe6`. Public Litmus use
  showed 6 matches (`1788777503557-2b48a32a-b707-438a-8596-beb95059fc0a`);
  normal placements 6@R6C4, 4@R6C5, and 2@R6C6 completed the clear
  (`1788777555318-28a9a27d-a230-4ebe-9173-cd2403e7efb`). Lucky Dip drew 1,5
  (`1788777585873-4c75942a-b865-4e39-8023-d07d70979e2f`), followed by 5@R4C9
  at 29,880. Remembered public Litmus hints enabled 3@R5C4 and 9@R5C5,
  confirmed by `1788777633976-1bd23b5e-efb3-468f-865e-3d9dc7510b60` and
  `1788777636142-6716a4ad-ca28-4daf-af7f-fdb279c52ef5`. End Turn produced
  the settled win; current progress is **15/27**, still zero full Books.

### C-40 continuation

- C-40 won Level 6 easy at **32,790/32,000**, 7 unused turns, payout 22
  (`1788777742569-88726998-c200-4027-9cf8-da1899da9ec5`), then cashed out
  166→188 (`1788777744680-605ae077-bb33-4fd4-b41f-31ac9ed5101b`). Sold Local
  Gossip (+2) and bought Front Page Splash for 7, leaving 183 coins. Level 6
  easy-but-hard remained partial at 36,180/48,000, Turn 4/10, 4 Tosses, hand
  1,1,7,4,7,2 (`1788777800590-3940db8d-93fd-441b-aba8-b1c9309904fc`). The
  batch ended cleanly at 105 weighted actions/118s. Current progress is
  **16/27**, still zero full Books.

### C-41/C-42 continuation

- C-41 won Level 6 easy-but-hard at **90,180/48,000**, 6 unused turns, payout
  21 (`1788777877228-b0873831-8185-4d40-8a9f-b3e2f497fe10`), cash 183→204.
  C-42 won the Level 6 Boss/The Critic at **71,180/64,000**, 5 unused turns,
  payout 20 (`1788778075345-83919618-730f-4e8c-bf95-96032938d2fa`), cash
  204→224. One public two-candidate guess selected 1 at R8C2 and was wrong
  (−100; `1788778044369-e29579ac-825b-4085-8431-902ca06d275f`); normal visible
  feedback then established 1@R8C8 (`1788778046325-b817299c-ebc4-47ca-9b2e-ed4919d8c8e0`),
  after which public deductions chained to the settled win. Current progress
  is **18/27**, still zero full Books.

### C-43/C-44 continuation

- C-43 won Level 7 easy at **89,280/64,000**, 7 unused turns, payout 22
  (`1788778311592-5cc28ac3-3842-480d-a69f-32e902ab6232`), cash 197→219.
  Double Down and Second Print were used normally; their public receipts are
  `1788778263409-cc67a28b-6c81-443b-bc6a-11ad2e64d4e7` and
  `1788778268057-de6b39f5-3a72-4d61-a7ae-4950582dd3da`. Public receipts show
  197 coins after the visible Sapphire placement at R5C8 and purchases/rerolls;
  no unlisted spend is inferred from arithmetic.
- C-44 won Level 7 Puzzle 2 at **134,640/96,000**, 6 unused turns, payout 21
  (`1788778428748-d28c3e92-645e-4689-a24a-2fcd2c26a4b7`), cash 219→240.
  Peek was bought for 3, leaving 237 (`1788778436160-a0a97255-9f7a-4732-83b6-227d5e7f7688`).
  The next puzzle remained partial at **97,200/128,000**, Turn 6/10, hand
  4,4,9,9,9,4, with no Toss spent (`1788778496075-7d2def8f-ae17-4630-9a07-d8e32c46e6aa`).
  Current progress is **20/27**, still zero full Books.

### C-45 continuation

- C-45 settled Level 7 Puzzle 3 at **168,480/128,000**, 3 unused turns,
  payout 18 (`1788778665646-bc60a386-9551-42cc-8d8e-0318907d576c`), cash
  237→255. Peek was used to choose 9; public Clue destination R1C6 and
  subsequent actual 9@R1C6 are evidenced by `1788778601904-9767c5d5-8c4e-4b90-a190-a0bda8121c08`
  and `1788778635783-55cf3d56-e7a2-4a61-b9ac-678cbd5c57d2`, then visible
  deductions completed the win. C-45 bought Peek for 3 and used four rerolls;
  the last Shop receipt is `1788778712696-176c79c1-aab4-4d7b-a12c-067abea2a3f8`
  with 238 coins expected from the visible sequence. No Extra Extra offer or
  Bookmark change was observed. Current progress is **21/27**, still zero full Books.

### C-46 continuation

- C-46 won Level 8 easy at **189,540/128,000**, 6 unused turns, payout 21
  (`1788779081431-c6c21edf-8cde-4407-8d3b-a8ca6ed635d6`). The win showed
  241 coins (including the Copper clear), then cash-out reached 262. Peek was
  bought for 3, leaving 259 (`1788779088813-565c036d-91e1-4796-93a6-e473e1025fb0`).
  Level 8 easy-but-hard remained partial at **34,200/192,000**, Turn 3/10,
  4 Tosses, hand 4,1 (`1788779129970-76aab9d6-8f2f-4779-95a9-ecc03d4f98d8`).
  A late placement was not confirmed; the AX win capture was mid-page-flip and
  included the new “Your board as played” text, so UI-21 native visual status
  remains inconclusive. UI-23 native evidence likewise remains pending.
  Current progress is **22/27**, still zero full Books.

### C-47 continuation

- C-47 won Level 8 Puzzle 2 at **247,140/192,000**, 5 unused turns, payout 20
  (`1788779216353-c52c369f-8ff4-45df-9d80-54d438c6d640`), cash 259→279 with
  no purchases. The fully settled iPad Results screenshot showed the updated
  board preview, readable actual blanks, and footer; UI-21 native visual status
  therefore passes. Garry Gray remained partial at **96,390/256,000**, Turn 5/10,
  no Toss, hand 9,9,1,2,5,5 (`1788779276405-f8a5db1d-fea8-4331-a4d5-f72af4e477fd`).
  Current progress is **23/27**, still zero full Books.

### C-48 continuation

- C-48 won Garry Gray at **317,925/256,000**, 4 unused turns, payout 19
  (`1788779440680-e6ccd55a-97c0-4cc5-bf9b-350a45e30b3f`), cash 279→298.
  One Peek selected 9@R1C2 (`1788779352234-07e47ce1-a420-4664-9916-fb27911cafcf`),
  then visible deductions chained to the win. Seven normal rerolls sought Extra
  Extra (costs 2+3+4+5+6+7+8=35); none was bought. Final Shop receipt
  `1788779487412-e5d773b8-43df-4253-9667-363790d1f085` showed 263 expected coins.
  Level 9 briefing identified final boss “The Budget Cut,” with all score
  multipliers halved (`1788779489452-c40f1953-eac0-4078-8e6e-71227f76c425`);
  Level 9 easy started at 0/256,000 Turn 1/10 (`1788779493197-a6055e50-d0b3-4b1b-8b09-7c131f753a5e`).
  Current progress is **24/27**, still zero full Books.

### C-49 continuation

- C-49 won Level 9 easy at **285,120/256,000**, 5 unused turns, payout 20
  (`1788779637327-3211d478-0b9c-40cc-b376-7a0b3c33dc34`), with 266 coins
  including the Copper bonus, then cash-out reached 286. Extra Extra was
  offered and bought for 7 after selling Letters to the Editor
  (`1788779639488-a4ccd645-bd7a-466b-8f51-c8c9e7ad10a3`). Level 9 Puzzle 2
  remained partial at **8,640/384,000**, Turn 2/10, 4 Tosses, hand 5,5
  (`1788779680616-cd8e15ad-4674-4d11-9ef8-2765721d850c`).
- UI-22 native attribution specifically passes in C49’s 12-second clip
  `/tmp/numberclub-score-ui22-live.mov` and reviewed contact sheet
  `/tmp/numberclub-score-ui22-live-contact.png`: sampled Sunday/Stop/Front
  Page/Rolling labels and turn points, Book bonus, Line complete, and Added to
  queue remained readable as single lines without overlap. This is not a
  blanket 60fps or device-performance claim. Current progress is **25/27**,
  still zero full Books.

### C-50 continuation

- C-50 won Level 9 Puzzle 2 at **671,580/384,000**, 4 unused turns, payout 19
  (`1788779830284-024a9815-5e67-4dca-85f2-15b90707f284`), cash 285→304 with
  no further purchases. The final boss, The Budget Cut, started at target
  512,000 (`1788779838427-e5c6ca10-8452-4fef-a4ee-9c5859578c77`), then remained
  partial at **18,090/512,000**, Turn 4/10, Toss 0, hand 7,2,9,7,2,6
  (`1788779879085-5938f259-8672-41ee-800b-18794b0ed704`). Current progress is
  **26/27**, still zero full Books.

### C-51 — Volume 9 completed

- C-51 completed **27/27 puzzles**, **9/9 levels**, and **9/9 bosses** in
  Volume 9, defeating The Budget Cut. The fully settled native congratulations
  page followed the win directly without Shop (`1788780062472-ae717b1c-744e-4e7a-b794-b86ec5176176`).
  Fresh AX confirms `BOOK COMPLETE`, 9/9, Obstacle II ready in this Book, 320
  coins, and only Close Book (`1788780113736-fe966eac-e110-4fe0-86ef-bbe25afa2ebc`).
  Final Peek selection 2@R2C5 (`1788779965920-eeff88f0-0d9d-404d-8310-42f3d2372be1`)
  was followed by normal deductions. This is the first completed Book; **11/12
  Books remain**.

### C-52 — completed-Book obstacle unlock visibility

- Public Volume 9 selection AX confirms Obstacle I and Obstacle II unlocked,
  while Obstacle III–IX remain locked (`1788780250207-5cd7bf24-e9fc-4157-a7cd-9602ac40d06f`).
  The separate cross-Book selection check remains pending.

### C-53 — cross-Book unlock isolation

- Selecting Volume 5 via its actual middle cover produced fresh AX showing
  Obstacle I unlocked and Obstacles II–IX locked
  (`1788780557124-d028e309-9d37-451f-a283-4e2db6061fd0`). After returning,
  the full shelf showed Volume 1 and Volume 5 locked on 2–9, while Volume 9
  alone showed its colored 2 tab and locks 3–9
  (`1788780585165-3c729737-1467-4b4a-9bdc-684e15f76c72`). This proves scoped
  per-Book unlock state with no visible stale unlock leak. A return tap during
  transition produced no selection and no unlock mutation; it is not classified
  as a new game bug.

- Final Volume 9 reselection again showed Obstacle I and II unlocked and III–IX
  locked (`1788780634445-aaa00306-f5e2-4fef-8941-78e8d59842bf`). The later
  top-cover attempt did not prove Volume 1 selection and is not labeled as such.

### Physical frontend pass — production-configured devices (7 September)

- Production-configured 1.0.1 (10), development-signed with Google test ads,
  was installed only on the iPhone 17 Pro and iPhone 16 Pro Max; no App Store
  submission or commit was made. Direct Mirror on the 17 Pro confirmed Guide
  vertical scrolling moved the real board, Next navigated to 2/9 and reset the
  article offset, and Close returned to Settings. Rack flick rotation settled;
  Volume 5 middle-cover extraction kept its banner stable and background-tap
  reverse returned to the same pocket. Settings scrolling worked physically;
  Mirror's no-effect result is therefore a tooling limitation, not a product
  bug. Haptic feel remains unverified.
- The standalone 90-second scrolling probe failed initialization on both
  devices (17 Pro authentication error 12; 16 Pro Max automation-mode timeout),
  so no test method ran and no pass is claimed. Both startup traces were on
  the 16 Pro Max: its earlier installed build measured 580.54 ms, and current
  source before the fix measured 590.86 ms for BookstoreSceneView creation.
  The 17 Pro had previously been running 1.0 (7), but is not the source of those
  startup measurements. The lazy
  bookstore regression suite passed 12/12 (`/tmp/numberclub-lazy-bookstore-regression-20260907.xcresult`).
- The optimized Production build was then installed in place on both allowed
  phones. The 16 Pro Max's largest startup SwiftUI update measured 482.46 ms
  (18.3% lower than 590.86 ms); one 231.06 ms startup hang remains. Evidence:
  `/tmp/numberclub-16promax-optimized-startup-20260907.trace`.
- The optimized 17 Pro's Volume 9 bottom-shelf extraction/banner/reverse return
  was visually checked. A bounded 40-second app-only interaction trace recorded
  a maximum SwiftUI update of 849.75 microseconds, but its Hangs/Hitches lanes
  say “No Graphs”; no zero-hitch or frame-rate claim is made. Trace:
  `/tmp/numberclub-17pro-rack-interaction-20260907.trace`.
- This is a frontend/performance pass, not additional full-Book completion.
  Subjective haptic feel remains unverified. No saves were reset and no App Store
  submission or commit was made.
