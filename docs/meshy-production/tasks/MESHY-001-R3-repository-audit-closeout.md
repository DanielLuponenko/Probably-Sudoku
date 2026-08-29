# MESHY-001-R3 — Close the final repository-audit gaps

## Task ID

`MESHY-001-R3`

## Agent name

`sonnet-repository-auditor`

## Dependencies

- MESHY-001 discovery result.
- MESHY-001-R1 exact 71-environment/43-display arrays.
- MESHY-001-R2 primary catalog/source/image re-audit, run
  `2C274212-A30E-497F-9A9A-1D6A7DFA014A`, preserved at
  `docs/meshy-production/reviews/MESHY-001-R2-2C274212-A30E-497F-9A9A-1D6A7DFA014A.json`.

## Exact objective

Close only the residual readable gaps explicitly reported by R2. Perform full
linear reads of the four rendered HTML wrappers, all 3,561 lines of the scene
coordinator, all 314 lines of the design language, and all eight SVG sources;
visually open the six baseline screenshots; freshly close the D-9 and
environment/display corroboration gaps; and issue an exact, contract-grounded
canonical-row accounting ruling. Make no mutation or implementation.

## Mandatory full linear reads

Use sequential `Read` calls from line 1 through the actual final line; targeted
`Grep`, structural equivalence, or a prior run's claim does not satisfy this
task:

| Path | Manager-observed line count |
|---|---:|
| `bookstore-aisle-rendered.html` | 2,485 |
| `clipping-choice-rendered.html` | 1,720 |
| `opening-bookstore-rendered.html` | 2,036 |
| `sudoku-shop-depth-rendered.html` | 2,191 |
| `App/Views/MainMenu/BookstoreSceneCoordinator.swift` | 3,561 |
| `DESIGN_LANGUAGE.md` | 314 |
| `Artwork/studio-logo-full.svg` | 21 |
| `Artwork/studio-logo-horizontal.svg` | 20 |
| `Artwork/studio-logo-mono-dark.svg` | 9 |
| `Artwork/studio-logo-mono-light.svg` | 9 |
| `Artwork/studio-mark-mono-on-dark.svg` | 5 |
| `Artwork/studio-mark-mono-on-light.svg` | 5 |
| `Artwork/studio-mark-mono.svg` | 4 |
| `Artwork/studio-mark.svg` | 14 |

The HTML paths are under
`/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/`.
All rendered files remain evidence/candidates according to their corresponding
source approval. Reading a wrapper may not promote an unapproved reference.

## Mandatory visual opens

Open each file with `Read` as image content and give one direct visual
observation; relying on `BASELINE.md`, checksums, or the similarly named design
language capture does not satisfy this task:

- `docs/meshy-production/screenshots/baseline/KAN153-baseline-clubshop-compact.png`
- `docs/meshy-production/screenshots/baseline/KAN153-baseline-clubshop-standard.png`
- `docs/meshy-production/screenshots/baseline/KAN153-baseline-clubshop-largest.png`
- `docs/meshy-production/screenshots/baseline/KAN153-baseline-gameplay-compact.png`
- `docs/meshy-production/screenshots/baseline/KAN153-baseline-gameplay-standard.png`
- `docs/meshy-production/screenshots/baseline/KAN153-baseline-gameplay-largest.png`

The SVG files are out-of-scope studio branding unless their content proves
otherwise, but their complete source must still be read and classified.

## Exact canonical-row ruling

R1 proposed 231; R2 summed 230. Resolve this from primary authority rather
than selecting a convenient number:

1. Read CONTRACT-001 §§2, 5.4, 6, 10, 14, 17–19 and the exact
   `COVERAGE_LEDGER.csv`/`.json` field contract.
2. A coverage row is keyed by `canonical_asset_id` and already has both
   `shop_use` and `gameplay_use`; do not double-count the same canonical asset
   solely because both booleans are true.
3. Count distinct paper shop merchandise and gameplay surfaces separately when
   they are genuinely different deliverables, as CONTRACT-001 requires.
4. Treat a whole SwiftUI screen or a launch/reachability defect as a defect/path
   record, not automatically as a canonical art asset. If it contains a unique
   visible art leaf not otherwise inventoried, count that leaf by ID.
5. Confirm whether the turntable is already represented inside the R1 43-entry
   display array before considering any additional row.
6. Decompose the four animated effect packages (`nb_neon`, `nb_laser`,
   `nb_flame`, `bd_laser`) into every distinct visible current/proposed
   canonical effect leaf discoverable from source. A parent package is not a
   leaf merely because it has a name. Reuse may share a canonical ID only when
   CONTRACT-001 §5.4 permits it.
7. Return compact valid JSON `CATALOG_CANONICAL_LEAVES` covering all required
   number digits, grid assets, paper shop/gameplay deliverables, and effect
   leaves, with unique IDs and `shopUse`/`gameplayUse` booleans. Do not repeat
   the R1 environment/display arrays.
8. Return exact integers for catalog canonical leaves, environment leaves,
   display leaves, grand canonical rows, and the formula. If production schema
   design can legitimately add future leaves, label this the exact audited
   current minimum, not the final Phase 2 manifest; do not use a lower bound or
   invent an unobserved asset.

## Tool and mutation envelope

Only `Read`, `Grep`, and `Glob` are exposed. No Bash, write/edit, web, build,
generation, launch, paid call, or nested agent is available or permitted. The
Codex manager owns pre/post fingerprint and model verification.

## Acceptance criteria

1. Every mandatory text path is read linearly through its final line and listed
   in `FULL_READ_PROOF` with the exact line range.
2. All six mandatory PNGs are directly visually opened and listed in
   `BASELINE_VISUAL_PROOF` with independent observations.
3. The full coordinator reread confirms or corrects R1's 71/1,893 and 43/101
   counts and identifies any omitted current visible leaf by exact path:line.
4. The full design-language reread freshly resolves/reconfirms D-9 against the
   contract and `DECISIONS.md`.
5. All four rendered wrappers receive approval classification and full-source
   comparison findings; candidates remain unapproved.
6. `CATALOG_CANONICAL_LEAVES` parses as JSON, has unique IDs, and supports one
   exact audited current-minimum grand total under the rules above.
7. Every R2 unchecked checklist item is now checked. No readable file or visual
   asset is deferred. Manager fingerprint inability is not a task blocker.
8. Return `STATUS: PASS` only if criteria 1–7 pass. Otherwise return `PARTIAL`
   with exact residuals. This task never marks a production asset `APPROVED`.

## Required output headings

- `STATUS`
- `AGENT_RUN_ID`
- `RESOLVED_MODEL`
- `BRANCH`
- `COMMIT_OR_PATCH`
- `FULL_READ_PROOF`
- `BASELINE_VISUAL_PROOF`
- `RENDERED_REFERENCE_CLOSEOUT`
- `SCENE_COUNT_CORROBORATION`
- `DESIGN_CONFLICT_CLOSEOUT`
- `CATALOG_CANONICAL_LEAVES`
- `EXACT_ROW_FORMULA`
- `R2_GAP_CLOSEOUT`
- `KNOWN_LIMITATIONS`
- `BLOCKERS`

`COMMIT_OR_PATCH` must be `NONE (read-only)`. Keep output compact by referencing
the preserved R1 arrays instead of reprinting them.
