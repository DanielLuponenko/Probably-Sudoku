# One-screen gameplay UX repair

Status: implemented. Final build6 passes all 627 app tests and the independent native layout/motion review. Live held-finger drag verification remains limited by the input tool, as detailed below.

The user's latest screenshots and mockup are preserved in [user-reported](user-reported). This request supersedes the earlier allowance for scrolling Results and Shop.

## Acceptance

- Successful Results shows the complete actual 81-cell board, score, payout and decisions together, without a scroll container or clipped ninth row.
- Shop shows every available offer (including the historical sixth offer), Reroll and Continue on the initial screen. Custom item details retain complete rules and purchase handoffs.
- Next Puzzle follows the supplied composition: chapter, connected three-stop route, target and turns, the actual prepared board, named skip reward/effect and visible Skip/Play choices. Bosses remain mandatory.
- During inventory drag, the sell target replaces the route's decisions in the same measured frame. Toss/End Turn are hidden and unavailable. Outside release returns the same item to its slot; sale commits that exact identity once.
- Board preparation and all animations are presentation only until explicit acceptance. Cancellation, navigation, backgrounding, Reduce Motion and existing saved actions preserve ownership and progression.

## Design

Reuse the existing ivory linen, sage board rails, dark Buff tiles and gold bands. Use the mockup's serif Next Puzzle heading and a restrained scale of compact information. Allocate content from the actual viewport after shared inventory and safe areas; do not use scrolling or crop overflow to claim a fit. The board is the main content of briefing and Results; the Shop's three stock rows use the available space evenly.

Motion responds to decisions: prepared boards fade into a reserved square; an accepted reward slips away before its guarded commit; a cancelled inventory lift returns to its source. Geometry stays fixed while controls change. Reduce Motion skips travel.

## Evidence

- Final build6 full suite: **627/627 passed, zero failures or skipped tests** on the iPhone 17 Pro regression device. [Summary](full6-summary.json), [log](full6.log). This includes the strengthened route-only long-name test and owned drag-action-area regression.
- [Independent native review](native-review.md): final iPhone 17 Pro briefing, gameplay, Results and Shop; complete long boss names on SE and iPhone 17 Pro; actual placements, purchases and skips; mandatory boss progression; and sampled recordings of page-turn animations. The review found defects in earlier candidates, which were fixed and rechecked before delivery.
- Integrated build3 focused run: **62 tests, 60 passed, 2 failed**. [Summary](focused3-summary.json), [log](focused3.log). The failures reproduced a collapsed Skip control and incomplete long boss name; both original renders are preserved in `before-fixes/`.
- Build4 recheck: **16/16 passed**, covering all briefing bounds and inventory drag tests. [Summary](recheck4-summary.json), [log](recheck4.log). Root then visually caught remaining route-name ellipsis despite the full name elsewhere satisfying OCR. The final check now examines only the route crop, and the route uses equal explicit columns and intrinsic two-line names.
- Results rendering proves all outer board rails, both internal horizontal box rules, square shape, visible caption and decisions, no scroll container and unchanged game bytes. It includes the actual fullscreen iPhone 17 Pro layout with safe areas, compact phone, AX5 and iPad.
- Shop rendering covers five and six offers across compact phone, iPhone 17 Pro, large phone and iPad, including AX5 and nine long-name/effect cards. Every offer and Continue are visible on the initial screen; native purchase/Continue controls are separately reviewed.
- Prepared-board tests compare the complete encoded preview board with the actual committed board, preserve the live saved game during preparation and reject stale previews after run mutations.
- The real puzzle/action-host rendering verifies Toss and End Turn disappear during an injected drag session and return after cancellation; the visible sell rectangle equals the action row. State tests verify curved coordinates, outside/inside release, repeated ends, exact owned identity, cancellation and stale return-animation callbacks. A departing route cannot clear the new route's registered action frame.
- Root visually inspected the [Results screen](rendered/results-iphone17pro-build3.png), [six-offer Shop at AX5](rendered/shop-iphone17pro-six-offers-AX5-build3.png), [corrected briefing](rendered/briefing-iphone17pro-build4.png) and [replacement sell controls](rendered/drag-actions-replaced-build4.png).

Final build6 compiles successfully. Its immutable candidate is `/tmp/NumberClub-one-screen-build6.app`; actual Debug code image SHA-256 is `d6534b17dd68106444b71aa1349771b007fab62daa7ea1423a29d335145f60c0`. The same code image is installed on the user's iPhone 17 Pro (`223A4227-A28E-4939-BB5E-3AAB820EB635`) and launched normally. The original run/profile were backed up before installation and remained byte-identical after launch: [comparison](user-simulator-backup/after.json).

Root also visually inspected the final native [Results](native/17pro-results-final6.png), [Shop](native/17pro-shop-final6.png), and complete Accountant route on [SE](native/se-accountant-final6.png) and [iPhone 17 Pro](native/17pro-accountant-final6.png). These final images supersede the intermediate build3/build4 captures above.

**Native input limitation:** the independent reviewer made one fresh supported CUA drag on iPhone 17 Pro; it opened the Buff panel as a tap instead of lifting the item. No live curved-drag/return pass is claimed. Hosted rendering, state transitions and identity tests are separate evidence, not substitutes for that pointer interaction.
