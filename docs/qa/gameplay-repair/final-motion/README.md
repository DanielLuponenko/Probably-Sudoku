# Final native return-motion and demo-rescue checks

**Passed on build 24**, 19 September 2026, by `route_clue_scope` after explicit exclusive SE handoff. No production or test source changed. Simulator ownership was released before offline report completion so the final app gate could run.

Device: SE-test `60D48736-12BA-4D48-ADCB-DC2DBB834730`, iOS 26.3, 375×667 points / 750×1334 capture pixels. Read-only device preference inspection confirmed `ReduceMotionEnabled = 0` and `ReduceMotionReduceSlideTransitionsPreference = 0`; neither was changed. The user's C4A device was untouched.

## Motion cases

QA menu only established the existing fixtures/items. All selected-card, Toss, Use and board actions were real native controls through CUA. No gameplay values or save files were edited.

| Case | Actual inputs and settled state | Recorded visual outcome |
| --- | --- | --- |
| Toss | Ordered fixture `[5,5,9]`; select first 5 UUID `4D5DA686-934F-4DA0-9615-FD000EA22BC0`, then Toss. Only that card vanished; second 5 `27DE4628-5DA9-4441-A1B3-78573FCC389E` and 9 remained. Allowance 4→3, score 0, wallet 5. | Departing 5 starts at its original hand position, travels right while shrinking/fading and disappears at the hand edge. Current board/hand geometry is used. No Pool badge or extra labelled destination. [Movie](toss.mov), [storyboard](toss-storyboard.png). |
| Redraw | Fresh Ordered fixture; QA grants Redraw; actual inventory panel → Use. Old `[5,5,9]` replaced by `[3,3,4,3,5,6,5]`; one Buff consumed. Toss allowance stays 4, score 0, wallet 5. | All three old numerals move toward the same right-hand edge as the panel dismisses; their fading images converge there. Seven new cards arrive in the live hand. The screenshot sequence shows both departing and arriving cards, with no Pool badge. [Movie](redraw.mov), [storyboard](redraw-storyboard.png). |
| Wrong placement | Penalty fixture `[8,1,9]`, Insurance left unused. Select 1 and attempt R1C2, which requires 2. The cell stays empty; 1 leaves the hand, 8/9 remain. Score/queue 0, wallet 5, Toss allowance 4. | Return 1 starts at the attempted board cell with the −50 penalty cue, moves diagonally toward the hand's right edge, then fades. Toast says “Wrong number — −50 queued Points first.” No visible Pool badge is introduced. [Movie](wrong.mov), [storyboard](wrong-storyboard.png). |

The tester inspected the three extracted sequences. **Root independently inspected all three storyboards** and confirmed the same source/edge destinations, retained 8/9 and empty attempted square, with no visible motion defect. These are actual native-frame checks, not geometry-model tests. They sample the relevant transition and endpoint; they do not claim exhaustive every-frame timing analysis or a physical inventory drag test.

All recordings used a dedicated `simctl io … recordVideo --codec=h264` process. Each recording was finalized by targeted SIGINT to its verified recording PID, then checked with `ffprobe`. No earlier failed piped recording was reused. [Validation](movie-validation.json): Toss 19.250 s, Redraw 5.056667 s, wrong placement 13.115 s, all H.264 750×1334. Raw recordings are preserved. Storyboards are analytical crops/frame samples only: Toss starts 18.80 s at 30 fps; Redraw starts 4.39 s at 18 fps; wrong placement starts 9.00 s at 16 fps.

## One completed demo rescue and separate decline

Read-only verification of the build's Info.plist showed `NumberClubAdMode = test`, Google demo app ID `ca-app-pub-3940256099942544~1458002511`, and demo rewarded unit `ca-app-pub-3940256099942544/1712485313`. The existing SDK boundary also forces the demo rewarded unit for Debug/Simulator. No live-ad spend, purchase, ad click-through, consent bypass or fake reward callback was used.

- Launched existing nonsaving `-skipStartScreen -seed FINAL-RESCUE-24 -rewardedRescue`. Its setup exhausts real turns before presenting the normal Out of Turns page. The single automatic acceptance-side load became ready; [offer](rescue-offer.png) showed score 0, target 1000, wallet 5 and the retained board.
- Activated actual **Watch an ad for three extra turns**. The SDK displayed **Test mode** ([capture](rescue-demo-test-mode.png)); the completed second creative visibly showed **Reward granted** and its X close control in the CUA screenshot. Closed that X without selecting Learn More or any advertisement link.
- The app resumed gameplay at **Turn 11/13**, score 0/1000, wallet 5, with seven held cards and the same visible given-grid pattern. [Accepted result](rescue-accepted-turn-11-of-13.png). This proves the native ad→earned callback→return-to-puzzle path. It does not independently prove exact hand UUIDs across the ad because the pre-ad Results page did not expose them; the existing engine/session tests provide that contract.
- A fresh nonsaving decline fixture `FINAL-RESCUE-DECLINE-24` was then opened. Its normal automatic preparation was allowed, but no second ad was watched and no failed load was retried. Actual **End book** changed the screen to **Book over**, score 0, wallet 5, and **New book**, with no reward. [Decline result](rescue-declined-book-over.png).

## Saved-state protection and handoff

Before install, the SE's Documents/Library were backed up at `/tmp/nc-final-motion-before-20260919-051520`; all earlier backups remain. Debug launches omitted `-persistQA`, and QA scoring fixtures explicitly disable persistence. At the end, normal seed `6C4C3`'s `run.json` was **byte-for-byte identical** to the pre-pass backup. [Comparison and SHA-256](save-comparison.json). No claim is made that SDK cache files remain unchanged after a demo ad.

Final visible state at explicit release: build 24, ephemeral **Duplicate Buffs and freeform inventory** fixture, Op-Ed→Stop, two Peek copies, Hand `[5,5,9]`, score 0/1000, wallet 5, Turn 1/10, Tosses 4, no selected card or open overlay. [Handoff capture](duplicate-fixture-handoff.png). It is ready for a possible user physical-drag check; no curved/diagonal inventory drag pass is claimed. No UI/simctl action occurred after ownership release.
