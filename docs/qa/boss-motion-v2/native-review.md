# Independent native boss-motion review

Reviewed 2026-09-19 on Book Playtest A — iPhone 17 Pro (`D04D3836-357E-4E92-811D-6D14E3BA1E01`, iOS 26.3). Native input used CUA only; simctl captured video/screenshots and installed the local build. The user’s normal iPhone simulator was not modified by this reviewer.

Final candidate: `/tmp/NumberClub-boss-motion-build3.app`, implementation dylib SHA-256 `caf713c2fec1e29527dfc394f501e4c3a527d9b003668deeeee8d052db6f8ab6`.

## Findings fixed during review

- The original entrance lifecycle consumed a newly mounted boss while PageFlipper still covered it. The new explicit entrance gate defers that unseen event. Actual Play from a natural boss briefing now shows the destination first, then the sequence of brick landings.
- Build 2 rendered printed grid rules above airborne bricks. The thick box border visibly sliced through the clay during descent. [Before](native/box-grid-crossing-build2.png) and [final recheck](native/box-grid-crossing-build3.png) at 20 sampled frames per second demonstrate the layer-order correction. Settled bricks remain aligned to their own cells.
- Root’s interim dust correction moved the puff behind the clay. Final footage shows a small tan contact accent around edges, followed by clean, dust-free resting blocks.

## Final native checks

| Check | Actual setup and result | Evidence |
| --- | --- | --- |
| Initial box-boss entrance after page curl | `-skipStartScreen -briefing -briefingBoss -seed 8RX9H` invokes the two real skip operations and reaches the naturally selected Garry the Gray briefing. Tapped Play. The page curl reveals the live board, then eight red blocks descend in sequence into the barred blanks. The given 8 inside the box remains uncovered when settled. | [4.33-second clip](native/box-entrance.mp4), [sampled sequence](native/box-entrance-detail-build3.png), [settled board](native/box-settled.png). |
| New-turn row restriction | `-skipStartScreen -seed BRICK-PREVIEW -qaBoss grayTheGarry` arranges the row boss on an ordinary debug board. Actual End Turn changes the barred blanks from row 8 to row 6. Six blocks land separately; old row 8 cells become available. This is a visual QA route, not a claimed natural boss completion. | [4.23-second clip](native/row-turn.mp4), [sampled sequence](native/row-turn-detail-build3.png), [settled board](native/row-settled.png). |
| Covered landing and return | On the natural Garry encounter, tapped End Turn and immediately opened Settings. Closing the custom panel returns to turn 2 with the new top-left box’s blocks settled, without another drop or dust replay. | [Original recording](native/box-next-turn-and-menu-build3.mov), [return samples](native/menu-return-detail-build3.png), [settled return](native/box-turn2-after-menu.png). |
| Blocked and released input | On Gray the Garry turn 2, tapped released R8C1: AX reports Selected. Tapped blocked R6C1: AX still reports that cell disabled and R8C1 remains selected. Coins stay 5 and turn stays 2/10. | Observed native accessibility state; rule/input regression coverage remains in the focused automated suite. |
| Persistence safety | Backed up the reviewer device’s normal run and profile before installing. All launches omitted `-persistQA`. Normal run and profile remain byte-identical afterward. | [SHA-256 comparison](native/save-comparison.json). |

The two short clips are trims of original simulator captures, converted from variable-rate recordings to H.264 at 30 fps while preserving recorded timing. Originals are preserved as `box-entrance-build3.mov` and `row-turn-build3.mov`; [codec/duration metadata](native/video-metadata.json) verifies the deliverables. The first build-1 recorder attempt was invalid after its terminal pipeline was interrupted and is retained only as failed-capture evidence, not verification.

Animation review used sampled native frames and actual UI transitions, not performance profiling. Reduced Motion, background cancellation, stale callbacks, finite last-brick dust, and state/RNG invariance are covered by the focused automated tests; this reviewer did not independently toggle the operating system’s Reduce Motion setting or background the app. No unresolved confirmed defect remains in the native scenarios above.
