# Build 9 consent runtime checks

6 September 2026. These checks exercise the published app-specific UMP
configuration, not live advertising and not the complete production app.

## Test boundary

- Isolated simulator: Probably Sudoku App Store Screenshots,
  `A063BEFC-8547-46BF-8642-5F490F8FD711`.
- Temporary probe: `/tmp/numberclub-cmp-probe.ZwAkIh`.
- Same bundle identifier and published AdMob application identifier as the
  game; UMP 3.1.0. The temporary display name clearly says TEST ONLY.
- No Google Mobile Ads framework, ad loader or ad request code is linked.
  Two probe safety tests passed in `SafetyTests.xcresult`.
- Forced EEA/regulated-US geography and consent reset exist only in this
  temporary simulator probe, never in the uploaded build 9.
- Game saves are not read, erased or modified by the probe. The protected
  full-book playthrough simulator was not touched.

## Observed European flow

1. Fresh reset/update: consent required, form available, privacy options
   required, `canRequestAds=false`.
2. Published form displayed Consent, Do not consent and Manage options;
   it listed one partner. Its app name reflected the probe's test display name.
3. Do not consent dismissed normally. UMP reported obtained, privacy options
   required and `canRequestAds=true`. This is an eligibility result, not an
   assertion that the user consented to all purposes; eligible limited or
   non-personalized ads are distinct from personalized consent.
4. Refresh preserved the choice. Privacy options reopened successfully.
5. Consent was accepted from the reopened form. A read-only snapshot of the
   test simulator's consent flags showed Google vendor 755 consent true,
   one consenting vendor and purpose consent bits `10110000000`.
6. Privacy options reopened again; Do not consent withdrew that acceptance.
   Persisted purpose consents became `00000000000`, Google consent false,
   and the consenting-vendor count became zero.

Legitimate-interest flags remained set after Do not consent. Do not describe
that button as an objection to all legitimate-interest processing. No raw
TC string or player identifier was needed for these checks.

## Observed US flow

1. Fresh regulated-US reset/update: consent not required, form available,
   privacy options required, `canRequestAds=true`.
2. Privacy options displayed Allow the sale or sharing of my data and
   Don't sell or share my data.
3. Don't sell or share my data was selected and Save and close dismissed
   the form normally.
4. After refreshing and reopening, the opt-out remained selected. The
   recorded GPP section ID was 7 (US National). Separate opt-out keys were
   not present, so no unobserved decoded GPP values are asserted.

Runtime log: `/tmp/numberclub-cmp-probe.ZwAkIh/runtime-idle.log`.
These observations supplement the existing ad-service unit tests. They do
not prove a production physical-device consent run, ad availability,
authenticated Game Center delivery, or Apple/AdMob approval.
