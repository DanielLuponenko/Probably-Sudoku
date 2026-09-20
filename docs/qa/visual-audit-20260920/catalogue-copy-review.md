# Catalogue copy review — 20 September 2026

The audit corrected **66 full descriptions**: 22 Bookmarks, 16 Markers and 28 Buffs. Boss Draft also received one short-summary correction. Changes use the existing `ItemDef.text` and bundled `CatalogueDetails.effect` / `shortEffect` sources, so visible details and VoiceOver receive the same rules. No separate presentation mapping was added.

## Findings and fixes

Developer wording had reached inventory descriptions, Shop details, skip-reward accessibility labels, Buff details and marker inspection. Examples included `effectiveHandSize`, “atomic action”, “existing lineClear hook”, “claim record”, “normal proposed price” and “legal token transfer”. A second pass removed less obvious jargon such as “locked loadout”, “local multipliers”, “orthogonally” and “normal score-zeroing rules”.

Examples of the resulting player language:

- **Careful Cut:** return 1–3 tossable cards without spending a Toss; draw no replacements; an empty Hand ends the Turn.
- **Inventory Count:** counts update as cards move and disappear at Turn end.
- **Local Gossip:** +30 Points before multipliers, with explicit Clue/Onyx and Boss scoring exceptions.
- **Second Print:** double one scoring clear, checking row, then column, then box when a placement completes several.
- **Rebind / Transposition:** move or swap selected marked squares while retaining their progress and used effects.

## Preserved meaning

- **Clues / Onyx:** ordinary Clue placement and clear scoring restrictions remain. Onyx restores placement Points only; it does not restore clear Points or override a Boss that prevents scoring. Double Down and Second Print wait for a qualifying non-Clue score. Tight Deadline and Exchange Rate still exclude Clue-derived Points, including Onyx-restored Points.
- **Keep Filling:** resource effects that already work there still do. Azure, Sapphire, Copper and Bird Seed now state this plainly. Frozen score and all item activation restrictions are unchanged; wording does not grant additional Keep Filling scoring.
- **Ordering:** flat additions still precede multipliers. Bookmark +Mult and ×Mult still apply in the saved scoring order; “when this Bookmark scores” replaces “at its locked slot”. Second Print preserves the actual row → column → box check order. Direct bonuses remain unmultiplied where specified.
- **Durations, identity and limits:** Turn/Puzzle/Chapter/Book duration, repeat limits, prices, rarity, IDs, hooks, ownership, card conservation and saved state were not changed. “Chapter” is the existing player-facing name for engine Level. Marker relocation retains progress; recovery returns the original Buff. All `limit` and `trigger` metadata fields were preserved exactly.

## Comparison with the archived approved source

The input archive at `docs/catalogue/2026-09-20/catalogue.json` and `catalogue.md` remains unchanged. Comparing the 66 entries below against that archive confirms that their names, categories, rarity, prices, trigger/limit fields, artwork addresses and implementation notes are unchanged. Their full-effect wording differs intentionally. The bundled JSON and Swift definitions match each other.

Other pre-existing differences from the archive are outside this pass: Jade’s full effect and the Finale / Counteroffer short summaries. This audit preserved those corrections, including Jade’s explicit warning that it does **not** cancel score or Boss coin penalties. Boss Draft’s short summary now says “random alternative” instead of “seeded alternative”.

## Residual technical metadata

The bundled JSON still contains developer-oriented `limit` text, for example “Existing engine permits use during Keep Filling”, “One pure copied additive operation” and references to claim coordinates or original instances. **These fields are not currently displayed or read aloud by the App.** A source audit of every App `CatalogueDetails` consumer found only short descriptions and artwork/category/code access; no consumer reads catalogue `limit` or `trigger`. The similarly named `operation.trigger` in score presentation is a scoring event, not this metadata.

`implementationNotes` are also retained in JSON, but `CatalogueDetails` does not decode that field. No residual metadata was edited in this pass. If a future catalogue UI begins displaying `limit` or `trigger`, those fields need a separate player-copy review before release.

## Verification

`WRITE_REFERENCE=1 swift test --package-path Engine --filter 'CatalogueMetadataTests|GenerateReference'` passed **3 tests, 0 failures**. This checks all 140 runtime definitions against bundled metadata, screens full and short descriptions for known implementation-language regressions, and regenerates/verifies `REFERENCE.md`. Log: `/tmp/nc-player-copy-gate.log`. `git diff --check` passed. This was a copy-only gate; it was not a new full gameplay test run.

## Corrected full-description IDs

### Bookmarks (22)

| ID | Item |
| --- | --- |
| `bm_local_gossip` | Local Gossip |
| `bm_sports_section` | Sports Section |
| `bm_society_pages` | Society Pages |
| `bm_op_ed` | Op-Ed Column |
| `bm_editorial_board` | Editorial Board |
| `bm_front_page_splash` | Front Page Splash |
| `bm_letters_to_the_editor` | Letters to the Editor |
| `bm_rolling_presses` | Rolling Presses |
| `bm_syndication` | Syndication |
| `bm_stop_the_presses` | Stop the Presses |
| `bm_the_sunday_supplement` | The Sunday Supplement |
| `bm_extra_extra` | Extra! Extra! |
| `bm_help_wanted` | Help Wanted |
| `bm_margin_notes` | Margin Notes |
| `bm_neighbourhood_news` | Neighbourhood News |
| `bm_serial_story` | Serial Story |
| `bm_double_column` | Double Column |
| `bm_carryover` | Carryover |
| `bm_number_index` | Number Index |
| `bm_overflow_column` | Overflow Column |
| `bm_advance_payment` | Advance Payment |
| `bm_readers_circle` | Readers' Circle |

### Markers (16)

| ID | Item |
| --- | --- |
| `mk_golden` | Golden Marker |
| `mk_azure` | Azure Marker |
| `mk_emerald` | Emerald Marker |
| `mk_onyx` | Onyx Marker |
| `mk_silver` | Silver Marker |
| `mk_sapphire` | Sapphire Marker |
| `mk_rose` | Rose Marker |
| `mk_copper` | Copper Marker |
| `mk_violet` | Violet Marker |
| `mk_exchange` | Exchange Marker |
| `mk_prism` | Prism Marker |
| `mk_fork` | Fork Marker |
| `mk_ledger` | Ledger Marker |
| `mk_hearth` | Hearth Marker |
| `mk_patina` | Patina Marker |
| `mk_bounty` | Bounty Marker |

### Buffs (28)

| ID | Item |
| --- | --- |
| `bf_peek` | Peek |
| `bf_redraw` | Redraw |
| `bf_overtime` | Overtime |
| `bf_double_down` | Double Down |
| `bf_insurance` | Insurance |
| `bf_second_print` | Second Print |
| `bf_bird_seed` | Bird Seed |
| `bf_paper_crane` | Paper Crane |
| `bf_careful_cut` | Careful Cut |
| `bf_collation` | Collation |
| `bf_inventory_count` | Inventory Count |
| `bf_proof_sheet` | Proof Sheet |
| `bf_rebind` | Rebind |
| `bf_transposition` | Transposition |
| `bf_release_note` | Release Note |
| `bf_single_issue` | Single Issue |
| `bf_detour` | Detour |
| `bf_boss_draft` | Boss Draft |
| `bf_tight_deadline` | Tight Deadline |
| `bf_collateral` | Collateral |
| `bf_exchange_rate` | Exchange Rate |
| `bf_return_receipt` | Return Receipt |
| `bf_clean_finish` | Clean Finish |
| `bf_cross_cut` | Cross-Cut |
| `bf_open_bracket` | Open Bracket |
| `bf_new_edition` | New Edition |
| `bf_carbon_receipt` | Carbon Receipt |
| `bf_rain_check` | Rain Check |
