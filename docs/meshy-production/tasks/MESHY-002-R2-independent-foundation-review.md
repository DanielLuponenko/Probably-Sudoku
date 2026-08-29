# MESHY-002-R2 — Independent hostile review of the Phase 3 foundation

## Identity and authority

- Task ID: `MESHY-002-R2`
- Manager run/session ID: `94CD44CC-3F9F-44B1-897E-458EA8781C43`
- Agent: `sonnet-independent-reviewer`
- Mode: strictly read-only; no file or repository mutation
- Reviewed worktree:
  `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-meshy-002`
- Reviewed branch: `feature/KAN-153-meshy-pipeline`
- Reviewed author commit: `7797833d251f4c32790c0610734d3a4e68b7aa3c`
- Required parent: `b5fc9384e479dde35b58ada97cceefd647020d34`
- Binding author task:
  `/Users/daniel/NumberClub/docs/meshy-production/tasks/MESHY-002-R1-phase3-zero-credit-pipeline.md`
- Binding master:
  `/Users/daniel/meshy_club_shop_master_prompt.md`
- No nested agents. Do not self-approve any missing future correction.

## Review objective

Hostilely audit the Sonnet-authored Phase 3 foundation commit against the full
master and MESHY-002-R1 contracts. Decide what is valid reusable foundation and
what must be corrected before Phase 3 can pass. A passing unit suite, clean
commit, or plausible report is not sufficient.

The author correctly returned `PARTIAL`; this review must not fail it merely for
refusing to fabricate the unavailable historical candidate inside its limited
tool environment. The manager has since obtained the two real provider-native
USDZ files through the authenticated, zero-credit Meshy connector. They are
untracked external inputs for the next author revision, not part of the reviewed
commit:

- `Artifacts/Meshy/MESHY-002-R1/provider-native/club-turntable-preview.usdz`
  SHA-256 `cd06daf1067084e2e09a0771d024499216e361b6253e284d775bc47e5f32f576`,
  663,884 bytes.
- `Artifacts/Meshy/MESHY-002-R1/provider-native/club-turntable-refine.usdz`
  SHA-256 `fff03e6d1ca488b73db77d6340deb311aa808f6ff18c07c93567b2ff278366ce`,
  22,039,583 bytes.

The Meshy connector returned balance `1,886` before and after download, preview
status `SUCCEEDED`/25 historical credits, refine status `SUCCEEDED`/10
historical credits, and only `usdz` as an available provider format. No new task
was created and no new credit was consumed. Treat these facts as manager-owned
inputs to verify locally where possible; do not make a paid call.

## Required checks

Read the master, author task, agent definitions, accepted Phase 1/2 artifacts,
all 49 changed files, and the complete commit diff. Pipe every Bash command
through `boost`. Do not trust the author report.

### Provenance and boundary

- Verify exact commit/parent/branch, author/committer, clean tracked state,
  changed-path allowlist, seeded ledger-line byte identity, and absence of root
  checkout changes caused by this run.
- Verify the structured manager evidence: CLI session was
  `F353EE1A-1255-410F-87AD-D5004E68A926`, canonical author model was
  `claude-sonnet-5`, zero nested agents, and zero paid Meshy calls. The author
  report's self-reported model and run ID are not authoritative.
- Identify every mismatch between the commit, `RUN_SUMMARY.json`, final report,
  task contract, and evidence counts/checksums.

### Pipeline correctness and security

- Inspect every implementation path, not just tests. Challenge dry-run zero
  network, approval-file authenticity, fixture-vs-external approval separation,
  replay protection, payload checksum basis, exact model/endpoint/attempt/credit
  matching, approval expiry, destination containment, method allowlists,
  secret/header/signed-URL redaction, immutable preservation, idempotency,
  paid-task resubmission behavior, bounded polling/backoff, retry exhaustion,
  malformed response handling, and ledger append semantics.
- Determine whether tests would still pass if a dangerous live POST, credential
  leak, path escape, or duplicate approval regression were introduced.
- Verify no app/runtime code gained a Meshy key or provider dependency.

### Plan, catalog, and pricing

- Mechanically verify 208 unique accepted IDs, 206 visible plus two dead-code
  rows, ordered parity, exact family mapping, and zero coverage-row mutation.
- Check whether assigning `text-to-3d-two-stage` to every visible row is actually
  supported by the accepted briefs and master mode-selection rules, especially
  precision digits/grids and composition-sensitive environment/fixtures. Flag
  a blanket choice if it creates unapproved visual or cost assumptions.
- Recompute low/expected/high totals and per-category subtotals from current
  official pricing. Determine whether the three bands are meaningful and
  whether they include every necessary preview/refine/reference-sheet,
  retexture/remesh/conversion, retry, and hardest-case assumption without
  double-counting.

### Official-doc truth

Use read-only `curl`/official `docs.meshy.ai` pages only. Verify all model,
endpoint, parameter, price, PBR, format, and `consumed_credits` claims. In
particular, resolve or explicitly record the current official contradiction:

- the Text-to-3D task-object page describes `texture_urls.emission` as omitted
  only when PBR is disabled or `ai_model` is `meshy-5`, which does not explicitly
  exclude `meshy-7`;
- the Image-to-3D page explicitly says `meshy-7`/`latest` do not produce an
  emission map; and
- the changelog says the PBR bundle includes emission for `meshy-6` and
  `latest` across several endpoints.

Do not accept a definitive universal Meshy-7 emission claim unless the current
official pages support it consistently. Require fail-closed capability
representation when official documentation conflicts.

### Tests and Phase 3 exit boundary

- Rerun the complete Node test suite, syntax checks, JSON/JSONL checks, plan and
  cost recomputation, path checks, redaction scan, and `git diff --check` over
  the author commit.
- Inspect both real USDZ inputs with available read-only tools. Do not create a
  derivative or thumbnail in this review.
- List the exact next-revision gates for provider response preservation,
  checksums, native USDZ validation, truthful test-only GLB derivation if used,
  fallback conversion, PBR/material inspection, Apple-runtime load,
  deterministic runtime thumbnail, manifest/ledger correction, current balance
  equality, run-ID/model correction, and final evidence regeneration.

## Verdict rule

Return `PASS` only if the reviewed commit itself has no blocking defect and is a
sound partial foundation whose explicitly missing external-input gates are the
only blockers. Return `FAIL` for any code/security/provenance/plan/pricing/doc
defect requiring author correction. Return `BLOCKED` only if review cannot be
performed read-only.

No verdict can accept Phase 3. A later Sonnet correction commit plus a fresh
independent review are mandatory.

## Required result

Return exactly the sections required by the independent-reviewer definition.
Every finding must name severity, exact file/path and line or artifact, violated
criterion, evidence, and required remediation. Separate author defects from
known external-input gates.
