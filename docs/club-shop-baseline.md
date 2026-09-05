# Club Shop — one baseline: the 3D counter

**Decision:** the Club Shop is a physical 3D counter and nothing else. Every product is a Meshy model standing on the cabinet's shelves; picking one lifts it onto the turntable, where it turns slowly under the picture lights. The only flat things on screen are the room's chrome: Back, the Stamp balance, the department tabs on the sign plaque, and the till strip. No proof sheet in the hutch, no card rail, no baked thumbnails, no mix of 2D merchandise over 3D furniture.

**Why this one:** it is the direction you built, it uses the rendered assets and textures we already own (eight boards, cabinet, plaque, bookcases, lamp, globe, pendant, picture lights), and it is where the beautiful, smooth motion lives — the walk to the counter, the shelves sliding between departments, a board lifting off its shelf onto the platform. It is not too complicated: the shelf bay, the turntable bay, the fit-and-rotate code and the nameplates all exist in the repository already (commit `9d7f06e`, "rebuild board merchandising and lighting") and only need to be put back and extended. What is new is twenty-one Meshy objects for Paper and Numbers, made with the same pipeline that made the boards.

**The plain alternative** — a paper sheet listing the items with prices, no 3D, no preview — is what the flat catalogue in `ClubShopView` used to be. It is cheaper and honest, and it is not what this game is. Not chosen.

---

## 1. The counter, department by department

Same cabinet, same camera, same walk-in. Each department fills the same shelves:

| | Objects on the shelves | Where from |
| --- | --- | --- |
| **Board** | Classic, Scribes, Midnight, Botanica, Stargazer, Golden, Neon, Porcelain — the eight USDZ boards with their 4K PBR maps | `App/Resources/Shop3D/MeshyShop*.usdz`, already bundled |
| **Paper** | thirteen paper objects (a short ream / open folio of each stock) | generated with Meshy from `Artwork/References/Meshy/Paper/pp_*-shop-multiview-reference-v1.png` |
| **Numbers** | eight type objects, each carrying a 7: press block, typewriter slug, pencil card, wood type, stencil plate, neon tube, laser-cut plate, hot-metal sort | generated with Meshy, base-then-retexture, one silhouette family |

Layout inside the hutch, from the measured cabinet (not screen guesses): **upper shelf row** and **lower shelf row** in the merchandise bay; the **turntable** on the counter top is the proof bay. Board and Numbers: 4 + 4. Paper: 5 + 5 + 3 on a third rail at the back, or two rows that scroll together behind the uprights — choose after measuring the hutch depth. Nothing is placed outside the uprights; nothing overlaps the drawer.

Under every object: a small brass **shelf tag** — the price, a pencil tick when owned, `IN USE` when equipped. Above the shelves nothing but the plaque. Names appear in the strip and on the nameplate under the selected object only, so the shelf stays a shelf and not a label wall.

## 2. Picking, previewing, buying — the motion

- **Tap an object** (or its 44 pt invisible SwiftUI hit target at the projected position): it lifts off the shelf, drifts down to the turntable and settles; the turntable begins its slow ±0.32 rad sweep (existing `ShopProofBayLayout` fit and yaw code). The previous object floats back to its shelf. The strip prints its name, blurb, state and the one action. Selection haptic.
- **Tab or swipe the hutch**: the shelves slide sideways as a unit behind the uprights and the next department's shelves slide in (SceneKit action on the merchandise bay root, 0.36 s ease). The turntable keeps the department's remembered selection. Reduce Motion: crossfade.
- **Buy**: two presses (`BUY · 100` → `CONFIRM · 100`, 3.6 s window). On confirm: success haptic, the balance ticks down, the shelf tag flips to `IN USE`, a brass `SOLD` chit drops onto the turntable for a second, toast `WRAPPED AND READY`.
- **Equip owned**: one press; tag flips to `IN USE`, toast `ON YOUR PAGE`.
- **See it on the page** *(secondary, optional)*: long-press the turntable or tap `ON THE PAGE` in the strip to lay a paper slip on the desk with the game's own page rendered in that treatment (the slip is a club-room object, like Settings). It is a detail view, not part of the counter composition, and the counter never depends on it.

## 3. What each object promises, and how the page keeps it

The shelf sells an object; the page shows its treatment. Boards: each in-game board skin is tuned to its board (Midnight dark and cool, Porcelain ivory with cobalt rules, Golden warm brass), so the page reads as the board you bought. Paper: the object is the stock the page prints on. Numbers: the object is the face the page sets its digits in. Names are identical everywhere: shelf nameplate, tag, strip, VoiceOver, page.

## 4. Work, in order

1. **Rename.** `Grid` → `Board` on the plaque, the strip, VoiceOver and in `CosmeticCategory.title` / `counterTitle` (both already changed in the tree; the build in the screenshot predates them).
2. **Remove the mix.** Delete the proof sheet and the card rail from `ClubShopOverlay` (`ShopProofPage`, `ShopSampleCard`, `ShopSampleRail`); keep tabs, back, balance, till strip, toasts and the hutch swipe. Add invisible hit targets fed by the coordinator's projected object rects.
3. **Restore the 3D bays** from commit `9d7f06e` into the single-cabinet coordinator: `installMerchandiseSlots`, `installProofBay`, `refreshShopProofBay`, `updateShopProofBayMotion`, `fitShopProduct`, `ShopProofBayLayout`, `ShopMerchandiseLayout`, the nameplate maker — without the three-cabinet carousel and without the fail-closed registries. Slot geometry from the measured cabinet (D1 in the steering notes).
4. **Boards on the shelves** with the catalogue mapping (D0): eight objects, uniform height, shelf tags, selected object on the turntable.
5. **Generate Paper and Numbers** with the existing pipeline scripts (`scripts/gen-shop-board-collection.mjs` base task → `scripts/retexture-shop-board-collection.mjs` per item), preserved outputs and manifests, thumbnails reviewed, only clean digits accepted. Bundle the accepted objects; decimate/size them like the boards.
6. **Shelf-to-turntable motion**, department slide, purchase chit, haptics, Reduce Motion path.
7. **Optional page slip** (§2) if wanted.
8. **Verify** on SE, 17 Pro, Pro Max: nothing outside the uprights, every object shadowed on its shelf, all flows, 60 fps with `-shopPerfHUD`, bundle size.

## 5. Guardrails for anyone touching the tree

- Shelf merchandise is a Meshy model. Never a card, a baked thumbnail or a SwiftUI drawing.
- The turntable always holds the selected object; it is the preview.
- Flat UI is chrome only: Back, balance, tabs, strip, toasts, hit targets, and the optional page slip.
- One cabinet, one camera pose, objects inside the uprights, nothing over the drawer.
- `AGENTS.md` must say this, not "merchandise is renderer-based".
