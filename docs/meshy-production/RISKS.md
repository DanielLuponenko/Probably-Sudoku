# Risks

| ID | Risk | Evidence/impact | Mitigation | State |
|---|---|---|---|---|
| R-001 | Claude OAuth was expired despite `auth status` reporting logged in | Production work and required Sonnet audit could not be accepted | User reauthenticated; structured session `06074628-263F-4B20-BCEF-2316F1A3B4C0` resolved to canonical `claude-sonnet-5`; continue per-run model verification | Resolved; monitor every run |
| R-002 | Existing dirty WIP has unknown authorship/provenance | Cannot be accepted as production merely because it compiles | Preserve byte-for-byte, audit every diff, and have the responsible Sonnet task adopt/revise it with independent review | Open |
| R-003 | `develop` is behind released `main` | Normal PR ancestry may conflict or omit approved bookstore/design work | Integration plan and explicit reconciliation before PR | Open |
| R-004 | Catalog floor implies high Meshy cost | Minimum numbers alone are 72 source assets; grids, papers, effects, displays, and environment add many more tasks | Audit exact leaf count; price current pinned modes; require hardest-case gate before mass generation; max three automatic attempts per spec | Open |
| R-005 | Meshy 7 does not emit an emission map according to current Text-to-3D docs | Flaming/laser packages may need Meshy-authored emissive components/material strategy without hand-authored repair | Validate generation briefs and Meshy-origin effect components in hardest-case phase; reject manual shader/texture substitution | Open |
| R-006 | Current physical build emits orientation warning | Release validation risk | Track as baseline defect; Sonnet QA agent must determine intended full-screen/orientation policy and test devices | Open |
| R-007 | Required iOS 17 minimum-runtime simulator is not installed | Minimum-OS visual/device matrix cannot yet be run locally | Discover installed runtimes and use physical/CI evidence or install the required runtime through approved tooling | Open |
| R-008 | Initial repository audit was intentionally partial | Lower-bound environment/display counts and grouped ledger rows could conceal visible leaves or untested reachability | R1–R7 closed inventory, reference, visual-read, semantic-count, parity, and ledger defects; manager verified model, checksums, and byte-identical checkout | Resolved |
| R-009 | Approved mockup inventory is only a demo subset (5 paper / 3 grid / 5 number) | A literal mockup port would hide 15 of the 28 real products | Lock 13/7/8 truth in `VISUAL_INVARIANTS.md`; test first/middle/last and scripted traversal of every ID | Open |
| R-010 | Full-room 3D, shadows, multiple visible products, and continuous spin can exceed phone budgets | Frame-time, memory, thermal, and bundle regressions could make a visually correct shop unusable | Asset LOD/texture budgets, neighbor-only preparation, instancing, reduced-motion path, simulator traces, and physical-device sustained runs before approval | Open |
| R-011 | Eleven successful historical Meshy tasks are available but were not produced under the complete current ledger contract | Reuse could save credits but silently import incomplete prompts, source GLBs, or provenance | Treat every historical asset as candidate-only; verify task/model/checksums/payload lineage and visual quality row by row before adoption | Open |
| R-012 | The core opening-to-store motion and physical retail stand can be diluted into a flat view swap, carousel, or generic confirmation UI | The initial VISUAL-001 draft omitted the complete direct-user interaction and could have propagated the wrong product architecture into generation and runtime work | Initial draft quarantined; D-009/invariant §0 and accepted R3 briefs encode exact camera/13-7-8/BUY/EQUIP/reverse behavior; later implementation evidence and independent release review remain mandatory | Specification risk closed by D-010; implementation risk open |

## Credit-estimate method

No paid generation has started. The exact estimate is blocked on the catalog and
leaf-component audit. As of the 2026-08-26 Meshy API changelog and current
official pricing, Meshy 7 preview geometry is 20 credits (25 with Ultra),
texturing is 10 credits at 2K/4K or 15 at 8K, and image/multi-image Meshy 7 is
20 untextured, 30 textured, or 35 at 8K. The pipeline engineer must calculate
low/expected/high totals from the actual generation-mode manifest before any
mass generation. Every paid tool invocation requires the user-facing cost
confirmation mandated by the Meshy integration.
