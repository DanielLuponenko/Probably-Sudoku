# Book return, benefit plaque, audio and onboarding — 2026-09-06

## Scope and safety

Implemented the current request only: reverse shelf return, reference-style
benefit plaque, music/SFX/haptics, three volume sliders and optional first-visit
practice. Paid-ad rollout and the full-book playtest remain paused. The existing
playtest simulator/run was not installed over, reset, or advanced. Existing
uncommitted gameplay/progression changes were retained. No commit, push,
TestFlight upload or physical-phone installation was performed.

## Behavior

- Top/middle/bottom return samples the original extraction path backward,
  including partial-extraction cancellation. Plaque and dimmer fade in place.
  The interactive cover stays visible until the newly unhidden SceneKit twin
  has completed a real GPU frame; rack controls stay locked until it is seated.
  Reduce Motion avoids the spatial journey.
- Cream/double-olive plaque, per-book tinted icon and value badge, equal 2%
  screen gutters. Volume 5 reads `+1 Toss`, `5 numbers per puzzle`, `4 → 5`.
  A live check caught Volume 9 truncating `45`; the full comparison now fits
  as one attributed line, with regression checks for every book.
- Bundled Suno `Morning Puzzle` instrumental, quiet AAC conversion, six short
  original procedural effects. See `AUDIO_ASSETS.md` for source/provenance.
- Persistent Master/Music/Sound effects sliders in both settings surfaces.
  Zero mutes; master multiplies both channels. Legacy mute preferences survive.
  Silent Mode, background, interruptions, disconnected headphones and external
  full-screen audio presentations are respected.
- Distinct, throttled Core Haptics patterns for selection, placement, error,
  toss, page turn and clears; retained prepared fallback generators. Haptics
  remain independently switchable and shut down when inactive.
- A new local user sees “Have you played Probably Sudoku before?” after the
  studio intro. Yes, Skip and Complete lead to the normal menu. The idle guide
  takes 97 seconds after practice preparation; VoiceOver is self-paced and
  backgrounding cancels the current timer. Practice uses a fresh isolated Engine
  Game, never the player's model/save/profile/coins/cloud/ads. Wrong practice
  taps are harmless. Existing progress or a saved run bypasses first-visit UI.

## Evidence

- `swift test --package-path Engine`: **207 passed**, zero failures.
  Log: `/tmp/numberclub-feature-engine-tests.log`.
- Focused iOS app-host suite: **81 passed**, zero failures. Covers tutorial,
  eligibility/store, audio policy/preferences/PCM and Apple AAC decoding,
  ad-audio boundaries, all rack paths, frame readiness/cancellation, all-book
  plaque OCR at 375/402/440-point widths with Obstacles I/IX, final-book routing.
  Result: `/tmp/numberclub-new-features-final-tests.xcresult`.
  Log: `/tmp/numberclub-new-features-final-tests.log`.
- Unsigned **Release iPhone build succeeded**, ordinary test-ad configuration.
  Log: `/tmp/numberclub-audio-onboarding-device-build.log`.
- Clean isolated iPhone 17 Pro simulator:
  `53F09D59-73E1-41FF-8B20-3C9B0E7B8502`.
  Visually checked welcome, practice/automatic advance, Skip to menu, no repeat
  welcome on relaunch, settings, mute, three-tier selection/return and plaques.
- Final plaque: `/tmp/numberclub-benefit-plaque-final.png`.
- Initial motion recording: `/tmp/numberclub-book-return-2026-09-06.mov`.
  Its brief cover handoff gap motivated the GPU-ready fix.
- Updated motion recording: `/tmp/numberclub-book-return-final.mov`.
  Reviewed extracted middle/bottom return frames with the cover retained
  through the handoff. Earlier top/middle/bottom path recordings and numerical
  reverse-path tests cover the unchanged trajectories.
- `git diff --check` clean.

## Limits

This is focused feature verification, not a completed full-book playtest or a
claim that every previous dirty UI change has been revalidated. Hardware haptic
feel and speaker/music balance still need a hands-on iPhone check. Simulator
recordings do not establish physical-device frame rate. The pre-existing
non-Sendable function-conversion warning in puzzle preparation remains.

An initial audio test run exposed fixtures reading the QA simulator's real
muted-music preference. Tests now inject their own mix; the saved preference
was preserved, and the final app-host run passed.
