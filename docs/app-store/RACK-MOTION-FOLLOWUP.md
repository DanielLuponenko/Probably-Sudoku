# Spinning book rack — 6 September 2026

## Cause and change

The old gesture handler ignored release velocity and immediately rounded to a
face using the same 0.42-second ease-in/ease-out action. Hard swipes could not
coast; snapping could reverse direction or restart acceleration.

`BookstoreRackSpin` now converts release velocity to angular momentum, projects
the resting face, and evaluates a continuous deceleration curve. Energetic
flicks match the finger's release speed and slow monotonically all the way to
rest, without a second snap animation. Gentle releases settle into alignment.
Maximum spin speed is bounded; stronger flicks travel farther and last longer.
Touch sensitivity is normalized to viewport width for phone/tablet consistency.

The SceneKit action samples absolute elapsed time, not fixed per-frame damping.
It does not rebuild SwiftUI or cover textures each frame. A locked playback
sample preserves unwrapped yaw and rejects late render callbacks after a new
gesture. Selection is published once at rest. New drags, selection, phase exits,
hidden presentation, teardown, and Reduce Motion cancel obsolete motion.

Accessible Select now faces the requested book forward before extraction, even
when invoked during a coast. A Reduce Motion preference change defers its
selection notification out of `updateUIView`. The stationary pose is read from
the model, using presentation state only while an actual turn action runs.

The focused-fix and SwiftUI performance guidance kept changes in the live rack's
motion owner, preserving the first-frame render delegate, extraction/return
paths, per-book progress, and retired Shop behavior.

API references: Apple's [pan velocity](https://developer.apple.com/documentation/uikit/uipangesturerecognizer/velocity(in:))
and [elapsed-time custom actions](https://developer.apple.com/documentation/scenekit/scnaction/customaction(duration:action:)).

## Verification

52 focused iPhone-simulator app tests passed, zero failures:

- 11 new pure motion tests: signed speed, bounds, invalid inputs, full turns,
  continuity, exact rest, normalized sensitivity, 30/60/120 Hz sampling.
- 9 new real coordinator/gesture-target tests: coalesced translation, momentum,
  cancellation/failure, Reduce Motion, re-grab, hidden/teardown/phase cancellation,
  and accessible turn-before-extraction.
- Existing selection, upper/lower return geometry, and per-book obstacle tests.

The first run exposed a stale pre-render presentation angle in the new catch
logic. The responsible layer was corrected; the final full focused run passed.

Evidence: `/tmp/numberclub-rack-verified.xcresult` and
`/tmp/numberclub-rack-verified.log`. Original failing evidence is retained in
`/tmp/numberclub-rack-focused.xcresult`. `git diff --check` passed.

In the isolated Save Regression simulator, native screenshots verified book
selection/extraction and reverse return still work. The desktop drag tool
delivered taps instead of reliable swipe input, so no claim of a complete
human-finger smoothness check is made. Gesture behavior was verified directly
through the real Objective-C gesture target plus deterministic motion samples.
No real user save or connected phone was touched in this task.

## Distribution boundary

Source and simulator only. No commit/push, phone install, archive replacement,
App Store upload, or review change. The earlier build-10 IPA does not contain
this later rack change and must be regenerated before the next distribution.
