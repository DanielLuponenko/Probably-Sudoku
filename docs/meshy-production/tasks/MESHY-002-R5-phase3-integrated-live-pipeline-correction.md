# MESHY-002-R5 — Phase 3 integrated live-pipeline correction

## Authority and identity

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Task ID: `MESHY-002-R5`
- Manager run/session ID: `2C9ED49B-3A3C-4967-87D4-C98FA4EDB05A`
- Agent: `sonnet-meshy-pipeline-engineer`
- Requested model: `sonnet`; the Codex manager will verify the canonical resolved model from the structured CLI result.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002`
- Branch: `feature/KAN-153-meshy-pipeline`
- Exact parent: `e8c42053746739590f5605d9d33274b7b4839572`
- Failed independent review: `MESHY-002-R4`, session `1BAAD20D-AF31-40AA-ABDA-36C67FE86DCB`, canonical reviewer model `claude-sonnet-5`, structured result UUID `a88ef708-e86e-4721-a1e0-0b8f37e38282`, verdict `FAIL`.
- Author R3 session: `16090EC3-1C53-4ACA-839E-AF10EB6F05DE`, canonical implementation model `claude-sonnet-5`, commit `e8c42053746739590f5605d9d33274b7b4839572`.
- No nested agents. Do not self-approve Phase 3 or any production asset.

This is a binding correction, not permission to reinterpret or reduce R1/R3. Read the master, R1 through R4 task contracts and reports, the complete `e8c4205` commit, every current pipeline file and test, all accepted Phase 1/2 controls, and all manager-provided candidates before editing. Correct every R4 blocker and every additional manager blocker below. Passing the old 211 tests is not evidence that the defects are closed.

## Zero-credit boundary

Consume exactly zero new Meshy credits. Make no live Meshy generation, refinement, retexture, remesh, conversion, retry, or other paid call. Do not probe `api.meshy.ai`, read credentials, search for credentials, or expose secrets. Official `docs.meshy.ai` GETs are allowed. All network behavior must be proved with local deterministic servers, injected DNS/transport fixtures, and the already-downloaded real candidate files.

## Writable paths — exact and exclusive

- `scripts/meshy/**`
- `Artifacts/Meshy/MESHY-002-R1/**`
- `docs/meshy-production/pipeline/**`
- `docs/meshy-production/evidence/MESHY-002-R5/**`
- `docs/meshy-production/MESHY_GENERATION_PLAN.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.md`
- `docs/meshy-production/ASSET_MANIFEST.json`
- `docs/meshy-production/MESHY_TASK_LEDGER.jsonl`, append-only only; all ten pre-R5 lines must remain byte-identical and ordered.

Do not edit R1/R3 evidence, accepted briefs/coverage/reference artifacts, task contracts, agent definitions, manager/review/risk/decision logs, application code, or Xcode configuration. Preserve failed R3 evidence as immutable history; create R5 evidence that explicitly supersedes its completion claim. Create exactly one clean Sonnet-authored child commit of `e8c4205` containing only allowed paths.

## Official provider contract facts that must govern implementation

Re-read and record current official sources, including `https://docs.meshy.ai/en/api/text-to-3d`, `https://docs.meshy.ai/en/api/image-to-3d`, `https://docs.meshy.ai/en/api/multi-image-to-3d`, pricing, errors/rate limits, and `https://docs.meshy.ai/openapi.json` when accessible. At minimum, preserve and test these manager-verified facts:

1. Text-to-3D preview `prompt` has a maximum of **600 characters**.
2. A successful creation response is `{ "result": "<task id>" }`; it is not `{ "id": ... }`.
3. Image-to-3D uses `POST /openapi/v1/image-to-3d`; Multi-Image-to-3D uses `POST /openapi/v1/multi-image-to-3d`. R3's eventual `/openapi/v2/image-to-3d` path is nonexistent.
4. The task-object documentation explicitly warns clients not to assume a UUID format for IDs. Treat a task ID as an opaque nonempty single path segment, URL-encode it, and never restrict it to `[A-Za-z0-9-]+`.
5. `target_formats: ["glb", "usdz"]` is currently supported for Text-to-3D preview/refine.
6. The official pages do not establish R3's blanket assertion that every 429/5xx creation response proves zero credits. When no authoritative task record reports credits, use `null`/unknown and require reconciliation.

Tests and fake-server fixtures must mirror the current official request/response schema exactly. Do not create a self-consistent fake API that differs from the provider.

## A. Correct the generation plan into executable, leaf-specific requests

R3's plan is not executable and must be regenerated.

### Approved-reference integrity

- Replace every hard-coded nonexistent `mockup.html` / `mockup.rendered.html` path with the exact approved user files:
  - `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/bookstore-aisle.html`, SHA-256 `0934eaa191d573b450d82f607476bc8bd67b7c8f36011d78a5305b7081e42561`.
  - `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/bookstore-aisle-rendered.html`, SHA-256 `c33a6f03bd2e977ec55c2ed87b2005565edf26d8fe2790347c1bda81de0895f4`.
- Build/test must read every referenced path, prove it exists as a regular non-symlink file where applicable, and recompute its checksum. A checksum copied onto a nonexistent or different filename is a hard failure.

### One real specification per leaf

- R3's 127 submittable rows collapse to only 18 unique preview prompts; all 127 prompts are 916–1,571 characters. This is unacceptable.
- Author a pipeline-owned leaf request-specification artifact under `docs/meshy-production/pipeline/` for every canonical row. Preserve the accepted family brief; add the exact leaf subject/form/purpose needed to distinguish `env.floor.slab` from `env.runner.rug`, every beam/shelf/book/rail/stand part, every display part, every paper shop item from its gameplay counterpart, and every other leaf.
- Every submittable preview body must be unique to its canonical asset, contain an unmistakable leaf identity and purpose, encode the accepted material/form constraints in affirmative provider-compatible language, remain at or below 600 characters, and hash to a unique exact HTTP-body checksum. Do not merely append an invisible ID to an otherwise generic prompt.
- Add tests proving: 127 submittable rows; 127 unique preview body hashes; 0 prompts above 600; 0 empty/generic leaf subjects; correct family/parent mapping; exact canonical order; and explicit shop/gameplay distinction or an explicit, non-paid mechanical-derivative lineage when reuse is genuinely valid.
- Because payload-hash replay protection is global, no two independently submittable rows may intentionally share the same exact request body. If one provider task is reused, model that as one paid source plus a non-submittable derivative row with explicit lineage and correct zero additional provider cost—not two impossible duplicate submissions.
- Keep all 79 digit/grid rows fail-closed and non-submittable until approved sheets exist. Replace the ambiguous candidate-mode template with one exact future mode per row and the correct official v1 endpoint/schema/credits. Do not populate `image_url`/`image_urls` or make the row submittable before real sheet paths/checksums exist.
- Preserve 208 exact ordered rows, 206 visible + 2 dead-code, and all accepted coverage IDs.

## B. Correct authorization and exactly-once creation semantics

- Production `submitStage` itself, not only the CLI, must require a nonempty runtime API key, HMAC secret, signed non-fixture approval, replay root, and evidence destination before any network call.
- Extend the signed authorization to cover every relevant field: canonical asset ID, family, stage, production environment, host, exact method/endpoint, pinned model, exact attempt, exact credits, exact HTTP-body SHA-256, destination evidence path, replay-store path or trusted fixed replay root, user-confirmation reference, approval and expiry times, and any output/bound policy that is not a fixed code constant.
- Reserve approval ID and exact payload durably before the physical POST. A partial reservation may fail closed, but must be explicitly evidenced; reuse across processes and concurrent calls must remain impossible.
- A paid creation operation may make **one physical POST total**. Set redirect handling to manual and never follow/reissue a creation POST for 301/302/303/307/308. Record a redacted `submission-uncertain`/reconciliation outcome with `consumedCredits:null` unless an authoritative response proves a more precise state. Test fetch/request invocation count exactly one for every redirect code and every timeout/error.
- Parse the official `{result}` task ID response under strict JSON/content-type/body-size bounds. Reject missing, empty, non-string, control-character, slash-bearing, or otherwise unsafe IDs before polling; URL-encode the accepted opaque segment. Preserve the task ID immediately.
- Do not invent `consumedCredits:0` for 429/5xx or any response without an authoritative task charge. Preserve provider-reported task credits exactly, including failure/cancellation; otherwise use null and reconciliation.

## C. Use a bounded, DNS-pinned production transport

- Production must not rely on a separately resolved `fetch()` after a lexical hostname check. Use a transport that resolves through an injected/testable resolver, rejects every loopback/private/link-local/unspecified/multicast IPv4/IPv6 answer, pins the approved resolved address for the actual TLS request, and validates the original hostname certificate/SNI. Prevent DNS rebinding/TOCTOU.
- Pin API calls to `api.meshy.ai`. Pin output downloads to the current documented Meshy asset host(s); unknown hosts fail closed and require a future manager-reviewed allowlist update. Never accept arbitrary public hostnames merely because they are not literal private IPs.
- Revalidate every allowed GET redirect and cap redirects. Creation POSTs follow none.
- Use immutable production bounds for connect/body/overall time, response bytes, redirects, polling attempts/elapsed time, per-file bytes, total-download bytes, content types, and JSON depth/shape. Test caller attempts to set `Infinity`, negative, NaN, or excessive overrides; production must ignore/reject them rather than become unbounded. Test IPv4, IPv6, IPv4-mapped IPv6, alternate numeric forms, hostname-to-private resolution, mixed public/private DNS answers, rebinding, userinfo, ports, fragments, path escapes, and redirect chains.

## D. Make evidence a pre-network, crash-safe journal for every outcome

- Create an exclusive, path-contained attempt journal and persist a redacted request/approval/reservation-start record **before** the POST. Then write immutable sequenced events/terminal outcome records. A process crash must leave an explicitly recognizable incomplete attempt, not an apparently complete bundle.
- Every outcome/throw path must be represented durably: approval/reservation failure after journal eligibility, pre-response uncertainty, malformed creation success, 4xx/429/5xx, redirect rejection, poll timeout/retry exhaustion, malformed/content-type/oversize task body, unknown status, provider FAILED/CANCELED with exact credits, download rejection/partial/mismatch/timeout, validator failure, and success.
- Evidence writes and replay writes must reject symlinks in every controlled path segment and use no-follow/exclusive primitives. Lexical `resolve().startsWith()` alone is insufficient. Test a pre-created `downloads` symlink, evidence-root symlink, replay-root symlink, and mid-bundle write failure.
- Never persist or print API keys, HMAC secrets, authorization headers, signed query strings/fragments, or unredacted provider URLs. Preserve response/task facts after deep redaction.
- Stream each download into an exclusive `.partial` artifact with hard per-file and total-byte bounds while hashing. On verified completion, atomically rename it. A failed partial remains clearly labeled and evidenced; it must never be treated as a completed artifact.
- Return and print only paths, sizes, hashes, validation summaries, task facts, and reason codes. Never retain raw model `Buffer`s in the public outcome and never JSON-serialize them to stdout.

## E. Integrate real validation before success and strengthen validators

- Validation must run inside the live submission pipeline on the exact preserved files before `reasonCode:'succeeded'`, before terminal success evidence, and before any manifest/registry eligibility. A validator failure returns/evidences `validation-failed`; tests must never manually validate only after `submitStage` already returned success.
- Require and validate every requested provider output or invoke the already-proved mechanical fallback with explicit provenance. For refine, require the complete expected PBR set and prove maps are actually referenced/bound, not merely named in a URL list.
- Strengthen GLB validation beyond R3's shallow implementation. At minimum validate all container/chunk alignment and padding; buffers/bufferViews/accessors with offsets, strides, component sizes, counts, sparse data, and bounds against actual bytes; every scene/node/mesh/primitive/attribute/index/material/texture/image/sampler reference; POSITION presence; supported primitive modes and correct triangle counts for triangles/strips/fans; finite transforms; finite position bounds; node graph cycles/out-of-range references; embedded image ranges/MIME types; UV requirements; real category triangle budgets; giant bounds; and required pipeline sidecar metadata for units/up-axis/pivot/scale/contact.
- Strengthen USDZ validation: EOCD and central-directory bounds/count/size; local/central header agreement; flags/encryption/data-descriptor/Zip64 policy; entry data range; duplicate/case-collision paths; traversal/absolute/NUL/backslash hazards; CRC32; per-entry/total size bounds; required root USD file; bounded `usdchecker` and `usdchecker --arkit`; bounded `usdcat`; default prim; finite positive meters-per-unit; valid up axis; finite transforms/bounds; nonempty meshes; material binding; texture references resolving to actual packaged entries; required PBR shader bindings; and recorded nonfatal diagnostics.
- Add adversarial fixtures proving every property above can fail. A four-byte marker, truncated ZIP entry, out-of-range accessor, missing POSITION, invalid scene reference, fake texture name without binding, corrupt CRC, symlink, giant transform, or unbounded tool process must never pass.
- Revalidate the two real provider-native USDZ candidates, the mechanically derived GLB/LODs, runtime USDZ, Apple framework evidence, iOS simulator evidence, and runtime thumbnail. Do not regenerate/alter the candidate creatively.

## F. Historical evidence and reporting

- Preserve R3 evidence and its false `blockers:[]` statement unchanged as failed historical evidence. In R5 evidence, explicitly record R4's FAIL and every superseded claim.
- Append, never edit, ledger records for the R4 independent-review FAIL, manager-discovered reference/prompt/schema/validator blockers, zero-credit R5 correction, and R5 outcome. Keep all ten pre-R5 lines byte-identical.
- Keep production `ASSET_MANIFEST.json.assets` empty and the historical candidate test-only/not-approved.
- Regenerate complete changed-file/checksum/path/syntax/test/redaction/cross-reference evidence only after final files exist. Name all self-exclusions.
- Report the exact commit and actual changed-file count; do not repeat R1/R3 count discrepancies.

## Mandatory gates

Run every command through `boost`. At minimum:

1. task/input/reference/candidate hashes and file existence/type/non-symlink checks;
2. all prior 211 tests plus adversarial tests for every requirement above;
3. official-schema-aligned fake server tests (`{result}` creation response, opaque ID, documented statuses/fields);
4. 127/127 unique leaf request bodies, every preview prompt 1–600 characters, exact checksum/body parity, zero duplicate submittable payload hashes;
5. 208 ordered parity, 206+2 formula, exact 79 precision rows, correct v1 future endpoints, zero accidental submittability;
6. production direct-call API-key/HMAC/field-tamper/expiry/replay/concurrency/cross-process tests;
7. exactly one physical POST for all 3xx/4xx/5xx/timeout/malformed outcomes;
8. DNS pinning/rebinding/private-IP and download-host allowlist tests;
9. hard bound/content-type/malformed/oversize/timeout tests for creation, polling, redirects, tools, and downloads;
10. durable pre-network journal and terminal evidence tests for every return/throw path, symlink rejection, crash/incomplete recognition, no-overwrite, partial-file semantics, and secret/signed-URL scan;
11. integrated corrupt-GLB/missing-PBR/corrupt-USDZ tests that return `validation-failed`, never `succeeded`;
12. expanded GLB/USDZ adversarial parser tests and real-candidate validation;
13. CLI successful fake-server run proves stdout contains no raw bytes/secrets and remains bounded;
14. syntax checks for every JS/Python/Swift script, JSON/JSONL/schema parse, ledger immutability, manifest/cost/plan cross-reference;
15. Apple framework, installed iOS simulator, thumbnail checksum/dimensions, mechanical lineage and LOD evidence remain valid;
16. full changed-path allowlist and `git diff --check`;
17. protected root HEAD/tracked diff fingerprint remain unchanged; and
18. one clean Sonnet-authored child commit of `e8c4205` with a clean worktree.

Do not weaken tests, silently skip tools, relabel standalone validation as integrated validation, or claim a false pass.

## Result

Return `COMPLETE_FOR_REVIEW` only when every R4 blocker, every manager blocker, and every gate above passes. Otherwise return `PARTIAL` with exact remaining blockers and preserve Phase 3 as blocked.

Return exactly these sections:

1. `STATUS`
2. `AGENT_RUN_ID`
3. `CHANGED_FILES`
4. `COMMIT`
5. `OFFICIAL_PROVIDER_CONTRACT`
6. `GENERATION_PLAN`
7. `LIVE_SECURITY_AND_EVIDENCE`
8. `INTEGRATED_VALIDATION`
9. `COMMANDS_AND_GATES`
10. `MESHY_TASKS_AND_CREDITS`
11. `CHECKSUMS`
12. `LIMITATIONS`
13. `BLOCKERS`

Report `AGENT_RUN_ID` exactly as `2C9ED49B-3A3C-4967-87D4-C98FA4EDB05A`. Do not invent another ID or guess the canonical model.
