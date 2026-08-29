# MESHY-002 — Official Meshy pipeline preflight and reproducibility foundation

## Task ID

`MESHY-002`

## Agent name

`sonnet-meshy-pipeline-engineer`

## Dependency IDs

- `MESHY-001`: repository/catalog/reference audit accepted by Codex.
- `VISUAL-001`: measurable visual invariants locked by Codex.
- `CONTROL-004`: this agent's task-specific model resolution verified.

## Exact objective

Establish a versioned, authenticated, reproducible Meshy-only production
pipeline that can preflight model/capability availability, calculate exact
expected credits before submission, submit only user-confirmed paid tasks, poll
with bounded retries, preserve native/source/runtime outputs and payloads,
mechanically optimize without visual redesign, validate PBR/formats, checksum
everything, and append immutable task/credit/retry evidence.

This contract initially authorizes implementation and zero-cost/read-only
preflight only. It does not authorize a credit-costing Meshy call.

## In-scope files and components

- New or existing Meshy pipeline scripts under `scripts/meshy/**` or a narrower
  path approved by Codex after audit.
- Pipeline tests and fixtures under task-assigned test paths.
- `docs/meshy-production/ASSET_MANIFEST.json` schema/evidence fields assigned by
  Codex.
- `docs/meshy-production/MESHY_TASK_LEDGER.jsonl` append-only evidence.
- Immutable task request/response manifests and source/runtime staging paths
  assigned after the audit.

## Writable paths

Must be narrowed in the dispatch revision after `MESHY-001`; no other paths are
writable. Shared production registries are excluded.

## Read-only paths

Entire repository, accepted audit/coverage/reference artifacts, official Meshy
documentation, and read-only Meshy capability/balance/task listings.

## Prohibited changes

- Any credit-costing Meshy generation, refinement, texturing, remesh, rigging,
  animation, conversion, or retry without a separate Codex cost disclosure and
  explicit user confirmation of the exact charge.
- Non-Meshy visual generation, procedural substitute art, hidden fallbacks,
  unpinned `latest` production requests, credentials in files/logs, destructive
  cleanup, writes outside the task, nested agents, or self-approval.
- Reinterpreting optimization as visual redesign.

## Approved references

The accepted `REFERENCE_INDEX.md`, locked visual invariant artifact, official
Meshy API documentation/changelog/pricing, and only the approved input images
and prompts recorded in the task manifest.

## Ledger rows owned by the task

Only pipeline/provenance fields and append-only task-attempt records assigned by
Codex. The task cannot set `final_status` to `APPROVED`.

## Acceptance criteria

1. Model/version, generation mode, format, PBR, and output behavior are pinned
   and documented from current official capabilities.
2. Dry-run/preflight returns an exact credit estimate and payload without
   submitting the paid request.
3. Every submission requires a unique approval reference and rejects execution
   without it.
4. Polling/retry logic is bounded, reason-coded, idempotent where supported, and
   never repeats an unchanged failed task indefinitely.
5. Request/response payloads, task IDs, timestamps, credits, retries, source
   assets, provider-native USDZ when available, GLB, runtime USDZ/LODs/textures,
   tool versions, and SHA-256 checksums are preserved.
6. Source-to-runtime validators catch missing maps, malformed scenes, broken
   animation, scale/pivot issues, and registry/manifest mismatch.
7. Tests prove the zero-credit guard and failure modes without paid calls.

## Required commands

To be finalized after the audit. At minimum: script unit tests, static/format
checks, dry-run payload generation, zero-credit guard tests, checksum validation,
and read-only balance/model capability checks. Pipe all shell output through
`boost`.

## Required screenshots

None for preflight. Later asset contracts must provide deterministic turntables,
contact sheets, and runtime captures.

## Required performance evidence

Pipeline elapsed-time logging, download size, optimization ratio, and validator
runtime. No asset-quality performance claim is allowed before real assets exist.

## Expected output schema

Use the exact structured result format in
`.claude/agents/sonnet-meshy-pipeline-engineer.md`, including a zero-credit
statement and every read-only preflight result.

## Rollback instructions

Revert only the task branch commit or apply the recorded reverse patch in its
isolated worktree. Never delete preserved source assets or append-only ledger
history; append a superseding record instead. Do not touch the protected root
working tree.
