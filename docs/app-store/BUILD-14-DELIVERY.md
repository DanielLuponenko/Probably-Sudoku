# Version 1.0.2 — build 14

Updated 12 September 2026. **Version 1.0.2 (14) uploaded and submitted to Apple.**
The owner authorized TestFlight and App Review with **manual release after approval**.
Public version 1.0.1 (13) remains available while the update is reviewed.

## Changes

- Repair cancellation handling so a cancelled preparation does not consume a later
  manual ad request. Add actionable failure messages and underlying SDK diagnostics.
- Keep retry and playback manual. No automatic retry, reward change, consent change,
  saved-game migration, or gameplay change is included.
- The earlier intermittent live-ad failure was not conclusively attributed to one
  cause. Build 13 subsequently completed a real rewarded ad and granted three turns.
  This update does not promise ad inventory or claim that every unavailable-ad case
  has been fixed. See [ad implementation and investigation](../REWARDED_ADS.md).
- Bump marketing version to 1.0.2 and build number to 14.

## Store presentation

The ASO Scout email was a third-party sales recommendation, not an Apple rejection.
Apple describes search relevance and user behavior (including downloads, ratings,
and reviews) as ranking factors; metadata changes do not guarantee a search rank.

- Name remains **Probably Sudoku**.
- Subtitle: **Roguelike Logic & Combos**.
- Keywords: `number,brain,offline,turn based,tactics,high score,multiplier,cozy,boss,challenge,math,grid`.
- Revised description explains the Sudoku scoring loop, Books, item combinations,
  interactive practice and optional rewarded videos. Promotional text highlights
  those features. It is conversion copy, not an indexed keyword field.
- These relevant keywords are hypotheses to evaluate after release, not claims of
  measured popularity. No competitor names, unsupported features or paid ASO tools.
- Exact release, review and beta copy: [English metadata](metadata/1.0.2-en-US.json).

All copy fits Apple's limits: name 15/30, subtitle 24/30, keywords 91/100,
promotional text 147/170, description 1465/4000 and release notes 192/4000.

The draft inherits six current native iPhone and six native iPad screenshots in
this order: gameplay, selected Book benefit sign, shop, rack, interactive tutorial,
and multipliers/items. Both galleries were verified in App Store Connect.
The selected Book picture uses the physical green benefit sign. The ad changes
have not changed the depicted gameplay. [Capture evidence](screenshots/version-13/CAPTURE-MANIFEST.md).

Sources: [Apple search](https://developer.apple.com/app-store/search/),
[Apple product page](https://developer.apple.com/app-store/product-page/).

## Validation and delivery

- 71 focused tests passed, zero failures: ad configuration, distribution metadata,
  failure classification, ad service, rescue session/persistence and failure-page
  rendering. Includes single-attempt behavior and cancellation regression coverage.
- Production archive succeeded. Verified version 1.0.2 (14), bundle ID, live AdMob
  IDs, valid code signature, three privacy manifests, both Google frameworks,
  matching application/dSYM UUID `61443F98-CC5E-3954-8556-A42EA1067C0F`, and no test
  bundles. Debug/Release and simulator execution use demo ads.
- Version 1.0.2 was created in App Store Connect. Description, keywords, promotional
  text, What's New and review notes were saved. Manual release was selected and
  verified. English (U.S.) subtitle was saved on App Information.
- Existing review contact, Game Center, ratings, privacy, URLs and pricing are preserved.

Local evidence: `/Users/daniel/Downloads/ProbablySudoku-Build14-20260912/`.

## Upload receipt

- Release source commit `5463b2f` merged through PR #121 to `70a0754` on main.
  Archive source hashes match the merged app, engine and project configuration.
- Apple upload succeeded at **18:22:51 Asia/Jerusalem, 12 September 2026**.
  Xcode reported `Uploaded package is processing` and `EXPORT SUCCEEDED`.
- GoogleMobileAds and UserMessagingPlatform vendor dSYM warnings were non-blocking.
  The app's own dSYM matches the executable. No upload validation errors.
- Corrected the shared TestFlight description and reviewer notes, which still
  described build 7 and demo ads. Saved copy now describes production live IDs,
  optional earned rewards, manual retry and registered-test-device playback QA.

- Apple processing completed. Uploaded build ID:
  `da98bfb6-7ce9-491d-a1a7-4f32c9225849`.
- Build 14 was assigned to the existing Public Beta group and submitted to Beta
  App Review with the saved build-specific testing instructions. Final TestFlight
  state at 18:28 is **Waiting for Review**, group **Public Beta**; the build is not
  yet available to external testers. Existing invitation: https://testflight.apple.com/join/SHA5Tbzz.
- Build 14 was selected and saved for App Store version 1.0.2. Manual release
  remains selected.

## App Review receipt

Apple acknowledged **1 Item Submitted** at **18:27 Asia/Jerusalem on 12 September
2026** for version **1.0.2 (14)**. The receipt confirms **Waiting for Review**.
Submission ID:
`79ebca34-bc0a-4b1c-adaf-7e2cfe11428b`.
[App Review receipt](https://appstoreconnect.apple.com/apps/6808968186/distribution/reviewsubmissions/details/79ebca34-bc0a-4b1c-adaf-7e2cfe11428b).

The submission includes the revised English (U.S.) subtitle. Manual release is
selected, so approval will leave the update awaiting the owner's release action.
No public release of version 1.0.2 was performed.
