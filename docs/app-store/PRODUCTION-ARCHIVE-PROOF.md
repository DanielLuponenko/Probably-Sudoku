# Production archive verification — 1.0 (8)

Verified 2026-09-06. This is an **unsigned validation archive**, not an uploaded
or installable distribution build. Existing signed build 7 archives are intact.

**Historical ad-free evidence:** Later on 2026-09-06 the owner confirmed a free
launch retaining the optional rewarded video. This SDK-free build 8 remains
preserved, but is no longer the requested launch configuration. A forthcoming
ad-enabled candidate (build 9 recommended for clear separation) needs its own
tests, signed archive inspection and privacy review. Nothing below proves that
future candidate or means that build 8 or 9 has been uploaded.

## Artifact

- Scheme: `ProbablySudoku-AppStore`; configuration: `Production`.
- Destination: generic iOS / arm64, separate DerivedData.
- Signing explicitly disabled for this validation only.
- Archive: `/tmp/numberclub-production-archive-proof.69LTrA/ProbablySudokuAppStore.xcarchive`
- Log: `/tmp/numberclub-production-archive-proof.69LTrA/archive.log`
- Result: **ARCHIVE SUCCEEDED**.

## Bundle inspection

- Bundle identifier `com.numberclub.app`; display name `Probably Sudoku`.
- Version **1.0**, build **8**; `NumberClubAdMode = disabled`.
- No `GADApplicationIdentifier`, `NumberClubRewardedAdUnitID` or `SKAdNetworkItems`.
- No beta Info.plist embedded as a resource.
- No Google Mobile Ads / UMP frameworks, resources or privacy manifests.
- Linked libraries are Apple/system libraries. SDK symbol and runtime class/module
  scans found no Google or UMP SDK presence.
- Only the app's own `PrivacyInfo.xcprivacy` is bundled, byte-identical to source:
  SHA-256 `47d7e21162b82f635ba323019e1ae2181763df98696df9afc90a2161c9f656f1`.
  Tracking is false; UserDefaults required-reason declaration is `CA92.1`.
- All three corrected underscore-based Game Center leaderboard IDs are in the binary.

## Focused test evidence

These are separate overlapping runs, not 85 unique tests:

- **52 tests, 0 failures**: support links, distribution/ad configuration, disabled
  ad lifecycle, failure-page rendering and final compact iPad briefing layout.
  `/tmp/numberclub-appstore-ads-proof.IRjCj4/CompactTicketAndReleaseTests.xcresult`
- **33 tests, 0 failures**: Game Center ID migration (8), Book completion progress
  (15), distribution metadata (2) and ad configuration (8).
  `/tmp/numberclub-appstore-ads-proof.IRjCj4/GameCenterIDMigrationTests.xcresult`

## Required before distribution

1. Publish and independently verify the approved support/privacy destinations.
   The app links currently point to the correct registered site, but it is private.
2. Finish Game Center server configuration and authenticated delivery checks.
3. Create a signed distribution archive from the final source; inspect its
   signature, provisioned entitlements, device families and SDK-free contents.
4. Upload, wait for Apple processing, select that exact build, and complete
   the owner-dependent release declarations in `RELEASE-CHECKLIST.md`.

No upload, App Review submission, public release, main merge or device installation
was performed by this validation step.
