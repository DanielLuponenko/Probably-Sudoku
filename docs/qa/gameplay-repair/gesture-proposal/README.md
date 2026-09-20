# Proposed public XCTest gesture check

**Pending explicit user authorization. Typechecked only; never run, installed, or added to a project/scheme.** This is a reviewable alternative-input proposal after CUA drag delivery failed in the game and Apple's Settings. The existing CUA instructions require UI actions through `cua_repl` unless the user specifically requests another technology. The proposal does not supply that authorization.

[InventoryDiagonalGestureUITests.swift](InventoryDiagonalGestureUITests.swift) is an isolated draft containing three UI cases. Its setup skips before any app launch unless an explicit authorization sentinel is supplied. The sentinel is a second guard, not permission. Existing `project.yml` includes app source only from `App` and tests only from `AppTests`; this `docs` directory is excluded. No production, project, or existing test files were changed.

## Public API assessment

Apple documents `XCUICoordinate.press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`: an initial hold, movement to one coordinate, and a final hold. The coordinate class also exposes the simpler one-endpoint overload. [Apple coordinate drag documentation](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press%28forduration%3Athendragto%3Awithvelocity%3Athenholdforduration%3A%29), [Apple element drag documentation](https://developer.apple.com/documentation/xcuiautomation/xcuielement/press%28forduration%3Athendragto%3Awithvelocity%3Athenholdforduration%3A%29).

Read-only inspection of the installed public SDK agrees:

- `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks/XCUIAutomation.framework/Headers/XCUICoordinate.h`, touch methods at lines 42–46.
- `XCUIElement.h` in the same directory, press/drag methods at lines 147–174.
- `Modules/XCUIAutomation.swiftmodule/arm64-apple-ios-simulator.swiftinterface` confirms the public gesture velocity type; the draft uses `.slow`.

**Inference from these public signatures:** differing start/end x and y support a diagonal drag attempt, but no supplied waypoint list or continuing held-touch handle permits an arbitrary continuous curve. Multiple calls would be separate gestures. We must not call a sequence of diagonal drags one uninterrupted curved drag. No private event synthesis, pointer injection, alternate controller, AppleScript or tool implementation inspection is proposed.

## Cases and exact expectations

| Case | Authorized input, if approved | Expected outcome | Evidence limit |
| --- | --- | --- | --- |
| Outside cancellation | Duplicate-inventory fixture; drag right-hand Peek diagonally to the lower left, outside Sell; repeat with Stop Bookmark. | Same two Peeks and two Bookmarks, wallet 5, unchanged score, no item detail opened by release. | Does not test entering Sell and then steering back out during one gesture. |
| Duplicate Buff sale | Fresh fixture; right-hand Peek diagonally to Sell; open the surviving Peek and choose held 9. | Peeks 2→1, wallet 5→6; other inventory unchanged. Surviving Peek remains usable, consumes at legal reveal, leaves board unplaced/score 0, wallet 6. | Both copies share label/price and expose no UUID in accessibility. Live UI proves one removed/one usable, not which UUID survived. |
| Bookmark sale | Fresh fixture; Op-Ed diagonally to Sell, then open/close Run Info. | Op-Ed removed, Stop retained, two Peeks retained, wallet 5→7 once; overlay leaves 7. | Distinct named item selection, not a duplicate-Bookmark identity proof. |

The draft records start/end/app frames, screenshots and accessibility snapshots around each completed gesture. It uses existing `-skipStartScreen -seed GESTURE-PROPOSAL`, then the public Settings → QA Tools → Scoring fixtures → Duplicate Buffs route. It omits `-persistQA`; the fixture itself sets `savesProgress = false`. QA only arranges state; test outcomes require actual press/drag or normal activation.

Endpoint calculation is restricted to the SE portrait 375×667 viewport and explicitly fails if that size differs. The current trash center is `root.midX, root.maxY − 58` (64-point target starting 90 points above the root bottom). On this SE there is no bottom home-indicator inset. An authorized recording must still confirm the actual target and lift: an endpoint miss or simulator delivery failure is not by itself a product defect. No test has yet validated this geometry through native XCTest.

## Run plan after explicit authorization only

1. Root obtains an exclusive Simulator handoff. Use only SE `60D48736-12BA-4D48-ADCB-DC2DBB834730`; do not touch the user's large-phone device. Record current installed build and back up SE app data/profile. Preserve all earlier backups and failure artifacts.
2. Create an isolated temporary checkout/project copy under `/tmp`, keeping this workspace's app/project/test sources unchanged. Add a separate `bundle.ui-testing` target named `InventoryGestureProposalUITests` to that copy, with this draft file as its sole test source and the app target as its dependency. Add a dedicated `InventoryGestureProposal` scheme containing only that UI target. Do not add it to `ProbablySudoku` or its normal test plan.
3. Build the isolated test runner after authorization. The draft passed `swiftc -typecheck` against the installed public iPhone Simulator SDK (Swift 5 mode, iOS 18 target); that created no runner and performed no UI action. Configure the dedicated test runner environment with `NC_AUTHORIZED_XCTEST_GESTURES=user-explicitly-approved`; the app still receives no persistence flag.
4. In the authorized run, capture a Simulator recording through the ordinary recording facility, then execute only `InventoryDiagonalGestureUITests` on the fixed SE destination with parallel test execution disabled. Do not run the broad app suite concurrently. Keep its `.xcresult`, readable test log, recording and native attachments.
5. Review the recording for actual lift, both-axis movement, unclipped overlay, visible target, release-outside cancellation and release-inside sale. Match final inventory/wallet to the assertions. A passing count without an observed actual drag is insufficient. If the target/delivery is wrong, preserve failure and report it; do not use an unapproved input workaround.
6. Compare the normal saved run/profile with the backup. The ephemeral fixture must not replace the user's saved Book. Leave a clearly described state and explicitly return Simulator ownership. Report each case as passed/failed/tool-blocked separately.

No runnable shell launcher is included: the new temporary test target and final command should be made concrete only after authorization and ownership, with the actual latest build and temporary paths. The normal scheme remains unaffected now.

Typecheck evidence: `/tmp/nc-gesture-proposal-typecheck.log`, exit 0. The first direct compiler invocation omitted the SDK's XCTest Swift overlay search path and therefore could not resolve Swift assertion functions; adding the public `Developer/usr/lib` include path resolved it without editing the test. This is compiler validation of the proposal, not gesture evidence.

## Exact identity and curved-path evidence remain separate

Existing executed app-hosted tests establish UUID behavior without pretending to deliver physical touches:

- `BuffIdentityTests.testDelayedSaleRejectsAnIdenticalCopyInTheOriginalSlot`: two distinct same-definition copies; captured drag sale resolves the selected UUID; removing it leaves the spare UUID; stale drag cannot resolve the shifted spare or a replacement.
- `BuffIdentityTests.testSavedCopiesKeepDistinctActionIdentitiesAfterResume`: distinct copy IDs survive JSON round-trip and removal/slot shift.
- `InventoryDragTests.testCurvedMotionPreservesBothCoordinatesAndFingerOffsetBeyondTheInventoryRow`: successive points change direction and preserve both coordinates/offset beyond the row.
- `InventoryDragTests.testOnlyReleaseInsideTheVisibleTrashCommitsAndItCanCommitOnlyOnce`: entering the target then releasing outside cancels; release inside yields one sale, repeated end cancels.

An eventual passing diagonal UI check plus these tests would establish native gesture wiring for the observed diagonal path, inventory count/refund behavior, and separately the identity/path-resolution contracts. It would **not** establish a live continuous curved drag, midway target exit, arbitrary device geometry, or direct observation of the duplicate survivor's UUID. Those require a physical/manual continuous-path check or a separately approved public capability that actually supports it. Adding UUID accessibility identifiers solely to claim this proof is outside this no-production-change proposal.
