# Compact controls verification — 19 September 2026

The marker inspection popup now shows the shared catalogue effect, with only short notices for given-covered or temporarily barred cells. Filled cells no longer add an occupancy paragraph. Onyx reads “Clues here score full placement points.” The question-mark map retains the full availability detail.

Ascending, descending and shuffle actions are inline above the hand. Native simulator activation verified all three actions without an overlay, preserving the same selected duplicate card UUID. Each action is individually exposed in the accessibility tree, with a 44-point hit target. An initial grouping that hid the buttons was removed and rechecked.

Verification:
- 47 selected tests passed: marker content/layout, hand arrangement, Clue presentation and gameplay geometry. Log: `/tmp/nc-compact-ui-tests1.log`.
- Final wording change rebuilt successfully and all eight marker content tests passed. Log: `/tmp/nc-compact-ui-tests3.log`.
- Native iPhone 17 Pro and 375 × 667 iPhone SE layouts inspected. Screenshots: `se-rest.png`, `se-onyx-accessible.png` (explicit dismissal is for accessible inspection).
- Independent agent review found the barrier-duration wording issue, corrected to “Temporarily barred.” No remaining findings in this scoped review.
- The final build is installed and open on the user's iPhone 17 Pro simulator. Its Application Support save files matched the pre-install backup exactly before launch. Backup: `/tmp/NumberClub-compact-controls-user-backup-20260919-1637`.

Scoring remains a proposal in this revision: show a live Points × Mult turn subtotal, highlight triggered modifiers, and bank it on End Turn. An exact payout forecast must also account for direct end-turn awards. No scoring rules were changed.
