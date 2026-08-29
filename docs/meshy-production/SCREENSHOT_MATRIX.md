# Screenshot matrix

Status: `BASELINE_SIMULATOR_CAPTURED_PHYSICAL_AND_MIN_IOS_PENDING`

Every entry must point to a runtime screenshot, device/OS/build identity,
registry/catalog selection, state seed, Reduce Motion/bloom settings, and review
result. Missing is not pass.

## Baseline device set

| ID | Device | OS | Shop | Gameplay | Result |
|---|---|---|---|---|---|
| DEV-COMPACT | KAN85 iPhone SE QA | iOS 26.3.1 | `screenshots/baseline/KAN153-baseline-clubshop-compact.png` | `screenshots/baseline/KAN153-baseline-gameplay-compact.png` | Captured and visually reviewed; flat shop/non-Meshy baseline, not a target pass |
| DEV-17PRO | iPhone 17 Pro | iOS 26.3.1 | `screenshots/baseline/KAN153-baseline-clubshop-standard.png` | `screenshots/baseline/KAN153-baseline-gameplay-standard.png` | Captured and visually reviewed; flat shop/non-Meshy baseline, not a target pass |
| DEV-LARGEST | iPhone 17 Pro Max | iOS 26.3.1 | `screenshots/baseline/KAN153-baseline-clubshop-largest.png` | `screenshots/baseline/KAN153-baseline-gameplay-largest.png` | Captured and visually reviewed; flat shop/non-Meshy baseline, not a target pass |
| DEV-PHYSICAL | Daniel’s iPhone 16 Pro Max | iOS 26.0.1 | Pending | Pending | Signed build passed on Xcode UDID `00008140-0011451A1133001C`; screenshots pending |
| DEV-MIN-IOS | Minimum supported iOS 17 runtime/device | Runtime not installed | Pending | Pending | Blocked by runtime availability |

## Required state templates

Shop: selected, previous, next, locked, owned, equipped, purchase available,
insufficient balance, loading, Reduced Motion, first/middle/last item, longest
localized name, and largest balance.

Gameplay: default, selected/related cells, error, correct-entry where distinct,
pencil marks, light/heavy population, Reduced Motion, bloom off/non-emissive
fallback, and every high-risk paper/grid/number combination.

Contact sheets are mandatory for every complete number style (all digits 1–9),
each grid package, each paper package, and the responsive shop environment.

## Baseline artifact identities

| Screenshot ID | Pixels | SHA-256 | Review finding |
|---|---:|---|---|
| BASE-CLUBSHOP-COMPACT | 750×1334 | `6801ad2c8442bc2a87dadcd3f5482cf18a6edefea8c26a9e34a4510469aae0ad` | Flat vertically scrolling SwiftUI shop; lacks target room depth, physical product presentation, shadows, and spinning proofing platform |
| BASE-CLUBSHOP-STANDARD | 1206×2622 | `8f0d32de40505acaa398da5628e6dc7c14a527ec26cf34b7185eb659ec31ec13` | Same non-conforming flat shop at standard size |
| BASE-CLUBSHOP-LARGEST | 1320×2868 | `5f5afe819050f9f2c1b102e001ee404ff11546ac47a530c99c83fdd7b6ec2c5b` | Same non-conforming flat shop at largest size |
| BASE-GAMEPLAY-COMPACT | 750×1334 | `432a0aa839cd09054569982b292082f55c19a62d8102a0180f92ea6cb1ae2019` | Book/grid baseline; no approved Meshy cosmetic lineage visible |
| BASE-GAMEPLAY-STANDARD | 1206×2622 | `fed0a7d33e160cc42ebd35b01aa0cc1bf21e5fec6fc9e77f85cfa50736ba92da` | Book/grid baseline; no approved Meshy cosmetic lineage visible |
| BASE-GAMEPLAY-LARGEST | 1320×2868 | `ea2f5f326046a63c78744ffb211f9b16f79636ca8c162c3b63f4eaf1c4d2697f` | Book/grid baseline; no approved Meshy cosmetic lineage visible |

These six files establish layout and regression evidence only. Their runtime
seed/launch metadata is not yet complete enough for a final reproducibility
gate; no baseline screenshot is promoted to a target visual approval.

## Final shop additions required by the direct user visual lock

For each required device, the final matrix must include all three real category
denominators (`/13`, `/7`, `/8`), first/middle/last navigation, the selected
item's full 360-degree turntable capture or sequence, stable contact/cast
shadows, and the exact catalog-to-gameplay registry identity. See
`VISUAL_INVARIANTS.md`; the mockup's 5/3/5 demo set is insufficient evidence.
