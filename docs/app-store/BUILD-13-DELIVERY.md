# Version 1.0.1 build 13 — interactive tutorial

10 September 2026, Asia/Jerusalem.

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

App Store 1.0.1 draft created with inherited screenshots, new What's New and
tutorial reviewer instructions. Manual release is selected. Final archive,
upload and submission receipts are recorded below once confirmed.
