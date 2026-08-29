# MESHY-001-R7 — Verify the remaining parallel paper-path correction

## Task ID

`MESHY-001-R7`

## Agent name

`sonnet-repository-auditor`

## Exact objective

Verify only the remaining instance of R5 defect #2 that R6 found in
`shopRendererPath` / `shop_renderer_path`, then issue the final combined
Phase 1 audit-gate ruling. Do not reopen already-passed counts, IDs, statuses,
references, catalog reconciliation, source/visual coverage, authority
adjustments, or the completion-state correction unless the corrected bytes
directly contradict them. Make no mutation or implementation.

## Corrected artifact identities

- `COVERAGE_LEDGER.json` SHA-256:
  `a9c3edb033ae41aff9d3391cb1075257946b0459fca8ad7871db7f507959506e`
- `COVERAGE_LEDGER.csv` SHA-256:
  `73c898a0b85df4da6731c7c886aa62c6ccfb96ed71ac207d868e36567bcd1d2c`
- R6 result:
  `docs/meshy-production/reviews/MESHY-001-R6-9F13A2B7-6BFC-44F3-BA6F-268001434247.json`
- R6 result SHA-256:
  `c845f5a4ee4df9876f205e3b6496f247ef788e9726b2fabeaed405c67a172059`

Manager revalidation after correction: 208 JSON rows, 208 CSV rows, 46
fields, identical ordered IDs, all 208 rows `BLOCKED`, unchanged 208/206
formula, and exact JSON/CSV equality for `exactLocation` and renderer-path
semantics on all 13 paper shop rows.

## Required checks

1. Read the R6 `CORRECTION_REQUIRED` result and verify the exact prescribed
   renderer-path correction in both ledgers.
2. Read all 13 paper `.shop` rows in JSON and CSV and verify both
   `exactLocation` / `exact_location` and
   `shopRendererPath` / `shop_renderer_path` agree:
   - only `pp_ivory`, `pp_manila`, and `pp_ledger` cite
     `BookstoreSceneCoordinator.swift:1557-1580,1909-1950`;
   - the nine other stack styles cite only `:1909-1950`; and
   - `pp_utility_roll` cites only `:1951-1967`.
3. Confirm no paper shop renderer path still contains
   `:1557-1580,1909-1969`, and no inconsistent `:1909-1969` stack range
   remains.
4. Confirm the already-passed completion-state fields remain
   `requiredRowStateForCompletion: APPROVED` and
   `currentProgramState: BLOCKED`, with no `completionStatus` claim.
5. Confirm ordered JSON/CSV IDs, 208 rows, 46 fields, all-BLOCKED status,
   208/206 formula, both authority adjustments, and prior R5/R6 defect
   closeouts are unchanged.
6. Return `STATUS: PASS` only if the combined MESHY-001/R1/R2/R3/R4/R5/R6/R7
   evidence satisfies CONTRACT-001 Phase 1, subject solely to manager-owned
   model/fingerprint/checksum validation. This does not approve any production
   asset: all 208 rows remain `BLOCKED` and every later phase remains open.

## Tool and mutation envelope

Only `Read`, `Grep`, and `Glob` are exposed. No Bash, write/edit, web,
build, generation, launch, paid call, or nested agent is available or
permitted. The manager owns model, branch, fingerprint, checksum, and
byte-level validation.

## Required output headings

- `STATUS`
- `AGENT_RUN_ID`
- `RESOLVED_MODEL`
- `BRANCH`
- `COMMIT_OR_PATCH`
- `R6_CORRECTION_CHECK`
- `PAPER_PATH_PARITY`
- `UNCHANGED_GATE_FACTS`
- `DEFECT_CLOSEOUT`
- `PHASE1_GATE_RULING`
- `KNOWN_LIMITATIONS`
- `BLOCKERS`

Otherwise return `CORRECTION_REQUIRED` with exact path/row edits. No row may
be promoted and `COMMIT_OR_PATCH` is `NONE (read-only)`.
