# MESHY-002-R4 — Independent Phase 3 security and pipeline review

## Authority and identity

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Review task: `MESHY-002-R4`
- Manager run/session ID: `1BAAD20D-AF31-40AA-ABDA-36C67FE86DCB`
- Agent: `sonnet-independent-reviewer`
- Requested model: `sonnet`; the Codex manager will verify the canonical resolved model from the structured CLI result.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002`
- Branch: `feature/KAN-153-meshy-pipeline`
- Review target: `e8c42053746739590f5605d9d33274b7b4839572`
- Required parent: `7797833d251f4c32790c0610734d3a4e68b7aa3c`
- Author run: `MESHY-002-R3`, session `16090EC3-1C53-4ACA-839E-AF10EB6F05DE`, canonical implementation model `claude-sonnet-5`, no nested agents.
- Prior independent review: `MESHY-002-R2`, verdict `FAIL` against R1.

You are an independent reviewer. Make no file edits, commits, Meshy calls, or nested-agent calls. Do not trust the author report or passing tests. Read the master prompt, R1/R2/R3 contracts, the complete target diff and every changed file, accepted Phase 1/2 controls, author evidence, and relevant tests in full. Run read-only gates through `boost`. Return evidence-backed findings and a strict `PASS` or `FAIL`; do not repair anything.

## Zero-credit and repository boundary

- Consume exactly zero Meshy credits and make no Meshy mutation request.
- Do not access or expose credentials.
- Do not edit either the isolated worktree or `/Users/daniel/NumberClub`.
- Verify the protected root remains at `942e0b4890645a306fc4e39140139de27b5dfbbb` and its tracked diff SHA-256 remains `4b1eff19b9ac64311432ecadfeb12f954b5e8552786ed082021a125aa7be89f8`.
- Verify the review target is one clean Sonnet-authored child of `7797833` and its 82 changed paths stay inside the R3 allowlist.

## Mandatory independent audit

Reproduce, rather than merely read, all applicable R3 gates: 211-test suite, syntax, plan/coverage order and totals, 79 fail-closed precision rows, prompt/body/checksum parity, cost formulas, ledger append-only integrity, artifact and evidence hashes, real GLB/USDZ validation, Apple/iOS evidence, redaction, path allowlist, and root protection.

Audit the production live-call path end to end from `meshy-cli.mjs` through approval, reservation, HTTP creation, polling, download, validation, preservation, and terminal reporting. Trace every return and throw path. Prove or reject each of these properties:

1. exactly one paid creation POST under all redirects and failures;
2. HMAC-authenticated, exact-body, exact-credit, exact-attempt, exact-destination, user-confirmed authorization that cannot be bypassed by calling a library directly;
3. API key is mandatory in production and can never reach logs, evidence, returned output, or errors;
4. replay state is atomic, durable, path-contained, and reserved before the network call;
5. production API and download destinations resist hostname, literal-IP, redirect, DNS-resolution/rebinding, userinfo, path, symlink, and private/link-local SSRF techniques;
6. creation, polling, response JSON, redirects, and downloads have hard attempt/time/status/content-type/body-byte bounds that callers cannot silently make unbounded;
7. every outcome—including pre-response uncertainty, malformed success, 429/5xx, poll timeout, retry exhaustion, malformed status, provider failure/cancel, partial download, redirect rejection, checksum failure, validator failure, and success—is durably evidenced without overwrite or secret leakage;
8. downloaded GLB/USDZ/PBR output is validated inside the submission pipeline before any `succeeded` result or manifest/registry eligibility, with the validation report preserved;
9. credit reporting never invents zero when provider/task state is uncertain and preserves provider-reported charges exactly;
10. evidence creation is all-or-nothing or otherwise explicitly crash-safe, and lexical containment cannot be bypassed with pre-existing symlinks;
11. the operator CLI does not serialize large raw model buffers to stdout or create an avoidable memory-amplification path; and
12. tests assert the real integrated behavior rather than manually invoking validation after `submitStage` has already returned success.

## Manager-observed risks that must be confirmed or disproved

These are leads, not instructions to rubber-stamp a failure. Cite exact file:line evidence and tests.

- `submit.mjs` appears to call `persistAttemptEvidence` only on the final success path; earlier uncertainty, HTTP error, poll timeout, provider-failed/canceled, malformed, download, and validation paths may leave no durable attempt evidence.
- `submitStage` appears not to invoke `validateStageOutput` at all. Current tests explicitly call validation after an outcome already reports `reasonCode:'succeeded'`, including malformed GLB and missing-PBR cases.
- `fetchWithApprovedRedirects` can issue a second POST after a 307/308, which may conflict with the exactly-once paid-POST invariant.
- direct production calls appear able to omit `opts.apiKey` and still reach the network.
- download SSRF checks appear lexical only; a public-looking hostname resolving to a private/link-local address and symlinked evidence directories may not be contained.
- polling/download response content types and JSON/body sizes appear unbounded; several retry/parser errors appear to throw before preservation.
- creation 429/5xx paths appear to assert `consumedCredits:0` without a task record proving that no task materialized.
- `persistAttemptEvidence` writes sequentially and may leave a partial bundle when a later exclusive write fails.
- successful outcomes appear to retain raw `Buffer` objects, which the CLI then JSON-serializes.

Look for additional blockers beyond this list. Review real validators for shallow-marker evasion, accessor/buffer bounds, PBR binding proof, USDZ ZIP safety, tool-output interpretation, runtime-derivative lineage, screenshot provenance, deterministic claims, and manifest eligibility.

## Verdict rule

Return `PASS` only if every Phase 3 exit condition and every R3 correction is actually met by integrated production code and reproducible evidence. Any exploitable bypass, false success, missing durable evidence path, invented credit state, unvalidated output, shallow proof, changed protected input, or unclosed R2/R3 condition requires `FAIL`.

Return exactly these sections:

1. `REVIEW_IDENTITY`
2. `VERDICT`
3. `BLOCKING_FINDINGS` ordered by severity with exact file:line evidence, executable reproduction, impact, and required correction
4. `NON_BLOCKING_FINDINGS`
5. `REPRODUCED_GATES`
6. `MODEL_AND_AGENT_PROOF`
7. `MESHY_TASKS_AND_CREDITS`
8. `ROOT_AND_COMMIT_INTEGRITY`
9. `LIMITATIONS`

Report `REVIEW_RUN_ID` exactly as `1BAAD20D-AF31-40AA-ABDA-36C67FE86DCB`. Do not invent a different ID or self-assert a canonical model name not available to you.
