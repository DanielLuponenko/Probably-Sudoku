# Version 1.0.1 build 13 — interactive tutorial

10–11 September 2026, Asia/Jerusalem.

## Scope and authorization

Build 13 succeeds the released version 1.0 build 9. The user authorized testing,
merging to main, TestFlight distribution and submission of 1.0.1 to App Review,
with manual release after approval. Build 9 was released by the user; this task
observed Ready for Distribution and its public App Store listing.

The tutorial now has 24 steps requiring real selection, placement, banking,
purchase, Marker placement, Buff use, selling and Cash Out actions. It teaches
Bookmarks, additive multipliers, Markers, one-use Buffs, refunds, Book benefits
and Boss rules. Practice uses an isolated engine Game and cannot affect saved
Books, coins, achievements or ad requests. The prepared Shop budget and puzzle
are explicitly explained. There is no timed autoplay or action-skipping button.

The Hand appears before the board. Instructions scroll independently from the
exit/progress bar and necessary action buttons. Accessibility text sizes use a
compact progress/exit bar and omit repeated footer hints so the lesson has room.
Production game rules and persistence schemas are unchanged; Shop additions
only expose initializers for the existing value types.

## Verification

- 252 engine tests passed, zero failures.
- 39 app tests passed: tutorial actions and arithmetic, wrong/duplicate taps,
  completion/exit, replay save-byte isolation, onboarding, Settings presentation,
  distribution metadata and ad configuration.
- A complete manual simulator walkthrough exercised every one of the 24 steps
  through actual app controls and returned to Settings. Observed combination:
  265 base × 2 = 530, Fresh Ink raises it to ×4 = 1,060; both sales return 2
  coins; Cash Out leaves 31 practice coins. The Hand is fully visible.
- Three final hosted layout tests passed, zero failures. They cover 375×667,
  768×1024, item buttons, combination text
  and the largest accessibility text size. They inspect actual rendering and
  scrolling; the manual walkthrough separately proves control activation.
- Evidence root: `/Users/daniel/Downloads/ProbablySudoku-Build13-20260910/`.
  Prior simulator data was backed up before testing. Earlier failed harness
  attempts remain as evidence; public in-process SwiftUI accessibility traversal
  was replaced with the repository's hosted rendering approach.

## Ads and agreements

The Production configuration retains the real AdMob app and rewarded-unit IDs.
Simulator builds deliberately use test ads. Never use ordinary live ad clicks
or views as a test; production-device testing requires registered test devices.

AdMob now links this app to App Store ID `6808968186`. Initial app ownership
verification/readiness is pending: the UI reports Requires review and Verify app
to lift limit. Its app-ads.txt tab has no crawl details or ad requests yet.
The published file returns HTTP 200 with the exact publisher record for normal
and Google crawler user agents, and the public App Store developer website
matches. No speculative hosting changes were made. Unrestricted ad serving and
revenue have not been verified.

Free Apps Agreement and Digital Services Act compliance are Active. The Paid
Apps Agreement is New, which does not block this free app with AdMob and no
in-app purchases. No contracts or financial details were changed.

## Distribution

App Store 1.0.1 uses new What's New text, tutorial reviewer instructions and
fresh screenshots. Manual release is selected. Archive, upload and submission
receipts follow.

- Source commit `b5ae7fa` merged via PR #116 to `d3233ed` on main. Archive source
  matches the merged app, engine and project configuration exactly.
- Production archive succeeded. Verified 1.0.1 (13), `com.numberclub.app`, live
  AdMob app ID `ca-app-pub-6970700553304979~2878649005` and rewarded unit
  `ca-app-pub-6970700553304979/5201560013`. Code signature valid, three privacy
  manifests, no test bundles. Application/dSYM UUIDs match:
  `A8550BAC-D025-3EC3-ABAA-056A6997514F`.
- App Store Connect upload succeeded at 23:38:20. GoogleMobileAds and UMP vendor
  dSYM warnings were non-blocking; the application's own symbols match.
- Apple processing completed. Build `50a3f877-85fc-4781-9f0f-92c50f7a58c0`
  was added to Public Beta and approved for TestFlight. Testing instructions
  include the tutorial, save isolation and registered-device ad testing.
  Existing invitation: https://testflight.apple.com/join/SHA5Tbzz.
- Build 13 is selected for 1.0.1 with manual release. The saved review contact
  was verified through native accessibility; browser DOM reads incorrectly
  report its phone/email fields empty. Existing details were preserved.
- Twelve fresh native screenshots replaced the draft's five old iPhone and
  three old iPad images. All six 1284×2778 iPhone images and six 2048×2732 iPad
  images were accepted unchanged, with no upload errors. Both ordered galleries
  were verified after reloading App Store Connect. Other display sizes inherit
  these primary sets; no separate old overrides were present.
- Gallery order is gameplay, selected Book, Shop, rack, tutorial Hand and
  multiplier lesson. Both selected Book images show `+1 HAND SIZE` on the
  physical green sign and no retired lower banner. New screenshots belong to
  1.0.1; the public 1.0 listing keeps its current images until the update is
  approved and manually released. [Capture evidence](screenshots/version-13/CAPTURE-MANIFEST.md).
- Apple acknowledged **1 Item Submitted** on 11 September 2026 at 00:06
  (Asia/Jerusalem). The submission details list **1.0.1 (13), Waiting for Review**.
  Submission ID: `8ba568f0-93f3-4b5a-92cb-c5886334debd`.
  [App Review receipt](https://appstoreconnect.apple.com/apps/6808968186/distribution/reviewsubmissions/details/8ba568f0-93f3-4b5a-92cb-c5886334debd).
  Manual release remains selected; no public release of 1.0.1 was performed.

## From TestFlight to the App Store update

TestFlight distributes build 13 to testers; it does not update the public app.
The same uploaded build is selected for App Store version 1.0.1 and submitted
to App Review. Approval of version 1.0 build 9 does not approve a later binary.
After Apple approves 1.0.1, manual release leaves it waiting for the owner to
choose Release This Version. The approved update and its new screenshots then
replace the public version. Existing players receive 1.0.1 through App Store
automatic updates or by tapping Update; they do not need TestFlight.

Apple references: [create a new version](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version),
[submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app),
and [release options](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option).
