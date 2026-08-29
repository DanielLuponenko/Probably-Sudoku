# Claude Sonnet agent control matrix

All accepted production runs require both `model: sonnet` in the project agent
definition and an explicit Sonnet session invocation. `Agent` is intentionally
absent from every tool allowlist so workers cannot spawn nested agents.

| Agent | Mode | Writable domain | May approve | Current gate |
|---|---|---|---|---|
| `sonnet-repository-auditor` | Read-only | None | No | Phase 1 passed through MESHY-001/R1–R7 with manager-owned model, checksum, and byte-identical checkout validation |
| `sonnet-meshy-pipeline-engineer` | Write | Pipeline scripts, immutable source/runtime asset staging, assigned evidence fields | No | Definition/model verified; Phase 1 dependency satisfied; Phase 3 zero-credit preflight may begin after exact worktree/file assignment |
| `sonnet-number-system-engineer` | Write | Assigned number registry/rendering paths only | No | Definition/model verified; depends on hard-case gate |
| `sonnet-paper-grid-engineer` | Write | Assigned paper/grid registry/rendering paths only | No | Definition/model verified; depends on hard-case gate |
| `sonnet-shop-scene-engineer` | Write | Assigned modular shop scene/spec paths only | No | Phase 2 spec gate accepted at corrected commit `9f9d872`; no runtime implementation accepted; depends next on Phase 3 and hardest-case asset gate |
| `sonnet-runtime-integration-engineer` | Write/integration | Assigned canonical registry and integration paths; sole cross-workstream conflict owner | No | Definition/model verified; depends on audited schemas |
| `sonnet-qa-performance-engineer` | Write for QA tooling/tests | Assigned test, validation, screenshot, and profiling paths | No | Definition/model verified; depends on audit |
| `sonnet-independent-reviewer` | Read-only | None; report returned to Codex | No | VISUAL-001-R5 independently passed the corrected Phase 2 brief boundary; continues to review every later author output separately |

Concurrency limit: at most two write-capable agents, with disjoint file
ownership. Shared registries have one owner at a time. Every run must have a
task contract in `tasks/`, a branch/worktree, a unique run ID, resolved model
evidence, and an immutable commit or patch checksum.

Model verification evidence: session
`06074628-263F-4B20-BCEF-2316F1A3B4C0`, result UUID
`6a48a2fc-3c95-448e-953d-7d39277998e5`, canonical model
`claude-sonnet-5`, first-party provider, standard service tier. This verifies
the integration only; every production run must still record its own resolved
model evidence.

All eight project definitions were discovered through an explicit `--agent`
invocation and independently exposed canonical model `claude-sonnet-5` on
2026-08-29. The probes disabled tools, performed no implementation, and are not
accepted as production output. Exact session/result IDs and costs are recorded
in `AGENT_RUN_LEDGER.jsonl`.

Audit run `E3D6C0A1-9B7F-4A2E-B518-7C9D3F6A2401` resolved to canonical
`claude-sonnet-5`, performed no mutation, and supplied accepted partial evidence.
It did not pass because its environment/display counts were lower bounds, its
ledger rows were grouped, and several references/files were not fully read or
visually inspected. The revision contract may not waive those gaps.

Revision run `349D394D-892D-4902-BCE0-C2D340A506FD` also resolved to
canonical `claude-sonnet-5` and made no mutation. Its exact JSON inventories
contain 71 unique environment leaf types totaling 1,893 instances and 43
unique display leaf types totaling 101 reachable instances, plus two dead-code
types that would create four instances. Those exact scene findings are accepted
as partial evidence only. The run remained `PARTIAL` because it did not finish
all HTML/image inspection, repository-wide path coverage, primary source
rereads, or every defect recheck. `MESHY-001-R2` owns only those gaps.

Finalization run `2C274212-A30E-497F-9A9A-1D6A7DFA014A` resolved to
canonical `claude-sonnet-5`, spawned no nested agents, and made no mutation. It
closed the primary catalog/shop/test reads, full localization and Engine pattern
sweeps, all five residue-count rederivations, and seven direct raster
inspections. It correctly remained `PARTIAL` for a short explicit closeout list,
including a 230-versus-231 accounting conflict. `MESHY-001-R3` must resolve
those items before Phase 1 may pass.

Closeout run `64B23C26-CCB9-4CD2-9B5D-534F05D6DA6C` resolved to canonical
`claude-sonnet-5`, spawned no agents, and made no mutation. It completed every
remaining full HTML/Swift/design/SVG read and all six baseline visual opens. It
corrected the catalog model to 72 number + 7 grid + 26 paper + 5 effect rows,
but withheld `PASS` because the R1 arrays were trapped in a long single-line
result field. The manager normalized and mechanically validated all 224 IDs in
`AUDITED_CANONICAL_LEAVES.json`; R4 must detect semantic overlaps before that
number or the Phase 1 gate can be accepted.

Reconciliation run `39E91EFD-4561-4950-A4E0-8B1ACB8E1C66` resolved to
canonical `claude-sonnet-5`, spawned no agents, and made no mutation. It found
12 semantically overlapping display stand-ins and three intrinsic glow
properties that are not independent leaves. The manager applied its full
classification with two stricter authority adjustments, producing synchronized
208-row JSON/CSV ledgers: 206 visible rows and two dead-code removal rows, all
`BLOCKED`. R5 must verify those exact artifacts before Phase 1 can pass.

Ledger-verification run `29ADB9EB-E571-4BDA-A30B-AEA14E342309`
resolved to canonical `claude-sonnet-5`, spawned no agents, and made no
mutation. It accepted the 208/206 accounting, classifications, authority
adjustments, ID uniqueness, allowed states, and catalog/reference coverage. It
found only an ambiguous top-level completion field and ten overbroad paper
hanging-sample citations. The manager corrected both synchronized artifacts;
R6 was issued as the correction-only closeout.

Correction-closeout run `9F13A2B7-6BFC-44F3-BA6F-268001434247`
resolved to canonical `claude-sonnet-5`, spawned no agents, and made no
mutation. It confirmed the completion-state correction and all prior counts,
IDs, statuses, formulas, and authority adjustments, but found the same
hanging-sample citation still copied into the parallel renderer-path field on
the paper rows. The manager corrected both JSON and CSV and mechanically
revalidated 208 rows, 46 fields, ordered ID parity, all-BLOCKED status, and all
13 paper path semantics. R7 is limited to that remaining correction and the
final Phase 1 ruling.

Final-closeout run `CE6572EB-7696-4BDE-8E27-5C90F28FB3BA` resolved to
canonical `claude-sonnet-5`, spawned no agents, and made no mutation. It
verified the remaining renderer-path correction on all 13 paper rows in both
ledgers, zero stale `1909-1969` citations, exact path parity, unchanged
208/206 accounting, all-BLOCKED status, and both authority adjustments.
Manager-owned task checksum and all three pre/post checkout fingerprints
matched exactly. Phase 1 is accepted; no production asset is approved.
