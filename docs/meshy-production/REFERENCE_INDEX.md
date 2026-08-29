# Approved-reference index

Status: `PHASE1_ACCEPTED_VISUAL_TARGET_LOCKED_PENDING_IMPLEMENTATION`

Only evidence explicitly approved by the user, a linked Jira acceptance
contract, or the binding production contract may be marked approved. Presence in
the repository alone is not approval.

| ID | Reference | SHA-256 | Approval evidence | Governs | Audit status |
|---|---|---|---|---|---|
| CONTRACT-001 | `/Users/daniel/meshy_club_shop_master_prompt.md` | `473e52da4c5ba2622ed3021f3d08564cc3e563495278e4c6eb228930fdde520c` | Direct user instruction in KAN-153 goal | Scope, governance, quality and release gates | Approved authority; not a visual asset |
| REPO-README-001 | `README.md` | `2c33fb68f83b0d118e22b5804f84cf8306ec9a509495f921e1fbdf47608e3e41` | Repository instruction | Build, device, performance, motion constraints | Active |
| DESIGN-001 | `DESIGN_LANGUAGE.md` | `1d99d2b8ffd6164c7703f595ea8cc343c54f06fc21b8d747ee4e441523012851` | KAN-150 design-language baseline | Product materials, typography, UI character | Pending Sonnet audit |
| DESIGN-002 | `DESIGN_LANGUAGE_BASELINE.md` | `43cc123d0c9ab91790a0575d76e2f3dea491b77ffd4150ddef81c6c2811f900a` | KAN-150 baseline artifact | Screenshot comparison | Pending Sonnet audit |
| CATALOG-001 | `REFERENCE.md` | `7a9e6fb7aefe8c1f1345f5765a53ad66be7298455f15a84e089c1d581ae61578` | Generated repository catalogue | Non-cosmetic game catalogue cross-check | Active, generated; never hand edit |
| RULES-001 | `/Users/daniel/GAME_REFERENCE.md` | `0f076ab5acac99793953f3824a2b870f2fc7dbdf7ae5a0d2bb6ada4a7bb630b9` | Repository instruction declares authority | Gameplay behavior and non-regression | Main-agent full read complete; Sonnet R1 cross-check required |
| MOCKUP-BOOKSTORE-001 | `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/bookstore-aisle.html` | `0934eaa191d573b450d82f607476bc8bd67b7c8f36011d78a5305b7081e42561` | Direct user re-approval on 2026-08-29: “the shop should look like in the mockup but better” | Interactive bookstore aisle composition and behavior; visual floor | Opened, rendered, and interacted with by main agent |
| MOCKUP-BOOKSTORE-002 | `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/bookstore-aisle-rendered.html` | `c33a6f03bd2e977ec55c2ed87b2005565edf26d8fe2790347c1bda81de0895f4` | Direct user re-approval on 2026-08-29 and explicit instruction to open/interact before editing | Rendered bookstore composition and interaction; visual floor | Opened, rendered, and interacted with by main agent |
| MOCKUP-SHOP-001 | `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/sudoku-shop-depth.html` | `723db7314abee0936720608900d1ec913ffe55de94f68be56d0609083ffcb945` | Discovered adjacent mockup; user approval not proven | Club Shop depth/composition candidate only | Unapproved; may not override the bookstore mockups |
| MOCKUP-SHOP-002 | `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/sudoku-shop-depth-rendered.html` | `f9d591715c41152f065853ff5635114d875767d95ba2f28aaaa1667f48ee6b0c` | Discovered adjacent rendered mockup; user approval not proven | Club Shop depth/composition candidate only | Unapproved; may not override the bookstore mockups |
| SCREENSHOT-CLUBSHOP-001 | `Artwork/DesignLanguage/club-shop.png` | `a0fdcf14f2f830d4f92b0c86d2392ac1f0a52ca95b674793c9faaa3150870798` | Design-language artifact | Existing flat Club Shop baseline only | Audited as non-conforming baseline, not target |

## Contract-extracted composition invariants

- `SHOP` moves the live camera in one uninterrupted path from the opening
  bookstore composition to the physical store stand while opening controls
  fade. `BACK` reverses that same path. Opening and shop are one continuous 3D
  room, never two views or a flat-store swap.
- The physical stand is the shop: all browsing, buying, and equipping occur on
  it. Every active-category product is simultaneously physically present and
  selectable—13 Paper, 7 Grid, or 8 Number styles—and the selected Number style
  proves digits 1–9.
- `BUY` is communicated by a brass stamp pressing the product's vellum price
  tag before the tag becomes `OWNED`; `EQUIP` mechanically moves the product to
  the lit central platform and changes a brass plaque to `EQUIPPED`.
- Category/product selection survives the reverse camera trip and later
  re-entry. The flat `ClubShopView` is a non-conforming baseline and may not be
  release-reachable.

- Private bookstore club: rich walnut, deep bottle green, aged brass, warm
  vellum/paper, controlled theatrical light, and premium letterpress character.
- The selected product receives the strongest proofing light and rotates around
  its optical pivot without drift.
- Previous, selected, next, and the final carousel item remain fully visible,
  selectable, and inside counter/safe-area bounds on every supported phone.
- Physical sign, plaque, control, display, and support bodies are Meshy-origin;
  localized names, prices, balances, descriptions, categories, and state copy
  may be dynamic text.
- Category controls remain subordinate to merchandise. Product scale stays
  consistent within a category. No giant monolithic room crop or generic app
  store cards are allowed.

The Sonnet repository auditor must expand this index with checksums, approval
evidence, component mappings, material/type/light/scale rules, and conflicts.

## Direct interaction record — 2026-08-29

The main agent served the exact two approved HTML files from their source
directory on a loopback-only read-only HTTP server because the in-app browser
rejects direct `file://` navigation. Both files were opened in separate in-app
browser tabs and visually inspected. In each reference the agent:

- entered `SHOP`;
- switched among `PAPER`, `GRID`, and `NUMBERS`;
- advanced the merchandise carousel using Arrow Right;
- observed Paper move from `1 / 5` Ivory Laid to `2 / 5` Manila;
- observed Grid move from `1 / 3` Fine Rule to `2 / 3` Heavy Rule; and
- observed Numbers move from `1 / 5` Typewriter to `2 / 5` Pencil.

The observed target is one continuous, deep bookstore room: dark walnut
shelving, bottle-green signage and counter surfaces, warm brass and proofing
light, a foreground counter with physical samples, soft cast/contact shadows,
and a focused selected product that auto-rotates on its display. All category
samples remain physically present while the selected item receives the strongest
focus. Source inspection also proves that the reference keeps bookstore and
shop in one scene and moves the camera to a side counter rather than swapping
to a flat view. Direct user clarification makes this motion the primary gate:
`SHOP` travels to the stand, `BACK` reverses it, and selection persists.

The mockup's `5 / 3 / 5` demo inventory and one re-skinned selected object per
category are implementation shortcuts, not the production target. Production
must expand to simultaneously visible physical assortments of `13 / 7 / 8`,
with physical brass-stamp purchase and mechanical equip feedback inside the
stand, without losing the approved composition. Measurable requirements are
locked in `VISUAL_INVARIANTS.md`.
