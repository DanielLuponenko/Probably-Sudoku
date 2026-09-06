# Probably Sudoku 1.0.1 (10) — local release checkpoint

Verified 6 September 2026. The historical local checkpoint below is preserved.
The user subsequently authorized **TestFlight-only distribution of build 10**,
with build 9's App Store review left untouched. See
`BUILD-10-TESTFLIGHT-DELIVERY.md` for the current delivery record.

## Later source change: rack momentum

The subsequent user-requested spinning-rack improvement is implemented and
verified in the working tree, **not in the previously exported IPA below**.
A fresh, separately preserved TestFlight archive now includes it; the existing
archive below remains the earlier Game Center checkpoint. Build 9's review is unchanged.
See `RACK-MOTION-FOLLOWUP.md` for scope and evidence.

## Release hold

Version 1.0 build 9 remains in Apple's existing review submission, last observed
**Waiting for Review**. Do not cancel, edit, or replace that submission. The user
requested that build 9 be approved before an App Store update. The later explicit
TestFlight-only authorization does not permit replacing or editing that review.

The follow-up package uses version **1.0.1**, build **10**, because it is intended
as an update after the 1.0 launch. Apple requires an incremented version for that
workflow: [Create a new version](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version).

An hourly, read-only thread heartbeat (`watch-build-9-approval`) checks submission
`2c697991-b5a9-42d9-b31c-7dffe6baff75` for app `6808968186`. It remains quiet while
waiting/in review and reports approval, public availability, rejection, or a
required action. It does not upload or submit build 10; after approval, hold for
the user's direction.

## Completed follow-up work

- Backfill genuine historical Game Center achievements and retained leaderboard
  values at normal startup/authentication, with durable queues and bounded retry.
- Preserve larger pending scores and restrict historical awards to known IDs.
- Do not submit the default fresh-profile level or invent a score from an
  achievement threshold or unfinished puzzle.
- Keep real saved-profile/run reads exclusive to the live singleton; injected
  fake-client tests remain isolated from user storage.
- Retain the earlier post-build-9 fixes documented in
  `POST-BUILD-9-REGRESSION-AUDIT.md`, including Game Center's Settings access,
  same-Shop sale achievement handling, and save/cloud/lifecycle protections.
  The user's exact ad-close/resume failure was not independently reproduced;
  regression coverage is not proof of a specific unobserved root cause.

## Physical Apple receipt and save preservation

On the USB iPhone 16 Pro Max, the existing real Game Center account authenticated
normally. After the app's own startup backfill, supported read-only GameKit calls
returned all **16 existing earned achievements at 100%**, with no service error.
All three canonical leaderboards returned a player entry and no service error:

| Leaderboard | Apple readback |
| --- | ---: |
| Highest puzzle score | 5,125 |
| Highest level reached | 9 |
| Books completed | 1 |

5,125 is the exact retained banked best score in the saved run, not a fabricated
or recovered all-time record. No synthetic score or achievement was reported.
The debugger used read APIs only; the application performed genuine history
delivery. Pending queues drained after delivery.

Before/after JSON comparisons preserved the saved run, per-book progress,
earned achievement set, highest level, and completed books. No run was reset
or abandoned. The debugger detached and resumed the app.

The installed physical validation variant is **1.0 (10)** with development
signing and explicit Google **demo** ad IDs. The final package below is
**1.0.1 (10)** with production ad IDs. Only the marketing-version metadata changed
after the code tests; the phone was not reinstalled just for that metadata.
No live ad interaction or native Game Center dashboard visual check is claimed.

## Verification

- 223 engine tests passed, zero failures.
- 75 focused iPhone app tests passed, covering Game Center/backfill and ID
  migration, rewarded rescue persistence, cloud transport/conflicts, same-Shop
  sale achievements, keep-filling results, and rewarded-ad service behavior.
- 25 iPad Game Center/backfill and migration tests passed.
- Read-only code review found no additional issue in the backfill change.
- `git diff --check` passed; all pre-existing work was preserved.
- Production archive and local-only App Store export succeeded.
- Exported signature passed `codesign --verify --deep --strict`; signing authority
  is Apple Distribution, Game Center and iCloud key-value entitlements remain,
  and `get-task-allow` is false. Bundle ID is `com.numberclub.app`.
- iPhone and iPad device families are present. App, Google Mobile Ads, and UMP
  privacy manifests are bundled. App/dSYM UUIDs match.

The existing broader 338-test iPhone and 117-test iPad evidence remains documented
in the prior audit; this follow-up reran the affected gates rather than claiming
a fresh full UI playthrough. The existing Sendable conversion and absent
AppIntents metadata warnings did not fail compilation. Signed-out synthetic
simulator Game Center logs are not used as proof of real-account delivery.

## Local artifacts and evidence

- Archive: `/Users/daniel/Downloads/ProbablySudoku-Build10.XBbHNv/ProbablySudoku-1.0.1-Build10.xcarchive`
- Distribution IPA: `/Users/daniel/Downloads/ProbablySudoku-Build10.XBbHNv/AppStore-LocalExport/ProbablySudoku.ipa`
- IPA SHA-256: `a151cdc9bd77a1b7457ce5e28a1fc128790187ef3bf3a815f2b3a2785387f4c4`
- Final app/dSYM UUID: `8A84A2A0-487F-322E-B24D-0D25B3F99B04` (arm64).
- Evidence root: `/tmp/numberclub-build10.DmesK5/`
- Apple receipt: `game-center-readback.log`
- Preservation snapshots: `PhoneBefore/`, `PhoneAfter/`, and corresponding
  preferences plists. These contain private user data; do not publish them.
- Tests: `engine-tests.log`, `iPhoneFocused.xcresult`, `iPadGameCenter.xcresult`.
- Packaging: `archive-1.0.1.log`, `local-export.log`, `export-verification.log`.
- Export options: `ExportOptions-LocalOnly.plist`, explicitly
  `destination = export`, not `upload`.

Production packaging retains the configured live AdMob app/rewarded unit IDs.
No new ad account configuration or ad-serving approval is implied by packaging.
The earlier 1.0 (10) validation archive was retained separately, not discarded.
The immutable submitted build-9 archive remains untouched. No commit, push,
merge, App Store upload, or review mutation was performed in this follow-up.
