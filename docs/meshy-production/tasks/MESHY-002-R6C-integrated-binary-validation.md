# MESHY-002-R6C — Integrated GLB/USDZ/runtime validation

## Authority

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Superseded failed/partial work: MESHY-002-R3, R4, and R5.
- Task/run ID: `D593465D-78A2-41D1-9D19-9C528E6E5DD1`
- Agent: `sonnet-meshy-pipeline-engineer`, requested model `sonnet`; no nested agents.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002-validation`
- Branch: `feature/KAN-153-meshy-validation`
- Exact parent: `e46b3407e9342ca72df8a0aad8db06993e93d68d`

This is production implementation by Claude Sonnet. Read the master, MESHY-002 R1–R5 contracts/evidence, the complete parent commit, all validator/submission/runtime-conversion files/tests, and all existing real-candidate evidence before editing. Close R5 section E completely; inherited green tests do not prove adequate validation.

## Zero-credit boundary

Make no Meshy API call, read no credential, regenerate no candidate creatively, and consume zero credits. Operate only on local fixtures and the already-downloaded real candidate assets.

## Exclusive writable paths

- `docs/meshy-production/evidence/MESHY-002-R6C/**`
- GLB, USDZ, USD tools, validation orchestration, metadata, conversion/LOD, and directly necessary submission-integration modules under `scripts/meshy/**`
- new or directly relevant tests/fixtures under `scripts/meshy/test/**`
- mechanically derived candidate artifacts only if the existing proof must be recreated byte-for-byte; never alter provider-native source candidates

Do not edit plan/specification/cost/ledger/manifest artifacts, accepted briefs, prior evidence, task contracts, authorization/transport/replay/evidence implementations except for a narrow typed validation integration point, application code, Xcode configuration, or agent definitions. The integration agent owns cross-track reconciliation.

## Required implementation

1. Live submission orchestration validates the exact preserved downloads before any `reasonCode:'succeeded'`, terminal success evidence, manifest eligibility, or public success return. Corrupt GLB, corrupt USDZ, or missing/unbound required PBR maps return/evidence `validation-failed`; tests may not validate manually after success.
2. Require every requested provider output or invoke the already-proved mechanical fallback with explicit provenance. Refine requires the complete expected PBR set and actual material/shader bindings, not matching filenames or URL-list presence.
3. GLB validation must enforce: header/version/declared length; chunk order/type/alignment/padding; JSON validity/depth; binary chunk bounds; buffers/bufferViews/accessors with offsets, strides, component widths/counts/types/normalization/sparse data and actual-byte bounds; all scene/node/mesh/primitive/attribute/index/material/texture/image/sampler references; POSITION; supported primitive modes and correct triangles for list/strip/fan; finite transforms/positions/bounds; graph cycles/duplicate-parent/out-of-range nodes; embedded image byte ranges and MIME; UV requirements for textures; category triangle budgets; giant/degenerate bounds; and required sidecar units/up-axis/pivot/scale/contact metadata.
4. USDZ validation must enforce: EOCD/central-directory offsets/counts/sizes; local-central agreement; supported flags; reject encryption/data-descriptor/unsupported Zip64; exact entry ranges; duplicate and case-collision paths; traversal/absolute/NUL/backslash hazards; CRC32; per-entry/total bounds; required root USD; package alignment policy; bounded `usdchecker`, `usdchecker --arkit`, and `usdcat`; default prim; finite positive meters-per-unit; valid up axis; finite transforms/bounds; nonempty meshes; material binding; texture references resolving to packaged entries; required PBR shader inputs; and explicitly recorded nonfatal diagnostics.
5. External tools use hard executable paths/allowlists where appropriate, sanitized environment, bounded stdout/stderr, timeout + process-group termination, and deterministic failure codes. Missing tools never silently pass.
6. Add adversarial generated fixtures for every property above. Four-byte markers, truncated chunks/ZIP entries, alignment/padding corruption, out-of-range accessors, bad sparse views, missing POSITION, invalid refs, node cycles, wrong primitive mode/count, nonfinite/giant transforms, fake texture names without binding, corrupt CRC, collisions/traversal, oversized archives, symlinks, tool hangs/output floods, and missing sidecars must fail.
7. Revalidate without creative alteration: both provider-native historical USDZ candidates, mechanically derived GLB, all LODs, runtime USDZ, PBR textures/bindings, Apple framework checks, installed iOS simulator checks, thumbnail checksum/dimensions, and recorded mechanical lineage. Preserve their historical/test-only/not-approved status.

## Mandatory proof

All inherited tests plus the complete adversarial matrix pass. Integrated fake-server success proves validation happens before success; corrupt GLB, corrupt USDZ, missing PBR, and tool timeout each produce `validation-failed`, never `succeeded`. Real candidate proof must include exact hashes/sizes, `usdchecker` and `--arkit`, bounded `usdcat`, parser results, PBR binding evidence, GLB/LOD/sidecar results, Apple framework, installed simulator, thumbnail dimensions/hash, and lineage.

Run syntax, JSON/schema parse, full tests, changed-path allowlist, `git diff --check`, redaction/secret scan, and protected-root HEAD/diff preservation. Evidence must contain exact commands/results and final checksums.

## Delivery

Create exactly one clean Sonnet-authored child commit of the exact parent, only within writable paths. Return `COMPLETE_FOR_INTEGRATION` only when every requirement/proof passes; otherwise `PARTIAL` with exact blockers. Report: STATUS, AGENT_RUN_ID, CHANGED_FILES, COMMIT, INTEGRATED_FLOW, GLB_VALIDATION, USDZ_VALIDATION, REAL_CANDIDATE_AND_RUNTIME_PROOF, TESTS_AND_GATES, ZERO_CREDIT_PROOF, CHECKSUMS, LIMITATIONS, BLOCKERS. Report the run ID exactly.
