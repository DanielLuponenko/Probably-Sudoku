# Gameplay redesign verification

The implemented target is the user-supplied reference in `reference.png`, with live game values rather than the example values in that image. The original brick source, prototype, and rollback material are retained.

## Scope

- Fullscreen ivory linen gameplay with live gold coin balance, Help/Settings, five Bookmark slots, two Buff slots, score/target, queued base × multiplier, concise boss information, board, hand, actions, and turn counter.
- Existing Book selection/opening/closing, between-puzzle Shop, results, and rules retained. The retired Club Shop was not restored.
- UUID-based hand presentation order supports ascending, descending, and explicitly requested random arrangement without changing canonical Engine order or RNG. Resume validates a bounded presentation snapshot.
- Cell/card geometry drives number-return animations. Board cells remain square, overflowing hands scroll, and layout allocation does not depend on score/boss/hand content.
- Existing brick artwork renders with red clay shading. Restrictions use the Engine's eligible blank-square set and a turn-aware landing lifecycle.
- One full-screen BookView capture host remains mounted through route transitions. Live controls stay within safe areas; snapshots and curl bounds include the whole surface.
- Unlimited ordinary-puzzle skips and deterministic Buff offers remain in place. Bosses remain mandatory, full inventories require explicit replacement, and historical Clippings retain their original effects.
- Player-facing arrangement, item inspection, skip replacement, Shop details, Help topics, and Settings destinations use custom paper panels. The shared overlay stack preserves modal input/accessibility, theme, timer pause, and dismissal handoffs without native iOS menus or sheets.

## Verification evidence

- Engine: 262 tests passed, 0 failures (`/tmp/nc-redesign-engine.log`).
- Initial focused app run: 67 tests passed, 0 failures (`/tmp/nc-redesign-focused.xcresult`). Includes hand arrangement, exact animation geometry, boss visuals/lifecycle, page capture/turn lifecycle, and the actual gameplay shell's layout matrix.
- Integrated focused gate: 117 tests passed, 0 failures (`/tmp/nc-redesign-custom-panels.xcresult`). This includes the real gameplay shell, compact/iPad briefings, custom panel lifecycle, skip transactions, Shop details, results, large values, and the independent review fixes.
- The first full app run exposed four failing cases: obsolete gameplay button theme expectations and three results rendering cases. Their fixes pass the integrated focused gate.
- The final broad app run executed 598 tests: 596 passed; two item-detail tests still waited for a native UIKit popover (`/tmp/nc-redesign-final-full.xcresult`). Those tests now mount the actual paper panel and retain complete-copy, compact-width, and accessibility scrolling checks. After synchronizing capture with panel arrival, they exposed a real fixed-width overflow at 320 points. Changing the item card to a 260-point maximum width preserves the paper's side margins.
- Final correction gate: all 14 item-detail, paper-panel, and Shop presentation tests passed, 0 failures (`/tmp/nc-redesign-final-detail-fit.xcresult`). This closes both failed cases from the broad run and rechecks every production caller affected by the width change. All 598 current app cases pass across the broad run and this targeted follow-up; this is not a claim that one full-suite invocation was green. The correction also received a separate read-only review with no further findings.
- Settings/Learning native-cover audit found and removed two remaining full-screen covers. The hosted nested Help/Topics regression then caught lost owner/dismiss environment values; composing them into the forwarded environment fixed the issue. All five panel tests pass (`/tmp/nc-redesign-nested-panels-fixed.xcresult`).
- The final manual pass has verified custom skip cancellation/replacement, footer-only acceptance, double-tap rejection, nested Settings/Help/Topics/video returns, hand arrangement, Buff use, and Shop purchase-to-marker-placement handoff. Remaining review details are recorded in `independent-review.md`.
- Actual compact/large iPhone and iPad captures were inspected against the reference. The first tablet capture exposed an undersized board; the final 900-point column removes the large unused footer while preserving square cells and visible actions.
- Independent code review and actual playtest: complete, with no confirmed remaining app defect. See [the independent report](independent-review.md) for exact interactions, resolved findings, and the CUA accessibility-dump limit. Actual iOS Reduce Motion was enabled for play and restored afterward.
- Final source audit found no production SwiftUI `Menu`, `sheet`, `popover`, `fullScreenCover`, `alert`, or `confirmationDialog` call sites. App-owned presentation uses paper panels; system-owned Game Center/ad SDK presentation remains under the platform's control. `git diff --check` passed.

## Final simulator captures

| Surface | Evidence |
| --- | --- |
| Large iPhone: full inventory, Gray row restrictions, large score/target, markers and Clue destination | [Gameplay](large-phone-gray-clue-final.png) |
| Large iPhone: Garry box restrictions | [Garry the Gray](large-phone-garry-final.png) |
| Large iPhone: ordinary puzzle and partial hand | [Three-card hand](large-phone-partial-final.png) |
| Large iPhone: largest accessibility text setting and timed boss | [Tik Tak](large-phone-accessibility-timer-final.png) |
| Compact iPhone: custom replacement choices with full reward/effect and Cancel | [Skip replacement](independent-se-custom-skip-final.png) |
| Compact iPhone: non-color-only Litmus verdicts | [Litmus](independent-se-litmus-final.png) |
| Compact iPhone: arranged overflowing hand | [Twelve-card hand](independent-se-overflow-sorted-final.png) |
| Compact iPhone: actual Reduce Motion, settled restrictions | [Reduce Motion](independent-se-reduce-motion-final.png) |
| Compact iPhone: long boss text and expired charge receipt | [Accountant](independent-se-accountant-expired-final.png) |
| Compact iPhone: results with pinned decisions and a scrollable record | [Results](se-results-final.png) |
| Compact iPhone: full-screen outgoing hierarchy and curl bounds, held at a Debug QA progress value | [Page curl](se-page-curl-final.png) |
| iPad: expanded square board, full inventory, markers, score and Clue | [iPad gameplay](ipad-showcase-final.png) |
| iPad: twelve live hand cards with stable board geometry | [iPad hand](ipad-twelve-cards-final.png) |

Launch-time visual fixtures are Debug simulator-only and disable run saving and achievement tracking before synthetic state is applied. Save/resume and skip transaction checks used separate real persisted runs, not those visual fixtures.

## Intentional differences from the reference

- Displayed score, inventory, hand, markers, clues, restrictions, and turn count are always live values.
- The board is mathematically square even where the supplied raster reference has unequal horizontal and vertical scaling.
- Existing catalogue symbols and game actions are preserved. The small Pool destination label supports the existing return animation without revealing hidden Pool counts.
- The existing number typeface and brick artwork are retained; their letterforms and surface texture differ from the supplied raster. Linen, recessed ivory wells, sage rails, clay shading, and contact shadows are rendered as live game materials.
- The primary sage button is darkened slightly to preserve at least 4.5:1 contrast for small labels. The cream and sage material is consistent across Book and paper themes during gameplay.
- On iPad the gameplay column expands up to 900 points, with the available height still limiting the square board. The application retains its existing portrait-only orientation support.
