# Number Club Design Language

**Status:** baseline for all player-facing UI  
**Owner:** KAN-150  
**Applies to:** every SwiftUI surface, cosmetic, illustration, glyph, transition,
and accessibility representation in Number Club.

**Visual baseline:** [Design Language Baseline](DESIGN_LANGUAGE_BASELINE.md)

## Visual reference set

These are captured from the current iPhone 17 Pro simulator build. They are
reference examples, not idealized mockups: new work must fit the same material
world and preserve the gameplay hierarchy they demonstrate.

| Surface | Reference | What it establishes |
| --- | --- | --- |
| Club room | [Main menu](Artwork/DesignLanguage/main-menu.png) | Lamp-lit wood, plaque, desk objects, number board, and controls as furniture |
| Live Book | [Puzzle page](Artwork/DesignLanguage/live-puzzle.png) | Physical volume, quiet paper, high-contrast grid, handwritten margin, and printed actions |
| Club Shop | [Cosmetic counter](Artwork/DesignLanguage/club-shop.png) | Material samples, ownership state, practical typography, and a dark room surround |

The accompanying [Design Language Baseline](DESIGN_LANGUAGE_BASELINE.md) is the
review artifact: it puts these captures beside the visual rules and their code
sources. Use it at the start of any player-facing UI change.

## 1. The thesis

Number Club is **a well-used puzzle book opened on the desk of a small,
slightly eccentric number club**. It is not a productivity app with a sudoku
theme placed on top.

The player should feel three things, in this order:

1. They have opened a physical Book.
2. The Book is printed, annotated, and occasionally corrected by people.
3. The numbers and rules inside it are precise enough to trust.

Every visual choice must answer: *what is this made of in the club room?*
If it cannot be named as a material, printed object, or hand-made mark, it does
not belong in the player-facing UI.

The single memorable signature is **the live, annotated puzzle page held inside
a real Book volume**: visible page edges, binding shadow, paper grain, printed
rules, and pencil interventions. All other surfaces support that object.

## 2. Non-negotiable rules

- Do not introduce generic iOS assets or default iOS-looking controls in
  player-facing screens.
- Do not introduce new SF Symbols as visible player-facing iconography. Existing
  symbols are migration debt; replace them with bespoke, drawable glyphs when a
  touched surface is redesigned. SF Symbols may remain in invisible accessibility
  fallbacks, developer tools, or temporary internal QA surfaces.
- Do not use `List`, `Form`, `Toggle`, system segmented controls, tab bars,
  floating circular action buttons, glass cards, generic gradients, or elevated
  white cards as the visible design solution.
- Do not use pure white pages, neutral greys as the primary material, or unnamed
  hex colours. A colour has a physical name and a semantic job.
- Do not use a pill merely because a label needs a background. Pills mean a
  physical token, a stamped count, or a short piece of tape—not a default button.
- Do not add decoration behind a number, label, control, or grid just to fill
  space. The page’s quiet areas are part of its rhythm.
- Gameplay state may never be communicated by colour alone. A wash, rule,
  hatch, strike-through, wording, and VoiceOver value should agree.

## 3. Material world and colour tokens

Use the existing `Paper` and `LevelPalette` tokens; add a named material token
before adding a literal colour. Theme cosmetics may alter stock, desk, board,
number face, and marking implement, but may not obscure game-state contrast.

| Token / material | Hex | Use |
| --- | --- | --- |
| Desk dark | `#261A13` | Room depth and dark surround |
| Desk mid | `#3E2C20` | Wood body |
| Desk light | `#4C3627` | Lit wood grain |
| Page | `#EDE8DB` | Default printed stock; never substitute white |
| Page warm | `#E6E0D0` | Recessed paper, quiet controls |
| Page edge | `#D8D0BC` | Book block and paper edge |
| Ink | `#2E2C28` | Primary printed information |
| Soft ink | `#5E594F` | Supporting copy |
| Faint ink | `#8E8879` | Metadata and secondary rules |
| Rule | `#B6AE9C` | Hairlines and quiet boundaries |
| Sage | `#7C8C73` | Positive progress and club action |
| Deep sage | `#66765E` | Primary action, selected confirmation |
| Brass | `#E0B33C` / `#A9801E` | Coins and earned club currency only |
| Red pencil | `#B4544A` | Error, restriction, correction, danger |
| Editorial blue | `#53688C` | Blue-ink editorial treatment only |

### Colour use

- Use ink and paper for the normal reading hierarchy; reserve colour for a
  change in meaning.
- Sage means advancement, an armed positive choice, completion, or current
  selection. It is never an all-purpose decorative accent.
- Red pencil means a restriction, refusal, wrong placement, or destructive
  action. It should look marked or struck, not merely “alert red”.
- Brass belongs to value already earned or spent: coins, Stamps, and their
  physical tokens. It is not a primary CTA colour.
- Cosmetic paper treatments remain low-contrast furniture around live content.
  Their artwork must be masked away from controls, labels, and the grid.

## 4. Typography: printed, written, and numerical

The interface has three voices. Do not make them interchangeable.

| Voice | Existing foundation | Job | Rules |
| --- | --- | --- | --- |
| Display print | `Print.heading`, `Print.clubTitle` | Book titles, page titles, the club plaque | Heavy, closely set, usually uppercase. One display moment per composition. |
| Reading print | `Print.subheading`, `Print.body`, `Print.caption` | Instructions, labels, descriptions, actions | Quiet and legible. Captions may be tracked and uppercase when they behave as a printed label. |
| Numerical print | `Print.numeral` and a selected `NumberSkin` | Grid, hand, score, counts | Monospaced digits; numerals are the game’s instruments, never decoration. |
| Handwriting | `Print.handwritten` / selected marker ink | Margin notes, ticks, corrections | Sparse, human, and never used for dense instructions, prices, or game-critical labels. |

- Headings are information hierarchy, not a texture. Avoid stacking several
  uppercase headings in one small area.
- Keep body copy in sentence case. Use direct verbs: “Open the Book”, “End
  Turn”, “Choose a square”.
- A label, action, and confirmation use the same words throughout a flow.
- Prefer actual type to rasterized words. Generated images must contain no
  player-facing lettering.

## 5. Layout grammar

### A. Room surfaces

The main menu, shelf, and Club Shop are places in the club room. They use depth:
foreground object, desk plane, wall or room behind it, and one purposeful light
source. Objects sit on the desk and cast contact shadows. They do not float in
empty dark space.

### B. Book surfaces

Puzzle, shop, results, briefing, and information screens are pages or slips.
The Book page owns the work; the island-safe strip carries only run constants
and exit controls. A page has a clear hierarchy:

```
run strip / physical controls
────────────────────────────
printed page title + one-line state
game object (grid, offer, result)
reserved annotation or explanation band
consequential actions at the foot
page number / quiet publishing furniture
```

- Pages have a generous outer margin and a deliberately reserved blank band for
  margin notes. Content does not jump when a note appears.
- Use printed rules, page edges, a binding, and subtle unevenness to establish
  physicality; do not simulate it with generic card corner radii.
- Prefer square-to-gently-rounded paper corners (2–5 pt) and restrained 1–1.5
  pt printed borders. Larger radii are reserved for the Book volume itself.
- The grid is always the highest-contrast, most spatially stable object on a
  puzzle page. Decorative stock must never compete with it.

### C. Slips

Settings, briefings, buffs, run information, and similar overlays are paper
slips laid on the desk or page. A slip needs a visible edge, a slight cast
shadow, and one clear dismissal route. It is not a translucent system sheet.

### D. Collections

Shelves, cosmetic catalogues, and loadouts are arranged as physical collections:
covers, samples in a drawer, bookmark tabs, or stacked cards. The selected item
has a physical state—pulled forward, outlined in ink, ticked in pencil, or
placed in use—not only a blue selection fill.

## 6. Component baselines

| Component | Anatomy | States | Never |
| --- | --- | --- | --- |
| Primary action | Deep-sage printed block, heavy action text, 52 pt minimum visual height | Default, pressed-in, disabled, destructive variant | Bright blue fill, chevron-only label, glow |
| Quiet action | Warm-paper field, printed rule, ink label | Default, pressed-in, disabled | Borderless text link where a physical control is expected |
| Destructive action | Quiet paper control with red-pencil rule and wording | Default, confirmation required where irreversible | Solid emergency-red rectangle |
| Number tile | Printed numeral on warm paper, thin rule, 54 pt high | Drawn, selected (lifted/outlined), blocked (red strike), empty (outline) | Plastic chips, glossy gradients, coloured balls |
| Grid cell | Hairline rule, heavy 3×3 division, numeral, semantic wash/mark | Given, selected, matching, barred, right, wrong, marked | Colour-only state, rounded card cell, animated layout movement |
| Coin / Stamp | Brass physical token plus numerical readout | Earned, spent, unavailable | Generic badge, arbitrary gold decoration |
| Toggle | Printed square checkbox with pencil tick | On, off, disabled | System switch |
| Back / utility control | Bespoke line glyph plus printed label where space permits | Normal, pressed, disabled | Isolated SF Symbol inside a floating circle |
| Boss state | Crooked red-pencil stamp plus concise explanation | Active, resolved | Alert banner or warning triangle |

**Touch targets:** a control may look smaller, but its tappable area is at least
44 × 44 pt. The visible object must still look intentional at that size.

## 7. Bespoke asset and glyph direction

Visible assets should be drawn in SwiftUI, `Canvas`, `Shape`, or supplied as
clean custom vector/raster art—not borrowed system iconography.

The glyph family is **club stationery**: a folded page corner, pencil, stamp,
bookmark ribbon, closed-book spine, coin face, tray, and club-room gear. Draw
with a consistent 1.5–2 pt slightly softened line, rounded joins where ink is
drawn, and a filled/outlined pairing for active versus passive states.

When a concept has no stationery analogue, use a concise word button first.
An unfamiliar custom glyph without a label is worse than a clear printed word.

Asset acceptance checklist:

- It has no embedded UI text or generated gibberish.
- It reads at 24 pt and at 44 pt touch-target scale.
- It works on light paper and dark desk backgrounds.
- It has selected, disabled, and VoiceOver-label behaviour.
- It belongs to the physical club room, not a device control centre.

## 8. Interaction, haptics, and motion

Motion should explain a physical event or game consequence. Spend it on one
dominant event in a scene, then let the rest stay still.

| Event | Motion | Timing / limit |
| --- | --- | --- |
| Pressing paper | Downward press and slight darkening | Fast, ~0.12–0.18 s; no glow |
| Selecting a hand tile | Tile lifts; board match receives a quiet wash | ~0.18 s; selection never moves layout |
| Number arrival | Character-specific print/type/pencil action | Stagger only for a newly dealt hand |
| Correct / blocked / wrong | Pencil wash, hatch, strike, or stamp | State remains readable after the motion ends |
| Page change | One continuous physical curl or paper wash | Never use a generic push or modal slide |
| Book opening | Cover opening moves into paper wash | Tapping may shorten it; no “Skip” button in the composition |
| Ambient room | Nearly imperceptible light or board life | Never compete with the primary task |

- Respect Reduce Motion: use identity transitions or immediate state changes;
  keep the final visual state and all information intact.
- Haptics reinforce a confirmed physical/game event (selection, success,
  warning), never every decorative animation.
- Avoid continuous looping movement on actionable objects.

## 9. Accessibility is part of the print

- Dynamic Type must preserve action labels, currency, and state without clipping
  or hiding price/action relationships. Let supporting prose wrap before
  shrinking critical content.
- Treat a card, number tile, or stamped state as one meaningful VoiceOver
  element where its children do not need independent actions.
- Describe visual state in the accessibility value: e.g. “Number 4, blocked
  this turn”, “Ivory Laid, owned, equipped”, “Score 240 of 350”.
- Do not rely on hue: selected tiles lift and rule; blocked tiles strike;
  wrong placements have an explicit warning; a selected cosmetic is ticked or
  physically foregrounded.
- Minimum contrast applies to every cosmetic theme, especially Night Sky.
  Cosmetic variation cannot reduce the distinction between printed, placed,
  selected, and wrong numbers.
- Decorative grain, stock art, desk furniture, and ambient effects are hidden
  from accessibility.
- Support Reduce Motion, Increase Contrast, VoiceOver order, and 44 pt targets
  before polish is considered complete.

## 10. Screen-specific decisions

### Main menu

The menu is a **club room**, not a launch screen. The title plaque, lamp-lit
number board, desk props, and physically placed actions make one composition.
Use no more than one active ambient focal point: the number board under the
lamp. Settings arrives as a paper slip on the desk.

### Shelf and start-a-book flow

Books are covers on a shelf, not carousel cards. A locked Book remains visible
as a physical object with a readable lock state. The starting-board choice
belongs on a slip after opening a Book, not beside the cover.

### Live puzzle

The puzzle page is a reading-and-marking workspace. Prioritize in this order:
grid state, selected number, score/target, turn state, then secondary actions.
The hand is a row of dealt paper tiles; empty capacity is an outline, never a
faded tile. A boss is an editorial intervention in red pencil, not a system
alert.

### Shops and cosmetics

The in-run shop is a page in the Book; the Club Shop is a drawer/counter in the
club room. They must not share the same navigation furniture or economic visual
language. Club cosmetics are material samples and are previewed in the actual
page/desk context. Ownership, equipped state, price, and affordability must be
visible without opening a detail view.

## 11. Implementation contract

Build from the existing foundations rather than bypassing them:

- Materials and base type: `App/Design/Theme.swift`
- Cosmetic material system: `App/Model/CosmeticTheme.swift`
- Book volume and stock overlays: `App/Views/BookView.swift`
- Puzzle grid and semantic state: `App/Views/GridView.swift`
- Hand/tile treatment: `App/Views/HandStripView.swift`
- Action treatment: `PaperButton` and `PressedPaperStyle` in
  `App/Views/PuzzlePageView.swift`
- Club-room composition: `App/Views/MainMenu/*`

For any new player-facing surface, the implementation review must answer:

1. Which real club-room object is this surface or control?
2. Which named material and semantic token does each colour use?
3. Which of the four type voices is each text role using?
4. How does selected, disabled, failure, and completion state read without
   colour?
5. What is the Reduce Motion equivalent?
6. Which bespoke glyph or written label replaces a generic iOS asset?

If those questions cannot be answered, stop and design the object before
writing the view.

## 12. Definition of done for visual work

- The design reads as Number Club with all labels temporarily removed.
- The new element has a material role, not only a UI role.
- It uses named tokens and one of the established type voices.
- It has all interactive, disabled, error, selected, and accessibility states.
- It remains legible at the smallest supported phone, the largest Dynamic Type
  size, and every supported cosmetic theme.
- It introduces no generic iOS assets or stock iOS control styling.
- Motion has a physical or game-semantic reason and a Reduce Motion path.
