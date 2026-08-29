# GENERATION_BRIEFS — Phase 2 Meshy generation-brief package

Status: `DRAFT_AWAITING_CODEX_REVIEW`

Task: `VISUAL-001` · Agent run: `FA8D4F18-F405-4824-B5EA-3FC2B60C99E4` · Branch: `feature/KAN-153-visual-target` · Base commit: `942e0b4890645a306fc4e39140139de27b5dfbbb` · Created: 2026-08-29T09:56:57.423Z

Correction: `VISUAL-001-R1` · Correction agent: `sonnet-shop-scene-engineer` · Correction run: `0DEEECFA-868D-44A5-8C87-6A1005226F9F` · Corrects/preserves immutable commit: `ea9a15e208afd1027648149350d471a8fbfeb51f` · Corrected: 2026-08-29T10:15:26.000Z

Review: `VISUAL-001-R2` · Reviewer agent: `sonnet-independent-reviewer` · Recommendation: `PASS` · Codex disposition: rejected — Codex found contradictions the R2 review did not resolve, corrected below.

Correction: `VISUAL-001-R3` · Correction agent: `sonnet-shop-scene-engineer` · Manager run ID: `15BC0AF9-8200-4701-9AEC-035F5EDBF58A` · Corrects/preserves immutable commit chain through: `5f236c6ae6931088c75b1301b6621340ac600fce` · Closes five contradictions: (C1) removed permissive `cut`/`snap` wording from Reduce Motion camera rules, (C2) reordered the BUY sequence so confirmed persistence always precedes stamp press/contact/impact-feedback/`OWNED` display, (C3) replaced the unvalidated 3%-of-shorter-viewport-dimension legibility floor with a validated 24pt/32pt silhouette-plus-independent-hit-target-plus-physical-tag browseability floor, (C4) added machine-readable zero-credit proof to the JSON, (C5) removed the inherited extra blank line at this file's EOF.

This artifact creates specifications only. It does not implement runtime code, generate art, call Meshy, spend credits, modify a production ledger row, or pass its own review gate. **Credits consumed: 0. No Meshy call made.**

The initial VISUAL-001 commit is preserved as immutable evidence but was rejected: it covered the 208 ledger IDs and general 3D bookstore direction without encoding the user's primary interaction contract precisely enough. The VISUAL-001-R1 correction (authority: D-009, direct user confirmation dated 2026-08-29) does not reset, rewrite, squash, delete, or hide that commit; it adds the opening-to-store journey and physical stand retail contract below as non-redesignable, machine-reviewable requirements and removes the prior compact-screen end-marker exception. The VISUAL-001-R3 correction above likewise does not reset, rewrite, squash, delete, or hide any prior commit, including the R1 correction commit or the R2 review; it amends the same two artifacts in place to close the five contradictions Codex found. None of VISUAL-001, R1, R2, or R3 change the 208/206/2/43/13/7/8/72/2 catalog accounting, the approved reference set, or the Phase 4 hardest-case wave.

## 0. Opening-to-store journey and physical stand retail contract (primary release gate)

This section is the primary product experience and a hard release gate. It governs every family below and may not be redesigned, reduced, or bypassed by any family-level brief. Full machine-readable form: `experienceFlow`, `physicalStandRetail`, `purchaseMechanism`, `equipMechanism`, `reversePathAndPersistence`, `flowEvidenceGates` in `GENERATION_BRIEFS.json`.

**One scene, one camera.** Tapping `SHOP` performs one uninterrupted cinematic camera move from the opening bookstore composition directly to the physical store stand; opening controls fade during travel. `BACK` reverses the identical path; shop controls fade out and opening controls fade back in. Opening and shopping are two camera compositions inside one continuous live 3D world — same geometry, lighting, shadows, products, and selection state throughout. There is no cut, view swap, second scene/canvas, loading interstitial, or flat shop screen at any point.

**The physical stand is the entire store.** Browsing, selection, inspection, buying, and equipping all happen through physical merchandise, tags, plaques, lamps, controls, and mechanisms on the stand. The flat `ClubShopView`, generic card lists, popups, sheets, and separate confirmation screens are explicitly release-rejected — not deferred, not acceptable as a fallback.

### State table

| State | Trigger in | Camera | Controls | Trigger out |
|---|---|---|---|---|
| `opening` | app launch / `exitingShop` completion | deterministic opening endpoint | opening controls interactive | `SHOP` tap |
| `enteringShop` | `SHOP` tap | interpolating opening → shopping | opening controls fading out, all input-locked | camera arrival completion callback |
| `shopping` | `enteringShop` completion, or `purchasing`/`equipping` completion | deterministic shopping endpoint | shop controls interactive | `BUY`, `EQUIP`, or `BACK` tap |
| `purchasing` | `BUY` tap on affordable unowned selected product | unchanged (shopping endpoint) | purchase/equip controls input-gated | purchase sequence deterministic completion |
| `equipping` | `EQUIP` tap on owned selected product | unchanged (shopping endpoint) | purchase/equip controls input-gated | equip sequence deterministic completion |
| `exitingShop` | `BACK` tap (deferred if `purchasing`/`equipping` in flight) | interpolating shopping → opening | shop controls fading out, opening controls fade in only on arrival | camera arrival completion callback → `opening` |

### Interaction mechanics table

| Interaction | Physical mechanism | Commit point | Reduce Motion equivalent |
|---|---|---|---|
| `SHOP` / `BACK` | One uninterrupted camera path, reversed for `BACK`; opening/shop controls cross-fade | camera reaches its deterministic locked endpoint | shortened duration, or a zero-duration transform interpolation to the same two endpoints executed by the same live camera inside the same live 3D scene; never a cut, snap out of that scene, or view/scene swap |
| Select product | Product physically moves/hands into the central lit, shadowed, rotating proofing platform | selection commit; every other active-category product stays visible at its deterministic stand position | automatic spin stops; drag or an accessible "Rotate preview" action remains available |
| `BUY` | Authoritative validation → one atomic balance/ownership transaction submitted → **confirmed persistence** → physical brass stamp: press → down → contact → release → confirmation | **confirmedPersistence** phase, which always occurs *before* the stamp press begins; stamp **contact** only reveals the already-persisted balance decrement and `OWNED` tag and fires the impact sound/haptic — it never causes them | press/down/contact/release shortened to a direct state change at the same post-persistence commit point; stamp/tag change, sound, haptic preserved; still never shown before confirmed persistence |
| `EQUIP` | Product mechanically slides/rotates onto the central proofing position; lamp brightens; prior item returns to its stand position | mechanical-move completion: authoritative equip-state write submitted for persistence | mechanical move/lamp brighten shortened to a direct state change; plaque/lamp/position change preserved |

**Purchase transaction ordering (locked; corrects VISUAL-001-R2 contradiction C2).** The BUY sequence is authoritative-first: input → authoritative validation → submit one atomic balance/ownership transaction → wait for confirmed persistence → *only then* does the physical brass stamp press/down/contact/release → confirmation. Before confirmed persistence the brass stamp stays at rest; no stamp contact, impact sound, impact haptic, displayed balance decrement, or `OWNED` tag is ever shown (a non-confirming pending/accessibility state, e.g. a busy indicator, may be shown but must not imitate stamp impact). Insufficient funds, duplicate/already-owned input, cancellation before submission, or persistence failure all leave the stamp at rest with state exactly unchanged and no successful physical confirmation. If persistence succeeds and the app is then interrupted before contact, the authoritative purchase remains valid and the physical stamp confirmation completes deterministically on foreground/re-entry — the product is never charged without eventually showing truthful ownership/balance state. Full machine-readable form: `purchaseMechanism.sequence` / `.failureAndRollback` / `.postconditionInvariant` in `GENERATION_BRIEFS.json`.

### Simultaneous-count table

| Category | Required simultaneous count | Digits-per-selected-style requirement |
|---|---:|---|
| Paper | 13 | — |
| Grid | 7 | — |
| Numbers | 8 | selected style shows digits 1–9 together at inspection scale; player equips the style package, not nine products |

No virtualization, pagination, clipping, overflow drawer, end marker (including any compact-screen exception), or selected-plus-neighbors shortcut may hide any active-category product on any device. Responsive framing may use multiple physical tiers/depth rows while keeping every product visible, subject to the measurable silhouette-separation, legibility, hit-target, occlusion, z-fighting, and shadow bounds in `physicalStandRetail.responsiveFraming.measurableBounds`.

### Browseability floor (locked; corrects VISUAL-001-R2 contradiction C3)

"Browseable" means visibly distinguishable, not a tiny thumbnail. The prior "3% of the shorter viewport dimension" floor is invalidated and replaced — it could produce an approximately 11-point object on compact hardware and did not prove the user could choose it.

| Requirement | Floor |
|---|---|
| Resting-pose product silhouette, shorter screen-space dimension | ≥ 24pt compact · ≥ 32pt standard/larger |
| Thin paper/grid forms | may use their **longer** screen-space dimension plus the physical name/style tag to satisfy recognition; neither product nor tag may be hidden |
| Hit target | independent 44×44pt per product (separate from every neighboring product's hit target) |
| Physical name/style tag | non-overlapping, legible at native resolution without zoom/selection, ≥ 11pt default text before Dynamic Type, meets existing contrast/accessibility requirements |
| Human screenshot review | must correctly identify all 13 Paper, all 7 Grid, and all 8 Number products from the fully populated category frame |

These floors may only increase from later real-device evidence that proves them insufficient; they may never be lowered merely to fit 13/7/8. Responsive tiers, camera composition, and stand geometry must solve fit while every active-category product stays simultaneously visible. Full machine-readable form: `physicalStandRetail.responsiveFraming.measurableBounds.legibility` / `.physicalNameTag` in `GENERATION_BRIEFS.json`.

### Persistence table

| State | Authoritative owner | Persists across |
|---|---|---|
| `selectedCategory`, `selectedProductId` | single authoritative state owner (one source-of-truth store/service) | `BACK` exit, restored opening, re-entry (`SHOP` again), backgrounding, relaunch |
| `ownedProductIds` | same authoritative state owner | exit, re-entry, backgrounding, relaunch |
| equipped product per applicable slot | same authoritative state owner | exit, re-entry, backgrounding, relaunch |
| in-flight `purchasing`/`equipping` transaction | same authoritative state owner | `BACK` is deferred until deterministic completion or a defined safe-cancellation point; never charge without persisted ownership, never show `OWNED`/`EQUIPPED` without persisted state |

### Evidence table

| Evidence | Requirement |
|---|---|
| Motion frames | opening; entry start; entry midpoint; stand arrival; reverse midpoint; restored opening; re-entry with selection preserved |
| Catalog frames | all 13 Paper at once; all 7 Grid at once; all 8 Number styles at once; selected Number style digits 1–9 |
| Transaction frames | BUY stamp contact and resulting `OWNED` tag/balance; EQUIP motion/lamp/`EQUIPPED` plaque |
| Matrix | every frame above repeated on compact, standard, largest, physical device, and minimum supported iOS where available; every supported orientation; Dynamic Type extremes; VoiceOver; Reduce Motion |
| Automated assertions | state-transition graph; single camera/scene identity; input/race behavior; simultaneous 13/7/8 visibility; deterministic selection; exact-once purchase; equip persistence; reverse camera endpoints; flat `ClubShopView` not release-reachable |
| Negative assertions | no old neighbor-only/end-marker allowance remains; no virtualization/pagination/overflow-drawer shortcut; no popup/sheet BUY or EQUIP confirmation |
| Performance | both camera directions; fully populated stands; selected rotation; BUY/EQUIP sequences; existing budgets not relaxed |

### Release-rejection table

| Rejected pattern | Why |
|---|---|
| Flat `ClubShopView`, generic card list, popup, sheet, or separate confirmation screen | The physical stand must be the entire store, not a UI layer bolted onto it |
| Any cut, second scene/canvas, or loading interstitial between opening and shopping, **including under Reduce Motion** | Opening and shopping must be one continuous scene/camera at all times; Reduce Motion may only shorten duration or use a zero-duration transform interpolation inside that same live camera/scene, never a cut, hard snap out of the scene, or a swap to a second renderer/view/scene |
| End marker, compact-screen exception, paging, virtualization, overflow drawer, or selected-plus-neighbors shortcut hiding any product | Every active-category product (13/7/8) must be simultaneously visible and selectable on every device |
| A resting active-category product silhouette below 24pt (compact) / 32pt (standard/larger), a missing independent 44×44pt hit target, or a missing/sub-11pt physical name/style tag | Browseable means visibly distinguishable, not a tiny thumbnail; this floor may only rise from real-device evidence, never fall to fit 13/7/8 |
| Stamp press, contact, impact sound/haptic, displayed decrement, or `OWNED` tag shown **before** the authoritative transaction has confirmed persistence | A failed or not-yet-confirmed purchase must never produce a false stamp confirmation |
| False BUY stamp, double stamp-balance decrement, premature `OWNED`/`EQUIPPED` state | Purchase/equip must be exact-once, persistence-gated physical transactions |
| Lost selection/ownership/equip persistence across exit, re-entry, backgrounding, or relaunch | Selection and physical state must remain truthful across the full lifecycle |
| Camera stranded at a non-deterministic intermediate pose after interruption or repeated taps | Camera transitions must be race-safe and always resolve to a deterministic endpoint |

## Authority and non-redesignable theme

Governed by `/Users/daniel/meshy_club_shop_master_prompt.md` (`CONTRACT-001`), `docs/meshy-production/REFERENCE_INDEX.md`, and `docs/meshy-production/VISUAL_INVARIANTS.md`. The only references permitted to govern visual generation for any family in this package are:

- `CONTRACT-001` — `/Users/daniel/meshy_club_shop_master_prompt.md` (sha256 `473e52da4c5ba2622ed3021f3d08564cc3e563495278e4c6eb228930fdde520c`) — Direct user instruction in KAN-153 goal
- `MOCKUP-BOOKSTORE-001` — `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/bookstore-aisle.html` (sha256 `0934eaa191d573b450d82f607476bc8bd67b7c8f36011d78a5305b7081e42561`) — Direct user re-approval on 2026-08-29: "the shop should look like in the mockup but better"
- `MOCKUP-BOOKSTORE-002` — `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/bookstore-aisle-rendered.html` (sha256 `c33a6f03bd2e977ec55c2ed87b2005565edf26d8fe2790347c1bda81de0895f4`) — Direct user re-approval on 2026-08-29 and explicit instruction to open/interact before editing

Explicitly excluded from governing generation (tracked for audit, never a generation target):

- `MOCKUP-SHOP-001` — Discovered adjacent mockup; user approval not proven; may not override the bookstore mockups
- `MOCKUP-SHOP-002` — Discovered adjacent rendered mockup; user approval not proven; may not override the bookstore mockups
- `SCREENSHOT-CLUBSHOP-001` — Audited as non-conforming flat baseline, not a generation target

**Non-redesignable theme:** one continuous private bookstore club room — rich walnut cabinetry, deep bottle-green surfaces, aged-brass hardware, warm vellum/paper, controlled warm theatrical lighting, premium letterpress/proofing-counter character. At least three visible depth planes. The selected item receives the strongest proofing light and rotates about its validated optical pivot without drift. No theme, catalog, or requirement-count reduction is authorized by this document.

## Responsive composition table

| Device ID | Device | OS | Role |
|---|---|---|---|
| DEV-COMPACT | iPhone SE (KAN85 QA device) | iOS 26.3.1 | compact |
| DEV-17PRO | iPhone 17 Pro | iOS 26.3.1 | standard |
| DEV-LARGEST | iPhone 17 Pro Max | iOS 26.3.1 | largest |
| DEV-PHYSICAL | Daniel's iPhone 16 Pro Max | iOS 26.0.1 | physical_device |
| DEV-MIN-IOS | Minimum supported iOS runtime/device | iOS 17.0 (project.yml deploymentTarget) | minimum_ios |

Measurable assertions locked for every device/orientation/state above:

- Zero clipping or intersection: merchandise, controls, and neighbors must not clip either horizontal edge or intersect the counter or each other.
- Complete first/middle/last reachability: for every category, the first, middle, penultimate, and last catalog item must be selectable through visible controls, swipe/drag, keyboard arrows where available, and VoiceOver.
- Truthful denominators: Paper shows X / 13, Grid shows X / 7, Numbers shows X / 8, always matching the true catalog count.
- Selected-item containment: the selected item never drifts outside its display bay.
- Neighbor behavior: previous/next items, and every other active-category product regardless of device size, stay fully visible, individually selectable, inside counter/stand boundaries, and visually subordinate to the selected item; no end marker (including any compact-screen exception), virtualization, pagination, clipping, overflow drawer, or selected-plus-neighbors shortcut may stand in for any active-category product on any device (see §0 and `physicalStandRetail` in `GENERATION_BRIEFS.json`).
- Optical-pivot drift tolerance: 2 points on the compact phone or 0.5% of viewport width on any larger phone, whichever is stricter, across one full revolution.
- Tap targets: Every interactive control has a hit target of at least 44 by 44 points, locked from VISUAL_INVARIANTS.md #5.
- Safe area: Camera framing is safe-area/Dynamic-Island/home-indicator aware; controls and labels must not overlap the product silhouette, turntable, safe area, or each other.
- Orientation: Portrait and every supported orientation must be captured per device; no captured orientation may clip a horizontal edge.
- Dynamic Type: Runtime text (names, prices, descriptions, balances, state copy) supports Dynamic Type without breaking the 44pt tap targets or causing overlap with merchandise.
- VoiceOver: Focus order follows category → merchandise navigation → selected product details → price/state → purchase/equip. Every physical product has a localized accessible name and state; loading/error states are announced.
- Reduce Motion: Automatic turntable spin and effect animation (flame/laser pulse, laser-grid travel) stop or simplify; a direct drag or accessible "Rotate preview" action remains available; purchase/selection/inspection remain fully available.

## Family brief table and 208-row coverage formula

Total ledger IDs: **208** · Visible production IDs: **206** · Dead-code disposition IDs: **2** · Expanded brief ID count: **208** · Duplicates: **0** · Family count: **43** · Matches ledger exactly: **true**

Coverage formula: `206 visible Meshy-origin production briefs + 2 explicit dead-code disposition briefs = 208 = the full COVERAGE_LEDGER.csv row count`, with zero duplicate canonical IDs across all families.

| Family ID | Category | # IDs | Shop | Gameplay | Phase 4 hardest case |
|---|---|---:|---|---|---|
| `numbers-nb_press` | numbers | 9 | true | true | no |
| `numbers-nb_typewriter` | numbers | 9 | true | true | no |
| `numbers-nb_schoolbook` | numbers | 9 | true | true | no |
| `numbers-nb_oldstyle` | numbers | 9 | true | true | no |
| `numbers-nb_stencil` | numbers | 9 | true | true | no |
| `numbers-nb_neon` | numbers | 9 | true | true | no |
| `numbers-nb_laser` | numbers | 9 | true | true | yes |
| `numbers-nb_flame` | numbers | 9 | true | true | yes |
| `effects-nb_flame` | effects | 2 | true | true | yes |
| `grid-bd_printed` | grid | 1 | true | true | no |
| `grid-bd_fine` | grid | 1 | true | true | no |
| `grid-bd_heavy` | grid | 1 | true | true | no |
| `grid-bd_sage` | grid | 1 | true | true | no |
| `grid-bd_blueprint` | grid | 1 | true | true | no |
| `grid-bd_gilt` | grid | 1 | true | true | no |
| `grid-bd_laser` | grid | 1 | true | true | yes |
| `paper-pp_newsprint` | paper | 2 | true | true | no |
| `paper-pp_white` | paper | 2 | true | true | yes |
| `paper-pp_ivory` | paper | 2 | true | true | no |
| `paper-pp_manila` | paper | 2 | true | true | no |
| `paper-pp_ledger` | paper | 2 | true | true | no |
| `paper-pp_graph` | paper | 2 | true | true | no |
| `paper-pp_onion` | paper | 2 | true | true | no |
| `paper-pp_carbon` | paper | 2 | true | true | no |
| `paper-pp_telegram` | paper | 2 | true | true | no |
| `paper-pp_garden` | paper | 2 | true | true | no |
| `paper-pp_night_sky` | paper | 2 | true | true | no |
| `paper-pp_ocean` | paper | 2 | true | true | no |
| `paper-pp_utility_roll` | paper | 2 | true | true | yes |
| `shop-environment-structural-shell` | shop_environment | 10 | true | false | no |
| `shop-environment-leftWall-bookcase` | shop_environment | 11 | true | false | no |
| `shop-environment-rightWall-bookcase` | shop_environment | 14 | true | false | no |
| `shop-environment-aisle-bay` | shop_environment | 7 | true | false | no |
| `shop-environment-back-wall` | shop_environment | 7 | true | false | yes |
| `shop-environment-high-shelf-wall` | shop_environment | 6 | true | false | no |
| `shop-environment-proofing-stand` | shop_environment | 16 | true | false | yes |
| `shop-display-counter-fixtures` | shop_display | 7 | true | false | no |
| `shop-display-signage` | shop_display | 2 | true | false | no |
| `shop-display-sample-and-product-rails` | shop_display | 2 | true | false | no |
| `shop-display-drawers` | shop_display | 4 | true | false | no |
| `shop-display-proofing-bay-turntable` | shop_display | 5 | true | false | yes |
| `shop-display-pendant-lamp` | shop_display | 8 | true | false | no |
| `shop-display-dead-code-neighbor-card` | shop_display_dead_code | 2 | false | false | no |

## Full 13 / 7 / 8 catalog rule

| Category | Required count | IDs |
|---|---:|---|
| Paper (shop + gameplay each) | 13 | pp_newsprint, pp_white, pp_ivory, pp_manila, pp_ledger, pp_graph, pp_onion, pp_carbon, pp_telegram, pp_garden, pp_night_sky, pp_ocean, pp_utility_roll |
| Grid | 7 | bd_printed, bd_fine, bd_heavy, bd_sage, bd_blueprint, bd_gilt, bd_laser |
| Numbers (× 9 digits = 72) | 8 | nb_press, nb_typewriter, nb_schoolbook, nb_oldstyle, nb_stencil, nb_neon, nb_laser, nb_flame |

No fourth Desk category exists. The two physical flame components (`effect.nb_flame.crown`, `effect.nb_flame.embers`) are tracked as the `effects-nb_flame` family, distinct from the 72 digit leaves.

## Phase 4 hardest-case briefs

### Flaming Numbers digits 1–9

Family IDs: `numbers-nb_flame`, `effects-nb_flame` · Canonical IDs (11): `number.nb_flame.1`, `number.nb_flame.2`, `number.nb_flame.3`, `number.nb_flame.4`, `number.nb_flame.5`, `number.nb_flame.6`, `number.nb_flame.7`, `number.nb_flame.8`, `number.nb_flame.9`, `effect.nb_flame.crown`, `effect.nb_flame.embers`

### Laser Numbers digits 1–9

Family IDs: `numbers-nb_laser` · Canonical IDs (9): `number.nb_laser.1`, `number.nb_laser.2`, `number.nb_laser.3`, `number.nb_laser.4`, `number.nb_laser.5`, `number.nb_laser.6`, `number.nb_laser.7`, `number.nb_laser.8`, `number.nb_laser.9`

### Laser Grid

Family IDs: `grid-bd_laser` · Canonical IDs (1): `grid.bd_laser`

### Clean-white-paper package

Family IDs: `paper-pp_white` · Canonical IDs (2): `paper.pp_white.shop`, `paper.pp_white.gameplay`

### Toilet-paper package

Family IDs: `paper-pp_utility_roll` · Canonical IDs (2): `paper.pp_utility_roll.shop`, `paper.pp_utility_roll.gameplay`

### Modular bookstore background section

Family IDs: `shop-environment-back-wall` · Canonical IDs (7): `env.backWall.backing`, `env.backWall.upright`, `env.backWall.shelf`, `env.backWall.fillerBook.body`, `env.backWall.fillerBook.spine`, `env.backWall.fillerBook.band`, `env.backWall.crown`

### Merchandise proofing stand/display bay

Family IDs: `shop-environment-proofing-stand`, `shop-display-proofing-bay-turntable` · Canonical IDs (21): `env.stand.base`, `env.stand.bearing`, `env.stand.foot`, `env.stand.pole`, `env.stand.tierRing`, `env.stand.tierSpoke`, `env.stand.topCap`, `env.stand.signPlaque`, `env.stand.signPlate`, `env.stand.book.pages`, `env.stand.book.board`, `env.stand.book.spine`, `env.stand.book.coverPlane`, `env.stand.book.backPlane`, `env.stand.book.obstacleTab`, `env.stand.pocketWire`, `shop.display.plinth`, `shop.display.turntableTop`, `shop.display.registerRing`, `shop.display.registerTick`, `shop.display.priceTag`

## Rejection checklist

- [ ] Theme drift away from private-bookstore walnut/bottle-green/aged-brass/vellum character into generic mobile-store cards, casino, military, arcade, or sci-fi-store presentation.
- [ ] Flat/generic card-store output in place of a continuous, physically lit 3D room with at least three visible depth planes.
- [ ] A monolithic, precomposed room model that crops unpredictably instead of a modular, aspect-ratio-aware kit.
- [ ] Any missing product, missing digit (1–9), or missing grid/paper package against the 13/7/8 catalog truth.
- [ ] A shop preview that uses unrelated art from the gameplay asset, or vice versa (fake shop/gameplay asset mismatch).
- [ ] Any digit whose readability depends on bloom/emissive being enabled.
- [ ] Generic toilet paper: a tinted/generic white plane standing in for the Utility Roll shop or gameplay deliverable.
- [ ] Floating or intersecting objects: any merchandise, control, or fixture without a coherent contact shadow, or that intersects the counter, neighboring products, or controls.
- [ ] Painted-on generic blob shadows in place of coherent scene-consistent contact/cast shadows.
- [ ] Pivot drift beyond the locked tolerance (2pt compact / 0.5% viewport width larger, whichever stricter) during a full turntable revolution.
- [ ] Use of any reference not listed in approvedReferenceIds for this package, including MOCKUP-SHOP-001/002 or SCREENSHOT-CLUBSHOP-001, to govern generation.
- [ ] Any procedural primitive, SwiftUI Shape/Path/Canvas/gradient, SF Symbol, or font glyph substituting for required Meshy-origin art.
- [ ] Incomplete provenance: missing Meshy task id, missing prompt/checksum, missing preserved source, or missing registry mapping for any canonical id in this package.
- [ ] Any flat `ClubShopView`, generic card list, popup, sheet, or separate confirmation screen release-reachable for browsing, buying, or equipping in place of the physical stand.
- [ ] Any responsive rule permitting an end marker, compact-screen exception, paging, virtualization, overflow drawer, or selected-plus-neighbors shortcut to hide any active-category product below the required 13/7/8 simultaneous count.
- [ ] A camera cut, second scene/canvas, loading interstitial, or view swap between the opening composition and the physical stand in either travel direction, including a Reduce Motion implementation that cuts, hard-snaps outside the live camera/scene, or swaps to a second renderer/view/scene instead of a same-scene zero-duration transform interpolation.
- [ ] A false `BUY` stamp, double stamp-balance decrement, premature `OWNED`/`EQUIPPED` state, or lost selection/ownership/equip persistence across exit, re-entry, backgrounding, or relaunch.
- [ ] Any stamp press, contact, impact sound, impact haptic, displayed balance decrement, or `OWNED` tag shown before the authoritative balance/ownership transaction has confirmed persistence — for insufficient funds, duplicate/already-owned input, cancellation before submission, or persistence failure alike.
- [ ] A browseability floor below 24pt (compact) / 32pt (standard/larger) resting silhouette, a missing independent 44×44pt hit target, or a missing/overlapping/sub-11pt physical name/style tag, used to make 13/7/8 fit on any device.

## Handoff fields required from the Phase 3 pipeline

For every canonical ID in every visible-production family, Phase 3 (`sonnet-meshy-pipeline-engineer`) must populate in `COVERAGE_LEDGER.json`/`.csv`:

- Meshy generation mode, exact requested model, exact resolved model/version (selected live from current official Meshy documentation at execution time — **not pinned by this document**).
- Meshy task id(s), full prompt and prompt checksum, reference-input paths and checksums, request/response payload paths, creation timestamp, consumed credits, retry count.
- Preserved source-asset path, provider-native USDZ path (when supplied), source GLB path, optimized runtime USDZ path, LOD paths, texture-map paths, source checksum, runtime checksum.
- Registry key, shop renderer path, gameplay renderer path, thumbnail path (rendered from the registered runtime asset).
- Test IDs, screenshot IDs, author run ID, reviewer run ID, and final status (only `APPROVED` counts as complete, and only Codex may set it after independent review).

Explicit **credits consumed: 0**. **No Meshy call made** while authoring this package. Machine-readable form: `zeroCreditProof.creditsConsumedStatement` (`"credits consumed: 0"`) and `zeroCreditProof.meshyCallStatement` (`"No Meshy call made"`) in `GENERATION_BRIEFS.json`.

## Dead-code disposition

- `shop-display-dead-code-neighbor-card` (shop.display.neighborCard.backing, shop.display.neighborCard.face): Dead procedural SceneKit path: addShopNeighborCards() is defined in BookstoreSceneCoordinator.swift but never called (grep-confirmed, only its own definition plus two internal references exist). It is currently unreachable in production.
