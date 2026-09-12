# Optional rewarded video: production and testing

## Missing-ad investigation — 2026-09-12

Read-only checks in AdMob found Probably Sudoku **Ready**, ad serving enabled,
no Policy Center issues, and verified app-ads.txt. The linked App Store ID and
the active Puzzle Rescue rewarded unit match the build 13 production archive.
The European privacy message for Probably Sudoku is published; the dashboard
also lists one active US-state message. No AdMob configuration changed.

The user's App Store installation displayed the generic unavailable message.
The initial dashboard selection, Last 7 days, excluded September 12. Its one
matched request and zero impressions therefore did not describe that day's
failures or identify the affected device. The later device investigation below
supersedes that limited initial evidence.
On an isolated simulator, the unchanged build 13 Debug app loaded Google's demo
rewarded video, completed it, and resumed the puzzle at Turn 11/13.

Two code issues were identified:

- A caller's cancellation queued MainActor cleanup. A replacement request could
  arrive first and be dropped. Cancellation now signals synchronously; a new
  request retires the cancelled one, and late SDK callbacks check that signal
  before loading a form, publishing an ad, or reporting an error.
- The offer discarded its supplied failure reason and displayed every failure
  as no ad available. It now distinguishes connection, timeout, privacy, and
  actual no-fill errors. SDK details stay out of player-facing text.

Local `RewardedAds` OSLog events record readiness, presentation, reward and
dismissal. Failures record the stage, original error domain and code; raw SDK
descriptions remain private. No telemetry service or gameplay targeting was added.
When diagnosing a device, filter Console for subsystem `com.numberclub.app` and
category `RewardedAds`. Genuine no-fill remains an AdMob availability outcome;
this fix cannot guarantee a paid ad for every request.

This repair requires a new App Store binary to reach existing players. It does
not modify the already distributed build. Routine verification uses demo units
and an isolated simulator, without paid impressions or clicks.

Validation: 68 focused tests passed in the SDK-enabled app, plus 45 in the
SDK-free fallback. These cover cancellation ordering, no-fill, offline/retry,
consent gating, duplicate/stale callbacks, saved rewards and the rendered offer.
The rebuilt Debug app also completed a Google demo video and resumed at Turn
11/13. Before/after save comparison confirmed the board, hand, score, target and
number pool were unchanged, with exactly three added turns and the rescue consumed.
Local evidence is in `~/Downloads/ProbablySudoku-AdFix-20260912/`, including
the final xcresult bundles, demo screenshots, save snapshots and lifecycle log.

### Follow-up on the actual App Store build 13

Device metadata confirmed that the mirrored iPhone 17 Pro was running the
App Store installation of version 1.0.1, build 13. Several individual load
attempts returned the generic failure message. Selecting **Today so far** in
AdMob then showed 13 requests from Israel, 1 matched request (7.69%), and
1 impression. Filtering for non-personalized ads retained all those requests.
These are aggregate, potentially delayed statistics, not an error trace for
an individual phone. They directly establish low ad availability for that
reported traffic, not a reason for every unmatched request.

A fresh isolated simulator ran the unchanged build 13 Debug binary with the
production app ID and declared production identifier pair in its copied
Info.plist. The existing simulator guard still selected Google's demo ad unit.
The production UMP configuration completed, reported GDPR not applicable in
the natural test geography, and the rewarded ad reached ready. This tested the
production consent backend that an ordinary sample-ID Debug build does not.

The original App Store installation subsequently loaded a production ad without
any app, privacy, or AdMob configuration change. At the user's request to verify
more than the ready button, one ad was opened and completed. Its own UI displayed
**Reward granted**. Closing it returned to Puzzle 3 at **Turn 11/13**, with the
score and target still **200/2,000**. No advertiser link was selected. This proves
one successful live load/presentation/reward/dismissal cycle on build 13, not
reliable fill for every request or a byte-for-byte comparison of the phone save.

The user authorized a temporary local HTTP capture. Two bounded Instruments
captures, including one synchronized with the retry, exported no HTTP entries.
They provide no server response body or SDK error code. The generic Security
and WebKit messages likewise do not identify the ad failure. Do not label this
incident a proven consent error or claim those warnings were repaired.

The narrow recovery change makes one additional load attempt after a 10-second
delay, only when the ad SDK reports no-fill. Both attempts share the original
45-second load deadline. Leaving the offer, cancellation, loss of foreground,
or a consent change prevents the delayed request. Consent forms are not repeated
and an available ad still requires the player to choose Watch. Two no-fill
responses stop and leave manual retry available. This handles a temporary miss;
it cannot manufacture inventory or guarantee a higher fill rate.

Retry validation: 73 focused SDK-enabled tests and 50 SDK-free tests passed.
The new cases cover no-fill followed by success, stopping after the second
no-fill, cancellation during backoff, changed consent/foreground state, the
shared deadline, late completion, and no automatic retry for unrelated errors.
Independent diff review found no actionable issues. The change still requires
a new distributed binary; the successful phone playback above used original
build 13 and must not be attributed to this unreleased retry change.

## Configuration

The user authorized production ad integration on 2026-09-06 after AdMob account
approval. Account approval is not the app's separate readiness approval.

| Build configuration | App ID | Rewarded unit | Use |
| --- | --- | --- | --- |
| Debug / Release | Google demo | Google demo | Development, direct QA installs, TestFlight |
| Production, physical iOS | Probably Sudoku | Puzzle Rescue | Explicit monetized App Store archive |
| Any simulator | Google demo | Google demo | Never paid traffic |

Verified against the signed-in AdMob app settings and ad-unit list:

- App: `ca-app-pub-6970700553304979~2878649005`
- Rewarded unit: `ca-app-pub-6970700553304979/5201560013`

The regular `ProbablySudoku` scheme still archives **Release** with demo ads.
`ProbablySudoku-Production` archives **Production** with the real identifiers.
Its Run/Test/Profile actions remain on safe configurations. Do not distribute a
Production archive for routine ad testing: TestFlight does not itself turn paid
ads into test ads. Use the regular scheme for testers; only registered AdMob
test devices should exercise production units during integration testing.

Configuration is generated from `project.yml` into the three Info.plist keys
`GADApplicationIdentifier`, `NumberClubAdMode`, and `NumberClubRewardedAdUnitID`.
The adapter validates the mode and exact matching identifier pair before consent
or SDK initialization. An absent, unknown, or mixed configuration fails closed;
it never silently requests another account's unit. Debug and simulator code
also forces the demo rewarded unit as a second safety boundary.

## External release gates — 2026-09-06

- Account: approved, as reported by the user and shown in their screenshot.
- Probably Sudoku app: **Requires review**, verified in the live AdMob dashboard.
- App store details: no linked store listing, verified in App settings.
- Production ad-unit ID exists and is of type **Rewarded**.
- European regulations → Messages shows the initial create-message screen,
  with no published message. Automatic fallback coverage is enabled in account
  settings, but it is not proof of a configured, app-specific production consent
  flow. Publish the intended message and verify it with test traffic before launch.
- Full paid serving is not verified. The code configuration does not bypass
  AdMob's app review, consent requirements, or store publication.
- Before monetized release: finish the public App Store listing, link it in
  AdMob, complete any requested app-ads.txt verification/readiness review, and
  verify production consent messages and app-specific privacy disclosures.

No paid ad was requested, viewed, or clicked during this configuration change.
No phone installation or App Store/TestFlight upload is part of this change.

## Configuration validation — 2026-09-06

- SDK-free host tests: 21 passed (5 configuration + 16 service/mock lifecycle).
  The harness links no Google SDK; its Google adapter stub cannot load ads.
- Unsigned generic-iOS **Production** build passed; the built Info.plist contains
  the verified live app/rewarded IDs and `NumberClubAdMode = live`.
- Production simulator build settings resolve to the complete demo pair and
  `test` mode; ordinary Release remains `test` with demo IDs.
- Build log: `/tmp/numberclub-production-ads-build.log`.
- This is compile/configuration proof, not a claim that AdMob approved the app
  or served a production ad. Gameplay testing remains stopped at the user's request.

## Ownership and failure behavior

`RewardedAdService.shared` is main-actor observable state. The eligible, live
results page calls `prepare()`; splash, frozen page snapshots, and ordinary
gameplay do not initialize the ads SDK or request ads. Cancel its task when the
offer leaves. `present(onReward:onDismiss:)` returns false when not accepted.
An accepted presentation calls dismissal once, whether skipped, completed, or
failed. Only the SDK earned-reward callback calls `onReward`, synchronously on
the main actor; dismissal alone never earns anything. The game remains owner
of its once-per-puzzle reward entitlement and save transaction.

Each network preparation stage (consent update, form download, ad load) times
out after 45 seconds; SDK completions from cancelled
or timed-out loads cannot replace a newer ad. Cached ads expire after 55 minutes
(Google's upper limit is one hour), are checked again at presentation, and are
single-use. No-fill, errors, or lack of a foreground presenter leave the player
free to continue without watching. SDK-presented video and privacy forms must
finish their own dismissal; the app does not force-dismiss third-party UI.

## Consent and privacy

Every preparation updates UMP consent information before any SDK initialization
or ad load. Required consent forms finish before ads are requested. A failed
update may use a prior-session choice only when UMP itself reports
`canRequestAds == true`; the app never reconstructs consent from saved strings.
There is no consent bypass, forced geography, consent reset, ATT/IDFA prompt,
Firebase, analytics integration, or mediation adapter.

Expose an interactive Settings privacy-options action only when
`privacyOptionsRequired` is true, and call `presentPrivacyOptions()` on user tap.
It invalidates the cached ad, so a changed choice cannot reuse an older ad.
Settings can call `refreshPrivacyStatus()` after relaunch: it updates UMP and
the visible entry-point requirement without showing forms or loading ads.
`lastError` retains a diagnostic error for development, while `state` carries
a short recoverable message for the offer UI.

UMP obtains its message configuration from the app ID in Info.plist. Google's
demo app configuration is not controlled by this account. Network QA must prove
that UMP permits the request and the demo video actually loads. A server/config
failure is a blocker to that proof, not permission to skip consent. When using
the Production configuration, configure and publish the appropriate messages under
AdMob Privacy & messaging first, and re-test relevant regions with explicitly
registered test devices. TestFlight is not automatically a Google test device.

Adding the SDK changes the privacy-disclosure review even while using demo ads:
review Google's current SDK data-collection disclosure, the merged SDK privacy
manifests, the app privacy policy and App Store Connect privacy answers before
another upload. No ATT prompt does not mean the SDK collects no data. The current
SKAdNetwork list includes Google's identifier only; before production review the
current recommended buyer list. Production serving also needs account approval,
a linked downloadable App Store listing, verified app-ads.txt on the developer
domain (App Store Marketing URL), and AdMob app readiness approval.

## Primary references

- [iOS setup and sample app ID](https://developers.google.com/admob/ios/quick-start)
- [Rewarded lifecycle, demo unit and one-hour expiry](https://developers.google.com/admob/ios/rewarded)
- [UMP consent, error handling and privacy options](https://developers.google.com/admob/ios/privacy)
- [UMP form API and nil presenter](https://developers.google.com/admob/ios/privacy/api/reference/Classes/UMPConsentForm)
- [Google SDK data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure)
- [Safe test ads/devices](https://developers.google.com/admob/ios/test-ads)
- [App readiness](https://support.google.com/admob/answer/10564477?hl=en)
- [App-ads.txt and iOS Marketing URL](https://support.google.com/admob/answer/9363762?hl=en)

Dependencies are pinned in project.yml: Google Mobile Ads 13.9.0 and UMP 3.1.0.
Run XcodeGen and app tests from the owning task, then verify a real demo load,
skip, earn-and-dismiss, offline failure, and privacy options in the running app.

## Build 5 validation — 2026-09-05

- Engine suite: 163 tests passed; app suite: 89 tests passed.
- A real Google demo video loaded and earned its reward in the isolated iOS
  simulator. The user also confirmed the test ad works.
- The resumed game and persisted save both showed Turn 11/13, a consumed rescue,
  and no terminal outcome. The board, hand, and score are covered by save-resume
  tests; skip, duplicate/stale callbacks, timeouts, and consent gating are covered
  by adapter/session tests, not claimed as physical-device manual checks.
- Build 5 retains demo IDs in Release and simulator-only QA/obstacle previews.
  Direct-device installation does not update the build awaiting TestFlight review.
