# MESHY-001-R4 — Reconcile normalized canonical leaves

## Task ID

`MESHY-001-R4`

## Agent name

`sonnet-repository-auditor`

## Exact objective

Perform the final audit reconciliation against the manager-normalized,
machine-validated arrays in `docs/meshy-production/AUDITED_CANONICAL_LEAVES.json`.
Resolve the only remaining R3 limitation: whether any of the 43 display rows
conceptually duplicates a catalog/effect row and whether the 110 catalog rows
follow the Phase 1 leaf-ledger rules. Return an exact corrected row model or
verify the existing 224-row model. Do not repeat completed reference reads,
visual inspection, or source sweeps. Make no mutation or implementation.

## Inputs

Read in full:

- `AUDITED_CANONICAL_LEAVES.json` (pretty-printed extraction of the R1/R3 JSON);
- `COVERAGE_LEDGER.csv` and `COVERAGE_LEDGER.json` field/status contracts;
- the MESHY-001-R1 and R3 preserved results;
- CONTRACT-001 §§2, 5.4, 6, 10, 12, 16–19;
- `App/Views/MainMenu/BookstoreSceneCoordinator.swift:1584-1813` and
  `:1880-2130`;
- `App/Views/CosmeticSkinRendering.swift` and `App/Views/BookView.swift` only
  where needed to map catalog/effect leaves.

The manager has mechanically proven:

- 71 environment entries, instance sum 1,893;
- 43 display entries, reachable instance sum 101;
- 110 catalog entries: 72 numbers, 7 grids, 26 papers, 5 effects;
- 224 syntactically unique IDs across all three sets; and
- zero literal ID collisions.

These mechanical facts do not prove semantic non-overlap. You must perform that
review from names, line ranges, source ownership, and the contract.

## Required reconciliation

### Display classification

Return valid compact JSON `DISPLAY_ROW_CLASSIFICATION` with exactly 43 entries.
For every display ID, assign exactly one class:

- `fixture_unique` — physical counter/plinth/sign/lamp/control/support art not
  represented by a catalog row;
- `catalog_merchandise_overlap` — the current generic merchandise leaf is
  superseded by per-product catalog rows and must not be added to the grand
  total;
- `catalog_effect_overlap` — the current generic effect leaf is represented by
  an effect catalog row and must not be added again;
- `dead_code_unique` — not currently visible/reachable but retained as a
  defect/removal row, outside the visible-art total; or
- `other_unique` with a required one-sentence justification.

### Catalog classification

Return valid compact JSON `CATALOG_ROW_CLASSIFICATION` for all 110 input IDs or
a corrected replacement array. For each row state whether it is a distinct
required canonical art leaf, a package/non-leaf, or a duplicate of another
canonical ID. Specifically rule on:

- whether one grid canonical asset may have both `shopUse` and `gameplayUse`
  without a second row;
- whether each paper `.shop`/`.gameplay` pair represents genuinely distinct
  deliverables or should instead be decomposed/reused differently;
- whether the five effect IDs are actual visible leaf components rather than
  four parent package labels; and
- whether number digits already cover every shop/gameplay number glyph.

### Exact Phase 1 total

Keep three concepts separate:

1. current generic visible implementation leaf types;
2. exact required catalog assets/packages from the source catalog; and
3. Phase 2 production leaves that may be added only after the asset schema
   decomposes a future Meshy package.

Phase 1 still requires an exact calculated audited current minimum. Do not add
the generic procedural merchandise leaf and its required per-product
replacement twice. Do not count a whole screen as an art asset. Do not invent
future children of a not-yet-designed Meshy package. Return:

- `visibleCurrentLeafRows`;
- `requiredReplacementCanonicalRows`;
- `nonVisibleDeadCodeRows`;
- `phase1CoverageLedgerRows`; and
- an exact formula and inclusion/exclusion rule.

If the existing 224 is correct, prove it. If it is not, return
`CORRECTED_CANONICAL_LEAVES` as valid compact JSON with unique IDs and an exact
summary that the manager can mechanically transcribe.

## Tool and mutation envelope

Only `Read`, `Grep`, and `Glob` are exposed. No Bash, write/edit, web, build,
generation, launch, paid call, or nested agent is available or permitted. The
manager owns model and fingerprint verification.

## Acceptance criteria

1. All 43 display and all 110 catalog input rows receive an explicit class.
2. Semantic overlaps are resolved, not hidden by distinct string IDs.
3. All returned JSON parses, IDs are unique within each output, and counts plus
   formulas are exact.
4. The ruling is grounded in source path:line and CONTRACT-001, including
   Phase 1 versus Phase 2 boundaries.
5. `STATUS: PASS` means the combined MESHY-001/R1/R2/R3/R4 repository audit now
   satisfies the Phase 1 audit evidence gate, subject only to the manager's
   independent model/fingerprint and JSON checks. It does not approve any
   production asset.
6. Otherwise return `STATUS: CORRECTION_REQUIRED` with complete replacement
   JSON; do not return another vague partial.

## Required output headings

- `STATUS`
- `AGENT_RUN_ID`
- `RESOLVED_MODEL`
- `BRANCH`
- `COMMIT_OR_PATCH`
- `DISPLAY_ROW_CLASSIFICATION`
- `CATALOG_ROW_CLASSIFICATION`
- `SEMANTIC_OVERLAP_FINDINGS`
- `EXACT_PHASE1_TOTAL`
- `CORRECTED_CANONICAL_LEAVES`
- `PHASE1_GATE_RULING`
- `KNOWN_LIMITATIONS`
- `BLOCKERS`

Use `NONE` for `CORRECTED_CANONICAL_LEAVES` when 224 is verified unchanged.
`COMMIT_OR_PATCH` must be `NONE (read-only)`.
