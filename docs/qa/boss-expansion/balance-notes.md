# Expanded boss balance probe — 2026-09-20

The fixed five-slot build narrowly misses three Chapter 9 targets despite filling the entire board. The three-slot build has a much larger late-game deficit. These are concrete tuning signals for the tested builds and seeds, not human win-rate estimates or proof that an encounter is unwinnable. No printed rules, targets or prices were changed in response.

Evidence: [all 40 scenario results](balance-scenarios.json) and [the engine probe](../../Engine/Tests/NumberClubEngineTests/ExpandedBossBalanceTests.swift). The focused run passed in 51.137 seconds (`/tmp/nc-boss-balance-12.log`); the subsequent complete engine gate passed **480 tests, zero failures** (`/tmp/nc-boss-engine-final-14.log`). This does not replace native UI verification.

The probe covers all twenty new bosses with these exact Bookmark orders:

| Build | Bookmarks, left to right |
|---|---|
| Three-slot core | Local Gossip → Op-Ed Column → The Sunday Supplement |
| Five-slot draw and growth | Local Gossip → Op-Ed Column → The Sunday Supplement → Crossword Daily → Rolling Presses |

Both builds use Book 1 (`probably`), no Obstacle, normal starting Hands and Turn budgets, Fresh Ink and Lucky Dip consumed at the opening, and Golden, Crimson, Violet and Sapphire markers on the first four visible blank positions. Resources are explicit fixtures; no Shop acquisition or historical growth is invented. Each generated board has 52 blanks. Regular bosses use Chapter 3, target **8,000**, seed `expanded-boss-balance-chapter-3`; final bosses use Chapter 9, target **512,000**, seed `expanded-boss-balance-chapter-9`. Royalty's two real Buff consumptions increase its Chapter 3 target to **8,800**.

All five Chapter 9 bosses filled all 52 blanks under both builds. Five-slot results:

| Boss | Score / 512,000 | Target reached | Banks | Result |
|---|---:|---:|---:|---|
| Late Courier | 472,260 | 92.24% | 8 | Failed; short by 39,740 |
| Page Cutter | 507,870 | 99.19% | 13 | Failed; short by 4,130 |
| Bindery | 490,215 | 95.75% | 5 | Failed; short by 21,785 |
| Serial Publisher | 523,590 | 102.26% | 5 | Won on Full Clear; no carry left |
| Review Board | 523,590 | 102.26% | 5 | Won with the real Full Clear approval |

The three-slot build reached **74,220 / 512,000 (14.50%)** against Late Courier, Page Cutter, Serial Publisher and Review Board; Bindery reached **70,240 (13.72%)**. Every case exhausted the board before exhausting its Turn budget. This is a severe deficit for a static three-slot Chapter 9 build, and points toward testing realistic build progression before adjusting boss-specific penalties.

All thirty Chapter 3 cases met their targets in one or two banks. Chain Stitcher, Dry Press and Back Page each won after nine placements in one bank under both builds, scoring **9,120**, **10,320** and **9,600**, respectively. Several five-slot cases reached **78,720 against 8,000** after their second bank. This suggests that the same preselected build can be generous early and insufficient late; the probe does not establish when players can actually afford or assemble it.

The policy knows each solution but only plays genuinely held, currently legal cards. It prefers nearly complete visible units, connected Chain Stitcher placements and Dry Press re-inking. It does not optimize future draws, Bookmark order, optional early banking or build acquisition. It uses no mistakes, Clues, Tosses, rescue or Keep Filling, and stops at the first result. Consequently, it barely stresses Return Slip, Embargo or Orphan Line and is not an exhaustive difficulty assessment. Only one board/Pool seed per chapter and two fixed loadouts were sampled.

Every action checked card conservation and unique Hand identities. Bank receipts exactly matched awarded score. Repeating each scenario with saves every third action produced the same final encoded game and metrics as uninterrupted play. A next balance pass should vary real acquired builds, seeds and deliberate counterplay before proposing any rule or target changes.
