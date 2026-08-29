# MESHY-002-R6A-R3 — Affirmative leaf-prompt correction

## Authority

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Failed candidate: `797662876e5628a4ae1fe7934953d32abcd77c1c` from R6A author run `79AEB685-2951-44C4-9B15-1D2A5A054FFE`.
- Independent FAIL: R6A-R2 review run `8AD8AC13-A7F6-48AF-92F7-0822DEBAA4F4`, canonical `claude-sonnet-5`, result UUID `8599912b-e855-4efc-9a38-dc1d5ca730ca`.
- Correction task/run ID: `B9A12AC2-4F13-4EB9-B399-A09A5C347178`.
- Agent: `sonnet-meshy-pipeline-engineer`, requested model `sonnet`; no nested agents.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002-leafspec`.
- Branch: `feature/KAN-153-meshy-leafspec`.
- Exact parent: `797662876e5628a4ae1fe7934953d32abcd77c1c`.

Read the master, R6A author contract/result, complete candidate commit, R6A-R2 review contract/transcript/result summary, all 127 prompts, generators, tests, and evidence before editing. This is a binding correction; preserve the failed commit and review as immutable history.

## Zero-credit boundary

No Meshy API call, credential access, or network probe. Consume zero credits.

## Writable paths

- `docs/meshy-production/pipeline/LEAF_REQUEST_SPECIFICATIONS.json`
- `docs/meshy-production/MESHY_GENERATION_PLAN.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.json`
- `docs/meshy-production/MESHY_COST_ESTIMATE.md`
- `docs/meshy-production/evidence/MESHY-002-R6A-R3/**`
- `scripts/meshy/lib/leafSpec.mjs`
- `scripts/meshy/lib/plan.mjs` only if deterministic wiring genuinely requires it
- `scripts/meshy/bin/build-plan.mjs` only if deterministic wiring genuinely requires it
- `scripts/meshy/test/leafSpec.test.mjs`
- `scripts/meshy/test/plan.test.mjs` only for directly relevant regression coverage

Do not overwrite R6A evidence or edit any other path.

## Required correction

1. Re-read and editorially inspect all 127 submittable prompts. Rewrite every prompt so it states only the asset's positive subject, silhouette, construction, material/finish, scale/context, and intended physical role. Preserve genuine semantic distinction without comparing against a different asset.
2. Remove negative/exclusion constructions, including whole-word `not`, `no`, `never`, `without`, `unlike`, `except`, contractions such as `isn't`/`doesn't`/`can't`, and phrases such as `distinct from`, `different from`, `separate from`, `rather than`, `instead of`, `unrelated to`, `independent of`, `other than`, `avoid`, `exclude`, `non-*`, and parenthetical exclusions. Do not replace them with euphemistic negation.
3. Keep each prompt 1–600 characters and semantically specific. Retain 127 unique prompts/bodies/hashes without ID/nonce/ordinal tricks. Preserve the accepted visual direction and explicit shop/gameplay identities through affirmative descriptions (for example, “a bound retail stack…” versus “a single playable sheet…”).
4. Add a production validator that rejects negative-form/exclusion language in every submittable prompt. Use word-aware matching to avoid false positives inside unrelated words. Include adversarial tests for every forbidden word/phrase/contraction pattern and for euphemistic exclusion constructs, plus positive controls.
5. Regenerate leaf spec, plan, and cost artifacts deterministically; update only new R6A-R3 evidence. Preserve exact 208/order/206+2/127/79 counts, endpoints, approved-reference hashes, and all prior R6A correctness.

## Mandatory gates

- Independent script proves zero forbidden constructs across all 127 prompts, and the validator itself is tested against poisoned fixtures.
- Manual/evidence table lists every changed canonical asset ID and before/after prompt checksum; all 127 are explicitly re-audited even if some remain byte-identical.
- 127 unique affirmative prompts, bodies, and hashes; prompt range 1–600; full byte parity to generated plan.
- Full inherited + new tests, deterministic double regeneration, syntax/JSON/schema/cross-reference, hashes, secret scan, changed-path allowlist, `git diff --check`, clean worktree, protected-root HEAD/diff unchanged.
- Evidence does not copy or amend failed R6A evidence; it explicitly cites and supersedes the R6A-R2 blocker.

## Delivery

Create exactly one clean Sonnet-authored child commit of `797662876e5628a4ae1fe7934953d32abcd77c1c`. Return `COMPLETE_FOR_REREVIEW` only if every gate passes; otherwise `PARTIAL`. Report STATUS, AGENT_RUN_ID, CHANGED_FILES, COMMIT, PROMPT_CORRECTION, VALIDATOR_AND_TESTS, GATES, ZERO_CREDIT_PROOF, CHECKSUMS, LIMITATIONS, BLOCKERS. Report the run ID exactly.
