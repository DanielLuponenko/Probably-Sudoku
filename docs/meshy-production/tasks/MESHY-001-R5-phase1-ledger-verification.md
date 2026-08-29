# MESHY-001-R5 — Verify the corrected Phase 1 ledger

## Task ID

`MESHY-001-R5`

## Agent name

`sonnet-repository-auditor`

## Exact objective

Independently verify the corrected, populated Phase 1 audit artifacts after the
R4 semantic-overlap correction and the manager's authority adjustments. Return
`PASS` only if the combined MESHY-001/R1/R2/R3/R4/R5 evidence now satisfies the
Phase 1 exit gate in CONTRACT-001 §12. This is an audit-gate pass only: all 208
rows may correctly remain `BLOCKED`, and no production asset becomes approved.

## Inputs to read

Read in full:

- `docs/meshy-production/AUDITED_CANONICAL_LEAVES.json`;
- `docs/meshy-production/COVERAGE_LEDGER.json`;
- the complete header and all 208 data rows of `COVERAGE_LEDGER.csv`;
- `CATALOG_AUDIT.json`, `REFERENCE_INDEX.md`, `DECISIONS.md`, and
  `AGENT_CONTROL_MATRIX.md`;
- the R4 preserved result; and
- CONTRACT-001 §§5.4, 6, 10, 12, and 16–18.

Manager mechanical validation already executed against these exact bytes:

- `AUDITED_CANONICAL_LEAVES.json` SHA-256
  `5be3e4e802de21671621e5c4bc1097bf362dfe5898836e29946017bf26445147`;
- `COVERAGE_LEDGER.json` SHA-256
  `11f0aac297a2febee10ccfd9e1aaeb65e5071ac2a1784f75b33523dba3035947`;
- `COVERAGE_LEDGER.csv` SHA-256
  `cef83ae6cf276006d3ee1fbc9dbdbe3dac029497e721f2f7b8f340b29ed64a49`;
- 208 JSON rows, 208 CSV rows, 46 fields/columns, identical ordered IDs;
- 208 unique IDs, 208 `BLOCKED`, 0 `APPROVED`;
- display classification `28 fixture_unique + 11 merchandise overlap + 2
  effect overlap + 2 dead code = 43`;
- required catalog `72 number + 7 grid + 26 paper + 2 effect = 107`;
- Phase 1 ledger formula `71 environment + 28 unique display fixtures + 107
  catalog replacements + 2 dead-code removal rows = 208`;
- visible approval denominator `206`; and
- three intrinsic material properties excluded from leaf rows:
  `effect.nb_neon.glow`, `effect.nb_laser.glow`, `effect.bd_laser.glow`.

The manager made two explicit authority-preserving corrections to R4:

1. `shop.hangingSample.paper` is `catalog_merchandise_overlap`, not a unique
   fixture asset, because R4 itself required it to reuse the existing
   `pp_ivory`/`pp_manila`/`pp_ledger` lineage and CONTRACT-001 §5.4 forbids
   minting a duplicate semantic paper leaf. The clip remains a unique fixture.
2. `effect.nb_flame.embers.gameplayUse` remains `true` as a requirement, while
   `currentGameplayImplemented` is `false` and the ledger row is `BLOCKED`.
   Current implementation absence cannot reduce the flaming-number scope.

## Required checks

1. Validate both manager corrections against source/contract authority.
2. Verify every one of the 208 JSON rows has all 46 required ledger fields, a
   unique canonical ID, an allowed state, an exact current location/description,
   and a concrete blocking reason.
3. Verify the CSV has the same ordered IDs and semantic values as the JSON; the
   manager's byte/mechanical proof may establish row/column arithmetic, while
   your full read establishes semantic fidelity.
4. Verify the catalog counts, display classifications, exclusions, and exact
   208/206 formulas contain no semantic double count or scope reduction.
5. Verify every visible in-scope item from the combined audit maps to one ledger
   row, and every procedural/placeholder/reachability defect is represented.
6. Verify approved references and all eight catalog views are indexed/reconciled.
7. Distinguish Phase 1 audit completion from production completion: procedural
   D-1/D-2/D-3 rows being `BLOCKED` is expected and must block later asset/release
   gates, but does not mean the audit failed to identify them.

## Tool and mutation envelope

Only `Read`, `Grep`, and `Glob` are exposed. No Bash, write/edit, web, build,
generation, launch, paid call, or nested agent is available or permitted. The
manager owns final model/fingerprint and JSON/CSV mechanical validation.

## Required output headings

- `STATUS`
- `AGENT_RUN_ID`
- `RESOLVED_MODEL`
- `BRANCH`
- `COMMIT_OR_PATCH`
- `ARTIFACT_VALIDATION`
- `AUTHORITY_ADJUSTMENT_REVIEW`
- `LEDGER_COVERAGE_REVIEW`
- `PHASE1_EXIT_CRITERIA`
- `PHASE1_GATE_RULING`
- `KNOWN_LIMITATIONS`
- `BLOCKERS`

Return `STATUS: PASS` only if the corrected artifacts satisfy Phase 1 subject
solely to manager-owned model/fingerprint/mechanical checks. Otherwise return
`CORRECTION_REQUIRED` with exact path/row corrections. No row may be promoted
from `BLOCKED`; `COMMIT_OR_PATCH` is `NONE (read-only)`.
