# Version 1.0.2 — build 14

Prepared 12 September 2026. Upload and submission are pending at this checkpoint.
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
  bundles. Upload is pending. Debug/Release and simulator execution use demo ads.
- Version 1.0.2 was created in App Store Connect. Description, keywords, promotional
  text, What's New and review notes were saved. Manual release was selected and
  verified. English (U.S.) subtitle was saved on App Information.
- Existing review contact, Game Center, ratings, privacy, URLs and pricing are preserved.

Local evidence: `/Users/daniel/Downloads/ProbablySudoku-Build14-20260912/`.
