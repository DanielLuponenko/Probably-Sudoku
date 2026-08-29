# MESHY-002-R6B-R3 — Output-host allowlist and real download bounds

## Authority

- Binding master: `/Users/daniel/meshy_club_shop_master_prompt.md`
- Failed candidate: `7dcfc2dd5ebf8e2dcb5b1beeab7668f1b642bed7`.
- Independent FAIL: R6B-R2 run `95150695-E2D1-4561-A11B-A54B6C5F84EF`, canonical `claude-sonnet-5`, result UUID `a64d279e-7ca1-40f7-b904-ead0b944100e`.
- Correction run ID: `EBAD0D4C-4846-48C9-B84A-EA50B5099867`.
- Agent: `sonnet-meshy-pipeline-engineer`, requested model `sonnet`; no nested agents.
- Worktree: `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002-transport`.
- Branch: `feature/KAN-153-meshy-transport`.
- Exact parent: `7dcfc2dd5ebf8e2dcb5b1beeab7668f1b642bed7`.

Read the master, R6B/R6B-R2 contracts and full results, entire failed commit, every transport/download/test/evidence file, and the current official Meshy Quickstart/API output examples before editing. Preserve failed history.

## Provider fact and zero-credit boundary

As of 2026-08-29, current official Meshy Quickstart/API examples return signed output URLs on the exact host `assets.meshy.ai` (for example `https://assets.meshy.ai/.../tasks/.../output/model.glb?...`). Pin this reviewable fact and source URL/timestamp in new evidence. Allow exactly `assets.meshy.ai` for provider output downloads—no wildcard/subdomain/arbitrary public host. A future provider-host change must fail closed and receive manager review. Make no Meshy API call, access no credentials, and consume zero credits; official docs GET only is allowed.

## Writable paths

- Directly relevant transport/download/bounds/fake-server/CLI modules and tests under `scripts/meshy/**`.
- New `docs/meshy-production/evidence/MESHY-002-R6B-R3/**` only.

Do not amend R6B evidence or any plan/cost/ledger/manifest/prior evidence/task/app/Xcode/agent file.

## Required correction

1. `assertSafeDownloadDestination` and every production download/redirect path must accept only HTTPS with canonical hostname exactly `assets.meshy.ai`, default port only, empty userinfo, empty fragment, and a safe normalized path. Reject trailing-dot/IDN/confusable/encoded-host tricks, IP literals, encoded separators/traversal, and every other host including `cdn.meshy.ai`, `*.amazonaws.com`, fictitious Meshy-looking domains, and arbitrary public hosts.
2. Signed query parameters are necessary for provider downloads. Permit them in the live request but never persist/print the raw URL, query, fragment, or authorization value. Evidence/public outcomes store only redacted host/path classification, hashes/sizes/formats/reason codes.
3. Re-resolve and DNS-pin `assets.meshy.ai` for the actual TLS GET with original SNI/certificate validation and private/mixed/rebinding rejection. Every GET redirect is manual, capped, and fully revalidated; redirects may remain only on exact `assets.meshy.ai`. Unknown redirect host fails closed with a durable reason.
4. Enforce `maxTotalDownloadBytes` as a running hard cap across all model and texture downloads, including declared Content-Length prechecks and actual streamed bytes. Include existing completed bytes plus current partial bytes; overflow leaves a labeled partial and terminal evidence, never a completed artifact.
5. Enforce exact format-aware content types before accepting body bytes. At minimum support current provider-safe types for GLB (`model/gltf-binary` or `application/octet-stream`), USDZ (`model/vnd.usdz+zip`, `application/zip`, or `application/octet-stream`), and textures (`image/png`, `image/jpeg`, `image/webp`, with `application/octet-stream` allowed only from the pinned provider host and still validated by file signature). Reject text/html, JSON, SVG/XML, missing/invalid types where the format contract requires one, and type/signature mismatch.
6. Caller overrides cannot disable/expand host, total-byte, per-file, redirect, or content-type policies. They may only tighten numeric bounds. Infinity/NaN/negative/excessive values fail/are clamped safely.
7. Add production-path adversarial tests: exact allowed host positive; arbitrary public/Meshy-lookalike/subdomain/trailing-dot/userinfo/port/fragment/encoded traversal negatives; same-host and foreign-host redirects; DNS private/mixed/rebinding; wrong/missing/content-type-signature mismatches; one large file; multiple individually-small files whose cumulative total exceeds the cap; declared-length lies; streamed overrun; partial semantics; secret/query redaction. Test the actual download loop, not constants in isolation.
8. Correct new evidence to mark the R6B-R2 FAIL and supersede the false completeness claim. Full inherited 330 tests must remain green.

## Gates and delivery

Run all tests, syntax/JSON/schema, local pinned-TLS integration, cross-process replay, physical-POST matrix, hashes, redaction, changed-path allowlist, `git diff --check`, clean worktree, and protected-root preservation through Boost. Create exactly one clean Sonnet-authored child commit of `7dcfc2dd5ebf8e2dcb5b1beeab7668f1b642bed7`. Return `COMPLETE_FOR_REREVIEW` only when every item passes; otherwise `PARTIAL`. Sections: STATUS, AGENT_RUN_ID, CHANGED_FILES, COMMIT, OFFICIAL_OUTPUT_HOST, URL_AND_DNS_ENFORCEMENT, CUMULATIVE_BOUNDS, CONTENT_TYPES_AND_SIGNATURES, TESTS_AND_GATES, ZERO_CREDIT_PROOF, CHECKSUMS, LIMITATIONS, BLOCKERS. Report the run ID exactly and leave canonical-model verification to the manager.
