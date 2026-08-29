# Club Shop visual and interaction invariants

Status: `LOCKED_VISUAL_FLOOR_PENDING_IMPLEMENTATION`

Authority: direct user instruction dated 2026-08-29, the two approved
`bookstore-aisle` references in `REFERENCE_INDEX.md`, and CONTRACT-001. The
mockups are the floor, not a loose inspiration. “Better” means greater physical
depth, material fidelity, lighting, shadow quality, catalog clarity,
accessibility, and runtime polish while preserving the approved bookstore
identity. It does not authorize a different theme or a generic storefront.

## 0. Opening-to-store continuous retail flow

This interaction is the primary product experience and a hard release gate:

- Tapping `SHOP` starts one uninterrupted cinematic camera move from the
  opening bookstore composition directly to the physical merchandise stand.
  The opening controls fade during travel. There is no cut, view replacement,
  second canvas, loading interstitial, or flat shop screen.
- The opening and the store are two camera compositions inside the same live
  3D bookstore world. Lighting, room geometry, products, shadows, and state
  remain continuous throughout the move.
- The store stand is the complete retail interface. Browsing, selection,
  inspection, buying, and equipping all happen through physical merchandise,
  tags, plaques, lamps, controls, and mechanisms on that stand. A generic card
  list, popup storefront, or release-reachable `ClubShopView` fails.
- In the active category, every product is simultaneously physically visible
  across the stand and individually selectable: all 13 Paper products, all 7
  Grid products, or all 8 Number style products. No carousel virtualization,
  clipping, paging, end marker, or selected-plus-neighbors shortcut may hide
  any active-category product. The selected Number style additionally displays
  digits 1–9 together at inspection scale.
- Selection mechanically brings the chosen product to the central lit,
  shadowed, rotating proofing platform while the complete active-category
  assortment remains visible across the stand.
- A successful `BUY` first confirms persistence of one atomic balance/ownership
  transaction, then presses a physical brass stamp onto that product's vellum
  price tag. Stamp contact reveals the already-persisted exact-once balance
  decrement and changes the same tag to `OWNED`, with impact sound/haptic at
  contact. Before confirmed persistence the stamp remains at rest; insufficient
  funds or failed persistence must never show stamp contact, impact feedback,
  decrement, or owned state.
- `EQUIP` mechanically slides or rotates the owned product into the central
  proofing position, brightens the proofing lamp, and changes the brass plaque
  to `EQUIPPED`. The previously equipped product returns to its deterministic
  stand position. The equipped state and selection persist.
- `BACK` reverses the same camera path into the opening composition while the
  shop controls fade and the opening controls return. The selected category
  and product are preserved when the player enters the shop again.
- The explicit state machine is `opening → enteringShop → shopping →
  purchasing/equipping → shopping → exitingShop → opening`. Transition and
  transaction input must be gated so repeated taps, interruption, cancellation,
  backgrounding, or persistence failure cannot double-charge, strand the
  camera, or display contradictory physical state.
- Reduce Motion may shorten or directly interpolate the same spatial camera
  path and replace impact motion with restrained state changes, but it may not
  switch to a different view, flatten the shop, hide merchandise, or remove
  purchase/equip feedback.

## 1. Continuous 3D room

- The shop remains a single navigable bookstore room rather than a full-screen
  flat product list or a stack of unrelated cards.
- The camera must show a foreground proofing counter, selected merchandise in
  the middle depth plane, and shelves/walls/signage behind it. At least three
  visually separable depth planes must be visible in every required viewport.
- Perspective, occlusion, material response, and lighting must make the scene
  read as physical 3D. A rendered still, CSS-like parallax, or billboard-only
  scene does not pass.
- Walnut, bottle green, aged brass, warm paper/vellum, and restrained warm
  theatrical lighting remain the dominant material/color family.
- In-scope room, fixture, display, and merchandise geometry must satisfy the
  Meshy-lineage and provenance gates. Dynamic localized text and narrowly
  allowlisted functional overlays do not become merchandise art.

## 2. Lighting, shadow, and focus

- Every merchandise object resting on a counter, shelf, stand, or turntable
  has a stable contact shadow; visibly floating objects fail.
- The selected item has the strongest local proofing light and readable
  silhouette without clipping highlights or crushing its material detail.
- Selected, neighboring, and background objects must cast/receive coherent
  shadows under the same scene lighting. Painted-on generic blob shadows fail.
- Category changes and carousel movement may shift the proofing light, but
  there must be no single-frame flash, shadow pop, or unexplained light leak in
  a 60 fps capture.

## 3. Rotating proofing platform

- The selected physical product sits on a visible 3D turntable/plinth and
  completes a continuous 360-degree rotation when motion is enabled.
- Rotation occurs about the item's validated optical pivot. In a captured full
  revolution, screen-space center drift may not exceed 2 points on the compact
  phone or 0.5% of viewport width on any larger phone, whichever is stricter.
- The turntable remains grounded with a contact shadow and does not intersect
  the product, counter, label, or adjacent samples.
- User carousel input must not reset the newly selected item into a visibly
  wrong orientation or continue spinning the previously selected item as the
  focus.
- With Reduce Motion enabled, automatic spin stops. A direct drag or an
  accessible “Rotate preview” action may expose other angles without ambient
  motion; purchase, selection, and inspection remain fully available.

## 4. Complete browseable catalog

The authoritative product catalog is the source, not the mockup's demo counts:

| Category | Required product IDs | Required count |
|---|---|---:|
| Paper | `pp_newsprint`, `pp_white`, `pp_ivory`, `pp_manila`, `pp_ledger`, `pp_graph`, `pp_onion`, `pp_carbon`, `pp_telegram`, `pp_garden`, `pp_night_sky`, `pp_ocean`, `pp_utility_roll` | 13 |
| Grid | `bd_printed`, `bd_fine`, `bd_heavy`, `bd_sage`, `bd_blueprint`, `bd_gilt`, `bd_laser` | 7 |
| Numbers | `nb_press`, `nb_typewriter`, `nb_schoolbook`, `nb_oldstyle`, `nb_stencil`, `nb_neon`, `nb_laser`, `nb_flame` | 8 |

- Every ID must be reachable through visible, discoverable shop controls with no
  debug flag, search incantation, or inaccessible overflow item.
- Each category shows a truthful `X / N` position where `N` is exactly 13, 7,
  or 8. First, middle, penultimate, and last items must all be selectable.
- Every product in the active category stays simultaneously visible as a
  physical object across the stand while one selected item receives proofing
  focus: exactly 13 Paper, 7 Grid, or 8 Number style products. Responsive
  framing may use multiple physical tiers/depth rows, but it may not hide,
  virtualize, page, crop, or replace any product with an end marker.
- Every resting product must be visibly distinguishable before selection: its
  projected silhouette has at least a 24-point shorter dimension on compact
  hardware and 32 points on standard/larger hardware, its independent hit area
  is at least 44 by 44 points, and its non-overlapping physical name/style tag
  is at least 11 points before Dynamic Type scaling. Thin paper/grid forms may
  satisfy the silhouette floor on their longer dimension only when both the
  product and tag remain clearly visible. These floors may rise after physical
  evidence but may not be lowered to fit 13/7/8.
- Swipe/drag, left/right controls, keyboard arrows where available, and
  VoiceOver adjustable or named previous/next actions must select the same
  deterministic ordered catalog.
- Paper and grid products show their full playable surface at inspection scale.
  A selected number style must visibly demonstrate all digits 1–9 before
  purchase/equip so the user is not choosing from a single misleading glyph.
- Locked, affordable, insufficient-balance, owned, and equipped states remain
  browseable. State may alter controls/copy but may not hide the physical item.
- Selecting, purchasing, or equipping an ID must map to the identical canonical
  asset package used in gameplay; separate fake shop art fails.

## 5. Counter composition and interaction hierarchy

- Physical category specimens remain on the foreground counter, as in the
  references, while one selected product receives primary focus.
- Category selectors, page count, product name, description, balance, price,
  and purchase/equip state remain legible but subordinate to merchandise.
- Tap targets are at least 44 by 44 points. Controls and labels must not overlap
  the product silhouette, turntable, safe area, Dynamic Island, home indicator,
  or each other.
- Product scale is stable within a category. No item may become a giant room
  prop merely to fit the camera, and thin paper/grid assets must remain readable
  without z-fighting.

## 6. Responsive, accessible, and evidence gates

- Required evidence covers the compact QA phone, standard iPhone 17 Pro,
  largest iPhone, the physical device, and minimum supported iOS runtime when
  available, in portrait and every supported orientation.
- For each device: Paper/Grid/Numbers; first/middle/last; locked/owned/equipped;
  Reduce Motion; largest balance; longest localized copy; and all defined
  bloom/non-emissive fallbacks must be captured.
- Required motion evidence includes opening, entry start, entry midpoint,
  arrival at the stand, reverse midpoint, and restored opening; the captured
  path must prove one continuous world with correctly cross-faded controls.
- Contact sheets prove all 13 papers, all 7 grids, and all 8 number styles with
  digits 1–9, including one frame per category proving every member is present
  simultaneously. A scripted reachability test must visit every one of the 28
  IDs and assert `X / N`, canonical registry identity, and gameplay mapping.
- Purchase/equip evidence must show the brass stamp and vellum-tag transition,
  exact balance mutation, central mechanical move, proofing-lamp change,
  `EQUIPPED` plaque, prior-item return, relaunch persistence, and failure paths
  without false physical confirmation.
- VoiceOver focus order follows category → merchandise navigation → selected
  product details → price/state → purchase/equip. Every physical product has a
  localized accessible name and state.
- Final visual approval requires side-by-side evidence against both approved
  bookstore references. “Better” is accepted only when the reviewer records
  improvements and zero lost invariants; subjective claims without screenshots
  and runtime interaction evidence do not pass.
