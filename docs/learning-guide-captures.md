# In-game learning guide captures

Captured game screens, not mockups or generated artwork.

## Current guide — 19 September 2026

The gameplay repair's independent native review found that the old guide still illustrated retired book edges, inventory, Numbers Drawn, Clipping offers and score bars. Current assets now use these byte-identical native captures:

| Bundled asset | Authentic source |
| --- | --- |
| GuideGameplay | [Normal resumed board, score340](qa/gameplay-repair/scoring-touch/S14-second-resume-score-340.png) |
| GuideRoute | [Initial briefing with Lucky Dip skip offer](qa/gameplay-repair/se-initial-briefing-build12.png) |
| GuideShop | [Current Shop Bookmark offers](qa/gameplay-repair/scoring-touch/S13-shop-wallet-14.png) |
| GuideShopItems | [Current Marker cards and purchased Buff](qa/gameplay-repair/se-full-buff-shop-after-explicit-sale.png) |

All four PNGs are750×1334. SwiftUI crops them at display time; figure dimensions, captions and accessibility descriptions now match the captured controls and offers. Original PNGs remain under `qa/gameplay-repair/rollback-help-media-20260919/`.

The bundled `guide-place-and-bank.mp4` is an18.5-second,750×1334,H.264/30fps silent recording of current player controls. The visible first row requires5. Selecting the held5 and placing it at R1C5 clears its row and box for140Points; the equipped Finance Pages and Crossword Daily separately grant2coins and2cards. End Turn banks140, refills the Hand and advances to Turn2. Second Print remains held and unused. The movie explanation identifies the Bookmark side effects so it does not teach them as base clear rewards.

Native source: [current-place-clear-and-bank.mov](qa/gameplay-repair/final-native/current-place-clear-and-bank.mov),80.006667seconds, recorded by the independent final reviewer. Retained intervals are4.5–9,35–42.5 and76.5–80seconds, followed by a3-second hold of the final real frame. Only settled waiting was cut; animation timing within retained intervals is unchanged. Variable-frame-rate source holds were expanded to30fps before trimming. The original September6 film remains [preserved unchanged](qa/gameplay-repair/legacy-guide/guide-place-and-bank-2026-09-06.mp4); the first current capture with an unhelpful empty demonstration board is retained separately as review evidence.

Build19 compiled the refreshed guide successfully, and the independent reviewer verified its current static board/Hand wording, actual movie playback through140points and pinned custom Close on the SE. The final integrated test gate is tracked in the [gameplay repair verification](qa/gameplay-repair/verification.md).

## Archived captures — 6 September 2026

- `GuideGameplay`: exact original `docs/app-store/screenshots/iphone-6.5/03-puzzle-gameplay.png`.
- `GuideRoute`: exact original `docs/app-store/screenshots/iphone-6.5/04-next-puzzle.png`.
- `GuideShop`: exact original `docs/app-store/screenshots/iphone-6.5/05-shop.png`.
- Source PNGs are 1284 × 2778. The SwiftUI guide crops these at display time, with explanatory text and accessible descriptions.

### Archived Watch a turn recording

`App/Resources/HowToPlay/guide-place-and-bank.mp4` is a native Simulator recording captured on 2026-09-06, from the existing app's deterministic `APPSTORE7` gameplay fixture with its Bookmark loadout. Actual controls were used to select 9, place it at row 4 column 2, select 4, place it at row 4 column 3, and End Turn. The final score is 290, including the equipped end-turn Bookmark effect; the Hand refills and the counter advances to Turn 2/10.

Only idle waiting was cut. Game animations retain their original timing; the final real frame is held for three seconds. The silent 26.4-second H.264 film is bundled for offline playback and starts only after the player chooses Watch a turn. It has no ad, networking, or connection to the player's own Book. Text instructions remain available independently.

Capture evidence on this workstation: `/tmp/numberclub-guide-captures/place-and-bank-original.mp4` (115.39 seconds). Retained intervals in seconds: 28–33, 63–70, 82–86, 98.5–104, 113.5–115.4. The interrupted first recording is also retained outside the app bundle.

### Archived verification — 2026-09-06

- 94 focused tests passed: `/tmp/numberclub-learning-final.xcresult`. Includes achievement eligibility and registration filtering, Game Center queue boundaries, prior purchase/sale logic, per-Book progress, onboarding, replay isolation and guide assets/content/rendering.
- Five rendered guide pages inspected at narrow phone, iPad reading-column and accessibility text sizes. Final attachments: `/tmp/numberclub-guide-captures/final-attachments`.
- Live Simulator checks: both menu and in-Book Settings expose Replay tutorial; completion returns to the presenting Settings; Exit practice does the same; reopening starts Practice 1 with a fresh board. Next topic advances the guide, and Watch a turn opens real offline video and dismisses back to the guide.
- Native accessibility tree exposes the heading, numbered instructions, image descriptions, video button and pinned navigation individually.
- Saved `run.json` SHA-256 before/after complete menu replay: `4bf5a94da0d960b68a824a4138cb2c77f9419f379ae93d260fcffd719e52aef5`.
- Saved `profile.json` SHA-256 before/after complete menu replay: `850c2d68994f0057946dd7d6d563ad59d4abb5dfc28ed3107daaa93ccb215cb1`.
- All checks used an isolated local Simulator. No phone installs, Game Center account reports, App Store metadata changes or uploads were performed. Uploaded builds 9 and 10 remain untouched.

### Separate issue recorded during the earlier rules check

Tik Tak's live clock currently continues during Keep Filling; expiry can fail a previously-won Book. The guide therefore does not promise that every Boss's Keep Filling mode is risk-free. This gameplay behavior was not changed by the learning/achievement work and needs a separately scoped regression and product decision.
