# Club Shop — getting to the mockup ("Board Collection")

**Target:** the frontal cabinet mockup — three green tab plaques, a `BOARD COLLECTION · balance` strip, a 3-wide grid of boards with brass price plates, a gold frame + `EQUIPPED` ribbon on the one in use, a green-leather detail panel with the selected board large on the left and the name, divider and a big brass-framed button on the right, drawer below, back button bottom-left.

**The one thing to understand about the mockup:** it is a *frontal* picture. Every surface is a rectangle, everything sits on a grid, and the "3D" is in the materials — walnut grain, leather, brass bevels, the lit boards — not in perspective. That is what makes it look composed. Our current counter is viewed from above-left at an angle, so nothing lines up and every flat thing over it looks pasted. The way to get the mockup is not a different shop; it is **the same cabinet, seen straight on, with the grid and panels laid out on its real surfaces.**

This is still one baseline, not a mix: the 3D scene owns everything that is an *object* (room, cabinet, the boards, the big preview board), and one furniture-styled UI layer owns everything that is *print* (tabs, title strip, price plates, badges, ribbon, panel text, button). Seen frontally, the two align to the pixel, and both are drawn in the same materials — walnut, bottle green, brass, gold serif — so there is no visible seam. The mockup itself is exactly this: lit objects plus printed furniture.

---

## 1. Mockup → cabinet, zone by zone

| Mockup element | Where it lives on our cabinet | Layer |
| --- | --- | --- |
| Three tab plaques `PAPER · BOARD · NUMBERS` | the black panel across the top of the hutch (the strip above the brass sign) | UI: three green-leather plaques with brass rims, gold serif, the active one brighter with a brass rule |
| `BOARD COLLECTION` strip with the stamp balance | the brass-framed sign plaque (`MeshyShopHeaderPlaque`) | UI: gold small-caps title left, stamp glyph + `340` in a dark inset right |
| Grid of boards, 3 across | the hutch, boards mounted flat on the beadboard in 3 columns (Board 3+3+2, Numbers 3+3+2, Paper 3+3+3+3+1 scrolling vertically behind the cornice/counter edge) | 3D: the Meshy boards, uniform height, real light and shadow |
| Brass price plate under each board (`FREE`, `40`, `65`…) with stamp glyph | 24 pt below each board, centred | UI: brass plate, dark engraved numerals; the plate is the tap target too (44 pt) |
| Green check badge (owned), gold frame + `EQUIPPED` ribbon (in use), gold glow frame (selected) | on the board's projected rect: badge top-right, ribbon across the bottom edge, frame around | UI, anchored to projected rects |
| Green leather detail panel with brass corners | the lower cabinet: the door (already bottle-green leather with a brass rim) plus the drawer face above it, treated as one panel | 3D door as the material; UI draws the brass corner ornaments and the inset |
| Selected board, large, left of the panel | floating 6 mm in front of the door's left half, rocking slowly ±6° | 3D: a clone of the selected board (replaces the turntable as the preview stage) |
| Name, stars, divider, big button | right half of the panel | UI: gold serif name; the stars become the item's blurb line (we have no rarity — see §6); ornament divider; brass-framed green button `EQUIPPED` / `EQUIP` / `BUY · 40` / `CONFIRM · 40` / `NEED 12 MORE` |
| Drawer with cup pull | the cabinet's drawer, untouched | 3D |
| Back arrow, gold circle bottom-left | safe-area chrome | UI |
| Reroll chip `⟳ 10` | **dropped** — the Club Shop has no rerolls; that is the in-run shop's mechanic | — |

## 2. Camera: straight on

Put the shop pose on the cabinet's front axis: camera at the cabinet's mid-height, looking horizontally at the cabinet's centre (no pitch), vertical FOV **30°**, far enough back that the cabinet fills ~92 % of the screen width on a 402-pt phone (≈6.7 scene units for our 1.64-unit-wide cabinet; derive it from the measured bounds, not a constant). The walk-in from the aisle ends on this pose. Because the view is frontal, `projectPoint` of any cabinet rectangle is a rectangle, and the UI layer lays out from those rects exactly. Keep the pendant, picture lights and bookcases: they are what makes the frontal view still read as a room and not a poster.

Short phones widen the FOV only vertically (existing `ShopCameraFraming` logic); the grid scrolls, so nothing has to shrink below legibility.

## 3. Grid geometry (from the measured cabinet, D1)

- Inner hutch width `W` between the uprights; column pitch `W / 3`; board width `0.78 × pitch`; row pitch = board height + plate height + 3 gaps.
- Boards mounted 4 mm proud of the beadboard, bottoms on invisible rails so the shadow lands where a shelf would be.
- The grid root sits inside the hutch volume; scrolling moves the root; the cornice and the counter edge occlude what leaves the opening — no clipping code.
- Selected board: +2 mm forward, gold frame (UI) with a soft 1.2 s glow pulse; Reduce Motion: static frame.

## 4. Print styles (the UI layer)

One family, drawn once as SwiftUI shapes and reused: **brass plate** (linear brass gradient, 1 pt dark rim, 1 pt inner highlight, engraved dark text with a 0.5 pt light offset), **green leather plaque** (bottle-green with grain noise, brass rim, gold text with a dark drop shadow), **gold serif** (Georgia Bold, tracked +1.5 for small caps), **stamp glyph** (a perforated square with a small crest, drawn as a path — the currency token everywhere), **ornament divider** (a hairline with a small brass knot). No greys, no system fonts in print, no glass.

## 5. States

| State | On the grid | On the panel |
| --- | --- | --- |
| Not owned, affordable | brass plate `stamp 40` | `BUY · 40` → `CONFIRM · 40` (3.6 s) |
| Not owned, short | brass plate `stamp 40`, numerals in red pencil | `NEED 12 MORE`, tap = toast `FINISH A BOOK TO EARN 60 STAMPS` |
| Owned | green check badge top-right, plate `stamp 40` dimmed | `EQUIP` |
| Equipped | gold frame + `EQUIPPED` ribbon, check badge | `EQUIPPED` (disabled, brass) |
| Default (free) | plate `FREE` | `EQUIP` / `EQUIPPED` |
| Selected | gold glow frame | the board clone on the panel, name and copy |

## 6. Copy

Name in gold serif from the catalogue (Classic, Scribes, Midnight, Botanica, Stargazer, Golden, Neon, Porcelain). Under it, instead of the stars, the item's blurb in paper italic (`Lunar Obsidian.`), or — if you want the stars — a five-step price tier (0–40 ★, 41–65 ★★, 66–90 ★★★, 91–110 ★★★★, 111+ ★★★★★). I'd take the blurb; stars imply a rarity system the game does not have.

## 7. Motion

Walk-in ends frontal; the grid fades up 0.3 s after arrival. Tab: the grid slides sideways behind the uprights (0.36 s), the panel board crossfades. Tap a board: gold frame snaps on, the panel board swaps with a 0.25 s crossfade and a small settle, selection haptic. Confirm purchase: ribbon unrolls across the board, check badge pops, balance rolls down, toast, success haptic. Reduce Motion: fades only.

## 8. What has to be built or generated

- **Camera + layout**: the frontal pose and the grid/panel anchors (coordinator), the UI layer (SwiftUI) — code only.
- **Boards**: the eight existing USDZ boards — nothing new. Decimate/size like the cabinet if frame time needs it.
- **Numbers**: eight Meshy type objects (7 on each), generated with the board pipeline; mounted in the same grid.
- **Paper**: thirteen objects. In a frontal grid a paper object is a sheet; generate the Meshy folio set from the prepared references for consistency of light and shadow, or mount real stock renders as sheets if the generations disappoint — decide on the first three results.
- **No new fixtures**: tab plaques, price plates, ribbon, badges, panel ornaments and the button are print, drawn in code, matching the header plaque and the door we already have.

## 9. Order of work

1. Frontal camera and the measured anchors (grid columns, plate row, panel halves). Screenshot: an empty cabinet, straight on, filling the width.
2. Board grid: eight boards mounted, uniform, shadowed; price plates; check/ribbon/frame; the preview clone on the door.
3. Tabs and the title strip; back button; department slide.
4. Purchase/equip flow on the panel; toasts; haptics.
5. Numbers and Paper generation with the pipeline; mount; vertical scroll for Paper.
6. Three-phone pass, Reduce Motion, VoiceOver (each plate is the board's accessible element: "Midnight, Board, 55 Stamps, owned").
