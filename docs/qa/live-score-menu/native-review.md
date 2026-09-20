# Independent native menu and live-score review

2026-09-19, real app on reviewer iPhone 17 Pro `D04D3836-357E-4E92-811D-6D14E3BA1E01`. Installed app `NumberClub-live-menu-build1.app`, debug dylib SHA-256 `99c9f3acb56757d831d924ae1a63c206fddfff9fad2db58aea41d7e32d3d7560`. Existing marker-hold/markers fixture with Accountant supplied by root. User device `223A4227-A28E-4939-BB5E-3AAB820EB635` was untouched. No production edits.

Verified through CUA native accessibility and real coordinate taps:

- One Arrange hand button opens a compact paper menu anchored above that button. It contains independent accessible Ascending, Descending and Shuffle hand choices. The rest of the screen stays undimmed; board, HUD, hand and bottom actions keep their positions. [Open menu](17pro-arrangement-open.png).
- Selected one specific duplicate 5: card UUID `62CC66E5-8D7A-4473-9462-B7A0A7BD09F9`. Choosing Ascending closed the menu and left that exact UUID selected in the sorted hand. Other duplicate 5 copies retained their separate IDs. [Selected resting state](17pro-rest-selected-duplicate.png).
- Selected Number 2, UUID `65C3D673-0DE5-4684-88F4-388796253887`, then opened the menu. A physical-coordinate CUA click at row 1, column 5 dismissed the menu only: the cell remained blank, Number 2 remained selected, coins stayed at 5 and formula stayed `0 × 1 = +0`.
- A second click at the same coordinate placed 2 exactly once, removed its card, charged Accountant's one coin (5 to 4) and updated the live formula to `20 × 1 = +20`, while remaining on Turn 1. [Live formula after placement](17pro-live-20-after-safe-dismiss.png).

Initial coordinate input failed with the CUA `windowNotFoundAtPosition` error while the review window was on the other display. Using the native Simulator Window menu's **Move to Mi Monitor** resolved coordinate routing; the dismissal and placement checks above then used real coordinate clicks. No alternative input driver was used.

The planned QA Ordered +1 then ×3 fixture (`50 × 6 = +300`) and End Turn bank check were not completed by this reviewer. Root took over the remaining native checks, including the small-phone review. CUA ownership was explicitly released; no subsequent UI actions were performed by this reviewer.
