# Store metadata — English (U.S.)

**Current portal changes: [Build 14 delivery](BUILD-14-DELIVERY.md).**
This file preserves the earlier metadata snapshot and historical ad-free copy.
Support/marketing/privacy URLs, rewarded-ad review notes, Advertising Yes and
launch availability have since been saved as documented in the current report.
Do not reuse the historical no-ad review notes below for build 9.


Draft version 1.0, prepared 6 September 2026. This is not a public-release notice.
App Store Connect app ID: `6808968186`.

## Current launch decision — 6 September 2026

The user confirmed a **free launch with the existing optional rewarded ad**:
one completed ad grants **three extra turns, once per puzzle**. The player can
end the Book without watching. This replaces the earlier ad-free launch plan.
Studio branding is **DlA**; the individual legal seller remains **Daniel Luponenko**.

The public support email and publication of the prepared support/privacy site
are approved. The release owner confirmed **public deployment**; unauthenticated
support/privacy HTTP checks passed. App Store Connect support/privacy URL fields
are still unmodified.

Build **7** remains the latest uploaded build. Unsigned SDK-free build **8** is
preserved historical validation. Recommend **9** for the forthcoming monetized
candidate; it has **not yet been built or uploaded**. The saved no-ads Review
Notes, ad-free privacy draft and **Advertising: No** rating answer below are
**stale and must not be reused unchanged for submission**.

## Saved product-page fields

- Name: **Probably Sudoku**
- Subtitle: **A roguelike, by the numbers**
- Primary category: **Games**; subcategories: **Puzzle**, **Strategy**.
- Copyright: **2026 Daniel Luponenko**.
- Keywords: `logic,puzzle,roguelike,strategy,numbers,brain,books,cozy,offline,combos,turn-based`
- Promotional text and optional marketing URL: not set.
- Required support URL: approval, public deployment and unauthenticated URL
  verification complete; the App Store field save remains pending.

### Description

Probably Sudoku turns a familiar grid into a book-length strategy adventure.

Choose from 12 Books, each with its own ability and questionable encouragement. Place numbers using Sudoku rules, build scoring combinations, and reach each puzzle's target before your turns run out. You don't have to fill every square to win.

A BOOK WORTH FINISHING

Each run spans nine levels and 27 puzzles. Plan around clearly announced Boss powers, then face one of five major final Bosses on the last page. Finish a Book to unlock its next Obstacle difficulty. Every Book keeps its own progress.

MAKE THE NUMBERS WORK FOR YOU

Spend earned coins on Bookmarks that strengthen your build, Markers that reward selected squares, and one-use Buffs for a timely advantage. Make the most of the numbers in your hand, decide when to toss them, and discover combinations that turn a modest move into a much bigger score.

PAPER, PERSONALITY AND ONE MORE TRY

Browse a rotating book rack, turn flexible paper pages, and enjoy gentle music, sound effects and tactile feedback. Adjust the audio to suit you. A short, skippable tutorial includes guided practice, and saved progress lets you put the Book down and return later.

Play without a required login. Your next good idea is probably one number away.

## Screenshots

Apple accepted five native iPhone and three corrected native iPad images.
Gallery order was confirmed after accessible keyboard reordering:

- iPhone: gameplay, book rack, shop, Next Puzzle, selected book.
- iPad: gameplay, selected book, Next Puzzle.

See the original [capture manifest](screenshots/CAPTURE-MANIFEST.md) and
[corrected iPad manifest](screenshots/version-8/CAPTURE-MANIFEST.md).

## Historical saved review notes — stale for the monetized candidate

The following text records what was saved for the previous ad-free plan, not
the review instructions to submit now. Replace the no-ads paragraph with the
actual optional three-turn/once-per-puzzle reward, its earned-ad condition and
the ability to decline. Recheck consent/privacy instructions against the final
SDK-enabled build before saving replacement notes. No replacement save is
claimed here.

Probably Sudoku is a single-player Sudoku strategy game. No app account, subscription or purchase is required. Game Center sign-in is optional; dismissing it does not prevent play.

To play: complete or skip the first-time tutorial, choose New Book, tap a book cover on the rack, select an available Obstacle tab, then Open the Book. Place numbers from your hand in valid Sudoku cells and tap End Turn to bank points. Reach the score target within the turn limit; filling the entire grid is not required.

Bookmarks, Markers, Buffs and all shop purchases use coins earned only through gameplay. A run has 27 puzzles across nine levels. Completing the final Boss leads to Book Complete and unlocks the next Obstacle only for that Book.

The App Store release is ad-free: the Google advertising and consent SDKs are excluded from this target. There are no live or demonstration ads, ad rewards, in-app purchases or paid currency.

Settings is accessible from the gear button on the menu and during play. It includes tutorial/help, audio controls, progress-related options, and Privacy policy and Support links under Privacy & support. There is no required reviewer login.

The user-provided review contact is saved in App Store Connect and was checked
visually after Save succeeded. Review-only email and phone are deliberately not
copied into this public-repository document. No reviewer account is required.

## Historical ad-free privacy draft (saved, not published; now stale)

This draft is not a complete disclosure for the newly approved Google/UMP
build. Preserve it as history; review the SDK data flows, privacy manifests,
tracking/ATT behavior and regional consent requirements before replacing or
publishing App Privacy answers or policy text. No legal declaration is made here.

| Data type | Purpose | Linked to identity | Tracking |
| --- | --- | --- | --- |
| Gameplay Content | App Functionality | Yes | No |
| User ID | App Functionality | Yes | No |

These conservative disclosures cover Game Center scores/achievements and the
player display names available through Apple's developer tools. The app also
uses Apple's private iCloud key-value storage for saved-game synchronization.
The historical SDK-free build 8 has no independent advertising, analytics or
crash-reporting SDK. TestFlight build 7 includes Google test-video SDKs. The old
policy draft distinguishes that beta from an ad-free release; that distinction
does **not** describe the newly chosen live rewarded-ad launch.

The prepared policy destination is:
`https://probably-sudoku-support.dannyluponenko.chatgpt.site/privacy`.
Support uses the same site's root. The in-app links use these destinations.
The support email and site publication are approved, and public deployment
has succeeded. Version **2**, source SHA `cdee1b6d0aceaa9d3e09ce6b156d082f1d930b09`,
deployment `appgdep_6a9d068f36d08191acfe5e57906f8c04`; the same deployment includes
`/app-ads.txt`. The release owner verified unauthenticated support and privacy
responses are **HTTP 200 with no redirects**. `/app-ads.txt` returns **HTTP 200**
and exactly matches the AdMob console snippet. App Store support/privacy URL
fields are still unmodified; no URL-field save is claimed here.

Verified AdMob account readiness is incomplete: the app **Requires review**, is
**not linked to its store listing**, and its **European regulations consent
message is not published**. These account/message gates and the applicable
privacy review must be resolved for the live-ad candidate. AdMob crawler/app
verification remains pending despite the successful public app-ads.txt response.

## Account-dependent items

- User's artwork/icon/3D commercial-use rights confirmation was saved as Content Rights.
- Apple's questionnaire calculated **13+** for the standard current rating,
  including frequent Game Center contests. This saved result used
  **Advertising: No**, now stale; correct that answer and recheck the resulting
  rating for the monetized build. Regional ratings/restrictions vary.
- Free Apps Agreement: **Active**. Paid Apps Agreement: **New**, not signed.
- Free launch pricing is confirmed; distribution countries remain unspecified.
- EU trader status still needs informed clarification. The user described
  themselves as private/non-trader, but Apple's guidance indicates individuals
  and advertising revenue can be relevant. No trader declaration is inferred
  or saved here; region-dependent contact requirements remain to be resolved.
- App Store version remains **Prepare for Submission**, with no final build selected.
- Build 7 is approved for TestFlight and remains the latest upload. Build 8 is
  preserved unsigned SDK-free evidence, not the current launch candidate.
  Recommended monetized build 9 is not yet built or uploaded.

## Shared TestFlight information

The global Beta App Description and Beta Review Notes were corrected and
confirmed **Saved** after the store metadata pass. They now identify build 7's
optional Google test videos and three-turn reward, instead of the obsolete
"no advertisements" claim. Build-specific What to Test notes also remain saved.
No beta privacy URL was entered during the earlier private-site stage. Recheck
and save the appropriate URL now that public deployment and HTTP access are
verified; that App Store Connect update remains pending.

## Historical native support-link verification — SDK-free build 8

Both menu Settings and in-game Settings were inspected in the SDK-free build 8
on the isolated QA iPhone simulator. Privacy policy and Support links are visible,
unclipped and enabled; Google/test-ad/privacy-choice controls are absent.

- `/tmp/release-settings-proof/menu-settings.png`
- `/tmp/release-settings-proof/in-game-settings.png`

The links were not activated because public destinations were still an owner
gate at the time. Approval has since been received; this native check does not
prove the subsequent site deployment. No puzzle progress, coins, turns or
preferences were changed by this check. The absence of ad controls is expected
only for this historical SDK-free build, not the newly approved monetized candidate.

See [release gates](RELEASE-CHECKLIST.md) and
[unsigned production proof](PRODUCTION-ARCHIVE-PROOF.md) before any submission.
