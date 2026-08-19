# The Number Club

A roguelike sudoku for iOS. Native SwiftUI — no game engine.

`GAME_REFERENCE.md` (at `~/GAME_REFERENCE.md`) is the authority on rules. Section
numbers in code comments refer to it.

## Layout

```
NumberClub/
├── project.yml              XcodeGen source of truth — never edit the .xcodeproj
├── Engine/                  Pure Swift package. No UIKit, no SwiftUI, no I/O.
│   ├── Sources/NumberClubEngine/
│   ├── Sources/simulate/    Bot soak test
│   ├── Sources/genbench/    Generation benchmark
│   └── Tests/
└── App/                     SwiftUI. Knows nothing about rules.
    ├── Design/Theme.swift   Materials, type, paper grain
    ├── Model/GameModel.swift
    └── Views/
```

The split is strict: the engine has no notion of a screen, and the app has no
notion of a rule. Everything in the engine is a value type, so a view can hold a
snapshot without worrying about it changing underneath.

## Building

Xcode 26.2. The project is generated, so after adding files:

```bash
cd NumberClub && xcodegen generate
```

Engine work needs no Xcode project at all, and is much faster without one:

```bash
cd Engine
swift test                     # 80 tests
swift run -c release simulate 200   # 200 Books, asserts conservation throughout
swift run -c release genbench       # per-difficulty generation timing
```

## What is done

**Engine — complete and tested.** Every rule in `GAME_REFERENCE.md`:

- Seeded generation with a unique solution and a technique-ladder difficulty gate
  (Easy falls to singles, Boss defeats the whole ladder). Release timings:
  easy 0.7 ms, medium 1.0 ms, boss 9.4 ms — fast enough to generate on the main
  thread between pages.
- Four independent random streams (§15), so drawing a number can never shift
  which Boss Modifier appears. A Book is fully determined by its seed plus the
  player's choices, and seeds are shareable.
- The conservation rule (§4) is asserted after every action: Pool + Hand always
  equals exactly what the remaining Blanks need. 2,449 simulated puzzles, zero
  breaks.
- All 23 Ads, 12 Markers, 10 Buffs, 9 Boss Modifiers, with the §6 scoring formula
  and the §14 resolution order.
- Shop with §9 stock, rarity odds, price bands and reroll pricing.
- Save/load round-trips mid-Puzzle.

**App — a playable vertical slice.** Desk, book page with fore-edge tabs, the
grid with its states, the Hand strip, the Buffs panel, the Shop page, the results
page, the page-turn transition, and the Marker square picker.

## Decisions worth not re-deriving

- **A Marker marks a square, not a number.** `GAME_REFERENCE.md` §11 is
  emphatic about this and is the newest artefact; the old TypeScript prototype
  and the asset checklist both attach a colour to a *digit* instead. Squares is
  what shipped. It is why The Fog is a real attack, why buying a Marker early
  compounds, and why moving a square costs coins.
- **Naming is Ads / Markers / Buffs** in code and on screen, not
  Newspapers / Cardinals / Charms.
- **Prices are rolled within the §9 band**, not taken from the per-item tables in
  §10–12. Every listed price does fall inside its band — a test asserts it — so
  the tables stay accurate as documentation.
- **Almost nothing is an exported image.** The grid, every cell state, the
  buttons, the badges, the Marker colours and the progress dots are all drawn.
  Marker finishes are a `Color` plus a wash, not twelve textures. Icons are SF
  Symbols, which brings scaling, weight matching and VoiceOver labels for free.
- **No Undo**, despite the mockup having a button for it. Undo would leak the
  Pool: place a number, learn it was wrong, take it back. The information the
  game deliberately hides (§4) is the thing Undo would hand over.
- **The mockup's three stars have no mechanic**, so the score-against-target
  meter took their place. That number is what the whole run is about and the
  mockups had nowhere to show it.

## Open questions

These are places where the design is genuinely undecided or where I had to pick.

1. **Balance.** A bot that places perfectly and buys greedily reaches Level 5–6
   and completed 0 of 200 Books. Targets double per Level while the board stays
   81 squares, so multiplier builds are not optional — they are the whole game.
   That may be correct for the genre, but it wants playtesting.
2. **Book tiers.** §2 flags the difficulty ladder as undecided, so finishing a
   Book currently just starts another at the same difficulty.
3. **The Censor** (§13) zeroes the placement *and* any clear that placement
   causes. Reading it as the placement alone makes it much weaker than the other
   eight modifiers.
4. **The Deadline plus Late City Final** gives 9 Turns — the Ad adds to whatever
   base applies. Reading The Deadline as a hard override instead would give 8.
5. **Toss allowance of 2** is flagged provisional by §5.1 itself.
