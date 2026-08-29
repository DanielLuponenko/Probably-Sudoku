# MESHY-001-R2 — Finalize repository-audit coverage

## Task ID

`MESHY-001-R2`

## Agent name

`sonnet-repository-auditor`

## Dependency IDs

- `MESHY-001`: verified partial discovery report.
- `MESHY-001-R1`: verified partial exact-scene report from run
  `349D394D-892D-4902-BCE0-C2D340A506FD`, preserved at
  `docs/meshy-production/reviews/MESHY-001-R1-349D394D-892D-4902-BCE0-C2D340A506FD.json`.

## Exact objective

Close every remaining audit gap named by MESHY-001-R1 without repeating its
already-valid 71-entry environment or 43-entry display arrays. Read every
omitted governing, source, test, asset, and reference path in full; visually
inspect every in-scope raster reference/runtime image supported by `Read`;
complete the repository-wide path/policy sweep; independently rederive the
catalog/effect rows; and freshly recheck defects D-1 through D-10. Produce no
implementation and make no mutation.

The combined MESHY-001 + R1 + R2 evidence may satisfy the Phase 1 audit gate
only if this run returns `PASS` and the Codex manager independently verifies
the exact model and checkout fingerprints. A partial run issues another
revision; it does not silently waive a gap.

## In-scope files and components

Read these omitted or partially read paths in full, even if a prior report
summarized them:

- `/Users/daniel/.codex/visualizations/2026/08/27/01a044a3-1743-7540-86df-260edeebf9c9/bookstore-aisle-rendered.html`
- the six candidate/unapproved HTML files beside it:
  `clipping-choice.html`, `clipping-choice-rendered.html`,
  `opening-bookstore.html`, `opening-bookstore-rendered.html`,
  `sudoku-shop-depth.html`, and `sudoku-shop-depth-rendered.html`;
- `App/Model/CosmeticTheme.swift` through its actual final line;
- `App/Model/CosmeticItem.swift` and `App/Model/PlayerProfileStore.swift`;
- `App/Views/CosmeticSkinRendering.swift`, `App/Views/BookView.swift`, every
  `App/Views/ClubShop/*.swift`, `BookstoreOpeningView.swift`,
  `BookstoreSceneView.swift`, and `ClubShopOverlay.swift`;
- every `AppTests/*.swift` file;
- `scripts/gen-shop-models.mjs`, all in-scope resource/manifest/provenance
  files, `project.yml`, and every localization path or localization reference;
- every Engine source/test path implicated by cosmetic catalog, effect,
  persistence, gameplay reachability, or testing, plus a repository-wide
  pattern sweep sufficient to classify every other Engine path as in or out;
- every raster/vector/3D path found by the repository asset inventory. Inspect
  all in-scope PNG/JPG/JPEG/WebP images visually with `Read`; read SVG source in
  full and report if the tool cannot render it; identify unrelated brand/icon
  assets explicitly rather than silently skipping them; and inspect the USDZ's
  available metadata/manifest even if binary geometry cannot be decoded.

Use `Glob` to enumerate the complete repository, including dot-directories and
untracked paths represented in the protected checkout. Use `Grep` across the
complete relevant source set for localization, launch flags, fallbacks,
procedural 2D/3D, SF Symbols, font glyphs, gradients, runtime-generated
textures, asset loads, catalog IDs, tests, and provenance fields. Do not infer
that no omitted path exists from a partial glob.

## Writable paths

None. Return all evidence in the structured result. Codex owns artifact edits.

## Read-only tool envelope

Only `Read`, `Grep`, and `Glob` are exposed. There is no Bash, Write, Edit,
Notebook, web, or nested-agent tool. The Codex manager owns checksums and
pre/post checkout fingerprints; absence of Bash is not a task blocker.

## Approved references

- `MOCKUP-BOOKSTORE-001` and `MOCKUP-BOOKSTORE-002` are the directly approved
  visual floor documented in `REFERENCE_INDEX.md` and
  `VISUAL_INVARIANTS.md`.
- All `clipping-choice`, `opening-bookstore`, and `sudoku-shop-depth` files are
  candidates/unapproved unless direct user evidence—not repository content—
  proves otherwise. Reading them may reveal conflicts but may not promote them.
- `Artwork/DesignLanguage/club-shop.png` is a flat baseline, not the target.

## Manager mechanical evidence to verify against source

MESHY-001-R1 manually counted five residue-gated instance totals. The manager
executed an independent Ruby enumeration against the exact loop domains and
obtained:

```json
{"left_filler_band":70,"right_filler_band":44,"left_stacked_book":24,"right_stacked_book":15,"back_filler_band":15}
```

Together with JSON validation of the R1 arrays: 71 unique environment IDs sum
to 1,893 instances; 43 unique display IDs sum to 101 reachable instances, with
two dead-code leaf types that would create four instances if wired. Verify the
source domains and report corrections; do not reprint the full arrays if they
are correct.

## Prohibited changes

Every mutation, build, generation, launch, network call, paid call, nested
agent, self-approval, scope reduction, inferred approval, lower-bound count,
representative-only row, and silent carry-forward of an unread path.

## Acceptance criteria

1. Every file listed above is read through its actual final line, and a compact
   `READ_COVERAGE` table records path, full line range, and finding.
2. All eight HTML files in the visualization directory have full-source reads,
   checksums from the manager/reference index where available, approval class,
   governed component, and every relevant composition/material/interaction
   conflict. Approved bookstore files remain authoritative.
3. Every in-scope raster image is opened with `Read` and receives a visual
   observation. Every discovered image/vector/3D asset is classified; any
   format decoding limitation names the exact path and tool limitation.
4. A complete repository path sweep returns `OMITTED_PATHS_FOUND` with exact
   paths or `NONE` backed by the Glob/Grep coverage. Hidden/untracked relevant
   paths and localization absence are included.
5. Defects D-1 through D-10 are freshly rechecked from primary files with exact
   path:line evidence. Corrections are explicit; no defect is merely copied
   from a prior report. New defects may be D-11+.
6. The 8 number styles/72 digit leaves, 7 grid styles/14 shop+gameplay rows, 13
   paper styles/26 shop+gameplay rows, and 4 effect packages are independently
   rederived. Displayed, purchasable, equipable, persisted, preview, gameplay,
   localized, and tested catalogs are reconciled independently.
7. The R1 71/1,893 and 43/101 counts plus the five manager-enumerated values are
   checked against source. State whether the proposed 231 canonical total is
   exact under the contract's one-row-per-leaf counting rule; if not, provide
   the corrected exact integer and formula without a lower bound.
8. The manager's pre/post fingerprints match; if any repository path changes,
   report it and stop without cleanup.
9. Return `STATUS: PASS` only when criteria 1–8 are closed with no remaining
   readable path deferred to a later run. Otherwise return `PARTIAL` and list
   every exact residual gap. This task never approves a production asset.

## Expected output schema

Return concise Markdown with exactly these top-level headings:

- `STATUS`
- `AGENT_RUN_ID`
- `RESOLVED_MODEL`
- `BRANCH`
- `COMMIT_OR_PATCH`
- `READ_COVERAGE`
- `HTML_REFERENCE_COMPLETION`
- `VISUAL_ASSET_INSPECTION`
- `REPOSITORY_PATH_SWEEP`
- `CATALOG_REDERIVATION`
- `R1_COUNT_VALIDATION`
- `DEFECT_RECHECK`
- `GAP_CLOSURE_CHECKLIST`
- `KNOWN_LIMITATIONS`
- `BLOCKERS`

Do not repeat the complete R1 leaf arrays; reference their IDs and report only
corrections. `COMMIT_OR_PATCH` must be `NONE (read-only)`.

## Rollback instructions

Writes are structurally unavailable. If a mutation is nevertheless observed,
stop and report the changed path; Codex owns recovery from the KAN-153 package.
