# Version 1.0.1 build 12 — production update candidate

10 September 2026, Asia/Jerusalem.

- Latest gameplay was already saved and merged via PR #111 before this task.
- Build 11 increment merged via PR #112. Demo-ad build 11 uploaded successfully at 22:57, before the user clarified production monetization. It is not the monetized update candidate.
- Build 12 increment merged via PR #113. Source: d102adb on main, synced with origin/main.
- 252 engine tests passed with zero failures on the identical gameplay source. Existing app/device regression evidence is preserved under docs; no new manual phone playthrough is claimed.
- Production archive succeeded. Signed bundle verified: version 1.0.1 (12), com.numberclub.app, live ad mode, production AdMob app ID ca-app-pub-6970700553304979~2878649005 and rewarded unit ca-app-pub-6970700553304979/5201560013.
- App/dSYM UUID BECBFFFF-0316-3157-A228-7E64E5A7501E matches. Three privacy manifests present; no test bundle.
- App Store Connect upload succeeded at 23:02:30. Vendor GoogleMobileAds/UMP dSYM warnings were non-blocking; application symbols match.
- Build 9 remains Pending Developer Release. No public app release or App Store review submission was performed.

## Monetization

The preserved build 9 archive already contains the same production ad IDs. AdMob account is approved, but Probably Sudoku app is Requires review with no linked App Store listing. The European privacy message is published for Probably Sudoku; US messaging shows one active message. Public app-ads.txt is reachable with the correct publisher record. Paid ad serving has not been exercised or verified.

After build 9 is public, link its App Store listing in AdMob and complete app verification/readiness review. Test production rewarded ads only on registered AdMob test devices. TestFlight alone does not make Google ads test ads.

## Update flow

Once version 1.0 is released, create version 1.0.1 in App Store Connect, select the tested production build 12, enter What's New, choose manual release, and submit to App Review. TestFlight approval does not replace App Store approval. After Apple approval, release the update; existing customers receive it through App Store updates. If code/configuration changes, upload another unique build and select it instead.

## Final TestFlight confirmation

Apple processing completed and What to Test notes were saved. Build 12 was added to the existing Public Beta group and submitted for beta review. Apple immediately showed **Approved**, expiring in 90 days. Build UUID: `26f53b68-318a-42e3-a75e-bba4132d6479`. Existing beta link: https://testflight.apple.com/join/SHA5Tbzz. Production-ad testing guidance is included in the saved notes. No App Store version was released or submitted for review.
