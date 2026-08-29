# MESHY-002-R6A — Canonical leaf request specifications

## Authority

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Superseded failed/partial work: MESHY-002-R3, R4, and R5.
- Task/run ID: `79AEB685-2951-44C4-9B15-1D2A5A054FFE`
- Agent: `sonnet-meshy-pipeline-engineer`, requested model `sonnet`; no nested agents.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002-leafspec`
- Branch: `feature/KAN-153-meshy-leafspec`
- Exact parent: `e46b3407e9342ca72df8a0aad8db06993e93d68d`

This is production implementation by Claude Sonnet. Read the master, MESHY-001 controls, accepted Phase 2 briefs, MESHY-002 R1–R5 contracts/evidence, the complete parent commit, and every plan-generation file/test before editing. Do not reduce scope or reinterpret the canonical inventory.

## Zero-credit boundary

Make no Meshy API call, read no credential, and consume zero credits. All work is deterministic local specification, plan generation, and tests. Official documentation GETs are allowed but not required; the provider facts below are binding.

## Exclusive writable paths

- `docs/meshy-production/pipeline/**`
- `docs/meshy-production/evidence/MESHY-002-R6A/**`
- `docs/meshy-production/MESHY_GENERATION_PLAN.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.md`
- `scripts/meshy/lib/plan.mjs`
- new leaf-specification/request-building modules under `scripts/meshy/lib/**`
- `scripts/meshy/bin/build-plan.mjs`
- new or directly relevant plan/leaf tests under `scripts/meshy/test/**`

Do not edit the ledger, manifest, R1/R3/R5 evidence, task contracts, accepted briefs, application code, Xcode configuration, agent definitions, transport/submission/evidence/validator modules, or unrelated tests.

## Required implementation

1. Author a pipeline-owned, machine-readable leaf specification for all 208 canonical ordered rows. It must preserve accepted coverage IDs/families/visibility/dead-code classifications and add explicit leaf subject, physical form, material/finish, gameplay or storefront purpose, relation/lineage, provider mode, endpoint, and request eligibility.
2. For each of the 127 currently submittable Text-to-3D preview sources, create one semantically distinct provider-compatible request body. The prompt must be 1–600 characters, affirmative, visually/materially specific, and unmistakably identify the actual part and purpose. Do not create uniqueness by appending an ID, nonce, invisible marker, ordinal, or otherwise generic token. Distinguish every structural/shop/environment part and every shop paper item from gameplay paper.
3. Produce 127 unique exact serialized HTTP bodies and 127 unique SHA-256 body hashes. Generated plan body/hash must be byte-for-byte reproducible from the leaf spec. Global replay protection must permit every intended request exactly once.
4. Preserve all 79 digit/grid precision rows as fail-closed, non-submittable, awaiting approved orthographic sheets. Assign exactly one correct future provider mode per row: single-sheet rows use `POST /openapi/v1/image-to-3d`; rows genuinely requiring multiple views use `POST /openapi/v1/multi-image-to-3d`. Record the exact future schema and expected credits, but do not invent image paths/URLs/checksums or make any row eligible.
5. Preserve exactly 208 rows in canonical order, 206 visible + 2 dead-code, all coverage IDs, cost accounting, correct approved bookstore reference paths/hashes, and empty production manifest eligibility.
6. Avoid prose-only claims. The specification and generated plan must be schema-validated, deterministic, and directly consumable by the later live submission pipeline.

## Mandatory proof

- All pre-existing tests remain green.
- Exact 208/order/206+2 parity; 127 submittable; 79 awaiting precision reference; 2 dead-code.
- 127/127 unique semantic leaf subjects, prompts, exact serialized bodies, and SHA-256 body hashes; every prompt 1–600 characters.
- Automated genericity checks plus explicit tests for easily conflated pairs: floor slab vs runner rug, beam vs rail, shelf vs book, stand base vs display plinth, storefront paper vs gameplay paper, each paper style, and distinct environment/shop components.
- Every body/hash in the generated plan recomputes from the canonical leaf artifact exactly.
- All 79 pending rows have correct v1 future endpoints and remain non-submittable with no fabricated image source.
- Approved `bookstore-aisle.html` and `bookstore-aisle-rendered.html` exist, are regular non-symlink files, and match their fixed SHA-256 values.
- Deterministic regeneration twice produces byte-identical plan/cost/spec artifacts.
- JSON/JSONL/schema parse, syntax, cross-reference, changed-path allowlist, `git diff --check`, secret scan, protected-root HEAD/diff preservation.
- Evidence records every command/result and final checksums after files are final.

## Delivery

Create exactly one clean Sonnet-authored child commit of the exact parent, only within the writable paths. Return `COMPLETE_FOR_INTEGRATION` only if every requirement and proof passes; otherwise return `PARTIAL` with exact blockers. Report: STATUS, AGENT_RUN_ID, CHANGED_FILES, COMMIT, SPECIFICATION, GENERATION_PLAN, TESTS_AND_GATES, ZERO_CREDIT_PROOF, CHECKSUMS, LIMITATIONS, BLOCKERS. Report the run ID exactly.
