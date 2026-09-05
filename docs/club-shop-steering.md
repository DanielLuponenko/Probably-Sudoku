# Club Shop — steering notes after build 1

**What this is:** a blunt read of the first build of the proofing counter (screenshot: Paper department, iPhone 17 Pro, 200 Stamps), what is wrong with it, the corrected direction, and numbered directives with acceptance checks. Written so it can be executed by me or handed to any agent working on `App/Views/ClubShop/*`, `App/Views/MainMenu/ClubShopOverlay.swift` and `BookstoreSceneCoordinator.swift`.

---

## 1. What build 1 proved

Worth keeping, because it works: all 28 items are reachable and honest (every sample and the proof are drawn by the game's own renderers); the departments are tappable tabs on the sign plaque and the selected one lights; state reads on every item (`IN USE`, ✓, price); the till strip carries name, blurb, state and one button; ownership, balance and the economy behaved. The cabinet, backdrop and lighting look right. The plan's *content* decisions are correct. The **composition** is not.

## 2. What is wrong, in order of damage

1. **The proof sheet is a cream rectangle pasted over the cabinet.** It covers the beadboard, the whole middle shelf rail and the lower opening, and stops just short of the counter top. Nothing about it is physical: no frame, no fixing, no perspective, no shadow onto the wood. The most beautiful part of the cabinet — its interior — is hidden by a flat card. This one item is why the screen reads as "UI stickers on a 3D render".
2. **The samples float over the drawer, not on the counter.** The row sits low, across the drawer face and its brass pull, with the price tags on the drawer. Cards spill past the cabinet's left edge over the bookcase. No contact shadow, no surface — they read as a toolbar, not as things standing on a counter.
3. **The paper samples are indistinguishable.** Newsprint, Fresh White, Ivory Laid, Manila, Ledger Blue and Graph are six near-identical off-white squares with a faint 3 × 3 ghost. The stock treatments are scaled down 5× and vanish. A shelf of identical cards is a shelf of nothing.
4. **The tabs fail their job.** `GRID` and `NUMBERS` are dim gold on bottle green at ~40 % opacity — invisible against the lit brass frame; `NUMBERS` is clipped by the frame; the italic note under them prints across the plaque's lower frame and is unreadable. And the department is called Board, not Grid — the eight board assets you made are the products, and build 1 wrongly left them off the shelf (D0).
5. **The composition is top-heavy.** Everything is crammed into the hutch and the counter; the drawer and the large lower door (a third of the cabinet) are dead. The eye has nowhere to rest and nothing at the bottom to hold it except the strip.
6. **Flat light.** The cabinet is lit warm from the picture lights and falls off toward the floor; every overlay element is evenly lit and colour-neutral, so even where it sits correctly it does not belong to the room.
7. **Small faults:** the `LINE CLEAR +45` stamp hides a cell and reads as a tooltip; the rail did not start with the selected card inside the cabinet; the sheet's hand tiles are large relative to the board; the strip is taller than it needs to be.

## 3. The correction: Meshy objects on the shelves, the renderer on the proof print, controls in the overlay

The overlay approach was right for what must be crisp, live and accessible — tabs, back, balance, the strip — and wrong for the merchandise. The merchandise is **physical stock on a physical counter**, and we already have it rendered: eight Meshy boards with 4K PBR maps (`MeshyShopClassicV3`, `…ScribesEdition`, `…MidnightV3`, `…BotanicaEdition`, `…StargazerEdition`, `…GoldenV3`, `…NeonV3`, `…PorcelainV2`) sitting in `App/Resources/Shop3D/`, plus the cabinet, plaque, bookcases, lamp, globe, pendant and picture lights. Build 1 hid the boards behind baked cards. That was wrong and it is reversed: **every sample on the shelf is a Meshy model**, lit by the picture lights, casting contact shadows, occluded by the uprights, in the cabinet's perspective — the presentation the Board department already had in `Artwork/Generated/MeshyShopCounterFacade/R1/runtime-final-no-hud.png`.

Three layers, each doing the one thing it is good at:

1. **SceneKit — the objects.** Board: the eight existing USDZ boards. Paper: thirteen Meshy paper objects. Numbers: eight Meshy type objects. Paper and Numbers do not exist yet and are generated with Meshy (credits authorised) through the retexture pipeline the boards already used (`scripts/gen-shop-board-collection.mjs`, `scripts/retexture-shop-board-collection.mjs`: one base mesh, one retexture per item, preserved provider output, manifest, thumbnail). Codex's thirteen paper multiview reference sheets in `Artwork/References/Meshy/Paper/` are the inputs for the paper set.
2. **SwiftUI on the counter — the truth.** The proof print in the hutch is still the game's own renderer, because it is the only thing that can show *the page you will get*; it becomes a framed specimen (D2) instead of a full sheet. Tabs, back, balance and the till stay in SwiftUI, with invisible 44 pt hit targets at the projected positions of the objects so taps and VoiceOver work on 3D merchandise.
3. **The page — the same object.** What the shelf sells, the puzzle page shows: each in-game board skin is derived from its Meshy board (D0), so buying Midnight puts Midnight under the numbers.

`AGENTS.md` was rewritten this morning to say merchandise is "deliberately renderer-based … do not substitute 3D product tiles". That contradicts this direction and must be corrected to: *shelf merchandise is Meshy models; the proof print is the renderer; nothing on the shelf may be a baked thumbnail or a card.* The rest of that file (composition, invariants, 44 pt, two-press buy, no obsolete meshes in the bundle) stands.

## 4. Directives

### D0 — Use the board assets that already exist, and call them boards
The eight Meshy boards in `App/Resources/Shop3D/` (`MeshyShopClassicV3`, `…StargazerEdition`, `…BotanicaEdition`, `…ScribesEdition`, `…MidnightV3`, `…GoldenV3`, `…NeonV3`, `…PorcelainV2`) are the Board department's samples. They go back on the hutch shelves as the physical objects they are — that is what they were made for and it looked right. Build 1 replaced them with baked cards because their names did not match the catalogue; the fix is to unify the names, not to hide the assets. The department is **Board**, never "Grid", on the plaque, in the strip, in VoiceOver and in code copy (`counterTitle` already changed).

Mapping and naming (catalogue IDs unchanged so saves and cloud profiles keep working):

| Catalogue ID | Board on the shelf | New catalogue name | In-game rule (unchanged) |
| --- | --- | --- | --- |
| `bd_printed` | Classic · Ivory & Brass | **Classic** | printed hairlines, heavy box lines |
| `bd_fine` | Scribes · Manuscript | **Scribes** | fine rule |
| `bd_heavy` | Midnight · Lunar Obsidian | **Midnight** | heavy black rule |
| `bd_sage` | Botanica · Bottle Green | **Botanica** | club-green rule |
| `bd_blueprint` | Stargazer · Midnight Blue | **Stargazer** | blue drafting dashes |
| `bd_gilt` | Golden · Botanical Brass | **Golden** | brass rule |
| `bd_laser` | Neon · Malachite Inlay | **Neon** | cyan glowing rule |
| `bd_porcelain` *(new)* | Porcelain · Cobalt & Ivory | **Porcelain** | new: cobalt rule on ivory washes |

Porcelain becomes the eighth board skin so every asset is sold: a `BoardSkin` with cobalt hair/bold lines and ivory `given`/`selected`/`sameNumber` washes, priced with the others. The subtitles (`Ivory & Brass`, `Lunar Obsidian`…) become the items' blurbs so the shelf label and the strip agree. One honest caveat to design around, not away: the tile is the object you buy, the page shows its rule — so each board's in-game washes should be tuned to echo its tile (Midnight's washes a shade darker and cooler, Porcelain's ivory, Golden's warm), so buying Midnight *feels* like Midnight on the page. The proof print (D2) shows exactly that page, which is what makes the tile-to-page relationship trustworthy.
*Accept:* eight boards on the Board shelves, each mapped to one catalogue item, names identical on shelf, strip and page; Porcelain buyable and rendering on the live grid.

### D1 — Measure the cabinet, stop guessing fractions
Derive the counter's surfaces from the mesh, not from `0.485` and `0.66` read off screenshots. Load `ClubTurntable`, collect upward-facing faces (normal · +Y > 0.9), histogram their heights: the peaks are the counter top, the lower shelf, the upper shelf/rail and the cornice. Write them into `ShopCabinetLayout` as **named surfaces with heights and front depths** (`counterTop`, `lowerShelf`, `middleRail`, `signPlaque`), each with its usable inner width (distance between the uprights). Everything below positions from these.
*Accept:* a debug overlay (`-shopAnchorsHUD`) draws the projected surfaces and they coincide with the wood in screenshots on SE, 17 Pro, 17 Pro Max.

### D2 — The proof print: a framed specimen in the upper opening
Hang the proof **between the plaque and the middle rail only**, never over the rail. Frame it: 3 % walnut frame, 6 % dark-green matte, brass corner tabs, a 2 px paper edge, a soft shadow onto the beadboard. Size it to 74 % of the inner hutch width. Because the opening is short, the print is a **specimen, not a whole board**: one large 3 × 3 box of the page (cells ≈ 34 pt at 17 Pro size) showing a given, a placed number, the selected square with its matches lit and the finish glowing, with the four hand tiles under it and the page furniture (`PUZZLE 4 · EASY · Turn 3/10`) as a small printed header. The specimen sits on the full paper stock, so illustrated papers show their ivy/night/tide border on the print's edges. Tapping the print opens the full page (`CosmeticInPlayPreview`, restyled as a paper slip on the desk) for anyone who wants to see the whole thing — the standard "tap to look closer".
*Accept:* rail visible below the print; digits ≥ 16 pt at 17 Pro size; the print's shadow lands on the beadboard; Night Sky, Garden and Ocean borders visible on the print.

### D3 — The samples: Meshy models on the shelves, inside the cabinet
Every department's samples stand **on the hutch shelves** (upper shelf and lower shelf, two rows, as the Board department already did), bottoms on the shelf surface, contact shadows, evenly spaced, and **clipped by the uprights** — the rows scroll sideways behind the wood when a department has more samples than fit (Paper: 13 → 5 + 5 + 3 becomes two rows that scroll together). Price/owned/in-use tags are small brass-rimmed shelf tags on the shelf lip under each sample. The drawer, its pull and the turntable stay clear (see D6). On arrival the rows are scrolled so the selected sample is fully inside the opening. The selected sample lifts a few millimetres off its shelf and catches the light.

Per department, the object on the shelf is:
- **Board:** the eight existing boards (D0). No change to the meshes; placement from D1's measured shelves, uniform scale, all eight the same height. Restore the shelf/nameplate composition from `runtime-final-no-hud.png`; the nameplates carry the catalogue name (the same name the strip shows), not a second invented name.
- **Paper:** thirteen Meshy paper objects — a short ream / open folio of each stock — generated from the prepared multiview sheets (`Artwork/References/Meshy/Paper/pp_*-shop-multiview-reference-v1.png`, thirteen of them) with the existing pipeline: one base object (`gen-shop-board-collection.mjs`-style base task), then one retexture per stock with its reference sheet as the style image, thumbnail and manifest preserved. Accept a paper object only if the stock is recognisable at 50 pt on the shelf (Garden's ivy, Night Sky's dark blue, Graph's grid, Ledger's rules, Utility Roll's cylinder); regenerate the ones that are not.
- **Numbers:** eight Meshy type objects — one per face: press type block (Press), typewriter slug (Typewriter), pencil-lettered card (Pencil), wood type (Handset), stencil plate (Stencil), neon tube (Neon Sign), laser-cut plate (Laser Cut), hot-metal sort (Hot Type) — each carrying a **7**. Generate from text with the board pipeline's base-then-retexture approach so all eight share one silhouette family. Meshy lettering is unreliable: accept only a clean, unmistakable 7; on failure, retexture with the digit supplied as an image reference, or regenerate. No object ships with a garbled digit.
*Accept:* no sample pixel outside the uprights; every object's shadow touches its shelf; the drawer and pull unobstructed; every paper and every face recognisable without its name; all objects share the scale and lighting of the boards.

### D4 — One truth for names, tags, print and page
The shelf nameplate, the shelf tag, the till strip, VoiceOver and the page use the catalogue item's name and nothing else. The proof print in the hutch shows the page with the selected object's skin (D2); the turntable shows the selected object itself (D6). Board skins on the page are derived from the boards (D0). Paper on the page is the stock the object represents; number faces on the page are the fonts the type objects represent.
*Accept:* for any item, a screenshot of shelf + strip + print + a live page shows the same name and the same material.

### D5 — Tabs that read
All three labels at full gold; the selected one brighter with the brass rule and a 2 pt darker plaque wash behind the unselected ones, so hierarchy comes from light, not from fading text into the green. Text size fitted so `NUMBERS` clears the frame with 12 pt of air. Drop the italic note from the plaque; the department note moves into the strip's meta line on arrival (`PAPER — the stock every page is printed on`) and is replaced by the item's meta once a sample is tapped.
*Accept:* all three tab labels legible in a screenshot at 50 % scale; nothing overlaps the frame.

### D6 — Give the counter top a job and the lower cabinet a purpose
The turntable holds the **selected sample as a physical card** (the same bake, on a small brass easel plane) turning slowly; tapping it is the same as tapping the strip's button. The lower door stays cabinet — that is what a cabinet looks like — but the **till strip sits on the plinth** in front of it, narrower and shorter (name + one line + button, ~64 pt), so the door reads as furniture with the till in front of it rather than dead space with a floating bar below.
*Accept:* the vertical rhythm reads plaque → print → samples → counter object → till, with the door visible between samples and till.

### D7 — Light the overlay like the room
For everything that stays in SwiftUI (tabs, strip, the framed print; hit targets are invisible anyway): a warm brass tint of 5–7 % at the top of the strip and plaque text shadows in the room's shadow colour. The Meshy objects need nothing — the picture lights and the fixture rig light them. Remove neutral greys from the shop inks; every colour is paper, brass, walnut, bottle green, sage or red pencil.
*Accept:* no overlay element is colder or flatter than the wood around it in a screenshot.

### D8 — Fix the small faults
`LINE CLEAR +45` moves to the row's right margin outside the box; hand tiles at 22 pt; strip padding 8/12; on entering a department the selected card is scrolled into view without animation.

### D9 — Verify like a shopper, on three phones
For each department: arrive; tab; swipe; tap three samples; buy one (arm → confirm), cancel one by moving; equip an owned one; back; re-enter; start a Book and confirm the page prints what was bought. Capture SE, 17 Pro, Pro Max at each step. Reduce Motion on for one full pass; VoiceOver rotor over tabs → print → cards → strip.

## 5. Order of work

1. D0 (board names unified, Porcelain added) and D1 (surfaces from the mesh) — everything else positions from these.
2. D3 for Board (the eight existing boards back on the measured shelves) — immediate, no new assets.
3. D3 for Paper and Numbers: generate the thirteen paper objects and the eight type objects with the existing Meshy pipeline; place them exactly like the boards.
4. D2 (framed specimen print).
5. D5, D6, D7, D8 in one polish pass.
6. D9 and the bundle diet / cabinet decimation from the main plan (the eight boards and the two new objects stay in the bundle; the ~20 unused board variants, frames, boxes and 100 MB grids still go).

## 6. What I need from you

- Keep building the way you built this one, or start the runner (`bash ~/NumberClub/scripts/qa/harness.sh`) so I can build and screenshot myself between each directive. The runner is the difference between one round-trip per fix and one per hour.
- Decide D2's "tap the print to see the whole page": yes (recommended) or keep the full board on the print at the cost of tiny digits.
- Decide D6's easel: a small Meshy generation (brass card easel, ~20 credits) or a drawn plane.
- Meshy: the generations for Paper (13) and Numbers (8) need `MESHY_API_KEY` in the environment where the pipeline scripts run; it is not on this machine. Say where it lives, or run the pipeline scripts from the runner's shell where the key is set.
- Correct `AGENTS.md` (see §3) so that no agent working the tree treats the boards as "unrelated product tiles" again.
