# Independent modifier-score review

## Final build 3: cleared for handoff

The corrected build passed the focused native review on both iPhone 17 Pro (1206×2622 pixels) and SE-test (750×1334 pixels). Tests remained nonpersistent QA sessions.

- Normal controls on both phones produced 960 pending → 1,920 pending after consuming Fresh Ink → 1,920 banked at Turn 2. Both Buff slots were empty afterward.
- Native score accessibility now exposes a Button. Resting/banked announcements omit empty arithmetic; pending announcements include the exact Points, Mult, and total. Activating the Button opened the score ledger; closing it did not alter the score.
- The corrected gain flight retains its original source geometry. Final native recording and 10fps bank contact sheet show the complete +1,920 inside the screen throughout the lift/fade.
- Fresh Ink feedback is readable after its slip uncovers the puzzle, followed by Op-Ed and Stop feedback. Native video shows the expected source outlines without annotations over the board.
- Root also corrected the empty feedback band's collapse. Final 10fps frames show that clearing the receipt leaves the score baseline and board stationary.
- SE screenshots show the entire board, pending/banked score, Hand, Toss, End Turn, and Turn counter on one screen without clipping or scrolling.

Final evidence: `17pro-final-resting.png`, `17pro-final-banked.png`, `17pro-final-flow.mp4`, `17pro-final-bank-contact.png`, `se-final-pending960.png`, `se-final-pending1920.png`, `se-final-banked.png`. The original recordings and earlier failure frames below remain as rollback evidence.

Native timing limitation: CUA accessibility traversal waits long enough for many receipt sequences to finish. The combined rapid-click attempt hit a stale CUA element ID, so this review does **not** claim a successful native rapid End Turn interruption. Normal ledger opening/dismissal and absence of duplicate awards passed; parent reports its focused automated interruption and covered-Buff tests passed separately. No new blocker remained in the final bounded native review.

## Earlier build 1 findings

Device: Book Playtest A — iPhone 17 Pro (iOS 26.3), D04D3836-357E-4E92-811D-6D14E3BA1E01. Build 1. QA launched without persistence. All game actions used native CUA accessibility controls; simctl only captured images/video.

## Verified through normal controls

- Loaded QA → Scoring fixtures → Crimson, Bookmarks and Fresh Ink; no synthetic placement/award was invoked.
- Selected held 4 and placed it at R1C4. Board shows the placed 4 on Crimson; held 4 disappears. Banked score stays 0; pending score shows +960 with 160 × 6.
- Opened held Fresh Ink and selected USE. Both Buff slots become empty. Banked score stays 0; pending score updates to +1,920 with 160 × 12.
- Selected End Turn. Score becomes 1,920 / 3,000 and Turn 2/10; pending line disappears visually. Board has identical outer geometry in resting, pending, and banked screenshots.
- Selected 9 and placed it at R1C9 in Turn 2. Opened and dismissed the score ledger. It consistently showed 90 Points × 12 = 1,080 pending; existing banked 1,920 did not change. No delayed award appeared after dismissal.
- Original video confirms compact named source receipts and exact Op-Ed/Stop outlines, without score text drawn onto the board.
- Read-only source inspection found presentation tasks read the committed calculation and only change ephemeral display fields. Performance UUID checks reject stale receipt updates.

## Issues reported to root for correction

1. Bank gain initially jumps beyond the left edge: `17pro-bank-flight-start.png`, t77.62s of `17pro-normal-flow.mp4`. The + sign is clipped. The bank beat clears the calculation, so the gain anchor appears to be remeasured as invisible +0 before the flight captures its source. Preserve the last nonempty source rectangle.
2. Invisible zero calculation remained in the combined score.preview accessibility label at rest and after banking. Native announcement after banking: “Score, 1,920, Target, 3,000, 0 points this turn, from 0 Points times 3 Mult.” Root has applied an explicit conditional parent label for the next build.
3. Initial Fresh Ink activation feedback ran largely beneath its closing paper slip. Root has added uncovered-page gating for the next build.

## Evidence

- 17pro-resting.png
- 17pro-pending960.png
- 17pro-pending1920.png
- 17pro-banked1920.png
- 17pro-normal-flow.mp4 (original native recording)
- 17pro-video-contact.png (one-frame-per-second overview)
- 17pro-bank-contact.png (bank transition at 10fps, starting 76.8s)
- 17pro-bank-flight-start.png (unmodified extracted native frame)

## Review scope

Final-build corrections and SE sizing were rechecked as described above. No production source was edited during this independent review.
