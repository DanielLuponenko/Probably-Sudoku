# MESHY-001-R6 — Verify the two R5 corrections

## Task ID

`MESHY-001-R6`

## Agent name

`sonnet-repository-auditor`

## Exact objective

Verify only the two concrete content defects reported by R5 after their
manager-applied JSON/CSV correction, then issue the final combined Phase 1
audit-gate ruling. Do not reopen already-passed counts, references, catalog
reconciliation, or source/visual coverage unless the corrected bytes contradict
them. Make no mutation or implementation.

## Corrected artifact identities

- `COVERAGE_LEDGER.json` SHA-256:
  `ab308882f88ed7c999a2d83c19dc26ef0206c1af4193fc3d1735eeffba007b10`
- `COVERAGE_LEDGER.csv` SHA-256:
  `81acd07acfe8c548cfc29b9103e6a0f59c8189fc375f52989c240ef326fb959a`
- R5 result:
  `docs/meshy-production/reviews/MESHY-001-R5-29ADB9EB-E571-4BDA-A30B-AEA14E342309.json`

Manager revalidation after correction: 208 JSON rows, 208 CSV rows, 46 fields,
identical ordered IDs, and exact JSON/CSV semantic equality for all 13 paper
shop rows.

## Required checks

1. Verify the misleading top-level `completionStatus: APPROVED` field is absent.
   Confirm the replacement fields state
   `requiredRowStateForCompletion: APPROVED` and
   `currentProgramState: BLOCKED`, preserving the allowed row-state contract
   without implying current approval.
2. Read all 13 paper `.shop` rows in both JSON and CSV and verify:
   - only `pp_ivory`, `pp_manila`, and `pp_ledger` cite
     `BookstoreSceneCoordinator.swift:1557-1580` and mention the fixed hanging
     sample;
   - those three also cite the stack path `:1909-1950`;
   - the nine other stack styles cite only `:1909-1950` and contain no hanging
     sample claim; and
   - `pp_utility_roll` cites only `:1951-1967` with roll/tail wording.
3. Confirm JSON/CSV semantics agree for those rows and no row count, ID, status,
   208/206 formula, or authority adjustment changed.
4. Read the R5 `CORRECTION_REQUIRED` result and state whether both and only both
   reported defects are closed.
5. Return `STATUS: PASS` only if the combined MESHY-001/R1/R2/R3/R4/R5/R6
   evidence satisfies CONTRACT-001 Phase 1, subject solely to manager-owned
   model/fingerprint/mechanical validation. This does not approve production
   assets: all 208 ledger rows remain `BLOCKED` and later phases remain open.

## Tool and mutation envelope

Only `Read`, `Grep`, and `Glob` are exposed. No Bash, write/edit, web, build,
generation, launch, paid call, or nested agent is available or permitted. The
manager owns model/fingerprint and byte-level validation.

## Required output headings

- `STATUS`
- `AGENT_RUN_ID`
- `RESOLVED_MODEL`
- `BRANCH`
- `COMMIT_OR_PATCH`
- `COMPLETION_FIELD_CHECK`
- `PAPER_ROW_CHECK`
- `JSON_CSV_PARITY`
- `R5_DEFECT_CLOSEOUT`
- `PHASE1_GATE_RULING`
- `KNOWN_LIMITATIONS`
- `BLOCKERS`

Otherwise return `CORRECTION_REQUIRED` with exact path/row edits. No row may be
promoted; `COMMIT_OR_PATCH` is `NONE (read-only)`.
