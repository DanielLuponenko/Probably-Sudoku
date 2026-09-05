# Gameplay polish / release acceptance

Scope: all seven reported bugs; catalog behavior and visual audit; boss-specific
feedback; animation smoothness; preserve rewarded rescue and page curl; merge,
push, and install the final verified build on the connected iPhone 17 Pro and
iPhone 16 Pro Max. The user explicitly excluded the unavailable iPhone 16 Pro.

## Evidence and remaining gates

| Requirement | Reproduction / cause | Status / proof |
| --- | --- | --- |
| 1. Occupied board tap cancels held card | Live BUGPOLISH seed: hand 4 stays green while board 1s highlight; `/tmp/numberclub-selection-conflict-before.png`. Model retained both selections. | Nine selection tests pass after a red gate with seven failing assertions. Live identical sequence is fixed: `/tmp/numberclub-selection-conflict-fixed.png`. |
| 2. Hand-targeted Clue | Existing button asked for a blank and auto-filled it from pool/hand. | Seven engine and seven presentation tests pass. Live Peek→Use→hand4 reveals empty R2C7 without moving a card; manual tap places that4 with Clue provenance. `/tmp/numberclub-clue-destination-live.png` and `/tmp/numberclub-clue-manual-place-live.png`. |
| 3. Stale number highlight | Same independent selection state; toggling a hand card revived board focus. | Exclusive-selection tests cover board→hand→same hand, switching cards and clearing all state without game mutations. Live hand→occupied board switches exclusively to the board number. |
| 4. Accountant live coin debit | Engine already debits every accepted placement before scoring; regression verifies correct/wrong/debt/save and no second bank debit. | Live baseline confirmed 5→4 before End Turn (`/tmp/numberclub-accountant-before.mov`). HUD now uses the authoritative balance and an immediate fee receipt, including net-zero coin refunds. App regression passes. |
| 5. Fog / boss presentation | Fog alpha roughly 1–2% beneath opaque cells; marker receipts leaked hidden positions. | State-driven overlays and marker receipt gating pass real-action/render tests. All19 treatments inspected. Live mist remains readable: `/tmp/numberclub-fog-live-final.png`. |
| 6. Syndication popup | Actual native popover opened above its top-rack anchor with a 260×8pt content area; all text clipped at 320/375/402pt phone widths. | Below-anchor regular popovers now260×119pt; OCR verifies full title/description at all widths. Native accessibility5 scrolling reaches the final sentence. Source Dynamic Type is explicitly forwarded across presentation. |
| 7. Duplicate shop markers | Seed unique-markers-1, level1/reroll1 produced Sapphire for 6 and5. | Stock uniqueness fix; 9 levels ×30 seeds ×4 rolls regression passes. |
| All Buffs, Bookmarks, Markers | Full catalog action-level audit, not only hook existence. | All 46 covered in `Engine/CATALOG_COVERAGE.md`. Fixed Bird Seed lifetime, Extra! Extra! event multiplier leakage, no-effect Buff consumption, and Keep Filling wrong-score leakage. Full 195-test engine gate passes, including Boss-conditional effects, saved growth/reset and combinations. |
| Additional visual issues / animation smoothness | Reproduction, screenshots, transition/cancellation/Reduce Motion checks. | Cancellable holds/toasts, visible clear marks and selected-card lift fixed. Long Boss names fit narrow widths.45s app-only Time Profiler trace records zero hangs. Curl recorded/inspected frame-by-frame; flexible printed face and opaque blank reverse preserved. |
| Save compatibility | Paid Clue hints persist; old saves default to no reveals, no data removal. | Full engine/presentation persistence gates pass, including old saves, paid retries, timed relaunch and frozen render snapshots. |
| Release | Preserve failure page redesign and QA simulator-only boundary. |141 app +195 engine tests pass. Signed Release1.0(6) archive succeeds, signature valid, both target devices provisioned, QA symbols/launch switches excluded. Independent review found no blocker. Git delivery/device installation recorded in the release handoff. |

The report tracks unfinished work explicitly; it is not a substitute for runtime
or test evidence. No physical-device data has been erased for QA.

## Additional findings

- Tik Tak previously stopped in Keep Filling and reset to three minutes on
  relaunch. Fourteen deterministic tests now pass for a persisted fractional
  monotonic budget, active-play lifecycle gates, old-save fallback, expiry,
  frozen snapshots and avoiding board invalidation for timer-only ticks.
- Bookmark press tasks now cancel on release/disappearance and reject stale
  generations; four regression tests pass.
- Cleared-line marks now receive their own appearance interval before fading;
  new toast messages no longer inherit a previous message's dismissal task.
- Nineteen rendered Boss treatments were inspected: digits remain readable,
  Censor marks only existing visible digits, restrictions follow actual state,
  and Fog does not disclose marker locations. Eight render/state tests pass.
- A live Debug QA hang was sampled in `/tmp/numberclub-live-hang.txt`:
  repeated `ContentView` initialization eagerly called `debugModel` and the
  puzzle generator during SwiftUI updates. Mount-lifetime initialization fixes
  the repeated work: identical launch becomes interactive, all hand cards
  arrive, and idle CPU reads0.0% instead of93%. The factory is absent from
  physical Release behavior.

## Final evidence

- App gate: `/tmp/numberclub-polish-full-app-final.log` —141 tests,0 failures.
- Engine gate: `/tmp/numberclub-polish-full-engine.log` —195 tests,0 failures.
- Native render attachments: `/tmp/numberclub-final-test-images`.
- Performance: `/tmp/numberclub-polish-interactions.trace` and corresponding
  `.json`;45.6s recorded,0 detected hangs. This simulator Time Profiler capture
  does not supply physical-phone frame-rate or SwiftUI hitch metrics.
- Curl: `/tmp/numberclub-build6-curl.mov`;16-frame detail sheet
  `/tmp/numberclub-build6-curl-detail2.png`. Renderer/shader source unchanged.
- Accountant final live5→4 fee before End Turn:
  `/tmp/numberclub-accountant-fee-final.mov`.
- Release archive:
  `/Users/daniel/Downloads/ProbablySudoku-Build6.od6JTe/ProbablySudoku.xcarchive`.
  Archive log: `/tmp/numberclub-build6-archive.log`.
- Google demo ad IDs remain enabled for testing in every configuration.
