mplementation prompt: boss expansion and readable, physical boss effects

Work in `/Users/daniel/NumberClub`. Implement the 20 new bosses specified below and improve the presentation of all current bosses. This is the full implementation brief, including engine behavior, interface feedback, animation, persistence, accessibility, and validation. Deliver working gameplay in the local iPhone simulator.

The game is a Sudoku scoring roguelike built around Books, numbered Hand cards, a conserved Pool, ordered Bookmark multipliers, square-bound Markers, and consumable Buffs. Preserve that identity. The objective is to make each boss's effect immediately understandable through what actually happens to the relevant game object.

## 1. Verify the current implementation first

Read the repository instructions and inspect the current code before changing it. The source paths in this brief were checked when the brief was written, but files and line numbers may change. Verify current symbols and behavior; do not treat an old screenshot, mockup, comment, or catalogue description as more authoritative than the running engine. Where implementation and item text disagree, investigate before deciding how the new boss interacts with them.

Start with:

- `Engine/Sources/NumberClubEngine/BossModifiers.swift`, `Puzzle.swift`, `Actions.swift`, `Game.swift`, `Run.swift`, `Pool.swift`, `Board.swift`, `Obstacle.swift`.
- `Scoring.swift`, `Resolver.swift`, `Effects.swift`, `CatalogueState.swift`, `BookmarkMechanics.swift`, `BookmarkState.swift`, `MarkerRuntime.swift`, `MarkerDecisions.swift`, `MarkerState.swift`, `BuffRuntime.swift`, `BuffState.swift`, and the current item catalogue.
- `App/Model/GameModel.swift`, `App/Views/PuzzlePageView.swift`, `GameplayScorePanel.swift`, `GridView.swift`, `BossBoardVisuals.swift`, `BossVignette.swift`, `HandStripView.swift`, `BookmarkRow.swift`, `BuffSlip.swift`, `ScoreLedgerSlip.swift`, Marker inspection, and the existing motion preferences.
- Current boss, scoring, item-decision, save/restore, accessibility, and layout tests.

Confirm the actual placement/penalty sequence; automatic End Turn after the last card is played or Tossed; ordinary retained-Hand refill; pending item choices; Clue behavior; eligible/ineligible score lots; direct awards; higher Obstacles; final-boss selection; and the current win/Keep Filling flow. Do not invent an alternative scoring system or Hand lifecycle for the new bosses.

Preserve all existing uncommitted work. Keep existing boss raw IDs and saved encounters compatible. Add new identities without renaming legacy serialized values. Do not rebuild the app, rewrite the README or art direction, revive the retired Club Shop/cosmetics pipeline, change unrelated item abilities, or replace Book selection and page transitions.

## 2. Presentation direction

Use the current full-page book/paper gameplay style: warm ivory, readable dark ink, restrained sage, tactile number tiles, and purposeful physical effects. Keep the board square, front-facing, large, and aligned to its hit regions. Preserve Bookmark and Buff positions. No new book borders, permanent bonus bar, oversized mascot, decorative banner, green slab, scattered stickers, or artwork unrelated to the boss's rule.

Every boss needs three states:

1. A short entrance that establishes its effect.
2. Specific feedback when that effect actually triggers.
3. A quiet persistent indication of what remains active, plus clear release/expiry feedback when relevant.

A name, icon, status sentence, red tint, or generic toast alone does not satisfy the animation requirement. Animate the object affected by the mechanic: the clock, a blocked square, a Hand card, a Bookmark, a Buff, or a score receipt. Keep necessary rule text as support. Use concise current-state labels in the existing boss area and inspection surfaces; never make the player memorize an unexplained glyph.

Use the game's existing rendering and asset systems first. SwiftUI Canvas, masks, procedural textures, or a small shader are reasonable for fog if appropriate after inspection. Do not introduce a full 3D engine or a dependency just to create a mist overlay. Use real assets when useful, including the current BossBrick asset; keep all lighting directions and shadows consistent.

Normal placement and feedback should stay quick. Aim for roughly 120–250 ms reactions and 350–700 ms major impacts. Longer entrances must settle promptly and cannot block input while decoration finishes. Animate from committed engine events and stable IDs; SwiftUI recomposition, inspection, app resume, and loading a save must not replay resolved effects or apply gameplay twice.

## 3. Tik Tak: make time impossible to overlook

Keep its existing four-minute active-play rule. Improve presentation without creating a second clock or changing pause/failure semantics.

- Show a prominent, stable `MM:SS` countdown throughout the encounter, starting at `04:00`. It must be recognizable at a glance on an actual iPhone, not a small subtitle below the boss name. The current approximately 14-point line is insufficient.
- Give the timer a dedicated compact area in the existing score/boss header. Aim for roughly 30–36-point monospaced digits at the default iPhone text size, adapting to the real layout. Preserve the large score and board; rearrange the header instead of shrinking gameplay. Include the small label `Time left` so it cannot be mistaken for a score or Turn count.
- A thin remaining-time indicator may sit directly under that same countdown if it helps, but do not add another toolbar or separate permanent status panel. The exact remaining time is always the primary signal.
- Above 60 seconds: clear dark ink. From 60 down to 31 seconds: amber emphasis. At 30 seconds and below: a restrained red accent and one brief threshold pulse. At 10 seconds: one additional distinct cue. Colour must never be the only way to convey urgency.
- Optional threshold haptics/sounds must respect the existing settings and fire once per crossing. Do not shake the board, flash continuously, or introduce a constant ticking sound by default.
- Derive display from the existing engine/model clock. Clamp at zero and handle fractional seconds so a positive remainder is not shown as expired. At actual expiry, invoke the existing failure flow once. Never drive gameplay with animation completion or frame count.
- Preserve current pause behavior for overlays, transitions, inactive scenes, and backgrounding. Where the countdown remains visible during a pause, clearly show `Paused`. Saving, restoring, orientation/layout changes, or inspecting an item cannot reset the four minutes or charge paused time.
- Keep the existing `ContinuousClock` elapsed-time source, fractional persistence, and upward-rounded displayed seconds. Score-feedback playback currently does not independently pause the clock; do not add that pause accidentally. The timer also runs in active Keep Filling and expires through the existing failure path. Frozen result snapshots must never tick or save a timer. A restored zero-time encounter expires on activation.
- VoiceOver must expose the remaining time on demand without announcing every second and drowning out the board. Announce only meaningful warnings and expiry once. Reduced motion retains the same readable timer and clear static urgency state.

Acceptance: a player viewing a normal-size simulator capture can immediately identify the time remaining at 04:00, 01:00, 00:30, and 00:10 without opening help or enlarging the image.

## 4. The Fog: actual visible fog, with correct information hiding

“The dog” in the request refers to **The Fog**. Its rule remains that Marker locations are hidden while their effects still operate. Add visible atmospheric fog; do not turn it into a different boss that hides Sudoku digits.

- On entry, soft ivory/grey mist rolls across the board and settles into a visible, gently drifting layer. Give it depth with at least two visually distinct layers moving at slightly different speeds, soft irregular density, and subtle overlapping wisps. It should read as fog rather than a flat white rectangle, global blur, three line drawings, or a `HIDDEN` stamp.
- Place fog above the board material and below crisp numerals and essential grid/selection feedback, or use an equivalent compositing arrangement. Players must read every digit, distinguish all 81 squares and 3×3 boxes, and accurately place cards. Mist can be somewhat denser at the outer edges while still visibly drifting across the centre.
- Fog is visual feedback for the global concealment rule. The underlying Marker icons, outlines, accessibility text, position-specific highlights, long-press details, and source-location animations must genuinely remain concealed using the current privacy rules. Do not merely put translucent fog on top of still-rendered Markers.
- Fog shape, density, motion, holes, and clearing MUST NOT depend on the hidden Marker map, hidden solution, or whether a square is secretly marked. There must be no visible patch per Marker and no clearing under a finger that exposes one. Two equal boards with different hidden Marker locations must have equal public rendering for the same animation phase until an actual permitted gameplay event changes public information.
- Keep all legal Marker effects functioning. Preserve the current filtered receipt/inspection behavior; do not expose a hidden source location through a tooltip, VoiceOver, score-source flash, or the fog pattern.
- The fog layer ignores hit testing. It must not intercept taps, drags, or the accepted hold-to-inspect gesture. Inspection should explain the Fog restriction without revealing a location.
- Stop continuous updates when gameplay is covered/inactive. Reduced motion uses a convincing static mist composition, never a completely missing effect. Honor the game's own reduced-motion preference; inspect how it combines with platform accessibility settings.
- Reuse the existing `bossMotionIsActive` lifecycle and background-motion/Low Power behavior. Keep the decorative animation clock local to its rendering layer; do not invalidate all 81 cells every frame. When continuous background motion is disabled, retain the static fog treatment. Apply existing concealment to Run Info's Marker map as well as the active board and score ledger.
- Fog disperses cleanly when the encounter ends, without following the user into the next puzzle. Resume shows the settled encounter, not another dramatic entrance.

Current code exposes `showsFog` but does not render actual board fog. Some existing tests expect Fog's board to look identical to the clear board: update that obsolete visual expectation intentionally. Preserve and strengthen tests proving hidden Marker maps do not change public rendering or leak through inspection.

Acceptance: a player can identify the fog effect without reading the boss label, while completing ordinary Sudoku interactions without reduced numeral legibility or knowledge of hidden Marker positions.

## 5. Improve the other current bosses consistently

Preserve existing mechanics and exact protections. These are visual requirements, not permission to change their rules:

| Boss | Required feedback |
|---|---|
| Gray the Garry | Physical clay bricks descend into only the chosen row's barred blanks. Each brick is slightly smaller than its square, aligned with the grid, with tightening contact shadow, a short impact, and minimal fading dust. Keep givens visible. Lift/clear expired bricks and show the new row at the next Turn, including a repeated selection. |
| Garry the Gray | The same material and landing language, arranged as a short wave through the chosen box's blank squares. Never cover the entire box with one flat block or spill settled bricks over borders. |
| The Shredder | Wet ink visibly lands and spreads inside newly fouled blanks. Existing fouls remain visibly settled until their exact saved expiry. Show six concurrent fouls when three from the previous Turn overlap three new ones; never visually clear them early. |
| The Censor | Keep the digit on the board readable. Show the censored digit in the boss area; stamp affected score receipts to zero. Preserve current zeroing semantics, including any existing penalty interaction; do not silently redesign them. |
| The Editor | Establish the reduced Hand capacity through a brief removed-slot/fold cue, then settle to the actual smaller Hand. Do not suggest that a required number was deleted from the Pool. |
| The Deadline | A short cut/stamp changes the effective Turn allowance. Keep the final remaining Turns readable, including Book/item modifiers. Do not confuse this Turn budget with Tik Tak's clock. |
| The Critic | Rejection feedback, exact doubled penalty, and the correct card-return path. No wrong digit remains in the grid. Protection that waives the penalty must also remove the corresponding penalty visual. |
| The Mirror | A real completed unit briefly traces, then its Line Clear receipt is crossed to zero. Keep placement and Full Clear feedback intact. No board reflection or rotation. |
| The Paywall | Visibly seal the relevant Clue action and explain disabled Buff-granted Clues in their existing details. Never consume a Clue or Buff just because the player inspected a disabled action. |
| The Erratum | A clean crossed-paper/tab treatment on Toss with its zero allowance. Preserve separate legal exchange tools. |
| The Collector | At payout, cross out the interest line only; show the actual lost interest. No invented deduction from unrelated payouts. |
| Natural Born Accountant | A brief coin transfer at each accepted charged placement attempt, paired with the real wallet delta. Negative balances remain readable. Invalid/blocked taps do not animate a fee. |
| Handy Dandy | Put clear, small physical seals on the exact barred Hand-card copies. Keep digits readable; another copy of the same digit must not appear barred unless it really is. Release/reselect at the correct Turn boundary. |
| The Final Draft | Enlarge the target through a single ×4 transformation, then display the real multiplied target. No extra full-screen banner or fabricated score loss. |
| The Executive Editor | Fold/dim only the sleeping triggered Bookmark and show why it is unavailable. Wake it at the correct boundary; passive starting upgrades stay represented correctly. |
| The Fine Print | Seal consumable Buff slots/actions. Previously activated persistent effects keep working and must not be falsely shown as cancelled. |
| The Budget Cut | Show the final combined multiplier being halved once in the actual bank receipt. Do not visually halve each individual Bookmark or halve direct score awards. |

## 6. Engine and state requirements for the 20 additions

Implement every specified new boss, not just placeholder names, selectable previews, or scripted animations. There are 15 proposed regular bosses and 5 proposed final bosses below. Register them in the corresponding encounter pools while keeping existing bosses available.

- A puzzle has its existing single boss. Do not combine bosses unless the current game explicitly supports it. Test new rules against Obstacles, Books, and the full current item catalogue.
- Validate boss-specific eligibility before announcing/committing an encounter. Use the real preparation path and starting inventory. Exclude ineligible candidates deterministically and use a valid existing fallback if needed. Once a boss has been shown, persist it; later inventory changes do not secretly reroll the encounter. Do not consume player resources while choosing it.
- Keep the boss RNG independent from Pool draws, Shop rolls, and visual randomness. Save every gameplay-relevant counter, UUID set, pinned order, deferred request, carried score, and target snapshot. Visual randomness must not consume engine RNG.
- Preserve the exact remaining-digit multiset across Pool and Hand. No boss may clone, destroy, convert, or randomly replace a required number. Maintain card UUID semantics through return/exchange operations.
- Use separate placement-only restrictions where specified. Existing fields that also block Toss are not interchangeable with these rules. Apply the same eligibility to all applicable input paths, including relevant Hand-Clue selection; keep explicit allowed release/exchange effects working.
- Do not read the hidden solution to decide whether an otherwise blocked Hand should be released. Release rules must use the specified visible values, ownership, IDs, and ordinary legality. The engine may still use the solution in its normal placement validation.
- End Turn, automatic empty-Hand banking, rescue, Full Clear, and mandatory item choices must resolve through the existing authoritative paths. Coalesce simultaneous automatic-bank reasons. Never bank twice or discard a pending choice to finish an animation.
- Scoring changes must operate at their specified level: event-local placement Points, source-attributed bonuses, pre-Mult queued Points, ordered held Mult, or post-Mult bank settlement. Preserve direct awards as a separate channel. Do not fake these changes only in text or mutate the state when a preview is opened.
- Pending preview, actual bank, receipts, source highlights, and score ledger must agree. Mixed eligible/ineligible point lots and finite item uses require explicit attribution. Reuse the existing deterministic point-lot debit policy where applicable; document and test any necessary new allocation instead of subtracting from a displayed scalar while leaving spendable lots intact.
- Newly added Codable fields need safe defaults for old saves. Existing active bosses, timer state, queued scores, item decisions, and saved scoring versions must continue to restore. A future unknown case must not silently corrupt an old run.

The values below are initial design values, not evidence of balanced difficulty. Implement them consistently, run representative balance scenarios, and report severe outliers with evidence. Do not silently change their printed rules or replace difficult mechanics with different ones.

## 7. Acceptance and delivery

Add focused engine tests for each new boss's actual mutation and scoring behavior, not tests that merely check its name or mirror the implementation. Include deterministic seeds, save/restore at relevant boundaries, rejected actions, protected mistakes, Clues, low Pool supply, duplicate card/item copies, higher Obstacles, manual/automatic End Turn, and Keep Filling where relevant.

Specific integration cases must include: FIFO order surviving Hand sorting; Bookends excluding independently barred cards; repeat-only release; Collator fallback release; exact Rebinder conservation; deferred Courier draws counting toward refill; Page Cutter's fourth fill plus empty-Hand completion producing one bank; Return Slip plus Jade returning one exact card; Orphan Line debiting mixed point lots correctly; Serial Publisher releasing all carry on Full Clear; Bindery preserving physical neighbours while reversing evaluation; cancelled Buff decisions never changing Embargo/Royalty state; Dry Press preserving non-score effects, protected Clue rules, finite-use entitlements, and its no-plain-blank escape; Review Board accepting Clue-created clears; Publicist not consuming a use on a zeroed event; Word Count retaining natural base; Back Page preserving Violet's explicit override.

For presentation, capture current simulator screenshots and short recordings using controlled valid game fixtures, not fake receipt-only states. The fixture must visibly support its claimed state: previously approved rows/columns are actually complete, queue labels show real totals, returning cards retain identity, and a completed bank has the correct Turn/refill state. Keep captures limited to the current build.

Show Tik Tak at start and each warning threshold, pause/resume, expiry, and restoration. Show Fog entering, drifting, reduced motion, inspection, and leaving. Compare equal Fog boards with different hidden Marker maps at the same animation phase. Exercise taps, drags, and long presses through the effect. Check the supported iPhone sizes, safe areas, enlarged text/display, and the existing game motion settings. Do not hide clipping by reducing the board or text to unreadable sizes. Measure animation behavior on an appropriate device/simulator and report any remaining performance limitation rather than claiming device performance from screenshots.

Include 375×667, 390×844, and 430×932 viewport checks where supported. At identical viewport and text settings, changing the boss or countdown value must not shrink the board. Retain existing TikTakClockTests and Marker inspection/score privacy coverage; replace only the obsolete expectations that there is no visible fog.

Provide: all 20 implemented bosses; the current-boss visual improvements; current-build simulator evidence; a concise list of affected engine/UI areas; test results; and explicit remaining balance or interaction risks. Keep work local unless separately asked to publish it. Use the full mechanical specifications below as part of this prompt.

---

## 8. Full specifications for the 20 new bosses

### The Galley Queue
Play either of the two oldest available Hand cards; remove one to advance the queue.

- Tier: Regular
- Exact rule: After every Hand mutation, rank cards by stable arrival order. Among cards not barred by an Obstacle or an independent item rule, only the two oldest may be placed. Placing or normally Tossing an eligible card immediately exposes the next oldest.
- Reset: Puzzle-wide FIFO discipline. Card arrival sequence survives save/load and Hand arrangement. New draws join the tail; no Turn reset lets sorting bypass the queue.
- Counterplay: Choose between the two front digits; Toss a front card when Tosses are available; use an explicit card-release Buff if its rule allows. Plan a correct destination before consuming a front card.
- Boundaries: With one otherwise available card, that card is playable. With two or fewer, the Boss bars nothing. Skip independently barred cards when choosing the front pair. If no independently available cards exist, ordinary End Turn remains available; never guess a solution square to manufacture an exit.
- Animation: Two thin brass type rails slide under the Hand, framing only its two oldest available cards; every number stays face-up. A demonstration cursor places the first framed card into its existing correct blank; the logical board is unchanged otherwise. The third card advances into the vacated rail with a short paper slide; remaining cards stay readable behind the rail. The two available cards hold a quiet ink outline. A tiny queue arrow stops; no perpetual shaking.
- Integration: NEW placement-only eligibility by CatalogueHandCard.id; use arrival serial, not display order or mutable indices. Re-evaluate after draw/remove/return/exchange. Do not store these bars in blockedHandIndices, because that existing field also forbids Toss.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:34, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:233, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:237, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/CatalogueState.swift:3, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/CatalogueState.swift:112

### The Bookends
Only the lowest or highest available digit in your Hand can be placed.

- Tier: Regular
- Exact rule: Before each Hand placement, calculate minimum and maximum digit among cards otherwise available under Obstacles/item rules. Every copy of either extreme is eligible; middle digits become available as extremes leave the Hand.
- Reset: Recomputed after every Hand mutation for the whole Puzzle. No hidden selection, random roll, or once-per-Turn trap.
- Counterplay: Work inward from either end, retain a useful extreme for a later square, or exchange/Toss an awkward extreme using ordinary allowed actions. All duplicate copies of an extreme remain selectable.
- Boundaries: One available digit value means every otherwise available card is playable. No cards are consumed by the Boss. Exclude independently barred digits before calculating the extremes so it cannot add a total Hand lock.
- Animation: Two small bookend silhouettes settle outside the Hand; low and high number cards gain a clear edge. The low digit lifts into a correct blank while its duplicate, if present, remains visibly eligible. The left bookend moves to the new low digit; middle cards remain fully legible with a restrained bottom rule rather than gray paint. Hold the new lowest/highest pair and the unchanged completed square; one short caption reads “Low or high.”
- Integration: NEW public Hand-extrema eligibility helper, called by placement and held-card Clue choice. Keep it independent of presentation sorting and isTossBlocked.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:226, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:233, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:441, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Pool.swift:95

### The Reprint Ban
Repeated digits wait while an unused, unbarred digit remains in your Hand this Turn.

- Tier: Regular
- Exact rule: Track digit values correctly filled this Turn. A held digit already in that set cannot be placed while at least one otherwise available Hand digit has not yet been used. If every otherwise available held value is already used, the repeat restriction is waived until a new unused value arrives.
- Reset: Used-digit set clears at each Turn boundary. Correct Clue fills also mark a digit as used; wrong attempts, blocked taps, draws and scoring subevents do not.
- Counterplay: Alternate digit values and plan their Sudoku destinations; choose when to draw fresh values. A newly drawn unused digit may temporarily make repeats wait again, so the change is explained before selection.
- Boundaries: A Hand containing only repeats or one available digit is never completely locked by this Boss. Waiver depends only on visible Hand values and existing bars, never the hidden solution. End Turn resets the used set normally.
- Animation: A small proof stamp presses a single used 5 onto the existing Boss header edge after a demonstrated correct 5 placement. Other held 5s receive a small hollow repeat-loop below the digit; an unused 3 stays available. The demonstration places the 3; if only repeated digits remain, the loops open with a short uncurl. Hold the fully readable Hand and an open repeat loop, making the no-total-lock fallback visible.
- Integration: NEW saved Turn-level 9-bit used-digit set and dynamic placement-only availability. Update on accepted correct fills after normal resolution; reset alongside startBossTurn. Do not feed it into Toss bars.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:67, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:181, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:368, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Obstacle.swift:87

### The Rebinder
At End Turn, return leftover Hand cards to the Pool before drawing a fresh Hand.

- Tier: Regular
- Exact rule: After the outgoing Turn has banked and its actual effects have finished, atomically return all leftover Hand cards to the Pool, then perform the ordinary new-Hand draw up to effective Hand size.
- Reset: Every ordinary Turn boundary, including automatic empty-Hand boundaries. No extra Turn is consumed. Puzzle/Book/Marker ownership remain unchanged.
- Counterplay: Use important held digits before banking rather than saving them; plan valuable square opportunities this Turn. Finishing with an empty Hand avoids any forced return.
- Boundaries: When there are no leftovers, use ordinary refill. Near board completion, draw only the remaining Pool supply. The exact multiset is preserved, including copies that happen to be drawn back immediately.
- Animation: A small cloth binding cord tightens beneath the remaining three Hand tiles when End Turn is chosen. Those exact three tiles slide into the existing Pool-side return direction, all digits visible during transit. A fresh conserved Hand slides out of a narrow paper edge; the Turn counter advances once. The cord releases and the new Hand settles; the Sudoku board and all placements stay fixed.
- Integration: NEW Boss boundary hook between outgoing banking/effects and refill. Reuse removeAllHandCards, Pool.put, appendHandDigits and card invalidation instead of hand replacement by raw arrays. Forced returns are not Tosses or player exchanges.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:421, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:617, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:672, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/CatalogueState.swift:129

### The Late Courier
Bonus draws wait for End Turn and count toward the next refill.

- Tier: Final
- Exact rule: Whenever a qualifying item would perform an automatic random bonus draw during a Turn, enqueue that draw request rather than drawing immediately. After that Turn banks and before ordinary refill, execute queued requests from the Pool once in their original order. The delivered cards count toward effective Hand size; ordinary refill then draws only the remaining deficit.
- Reset: Saved per-Turn deferred request queue, emptied exactly once after banking and before ordinary refill. Initial dealing, ordinary refill itself, paid Clue extraction, explicit exchanges, and choice-based draws are outside this rule. Deferred requests reserve no Pool cards and advance no draw RNG until executed.
- Counterplay: Play from the Hand already available, then end the Turn deliberately to receive owed draw attempts. Delivery changes timing rather than adding a second refill. Use targeted or choice-based tools whose complete choices remain immediate if available.
- Boundaries: Empty Pool requests draw fewer or zero, using ordinary Pool.draw behavior. A request is not a removed or reserved number, so every required copy remains in Pool/Hand and Clues continue to work. Required encounter eligibility: the current run must own or already have activated a qualifying automatic-random-draw source that can operate in this encounter with nonempty Pool supply. Do not roll this Boss for a build with no qualifying source; that is a selection rule, not optional weighting.
- Animation: A Sapphire square is correctly filled; instead of a card entering the Hand, a folded delivery ticket marked “1” tucks beside the existing End Turn button. A second automatic draw adds one ticket. No card is removed from Pool and no hidden digit is revealed yet. End Turn banks first. The two tickets unfold into two actual Pool draws and join the Hand before the ordinary refill starts. Ordinary refill visibly adds only the remaining number of cards needed to reach normal Hand size; the two delivered cards already occupy two of those places. Tickets vanish, the Hand settles, and one Turn increment remains visible. No extra refill or duplicated card follows.
- Integration: NEW centralized automatic-random-draw policy and required encounter-eligibility check. Save request counts and source order; execute after outgoing banking, before the existing needed = max(0, handSize - hand.count) calculation. Delivered cards participate in that calculation, preventing a second net refill boost. Do not reserve Pool copies or advance RNG at request time. Route automatic draws in expanded item runtimes through the same policy; modifying only Actions.apply misses catalogue hooks.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:412, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:342, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:348, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:672, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Pool.swift:84

### The Collator
Half your Hand waits until 2 correct fills—or until the first packet is empty.

- Tier: Regular
- Exact rule: At Turn start, split the current Hand in arrival order into an open first packet of ceil(count/2) and a waiting second packet. Two correct fills this Turn release the whole second packet. Also release it immediately whenever no otherwise playable card remains in the first packet.
- Reset: One two-packet deal per Turn. Packet membership is stored by UUID. New item-drawn cards are open immediately and do not become a third packet. Every correct fill, including a paid Clue fill, advances the two-fill release count.
- Counterplay: Use two available numbers to open the rest, or spend an ordinary Toss to clear an awkward first packet. Additional draws remain an intentional counter. Waiting digits are always readable, so the player can plan the release.
- Boundaries: If the Hand has fewer than 3 cards, do not split it. If Obstacle/item bars leave the first packet without any playable card, open the second packet immediately. If all globally available cards have gone, ordinary End Turn remains reachable. Never require a correct hidden solution to decide release.
- Animation: A short paper belly band settles under the right half of the Hand, leaving all numbers fully visible above it; two empty dot punches sit on the band. A correct placement fills the first dot punch. A second correct placement fills the second dot and unhooks the band in one clean motion. The released cards lift a few pixels into line with the first packet and settle; no extra cards are created.
- Integration: NEW packet card-ID set plus correct-fill counter in BossTurnState. Add placement-only waiting eligibility; reevaluate on all Hand mutations and ordinary item bars. Packet release must occur before empty-Hand auto-end logic.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/CatalogueState.swift:3, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:84, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:334, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:368

### The Page Cutter
Every 4 correct fills end the Turn automatically. Start with 4 extra Turns.

- Tier: Final
- Exact rule: Count each correct board fill once, regardless of how many units it completes. After the fourth fill and all associated effects/mandatory choices resolve, invoke the ordinary End Turn path exactly once. At Puzzle creation add 4 to the otherwise effective Turn budget.
- Reset: Fill counter resets at every actual Turn end. Wrong attempts and blocked taps do not advance it. Correct Clue fills do. Extra Turns are granted once at creation; rescue and later Turn-grant items keep their normal rules.
- Counterplay: Plan groups of four around Marker chains, clears and the ordering of held multipliers. Put the most valuable fourth play at the end of the batch. Manual End Turn remains legal earlier, consuming a normal Turn.
- Boundaries: When eligibility holds but the Hand later shrinks, a smaller Hand may empty and end normally. If the fourth play also empties the Hand or completes the board, coalesce all auto-end reasons into one boundary. Never terminate a mandatory item decision, double-bank, or skip earned effects. Required selection gate: starting effective Hand >4 or an already active guaranteed extra-draw engine; otherwise reroll the Boss before dealing, without consuming player resources.
- Animation: Four small cut-registration ticks appear beside the existing Turn label; three are already filled in the demonstration. The fourth correct number lands, completing the fourth tick while its ordinary earned score appears. A paper cutter line slides only across the margin below the Hand, then triggers the existing bank/page-turn motion; it never slices a Sudoku digit. Next Turn appears with a refreshed Hand and four empty ticks. The expanded Turn budget remains visible.
- Integration: NEW accepted-correct-fill counter and pendingAutoEnd flag, with one coalesced boundary after pendingItemDecisions become empty. Add +4 once during Puzzle.create/effectiveTurns integration. NEW pre-deal eligibility uses actual effective Hand capacity and an explicit deterministic-draw-source capability; it may not inspect Board.solution, predict player correctness, or count merely optional/random future draws. Exclude ineligible runs before the Boss is locked.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:84, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:534, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:598, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:293, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:690

### The Chain Stitcher
Each natural fill after the first must share a unit with the previous one, or earn half Points.

- Tier: Regular
- Exact rule: For every natural correct fill after the first this Turn, compare its destination with the immediately previous natural correct fill, not the first fill of the Turn. Sharing that previous square’s row, column, or box earns ordinary placement Points. Otherwise halve only this placement event’s final Points, rounding down. In either case, move the remembered square to this newly accepted fill so the next comparison advances along the chain.
- Reset: One moving remembered square per Turn; first natural correct fill is unrestricted. Every accepted natural correct fill becomes the next anchor, including a fill that just took the half-Points cost. Clue fills and wrong attempts neither move nor reset the anchor. Row/column/box clear Points are unaffected.
- Counterplay: Build a moving chain through units shared with the immediately previous natural fill. Choose to break the chain when a stronger Marker or a clear is worth half a placement, then continue normally from that new square.
- Boundaries: Every correct Sudoku placement is always accepted. A disconnected destination costs Points, never a card penalty or a barred square. Near completion or with an awkward Hand, the player can finish any blank correctly rather than being trapped.
- Animation: After one correct placement, a fine short thread settles on that square’s outer corner, outside its numeral. Selecting the next Hand card briefly highlights the prior square’s row, column and box edges with a single low-contrast pulse, then clears those highlights. A demonstration natural placement outside all three units is accepted; a small placement receipt visibly changes 80 to 40 while the board value remains correct. The thread detaches and rests at the new square; all temporary highlights disappear.
- Integration: NEW previous-natural-square context and event-local Boss point factor with an explicit ledger operation. Apply after local placement arithmetic, before that event enters the Turn queue; do not halve the entire held multiplier or any Clear event.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Board.swift:36, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/CatalogueState.swift:12, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:220, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:375, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:88

### The Return Slip
A wrong card returns to your Hand, sealed until next Turn; its normal penalty still applies.

- Tier: Regular
- Exact rule: After an accepted wrong placement, route that exact card back to Hand rather than Pool and mark its UUID sealed until the next Turn. The usual score penalty and any item protections resolve normally. No additional penalty is charged for tapping a sealed card.
- Reset: Sealed IDs clear at the next actual Turn boundary before refill/restriction selection. A sealed card cannot be placed, used for a Hand Clue, or Tossed unless an explicit existing card-release item permits it.
- Counterplay: Avoid speculative placements and use normal reasoning or Clues before committing a risky digit. End Turn to unseal mistakes. An explicit Release tool is a clear item counter.
- Boundaries: If every remaining card is sealed, End Turn remains usable; the Boss never requires a forced wrong attempt. Unsealing does not draw, clone or change the digit. A card already returned by Jade is sealed once, not returned a second time.
- Animation: A demonstration wrong placement uses the normal rejection feedback and score penalty; no wrong digit stays on the board. The same numbered tile slides back into its Hand slot and acquires a narrow folded return-slip corner with a closed padlock; the number stays visible. The player presses End Turn; the slip peels away as the Turn advances exactly once. The original card remains in Hand and becomes selectable again, visibly demonstrating conservation.
- Integration: NEW wrongPlace routing plus sealed-card UUID set, integrated after protection calculation and before existing Pool/Hand routing. Use CatalogueHandCard return helpers, and clear seals at the boundary without changing card identity.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:114, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:160, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/CatalogueState.swift:140, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:237, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:670

### The Orphan Line
At banking, lose 20 queued Points per card left in Hand, up to 100; never below zero.

- Tier: Regular
- Exact rule: At an actual End Turn, after outgoing Turn-end effects settle but before the held multiplier is applied, subtract min(100, 20 × remaining Hand count, queued Points) from the queued Point bank. No debit touches already-banked score or coins.
- Reset: Once per Turn in the scoring .playing phase only. It has no effect during Keep Filling. Empty-Hand automatic banking pays no surcharge.
- Counterplay: Use more of the Hand before banking, spend a permitted Toss to reduce leftovers, or accept a bounded Point cost when banking early is strategically stronger. Judge the visible cost before pressing End Turn.
- Boundaries: All correct placements remain legal. A zero or tiny queue floors at zero; no debt or irreversible number loss is created. Obstacles that disable Tosses leave ordinary placement and End Turn choices available.
- Animation: Two leftover Hand cards send two short ruled-paper tails toward the queued-Points label, making the source of the coming cost visible. A compact receipt beside the existing queue reads “2 left · −40 Points”; the projected bank updates without running any effect twice. End Turn cuts the two orphan tails cleanly; queue 220 becomes 180 before the unchanged held multiplier is shown. Normal bank and refill finish. The tails and temporary receipt disappear, leaving the usual HUD.
- Integration: NEW deterministic pre-multiplier Turn-ledger debit, included identically in pure pendingScore preview and actual bank. Do not mutate pendingBase while merely rendering or inspecting. The expanded selective-multiplier ledger needs explicit point-lot debit allocation, not only a displayed total adjustment.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:617, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:88, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:157, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:213, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:655

### The Serial Publisher
Bank at most a third of the target each Turn. Overflow carries; a Full Clear releases it.

- Tier: Final
- Exact rule: At bank, B is the existing ordinary bank after all eligible/ineligible Mult calculations, excluding direct awards. C=ceil(startingTarget/3). If the board is not full: paid=min(C,carried+B); carried=carried+B-paid. If full: pay carried+B and clear carried. Direct awards retain their existing separate path. Empty banks may release carried score but spend a normal Turn.
- Reset: Puzzle-local carried post-Mult score. Clear after payout/failure; no carry into another puzzle. Cap remains based on starting target.
- Counterplay: Spread banks across Turns; reach a Full Clear to release the remainder immediately. Direct-award builds keep their identity.
- Boundaries: At least three scheduled Turns and positive target. Otherwise exclude before encounter commitment. Full Clear always releases all earned overflow so a completed board cannot strand it.
- Animation: A band around the carried score receipt.
- Integration: Add a pure boss settlement after pendingScoringLedger produces B and before bankPending commits. Store overflow separately from pendingBase/Buff point lots. Full-board release must precede updatePhase.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:157, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:617, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:757, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BookmarkMechanics.swift:309

### The Bindery
Pin your Bookmarks for this Puzzle. Odd Turns read left to right; even Turns read right to left.

- Tier: Final
- Exact rule: Before first accepted action, player may arrange inventory. Pin its owned UUID order for this puzzle. Evaluate held Mult slots forward on odd Turns and backward on even Turns. Every item still runs once. Physical-neighbour effects such as Reader's Circle keep their original pinned physical neighbour, not the traversal neighbour. Passive budgets remain live.
- Reset: Puzzle-local pinned UUID order and alternating traversal. Clear at puzzle end; retain the user's actual inventory order rather than permanently reversing it.
- Counterplay: Choose an initial arrangement that gives useful odd/even banks; schedule conditional Bookmark activation and strong banks for the favourable reading direction.
- Boundaries: Select only with a verified order-sensitive loadout, conservatively a guaranteed additive held-Mult Bookmark plus a guaranteed multiplicative held-Mult Bookmark. Exclude otherwise. If external retirement later removes the relevant pair, preserve survivors and impose no substitute punishment.
- Animation: Binding thread traces the evaluation direction.
- Integration: Keep per-Turn scoring lock; supply pinned evaluation order to pure held-Mult iteration and gate reorderBookmark after puzzle pin. Do not mutate source order to animate. Preserve UUID provenance and physical adjacency semantics.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:74, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:138, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BookmarkMechanics.swift:246, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Inventory.swift:7

### The Embargo
Preparation Buffs must be used before your first placement each Turn.

- Tier: Regular
- Exact rule: Only an explicit preparation allowlist is affected: Peek, Redraw, Overtime, Double Down, Insurance, Second Print, Lucky Dip, Bird Seed, Fresh Ink, Litmus, Paper Crane. After the first accepted placement attempt of a Turn, affected activations are unavailable until next Turn. Tosses, inspection and rejected attempts do not close the window. Reactive/target-dependent newer Buffs such as Rain Check are unaffected.
- Reset: One puzzle-local placementStarted flag, reset each Turn. Existing armed and persistent effects continue normally.
- Counterplay: Prepare before playing; use reactive Buffs later; bank when a fresh preparation window is worth the Turn.
- Boundaries: Require at least one held allowlisted Buff with a legal opening use, otherwise exclude. Never extend the allowlist merely because a newly added Buff is named 'preparation'; target-dependent items need explicit review.
- Animation: One seal on the affected Buff card.
- Integration: Guard affected source UUIDs in BuffRuntime options/phaseAllows/begin and revalidate at commit, without consuming the Buff or mutating cancelled decisions. Mark closed only after an accepted placement resolves.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Buffs.swift:48, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BuffRuntime.swift:16, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BuffRuntime.swift:25, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BuffRuntime.swift:190, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:34

### The Dry Press
After a marked fill, Marker placement bonuses sleep until you fill an unmarked square.

- Tier: Regular
- Exact rule: Start ready. At a committed correct fill, classify its square from the current owned Marker map before filling. If it is unmarked, set ready before scoring that fill. If it is marked and ready, score normally, then set dry after the whole placement/clear transaction. If it is marked and dry, suppress only the positive immediate placement-score operators supplied by that square's own Marker: flat placement Points, a local placement multiplier above ×1, and a positive base-value override. Base digit Points and Bookmark/Buff contributions remain. Do not zero the event. All Line/Full Clear rewards, existing held Mult or future Mult growth (including Rose), promised follow-up rewards from previously activated Markers, coin/draw/Toss/Turn effects, negative/trade-off rules, protection, and Clue/Onyx rules remain unchanged. Clue fills still change ready/dry state by square type, but their existing score-restoration/zeroing rules are exempt from suppression. Wrong or rejected attempts change no ready/dry state.
- Reset: Puzzle-local ready/dry flag, saved across Turns; banking alone does not re-ink. Starts ready each puzzle. A correct unmarked fill re-inks immediately. If no unmarked blank remains after a committed board/Marker-map change, release the dry state and waive further drying while that remains true. Keep Filling imposes no suppression. Resolve an empty-Hand automatic bank only after committing this flag.
- Counterplay: Alternate a valuable marked placement with a plain fill; plan the order before spending a high-value Marker. While dry, all squares remain playable and still earn normal base/other-item points. A Clue on a plain square can safely re-ink without changing its normal scoring rules.
- Boundaries: Require at least two currently blank marked squares with a disclosed positive immediate placement-score effect and at least one currently blank unmarked square; otherwise exclude before committing the encounter. Coin-only/protection-only Markers and dormant marks under givens do not make it eligible. If all plain blanks disappear later, waive drying instead of permanently shutting down the remaining Marker bonuses. A lack of a matching plain-square card never blocks placement: only the specified scoring bonus sleeps.
- Animation: One ink pad switches between inked and dry in the existing boss area.
- Integration: Use run.markers(covering:) for live square classification. Add explicit current-claim immediate-score attribution so dry suppression is a pure operator gate before final placement arithmetic, not a second call to MarkerRuntime or subtraction of the full markerExtraPoints counterfactual. MarkerRuntime.beforePlacement currently mixes follow-up rewards, paid Pledge, counters and direct economy writes; it needs a small explicit effect/state split for this new proposal. Evaluate actual hooks once. When a score-only local trigger is suppressed, do not consume that trigger's finite scoring-use entitlement; continue independent non-score progress normally. Do not offer/charge Pledge's optional coin purchase while its placement bonus is suppressed. Never skip an entire Marker hook, suppress source-wide contributions from another square, set result.zeroed, or run a mutation-bearing counterfactual. Adjust actual receipts and point-lot attribution before their normal recordPoints calls. Show sleeping bonus and protected Clue/non-score exceptions in the existing Marker detail.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Run.swift:197, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Resolver.swift:49, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/MarkerRuntime.swift:67, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/MarkerRuntime.swift:108, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/MarkerRuntime.swift:120, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/MarkerRuntime.swift:173, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/MarkerRuntime.swift:186, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:197, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:227

### The Review Board
Reach the target and complete a row, a column and a box to pass the final review.

- Tier: Final
- Exact rule: Maintain three puzzle-local clear-type bits. Actual new completedUnits on accepted correct placements set row/column/box, including Clue clears; one placement may set all three. Winning requires score>=target AND all required bits. A type with no incomplete unit at encounter start is already approved. A Full Clear approves every type.
- Reset: Puzzle-local three-bit qualification; never clears once earned. Keep normal score banking and all existing rewards.
- Counterplay: Build toward intersecting line completions while scoring; a placement completing two or three unit types is especially valuable. Clues remain useful for qualification.
- Boundaries: Final only. Already-completed/impossible-to-newly-complete unit types are waived from the start and shown approved. If all types are already approved, exclude the boss. Full board cannot remain blocked by this qualification.
- Animation: One approval stamp for the newly satisfied unit type.
- Integration: Observe actual completedUnits, not positiveClearUnits. Add the same qualification predicate to updatePhase, canKeepFilling/win routing and winningTurn recording; do not cash out based on score alone.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:190, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:257, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:757, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BookmarkMechanics.swift:309, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BookmarkMechanics.swift:224

### The Rival Column
Beat your previous bank or lose 20% of this bank, capped at 100 points.

- Tier: Regular
- Exact rule: First positive ordinary bank is untaxed and sets benchmark B. Later positive ordinary bank G pays G if G>B; otherwise deduct min(100,floor(G×0.20)). Then benchmark becomes the current untaxed G, even after a miss. Empty banks neither pay a fee nor reset B. Direct awards are excluded from comparison and deduction.
- Reset: Puzzle-local previous positive ordinary-bank benchmark; no permanent escalation. One comparison per atomic bank.
- Counterplay: Plan rising bank sizes or intentionally spend a smaller Turn to reset the benchmark; direct awards retain their value.
- Boundaries: Needs at least two scheduled Turns. No charge on zero bank, no score debt and no subtraction from previously banked score. Floor rounding is shown in preview. Exclude if one-Turn encounter.
- Animation: An editorial underline on the bank comparison.
- Integration: Transform the pure ordinary-bank settlement after mixed eligible point arithmetic; store the raw gross benchmark before the deduction. Ledger must show fee as a boss settlement, not a fake wrong placement, and direct awards still run separately.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:157, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:617, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:634, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BookmarkMechanics.swift:309

### The Royalty Contract
Each Buff spent raises the starting target by 5%, at most three times.

- Tier: Regular
- Exact rule: Snapshot original target T. On each successfully consumed owned Buff during playing, up to three events, set target=T+n×ceil(0.05×T), n<=3. A cancelled/rejected decision, a preview, an already-armed no-op or a generated inner Encore effect does not count. The outer consumed Encore counts once. Effects still resolve in their usual order.
- Reset: Puzzle-local original target and successful activation count. Target never changes after win/Keep Filling. Each activation's exact target delta is shown before committing.
- Counterplay: Save marginal Buffs; spend strong ones when their expected points or saved Turns exceed the disclosed target increase.
- Boundaries: Require a currently held Buff with a legal puzzle-use path. Exclude otherwise. Maximum added target is the printed three increments; acquiring extra Buffs cannot exceed that cap.
- Animation: A contract tab connecting spent Buff to target.
- Integration: Count only the committed owned-source consumption in BuffRuntime, outside recursive generated effects. Apply a saved target snapshot/count transactionally and re-evaluate score preview; no RNG use or item duplication.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BuffRuntime.swift:321, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BuffRuntime.swift:357, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:547, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Puzzle.swift:297

### The Publicist
Each Bookmark's flat placement or Line Clear bonus pays only once per Turn.

- Tier: Regular
- Exact rule: Per owned Bookmark UUID, permit the first positive flat contribution to a placement or Line Clear receipt each Turn. Suppress only later flat contributions from that copy for those event types. Do not suppress marker/Buff effects, coins, draws, state growth, event multipliers, Full Clear, direct bank awards or held Mult. Claim the budget only when the final event actually scores positive points.
- Reset: Turn-local Set<Bookmark UUID>; reset at normal Turn boundary. Store with receipts for restore/replay safety.
- Counterplay: Use short deliberate banks, save first activation for the most valuable local multiplier, or rely on other scoring channels.
- Boundaries: Require a repeatable flat placement/clear Bookmark such as Local Gossip, Sports Section, Margin Notes or Neighbourhood News, with at least two potential qualifying placements in the puzzle. Otherwise exclude. Nontriggering or zeroed receipts never spend the budget.
- Animation: A once-paid stamp on the responsible Bookmark.
- Integration: Apply a source-attributed flat-contribution gate before local multipliers, and commit UUID budget only after final zeroing/eligibility is known. Support both original Resolver hooks and structured BookmarkMechanics bonuses; never skip entire hooks because they can have non-score side effects.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Resolver.swift:76, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BookmarkMechanics.swift:102, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:203, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:220, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Bookmarks.swift:64

### The Word Count
Item bonuses to ordinary placements share a 150-Point allowance each Turn.

- Tier: Regular
- Exact rule: For an eligible non-Clue placement, let R be the finalized positive placement Points before Turn Mult; let N be the same placement's natural base-only Points with no item effects. Extra=max(0,R−N). Permit min(Extra,remainingAllowance), starting allowance 150. Award min(R,N)+permittedExtra and spend permittedExtra from allowance. Do not alter Line/Full Clear, direct awards, separate Buff challenge awards, coins/draws or held Mult. Clue receipts keep current rules.
- Reset: Turn-local allowance; preview remaining amount in the boss line and receipts. Reset each Turn; no persistence beyond puzzle.
- Counterplay: Spread boosted placements across banks; let a high local multiplier use the budget first; build toward line clears or held Mult.
- Boundaries: Require a loadout whose disclosed possible extra ordinary-placement Points can exceed 150 in a Turn; otherwise exclude. Natural base score cannot be removed by the cap. Validate the candidate conservatively against actual owned effects, not names or arbitrary IDs.
- Animation: A short measuring rule clips the extra-points receipt.
- Integration: Add a boss operation after local placement arithmetic but before append and point-lot recording. Reconcile actual receipt values with originalPlacementPoints/Buff funding classifications so rain-check and selective Mult cannot spend clipped Points. Do not simply lower pendingBase later.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:206, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:227, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:232, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:240, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/BuffRuntime.swift:611

### The Back Page
Base values run backwards: 1 scores 90 Points, 9 scores 10. Item rules still apply.

- Tier: Regular
- Exact rule: For correct placement natural base use 10×(10−printedDigit) instead of 10×printedDigit. Ordinary 1..9 bases become 90,80,70,60,50,40,30,20,10. A marker explicitly overriding placement base, such as Violet's score-as-9 rule, retains its printed item meaning and sets 90 after this boss baseline. All other flat/local/held multipliers apply normally; wrong-placement penalties, Line/Full Clear bases and Clue zeroing are unchanged.
- Reset: Standing puzzle scoring rule only; never mutate board digits, Hand digits or solution.
- Counterplay: Prioritize low digits for valuable bonus squares and Buffs; evaluate items using their actual printed base override.
- Boundaries: Any normal unfinished puzzle with at least one non-5 blank digit. Exclude a degenerate only-5 remainder; never secretly change the rule to force a penalty. This is intentionally a sidegrade challenge, not guaranteed harder for every build.
- Animation: The score ticket flips; the Sudoku digit never changes.
- Integration: Centralize boss-aware natural base calculation and use it consistently for real receipt, marker-only counterfactual, original-placement attribution and previews. Represent inversion as a boss base operation before explicit marker overrides; do not misuse Violet's baseOverride for the boss.
- Sources: /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:197, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:206, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Actions.swift:224, /Users/daniel/NumberClub/Engine/Sources/NumberClubEngine/Scoring.swift:198