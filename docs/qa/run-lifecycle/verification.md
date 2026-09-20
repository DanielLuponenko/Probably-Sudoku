# Continue, save/resume, and abandon audit

Date: 2026-09-19

## Confirmed defects and fixes

- **Repeated progression:** the Reduce Motion / missing-renderer page-turn path calls its action synchronously. Repeating Shop Continue could advance again from the new briefing. GameModel now requires the corresponding saved phase before dealing, opening the Shop, or advancing. Repeated payout, Keep Filling, and retired-owner actions are inert.
- **Resume conflict bypass:** the flat shelf's Continue directly loaded the local save even if iCloud held another copy. Both front-door entry points now require a conflict decision. Decisions are rechecked against the displayed snapshots before replacement or cloud adoption.
- **Stale animation ownership:** opening and closing callbacks now carry a transition token; closing also verifies the exact model owner. An old completion cannot clear a later Book.
- **Abandoned cloud resurrection:** removing a cloud key left no durable evidence of abandonment. Local discard receipts and optional cloud metadata now reject delayed legacy copies of the discarded attempt and preserve unrelated remote Books.
- **Storage failure handling:** failed local writes no longer publish newer cloud state. Failed deletion leaves the current Book open. Starting/adopting a Book requires a successful local save. Interrupted deletion uses a pending receipt, including write/remove/rollback failure paths.
- **Replacement durability:** a new Book is saved before its cover opens. Replacement atomically overwrites the run file instead of deleting the old save first. Failed replacement keeps the old Book; interrupted receipt finalization still recovers the new Book.
- **Completion durability:** a failed permanent unlock write no longer marks the completion acknowledged. The completed receipt stays open and saved until retry succeeds; closing cannot remove the last recovery source. Repeated acknowledgement never pays again.
- **Keep Playing:** cancelling the abandon decision now closes Settings and returns directly to the current game.

## Automated verification

Build 2 (final candidate): **137 selected app tests passed, zero failures**. Build 1 passed 127 before the final durability additions.

Logs: `/tmp/nc-run-lifecycle-test1.log`, `/tmp/nc-run-lifecycle-test2.log`

Final result bundle: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_18-35-39-+0300.xcresult`

Suites: ProgressionNavigationTests, DiscardedRunPersistenceTests, CompletionDurabilityTests, RunPersistenceLifecycleTests, CloudRunTransportTests, CloudRunConflictTests, RunStoreCompletionCompatibilityTests, FinalBookRoutingTests, KeepFillingResultsTests, PreparedPuzzleTests, SkipRewardSessionTests, RewardedRescuePersistenceTests, RewardedRescueSessionTests, TikTakClockTests, MenuReturnTransitionTests, PageFlipTests.

The 24 new storage regressions use temporary directories, injected I/O failures, and an in-memory cloud transport. They do not read or change the player's iCloud account. The 8 navigation regressions include actual repeated PageFlipper Reduce Motion callbacks and semantic save round trips. Two completion-durability tests inject in-memory persistence and disable profile reporting.

## Native verification

See [independent native review](native-review.md). The candidate is installed on the dedicated Book Playtest A iPhone 17 Pro. The user's simulator and saved Book are separate.

Final build 2 was also installed and launched normally on the user's iPhone 17 Pro (`223A…`). All five Application Support files were verified byte-identical through installation. Backup: `/tmp/NumberClub-run-lifecycle-user-backup-20260919`.

## Compatibility and limits

Game JSON and prior Clipping/reward effects are unchanged. Existing schema-1 cloud payloads still decode; discard metadata is optional. Completed receipts remain resumable, failures remain excluded, and rescues retain their existing phase and budget.

Legacy saves identify an attempt by seed, Book, and obstacle. A deliberate local restart with exactly the same identity remains playable locally; an ambiguous remote copy remains excluded after abandonment. Normal Book starts generate a new seed. Actual cross-device iCloud delivery was simulated, not tested with two signed-in devices.

The existing completed-Book route still opens the flat shelf focused on the completed volume; failure/abandon returns to the 3D Bookstand. A Save & Return to Bookstand control would be a separate UX addition; closing the app already retains the active Book.
