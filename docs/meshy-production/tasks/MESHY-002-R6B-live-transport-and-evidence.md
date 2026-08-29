# MESHY-002-R6B — Live transport, authorization, and crash-safe evidence

## Authority

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Superseded failed/partial work: MESHY-002-R3, R4, and R5.
- Task/run ID: `BD8E89BB-2D7F-4643-B00D-74EBA344B771`
- Agent: `sonnet-meshy-pipeline-engineer`, requested model `sonnet`; no nested agents.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002-transport`
- Branch: `feature/KAN-153-meshy-transport`
- Exact parent: `e46b3407e9342ca72df8a0aad8db06993e93d68d`

This is production implementation by Claude Sonnet. Read the master, MESHY-002 R1–R5 contracts/evidence, the complete parent commit, and every transport/authorization/submission/evidence/download file and test before editing. Close all R5 sections B–D; passing the inherited suite is not sufficient.

## Zero-credit boundary

Make no Meshy API call, read no credential, and consume zero credits. Use deterministic local servers, injected resolvers/transports, and fixtures only. Never probe `api.meshy.ai`.

## Exclusive writable paths

- `docs/meshy-production/evidence/MESHY-002-R6B/**`
- transport, authorization, replay, journal, evidence, download, schema, redaction, submission, CLI, and fake-server modules directly under `scripts/meshy/**`
- new or directly relevant tests/fixtures under `scripts/meshy/test/**`

Do not edit plan/specification/cost/ledger/manifest artifacts, accepted briefs, prior evidence, task contracts, application code, Xcode configuration, agent definitions, or binary validators except for typed interfaces strictly necessary to call them; the integration agent owns cross-track reconciliation.

## Required implementation

1. Production `submitStage` itself must fail before network unless it receives a nonempty runtime API key, HMAC secret, signed non-fixture approval, replay root, and evidence destination. Fixture bypasses must be structurally impossible in production mode.
2. Sign and verify canonical asset ID, family, stage, production environment, host, exact method/endpoint, pinned model, attempt, exact credits, exact HTTP-body hash, evidence destination, trusted replay root/path, user-confirmation reference, approval/expiry times, and every mutable output/bound policy. Tampering any signed field fails before network.
3. Durably and exclusively reserve approval ID + payload across processes before POST. Concurrent/replayed use must allow zero or one physical creator and deterministically fail the rest, leaving evidence.
4. Exactly one physical creation POST total. Manual redirect handling; never follow/reissue POST for 301/302/303/307/308. Every redirect, timeout, socket error, malformed response, 4xx, 429, and 5xx has invocation count one and a durable reconciliation outcome with `consumedCredits:null` unless an authoritative task record reports credits.
5. Parse bounded official `{result:"<opaque task id>"}` responses. Task IDs are safe nonempty single path segments, not UUID-constrained, and are URL-encoded before polling.
6. Replace preflight-only hostname checks with a real DNS-pinned TLS transport: injected resolver, reject any private/loopback/link-local/unspecified/multicast IPv4/IPv6 answer including mapped/alternate forms, reject mixed public/private sets, pin the approved resolved address for the actual request while validating original SNI/certificate, and prevent rebinding/TOCTOU.
7. API POST/GET allowlist is exactly `api.meshy.ai`. Download hosts use an explicit reviewed Meshy asset-host allowlist. Unknown hosts fail closed. Revalidate every allowed GET redirect and cap them; creation POST follows none.
8. Immutable production bounds cover connect/body/overall time, response bytes, redirects, poll attempts/elapsed time, per-file/total download bytes, content type, JSON depth/shape, and tool/output sizes. Caller Infinity/NaN/negative/excessive overrides fail or are ignored, never unbound production.
9. Create an exclusive, path-contained, redacted attempt journal before network and append immutable sequenced events plus terminal outcome. Crashes leave recognizable incomplete attempts. Every return/throw path is journaled: approval/reservation failure after eligibility, pre-response uncertainty, malformed creation, all HTTP classes, redirects, polling exhaustion/malformed/unknown/FAILED/CANCELED, download rejection/partial/mismatch/timeout, validation handoff failure, and success.
10. Reject symlinks in every controlled path segment with no-follow/exclusive primitives. Cover evidence root, replay root, downloads path, pre-created files, and mid-bundle write failures. Lexical `startsWith` is not sufficient.
11. Stream downloads into exclusive `.partial` files while bounding and hashing, then atomically rename only after verification. Failed partials stay labeled/evidenced and never count complete.
12. Public outcomes/stdout contain paths, sizes, hashes, validation summaries, task facts, and reason codes only—never raw Buffers, secrets, authorization headers, signed URL queries/fragments, or unredacted provider URLs.

## Mandatory proof

Add adversarial tests for every numbered requirement, including cross-process reservation, all redirect codes, physical POST count, IPv4/IPv6/mapped/numeric/private/mixed/rebinding/userinfo/port/fragment/path escape cases, redirect chains, bound override attacks, every journaled failure/throw path, symlink attacks, crash recognition, no-overwrite, partial files, malformed/oversize/content-type/timeout bodies, unknown status, exact provider credit preservation, and bounded secret-free CLI stdout. All inherited tests remain green.

Run syntax, JSON/schema parse, full test suite, changed-path allowlist, `git diff --check`, secret/redaction scan, and protected-root HEAD/diff preservation. Evidence must contain exact commands/results and final checksums.

## Delivery

Create exactly one clean Sonnet-authored child commit of the exact parent, only within writable paths. Return `COMPLETE_FOR_INTEGRATION` only if every requirement/proof passes; otherwise `PARTIAL` with exact blockers. Report: STATUS, AGENT_RUN_ID, CHANGED_FILES, COMMIT, AUTHORIZATION, EXACTLY_ONCE_POST, PINNED_TRANSPORT, EVIDENCE_JOURNAL, DOWNLOADS_AND_OUTPUT, TESTS_AND_GATES, ZERO_CREDIT_PROOF, CHECKSUMS, LIMITATIONS, BLOCKERS. Report the run ID exactly.
