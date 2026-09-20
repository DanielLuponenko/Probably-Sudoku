# Boss roster redesign

22 encounters for newly started Books: 16 regular encounters and 6 final encounters. The remaining historical boss IDs remain decodable and playable in existing saves. This matrix describes mechanical differences and the visual signal each needs; implementation and recording evidence are tracked separately.

## Regular encounters

| Encounter | Exact mechanical pressure | Decision it creates | Visual identity | Relative pressure |
| --- | --- | --- | --- | --- |
| The Fog | Conceals board markers, including inspection information. | Play around uncertain marker rewards instead of using a visible marker route. | Mist conceals marks while numbers and Sudoku boundaries remain readable. | Low–medium; only meaningful with exposed markers. |
| The Mirror | Row, column and box clear score bonuses are zero; full-clear scoring remains. | Build placement value rather than depending on unit-completion score. | Reflected clear receipt loses its score while placement receipts remain. | Medium against clear builds. |
| The Erratum | No Toss allowance. | Commit scarce held digits or bank for refill instead of filtering freely. | Crossed-out Toss tool; hand and placements remain ordinary. | Low–medium. |
| Natural Born Accountant | Each attempted placement costs one coin, even below zero. | Weigh speculative moves and extra placements against the next Shop. | A coin visibly leaves the wallet on accepted attempts. | Medium economic pressure. |
| Tik Tak | Four minutes for the puzzle. | Spend thinking time deliberately; trade precision against speed. | Physical clock with visible time and low-time urgency. | High for slow solving; distinct from a turn limit. |
| Garry the Gray | One box is barred per turn, unless that would bar every remaining blank. | Shift to a different area and prepare for the next turn's opening. | Bricks land individually in the barred box with brief impact dust. | Medium spatial access pressure. |
| The Bookends | Only lowest/highest independently available digits may be placed; all copies of an extreme are eligible. | Consume an extreme to expose useful middle digits. | Brass LOW/HIGH brackets; interior cards visibly wait. | Medium hand-order puzzle. |
| The Rebinder | At banking, all leftover cards return to the finite Pool before a fresh Hand is drawn. | Spend useful held cards now rather than reserve them across turns. | Leftover cards fold back toward the Pool, followed by the replacement hand. | Low–medium; opposite hand strategy to Erratum. |
| The Chain Stitcher | A natural correct fill earns full placement points if it shares row, column or box with the last natural correct fill; otherwise half. Clues do not move the anchor. | Plan a connected placement route using the actual held digits. | Gold eligible wells and a brief stitch between committed placements. | Medium spatial scoring pressure. |
| The Return Slip | A wrong card returns as the same physical copy, sealed for this turn; the normal mistake penalty still applies. | A speculative move can reduce the useful hand without losing the digit forever. | Returned tile receives a red seal that releases next turn. | Low–medium risk/recovery pressure. |
| The Dry Press | Consecutive marked fills suppress immediate marker placement bonuses until an unmarked fill; if no unmarked blanks remain, the press stays available. | Alternate marked rewards with unmarked placements. | Ink pad visibly changes between wet and dry. | Medium; qualified marker loadouts only. |
| The Back Page | Natural base values reverse: 1 gives 90 points, 9 gives 10. Explicit value overrides retain their own rule. | Prioritize low digits for score without changing Sudoku correctness. | Held cards show their reversed base price. | Low scoring-priority inversion. |
| The Royalty Contract | Each Buff used raises the starting target by 5%, at most 3 times. | Spend a Buff only when its benefit justifies the added target. | Contract accumulates up to 3 seals and moves the target visibly. | Medium; usable Buff required. |
| The Rival Column | A bank that does not beat the preceding bank loses 20% of that bank, capped at 100 points. | Stage banks so score grows rather than spending the strongest sequence first. | Previous receipt sets a visible benchmark beside the new receipt. | Low–medium tempo pressure. |
| The Publicist | Each Bookmark copy's flat placement or clear bonus pays once per turn; other types of effect remain active. | Spread scoring over turns or lean on other types of bonuses. | Each affected Bookmark visibly spends its per-turn print entitlement. | Medium; repeatable flat-bonus loadout required. |
| The Collateral | Target is 50% higher. Before the turn's first accepted action, optionally pledge one exact hand-card copy for+2 Mult before Bookmarks. It returns at banking before refill. | Give up access to a useful digit for the rest of this turn to strengthen that bank. | The selected tile enters an envelope; its seal displays+2 Mult; the same tile returns. | Low–medium voluntary tradeoff. |

## Final encounters

| Encounter | Exact mechanical pressure | Decision it creates | Visual identity | Relative pressure |
| --- | --- | --- | --- | --- |
| The Final Draft | Four times the chapter's ordinary boss target. | A full-build strength test: prepare enough points and Mult before entering. | A four-part target/press mechanism communicates the scale before play. | Very high; the roster's single pure numerical build check. |
| The Executive Editor | One triggered Bookmark is disabled each turn; passive upgrades are retained. | Adapt placement and bank order to the temporarily unavailable source. | The sleeping Bookmark receives a physical closed-editor cover that moves between turns. | High; requires a suppressible Bookmark to be meaningful. |
| The Bindery | First accepted action pins Bookmark order; odd turns read forwards, even turns backwards. | Arrange additive and multiplicative sources for alternating evaluation directions. | Physical binding and a direction cue across the actual Bookmark row. | High; requires both additive and multiplicative sources. |
| The Review Board | Meet the score target and complete at least one row, one column and one box. | Route scarce held digits toward three completion requirements while scoring. | Three approval slips stamp separately on actual completed units. | High structural objective. |
| The Split Edition | Select an edition before the first accepted turn action. All direct awards and that turn's bank go to that edition. Both separate half-targets must be met; surplus in one cannot satisfy the other. | Allocate strong/weak turns between two objectives and avoid overfunding one. | Two distinct page stacks with separate progress; a clip marks the committed destination. | High resource allocation. |
| The Last Edition | Opening Hand is 4 larger. Target is one quarter of the ordinary boss target, rounded up. Only one bank is allowed, including automatic banks. No Overtime, rewarded rescue or Keep Filling. | Build one decisive sequence and manage the last hand card because exhausting the Hand banks. | One sheet enters a press; a single-bank commitment and lever make the ending legible. | Very high commitment; target calibrated separately. |

## Distinctness and fairness checks

- Only Bookends controls ordinary digit order; the other five historical hand-order variants leave the new selection pool.
- Only Garry uses changing board barricades. Chain changes value, not access; Review Board changes the completion objective.
- Fog, Dry Press, Publicist, Royalty, Executive Editor and Bindery need relevant owned sources. No item-dependent encounter should be selected as an inert regular puzzle.
- Choices do not inspect the hidden solution. Placement rules, card identities, finite Pool conservation and invalid-action atomicity remain engine-owned.
- Book encounter history should prevent repeats while unused eligible bosses remain. Consecutive encounters should avoid the same pressure family where alternatives exist.
- Newly selected bosses are fixed at announcement. Shopping, selling, overlays and resume must not silently choose a different encounter.
- Old announced encounters and active historical runs retain their version's mechanics and selection roster.
- Collateral must preserve the exact UUID across duplicate digits, redraws, bank return and save/resume. The reserved card is part of conservation and cannot be discarded, duplicated or pledged twice.
- Split Edition must route direct scores as well as banks. Full Clear cannot bypass a deficient edition. Invalid or mid-turn switches must not change any state.
- Last Edition must enforce its one-bank limit through manual bank, automatic empty-Hand bank, full clear, Overtime and rewarded-rescue paths. A target met before the sole bank must still finish consistently.

## Balance interpretation

The last chapter's Probably Book ordinary boss target is 512,000. Last Edition therefore starts at 128,000, with 11 cards for this Book. A basic+Mult Bookmark and one multiplicative Bookmark is insufficient; a developed late-game build must supply substantially larger Mult, marker value or legitimate bonus draws. This is a deliberate final-build requirement, but simulation must report the actual build and finite resources rather than describe it as universally winnable.

Deterministic probes know the solution and test whether mechanics terminate and conserve resources. They do not establish human win rates, animation readability or difficulty acceptance; those require actual play and recorded UI review.
