# Unlimited skips awarding Buffs — verification

Date: 2026-09-18

The execution results and manual screenshots below record the original skip implementation before the subsequent gameplay-shell and custom-panel integration. See [the integrated verification report](../gameplay-redesign/verification.md) for current results and the final independent playtest. The final audit section here maps the current code to its regression coverage; it does not claim a new test run or new manual validation.

## Implemented behavior

Every undealt ordinary Puzzle offers one named consumable Buff and its full catalogue effect. Offers use a fixed versioned reward table and a seed/Level/slot domain, independent of every live gameplay random stream. Boss Puzzles cannot be skipped.

Acceptance adds the Buff (or replaces the explicitly chosen instance), records the skipped position, reward UUID and replacement UUID, and advances exactly one slot. GameModel assigns the complete engine result once; its existing atomic RunStore write receives inventory, history and progression together. No Clipping bonus is generated. Full inventory cannot accept without a valid replacement UUID; cancellation does not mutate the run.

Saved Buff copies have distinct UUID identities. Historical saves migrate those identities deterministically, retain earned Clipping effects and history, and receive no retroactive Buffs. Shop purchase identities also avoid gameplay randomness. Delayed inventory actions resolve the original copy by UUID.

## Automated checks

- Engine: `swift test --package-path Engine` — 262 tests passed, zero failures, including 10 SkipBuffTests.
- Focused iOS simulator run (ProbablySudoku scheme): 42 tests passed, zero failures. Suites: SkipRewardSessionTests, RoutePresentationTests, PreparedPuzzleTests, BuffIdentityTests and BriefingBoundsTests.
- All 18 ordinary positions across nine chapters accept skips; each chapter reaches its mandatory boss.
- Offer reads, Shop exit, save/resume and seed-matched runs preserve offers and gameplay random streams.
- Empty, one-slot and full inventories; explicit replacement; invalid replacement and cancellation; duplicate Buff definitions with distinct persisted identities.
- Repeated claims, claims from another model, navigation away and back, frozen outgoing pages, completed and in-flight puzzle preparation cannot replay or overwrite a skip.
- Legacy Clipping coins, pending multiplier and interest-cap effects remain intact; no new Clipping effects or retroactive Buffs.
- OCR/render checks cover all 11 catalogue descriptions in compact and wide tickets, plus phone/tablet briefing bounds.

Focused result bundle: `/tmp/numberclub-skip-focused.xcresult`.

At this original checkpoint, the full ProbablySudoku app suite attempted 562 tests: 554 passed, six methods reproduced existing baseline assertion failures below, and two rendering cases were interrupted by simulator recovery. Both interrupted cases passed a separate rerun: **556 app tests passed across the completed runs; six pre-existing failures remained at that checkpoint**. No skip-specific test failed. The later gameplay integration addressed those six cases.

Full result bundle: `/tmp/numberclub-skip-full.xcresult`. Successful interrupted-case rerun: `/tmp/numberclub-skip-render-recheck.xcresult`. `git diff --check` passed.

## Independent hands-on review

A separate agent reviewed the implementation after focused verification and played the actual app on the compact SE-test iPhone simulator. It reported no actionable correctness defects.

- Full inventory: opening and cancelling replacement retained Puzzle 1, Peek and Fresh Ink, 5 coins, and no skip history. Run information and Settings preserved the Bird Seed offer.
- Double-tapping Replace Fresh Ink committed exactly one skip: Puzzle 2, Peek retained, Bird Seed added, 5 coins unchanged. The on-disk `run.json` contained one complete skip record with the chosen replacement UUID and the reward UUID matching inventory.
- Real relaunch through Play → Book → Open the Book restored Puzzle 2, the same Litmus offer, original inventory UUIDs and the single history record.
- Replacing Peek with Litmus reached The Censor boss briefing with no skip offer. Tapping the old offer region did nothing; Play entered the actual boss Puzzle.
- Duplicate rewards: seed `duplicate-skip-20` awarded Double Down twice with distinct saved UUIDs and two history records. In the actual boss Puzzle, double-tapping Use on the second copy consumed only that UUID, kept the first copy and armed Double Down; both history records remained.
- Empty inventory: double-tapping Double Down added one copy and one history record and advanced only Puzzle 1 → 2, with coins unchanged.
- Shop navigation: Shop → Continue revealed Insurance. Accepting it granted one Buff, advanced to the boss and retained the 5-coin balance.
- Pending animation: tapping the next Litmus skip then immediately opening Settings cancelled the delayed action. Closing Settings retained Puzzle 2, the same offer and original Double Down, with no extra record.

Screenshots:

- [Full-inventory replacement choice](independent-se-replacement-choice.png)
- [Offer restored after relaunch](independent-se-resumed-offer.png)
- [Mandatory boss after two skips](independent-se-mandatory-boss.png)
- [Empty-slot reward claimed once](independent-se-empty-slot.png)

On the compact SE, the briefing scrolls to show the ticket footer; the named reward and full effect remain readable before acceptance.

## Pre-existing full-suite failures

An isolated detached HEAD checkout at `/tmp/NumberClub-skip-baseline-20260918` included the original uncommitted brick edits and assets, but none of the skip implementation. Running BookVictoryRenderingTests and BookstoreObstacleTests reproduced the same six failing methods (24 tests, 118 assertion failures):

- `BookVictoryRenderingTests.testIPadResultsKeepPayoutNearHeaderAndActionsAtBottomWithoutMutatingRun`
- `BookVictoryRenderingTests.testShortRegularResultsOmitBoardPreviewAndKeepActionsVisible`
- `BookstoreObstacleTests.testCompletedBookKeepsItsOwnMaterialUnlockAfterSelectionReturnAndAnotherBookCompletion`
- `BookstoreObstacleTests.testInitialProgressAndSelectionArePrintedOnceBeforeTheFirstSceneUpdate`
- `BookstoreObstacleTests.testPreviewArtworkStaysLocalAndRealMaterialsContinueToRespectSavedAndDebugCeilings`
- `BookstoreObstacleTests.testRealShelfMaterialsKeepTheirOwnUnlocksAcrossFirstBookFocusReturnAndOtherBookFocus`

Results tests exposed existing board/payout/action layout problems. Bookstore tests compared textures rendered at scale 2 against production scale 1.5. These product/test corrections were subsequently included in the full gameplay integration; this baseline evidence is retained for provenance.

Baseline evidence: `/tmp/numberclub-skip-baseline-20260918.xcresult` and `/tmp/numberclub-skip-baseline-20260918.log`.

## Final requirement audit — 2026-09-19

Read-only implementation/test review found no new skip correctness issue. Current integration test results and the custom-panel hands-on recheck are tracked separately; the earlier suite totals above must not be treated as a final integrated pass.

| Requirement | Implementation and regression evidence |
| --- | --- |
| Unlimited ordinary skips throughout all nine chapters; mandatory bosses | `RunState.currentSkipOffer` checks position and phase, with no numerical allowance. `SkipBuffTests.testEveryOrdinaryPuzzleAcrossEveryChapterCanBeSkippedWithBossesMandatory` accepts all 18 ordinary positions, starts each boss, rejects boss claims without mutation, and resumes between skips. `SkipRewardSessionTests.testEveryChapterStillOffersOrdinarySkipsAfterPriorSkips` covers app claim policy across the same route. |
| One Buff, one skipped puzzle, complete history, no new Clipping bonus | `Game.skipPuzzle` appends one zero-price owned Buff and one `SkipRecord`, then advances one slot in a private run copy. The all-chapters test verifies position, reward identity, inventory count, unchanged coins and unchanged RNG streams on every acceptance. `testSkipRewardInventoryAndProgressionRoundTripAsOneSavedAction` checks history, inventory, progression and absence of new multiplier/interest-cap state in the exact storage payload. |
| Advertise a stable named Buff and full effect before acceptance | `SkipOffer` derives its reward from a frozen v1 catalogue table and a seed/level/slot domain, independent of live streams. Engine offer-read/resume/Shop tests and app redraw/navigation/Shop-resume tests verify equality. `BriefingBoundsTests` renders every catalogue description at compact and wide sizes. The current ticket makes the heading/effect inert and accepts only from its explicit bottom CTA; the short full-inventory test exercises the actual full-screen host and scroll-to-action layout. |
| Preserve two slots; explicit replacement or cancellation | Engine validation rejects a full inventory without a replacement, an unknown UUID, and replacement when space exists, without changing encoded state. `SkipRewardSessionTests.testFullInventoryRequiresAnExplicitChoiceAndCancellationKeepsEverything` verifies original copies survive cancellation/navigation and only the chosen UUID is removed. `SkipBuffReplacementSlip` now presents custom paper choices and Cancel; opening and dismissing it do not call the mutation. |
| Exactly-once claims despite repeated taps, delayed animation and navigation | The engine compares the complete offer and rejects recorded positions; GameModel additionally requires its own owner UUID and current revision. Engine duplicate/stale/resumed claim tests, `RoutePresentationTests`, and `SkipRewardSessionTests` cover repeated calls, other sessions, navigation and frozen outgoing pages. The briefing latches the pending claim/request and cancels it on background, unrelated cover, page turn or disappearance; replacement buttons latch their chosen action. |
| Background preparation cannot restore a skipped board or erase the reward | `game.didSet` invalidates preparation before persistence. Detached preparation works on a copy, and both publication and first-frame commit revalidate revision/request identity. `PreparedPuzzleTests.testAcceptedSkipInvalidatesAReadyDealWithoutLosingItsReward` and `testAcceptedSkipWhilePreparingCannotPublishTheSkippedPuzzle` verify completed and in-flight work cannot overwrite the accepted skip; the next prepared board retains the awarded Buff. |
| One consistent saved action | `GameModel.takeSkip` assigns `game = accepted` once after engine validation. `RunStore.save` encodes inventory/history/progression together and writes the payload with `.atomic`; preparation warmup only encodes discarded bytes. The storage round-trip test checks the whole accepted snapshot and rejects the prior claim after restoration. The earlier hands-on check also inspected the resulting on-disk record, replacement UUID and reward UUID. |
| Preserve old saves and earned Clipping effects; no retroactive rewards | Missing `skipHistory` decodes as empty; old `runItemState` keys remain intact. `SkipBuffTests.testLegacySaveKeepsClippingsAndGetsNoRetroactiveBuffsOrAllowanceLimit` verifies historical skip count, coin balance, pending multiplier and interest cap, deterministic repeated legacy decode, and no replacement rewards. A new skip leaves legacy effect state unchanged. |
| Duplicate Buff definitions retain separate durable identities | `OwnedBuff.id` is a persisted UUID. Legacy migration uses the run seed, array position and old attributes; reward IDs use the skipped position; Shop IDs use visit/reroll/slot. Engine tests cover duplicate rewards, deterministic migration and Shop purchases. `BuffIdentityTests` checks delayed sale/use resolution and resumed duplicate copies by UUID. |
| Remove allowance/exhaustion copy; retain useful totals/history | Source search finds no remaining `skipsRemaining`, allowance/exhaustion messages or numerical skip limit in App or Engine sources. `RunInfoSlip` displays total puzzles skipped, Buff skip records and historical Clippings. Profile achievement progress still records total skips. The wide-ticket OCR test explicitly rejects “skips remaining.” |

Reviewed sources: [skip engine](../../../Engine/Sources/NumberClubEngine/Skip.swift), [engine mutation](../../../Engine/Sources/NumberClubEngine/Game.swift), [run persistence/migration](../../../Engine/Sources/NumberClubEngine/Run.swift), [app claim and preparation lifecycle](../../../App/Model/GameModel.swift), [atomic storage](../../../App/Model/RunStore.swift), [briefing and replacement UI](../../../App/Views/PuzzleBriefingView.swift).

Regression suites: [SkipBuffTests](../../../Engine/Tests/NumberClubEngineTests/SkipBuffTests.swift), [SkipRewardSessionTests](../../../AppTests/SkipRewardSessionTests.swift), [PreparedPuzzleTests](../../../AppTests/PreparedPuzzleTests.swift), [RoutePresentationTests](../../../AppTests/RoutePresentationTests.swift), [BuffIdentityTests](../../../AppTests/BuffIdentityTests.swift), [BriefingBoundsTests](../../../AppTests/BriefingBoundsTests.swift).
