# Native motion preference verification

2026-09-19. Independent reviewer: graphics_native_qa. Candidate: `/tmp/NumberClub-game-motion-candidate.app`. Actual iPhone 17 Pro simulator D04, iOS 26.3. No production files edited or builds run by this reviewer.

## Verified

- Original game preference was absent. Actual iOS Settings Reduce Motion was switched from off to on and verified by accessibility Value 1 and screenshot. With the absent/default game preference, the studio intro animated, the camera moved toward the rack, Next Book animated rack rotation, a selected cover moved forward, the cover swung open, and briefing-to-puzzle used a visible curling sheet. The game therefore retains full motion while the OS preference is on.
- The in-game Reduced motion control initially showed Off. Switching On updated its checkmark and the Background motion explanation in the same open Settings panel. Closing preserved every board square, hand UUID, score, coin count and Turn (90 compared accessibility records).
- After terminating and relaunching the app, the control still showed On. Its next briefing-to-puzzle transition used a short stationary crossfade without a curled sheet; the recorded 20 fps contact sheet shows the change.
- Switching Off live preserved the next fixture's complete board, hand identities, score, coins and Turn. After another process termination/relaunch, the control still showed Off and the next page turn again showed curled intermediate frames. Actual iOS Reduce Motion was independently rechecked as still On before restoration.
- Settings copy and the new switch fit the native normal text-size panel. Background motion retains its own saved On setting while the new Reduced motion preference suppresses its effects.

## Evidence

- `ios-motion-on.png`, `game-motion-on.png`, `game-motion-off-after-relaunch.png`.
- `ios-on-game-default-intro-rack-book.mp4`: concise chronological excerpts of intro, camera approach, rack rotation, cover pullout/opening and page curl. Idle gaps are deliberately cut.
- `ios-on-game-reduced-relaunch-page.mp4`: five-second excerpt of the reduced page transition after relaunch; `reduced-page-contact.png` shows its frames.
- `ios-on-game-full-relaunch-page.mp4`: five-second excerpt showing the full page curl after the saved preference was turned back off. `full-page-contact.png` also contains its intermediate curled sheet.
- Uncut recordings retained at `/tmp/NumberClub-motion-native-recordings`.

## Limits

Rack rotation was exercised through its actual accessible Next Book action. A CUA coordinate drag selected a Book instead of establishing a reliable physical flick, so finger-flick timing is not claimed as native coverage. Root's gesture tests are separate evidence. This focused native check did not replay every boss effect or annotation, and did not test physical devices. SE remained untouched for this change.

## Restoration and disposition

Before testing, both isolated devices' Application Support and Preferences were backed up with SHA256 manifests (eight files each). D04's iOS Reduce Motion was restored to Off; `restored-ios-motion.png` records it. D04 was then shut down to avoid cached preference writes, its original app data and preferences restored byte-identically, and it was booted without launching the game. Final manifest checks passed for all eight D04 files and all eight untouched SE files. Original backups remain in `/tmp/NumberClub-motion-native-original-D04` and `-SE`; test state is retained in `/tmp/NumberClub-motion-native-D04-test-state`.

No unresolved native issue found in the changed behavior. All recorders and the QA game process were stopped. CUA was released to the parent before its user-device handoff; this reviewer never touched user device 223A.
