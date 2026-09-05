# Club Shop — redesign plan

**Scope:** the out-of-game Club Shop (the walnut counter in the bookstore), where Stamps buy paper, grid and number cosmetics. Not the in-run shop page.
**Goal:** a counter that is beautiful, simple, honest and shippable — every one of the 28 catalogue items visible, previewable and purchasable, on every iPhone, at 60 fps, in a bundle the App Store will take.
**Date:** 4 September 2026 · **Author:** Claude, for Daniel · **Status:** design settled; implementation started (see §8).

---

## 0. The decision in one paragraph

The cabinet stays; the merchandise changes. The walk to the counter, the walnut-and-brass cabinet, the bookcases, the pendant and picture lights are all keepers — they are the room, and they are what Meshy is good at. What goes is the idea of selling **3D tiles** as if they were the products. A paper stock, a grid rule and a number face are *page materials*; the only honest way to show one is with the code that prints the page. So the counter becomes a **proofing counter**: a real page, mid-puzzle, hangs in the hutch printed in whatever you tap; the 28 samples stand on the counter as small cards of the actual material with their price, owned or in-use state on a tag; three brass department tabs sit on the sign plaque; and one till strip at the foot says the name, the blurb and the single thing you can do about it. Everything you see is what lands on your page. The 1 GB of USDZ that never appears on screen leaves the bundle, and the 3-million-triangle cabinet is cut to a phone-sized mesh.

---

## 1. What is on the counter today — audit

### 1.1 Where it lives

| Layer | File | What it does now |
| --- | --- | --- |
| Room + counter (SceneKit) | `App/Views/MainMenu/BookstoreSceneCoordinator.swift` (3,523 lines) | Builds the aisle, the book stand and the shop: **three clones** of the Meshy cabinet side by side, a carousel that slides them on swipe, hand-placed Meshy board tiles on the Grid cabinet, a rotating "proof bay" turntable, baked gold titles and nameplates. |
| Shop chrome (SwiftUI) | `App/Views/MainMenu/ClubShopOverlay.swift` | Back, `5 STAMPS`, an unused product strip, a horizontal drag mirrored into the 3D carousel. |
| State + gates | `App/Views/MainMenu/BookstoreSceneState.swift` | `ClubShopRuntimeRegistry` / `ClubShopFixtureRegistry` — fail-closed JSON registries that only admit an item when a Meshy asset with a recorded checksum and reviewer ID exists. Both bundled registries are **empty** (`EMPTY_PENDING_APPROVAL`). |
| Flow | `App/Views/MainMenu/BookstoreOpeningView.swift` | Category/item state, buy/equip, toasts, haptics. Refuses to sell anything the registry does not list ("ASSET PENDING"). |
| Catalogue + economy | `App/Model/CosmeticItem.swift`, `CosmeticTheme.swift`, `PlayerProfileStore.swift` | 13 papers, 7 grids, 8 number faces; ledger-based Stamps; equip/purchase rules. **This layer is good and untouched.** |
| Real renderers | `App/Views/CosmeticSkinRendering.swift`, `BookView.swift`, `GridView.swift`, `HandStripView.swift` | `CosmeticGridRules`, `CosmeticNumberGlyph`, `PaperStockOverlay`, `PaperGrain` — the code that actually prints every cosmetic on the live page. |
| Dead code | `App/Views/ClubShop/ClubShopView.swift`, `CosmeticCard.swift`, `CosmeticInPlayPreview.swift`, `CosmeticCurrencyBadge.swift` | The retired flat catalogue. Compiled, never shown. |

### 1.2 What is wrong (what you saw in the simulator)

1. **Paper and Numbers are empty and unbuyable.** The registry is empty, so 21 of 28 items render nothing and the button reads `ASSET PENDING`. The default paper shows `PAPER · 0 STAMPS`.
2. **The Grid tiles are not the products.** `MIDNIGHT · LUNAR OBSIDIAN` stands in for *Heavy Rule*, `STARGAZER` for *Blueprint*, `CLASSIC · IVORY & BRASS` for *Printed Rule*; there is a `PORCELAIN` tile that maps to nothing. A player buying "Midnight" gets thicker black hairlines. That is a lie on the counter.
3. **Assets float.** The tiles are fitted into abstract "bays" measured as fractions of the cabinet bounds, not to its shelves; the top row hangs in the air, the title `Grid` prints over the tiles, the turntable sample collides with the lower shelf.
4. **Browsing is undiscoverable.** Departments change only by swiping the whole cabinet; there are no tabs, no indication that Grid and Numbers exist. Items are selected by tapping small 3D tiles through SceneKit hit-testing.
5. **State is invisible.** Owned, equipped, price and affordability appear only for the selected item in the strip — the design language explicitly requires them "visible without opening a detail view".
6. **No preview in context.** Nothing shows how the page will look; the in-play preview view (`CosmeticInPlayPreview`) exists and is never used.
7. **The strip copy is wrong**: `PAPER · 0 STAMPS`, `ASSET PENDING`, `Newsprint` with no explanation of what it changes.
8. **Deployment blockers.** `App/Resources/Shop3D/` holds **1.04 GB** of USDZ that XcodeGen bundles into the app (`sources: - path: App`): `ClubShopBoard` 117 MB, `ClubTurntable` 101 MB, three 100 MB grid meshes, ~20 board/box/frame variants of 6–48 MB that never render. The cabinet mesh alone is **3,075,538 triangles** (`model.tc39enls.usdc`, 94 MB) and is cloned three times, each with shadows, HDR, SSAO and MSAA on.
9. **Governance replaced design.** `docs/meshy-production/` (ledgers, reviews, 30 task briefs) and `docs/qa/club-shop-counter-rework-plan.md` describe a pipeline that blocks shipping until 72 Meshy digit meshes and 13 paper meshes exist and are independently approved. That pipeline produced the empty counter.

### 1.3 Root cause

Two decisions compound: (a) merchandise was modelled as generated 3D objects, which cannot represent a hairline rule weight or a typeface faithfully, and (b) a fail-closed registry made every item disappear until that impossible asset existed. Fixing tile placement would not fix the shop; the merchandise model itself has to change.

---

## 2. What top-tier cosmetic shops do — research, distilled into rules

The pattern is remarkably stable across genres. Game UI Database catalogues ~876 "change skin / accessory" screens with the same anatomy: **a preview area, an item grid, category tabs, an equip/buy action, and ownership indicators on the items** ([Game UI Database](https://www.gameuidatabase.com/index.php?scrn=20)). Puzzle and casual titles that are praised for their look (Good Sudoku, NYT Games, Alto's wardrobe) all preview the theme *on the thing it changes*, not on a swatch. Mobile shop UX guidance adds: let content peek past the edge so the player knows there is more, reduce friction to the unlock, and make the one primary action visually dominant ([UX Planet — game design UX best practices](https://uxplanet.org/game-design-ux-best-practices-guide-4a3078c32099)). Apple's HIG on in-app purchase asks for the price and what you get to be unambiguous before commitment, and its accessibility rules give the 44 pt target, VoiceOver values and Reduce Motion baseline ([Apple HIG — In-app purchase](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase)).

Rules the design must satisfy:

1. **Preview in context.** The hero shows the item on a real page, combined with what the player already wears.
2. **Persistent, tappable categories.** Swipe is a bonus, never the only route.
3. **State on the thumbnail.** Price / owned / in use readable on every item without selecting it; affordability distinguished without colour alone.
4. **One primary action** with a label that says what happens: `BUY · 40`, `EQUIP`, `IN USE`, `NEED 12 MORE`.
5. **Guard hard-earned currency.** 60 Stamps is a whole Book; a purchase is a deliberate two-press action, never a mis-tap.
6. **Buy = wear.** A purchase equips immediately and the shelf updates in place.
7. **Feedback on every action**: copy, haptic, and the balance ticking down.
8. **Accessibility is part of the design**: 44 pt targets, VoiceOver labels/values/hints, adjustable actions for browsing, Reduce Motion path, Dynamic Type in the strip.
9. **Stay in the material world** (design language §2, §5D, §10): a counter with samples in the club room — no cards, tab bars, glass or system sheets.

---

## 3. The design — "The Proofing Counter"

### 3.1 Concept

You walk to the counter (as today). On it: the sign plaque now names the three departments; a **proof sheet** — a real page, four turns into a puzzle, printed in the sample you are looking at — hangs in the hutch; the department's **samples stand in a row on the counter top**, each a small card of the material with a brass tag; at the foot, the **till strip** with the name, the blurb, the state and one button. Back and the Stamp balance stay in the corners like the rest of the room's chrome.

### 3.2 Layout, anchored to the cabinet

Positions are not screen offsets. When the camera settles, the scene projects four rectangles from the cabinet's own geometry (`ClubShopAnchors`: cabinet, sign plaque, hutch, counter) and the overlay lays itself out on them — so the samples sit on the counter on an SE, a 17 Pro and a Pro Max alike.

```
 ┌───────────────────────────────────────────────┐
 │ (‹ BACK)                        (● 5  STAMPS) │  chrome, safe area
 │                                               │
 │           ╔═══════════════════════╗           │
 │           ║  PAPER   GRID  NUMBERS ║           │  tabs on the sign plaque
 │           ║   the stock every page… ║          │
 │   ┌───────╨───────────────────────╨───────┐   │
 │   │  ┌─────────────────────────────────┐  │   │
 │   │  │ PUZZLE 4  EASY        Turn 3/10 │  │   │
 │   │  │ ┌──┬──┬──┬──┬──┬──┬──┬──┬──┐    │  │   │  proof sheet in the hutch
 │   │  │ │5 │3 │  │  │7 │  │  │  │  │    │  │   │  (real grid, given wash,
 │   │  │ │  ┆  ┆…                   │    │  │   │   selected + matches lit,
 │   │  │ └──┴──┴──┴──┴──┴──┴──┴──┴──┘    │  │   │   a cleared row, the hand)
 │   │  │ NUMBERS DRAWN      [3][6][9][2] │  │   │
 │   │  └─────────────────────────────────┘  │   │
 │   ├────────────────────────────────────────┤   │
 │   │ [▣] [▣] [▣] [▣] [▣] [▣] [▣] [▣] [▣] [▣]› │   │  sample rail on the counter
 │   │  40   ✓  IN USE 55  85  100 100 …      │   │  (tags: price / owned / in use)
 │   │              (drawer)                  │   │
 │   ┌────────────────────────────────────────┐   │
 │   │ Night Sky                   [BUY · 100]│   │  till strip, safe area
 │   │ A quiet sky. The grid is the constel…  │   │
 │   │ PAPER · 100 STAMPS                     │   │
 │   └────────────────────────────────────────┘   │
 └───────────────────────────────────────────────┘
```

**Sign plaque → department tabs.** `PAPER · GRID · NUMBERS` in gold serif small caps on the brass-framed plaque; the lit one carries a brass rule and a one-line note beneath ("The stock every page is printed on."). Tap to switch; swiping the hutch also switches, with the sheet following the finger a little before it commits.

**Hutch → proof sheet.** A sheet of the selected paper (grain, stock treatment, ivy/night/tide artwork where the stock has it) carrying a fixed sample puzzle: the same givens, the same placed numbers, one selected square with its matches lit, a row that has just cleared with its `LINE CLEAR +45` stamp, and the hand row with one lifted tile. It is rendered by `CosmeticGridRules`, `CosmeticNumberGlyph`, `PaperStockOverlay` and `PaperGrain` — the live renderers — with the player's *other* equipped items, so it shows exactly the page they would get. Animated finishes (Laser Grid pulse, Neon/Laser/Hot Type glow) run live. Changing the sample crossfades the sheet and replays the number's arrival motion; changing the department slides it along the counter. The sheet is laid out at a 264 × 240 reference and scaled by one unit so type stays crisp on every phone.

**Counter → sample rail.** One horizontally scrolling row of cards (≈52–62 pt) standing on the counter top in front of the drawer, five or six visible with the next peeking in. Paper cards show the stock with a ghost of the grid; grid cards show the rule on newsprint; number cards show `4 7` in the face. Each card has a tag: brass **price** (red pencil when you cannot afford it), a pencil **tick** when owned, a sage **IN USE** when equipped. The selected card lifts, scales 7 % and takes a gold rule. Cards are 44 pt+ buttons with VoiceOver labels ("Night Sky, Paper — 100 Stamps, not enough Stamps"). Samples are rendered on the starting loadout so the 13 papers, 7 rules and 8 faces stay comparable side by side; the proof sheet is where the player's own loadout applies.

**Till strip.** Name (Georgia), blurb, meta line (`PAPER · 100 STAMPS` / `OWNED` / `ON YOUR PAGE` / `YOURS`), and one button. VoiceOver can step samples from the strip with the adjustable action.

**Chrome.** `‹ BACK` capsule left, brass Stamp token + `5 STAMPS` right, both in the safe area. Toasts sit above the strip.

### 3.3 Interaction model

| Moment | What happens |
| --- | --- |
| Arrive | Camera walks in (unchanged). The merchandise fades in once the anchors are projected. Department opens on the sample you are wearing; each department remembers the last sample looked at. |
| Tap a tab / swipe the hutch | Sheet and rail slide to the department (fade only under Reduce Motion). Selection haptic. |
| Tap a sample | Card lifts, rail centres it, sheet reprints with it, strip updates. Selection haptic. |
| `BUY · 100` (affordable, unowned) | First press arms: button turns gold `CONFIRM · 100` with a 3.6 s countdown rule. Second press charges the ledger, equips, toast `WRAPPED AND READY`, success haptic, balance ticks down, the card's tag becomes `IN USE`. Moving to another sample, another department or leaving cancels the armed state. |
| `EQUIP` (owned) | Equips, toast `ON YOUR PAGE`, success haptic. |
| `IN USE` (equipped) | Disabled — owned is never a button, and the interesting action on something you wear is already done. |
| `NEED 35 MORE` (unaffordable) | Tappable; toast `FINISH A BOOK TO EARN 60 STAMPS`, warning haptic. Price tag on the card is red pencil, meta line is red pencil, so the state never rests on colour alone (it is also the wording). |
| Back | Cancels any armed purchase, camera walks out, anchors retire, merchandise fades. |

Every economic decision still goes through `PlayerProfileStore.purchase` / `.equip` — single charge, ownership persisted, equip-only-when-owned, cloud sync untouched.

### 3.4 Copy

| State | Card tag | Meta line | Button |
| --- | --- | --- | --- |
| Equipped | `IN USE` | `PAPER · ON YOUR PAGE` | `IN USE` (disabled) |
| Owned | ✓ | `PAPER · OWNED` | `EQUIP` |
| Default (free) | ✓ | `PAPER · YOURS` | `EQUIP` |
| Affordable | `100` brass | `PAPER · 100 STAMPS` | `BUY · 100` → `CONFIRM · 100` |
| Unaffordable | `100` red pencil | `PAPER · 100 STAMPS` (red) | `NEED 35 MORE` |

Toasts: `WRAPPED AND READY`, `ON YOUR PAGE`, `NOT ENOUGH STAMPS`, `FINISH A BOOK TO EARN 60 STAMPS`.

### 3.5 Motion (and its Reduce Motion path)

| Event | Motion | Reduce Motion |
| --- | --- | --- |
| Merchandise appears | 0.32 s fade after anchors land | 0.05 s |
| Department change | sheet + rail slide 0.36 s snappy in swipe direction | crossfade |
| Sample change | sheet crossfade 0.26 s + number arrival replay | instant, no arrival |
| Card select | lift 7 pt, scale 1.07, 0.22 s snappy | same (position change only) |
| Confirm window | 3.6 s linear countdown rule on the button | same |
| Balance change | numeric text roll | same |

### 3.6 Accessibility

44 pt targets throughout; tabs, cards, button and strip are labelled with value and hint; the strip exposes previous/next sample and the overlay exposes previous/next department as custom actions; the proof sheet is one described element; scenery is hidden; Dynamic Type scales the strip (stacked layout at accessibility sizes) while the anchored objects keep physical size; all state is carried by wording, tick, tag and rule as well as colour.

### 3.7 What this deliberately does not do

- No 3D merchandise, no baked thumbnails, no nameplates with invented names.
- No modal sheets, no system tab bar, no `List`.
- No new SF Symbols in player-facing UI (back chevron, tick and stamp token are drawn).
- No change to the catalogue, prices, rewards or the ledger.

---

## 4. Assets — what stays, what goes, and where Meshy fits

### 4.1 Keep (the room)

`ClubTurntable` (the cabinet), `MeshyShopLibraryLeft/Right`, `MeshyShopSideLamp`, `MeshyShopSideGlobe`, `MeshyShopPendant`, `MeshyShopPictureLight`, `MeshyShopHeaderPlaque` (now a blank sign carrying live tabs). Their materials, placement and the fixture-mounted light rig are unchanged.

### 4.2 Remove from the bundle (never rendered by the new counter)

`ClubShopBoard` (117 MB), `MeshyGoldenGrid` / `MeshyMidnightGrid` / `MeshyNeonGrid` (~100 MB each), all `MeshyShop*Edition`, `*V2`, `*V3` board tiles, `MeshyShopProductBox(V2)`, `MeshyShopDisplayShelf`, `MeshyShopFeaturedBoard`, `MeshyShopFeaturedFolio`, `MeshyShopCounterFacade`, `MeshyShopBoardFrame`, `MeshyShopBoardHardwareGrid`, `MeshyShopNameplate`, and the two registry JSONs. Roughly **870 MB** out of a 1.04 GB folder. Files move to `Artwork/Generated/Shop3D-retired/` (kept for provenance, out of the app target), not deleted.

### 4.3 Slim the cabinet

The cabinet is 3.08 M triangles with 2 K textures. Target: **≈80–120 k triangles**, same 2 K albedo/normal/roughness/metallic, re-exported as USDZ. Two routes: (a) local quadric decimation preserving UVs (pymeshlab) — free, deterministic, done in this session; (b) Meshy **Remesh** on the original task — costs credits, same outcome. Route (a) first; (b) only if the decimated normals show artefacts on the beadboard. Expected: bundle ≈ 170 MB → ≈ 60 MB, and a large drop in frame cost (one cabinet instead of three, a fraction of the geometry).

### 4.4 Why no Meshy merchandise, and the one optional Meshy piece

Generated 3D cannot represent what these products are: a 0.5 pt versus 1 pt hairline, a dashed blueprint rule, a serif versus a rounded digit, a neon glow that pulses. Meshy also cannot produce reliable lettering (the README's "generated type is always gibberish" was learned on this project). The honest, cheap and always-in-sync preview is the game's own renderer, which is why the design uses it. **Optional, on request:** a small brass **sample easel** for the turntable to hold the selected card as a physical object in the scene (one generation, ~20 credits). It is decoration, so it is not in the default scope.

---

## 5. Engineering plan

### Phase 0 — Build loop *(needs one command from you)*

I cannot type in your Terminal and my shell has no Xcode. `scripts/qa/harness.sh` watches `scripts/qa/queue/` and runs the build/screenshot jobs I drop there, writing logs to `scripts/qa/out/`. Start it once in your open Terminal:

```
bash ~/NumberClub/scripts/qa/harness.sh
```

It also removes the stale `.git/index.lock` left by a read-only `git status` through the mount.

### Phase 1 — Replace the merchandise *(written, not yet compiled)*

| File | Change |
| --- | --- |
| `App/Views/ClubShop/ClubShopChrome.swift` *(new)* | `ClubShopAnchors`, the shop inks, pressed style, department titles/notes. |
| `App/Views/ClubShop/ShopProofPage.swift` *(new)* | The proof sheet: header, `ShopProofBoard` (fixed sample puzzle on the live renderers), hand row, paper sheet, arrival replay. |
| `App/Views/ClubShop/ShopSampleCard.swift` *(new)* | Sample card + faces (`ShopPaperSwatch`, grid, digits), state tags, `PencilTick`, `ShopSampleRail`. |
| `App/Views/MainMenu/ClubShopOverlay.swift` *(rewritten)* | Anchored layout, tabs, hutch swipe, chrome, `ShopTillStrip` with the two-press buy, `StampToken`, `BackChevron`. |
| `App/Views/MainMenu/BookstoreOpeningView.swift` | Anchors state, per-department memory opening on the worn item, `selectShopItem`, `primaryShopAction` (arm → confirm), cancel paths, registry gate removed. |
| `App/Views/MainMenu/BookstoreSceneCoordinator.swift` | One cabinet instead of three; carousel, merchandise slots, board display, proof bay, nameplates, baked titles and shop gestures removed (~950 lines); `ShopCabinetLayout` fractions; `publishShopAnchors()` projecting the plaque node and cabinet front to screen; anchors retired on leaving. |
| `App/Views/MainMenu/BookstoreSceneState.swift` | Registries and `BookstoreShopPresentation` removed; phases/commands kept. |
| `App/Views/MainMenu/BookstoreSceneView.swift` | Bridge updated (`onShopAnchorsChanged`). |
| `AppTests/ShopCameraFramingTests.swift` | Suites for deleted types removed; camera framing, swipe-threshold and route tests kept. |

### Phase 2 — Build, calibrate, verify on three phones

1. `xcodegen generate`, build Debug for the `Club Shop QA iPhone 17 Pro` simulator, fix compile errors.
2. Launch with `-clubShop -grantClubCurrency 200` and `-clubShop -resetProfile`; screenshot each department; check the tabs sit on the plaque, the sheet in the hutch, the cards on the counter. Tune `ShopCabinetLayout` fractions from the screenshots, not by eye in code.
3. Repeat on iPhone SE (3rd gen) and iPhone 17 Pro Max; the anchors must hold without device branches.
4. Walk the flows in the simulator: arrive → tab → swipe → tap sample → buy (arm, cancel, confirm) → equip → back → re-enter (persisted state) → start a Book and confirm the page prints the purchase.
5. Reduce Motion on; VoiceOver rotor over tabs, cards, strip; Dynamic Type at accessibility sizes.

### Phase 3 — Bundle diet and performance

1. Move the unused USDZ out of `App/Resources/Shop3D/` (harness job; LFS-tracked files move with `git mv` once you decide how to commit).
2. Decimate `ClubTurntable` (pymeshlab, UV-preserving), rebuild the USDZ, drop it in, compare screenshots before/after.
3. Run with `-shopPerfHUD` on the 17 Pro simulator and, if possible, your phone: target 60 fps at the counter, no hitch on department change.
4. Measure the built `.app` size.

### Phase 4 — Polish

Screenshot review against the design-language checklist (§12 of `DESIGN_LANGUAGE.md`): material role, type voices, states without colour, Reduce Motion, no generic iOS assets. Adjust card size, tag legibility, sheet scale, strip spacing from what the captures show.

### Phase 5 — Tests, docs and policy reconciliation

- Unit tests: keep `ShopCameraFramingTests`, `ShopCounterCarouselTests`, `ClubShopRouteTests`; add `ShopSampleStateTests` (state → tag/button copy) and an anchors sanity test if the projection math is factored out.
- Delete the dead flat catalogue files (`ClubShopView`, `CosmeticCard`, `CosmeticInPlayPreview`, `CosmeticCurrencyBadge`); `CosmeticPreview` stays (Settings uses it).
- Update `DESIGN_LANGUAGE.md` §10 "Shops and cosmetics" and recapture `Artwork/DesignLanguage/club-shop.png`.
- `CLAUDE.md` / `AGENTS.md`: the "KAN-153 Meshy-only merchandise" section and the "no procedural … may substitute for an in-scope Meshy asset" invariant contradict this design. Proposed rewrite: *Meshy owns the room and its fixtures; page materials are rendered by the game's own renderers; no generated model may stand in for a catalogue item.* `docs/meshy-production/` and `docs/qa/club-shop-counter-rework-plan.md` get a one-paragraph "superseded" note at the top rather than deletion.

### Phase 6 — Deployment readiness (definition of done)

- [ ] Every one of the 28 items previewable, buyable (when affordable), equippable; balance and ownership correct after each action and after relaunch.
- [ ] Anchors correct on SE, 17 Pro, 17 Pro Max screenshots.
- [ ] 60 fps at the counter; no hang > 250 ms on entry or department change.
- [ ] `.app` under ~80 MB; no unused USDZ in the bundle; `strings` shows no debug-only shop copy in Release.
- [ ] Reduce Motion, VoiceOver, Dynamic Type passes recorded as screenshots.
- [ ] `swift test` in `Engine/` and the app test target green.
- [ ] Docs and policy files updated; working tree reviewed with you before any commit (the tree is on `main` and dirty with earlier work — I will not commit or branch without your say).

---

## 6. Verification matrix

| | iPhone SE (3rd) | iPhone 17 Pro | iPhone 17 Pro Max |
| --- | --- | --- | --- |
| Paper / Grid / Numbers arrival | ☐ | ☐ | ☐ |
| Anchors: tabs on plaque, sheet in hutch, cards on counter | ☐ | ☐ | ☐ |
| Buy (arm → confirm), cancel by moving, cancel by timeout | ☐ | ☐ | ☐ |
| Equip owned / IN USE disabled / NEED n MORE toast | ☐ | ☐ | ☐ |
| Night Sky on the sheet with each grid and face (contrast) | ☐ | ☐ | ☐ |
| Reduce Motion / VoiceOver / accessibility Dynamic Type | ☐ | ☐ | ☐ |
| Back → aisle → re-enter (state persists) → Play (page prints it) | ☐ | ☐ | ☐ |
| FPS with `-shopPerfHUD` | ☐ | ☐ | ☐ |

---

## 7. Decisions I need from you, and risks

1. **Retire the Meshy-only merchandise contract.** This plan removes the fail-closed registries and contradicts the KAN-153 clauses in `CLAUDE.md`/`AGENTS.md` and the contract at `/Users/daniel/meshy_club_shop_master_prompt.md` (outside the repo; I could not read it). The room stays Meshy; the products do not. I need your yes on that.
2. **Two-press purchase.** I recommend it (a Stamp costs a whole Book). If you would rather have one tap, it is a one-line change.
3. **Bundle diet moves LFS-tracked files.** Your git history keeps them; the app stops shipping them. Say if you would rather I only exclude them in `project.yml`.
4. **Optional Meshy easel** (§4.4) — yes/no.
5. **Risk — anchor projection.** If `projectPoint` disagrees with the overlay's coordinate space on some device, the fix is calibration in `ShopCabinetLayout`, and the screenshots in Phase 2 will show it immediately.
6. **Risk — the dirty tree.** Codex's uncommitted work on `main` is mixed with mine. I will list the exact files I touched at the end so you can stage them deliberately.

---

## 8. Status right now

Done on disk (uncompiled): the six overlay/scene files in Phase 1, the `BookstoreOpeningView` and coordinator edits, the trimmed test file, and `scripts/qa/harness.sh`. Not started: the build (blocked on Phase 0), calibration, the bundle diet, decimation (tooling is installed and the cabinet mesh has been measured), docs. Nothing has been committed.
