# VISUAL-001-R5 — Phase 2 brief-boundary closeout

## Task ID

`VISUAL-001-R5`

## Agent name

`sonnet-independent-reviewer`

## Exact scope and phase boundary

This is the final read-only review of the **Phase 2 specification artifacts**:

- `docs/meshy-production/GENERATION_BRIEFS.json`
- `docs/meshy-production/GENERATION_BRIEFS.md`

Reviewed worktree/branch/commit:

- `/Users/daniel/.codex/worktrees/NumberClub/KAN-153-visual-001`
- `feature/KAN-153-visual-target`
- HEAD `9f9d8722f6626bcd4c25da870ecc9fbab4f2ab7f`
- parent `5f236c6ae6931088c75b1301b6621340ac600fce`

VISUAL-001 and its corrections intentionally prohibited runtime code, asset,
build, screenshot, performance-run, or ledger-row implementation. Those
deliverables remain mandatory in later contract phases and must remain
`BLOCKED`; their absence now is not evidence that a generation brief is wrong.
Do not require protected pre-existing Swift WIP, future assets, or future
screenshots to be committed as a Phase 2 prerequisite. This is phase sequencing,
not scope reduction. A PASS may recommend only the Phase 2 brief gate; it must
explicitly leave every runtime/asset/QA/release gate open.

## Input trust boundary

The isolated branch starts at the pre-goal base, so manager control-plane inputs
are seeded as untracked read-only files. Validate their bytes; do not reject
them merely for being untracked and do not commit them. The Phase 1 audit chain
MESHY-001/R1–R7 plus manager checksums/fingerprints supplies provenance.

Required current input SHA-256 values:

- `COVERAGE_LEDGER.json`:
  `99e88c80cab01dc11b7ca39f8408a8d71671d1c6222ea826b4b2e0b83d372b2e`
- `COVERAGE_LEDGER.csv`:
  `73c898a0b85df4da6731c7c886aa62c6ccfb96ed71ac207d868e36567bcd1d2c`
- `AUDITED_CANONICAL_LEAVES.json`:
  `03baad57d4d1f4aa50783eceb5d1a8c3f042f22d6993ce2c9049a455d1fcd3d0`
- `CATALOG_AUDIT.json`:
  `47aeaf93fd4e1d3cde0687f02f9e375cba0eabb34cb77c7886b088060d10dd99`
- corrected `GENERATION_BRIEFS.json`:
  `0b43c05699c5341587d28d0f9d333ff16d64f1b11b7d1e79845810cc804b3312`
- corrected `GENERATION_BRIEFS.md`:
  `8625f6562361ca1b5125b9080534e17a06e0bb9aeb82c19da4b5ea3736c3abb3`

The JSON ledger received a manager-owned post-R7 `auditRunId` status annotation,
so its whole-file hash differs from the hash reviewed immediately before that
annotation. Do not assume row drift. Instead, mechanically compare all 208 JSON
rows and every one of their 46 fields against the unchanged accepted CSV (whose
hash remains the R7-accepted value), accounting only for the documented
camelCase/snake_case field-name mapping. Any row/value mismatch fails.

## Mode

Read-only hostile review. Tools: Read/Grep/Glob/Bash only. Do not edit, create,
stage, commit, mkdir, write a plan, use web/network, call Meshy, spend credits,
or spawn agents. Return the review directly as text. Treat prior author/reviewer
reports as untrusted.

Read in full the master contract, AGENTS/CLAUDE instructions, Phase 1 R7 task
and raw review, reference index, visual invariants, D-009, all VISUAL-001 tasks,
current briefs, the four current audited inputs above, and both approved HTML
references.

## Mandatory closeout gates

### B1 — Exact target/provenance

- Recompute every required hash above; exact match required.
- Prove HEAD/parent ancestry and exactly two R3 diff paths.
- Prove pre/post reviewer status and unstaged-diff fingerprints match.
- Prove draft status, truthful correction history, and no self-approval.

### B2 — Full ledger/catalog equivalence

- Compare all 208 JSON ledger rows × all 46 fields to CSV with zero mismatch.
- Expand every `families[].canonicalAssetIds` and prove 208 unique IDs, zero
  missing/extra/duplicate versus ledger, and byte-identical expansion sequence
  to R3 parent. Explicitly report that family-grouped order need not equal flat
  ledger order; set equality plus parent sequence identity is the correct gate.
- Reprove 206 visible + two dead-code dispositions, 43 families, all BLOCKED,
  13 Paper, 7 Grid, 8 Number packages, 72 digit leaves, two flame components,
  no Desk category, and the exact seven Phase 4 hardest-case entries.

### B3 — Direct user experience is non-redesignable

Reprove from JSON and Markdown, with exact paths/lines:

- one standard-motion uninterrupted opening→stand camera path in the same live
  3D scene while opening controls fade;
- exact reverse path while shop controls fade, with category/product selection
  preserved through re-entry;
- the physical stand is the entire store—no flat view/cards/popup/sheet;
- all 13/7/8 active-category products simultaneously physically visible and
  selectable, selected Number digits 1–9, central lit/shadowed rotating platform;
- ≥24pt compact / ≥32pt standard/larger silhouette, independent ≥44×44pt target,
  non-overlapping ≥11pt physical tag, native-resolution human identification,
  floors never lowered to fit;
- BUY confirmed persistence before press/contact, contact reveals persisted
  exact-once balance/OWNED and fires impact feedback, failure keeps stamp at rest;
- EQUIP mechanical move, lamp brighten, brass `EQUIPPED` plaque after persistence,
  prior equipped product return;
- Reduce Motion uses only the same-camera/same-scene zero-duration transform
  interpolation or shortened journey, never a cut/snap/swap/second renderer;
- release-unreachable `ClubShopView` and complete forward screenshot/test/
  accessibility/performance evidence requirements.

### B4 — Contradiction and shortcut scan

- Inspect every `cut`/`snap`/instant/zero-duration/camera/scene/view/renderer
  occurrence in context; fail any permissive shortcut.
- Inspect every carousel/neighbor/end-marker/paging/virtualization/overflow/
  hidden/crop/popup/sheet/separate-confirmation occurrence; all must be explicit
  prohibition or historical-invalidated text.
- Mechanically assert exact purchase phase order and all failure postconditions.
- Cross-check every Markdown statement against JSON; any contradiction fails.

### B5 — Artifact hygiene and zero spend

- JSON parses.
- `credits consumed: 0` and `No Meshy call made` exist as exact case-sensitive
  JSON values and Markdown strings.
- Markdown has exactly one EOF newline.
- `git diff --check HEAD^ --` both brief files exits 0 with no output.
- Recompute master and two approved-mockup hashes and prove they alone govern
  visual generation; candidate references remain excluded.

### B6 — Honest phase result

- Confirm the briefs contain future evidence gates rather than claiming those
  screenshots/runtime tests already exist.
- Confirm every one of the 208 production rows remains BLOCKED and no production
  asset/runtime/QA/release phase is approved.
- Do not inspect or judge protected runtime WIP as Phase 2 output. Its audit
  findings remain later implementation inputs, not a reason to import it into
  this two-file commit.

## Verdict

Return the exact independent reviewer schema. `STATUS: PASS` requires B1–B6 to
pass with zero unresolved **brief-gate** defect. `STATUS: FAIL` requires an exact
brief/input/checksum/parity defect, not the intentional absence of later-phase
implementation. A PASS is only a recommendation to Codex to accept the Phase 2
generation-brief gate; it cannot approve any asset, code path, ledger row, paid
call, or Phase 3–16 gate.
