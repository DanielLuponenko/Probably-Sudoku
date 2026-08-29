# MESHY-002-R1 — Phase 3 zero-credit production pipeline

## Authority and run identity

- Binding master contract: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Task ID: `MESHY-002-R1`
- Manager run/session ID: `F353EE1A-1255-410F-87AD-D5004E68A926`
- Assigned agent: `sonnet-meshy-pipeline-engineer`
- Required requested model: `sonnet`
- Required canonical resolved model: a Sonnet-family model, recorded by the
  manager from the structured CLI result; self-identification is insufficient.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002`
- Branch: `feature/KAN-153-meshy-pipeline`
- Accepted visual parent: `9f9d8722f6626bcd4c25da870ecc9fbab4f2ab7f`
- No nested agents. The author may not approve its own output.

This task implements and proves the Phase 3 pipeline. It does not approve any
production asset, coverage row, runtime scene, or visual result.

## Exact objective

Build a reproducible Meshy-only production pipeline that:

1. inspects current official Meshy documentation and changelog at execution
   time and records the decision timestamp and source URLs;
2. pins exact supported model identifiers and request parameters rather than a
   mutable `latest` alias;
3. expands the accepted 208-row coverage ledger and 43 accepted generation
   families into a complete generation-mode plan and a mechanically checked
   low/expected/high credit estimate;
4. produces deterministic dry-run payloads with exact credit estimates;
5. refuses every live paid request unless an external Codex-authored approval
   record exactly matches the endpoint, payload checksum, model, attempt,
   maximum credits, and unique approval ID;
6. performs bounded polling/retry, redaction, immutable payload/response
   preservation, immediate output download, SHA-256 accounting, native-USDZ
   validation, GLB-to-USDZ fallback conversion, PBR/geometry/scale/pivot checks,
   runtime derivative validation, and runtime thumbnail generation;
7. proves the pipeline against one real historical Meshy candidate through
   read-only GET/download operations only, without promoting that candidate to
   production or spending credits; and
8. records exact evidence without credentials, invented provider facts, hidden
   fallbacks, placeholders, or visual redesign.

## Zero-credit execution boundary

The complete author run must consume exactly `0` new Meshy credits.

- No live `POST`, `PUT`, `PATCH`, or `DELETE` request may be made to Meshy or a
  provider output host in this run.
- Live external network access is limited to `GET`/`HEAD` requests for official
  pages under `https://docs.meshy.ai`, authenticated read-only account/balance
  or task-detail endpoints under `https://api.meshy.ai`, and the fresh signed
  download URLs returned for the two candidate task IDs below.
- Paid-submit code must be implemented and tested only against a localhost fake
  server. A dry run must never send a network request.
- A locally generated approval fixture is test data only and cannot authorize a
  live call. The production guard must reject it unless an explicit live flag
  and a matching external approval record are both supplied.
- If any required validation cannot be completed without a new paid task, stop
  with `PARTIAL` and report the exact proposed task, payload checksum, and
  current documented credit charge. Do not submit it.

Read-only historical candidate IDs:

- Preview: `01a04a31-dc48-74a3-8818-d38f6ab55499`
- Refine: `01a04a33-5e3c-73bb-971e-920c0a57cbce`

These tasks and all existing local derivatives remain
`CANDIDATE_ONLY_NOT_APPROVED`. They may be used solely to prove preservation,
validation, conversion, manifest, checksum, Apple-runtime load, and thumbnail
machinery. Fresh task responses must have credentials and signed-query secrets
redacted before persistence. Do not place an expiring signed URL in the ledger.

## Writable paths — exact and exclusive

Only these paths in the assigned worktree are writable:

- `scripts/meshy/**`
- `Artifacts/Meshy/MESHY-002-R1/**`
- `docs/meshy-production/pipeline/**`
- `docs/meshy-production/evidence/MESHY-002-R1/**`
- `docs/meshy-production/MESHY_GENERATION_PLAN.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.md`
- `docs/meshy-production/ASSET_MANIFEST.json`
- `docs/meshy-production/MESHY_TASK_LEDGER.jsonl`, append-only; the two seeded
  records must remain byte-identical and in the same order.

The author may commit only files under those paths. It may not edit this task
contract, agent definitions, manager logs, risk/decision/review documents,
application code, Xcode project configuration, the accepted briefs/ledgers, or
the existing root WIP script.

## Required read-only inputs and exact checksums

Read each input in full before implementation. Reject the run if a checksum
does not match.

| Input | SHA-256 |
|---|---|
| `/Users/daniel/meshy_club_shop_master_prompt.md` | `473e52da4c5ba2622ed3021f3d08564cc3e563495278e4c6eb228930fdde520c` |
| `docs/meshy-production/GENERATION_BRIEFS.json` | `0b43c05699c5341587d28d0f9d333ff16d64f1b11b7d1e79845810cc804b3312` |
| `docs/meshy-production/GENERATION_BRIEFS.md` | `8625f6562361ca1b5125b9080534e17a06e0bb9aeb82c19da4b5ea3736c3abb3` |
| `/Users/daniel/NumberClub/docs/meshy-production/COVERAGE_LEDGER.json` | `99e88c80cab01dc11b7ca39f8408a8d71671d1c6222ea826b4b2e0b83d372b2e` |
| `/Users/daniel/NumberClub/docs/meshy-production/COVERAGE_LEDGER.csv` | `73c898a0b85df4da6731c7c886aa62c6ccfb96ed71ac207d868e36567bcd1d2c` |
| `/Users/daniel/NumberClub/docs/meshy-production/AUDITED_CANONICAL_LEAVES.json` | `03baad57d4d1f4aa50783eceb5d1a8c3f042f22d6993ce2c9049a455d1fcd3d0` |
| `/Users/daniel/NumberClub/docs/meshy-production/CATALOG_AUDIT.json` | `47aeaf93fd4e1d3cde0687f02f9e375cba0eabb34cb77c7886b088060d10dd99` |
| `/Users/daniel/NumberClub/docs/meshy-production/VISUAL_INVARIANTS.md` | `e6460111af821ea109e4efcf87a90613c83e8c92f207a358ebaf08feebfb0287` |
| `/Users/daniel/NumberClub/docs/meshy-production/REFERENCE_INDEX.md` | `8a5f2885796f39daabbb558f6f96c11856a55db8f0e8d7d90eedae0ac13d9080` |
| `/Users/daniel/NumberClub/docs/meshy-production/PERFORMANCE_BUDGETS.md` | `01a99790498baf5075c612170e63964b2a1a45ef831511b0b5279f3a737c7b7f` |
| seeded `docs/meshy-production/ASSET_MANIFEST.json` | `8e4977b2ae6c700115f2677c12aa36fac00f23ec7c234ba96cb3dff11862cde3` |
| seeded `docs/meshy-production/MESHY_TASK_LEDGER.jsonl` | `cba55926a67514c36510fb7ff342154f3e54c0ac1cb15d405cbec615d394bb13` |
| `/Users/daniel/NumberClub/scripts/gen-shop-models.mjs` | `9383c13d587f81512cbdf343797c116b1f01671de48ebc9382ca12a5588d502b` |
| approved mockup HTML | `0934eaa191d573b450d82f607476bc8bd67b7c8f36011d78a5305b7081e42561` |
| approved rendered mockup HTML | `c33a6f03bd2e977ec55c2ed87b2005565edf26d8fe2790347c1bda81de0895f4` |

The two mockup files are at
`/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/`.
The root WIP script is audit input only. Do not copy, adopt, execute, or modify it
without first identifying every unsafe or irreproducible behavior.

## Official-source requirements

At minimum, inspect the live official pricing, changelog, and relevant endpoint
pages under `docs.meshy.ai`. Technical claims may rely only on official Meshy
documentation. Record:

- source URL and observation timestamp;
- current exact model identifiers and which endpoints/modes accept them;
- endpoint, parameter, PBR-map, format, output, task-response, and
  `consumed_credits` behavior;
- current price formula for every mode used by the generation plan;
- deprecated parameters and mutable aliases that the pipeline rejects; and
- whether emission/emissive output is currently documented, correcting the
  seeded historical claim if the live official source contradicts it.

Do not silently reinterpret missing documentation as a capability. Represent
unknowns explicitly and make the validator fail closed where required.

## Required implementation behavior

### Deterministic manifests and estimates

- Define versioned schemas for generation specifications, approval records,
  attempts, provider responses, preserved outputs, runtime derivatives,
  validation reports, and immutable ledger append records.
- Expand all 208 accepted canonical IDs exactly once: 206 visible rows and two
  dead-code removal rows. Preserve the accepted ordered ID sequence. Dead-code
  removal rows cost zero and may never create a Meshy task.
- Map every visible row to one accepted family and an explicit generation mode.
  Do not combine distinct required digit identities into an untraceable task.
- Calculate low, expected, and high totals from the live official pricing and
  explicit attempt/texture/quality assumptions. Show formulas and per-category
  subtotals. No guessed hidden discount and no invented budget ceiling.
- A dry run emits canonical JSON, payload SHA-256, exact expected credits,
  endpoint, model, and zero-network proof.

### Paid-call guard

- Default to dry-run/offline behavior.
- A live create/refine/retexture/remesh/convert call requires all of:
  `--live`, a non-fixture external approval file, unique approval ID, exact
  unredacted payload checksum, exact model and endpoint, exact attempt number,
  exact maximum credit authorization, non-expired approval timestamp, and an
  explicit destination evidence directory.
- Fail closed on any mismatch, missing field, duplicate approval ID, reused
  accepted payload, unknown official price, `latest` alias, deprecated quality
  parameter, or attempt beyond the approved bound.
- Redact API keys and authorization headers from errors, debug logs, manifests,
  fixtures, and persisted responses.
- The shipped app must never contain the Meshy key or make a Meshy request.

### Polling, retry, preservation, and validation

- Bound HTTP retries, poll attempts, elapsed time, and backoff. Reason-code
  transient, permanent, timeout, provider-failed, canceled, validation-failed,
  and approval-failed states.
- Creation retries may not silently resubmit a paid task. Default maximum is
  three paid generation attempts per asset specification; a fourth requires a
  materially changed brief and a new Codex decision/approval.
- Preserve redacted request and response payloads, task/model/mode/timestamps,
  prompt and reference hashes, reported actual credits, retry data, downloads,
  tool versions, and SHA-256 for every byte artifact.
- Download successful outputs immediately. Preserve provider-native USDZ and
  highest-quality GLB when exposed. Never overwrite a source artifact.
- Validate native USDZ first. Mechanically convert from preserved GLB only when
  native USDZ fails or is absent, record why, and preserve both paths.
- Validate file/non-empty, parse/open, finite transforms, bounds, axis, units,
  scale, pivot metadata, hidden giant geometry, materials, required PBR maps,
  UVs, triangle budgets, lineage, checksum parity, Apple-runtime loading, and a
  deterministic runtime thumbnail. Use mechanical optimization only.

## Historical-candidate proof

Use authenticated read-only GETs to inspect the two authorized task IDs and the
current balance. If current signed downloads are exposed, download the real
candidate outputs to `Artifacts/Meshy/MESHY-002-R1/**`, preserving and hashing
them. Do not record API keys or signed-query secrets.

Register a clearly non-production `pipelineTestAsset` in
`ASSET_MANIFEST.json`; do not add it to the production `assets` array and do
not alter any coverage-row status. Produce a separately rendered runtime
thumbnail from the actual test asset, not the provider thumbnail. Prove native
USDZ validation and the fallback-conversion path. If no provider GLB is
available, a mechanically derived test GLB from the same real Meshy candidate
may exercise conversion only when it is labelled truthfully as test-only and
never represented as provider-native source.

Append, without changing either seeded line, a zero-credit preflight record and
historical-candidate validation record to `MESHY_TASK_LEDGER.jsonl`. Record
actual credits reported by historical responses separately from the run's new
credits (`0`).

## Required tests and commands

Every shell command must pipe output through `boost`. At minimum run and report:

1. task/input checksum verification;
2. `node --test` for every test under `scripts/meshy/**`;
3. static syntax checks for every JavaScript module;
4. official-doc decision/schema validation;
5. 208-ID plan parity, uniqueness, family mapping, and 206+2 formula checks;
6. cost-estimate formula recomputation from the plan;
7. dry-run determinism and zero-network proof;
8. fake-server happy paths and failures for create, approval mismatch,
   duplicate approval, model/price mismatch, timeout, 429/5xx, provider failure,
   cancellation, malformed response, bad checksum, missing map, invalid bounds,
   and retry exhaustion;
9. authorization/API-key redaction scans over every changed or generated file;
10. read-only live auth/balance/task-detail proof with before/after balance
    equality and `0` new credits;
11. `usdchecker`/available USD tools, GLB/PBR/geometry validation, native USDZ
    validation, fallback conversion, Apple-runtime load, and deterministic
    thumbnail checksum for the historical candidate;
12. JSON/JSONL parse checks, source/runtime checksum recomputation, and manifest
    cross-reference checks;
13. `git diff --check` and exact changed-path validation; and
14. a clean committed task branch with a single Sonnet-authored implementation
    commit whose parent is the manager seed commit.

Do not suppress, weaken, or skip a failing test. Report unavailable host tools
as exact evidence; use an allowed existing toolchain alternative when it
preserves the contract.

## Acceptance criteria

The author may return `COMPLETE_FOR_REVIEW` only if all of these are true:

- the structured run proves canonical Sonnet, zero nested agents, and zero new
  Meshy credits;
- official live docs support every pinned capability and price claim;
- all 208 IDs are covered exactly once by the generation plan and estimate;
- dry-run and paid-call guards are fail-closed and mechanically tested;
- secrets are absent from persisted artifacts and error output;
- the real historical candidate proves download/preservation/checksums,
  native-USDZ validation, fallback conversion, Apple-runtime loading, separate
  runtime-thumbnail generation, and manifest/ledger cross-reference;
- every required command passes;
- only allowed paths changed; and
- the changes are committed, but no asset or Phase 3 gate is self-approved.

Otherwise return `PARTIAL` with exact blockers. Independent Sonnet review and
Codex acceptance remain mandatory even after `COMPLETE_FOR_REVIEW`.

## Required result format

Return exactly these top-level sections with exact values or `NONE`:

- `STATUS`
- `AGENT_RUN_ID`
- `RESOLVED_MODEL`
- `BRANCH`
- `COMMIT_OR_PATCH`
- `CHANGED_FILES`
- `LEDGER_ROWS_AFFECTED`
- `OFFICIAL_DOCS_AND_MODEL_DECISION`
- `GENERATION_PLAN_AND_CREDIT_ESTIMATE`
- `COMMANDS_RESULTS`
- `SCREENSHOT_PATHS`
- `PERFORMANCE_DATA`
- `MESHY_TASKS_AND_CREDITS`
- `CHECKSUMS`
- `KNOWN_LIMITATIONS`
- `BLOCKERS`

## Rollback

Revert only the Sonnet implementation commit or use its recorded reverse patch
inside the isolated worktree. Never delete immutable source evidence or rewrite
append-only ledger history; append a superseding record after manager approval.
Never touch the protected root checkout.
