# Finite final-boss balance probe

Independent engine review, 20 September 2026. 72 runs: six final bosses × three board/Pool seeds × four catalogue builds. All runs use production boss rules, normal finite opening Hands and Pool, real placements, real automatic/manual banks, legal two-slot Buff consumption and periodic save/resume. No points, Mult, bonus draws or extra turns are injected.

The placement policy knows the solution and prefers visible nearly complete units. This measures attainability and mechanical consistency, not human difficulty, shop acquisition odds or win rate. Split Edition commits each new turn to the larger remaining deficit and banks when it can finish one edition. No rewarded rescue is used.

## Builds

- **Basic (23 listed coins):** Local Gossip → Op-Ed Column → Sunday Supplement. No Markers or Buffs.
- **Developed (82 listed coins):** Front Page Splash → Rolling Presses → Syndication → Local Gossip → Sunday Supplement. Syndication has 12 previous wins since purchase.
- **Clear engine (89 listed coins):** Front Page Splash → Rolling Presses → Syndication → Extra! Extra! → Sunday Supplement. Syndication has 18 previous wins since purchase.
- **Number collection (89 listed coins; no Syndication):** Front Page Splash → Number Index → Sunday Supplement → a separately owned Sunday Supplement → Rolling Presses. Number Index has earned its maximum +10 from five previous puzzles placing every digit naturally. Two Sunday copies have separate physical identities.
- All three five-slot builds each own Crimson and Golden Markers covering three public opening blanks each, plus Fresh Ink and Lucky Dip. Both Buffs are spent through their production actions before play. Mark positions use the first six visible blanks, never hidden solution digits.
- Costs include all listed Bookmarks, two Markers and two Buffs. Three-slot/five-slot limits are respected. Prior growth is below the 26 available wins before the last boss; obtaining these particular shop items is not simulated.

## Results

| Final boss | Basic wins | Developed wins | Clear-engine wins | Developed score/target | Clear-engine score/target |
|---|---:|---:|---:|---:|---:|
| Final Draft | 0/3 | 3/3 | 3/3 | 1.05–1.59 | 1.09–1.53 |
| Executive Editor | 0/3 | 3/3 | 3/3 | 1.03–1.28 | 1.12–1.29 |
| Bindery | 0/3 | 3/3 | 3/3 | 1.26–2.23 | 1.02–1.67 |
| Review Board | 0/3 | 3/3 | 3/3 | 1.02–1.80 | 1.20–2.26 |
| Split Edition | 0/3 | 3/3 | 3/3 | 1.18–1.47 | 1.30–1.72 |
| Last Edition | 0/3 | 3/3 | 3/3 | 1.17–2.83 | 1.02–3.28 |


## Independent build route without Syndication

| Final boss | Number-collection wins | Score/target |
|---|---:|---:|
| Final Draft | 3/3 | 1.01–2.02 |
| Executive Editor | 3/3 | 1.08–1.56 |
| Bindery | 3/3 | 1.51–2.44 |
| Review Board | 3/3 | 1.18–2.08 |
| Split Edition | 3/3 | 1.34–1.60 |
| Last Edition | 3/3 | 1.25–3.57 |

This additional 18-run route removes Syndication entirely and replaces its growth with Number Index and a second Sunday copy. It still assumes a developed five-slot build and specific shop acquisitions. It demonstrates one alternative attainable scoring route, not that every five-item loadout can win every final.

All 72 runs conserved the finite digit multiset and unique held identities, terminated within the bounded action budget, respected the bank limit, and required the real boss victory conditions. Review Board completed its three unit categories; Split Edition funded both separate targets.

Final Draft remains the strongest numerical check: its 2,048,000 target took 6–7 banks for the developed build. The first 64,000 Last Edition target was comparatively forgiving. After review it was raised to 128,000 (one quarter of the normal boss target), and all 54 probes were rerun. The lowest developed result is 1.17× this revised target and the lowest clear-engine result 1.02×, leaving much less margin for a weak sole bank. This is still solution-assisted placement, not a human win-rate estimate.

Raw per-run resources, score, objective progress and remaining blanks: [final-balance.json](final-balance.json).

Verification: 11 independent test methods passed, including 72 finite balance runs and 39 historical active-boss save round trips. The final coefficient rerun is recorded in `/tmp/nc-boss-roster-independent4.log`.
