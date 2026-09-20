# Boss animation recordings

Open [the animation viewer](animations.html) to select any of the 39 bosses. Every entry has a real H.264 recording, a matching settled poster, replay, pause, slow motion and a close-up focused on the affected part of the screen. The inventory describes existing production behavior and explicitly identifies static or shared effects.

These silent clips record hosted production iOS views on an isolated iPhone 17 Pro simulator (402×874 points), using non-saving QA fixtures. The controls/model apply real placements, banking and Buff actions; animation is not recreated in the web page. The original user simulator and saved Book were not altered. This pass changes recording tests and review artifacts, not gameplay code.

- [All 39 clip paths, action timing and fixture disclosures](animation-clips.json)
- [Source-checked animation inventory](animation-inventory.json)
- [First recording timeline](animations/nc-boss-animation-recording-timeline.json)
- [Supplement and continuation timeline](animations/nc-boss-animation-continuation-recording-timeline.json)

The first pass recorded 26 complete segments, then stopped because the Chain Stitcher capture fixture incorrectly treated a given as a blank. That test fixture was corrected. The second pass successfully recorded the remaining 13 and a stronger Censor demonstration. The supplemental Censor test verifies that the actual zero-scoring receipt appears during production playback; it retains the engine's rolled digit and conserves the Hand/Pool when preparing the held card. Its clip replaces the initial Censor clip.

Collector uses an explicitly QA-completed target to expose the real cancelled-interest payout. Serial Publisher uses a disclosed 900-point target to make carry visible in a short clip. Tik Tak starts from a disclosed 32-second saved checkpoint to show the 30-second pulse; its earlier full final-minute recording remains linked separately. Ordinary page curls are not filmed by this hosted showcase. A description of an entrance does not imply every mechanic has unique entrance motion.

Both recording builds passed. The second capture run passed both selected test methods. All 39 exported videos were checked for valid H.264 streams, duration and matching posters. Browser verification covered playback, paused close-up, quarter speed, selection and 39-entry coverage. Independent review checked the inventory, file links, animation frames and controls; its findings were addressed.

Recording tests are opt-in:

- `BossAnimationShowcaseTests/testRecordEveryBossWithProductionMotionAndRealActions`: `NC_RECORD_ALL_BOSS_ANIMATIONS=1`.
- `BossAnimationShowcaseTests/testRecordRemainingBossesFromChainStitcher` and `BossAnimationCensorCaptureTests/testRecordCensorZeroScoreReceiptFromActualRolledDigit`: `NC_RECORD_BOSS_ANIMATIONS=1`.

Raw recordings and result bundles remain under `/tmp/nc-boss-animation-*` and `/tmp/NumberClub-boss-animation-*-20260920.xcresult`. First-pass partial capture evidence is retained rather than replaced or presented as a fully passing test run.
