# MESHY-001-R1 — Close repository-audit exhaustiveness gaps

## Task ID

`MESHY-001-R1`

## Agent name

`sonnet-repository-auditor`

## Dependency IDs

- `MESHY-001`: partial report from run
  `E3D6C0A1-9B7F-4A2E-B518-7C9D3F6A2401`, preserved at
  `docs/meshy-production/reviews/MESHY-001-E3D6C0A1-9B7F-4A2E-B518-7C9D3F6A2401.json`.

## Exact objective

Close only the exhaustiveness gaps that prevented `MESHY-001` from passing.
Read every previously skipped governing/reference file in full, visually inspect
the supported image references, read every line of the 3,561-line
`BookstoreSceneCoordinator.swift`, and return an exact canonical leaf inventory
for the shop environment and display instead of lower bounds. Verify the full
repository scan for any in-scope paths omitted by the first run. Produce no
implementation and make no mutation.

## In-scope files and components

- Every line of `App/Views/MainMenu/BookstoreSceneCoordinator.swift`, including
  every loop, helper, visible texture generator, primitive generator, fallback,
  and all instantiated visible children.
- The complete contents of `README.md`, `REFERENCE.md`, `DESIGN_LANGUAGE.md`,
  `/Users/daniel/GAME_REFERENCE.md`, all approved/candidate bookstore/shop HTML
  references, and all in-scope PNG/SVG references.
- The complete contents of `docs/meshy-production/REFERENCE_INDEX.md`,
  `VISUAL_INVARIANTS.md`, `DECISIONS.md`, `CATALOG_AUDIT.json`, and every other
  current coordinator artifact needed to interpret the 2026-08-29 direct-user
  visual lock.
- Every repository file/path not substantively inspected in `MESHY-001`, using
  a complete file inventory that includes hidden/untracked relevant paths.
- The first audit report and its ten defects, to verify or correct—not merely
  repeat—them.

## Writable paths

None. Return all evidence in the structured result. Codex owns artifact edits.

## Read-only paths

The entire protected repository and all external paths listed in
`MESHY-001-repository-audit.md`.

## Prohibited changes

Every mutation, build, generation, launch, network call, paid call, nested
agent, self-approval, scope reduction, lower-bound count, or representative-only
inventory. Do not repeat broad findings without closing the listed gaps.

## Approved references

Same authority/reference set as `MESHY-001`, updated by the user's direct
2026-08-29 re-approval of `MOCKUP-BOOKSTORE-001` and
`MOCKUP-BOOKSTORE-002`: the production shop must look like those mockups but
better, with depth, 3D assets, shadows, a spinning platform, and every real
paper/grid/number product visibly browseable. The main agent has already opened
and interacted with both exact HTML files as recorded in `REFERENCE_INDEX.md`.
`MOCKUP-SHOP-001` and its rendered partner remain candidates, not approved,
unless separate direct approval evidence is found.

## Ledger rows owned by the task

No approval fields. Return exact environment/display leaf specifications that
Codex can transcribe into one ledger row per canonical visible asset. Each
specification must state repeated runtime instance counts separately; do not
mistake an instance of one reusable canonical asset for a distinct source asset.

## Acceptance criteria

1. Every line of `BookstoreSceneCoordinator.swift` is read, and every visible
   environment/display object or object group is assigned one stable proposed
   canonical asset ID, exact source line range, current generator/texture,
   screen/location, runtime instance count or formula, dependencies, and Meshy
   replacement description.
2. Exact integers replace `≥45`, `≥36`, and `~197+`. Report both canonical leaf
   asset count and rendered instance count, explaining the counting rule.
3. All previously unread governing/reference documents are read in full. For
   each reference, return checksum, approval status/evidence, governed
   components, composition/material/type/light/scale/spacing rules, and every
   real contradiction.
4. PNG/SVG references and renderable HTML references are visually inspected
   when the Read tool supports them. If a format cannot be visually decoded,
   report that exact limitation and still inspect its full source/metadata.
5. The complete repository path inventory identifies every in-scope source,
   asset, test, localization, flag, fallback, and generated/provenance file
   omitted by `MESHY-001`, or explicitly states none with evidence.
6. Recheck defects D-1 through D-10 and provide corrections with path:line
   evidence. Distinguish a compiled release path from a launch-only QA path,
   but do not waive production reachability.
7. Return compact machine-transcribable JSON arrays named
   `ENVIRONMENT_CANONICAL_LEAVES` and `DISPLAY_CANONICAL_LEAVES`; no grouped
   `~N`, `etc.`, wildcard ID, lower bound, or representative row is accepted.
8. Checkout fingerprints before and after match the manager-supplied pre-run
   fingerprints. If any path changes, stop and report it without cleanup.
9. Reconcile the approved mockup's demo counts (5 paper / 3 grid / 5 number)
   against the real 13 / 7 / 8 catalog and verify the exact implementation paths
   that must make all 28 product IDs browseable. Treat `VISUAL_INVARIANTS.md` as
   a locked review input, not permission to reduce or redesign the catalog.

## Required commands

Prefer `Read`, `Grep`, and `Glob` so this read-only plan-mode run does not need
shell approval. Any Bash command must pipe output through `boost`; if the runner
denies `boost`, record the denial and use a non-Bash read tool instead rather
than silently issuing the command without the required pipe. Do not build or
run the app.

## Required screenshots

None created. Visually inspect existing approved/candidate reference images and
report observations by reference ID.

## Required performance evidence

None. Map the visible/runtime paths later profiling must exercise.

## Expected output schema

Use the auditor's standard headings plus:

- `GAP_CLOSURE_CHECKLIST`
- `ENVIRONMENT_CANONICAL_LEAVES` (valid compact JSON array)
- `DISPLAY_CANONICAL_LEAVES` (valid compact JSON array)
- `EXACT_COUNT_FORMULA`
- `FULL_REFERENCE_ANALYSIS`
- `DEFECT_CORRECTIONS`
- `OMITTED_PATHS_FOUND`

Return `STATUS: PASS` only if every acceptance criterion above is satisfied;
otherwise return `PARTIAL` and enumerate exact missing items. This task never
sets a production asset to `APPROVED`.

## Rollback instructions

Writes are forbidden. On mutation, stop and report the changed paths and
command; Codex owns recovery using the external KAN-153 rollback package.
