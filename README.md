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

## 120Hz

`CADisableMinimumFrameDurationOnPhone` must be **true**, or iOS holds the app at
60Hz on a ProMotion phone and everything reads as slightly heavy.

It cannot be set through `INFOPLIST_KEY_CADisableMinimumFrameDurationOnPhone`.
That prefix only carries the fixed set of keys Xcode knows about; anything else
is accepted into the project file and then silently dropped from the generated
plist — the setting is visibly present in `project.pbxproj` and absent from the
built `Info.plist`. The target therefore uses an explicit `info:` block in
`project.yml`, which XcodeGen writes to `App/Info.plist` (generated, not
committed).

Check it survived, rather than assuming:

```bash
/usr/libexec/PlistBuddy -c "Print :CADisableMinimumFrameDurationOnPhone" \
  <build>/NumberClub.app/Info.plist        # must print: true
```

## Running it on a real iPhone

Team `233268ZQDV`, bundle id `com.numberclub.app`, automatic signing. Apple
answers, so the account and team are set up correctly — a device just has to be
registered before a profile can exist.

On the phone, once: **Settings → Privacy & Security → Developer Mode → on**,
then restart. This is required on iOS 16 and later and is the step that is
usually missed; without it the phone will not appear as a run destination at
all.

Then plug it in, unlock it, tap **Trust This Computer**, and:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun devicectl list devices                       # confirm it is seen
UDID=<the identifier from that list>

xcodebuild -project NumberClub.xcodeproj -scheme NumberClub \
  -destination "platform=iOS,id=$UDID" -configuration Debug \
  -derivedDataPath build -allowProvisioningUpdates build

xcrun devicectl device install app --device "$UDID" \
  build/Build/Products/Debug-iphoneos/NumberClub.app
xcrun devicectl device process launch --device "$UDID" com.numberclub.app
```

The first build registers the phone with the team and creates the profile,
which is why it has to be connected for that step.

## Running it

```bash
cd NumberClub && xcodegen generate
xcodebuild -project NumberClub.xcodeproj -scheme NumberClub \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Then install and launch. Note the **uninstall** — `simctl install` over an
existing app will happily keep running the old binary, which costs an hour the
first time it happens:

```bash
SIM=$(xcrun simctl list devices available | grep -m1 'iPhone 17 Pro' | grep -o '[0-9A-F-]\{36\}')
xcrun simctl boot "$SIM"; open -a Simulator
xcrun simctl uninstall "$SIM" com.numberclub.app
xcrun simctl install "$SIM" <DerivedData>/Build/Products/Debug-iphonesimulator/NumberClub.app
xcrun simctl launch "$SIM" com.numberclub.app
```

Debug launch arguments, so iterating on the board does not mean tapping through
the cover every time:

| Argument | Effect |
|---|---|
| `-skipStartScreen` | straight into a Puzzle |
| `-seed DEMO` | the same Book every launch |
| `-selectHand 0` | start with a number picked up, to see the highlight |
| `-autoEndTurn` | ends a Turn one second in, so the page flip can be recorded |
| `-curlHold 0.35` | freezes a page turn part-way, to look at the curl without racing it |
| `-thenTapSquare 1` | after `-selectHand`, taps that square — reproduces the highlight order |
| `-winNow` | meets the target on launch, to land on the results page |
| `-qa` | opens Settings on launch |
| `-playOpening` | starts on the Book-opening transition, to record it |
| `-clearLine` | completes a row on launch, to see the completed-unit mark |
| `-buffSlip` | grants Paper Crane and opens its slip |
| `-runInfo` | opens the run information slip on launch |
| `-loadout` | grants some Bookmarks and Buffs, to see the row populated |
| `-obstacle 3` | opens the shelf on that obstacle level |

## Books have a personality

A Book is a published thing, not just a difficulty tier. The first is
**You've Got This, Probably** — cheerful, faintly unsure of itself — and it
talks to the player in the margins while they play. `App/Books/BookEdition.swift`
holds its title, blurb and hundred lines; harder Books get their own editions
when the ladder in §2 is settled.

Notes are print handwriting (Bradley Hand, on every device) rather than a
script face, and they are **rolled from the seed**, not from a live random
source — so a Book says the same things in the same places every time it is
played, which is the same promise §15 makes about everything else. A note
appears on the first Turn of each Puzzle and then about two Turns in five.

They are drawn in the band under the grid: the one part of the page with
nothing printed on it and nothing to tap. The note is offset from the left by
at most a quarter of the free width and is never wider than the remaining three
quarters, so whatever the line says it cannot reach the edge of the page, and
the band reserves its height whether or not the Book speaks, so a note
appearing never shifts the grid.

## Obstacles

Chosen with the Book, in the band above it, and fixed for the run. Deliberately
separate from the Book's own difficulty ladder (§2, still undecided): an
obstacle does not change the boards or the targets, it changes what you have to
work with, so the two dials move independently.

| | |
|---|---|
| Obstacle I | Nothing |
| Obstacle II | One fewer number in hand |
| Obstacle III | II, and one number blocked from being played each Turn |

The blocked number stays in your hand — you can see it, and you can still Toss
it — you simply cannot put it on the board until the Turn is over. It is chosen
**after** the refill and **from the numbers actually held**, because barring a
number the player does not have is no obstacle at all. It comes off the seeded
pool stream, so a seed still reproduces a run exactly.

It blocks a digit rather than a hand position: positions shift as the hand is
played, and a block that moves is unreadable.

Each level is drawn as well as described — the Hand itself with the obstacle
applied: seven numbers for I, six and an empty slot for II, and six with one
struck through in red pencil for III.

It has to be **paper**: cream stock with printed numerals, laid unevenly and
casting a shadow on the wood. The first attempt was flat grey rounded
rectangles with a dashed box for the missing slot, which is interface — and the
only thing on that screen that would have been. The missing slot is an outline
rather than a faded tile, because fading a tile leaves its shadow behind and
reads as a dark block.

The three descriptions are kept to one line each, so the artwork sits at the
same height on all three.

## The shelf

`StartBookView` is where the app opens, and where it returns whenever a Book
ends or is abandoned — §3 makes the Starting Board a choice you make when you
open a Book, so one is never dealt silently.

It is a shelf, not a title screen. Five Books are swiped through as covers.
Only the written one can be opened; the other four are shown locked rather than
hidden, so the ladder §2 leaves undecided is visible instead of implied.

The Starting Board moved **off** the shelf and onto a slip shown when you open
a Book. Three cards competing with a cover is three cards too many, and §3 says
the choice belongs to the moment a Book is opened anyway.

Two decisions that are easy to get wrong here:

- The cover is shown **whole**, not filled to the screen. Cropping a 2:3 cover
  into a 9:19.5 phone throws away the tabs, the sticky notes and half the
  title — which is most of what the cover is.
- The backdrop is a plain dark gradient rather than a photograph of a desk. The
  cover is already photographed lying on one, and two desks read as a picture
  of a book rather than as a book.

`scripts/gen-cover.mjs` generates a desk photograph via Meshy (`gpt-image-2`,
12 credits, needs `MESHY_API_KEY`); it asks for no lettering anywhere, because
generated type is always gibberish. The Meshy MCP server is also registered at
user scope, so the same generation can be driven conversationally.

### Opening a Book

Tapping **Open the Book** plays `probably-open.mp4` — the cover swings open onto
a blank page — and then blurs and whitens out onto the first Puzzle, which is
dealt behind the wash. Same Meshy settings as the loop; trimmed to 3.2s, which
is where the cover has finished opening and the model starts padding out its
five seconds.

The blur begins 0.75s **before** the clip ends so the two movements overlap.
Waiting for the video to stop and then blurring reads as two separate things
happening, which is the opposite of what a page turn should feel like. The
paper wash is held across the swap and lifted afterwards, so there is never a
cut between the clip and the board. Reduce Motion skips straight to the Puzzle.

### The cover loop

Generated in Meshy's **web app** — the API has no video endpoint at all. Two
settings decide whether it comes out usable, and one of them resets on you:

| | |
|---|---|
| Tab | Image to Video |
| Model | **Kling 2.5 Turbo** — resets to Seedance 2.0 on every page load |
| Source | the Book's 9:16 scene, so the video matches the still exactly |

Image to Video has **no aspect ratio control**; it takes the aspect from the
image. Seedance ignores that and returns 16:9 whatever you feed it, so a
landscape render almost always means the model reset itself back to Seedance.
Kling keeps the framing and costs 25 credits against Seedance's 110. Text to
Video does expose 16:9 / 9:16 / 1:1, but cannot reproduce a specific Book.


`App/Resources/probably-loop.mp4` is the first Book, animated. Made in Meshy's
web app (Kling 2.5 Turbo, 25 credits) rather than through the API, then
processed:

```bash
ffmpeg -i in.mp4 -filter_complex \
  "[0:v]scale=720:-2,setpts=PTS-STARTPTS,split[a][b];[b]reverse,trim=start_frame=1[r];[a][r]concat=n=2:v=1[v]" \
  -map "[v]" -an -c:v libx264 -pix_fmt yuv420p -crf 25 -movflags +faststart out.mp4
```

Played forward then backward, so the loop point is the same frame and there is
no jump — a 5s clip becomes a 10s loop with no seam.

**Encode at the size it is displayed at, not the size it arrived at.** The clip
is shown `resizeAspectFill` on a 1320x2868 screen, which scales a 1076x1924
source by **1.49x** every frame through the runtime's bilinear scaler. Encoding
at 1604x2868 with an offline lanczos scale removes that entirely.

**Encode at the source's native size.** The first version was scaled to 720
wide to keep it under a megabyte, which threw away a third of the linear detail
before the phone had even started. An iPhone 16 Pro Max is 1320px wide, so the
shipped asset is upscaled either way, and every pixel dropped here is one it has
to invent. Native is 1076 wide at CRF 19, which costs about 5.5MB and looks like
a photograph rather than a video of one.

Some softness is left and cannot be encoded away: Kling returns 1076x1924 and
Meshy exposes no resolution control, so the asset is still short of 1320. Fixing
that needs a higher-resolution generation, not a better encode. Worth checking
rather than assuming: comparing the first and last frames of the finished loop
gives a mean difference of 0.77 out of 255, which is encoding noise.

Three things learned the expensive way:

- **Seedance ignores the source aspect.** A portrait image came back 1280x720
  landscape. Kling 2.5 Turbo keeps the framing, and costs 25 credits against
  Seedance's 110.
- **Ask for stillness in the negative and the specific.** "Almost imperceptibly
  slowly" was read as a hard push-in that ended on a close-up of cloth. Listing
  what must not happen — no push in, no zoom, no pan, no dolly — worked.
- **Anything you invite it to move, it will move too far.** Asking for sticky
  note corners to "lift and settle" produced a note peeling up to reveal a
  second note underneath covered in invented handwriting. Asking instead for
  the notes to *stay stuck flat and never reveal anything beneath them*, while
  still letting the paper flutter, kept the draught and lost the artefact.

**Meshy's API cannot make video.** `image-to-video`, `text-to-video` and
`video` all 404 with `NoMatchingRoute`, though the feature exists in their web
app; only `text-to-image`, `image-to-image` and `image-to-3d` answer. Driving
the web app by hand works but produced a landscape 1280x720 clip from a portrait
source, and pushed the camera hard into the cloth despite being asked not to —
so movement is done in the app instead. `CoverBackground` will play a loop named
`cover-loop.mp4` if one is ever added to the bundle, and falls back to the
drifting still otherwise, under Reduce Motion, or in Low Power Mode.

## Settings and help

The gear opens Settings, the `?` opens the help. Both are **printed slips laid
on the desk over the book**, not system sheets: cream stock with grain, ink
type, dotted leaders, paper buttons, red pencil for the destructive one, and the
desk dimming behind. A `List` inside a `NavigationStack` would be the one place
the game stops being an object, which is the whole premise.

Settings carries where you are in the Book, the seed with a copy button (a seed
plus the same choices reproduces a Book), how to play, and Abandon Book behind
a confirmation that names what is lost. The confirmation is in the slip too —
a system dialog would break the illusion just as badly.

The QA panel stays a plain system list on purpose. It is a tool for building the
game, not part of it.

## QA panel

Settings has a Development section in debug builds that opens the QA panel: add points or coins, meet the target,
fail the Puzzle, fill the board, start a new Book, and read the live state
(seed, level, score, turn, phase, Pool remaining, Boss).

The whole panel and the engine calls behind it sit inside `#if DEBUG`, so they
cannot reach a player. Verified rather than assumed — a release build contains
none of the panel's strings and no debug dylib:

```bash
strings <Release>/NumberClub.app/NumberClub | grep -c 'Add 1,000 points'   # 0
```

Awards go through the same phase check a real placement does, so a QA win
reaches the Cash Out / Keep Filling choice exactly the way a played one would.
"Fill the board" takes each number from the Pool or Hand so the conservation
rule still holds, but scores nothing.

To actually look at an animation, record rather than screenshot — a `simctl
screenshot` takes longer than the flip does:

```bash
xcrun simctl io "$SIM" recordVideo --force flip.mp4 &   # then launch, then kill -INT
ffmpeg -i flip.mp4 -vf fps=30 frame%03d.png
```

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
- All 23 Bookmarks, 12 Markers, 10 Buffs, 9 Boss Modifiers, with the §6 scoring formula
  and the §14 resolution order.
- Shop with §9 stock, rarity odds, price bands and reroll pricing.
- Save/load round-trips mid-Puzzle.

**App — a playable vertical slice.** Desk, book page with fore-edge tabs, the
grid with its states, the Hand strip, the Buffs panel, the Shop page, the results
page, the page-turn transition, and the Marker square picker.

## Where this departs from GAME_REFERENCE.md

**The Pool is shown.** §4 designs it to be invisible — "never shown, never
counted for you, and has no tally anywhere" — because it is knowable anyway
(nine of each digit, minus the board, minus your hand) and working it out is
called the game's deepest source of information, "earned by paying attention,
not by reading a number off the screen". The `?` now prints it as `9 x 5`. That
is a deliberate choice to do the counting for the player; if the run ever feels
like it lacks a skill ceiling, this is the first thing to take away again.

**Toss is one number at a time, four for the whole Puzzle** (§5.1 has it as a
multi-select with two per Turn). Two per Turn across ten Turns is twenty, which
is not a budget — it costs tempo but never forces a decision, and multi-select
let the Hand be reshaped wholesale every Turn, which is most of the Pool's
pressure gone. Four for a Puzzle makes each one a choice. Weather Forecast
still adds two; The Erratum still removes it.

## Decisions worth not re-deriving

- **A Marker marks a square, not a number.** `GAME_REFERENCE.md` §11 is
  emphatic about this and is the newest artefact; the old TypeScript prototype
  and the asset checklist both attach a colour to a *digit* instead. Squares is
  what shipped. It is why The Fog is a real attack, why buying a Marker early
  compounds, and why moving a square costs coins.
- **Naming is Bookmarks / Markers / Buffs** in code and on screen, not
  Newspapers / Cardinals / Charms.
- **Prices are rolled within the §9 band**, not taken from the per-item tables in
  §10–12. Every listed price does fall inside its band — a test asserts it — so
  the tables stay accurate as documentation.
- **The page turn is a Metal shader, not a 3D transform.** `rotation3DEffect`
  turns a rigid rectangle, which is the Word-97 transition, not paper. Paper
  bends: `App/Shaders/PageCurl.metal` wraps the sheet around a cylinder tangent
  to a fold line that sweeps across it, so the far half of the roll is seen from
  behind. Requires the Metal toolchain — `xcodebuild -downloadComponent
  MetalToolchain`.

  Two traps cost real time here, both worth knowing:
  - **Do not call `layerEffect` inside `visualEffect`.** The proxy is convenient
    for the view's size, but the shader then only ever sees the *final* value of
    an animated parameter, so the curl arrives already finished and the turn
    looks instant. Measure the size separately and call `layerEffect` directly
    from an `Animatable` modifier.
  - **Insert the leaving page one frame before animating it.** Inserting a view
    and animating it in the same update gives the animation no value to travel
    from, with the same symptom.
- **The book is an object, not a card.** What makes something read as a book is
  thickness, so it is built as one: boards standing proud of the paper, a block
  of individually drawn page edges down the fore-edge and along the tail, a
  binding the paper turns down into, and a printed page number. A bookmark
  ribbon was tried and removed: a ribbon only reads as one if it drapes down
  over the page with a shadow under it, and that space belongs to the turn
  counter and the level dots — pinned to the fore-edge at ribbon width it just
  looked like a red line. The live page is a separate view from the volume, which is what lets
  it lift off the block when the page turns while the boards stay put.
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

1. **Balance.** From `simulate 300` — a bot that places perfectly but buys
   greedily (first affordable offer, no build plan):

   | Level | attempts | won | best score | target | best / target |
   |------:|---------:|----:|-----------:|-------:|--------------:|
   | 1 | 900 | 900 | 3,000 | 2,000 | 1.50x |
   | 3 | 828 | 749 | 10,300 | 8,000 | 1.29x |
   | 5 | 289 | 237 | 46,085 | 32,000 | 1.44x |
   | 7 | 32 | 23 | 161,085 | 128,000 | 1.26x |
   | 9 | 4 | 2 | 393,960 | 512,000 | **0.77x** |

   Two things fall out of this. The doubling ladder tracks achievable scoring
   well — headroom sits at 1.2–1.5x almost the whole way, which is the right
   shape. But **0 of 300 Books completed**, because a per-Puzzle win rate around
   85% compounded over 27 Puzzles is roughly 1%. A real player builds better than
   this bot, so the true rate is higher — but the Level 9 row, where the best run
   out of 300 Books still fell 23% short of target, suggests the top of the ladder
   may not be reachable at all. Worth playtesting before tuning anything else.
2. **Book tiers.** §2 flags the difficulty ladder as undecided, so finishing a
   Book currently just starts another at the same difficulty.
3. **The Censor** (§13) zeroes the placement *and* any clear that placement
   causes. Reading it as the placement alone makes it much weaker than the other
   eight modifiers.
4. **The Deadline plus Late City Final** gives 9 Turns — the Bookmark adds to whatever
   base applies. Reading The Deadline as a hard override instead would give 8.
5. **Toss allowance of 2** is flagged provisional by §5.1 itself.
