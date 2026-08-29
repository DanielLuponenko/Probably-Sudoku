# MESHY-002-R3 — Phase 3 correction and real-candidate proof

## Authority and identity

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Task ID: `MESHY-002-R3`
- Manager run/session ID: `16090EC3-1C53-4ACA-839E-AF10EB6F05DE`
- Agent: `sonnet-meshy-pipeline-engineer`
- Requested model: `sonnet`; the manager will verify the canonical resolved
  model from the structured CLI result.
- Worktree:
  `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002`
- Branch: `feature/KAN-153-meshy-pipeline`
- Parent author commit: `7797833d251f4c32790c0610734d3a4e68b7aa3c`
- Manager seed: `b5fc9384e479dde35b58ada97cceefd647020d34`
- Prior author task: `MESHY-002-R1`
- Independent review: `MESHY-002-R2`, session
  `94CD44CC-3F9F-44B1-897E-458EA8781C43`, canonical reviewer model
  `claude-sonnet-5`, result UUID `3b320bcb-1224-4043-be15-aa6d92c1c890`,
  verdict `FAIL`.
- No nested agents. Do not self-approve Phase 3 or any production asset.

This is a correction task, not permission to reduce or reinterpret R1. Read the
master, R1/R2 task contracts, the complete R1 diff, all accepted Phase 1/2
artifacts, the R2 findings below, and every current pipeline file before editing.

## Zero-credit boundary

Consume exactly `0` new Meshy credits. Make no live Meshy generation,
refinement, retexture, remesh, conversion, retry, or other paid call. The real
historical files below have already been downloaded by the Codex manager through
the authenticated read-only Meshy connector; use them locally. Official
`docs.meshy.ai` GETs are allowed. Do not probe `api.meshy.ai` without a secret,
and do not search for or expose credentials.

## Manager-provided authenticated inputs

Read and verify:

- `docs/meshy-production/evidence/MESHY-002-R3/MANAGER_CONNECTOR_INPUTS.json`
  SHA-256 `f8c05f5dc59b700c4c0e8ad74bf8e153cb914b4214589232d25703d496fbdfe9`.
- Preview USDZ:
  `Artifacts/Meshy/MESHY-002-R1/provider-native/club-turntable-preview.usdz`,
  663,884 bytes, SHA-256
  `cd06daf1067084e2e09a0771d024499216e361b6253e284d775bc47e5f32f576`.
- Refine USDZ:
  `Artifacts/Meshy/MESHY-002-R1/provider-native/club-turntable-refine.usdz`,
  22,039,583 bytes, SHA-256
  `fff03e6d1ca488b73db77d6340deb311aa808f6ff18c07c93567b2ff278366ce`.
- Refine textures:
  - base color `ea64ec3099218daea94bf0ee0c4738ccf623dd178a165730eaecef63c1e28a61`
  - metallic `55c24bad836904c7760234aacfaba627f18193885e4aa96d55a37899f90b6a10`
  - normal `de593adf33f53c098da9fdfa5873d521d9dc01aea8b99e69e51c8f3babd121a9`
  - roughness `548a19d0a4233a68170f304f8960c4041fcb50afb540be234e32cd700afaacf5`

The provider exposed USDZ only; never label a later GLB as provider-native.
Balance was `1,886` before and after the read-only status/download operations.
The historical tasks remain `CANDIDATE_ONLY_NOT_APPROVED`.

## Writable paths — exact and exclusive

- `scripts/meshy/**`
- `Artifacts/Meshy/MESHY-002-R1/**`
- `docs/meshy-production/pipeline/**`
- `docs/meshy-production/evidence/MESHY-002-R1/**`
- `docs/meshy-production/evidence/MESHY-002-R3/**`
- `docs/meshy-production/MESHY_GENERATION_PLAN.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.md`
- `docs/meshy-production/ASSET_MANIFEST.json`
- `docs/meshy-production/MESHY_TASK_LEDGER.jsonl`, append-only only; all four
  existing lines must remain byte-identical and ordered.

No application code, Xcode project configuration, accepted brief/coverage
artifact, task contract, agent definition, or manager/review/risk/decision log
is writable. Commit only the paths above.

## Mandatory reviewer corrections

### 1. Canonical plan order

The manager resolves the inherited input ambiguity now: for the Phase 3
generation plan, `COVERAGE_LEDGER.json` row order is canonical. Build all 208
plan rows in that exact order while still mapping each ID to exactly one of the
43 accepted brief families. Add a test against the exact ordered sequence, not
only set equality. Keep 206 visible plus two dead-code rows and alter zero
coverage rows.

### 2. Precision-sensitive modes

Do not route all 72 digits and seven grid assets directly to text-to-3D merely
because reference sheets are not yet present. For those 79 rows:

- use an explicit `awaiting_orthographic_reference_sheet` generation state;
- mark the row non-submittable until an approved sheet path and checksum exist;
- define the eventual pinned `image-to-3d` or `multi-image-to-3d` request
  template and exact documented credits without inventing a reference;
- preserve complete digit/grid evidence requirements; and
- expose their provider credit totals separately from currently submittable
  rows. If a future Meshy 2D task is chosen to author sheets, its cost must be
  added explicitly then; do not charge an invented sheet-generation price now.

No direct text-to-3D exception is granted for the 79 precision rows.

### 3. Official emission contradiction

Re-read current official Text-to-3D task object, Text-to-3D parameter,
Image-to-3D, Retexture, pricing, and changelog pages. Record the contradictory
official wording explicitly. Resolve it operationally by treating Meshy 7
emission as `unknown_fail_closed`, never required or assumed. Do not claim the
official pages are internally consistent. The downloaded refined USDZ has no
emission map; record that asset fact separately from the provider-wide docs
decision.

## Mandatory manager corrections missed or underweighted by R2

R2's three blocking findings are necessary but not sufficient. Correct all of
the following before returning.

### Reproducible request specifications

- Every submittable row needs a complete provider request specification derived
  from its accepted brief: full positive form/material/detail prompt,
  exclusions encoded into positive constraints, prompt checksum, approved
  reference paths/checksums, endpoint/mode/model, format/PBR/quality/topology
  parameters, scale/pivot requirements, and family/parent identity.
- Never emit a provider request with no prompt. R1's preview requests contain no
  `prompt` and its refine templates contain no `preview_task_id`; fix this.
- A refine dry run must require the actual accepted preview task ID. A
  placeholder may exist only in a clearly non-submittable template; it may not
  hash or authorize a live payload.
- The approval checksum must be over the exact canonical JSON bytes sent in the
  HTTP body, not an internal wrapper that is not posted.
- A dead-code or awaiting-reference row must reject dry-run submission.

### Authenticated fail-closed live transport

- Add a real operator CLI; do not leave a partially wired live function hidden
  behind tests.
- Pin production live calls to `https://api.meshy.ai` and the exact allowed
  method/endpoint. Reject caller-supplied live hosts, non-HTTPS, loopback,
  private/link-local destinations, redirects to unapproved hosts, path escapes,
  and unknown methods. Local fake-server mode must be a separate explicit test
  mode that can never use a production approval.
- Read `MESHY_API_KEY` only at execution time and send the documented redacted
  bearer authorization header. Never persist or echo it. Tests must prove the
  header reaches the fake server and never reaches logs/evidence.
- A production approval record must be cryptographically authenticated with a
  separate manager HMAC secret supplied at runtime, cover every authorization
  field and the exact request-body checksum, and fail closed when unsigned,
  tampered, fixture-labelled, future-dated, expired, wrong environment/host/
  method/endpoint/model/attempt/credits/destination, or replayed. An
  `approvalIsFixture:false` caller boolean is not authentication.
- Expected credits must equal the authorized credits exactly for that payload;
  no silent slack. The approval must include the user-confirmation reference.
- Persist approval-ID and accepted-payload replay state atomically before a
  live POST. In-memory optional `Set`s are insufficient. Test repeated process
  invocation and concurrent reservation.

### Paid POST, polling, failure, and preservation semantics

- Never automatically retry a paid creation POST unless the current official
  endpoint documents an idempotency mechanism and it is pinned. R1 currently
  retries POST on 429/5xx and can duplicate billed tasks. Submit once; an
  ambiguous transport result becomes `submission-uncertain` and must not report
  zero credits or resubmit.
- Do not report `consumedCredits:0` after a timeout/unknown result merely because
  the task response was unavailable. Use `null`/`unknown`, preserve evidence,
  and require task reconciliation.
- Bound and reason-code GET polling/download retries, time, bytes, status,
  content type, redirects, and malformed bodies. Preserve provider failure and
  cancellation credits exactly as reported.
- Actually write request manifest, redacted response, attempt record, task ID,
  reported credits, downloaded bytes, tool versions, checksums, and validation
  report under a path-contained evidence directory with exclusive/no-overwrite
  semantics. R1's `destinationEvidenceDir` is ignored and downloads remain only
  in memory; fix it.
- Never persist usable signed URLs. Redact the entire query/fragment of any
  provider URL by default. R1 fails to recognize common `X-Amz-*` query names;
  add real signed-URL tests.
- Download URL policy must prevent SSRF/private-host access in production while
  retaining a separate loopback fake-server path in tests.

### Real validators, conversion, Apple runtime, and thumbnail

- Replace the four-byte/marker-only GLB validator with a real GLB v2 parser that
  validates header/version/declared length/chunks/JSON, buffers/accessors,
  finite node transforms and accessor bounds, nonempty meshes/primitives,
  material/texture/image references, UV presence when required, triangle
  estimates/budgets, units/axis/pivot metadata, and giant-bounds rejection.
- Validate USDZ package structure, safe paths, file sizes, `usdchecker` and
  `usdchecker --arkit`, default prim, finite transforms/bounds, up axis/units,
  materials, actual packaged PBR maps and bindings, and checksums. Do not treat
  a nonfatal `UsdShade` diagnostic as a pass without recording it.
- Prove the provider-native refine USDZ first. Extract/derive a test-only GLB
  mechanically from the same real candidate if necessary; label it
  `MECHANICALLY_DERIVED_TEST_GLB`, never provider-native. Exercise the complete
  fallback GLB-to-USDZ path with available Blender/USD tools, preserve source and
  derivative separately, and record exact reasons/tool versions/commands.
- Produce a mechanically optimized runtime USDZ plus at least the LOD outputs
  required by the current performance budget, without creative redesign.
- Load the actual runtime candidate in an Apple framework and in the installed
  iOS simulator through a task-local probe harness. Produce a separately
  rendered deterministic runtime thumbnail from that registered runtime asset,
  not the provider thumbnail. Record dimensions/checksum and keep it visibly
  distinct from provider provenance imagery.
- If any tool cannot prove a required property, report it as a blocker; do not
  relabel a shallow check as the required validator.

### Evidence and historical correction

- R1 changed 49 files, not 47. Regenerate a complete final changed-file list,
  checksums, syntax/test evidence, and path proof after every final file exists.
  Self-referential evidence may explicitly exclude itself, but the exclusion
  must be named.
- Preserve the R1 self-reported run ID/model as historical text, but add the
  manager-verified session `F353EE1A-1255-410F-87AD-D5004E68A926`, canonical
  model `claude-sonnet-5`, and the exact discrepancy. In this R3 result, report
  `AGENT_RUN_ID` exactly as `16090EC3-1C53-4ACA-839E-AF10EB6F05DE`; do not
  generate another ID and do not guess a model version.
- Update `ASSET_MANIFEST.json` with a non-production pipeline test asset only
  after all real-candidate gates pass. Leave production `assets` empty and all
  coverage rows blocked.
- Never edit any existing `MESHY_TASK_LEDGER.jsonl` line. Append superseding
  records for: authenticated manager connector evidence; R1's agent-local 401
  limitation; official-doc emission ambiguity; real-candidate validation;
  actual zero new credits; and R3 outcome.
- Record that manager connector metadata is not the complete original provider
  request/response payload. That limitation keeps the historical candidate from
  production approval even if it is valid as a pipeline test asset.

## Required tests and gates

Run every command through `boost`. At minimum:

1. all input/task/manager-evidence/download hashes;
2. all prior 81 tests plus new adversarial tests for every correction above;
3. syntax checks for every module/script/Swift probe;
4. exact 208 ordered parity and 206+2 formula;
5. exact 79 awaiting-reference rows and zero accidental submittability;
6. complete prompt/request/refine-task-ID/dry-run-body checksum tests;
7. HMAC/tamper/replay/cross-process/concurrency/path/host/method/redirect/SSRF/
   signed-URL/API-key redaction tests;
8. single-POST/uncertain-result/no-auto-resubmit tests;
9. disk preservation/no-overwrite/partial-download/checksum/malformed/timeout/
   credit-unknown tests;
10. real GLB and USDZ parser/validator pass/fail fixtures plus the actual two
    candidate USDZs;
11. actual mechanical extraction/conversion/optimization/LOD validation;
12. Apple framework load, installed iOS simulator load, and deterministic
    runtime thumbnail generation from the actual registered test asset;
13. manager balance-before/after equality and zero-new-task/zero-credit evidence;
14. JSON/JSONL/schema/manifest/ledger/checksum cross-reference;
15. full changed-path allowlist and `git diff --check` over the R3 commit;
16. protected root status/diff fingerprints remain unchanged; and
17. one clean Sonnet-authored child commit of `7797833`.

Do not weaken tests, skip failed commands, or claim unavailable tools passed.

## Acceptance boundary and result

Return `COMPLETE_FOR_REVIEW` only if every assigned correction and Phase 3 test
gate passes. Otherwise return `PARTIAL` with exact remaining blockers and do not
reduce scope. No production asset, Phase 3 gate, or later phase is self-approved.

Return exactly the standard pipeline-agent sections. Include exact commit,
changed files, official-doc decision, ordered plan/mode totals, corrected credit
estimate, every command result, runtime thumbnail path, performance data,
historical tasks/new credits, checksums, limitations, and blockers.
