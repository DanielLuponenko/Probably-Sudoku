# Post-build-9 Game Center and save regression audit

Date: 2026-09-06. These are local follow-up changes, not changes to the submitted
build-9 archive or its App Store review submission. No submission was cancelled,
replaced, uploaded or released during this audit.

## Confirmed defects and fixes

- **Buyer's Remorse:** the achievement's existing same-Shop wording now matches
  the event. Bookmarks and Buffs record a persisted, run-local Shop visit ID.
  Rerolls retain that ID; another Shop in the same level does not. Older held
  items have unknown provenance and cannot earn a new false award. Already
  earned achievements and legacy saves remain intact. The visit ID consumes no RNG.
- **Game Center presentation:** the floating access-point badge stays inactive.
  Both Settings surfaces provide explicit leaderboard and Game Center achievement
  buttons; the local achievement page is retained. Apple's offered authentication
  controller is retained for an explicit user action, never forced at launch.
- **Game Center retries:** failed queued deliveries retry when the app returns
  to the foreground. In-flight guards and best-score coalescing prevent duplicate
  concurrent submissions or an offline retry loop.
- **Unreadable cloud runs:** the schema-1 envelope already decodes its `Data`
  payload. Trying to decode the enclosed game JSON as another base64 Data value
  always discarded a valid remote run. The loader now returns the original game
  bytes; the existing game decoder remains responsible for validation.
- **False cloud conflicts:** Sets and the Square-keyed boss foul map do not have
  stable serialized array order. Conflict detection now compares those seven
  unordered fields semantically, while retaining exact order for the Hand, board,
  Pool, inventory, marker squares and Shop offers. Actual game-state differences
  still preserve both saves and require a player choice.
- **Abandoned-book lifetime:** retiring a model invalidates the reward ticket,
  cancels puzzle preparation, stops clock sampling and disables further saves
  before clearing the run. A disappearing timed puzzle can no longer recreate
  an abandoned save or overwrite its replacement. Read-only models cannot clear
  a player's save.

## Ad-resume investigation

The earned-turn-loss report was not reproduced in the tested local resume path.
It was not assumed fixed merely because adjacent persistence bugs were found.

- In-memory integration checks exercise every Book on a non-default obstacle:
  termination before the earned callback preserves the offer, termination after
  the callback preserves exactly three turns, and another relaunch after spending
  one turn preserves exactly two. Board, Hand, score, book, obstacle and RNG state
  remain the same. Duplicate dismissal and stale tickets do not grant twice.
- On a newly created, signed-out iPhone simulator, used **Google's demo ad**, not
  a production impression. Seed `ad-resume-runtime`, Volume 1, obstacle I.
- Before the ad: persisted `outOfTurns`, turn 11, budget 10, reward unused.
- Waited for the SDK's visible **Reward granted** end card. Before dismissing it,
  inspected the actual atomic run file: `playing`, turn 11, budget 13, reward used,
  same Hand `[8,6,4,1,4,5,1]` and score 0.
- Force-terminated the app while the ad end card was still open. Relaunched with
  **no QA launch arguments**, used Play → same cover → Open the Book. The normal
  game UI restored the same board/Hand at **Turn 11/13**.
- Pressed the normal End Turn button. The UI and run file both advanced to
  **Turn 12/13** with the reward still consumed.

## Verification evidence

Evidence root: `/tmp/numberclub-resume-fixes.9qwI3s`.

- RED: `BeforeFix.xcresult` — cloud unwrap fails and abandoned clock remains live.
- GREEN: `AfterFix.xcresult` — 59 focused app tests, zero failures (reward service,
  session, full Book resume matrix, clock and save compatibility).
- `GameCenterShop.xcresult` — 24 focused tests passed before the two additional
  explicit-authentication tests were added.
- Engine: 223 tests passed, including 12 new purchase-provenance regressions.
  Log: `/tmp/numberclub-shop-provenance-full.log`.
- `iPhoneFull.xcresult` — all 338 app tests passed, including the final 11
  GameCenterService tests. This run predates the seven new cloud-conflict tests.
- `FinalCloud.xcresult` — 24 targeted tests passed with the final cloud comparison,
  transport, authentication and rescue persistence changes (including all seven
  new cloud-conflict tests).
- `iPadFocused.xcresult` — 117 focused app tests passed on a separate unsigned
  iPad test host, including the new logic and briefing/failure layout checks.
- `production-build.log` — Production configuration builds for generic iOS;
  this was an unsigned compile check, not a new distribution archive or upload.
- `signed-game-center-build.log` — normal Xcode-signed Debug simulator build
  succeeds. Overlapping test suites are not additive counts.

## Live-service verification boundaries

Unit tests use fake GameKit clients and isolated defaults. They do not prove
Apple accepted a score or award. No synthetic results were sent to a real account.

The initial unsigned simulator test host logged a missing Game Center entitlement
before GKErrorDomain code 3. That host is invalid for live GameKit verification;
it is not evidence of a defect in the already-signed App Store archive.

A separate normally signed simulator validation copy was checked on a fresh iPad
that has never run synthetic gameplay tests. Its simulator `__TEXT,__entitlements`
section contains `com.apple.developer.game-center=true` and the correct application
identifier (`233268ZQDV.com.numberclub.app`). The matching generated
`ProbablySudoku.app-Simulated.xcent` was inspected as well; Simulator puts these
entitlements in the executable section rather than the ordinary codesign payload.
The captured signed launch no longer logs the missing-entitlement rejection.

Settings was inspected visually and through accessibility. Both explicit Game
Center controls are available, with no floating badge or forced authentication
popup. In this signed-out environment Apple supplied no authentication controller;
the explicit tap correctly shows nonblocking sign-in guidance instead. A successful
real-account authentication, native dashboard and accepted score/achievement were
**not** observed. No credentials were entered or account settings changed.

Apple references: [Game Center entitlement](https://developer.apple.com/help/account/reference/capability-entitlement-updates/),
[player authentication](https://developer.apple.com/documentation/gamekit/authenticating-a-player),
[communications failure](https://developer.apple.com/documentation/gamekit/gkerror/code/communicationsfailure).

Authenticated dashboard/server delivery and actual cross-device iCloud sync must
not be described as verified without a successful real-account check. The cloud
transport/conflict tests use real serialized formats but no user's iCloud data.

No tests or installations were performed on the physical iPhone 16 Pro. Existing
playthrough simulators, phones and the submitted build-9 archive were preserved.

## Follow-up boundary

The investigation-first and surgical-patch workflow limited edits to reproduced
defects and their responsible state owners; the SwiftUI lifecycle guidance kept
authentication opt-in and retired-model callbacks harmless. No new ad setup,
content, gameplay balance or unrelated UI redesign was added.

These changes need a **new numbered build** if they are to replace the submitted
binary. Build 9 remains untouched in review. Before describing Game Center as
fully verified, use a clean signed-in test environment for authentication,
dashboard presentation and genuine earned-result delivery; do not sign a real
account into either synthetic-test simulator.

### Follow-up: user-authorized live verification

After the user authorized the remaining real-account check, opened system
Settings → Game Center on the clean signed iPad simulator
(`Probably Sudoku Tablet Regression`, `F7406F2F-8C95-49BC-A20F-FC7CC0558E41`).
Game Center was off and no Apple Account was signed in. Enabling Game Center
opened Apple's email/phone sign-in sheet. Left that sheet ready for the user;
no credentials were entered and authentication has not succeeded yet.

Once signed in, the minimal legitimate-play receipt check is two normal clipping
skips (Editorial Control / `com.numberclub.app.achievement.two_skips`), followed
by starting the boss puzzle (`com.numberclub.app.highest_level_reached = 1`).
Confirm the earned values in Apple's native dashboard or supported GameKit
readback, not merely by seeing an empty local delivery queue. A positive
Highest Puzzle Score requires actual scored play reaching results as well.

### Follow-up: quick physical iPhone 16 Pro check (2026-09-06)

The user subsequently authorized testing this phone. CoreDevice confirmed the
paired iPhone 16 Pro was reachable and had version 1.0 (9) installed. Normal app
launch succeeded, without QA arguments or a reinstall. iPhone Mirroring still
required the Mac login, so the native Game Center dashboard could not be used.
Supported debugger attachment was attempted as a read-only fallback, but did not
produce a usable authentication value or a server readback; it must not be counted
as a pass. Debugger sessions were closed; the app process was present afterward.

No score/achievement report or reset API was invoked, no credentials were entered,
and no saved-game files or account settings were modified by the checks. The
installed build predates the local post-build-9 fixes. Live Game Center
authentication and Apple's receipt of earned results remain unverified.

### Follow-up: USB iPhone 16 Pro Max (2026-09-06)

The user then explicitly offered the USB-connected iPhone 16 Pro Max. CoreDevice
confirmed wired transport, Developer Mode enabled, no passcode requirement, and
installed version 1.0 (6). Mac iPhone Mirroring remained login-locked, but a
supported LLDB attach with a bounded process-state event gate succeeded. The
normal app's `GKLocalPlayer.local.isAuthenticated` returned **true**, with no
evaluation error. No authentication handler or credentials were substituted.

Read-only GameKit calls returned the three canonical underscore leaderboard IDs
with no service errors. `loadEntriesForPlayers` returned no player entry on any
of the three boards; `GKAchievement.loadAchievements` returned an empty list with
no error. This proves authenticated service/catalog access, **not earned-result
delivery**. No report, reset, or invented-score calls were used in the probe.

The archived build-6 executable contains obsolete hyphenated leaderboard IDs.
The phone's genuine local profile contains 16 earned achievement IDs, highest
level 9, and completed volume 1, while both v1 pending delivery queues are empty.
Current code migrates pending IDs but does not replay all already-earned profile
IDs on startup: `recordAchievementChange` sends only newly earned awards, and
cloud merge sends only newly arriving awards. Therefore an empty older queue
leaves historical local awards absent from the canonical Apple records. Do not
assume an app update alone repairs this case. A history-backfill change and a
successful server readback remain follow-up work; no product code was changed
in this validation turn.

Before updating the phone, copied its Application Support directory and app
preferences to `/tmp/numberclub-game-center-usb.AJvm1U/`. Reused the current
post-fix ProductionCheck build cache with ordinary Apple Development signing
and explicit Google demo ad identifiers / `ADMOB_MODE=test`. The signed build
retains Game Center and iCloud entitlements; compilation and same-bundle device
installation succeeded. It is a **local test build**, still numbered 9, not a
new App Store upload or a replacement of the submitted immutable archive.

After the update, the normal app again authenticated and loaded all three
leaderboards successfully; Apple still returned no player entries or completed
achievements. Before/after JSON checks showed `run.json` and `progress.json`
unchanged. All 16 earned IDs, highest level, and completed volume were retained;
profile normalization added the expected per-book completion field
`completedObstaclesByBookID = { probably: 1 }`, alongside serialization ordering
and modification-time changes. No save was reset or abandoned. Debugger sessions
detached and resumed the app. The probe source and before/after copies are in
the temporary evidence directory above.

### Follow-up: historical Game Center delivery resolved, build 10 held locally (2026-09-06)

The user authorized the three follow-up items and explicitly requested that
build 9 remain in review before updating with build 10. Historical backfill is
now implemented in the live Game Center service. It merges known earned awards
and exact retained scores into the durable delivery queues before flushing;
fresh-profile defaults and unfinished puzzle scores do not become submissions.
Maximum queued scores are preserved, retries remain bounded, and injected test
clients never read the user's real profile or saved run.

The USB iPhone 16 Pro Max received a local development-signed build 10 with Google
demo ad identifiers. Normal app startup performed the backfill. Read-only GameKit
queries then confirmed Apple's records: **16 completed achievements**, highest
level **9**, books completed **1**, and highest puzzle score **5,125**, all with
zero service errors. The score is the exact retained banked best score, not a
reconstructed all-time maximum. No report/reset API was invoked by the debugger.

Before/after comparisons confirmed the saved run, book progress, earned award
set, highest level, and completed books were unchanged. Debugger sessions were
detached and the app resumed. This resolves the previously documented missing
historical-delivery evidence; native dashboard presentation and actual
cross-device iCloud transport are not newly claimed as verified.

Validation passed: 223 engine tests, 75 focused iPhone app tests, and 25 iPad
Game Center tests. Evidence is in `/tmp/numberclub-build10.DmesK5/`, including
`game-center-readback.log`, the before/after copies, and both `.xcresult` bundles.

The final follow-up package is **1.0.1 (10)**. Archive and local App Store export
succeeded, and the exported Apple Distribution signature passed strict
verification. Nothing was uploaded. Build 9 was last observed **Waiting for
Review**, unchanged. An hourly read-only approval check is active and must not
upload or submit build 10. See `BUILD-10-RELEASE-STATUS.md` for artifact paths and
the release hold.
