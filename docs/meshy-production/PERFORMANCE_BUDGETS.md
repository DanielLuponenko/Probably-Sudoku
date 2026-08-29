# Performance budgets

Status: `PARTIAL_BASELINE_CAPTURED_BUDGETS_PENDING_MIN_DEVICE_LOCK`

Budgets cannot be weakened merely because a build fails. Changes require a
recorded product decision.

| Metric | Initial contract target | Baseline | Final budget state |
|---|---:|---:|---|
| Steady shop/gameplay frame rate on minimum supported device | 60 fps | Not yet measured; iOS 17 runtime absent | Unlocked pending physical/minimum-device evidence |
| p95 steady-state frame time | <= 20 ms | Not established; 10-second Time Profiler traces had no >250 ms `potential-hangs` row | Unlocked pending frame-time capture |
| Recurring category-switch hitch after neighbor preload | None | Pending | Unlocked |
| Synchronous disk/network I/O on interaction path | None | Audit pending | Unlocked |
| Runtime network dependency for shipped cosmetic assets | None | Audit pending | Locked requirement |
| Duplicate geometry per Sudoku cell | None; shared resources/instancing | Audit pending | Locked requirement |
| Selected + previous + next preload | Required | Audit pending | Locked requirement |
| Peak memory | Pending minimum-device baseline | iPhone 17 Pro snapshot: gameplay 52 MB footprint/52 MB peak; flat shop 62 MB footprint/65 MB peak | Unlocked pending minimum-device and final-scene evidence |
| App bundle impact | Pending baseline and release constraint | Baseline simulator bundle approximately 52 MB / 53,560 KiB | Unlocked pending asset-manifest estimate |
| Asset load / first-use preparation | Pending baseline | Pending | Unlocked |

Required evidence includes per-asset triangles/textures/memory, bundle impact,
load and preparation times, category-switch and populated-board traces, peak
memory, sustained thermal behavior, and cache hit/miss behavior. On Simulator,
use Time Profiler rather than the SwiftUI Instruments template; the SwiftUI lane
is expected to be empty on Simulator.

## Baseline trace register

| Trace | Scenario | Duration | Finding | Composite SHA-256 |
|---|---|---:|---|---|
| `/Users/daniel/.codex/evidence/NumberClub/KAN-153/baseline-20260829/KAN153-baseline-gameplay-17pro.trace` | Gameplay, iPhone 17 Pro Simulator | 10 s | No `potential-hangs` row above 250 ms; not a p95/frame-rate proof | `b0342b28c5f4f74fac52de777c2712831edbfd13d1d6806d563522715b6e55bd` |
| `/Users/daniel/.codex/evidence/NumberClub/KAN-153/baseline-20260829/KAN153-baseline-clubshop-17pro.trace` | Release-reachable flat shop, iPhone 17 Pro Simulator | 10 s | No `potential-hangs` row above 250 ms; not representative of final 3D load | `145ba1421c055b6c35ecf32930aa0e98c8a1a6dc477f5ede1e3599918d188b09` |
| `/Users/daniel/.codex/evidence/NumberClub/KAN-153/baseline-20260829/KAN153-baseline-gameplay-hitches-17pro.trace` | Animation Hitches attempt | N/A | Instrument unsupported on Simulator; environment limitation only | `b8165adfdfadd1cd4bf136e5d631a1337830f7b6681325ba486e45a76e893663` |

## Full-room 3D stress requirements

The final shop must be profiled with selected, previous, next, and visible
counter specimens loaded; coherent shadows active; selected merchandise
spinning; each 13/7/8 category traversed end-to-end; and repeated category
switches after preload. Reduced Motion is a separate required path, not a way
to hide performance failures in the default presentation. Budgets may be met by
LOD, instancing, shared materials, texture sizing, and deterministic neighbor
preparation, but not by removing browseable products or approved depth/shadows.
