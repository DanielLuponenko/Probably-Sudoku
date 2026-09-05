# Optional rewarded video: testing integration

All configurations, including Release and TestFlight, use Google's demo app ID
`ca-app-pub-3940256099942544~1458002511` and iOS rewarded unit
`ca-app-pub-3940256099942544/1712485313`. There is no automatic production switch.
Do not publish a production monetized build until an explicit switch is approved.

Reserved production identifiers (documentation only; not used by the app):

- App: `ca-app-pub-6970700553304979~2878649005`
- Rewarded unit: `ca-app-pub-6970700553304979/5201560013`

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
the real app ID later, configure and publish the appropriate messages under
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
