# In-game learning guide captures

Captured game screens, not mockups or generated artwork.

- `GuideGameplay`: exact original `docs/app-store/screenshots/iphone-6.5/03-puzzle-gameplay.png`.
- `GuideRoute`: exact original `docs/app-store/screenshots/iphone-6.5/04-next-puzzle.png`.
- `GuideShop`: exact original `docs/app-store/screenshots/iphone-6.5/05-shop.png`.
- Source PNGs are 1284 × 2778. The SwiftUI guide crops these at display time, with explanatory text and accessible descriptions.

## Watch a turn

`App/Resources/HowToPlay/guide-place-and-bank.mp4` is a native Simulator recording captured on 2026-09-06, from the existing app's deterministic `APPSTORE7` gameplay fixture with its Bookmark loadout. Actual controls were used to select 9, place it at row 4 column 2, select 4, place it at row 4 column 3, and End Turn. The final score is 290, including the equipped end-turn Bookmark effect; the Hand refills and the counter advances to Turn 2/10.

Only idle waiting was cut. Game animations retain their original timing; the final real frame is held for three seconds. The silent 26.4-second H.264 film is bundled for offline playback and starts only after the player chooses Watch a turn. It has no ad, networking, or connection to the player's own Book. Text instructions remain available independently.

Capture evidence on this workstation: `/tmp/numberclub-guide-captures/place-and-bank-original.mp4` (115.39 seconds). Retained intervals in seconds: 28–33, 63–70, 82–86, 98.5–104, 113.5–115.4. The interrupted first recording is also retained outside the app bundle.

## Verification — 2026-09-06

- 94 focused tests passed: `/tmp/numberclub-learning-final.xcresult`. Includes achievement eligibility and registration filtering, Game Center queue boundaries, prior purchase/sale logic, per-Book progress, onboarding, replay isolation and guide assets/content/rendering.
- Five rendered guide pages inspected at narrow phone, iPad reading-column and accessibility text sizes. Final attachments: `/tmp/numberclub-guide-captures/final-attachments`.
- Live Simulator checks: both menu and in-Book Settings expose Replay tutorial; completion returns to the presenting Settings; Exit practice does the same; reopening starts Practice 1 with a fresh board. Next topic advances the guide, and Watch a turn opens real offline video and dismisses back to the guide.
- Native accessibility tree exposes the heading, numbered instructions, image descriptions, video button and pinned navigation individually.
- Saved `run.json` SHA-256 before/after complete menu replay: `4bf5a94da0d960b68a824a4138cb2c77f9419f379ae93d260fcffd719e52aef5`.
- Saved `profile.json` SHA-256 before/after complete menu replay: `850c2d68994f0057946dd7d6d563ad59d4abb5dfc28ed3107daaa93ccb215cb1`.
- All checks used an isolated local Simulator. No phone installs, Game Center account reports, App Store metadata changes or uploads were performed. Uploaded builds 9 and 10 remain untouched.

## Separate existing issue found while checking the rules

Tik Tak's live clock currently continues during Keep Filling; expiry can fail a previously-won Book. The guide therefore does not promise that every Boss's Keep Filling mode is risk-free. This gameplay behavior was not changed by the learning/achievement work and needs a separately scoped regression and product decision.
