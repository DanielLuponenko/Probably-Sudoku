# App Store release checklist — 1.0 launch preparation

**Current checkpoint: [Build 14 delivery](BUILD-14-DELIVERY.md).**
The sections below preserve the earlier September 6 planning checkpoint;
their pending URL/message/pricing/build-9 statements are superseded by that
dated status report and must not be used as the current portal state.


Updated 2026-09-06. **Not submitted to App Review or released publicly.**
App Store Connect statuses below are reported by the release owner; source,
artifact and screenshot evidence is linked separately. TestFlight approval
does not constitute App Store approval.

## Current owner decision — 6 September 2026

- Launch **free with an optional rewarded ad**, not ad-free: one completed ad
  can grant **three extra turns, once per puzzle**. Watching is optional; the
  player can end the Book instead. No purchase or paid currency is planned.
- The user approved the public support email and publication of the prepared
  support/privacy site. The release owner confirmed **public deployment**;
  unauthenticated support/privacy HTTP checks passed. App Store Connect
  support/privacy URL fields remain unmodified.
- Studio branding is **DlA**. The individual legal seller remains
  **Daniel Luponenko**; this is not an account/entity conversion.
- Build **7** remains the latest uploaded build. The unsigned SDK-free build
  **8** archive is preserved historical evidence, not the chosen launch product.
  Recommend **9** for the forthcoming monetized candidate to distinguish it
  from that evidence; build 9 has **not been built or uploaded**.
- The saved **no-ads Review Notes**, **ad-free App Privacy/policy draft**, and
  **Advertising: No** age-rating answer are now **stale**. Do not reuse or
  publish them as declarations for the monetized candidate. Google/UMP privacy,
  consent and rating review must precede their replacement and submission.

## Completed work and preserved historical evidence

- Build **1.0 (7)** uploaded and approved for the public beta:
  [Join TestFlight](https://testflight.apple.com/join/SHA5Tbzz).
  Preserved archive: `/Users/daniel/Downloads/ProbablySudoku-Build7-Final.xcarchive`.
  Upload acknowledgement: `/tmp/numberclub-build7-upload.8x8jgy/upload.log`.
  Do not substitute the older `ProbablySudoku-Build7.xcarchive` baseline.
- App Store description, keywords, subtitle, review contact and copyright
  saved by the release owner. Five native iPhone screenshots accepted by
  App Store Connect; see [capture manifest](screenshots/CAPTURE-MANIFEST.md).
  Saved copy and visually checked review-contact status:
  [store metadata](STORE-METADATA.md).
- User confirmed source-content rights; Content Rights declaration saved by
  the release owner. Music provenance remains in [AUDIO_ASSETS.md](../AUDIO_ASSETS.md);
  generation evidence for the ink texture is in [boss-ink-asset.md](../boss-ink-asset.md).
- Historical, superseded launch route: SDK-free build 8 source prepared using
  the `ProbablySudokuAppStore` target /
  `ProbablySudoku-AppStore` scheme, shared gameplay module, no Google package
  dependencies, `NUMBERCLUB_AD_FREE`, and disabled ad metadata in `project.yml`.
  The standard beta target remains separate. Preserve this rollback evidence;
  this target cannot provide the newly approved rewarded ad.
- Selected-book and briefing iPad layout fixes prepared. Native build 8
  recapture verified the complete plaque, separate Open button, all three
  shelf tiers and reverse return; see [version 8 manifest](screenshots/version-8/CAPTURE-MANIFEST.md).
  Version 7 iPad images are defect baselines, not upload candidates.
- Native Privacy policy and Support links added to both Settings entry points
  through `AppLinks` / `AppSupportSection`; destinations use the registered
  app-specific site. It was initially deployed privately. Public email/site
  approval, public deployment and unauthenticated accessibility verification
  are now complete.
- Support-site public deployment confirmed by the release owner on September 6:
  [support](https://probably-sudoku-support.dannyluponenko.chatgpt.site),
  [privacy](https://probably-sudoku-support.dannyluponenko.chatgpt.site/privacy),
  and [app-ads.txt](https://probably-sudoku-support.dannyluponenko.chatgpt.site/app-ads.txt).
  Version **2**, source SHA `cdee1b6d0aceaa9d3e09ce6b156d082f1d930b09`, deployment
  `appgdep_6a9d068f36d08191acfe5e57906f8c04`. The release owner verified
  unauthenticated support and privacy responses are **HTTP 200, no redirect**;
  `/app-ads.txt` is **HTTP 200** and exactly matches the AdMob console snippet.
  AdMob crawler/app verification is not yet complete. App Store URL fields
  are unchanged.
- Historical App Privacy draft saved, **not Published**: User ID and Gameplay Content,
  each used for App Functionality, linked to identity, not used for tracking.
  The release owner confirmed these two data types for the previous ad-free
  plan. This draft is now incomplete for Google/UMP and must be reviewed;
  see [store metadata](STORE-METADATA.md).
- Business status inspected read-only: **Free Apps Agreement Active**,
  August 20, 2026–August 20, 2027. **Paid Apps Agreement New**, with legal-entity
  information update requested before signing. EU trader declaration remains
  pending. No agreement was accepted or contact information published by this audit.

## Verification / submission gates

- [x] Latest combined SDK-free gate: **52 tests passed, 0 failures**, including `AppLinksTests`,
  `DistributionMetadataTests`, `AdConfigurationTests`, `RewardedAdServiceTests`,
  `FailurePageRenderingTests` and `BriefingBoundsTests`.
  `AppSupportSection` / `SupportLinkStyle` compiled successfully. Log:
  `/tmp/numberclub-appstore-ads-proof.IRjCj4/compact-ticket-release-tests.log`.
  Result: `/tmp/numberclub-appstore-ads-proof.IRjCj4/CompactTicketAndReleaseTests.xcresult`.
  Earlier SDK-free baseline: 49 tests passed in `focused-tests.log` in the
  same directory; it does not prove the subsequent link/layout changes.
- [x] Release owner uploaded and verified three corrected build 8 iPad images.
  Galleries are gameplay-first: iPhone gameplay / rack / shop / Next Puzzle /
  selected book; iPad gameplay / selected book / Next Puzzle.
- [x] Outer App Information Save confirmed by the release owner for the
  calculated **13+** age rating (frequent Game Center contests). This is a
  historical saved result: **Advertising: No** is stale after the September 6
  decision and the rating must be recalculated from accurate final answers.
- [x] Create the three matching Game Center leaderboard drafts: Highest Puzzle
  Score, Highest Level Reached and Books Completed. All are Classic / Integer /
  Best Score / High to Low, English (U.S.), **Prepare for Submission**. Apple
  rejected the original hyphenated IDs; the owner-authorized external-only
  underscore correction is now in source and matches the saved drafts.
  Exact IDs, server record links and queue migration notes:
  [Game Center configuration](GAME-CENTER-CONFIGURATION.md).
- [x] Create/localize all **19 matching achievement drafts**, each 50 points
  (**950 total**), Hidden No, repeatable No, source-matched English titles and
  pre-earned descriptions, truthful earned text, and unchanged app icon as
  temporary shared artwork. All 19 were reopened to verify processed `icon.png`,
  saved settings and **Prepare for Submission**. Record links are in the
  [Game Center configuration](GAME-CENTER-CONFIGURATION.md).
- [ ] Approve final Game Center points/earned text/artwork and verify authenticated
  delivery before publication. No component was added for review, enabled for
  an app version or submitted by these draft-preparation tasks.
- [x] Publish the approved support/privacy site and verify unauthenticated HTTP
  access, including the exact `/app-ads.txt` response; proof is recorded above.
- [ ] Save the appropriate App Store support/privacy URL fields; they remain
  unmodified. Verify policy text and App Store privacy
  answers describe the live Google/UMP rewarded-ad build, not the superseded
  ad-free edition or merely the test-ad beta.
- [ ] Resolve AdMob readiness: the verified app status is **Requires review**
  and it is **not linked to its store listing**. The **European regulations
  consent message is not published**. Complete the appropriate account/message
  setup and verify applicable consent/privacy choices before live release.
  The public app-ads.txt response does not establish AdMob crawler verification
  or app approval; these remain pending.
- [ ] Review Google/UMP data flows, SDK privacy manifests, applicable tracking/
  ATT behavior and regional consent requirements; replace the stale App Privacy
  draft and no-ads Review Notes, and correct the advertising age-rating answer.
  No legal/privacy conclusion is made by this checklist.
- [ ] Configure and verify an SDK-enabled Production archive with the approved
  live app/rewarded IDs and real-ad-safe offer copy. Keep Debug/simulator and
  routine Release/TestFlight archives on demo ads. A Production binary does not
  automatically switch to test ads merely because it is distributed by TestFlight.
- [x] Unsigned generic-iOS **1.0 (8)** Production archive passed; bundle,
  binary/linkage and resources are SDK-free, with the app's own privacy manifest
  and corrected leaderboard IDs. This is validation, not a distributable signed
  archive: [production archive proof](PRODUCTION-ARCHIVE-PROOF.md). This remains
  historical SDK-free evidence, not verification of the forthcoming monetized build.
- [ ] Create and verify the forthcoming monetized candidate (recommended
  **1.0 (9)**), then its final **signed** archive using the approved SDK-enabled
  Production route. Inspect final bundle/version, signature, device families,
  Google/UMP linkage and privacy manifests, and the validated live ad identifiers.
  Signing/provisioning, upload, processing acknowledgement and build selection
  remain pending.
- [ ] Recheck the final store metadata, screenshots, age rating, availability
  and review information against the selected build before submission.
- [ ] Submit for App Review only after the remaining owner choices and release
  gates are resolved. No submission has been made at this checkpoint.

## Pending owner choices

- Confirm the countries/regions of availability; these remain unspecified.
  Free launch pricing and public support email/site approval are already confirmed.
- Resolve the informed EU trader-status clarification. The user described
  themselves as private/non-trader, but Apple's guidance indicates that
  individuals and advertising revenue can be relevant to trader status.
  Do not infer or save a legal declaration from that description alone.
  Confirm any region-dependent trader contact requirements separately from
  the already-approved public support email.

All existing archives, screenshot baselines, saves and parallel source work
remain preserved. Public site deployment does not constitute an app upload or
submission. This checklist does not itself accept agreements or make legal
declarations.
