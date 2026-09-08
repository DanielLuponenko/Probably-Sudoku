# Fast Book and obstacle validation

Use the existing engine and app tests. Do not rebuild a UI-playing helper to
check arithmetic, progression, persistence, or combinations of standing rules.
Automated fixtures are not human playthroughs and must never be counted as such.

## Smallest relevant checks first

From the repository root:

```sh
(swift test --package-path Engine --jobs 2 --filter ProductionCombinationMatrixTests/testAll108BookObstacleStartsKeepTurnRulesAndPreserveSaves) | boost
```

This starts all **12 Books × 9 obstacles** through production `Game.startPuzzle`,
with unchanged targets, hands, boards, coins and rules. It checks clue counts,
solution uniqueness, hand/turn/toss budgets, blocked-card selection, three
legal-placement/End Turn cycles, no-toss rejection, conservation, and identical
save/reload continuation. The solution is a unit-test input oracle, not evidence
of human solving skill. Measured: **108 starts / 324 turns in 3.962 seconds**
(6.54 seconds including incremental build and process startup).

For Boss, inventory, or scoring changes, run the entire combination class:

```sh
(swift test --package-path Engine --jobs 2 --filter ProductionCombinationMatrixTests) | boost
```

Its additional 2,052 Book × obstacle × Boss cases use cached legal-board fixtures
and actual engine actions. They cover restrictions, items, save determinism and
rescue identity, not every possible inventory or generated puzzle.

For a broad engine checkpoint:

```sh
(swift test --package-path Engine --jobs 2) | boost
```

The pre-addition full suite passed **251 tests in 90.941 seconds** (92.95 wall).
The new 108-start test passed separately. No product source changed between them.

## App checks: select by changed behavior

Reuse `/tmp/numberclub-route-build` where available. Use one isolated simulator,
`-jobs 2 -parallel-testing-enabled NO`, and XCTest timeouts. Do not overlap a
native playthrough with a build or rendering gate.

- Unlocks, Book identity, cloud merge, rewarded-ad close/resume:
  `BookProgressionMatrixTests` and `BookstoreObstacleTests`.
  Latest tests took 22.108 + 16.042 seconds, excluding host startup.
- Book colors, artwork, paused motion and margins:
  `BookPresentationThemeTests`, `BookLivingSceneTests`, `BookScenePresentationTests`.
- Route changes: `RoutePresentationTests`; add `BriefingBoundsTests` only when
  layout changed (the latter takes about 80 seconds).
- Benefit-label changes: `BookBenefitPlaqueRenderingTests`. Its 72 OCR renderings
  take about 42 seconds; they are not needed for an unrelated engine edit.

Use `xcodebuild test -only-testing:ProbablySudokuTests/<Class>` with the existing
project/scheme and an explicitly resolved test simulator. A screenshot assertion
failure requires inspection of its image before changing the game.

The 2026-09-07 broad app pass had 54 passes / 55 tests in 167.164 test seconds
(235.75 wall including build/startup/teardown). The remaining badge OCR assertion
misread a neighboring glyph as an extra digit; its full screenshot shows the
correct `0 → 10`. A narrower OCR region caused a different recognition failure
and was reverted. This is an outstanding automated-check issue, not a clean
55-test pass. Do not repeatedly rework OCR or change correct artwork to satisfy
it; retain the screenshot evidence and keep this limitation explicit.

## Native checks remain separate

Real touch hit testing, transition timing, sustained device performance and
human difficulty are not proved by these matrices. Use short, bounded native
sessions for those risks, preserving saves and existing watchdog limits. Reserve
whole-Book playthroughs for end-to-end/balance evidence instead of repeating them
to verify every arithmetic or unlock rule. Never mark the remaining Books as
human-completed because their automated checks passed.
