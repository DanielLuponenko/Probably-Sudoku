# MESHY-002-R6B-R2 — Independent transport, authorization, and evidence review

## Identity

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Review task/run ID: `95150695-E2D1-4561-A11B-A54B6C5F84EF`
- Reviewer: `sonnet-independent-reviewer`, requested model `sonnet`; no nested agents.
- Strictly read-only worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002-transport`
- Candidate: `7dcfc2dd5ebf8e2dcb5b1beeab7668f1b642bed7`
- Required parent: `e46b3407e9342ca72df8a0aad8db06993e93d68d`
- Author run: `BD8E89BB-2D7F-4643-B00D-74EBA344B771`; structured result proves canonical `claude-sonnet-5`, zero subagents, result UUID `4391ea6c-b229-48dc-893e-2fa5674b2fd8`.
- Author contract: `/Users/daniel/NumberClub/docs/meshy-production/tasks/MESHY-002-R6B-live-transport-and-evidence.md`, SHA-256 `253482bac63b30425d52254edc0898eaed35f832054a043a29b4471fb6840ec9`.

Review independently and read-only. Read the master, R1–R5 history, full author contract/result, complete candidate diff, every changed file/test, and all R6B evidence. Use temporary paths only for reproduced tests. Do not edit, regenerate tracked files, commit, spawn agents, sample the diff, or trust author claims.

## Required audit

1. Verify exact commit/parent/cleanliness/one-commit history/changed-path allowlist, no prior evidence or app/Xcode/plan/ledger/manifest mutation, zero Meshy calls/credential reads, and protected-root preservation.
2. Reproduce all 330 tests, syntax, JSON/schema, hashes, secret/redaction scan, `git diff --check`, CLI e2e, HTTPS certificate/SNI pinning test, and cross-process reservation tests. Ensure tests were not weakened.
3. Trace production `submitStage` and CLI paths from input through network. Prove nonempty runtime API key, HMAC secret, signed non-fixture approval, replay destination, and evidence destination are mandatory before any network call, with no production-reachable fixture/test-loopback/base-URL bypass.
4. Verify canonical HMAC signing covers every required mutable field and byte form, including canonical asset/family/stage/environment/host/method/endpoint/model/attempt/credits/body hash/evidence destination/trusted replay root or exact path/user confirmation/approval+expiry/output-bound policy. Test each field tamper, wrong environment, replay, expiry, and cross-process concurrency.
5. Prove durable approval+payload reservation before the physical POST. For every 301/302/303/307/308, 4xx, 429, 5xx, socket failure, timeout, malformed/oversize/wrong-content-type body, and bare/malformed 2xx, independently prove physical creation POST invocation count exactly one, no redirect/retry/reissue, and authoritative/null credit semantics.
6. Audit official `{result}` opaque task-ID handling and safe URL encoding; no UUID assumption or unsafe segment acceptance.
7. Audit the actual production TLS request path, not a preflight: injected/testable resolver; reject all private/loopback/link-local/unspecified/multicast IPv4/IPv6, mapped/alternate/numeric forms, any mixed answer, rebinding; pin the accepted address on the actual socket while checking original hostname SNI/certificate. Prove API host exactly `api.meshy.ai`.
8. Audit output downloads separately. Require an explicit reviewed Meshy asset-host allowlist, reject arbitrary otherwise-public hosts, revalidate every GET redirect/address, cap redirects, disallow userinfo/ports/fragments/path escapes/signed-query leakage, and preserve bounded transport semantics.
9. Audit immutable production bounds against Infinity/NaN/negative/excessive overrides for connect/body/overall times, response bytes, JSON depth/shape, redirects, poll attempts/elapsed time, per-file/total bytes, content types, and output/tool sizes. Ensure malformed bodies fail durably rather than throwing before evidence.
10. Trace the crash-safe evidence journal. It must exist durably before network, use exclusive/no-follow/path-contained operations, carry immutable sequence and recognizable incomplete state, and record a precise event/outcome for every return/throw path. The author's limitation that many exceptions collapse into generic `threw` + `errorMessage` is presumed insufficient if it cannot mechanically distinguish required outcomes.
11. Audit symlink/hardlink/path attacks at every controlled segment and time: evidence root, replay root, downloads dir, precreated file, ancestor replacement race, mid-bundle failure, no overwrite. Lexical prefix tests alone fail.
12. Audit streaming `.partial` files, per-file/total bounds, hashing, atomic rename, failed-partial semantics, and public/stdout redaction. Raw Buffers may exist transiently internally only if bounded and necessary for validation; they must never appear in public outcome/evidence/stdout. Ensure API keys, HMAC secrets, auth headers, query/fragments, signed URLs, or raw provider URLs cannot persist.
13. Inspect every new/adapted test for tautology, shared implementation bugs, mocked physical-count claims, test-only bypass leakage, weak assertions, race flakiness, or missing failure paths. Inspect evidence counts/checksums after the author's amend.

## Verdict

Return `PASS` only when every R6B contract item is implemented and proven. Any missing host allowlist, outcome journal, path safety, bound, signed field, or exactly-once case is `FAIL`. Provide exact file:line/symbol/test evidence and corrections. Sections: VERDICT, REVIEW_RUN_ID, COMMIT_AND_SCOPE, REPRODUCED_GATES, AUTHORIZATION, EXACTLY_ONCE, DNS_PINNING, DOWNLOAD_HOSTS, BOUNDS, JOURNAL_AND_PATH_SAFETY, OUTPUT_REDACTION, TEST_QUALITY, FINDINGS, REQUIRED_CORRECTIONS, MODEL_AND_REPORTING, ZERO_CREDIT_AND_ROOT_PROOF. Report the review ID exactly.
