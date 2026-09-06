# Build 10 — TestFlight-only delivery

6 September 2026. User explicitly authorized uploading the latest build 10 to
TestFlight, preserving build 9's App Store submission. **Upload succeeded at
14:41 local time.** Processing completed, testing notes were saved, and build
1.0.1 (10) was submitted to **TestFlight beta review only** for Public Beta.
Apple now shows **Waiting for Review**. It is not yet installable through the
public link; approved build 7 remains available until beta approval of build 10.

## Package

- Version/build: **1.0.1 (10)**, bundle `com.numberclub.app`, iPhone and iPad.
- Fresh archive includes the rack momentum improvement, plus the previously
  verified save/rescue, same-Shop achievement and Game Center history fixes.
- Production compiler configuration with explicit command-line **Google demo
  ad IDs** for this beta. No project production ad setting was changed.
- App ID: `ca-app-pub-3940256099942544~1458002511`.
- Rewarded unit: `ca-app-pub-3940256099942544/1712485313`.
- This beta is not the live-ad App Store update candidate. Any later live-ad
  binary must use a new build number; do not reuse uploaded build 10.
- Archive: `/Users/daniel/Downloads/ProbablySudoku-TestFlight10.09L6mT/ProbablySudoku-1.0.1-Build10-TestFlight.xcarchive`.
- App/dSYM UUID: `35A32D65-6E9A-310E-8267-40DBE6FDD23C` (arm64).
- Evidence: `/tmp/numberclub-testflight10.4dh8rc/` (`archive.log`, `upload.log`,
  `ExportOptions-Upload.plist`, `What-to-Test.txt`).
- Separately exported local IPA: `/Users/daniel/Downloads/ProbablySudoku-TestFlight10.09L6mT/LocalExport/ProbablySudoku.ipa`.
- Local-export SHA-256: `5816cead7bcec5e021953e544c0604c6f3aa3ee814529f82e0f0b5b2d25d90e1`.

## Verification

- Fresh archive succeeded and compiled `BookstoreRackSpin.swift`.
- Archive signature verification passed; app/dSYM UUIDs match.
- Packaged plist confirms 1.0.1 (10), demo ad mode/IDs, iPhone+iPad families and
  no non-exempt encryption. App, Google Mobile Ads and UMP privacy manifests exist.
- Reused matching rack proof: 52 focused tests passed in
  `/tmp/numberclub-rack-verified.xcresult`. Earlier save/Game Center gates are
  documented in `BUILD-10-RELEASE-STATUS.md`; no fresh full playthrough is claimed.
- `git diff --check` passed before archiving. Existing work/archives preserved.
- Apple's upload completed successfully. Non-blocking warnings identify missing
  vendor dSYMs for GoogleMobileAds and UserMessagingPlatform; the application's
  own matching dSYM is present. These warnings are not a failed upload.
- Local export has Cloud Managed Apple Distribution signing, `get-task-allow`
  false, `beta-reports-active` true, and Game Center/iCloud key-value entitlements.

## Distribution boundary

Build 9 remains in submission `2c697991-b5a9-42d9-b31c-7dffe6baff75`, observed
**Waiting for Review** with all 23 items before this upload. No App Store version,
release selection, review metadata or submission was modified.

Public Beta group: `deaab7dd-fb59-4ff1-95c8-07be68bbccdd`.
Existing join link: https://testflight.apple.com/join/SHA5Tbzz
Before this upload the group contained approved builds 7 and 4 only.

## Verified beta handoff

- Build UUID: `380a1c1e-419b-49db-90a1-810bee552383`.
- Group now contains build 10 (**Waiting for Review**) and unchanged approved
  builds 7 and 4. No build was expired or removed.
- Public link remains enabled, with 0/50 testers.
- Build-specific What to Test notes explicitly cover test/demo ads, rack
  momentum, saved-run/rescue resume, Game Center history and same-Shop sales.
- **Automatically notify testers** was checked when submitting beta review.
- No App Store submission/release action, commit, push or phone install occurred.
