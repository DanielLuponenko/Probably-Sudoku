# MESHY-002-R6C-R3 — Mandatory validation policy and live mechanical fallback

## Authority

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Failed candidate: `4e0d1518e04012e31cd7c31c478def44384afc61`.
- Independent FAIL: R6C-R2 run `85B363A7-D71F-44EF-9697-A737A3702FA6`, canonical `claude-sonnet-5`, result UUID `0bc4a390-c593-4534-ba0d-b520a3334ac8`.
- Correction task/run ID: `E8458208-11E4-44C3-8A1B-3B119E4B95BD`.
- Agent: `sonnet-meshy-pipeline-engineer`, requested model `sonnet`; no nested agents.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002-validation`.
- Branch: `feature/KAN-153-meshy-validation`.
- Exact parent: `4e0d1518e04012e31cd7c31c478def44384afc61`.

Read the master, R6C/R6C-R2 contracts and complete results, the entire failed commit, all validator/conversion/submission code, the audited canonical inventory, generation plan, real candidate evidence, mechanical-derivation proof, and performance baseline before editing. Preserve failed history. This task closes every independent-review blocker; do not relabel a boundary as completion.

## Zero-credit boundary

No Meshy API call or credential access. Local Blender/USD tools and already-preserved candidates are allowed. Consume zero credits.

## Writable paths

- `scripts/meshy/**` only where directly required for validation policy, sidecars, bounded mechanical fallback, submission integration, fixtures, and tests.
- `docs/meshy-production/pipeline/VALIDATION_POLICIES.json` (new canonical artifact).
- `docs/meshy-production/evidence/MESHY-002-R6C-R3/**` (new only).

Do not edit R6C evidence, plans/costs/briefs/coverage/ledger/manifest/task contracts, application code, Xcode configuration, or agent definitions. The later integration agent will cross-link the dedicated policy artifact into the merged generation plan; this correction must make the live library path enforce the policy now by canonical asset ID/category.

## A. Real mandatory validation policy

1. Create a schema-validated deterministic `VALIDATION_POLICIES.json` with exactly one policy for each of the 208 canonical IDs in canonical order. Two dead-code rows are explicitly non-submittable; every other row has category, source triangle ceiling, runtime LOD0 ceiling, units/up-axis, normalization, pivot, scale, contact or attachment rule, and policy checksum.
2. Lock these conservative Phase-3 **source** triangle ceilings (maximum provider-source triangles per leaf): effects 25,000; grid 40,000; numbers 25,000; paper 20,000; shop_display 50,000; shop_environment 60,000. Lock these **runtime LOD0** ceilings: effects 6,000; grid 15,000; numbers 8,000; paper 6,000; shop_display 15,000; shop_environment 20,000. They are provisional safety ceilings grounded in the real 10,395-triangle test candidate and the 60-fps/minimum-device contract; Phase 15 may tighten them, but may not loosen them without a recorded manager decision.
3. Use meters and Y-up. For GLB source variability, compute a deterministic sidecar from actual finite parsed bounds plus the canonical policy: source bounds, target normalized extent, uniform normalization scale, resulting bounds, optical pivot transform/rule, contact plane or attachment anchor, units, up axis, and policy hash. Never merely assert a sidecar supplied by the caller.
4. Category/ID rules must encode physical intent: grounded floor/wall/furniture/paper/product pieces use stable contact metadata and appropriate bottom/edge pivot; hanging/ceiling/lamp parts use mounting anchors; number/grid/effect components use registered optical/attachment pivots; airborne light traces/dust use an explicit non-ground attachment rule. Every row must be reviewed, with no generic missing default.
5. `submitStage` resolves the immutable canonical policy internally from canonical asset ID/category, generates/validates the sidecar by default, applies the source triangle ceiling unconditionally, and fails closed before success if policy/sidecar/budget is absent or inconsistent. Caller overrides may only tighten bounds; attempts to loosen/change identity fail.
6. Validate mechanically derived runtime GLB/LODs against the runtime LOD0/LOD policies as well as source assets against source ceilings. Persist policy and sidecar checksums in validation/provenance summaries.

## B. Invoke the real mechanical fallback

1. When any requested `glb` or `usdz` format is absent but the other validated source format exists, `submitStage` must invoke the already-proved local mechanical conversion path before deciding success/failure. Detection or accepting a caller-prebuilt fallback is insufficient.
2. Production fallback uses fixed reviewed Blender executable/script paths, sanitized environment, bounded stdout/stderr/time, process-group termination, exclusive contained workspace/output files, no overwrite/symlink following, and no shell interpolation. Test injection is permitted only through a structurally test-only adapter unreachable from production inputs.
3. Preserve the original provider file. Record immutable provenance: input format/path/hash/size, missing requested format, exact fixed tool/script and versions/checksums, command arguments with safe paths, start/end/time/result, output path/hash/size, and policy/sidecar lineage.
4. Validate the produced fallback file fully (including USDZ Apple checks where applicable) before it satisfies `target_formats`. Conversion failure, timeout, malformed output, policy failure, or provenance-write failure returns/evidences `validation-failed` with a precise subreason, never `succeeded`.
5. Cover both GLB→USDZ and USDZ→GLB. Use the actual installed Blender and real preserved candidate for at least one zero-credit end-to-end fallback proof; synthetic injected runners alone are insufficient.

## C. Tests and evidence

- Full 208 policy/order/parity/checksum proof and explicit per-ID policy review table.
- Poisoned policies: missing ID/category, wrong checksum, excessive/NaN/Infinity/negative budgets, caller loosening, mismatched category, invalid units/up-axis/pivot/contact/scale/bounds.
- Over-budget real/synthetic GLB fails through `submitStage`; absence of policy/sidecar fails; no optional success path remains.
- Actual-geometry sidecar math tests for grounded, hanging, optical, and airborne/attachment assets, including nonfinite/degenerate/giant bounds.
- Missing-USDZ and missing-GLB end-to-end cases invoke the fallback exactly once, preserve input, validate output, and succeed only after provenance; timeout/nonzero/malformed/symlink/overwrite/provenance failure cases return `validation-failed`.
- Real Blender conversion proof and exact hashes; all prior 284 tests remain green.
- Syntax/JSON/schema/cross-reference, deterministic artifacts, candidate/USD tools, Apple/installed simulator/thumbnail, secret scan, changed-path allowlist, `git diff --check`, clean history, protected-root preservation.
- New evidence explicitly records the R6C-R2 FAIL and supersedes the false completion claim. Do not amend prior evidence.

## Delivery

Create exactly one clean Sonnet-authored child commit of `4e0d1518e04012e31cd7c31c478def44384afc61`. Return `COMPLETE_FOR_REREVIEW` only if every required item passes; otherwise `PARTIAL`. Do not state a canonical resolved model; report the requested model and let the manager verify structured `modelUsage`. Sections: STATUS, AGENT_RUN_ID, CHANGED_FILES, COMMIT, VALIDATION_POLICY, SIDECAR_ENFORCEMENT, LIVE_MECHANICAL_FALLBACK, TESTS_AND_GATES, REAL_TOOL_RUNTIME_PROOF, ZERO_CREDIT_PROOF, CHECKSUMS, LIMITATIONS, BLOCKERS. Report the run ID exactly.
