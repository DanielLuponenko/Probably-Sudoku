# Build 9 — current release checkpoint

Updated 6 September 2026. **Submitted to App Review; Waiting for Review; not publicly released.**
This checkpoint supersedes the earlier ad-free/build-8 planning notes. Build 8
and all previous screenshots, archives and verification logs remain preserved.

## Gameplay fix

`Puzzle.canKeepFilling` now requires a won puzzle, at least one empty cell and
remaining turns. Engine actions and Results UI use the same condition. A full
board offers cash-out, not Keep Filling. The model changes page only when the
action succeeds. Legacy saves already stranded in `keepFilling` on a full board
recover to `won` without awarding the completion bonus again or changing coins.

Regression evidence:

- Engine: 211 tests, zero failures, including four new completion tests.
  `/tmp/numberclub-keep-filling.yZDOro/all-engine.log`
- iPhone: 103 focused app tests, zero failures.
  `/tmp/numberclub-build9.whT3CJ/iPhoneFocused.xcresult`
- iPad: 88 focused app tests, zero failures in the scheme's Debug test configuration.
  `/tmp/numberclub-build9.whT3CJ/iPadFocusedDebug.xcresult`
- Production simulator compilation succeeded and actual bundle metadata uses
  the complete Google demo app/ad-unit pair. An initial attempt to run the
  Production test bundle failed because that configuration does not enable
  `@testable` imports; this is preserved in `iPadFocused.xcresult`, not counted
  as a passing test run. No archive settings were weakened for testing.

These are separate, overlapping gates, not a sum of unique tests. They do not
prove signed-in Game Center delivery or the live consent/advertising service.

## Production candidate

- SDK-enabled `ProbablySudoku-AppStore` scheme archives Production build **1.0 (9)**.
- Archive: `/tmp/numberclub-build9.whT3CJ/ProbablySudoku-Build9.xcarchive`.
- Bundle `com.numberclub.app`; arm64 iPhoneOS; iPhone and iPad supported.
- Real publisher app ID `ca-app-pub-6970700553304979~2878649005` and rewarded
  unit `ca-app-pub-6970700553304979/5201560013`; mode `live`.
- 50 SKAdNetwork identifiers; GMA 13.9.0 and UMP 3.1.0 manifests present.
- Signature verification passed. The preserved archive is development-signed;
  App Store export re-signed the upload with **Apple Distribution: Daniel
  Luponenko (233268ZQDV)** and `get-task-allow=false`. App/dSYM UUIDs match.
  Game Center and iCloud key-value-store entitlements are present in the export.
- No test bundle, preview/debug dylib or inspected QA marker in the archive.
- UMP permission gates SDK initialization and requests. Publisher first-party
  ID and personalization are disabled before startup; each request has `npa=1`;
  creatives are limited to general-audience content. No ATT permission request
  or tracking usage-description string is present.
- Debug, routine Release and simulator configurations remain test-ad-safe.
  A Production binary does **not** become test-ad-safe merely by being installed
  through TestFlight; do not assign this candidate to routine testers without
  appropriate test-device configuration.
- **Distribution export/upload succeeded at 09:57 local time.** Receipt:
  `/tmp/numberclub-build9.whT3CJ/upload.log`, `EXPORT SUCCEEDED`, delivery UUID
  `2ef110fe-6a05-4fe9-ada2-465ec561ec24`. App Store Connect then completed
  processing: **1.0 (9), Complete / Ready to Submit**. Build **9** was selected
  and saved for App Store version 1.0; re-opening the version confirmed the
  saved build row. On **6 September at 11:02 local time**, version 1.0 with
  build **9** was added to a draft submission. At **11:18 local time**, the
  complete 23-item package was submitted and Apple confirmed **Waiting for
  Review**, including the app version **1.0 (9)**. Submission ID:
  `2c697991-b5a9-42d9-b31c-7dffe6baff75`.
- Two non-blocking upload warnings concern missing vendor dSYMs for Google
  Mobile Ads and UMP; the app's own symbols match. The upload was accepted.
  Do not commit/share raw `.xcdistributionlogs`: they may contain authentication
  headers. No testing-group assignment or public-beta change was performed.

## Saved portal configuration

The release owner directly saved and re-opened the following settings:

- App Store Support URL and Marketing URL:
  `https://probably-sudoku-support.dannyluponenko.chatgpt.site`.
- Privacy Policy URL:
  `https://probably-sudoku-support.dannyluponenko.chatgpt.site/privacy`.
- TestFlight Marketing/Privacy Policy URL fields updated to the same public
  destinations. Existing build-7 public-beta description/notes preserved;
  build 9 has not been distributed to that group.
- Build-9-specific What to Test notes saved, covering full-board continuation,
  layouts, book progression, Game Center, and the requirement to designate
  test devices before ad QA. Its groups and individual testers remain zero.
- Review notes describe the free game, optional rewarded video, exactly three
  extra turns once per puzzle, no reward on cancellation, ability to End Book,
  consent/ad-availability constraints, and no reviewer login.
- Existing review contact phone/email were visually re-verified after the
  final Save. Browser DOM/AX reads misleadingly report those fields empty;
  do not overwrite them based on that alone. No reviewer credentials required.
- Game Center version-level checkbox saved and verified checked. All **3
  leaderboards and 19 achievements** were included in the same first app-version
  submission. Apple individually lists all 22 components **Waiting for Review**.
  Existing achievement metadata, 50 points each (950 total), and processed
  artwork were preserved. This is not authenticated-delivery or review approval.
- Advertising **Yes**, re-opened in Apple's rating questionnaire to verify it
  persisted. Calculated rating remains 13+ with regional variations.
- Free price schedule set with a USD $0.00 base and zero-priced equivalents.
- Availability saved for **173 countries/regions**, excluding **China mainland**
  and **Vietnam**, because the required game licences have not been supplied.
  Future new markets are not automatically enabled without checking requirements.
  The user authorized every currently permissible launch country.
- Mac and Vision Pro automatic availability disabled: this launch is verified
  for iPhone/iPad, not those additional platforms.
- After the trader-status explanation, the owner expressly declared
  **non-trader** on 6 September. That declaration was saved and verified:
  Business shows DSA **Active / all requirements completed**, and App
  Information confirms the app-specific **non-trader** selection. No public
  trader contact details were entered. This records the owner's declaration,
  not an independent legal determination.
- Apple App Privacy now has **nine published categories**: existing
  Gameplay Content/User ID plus Coarse Location, Device ID, Product Interaction,
  Advertising Data, Crash Data, Performance Data and Other Diagnostic Data.
  All seven SDK categories have their deployment-specific purposes and linkage
  saved, with tracking No based on the follow-up supplier-documentation review
  in the privacy audit. Diagnostics are unlinked; the other SDK categories are
  linked. No Developer Advertising purpose is declared for this rewarded-only
  deployment. **Published on 6 September 2026:** the owner explicitly authorized
  publication after the confirmation was explained. Apple's final Publish
  action completed, and the portal verified “Published a few seconds ago by
  Daniel Luponenko” with all nine categories and their saved purposes/linkage.
  Publication of the privacy label is not App Review submission or approval.

## AdMob consent messages

Both messages are verified **Published** for Probably Sudoku:

- `Probably Sudoku — European privacy choices`, English; Do Not Consent enabled.
  Google-only consent partner, automatic partner addition off, RTB creative
  consent checks on, special feature 2 off. Existing legitimate-interest
  controls preserved.
- `Probably Sudoku — US privacy choices`, English (en-US); all current/future
  supported US privacy-law states, opt-out enabled. Custom US ad partners:
  Google only.

Publication alone is not runtime proof. A follow-up isolated UMP-only probe
using the actual app ID verified European rejection, acceptance and withdrawal,
and persisted US sale/sharing opt-out, with no ad SDK linked. See
[runtime checks](BUILD-9-CONSENT-RUNTIME-CHECKS.md) for scope and evidence.
No real ads were viewed or clicked during release preparation. The app
still requires AdMob review and is not yet linked to a published store listing.
The public policy/support/app-ads.txt site remains deployed and HTTP-accessible;
that does not establish AdMob crawler verification or approval.

## Residual QA risks — not compulsory submission gates

### Physical-device scope update

The owner explicitly stopped iPhone 16 Pro testing on 6 September. Do not
resume it or make that particular phone an Apple submission prerequisite.
Its saved data was preserved while installing the routine Release/demo-ad
variant of source build 9; the App Store candidate remains the unchanged
Production/live-ad archive. Console streaming and the device-testing agent
were stopped. No live ad requests or synthetic Game Center scores were used.

Earlier console/debugger-assisted launch attempts terminated, including one
SIGKILL. No application crash cause was established. The final normal launch
at 10:42:28 local produced UIKit scene/haptic messages through 10:42:37, so do
not present those earlier attempts as proof that the uploaded app crashes
before main. Authenticated Game Center delivery and physical consent testing
remain unverified, not failed. The completed simulator CMP evidence is retained.

The remaining limitations are authenticated Game Center score/achievement
delivery and the complete Production app's physical-device consent/ad
integration. No-account tests and the isolated UMP probe do not establish
those results. Preserve these as unverified residual risks, **not compulsory
additional gates before submission**, and do not restart the stopped iPhone
16 Pro testing automatically.

## Submission complete — awaiting Apple

On **6 September 2026 at 11:18 AM local time**, **Submit for Review** completed.
Apple displayed **23 Items Submitted**. The review details page was then opened
and verified: version **1.0 (9)**, all **3 leaderboards**, and all **19
achievements** each show **Waiting for Review**.

[App Review submission](https://appstoreconnect.apple.com/apps/6808968186/distribution/reviewsubmissions/details/2c697991-b5a9-42d9-b31c-7dffe6baff75)

The saved release setting is **Automatically release this version** after App
Review approval. Free pricing and the 173 permitted launch markets are
unchanged. Upload, processing, build selection, privacy publication, the
owner-declared non-trader status and submission are complete. Approval and
public availability are still pending; no approval or release is claimed.
No physical-phone testing was resumed during the submission steps.

AdMob review after store linking is separate from Apple's App Review. Neither
TestFlight approval nor a successful upload is public App Store approval.
