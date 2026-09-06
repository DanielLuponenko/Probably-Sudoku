# Build 9 privacy and Game Center audit

Date: 2026-09-06. Status: **working disclosure worksheet, not a final declaration, publication approval, or legal conclusion**.

Scope: current monetized build-9 source, pinned SDK manifests (including a follow-up read of the actual build-9 archive), current primary Apple/Google documentation, and portal facts reported directly by the release owner. No live ad request, authenticated Game Center test, browser operation, build, or app-source change was performed for this audit. The SDK-free unsigned build-8 archive is historical evidence for a different product, not proof of build-9 privacy behavior.

## Decision and verified configuration

The source enforces non-personalized ads. After the follow-up RTB-policy review below, **Used for Tracking = No is a supportable configuration-specific assessment**, relying on Google's documented behavior and the actual restrictions, not an unconditional guarantee about every SDK/customer/buyer. This supersedes the initial recommendation to leave all tracking answers unresolved pending app-specific supplier correspondence. “Data Not Collected” remains inappropriate for the Google-enabled product. Final owner attestation/publication is not performed by this audit.

- `App/Ads/GoogleRewardedAdAdapter.swift:80`: UMP `canRequestAds` gates Google initialization and is checked again before loading. At lines 106–118, publisher first-party ID is disabled, PPT personalization is disabled, and every explicit rewarded request carries `npa=1`. These restrictions are applied before `MobileAds.start()`. No gameplay identifiers, Game Center aliases, custom targeting, or keywords are supplied.
- `App/Ads/GoogleRewardedAdAdapter.swift:43`: UMP updates and required/privacy-options forms use normal SDK APIs. No forced production geography or consent reset is configured.
- `project.yml:205`: routine Debug/Release builds use demo IDs; physical-device Production uses the verified app `ca-app-pub-6970700553304979~2878649005` and rewarded unit `ca-app-pub-6970700553304979/5201560013`. Simulator builds remain test-only. A **Production archive delivered through TestFlight still contains live IDs**; testers must be registered test devices.
- No ATT API, ATT import, or `NSUserTrackingUsageDescription` was found in app source/configuration. A general ad-content rating is a creative filter, not an assertion about user age or consent.
- `AppTests/RewardedAdServiceTests.swift:10` verifies the privacy setters and request extras without starting Google. These assertions are not observations of server-side processing.

Release-owner portal evidence, verified September 6:

- EU message published: Do Not Consent enabled; one partner, Google only; automatic partner addition off; RTB creative-consent check on; SF2 off.
- US message published for all current/future supported US states; custom US partner selection saved with one partner, Google only.
- Follow-up global blocking-controls inspection by the release owner showed 53,426 sources, zero blocked, and automatically allowing new Google-certified sources on. No global setting was changed. Consent-partner selection is therefore **not** globally Google-only demand.
- A further September 6 owner inspection found Campaigns unavailable until linking a Google Ads account; this account is not linked. The Mediation groups table contains only `AdMob (default)`, with zero impressions/earnings and no custom groups. Together with no mediation adapters in source, these observations support the current no-house/direct-sold-campaigns and no-custom-mediation assessment. They do not restrict worldwide demand to Google, prove runtime data handling, or remove the SDK collection disclosures.
- Apple Advertising = Yes saved. Availability saved as 173 regions, excluding China/Vietnam licensing-dependent markets; future markets off.

## Apple tracking: definition and current assessment

Apple's definition includes joining app/user/device information with other companies' data for advertising measurement, not only personalized targeting. Without ATT authorization, the app must not perform that tracking; UMP approval does not substitute for ATT. If SDK behavior is uncertain, Apple directs developers to consult the supplier. [Apple privacy and ATT guidance](https://developer.apple.com/app-store/user-privacy-and-data-use/)

Google NPA still permits identifiers for capping and aggregated reporting. This is neither automatically Apple tracking nor proof of no tracking. [Google NPA](https://support.google.com/admob/answer/7676680?hl=en)

PPT disables personalization and profile updates and restricts identifiers in non-personalized bid requests. The combined NPA/PPT and RTB-consent checks are meaningful safeguards, but Google does not fully guarantee non-Google buyer behavior. EU/US Google-only consent lists do not resolve every serving path outside those scopes. [Google PPT](https://support.google.com/admob/answer/14323214?hl=en)

Publisher first-party ID is explicitly disabled. The 50 SKAdNetwork entries support attribution without IDFA; their presence alone proves neither tracking nor the absence of other tracking. [Google privacy strategies](https://developers.google.com/admob/ios/privacy/strategies)

**Draft recommendation after follow-up:** Device ID collected = Yes, linked = Yes, used for tracking = **No**, on the documented actual-use basis below. The other six SDK categories also have a supported tracking answer of No. Do not select tracking Yes merely as a conservative placeholder: it asserts actual use, not uncertainty. This recommendation relies on the complete restrictions and supplier evidence, not NPA/no-ATT alone. Retain the generic SDK's different tracking flag as a capability baseline and document why the actual use differs.

## Potential SDK collection: disclosure worksheet

The pinned Google Mobile Ads 13.9.0 manifest declares the following. These are **generic vendor declarations**, not a measured build-9 data trace. “Advertising purposes” below means Third-Party Advertising, Developer's Advertising or Marketing, and Analytics.

| Apple category | Vendor linked flag | Vendor tracking flag | Vendor purposes |
| --- | --- | --- | --- |
| Coarse Location | Yes | No | Advertising purposes |
| Device ID | Yes | **Yes** | Advertising purposes |
| Advertising Data | Yes | No | Advertising purposes |
| Product Interaction | Yes | No | Advertising purposes |
| Performance Data | No, version-specific basis below | No | Advertising purposes |
| Other Diagnostic Data | No | No | Advertising purposes |
| Crash Data | No | No | Analytics |

UMP 3.1.0 declares Coarse Location, Performance Data, and Product Interaction as unlinked, not tracking, for App Functionality. These overlap the GMA categories; they are not extra duplicate categories in the final label.

Reconcile before completing the label:

- GMA's generic Device ID tracking flag does not prove actual tracking under these restrictions, but cannot be silently ignored. No IDFA/PPI does not establish no identifiers: Google describes other app/developer-bounded identifiers.
- Follow-up resolution: the disclosure page's prose explicitly describes SDK **7.68.0**, despite its recent footer date, and directs users of 11.2+ to the privacy manifest. The actual archived GMA 13.9.0 and UMP 3.1.0 manifests both mark Performance Data unlinked. **Not Linked is the best-supported version-specific answer for this deployment**, assuming no additional collection feature is enabled. Preserve the prose discrepancy as a supplier-documentation issue, not an automatic release blocker or a reason to invent linked collection.
- Apple defines Developer's Advertising or Marketing as first-party ads, direct marketing, or sharing to display the developer's ads. For this third-party rewarded-only deployment, without house campaigns, app-acquisition attribution, or marketing links, omit that purpose; use the deployment-specific worksheet below. Revisit if those features are added. This is an interpretation of the actual use, not a claim that the generic SDK manifest changed.
- App-owned `App/PrivacyInfo.xcprivacy` declares no tracking and UserDefaults reason CA92.1. It is not the combined application's SDK privacy report.
- Optional rewarded-ad participation does not exempt advertising collection from disclosure. [Apple disclosure rules](https://developer.apple.com/app-store/app-privacy-details/), [Google SDK disclosure guidance](https://developers.google.com/admob/ios/privacy/data-disclosure)

Manifest provenance: inspected cached artifacts under `/tmp/numberclub-production-archive-proof.69LTrA/DerivedData/SourcePackages/artifacts/`, specifically `swift-package-manager-google-mobile-ads/GoogleMobileAds/GoogleMobileAds.xcframework/ios-arm64/GoogleMobileAds.framework/PrivacyInfo.xcprivacy` and `swift-package-manager-google-user-messaging-platform/UserMessagingPlatform/UserMessagingPlatform.xcframework/ios-arm64/UserMessagingPlatform.framework/PrivacyInfo.xcprivacy`. The versions match current pins. Cache inspection is **not** inspection of a final build-9 archive or live network behavior.

Follow-up archive provenance: read both framework `PrivacyInfo.xcprivacy` files in `/tmp/numberclub-build9.whT3CJ/ProbablySudoku-Build9.xcarchive/Products/Applications/ProbablySudoku.app/Frameworks/`. Their declared categories/flags match the table; GMA's archived Info.plist reports 13.9.0. This establishes what the archive declares, not what a live server did.

### Deployment-specific answers supported now

The following collection/linkage/purpose answers, together with tracking No for all seven categories, are the supported deployment-specific recommendation. This is an evidence-based inference, not a live network trace. No portal answers were written by this audit.

| Category | Collected | Linked | Purposes supported by current use |
| --- | --- | --- | --- |
| Coarse Location | Yes | Yes | Third-Party Advertising, Analytics, App Functionality (UMP) |
| Device ID | Yes | Yes | Third-Party Advertising, Analytics |
| Product Interaction | Yes | Yes | Third-Party Advertising, Analytics, App Functionality (UMP) |
| Advertising Data | Yes | Yes | Third-Party Advertising, Analytics |
| Crash Data | Yes | No | Analytics |
| Performance Data | Yes | No | Third-Party Advertising, Analytics, App Functionality (UMP) |
| Other Diagnostic Data | Yes | No | Third-Party Advertising, Analytics |

No Product Personalization or Other Purposes is evidenced by this restricted rewarded-only implementation. Do not remove collection categories merely because particular users never request an ad. [Apple purpose definitions](https://developer.apple.com/app-store/app-privacy-details/#data-use), [Google version/manifest guidance](https://developers.google.com/admob/ios/privacy/data-disclosure)

### Tracking rationale and residual verification

New primary evidence is stronger than “NPA might do anything”: Google's AdMob-specific RTB documentation says NPA removes user identifiers and third-party-SDK-collected signals worldwide, although its article still permits user-agent/truncated-IP signals. Its linked Authorized Buyers guide describes further IP/first-party-ID redaction. Current buyer rules require honoring publisher data restrictions and restrict third-party-data association. Thus the enabled-source count alone is **not proof of tracking**. [AdMob NPA bidding](https://support.google.com/admob/answer/10833943?hl=en), [Authorized Buyers NPA fields](https://support.google.com/authorizedbuyers/answer/11121285?hl=en), [buyer rules, updated May 2026](https://www.google.com/intl/en/authorizedbuyers/guidelines/)

Together with unavailable ATT-authorized IDFA, disabled publisher first-party ID, global PPT before startup, NPA on every explicit load, and no mediation/marketing integration, these documents provide a reasonable basis for **No** under Apple's cross-company targeting/measurement definition. Retaining an app-scoped identifier for ad delivery, integrity, or aggregate reporting does not by itself establish that prohibited cross-company link. Google documents a rotating app-specific SDK instance ID and optional ATT integration. This is a reasoned assessment of the configured use, not a supplier guarantee that improper processing is impossible. [Google iOS strategy and instance ID](https://support.google.com/admob/answer/9997589?hl=en), [current ATT/PPI integration](https://developers.google.com/admob/ios/privacy/strategies), [Apple tracking definition](https://developer.apple.com/app-store/user-privacy-and-data-use/)

Lifecycle caveat: `GoogleRewardedAdAdapter.swift:86` sets global PPT/PPI restrictions, then starts Google. The per-request `npa=1` object is not passed until line 100. Google documents that **initialization may preload ads**, and PPT is not identical to NPA. Therefore the code proves NPA for explicit rewarded loads, not for every possible initialization request. This is **not observed tracking, proof of a preload in this no-mediation app, or a demonstrated bug requiring another build**. Global PPT/PPI restrictions are already set at the documented pre-initialization boundary, and UMP permission gates startup. Preserve this caveat in runtime QA; do not elevate a generic capability warning into a claim of actual prohibited data use. [Google startup warning](https://developers.google.com/admob/ios/quick-start#initialize_the_google_mobile_ads_sdk), [global request configuration](https://developers.google.com/admob/ios/targeting)

Practical release recommendation: retain build 9's restrictions and complete the deployment-specific disclosure draft, with owner approval and runtime consent/ad QA. App-specific supplier correspondence is an optional escalation if the owner needs stronger assurance or runtime evidence contradicts the documented behavior, **not an automatic prerequisite requiring an unbounded wait**. Do not add ATT, disable ads, falsify age, or force a consent-denial flag merely to make a checkbox easier. No ATT must not be interpreted as “the OS blocks all tracking endpoints”: the inspected GMA manifest supplies no tracking-domain list proving that claim. Public documentation does not certify this particular app; the unavoidable owner choice is whether to attest to the documented actual-use assessment, not whether to invent Yes or No without evidence.

## Remaining ad verification gates

1. Obtain owner approval of the configuration-specific mapping above. Keep NPA=1, PPT personalization disabled (`publisherPrivacyPersonalizationState = .disabled`), PPI disabled, no ATT, and no mediation/marketing integration; reassess before changing these conditions. Escalate to Google if runtime observations contradict documented restrictions or additional assurance is required.
2. Preserve the verified global demand/creative settings. Published EU/US messages alone do not prove globally Google-only demand or AdMob app/crawler approval.
3. Preserve the actual Production archive's metadata and aggregated privacy report. Framework manifests have now been checked read-only; reconcile their generic declarations with deployment-specific answers and public policy before publication.
4. On an approved test device with test ads, verify fresh required consent, Do Not Consent, privacy-options withdrawal/change, returning-user consent, and interruption. Observe initialization/request ordering and `canRequestAds` handling. Rejection need not always imply no eligible limited/non-personalized ad: follow UMP's actual availability result, not an invented blanket rule. No live inventory clicks are needed.

## Game Center: disclosure and practical verification

`App/Model/GameCenterService.swift:133` submits scores for `GKLocalPlayer.local`; line 174 onward reports completed achievements. The source does not read/export scoped ID strings or pass Game Center information to Google.

Gameplay Content/App Functionality is supported by Apple's game-save/gameplay guidance. Do not automatically classify all Apple-managed authentication data as developer-collected User ID: Apple distinguishes collection by the developer from collection only by Apple. Conversely, developer-accessible leaderboard data is not necessarily Apple-only; App Store Connect exposes player names and scores. Resolve the precise User ID treatment rather than asserting either direction solely from framework inclusion. [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details/), [scoped player identifiers](https://developer.apple.com/documentation/gamekit/protecting-the-player-s-privacy-using-scoped-identifiers), [score management](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-scores-and-players)

Required integration checks beyond no-account tests:

- Verify signed entitlements, the three canonical leaderboard IDs, achievement definitions, app-version association, and component review status.
- With a dedicated approved test account, verify real authentication, dashboard visibility, score submission/readback and achievement delivery. Apple prerelease Game Center testing uses the same server environment as released games; do not treat it as a separate disposable sandbox. [Apple testing guidance](https://developer.apple.com/help/app-store-connect/configure-game-center/overview-of-testing-game-center)
- Check offline/relaunch/re-authentication retry, maximum-score preservation, and local achievement preservation after failure. Foreground activation only updates the access point (`GameCenterService.swift:86`); queued retries wait for authentication or a later gameplay event.
- Decide and test account-switch policy: queues are app-global, not account-scoped, and pending progress is sent to whichever account is authenticated at delivery. No-account tests do not establish account isolation.

## Existing test evidence and stop condition

Release owner reports separate passing gates: iPhone 103 tests, iPad 88 tests, engine 211 tests. Do not sum these as unique tests. They support implementation/regression quality, not server-side privacy claims or authenticated Game Center delivery.

Stop this audit at the evidence above. No final privacy declaration or publication was authorized/performed. The supported mapping, residual verification caveats, and reasons for differing from generic SDK flags are explicit; legal interpretation and the final account declaration remain with the release owner.
