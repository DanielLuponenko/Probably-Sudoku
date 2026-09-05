# Flexible page turn — 2026-09-05

## Implementation

- Capture the displayed page once, including its current SwiftUI state. Do not
  reconstruct the outgoing page from a new GameModel.
- Render a subdivided Metal sheet with a bottom-right-led oblique fold, a pinned
  spine, and a gently bowed returned section. The printed front and opaque blank
  reverse are separate fragment paths on the same geometry.
- Change the destination only after the captured first frame is ready/presented.
  Drive progress from display timestamps, with no per-frame SwiftUI invalidation.
- Preallocate the mesh and three uniform buffers; no transient setBytes uploads
  during animation. Normalize snapshots to RGBA8 before texture upload.
- Cancel safely on interruption, reject stale callbacks/repeated taps, retain
  Reduce Motion navigation, and reconcile terminal puzzles after cancellation.

## Verification

- iPhone 17 Pro simulator, iOS 26.3.1: five held fractions (0.15, 0.35, 0.50,
  0.70, 0.90) inspected. No printed reverse, transparent fold, or clipped corner.
- Metal API validation: five consecutive forward turns in one process passed:
  puzzle → results → shop → briefing → puzzle → achievements. Controls became
  available after each turn; no GPU error or new crash report during this run.
- Simulator and unsigned generic iOS builds passed.
- Ten PageFlipTests passed; 136 Engine tests passed.
- The full app suite also runs an existing CoreGameplayTests expectation that
  `-bookRack` opens bookShelf, while FrontDoorRoute currently maps it to mainMenu.
  That unrelated test fails and neither its test nor routing code was changed.

## Evidence and limits

- Latest recorded turn: `/tmp/numberclub-page-turn-verified.mp4`
- Frame sequence: `/tmp/numberclub-page-turn-verified-contact.png`
- Held fractions: `/tmp/numberclub-corner-fold-held-contact.png`
- Consecutive navigation recording: `/tmp/numberclub-reused-buffer-navigation.mov`
- Sudoku-to-results recording: `/tmp/numberclub-reused-buffer-results.mov`
- Pre-change source backup: `/tmp/numberclub-page-flip-before-OjprUi/`

Simulator recordings are not physical-device frame-rate measurements. Physical
iPhone feel and wider iPad layouts remain unverified; a much wider page may need
a proportionally larger render margin. The prior unrelated working-tree changes
were preserved.
