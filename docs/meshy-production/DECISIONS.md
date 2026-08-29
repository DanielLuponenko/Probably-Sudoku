# Decisions

## D-001 — Preserve the current released baseline rather than roll back to stale develop

- Date: 2026-08-29
- Jira: KAN-153
- Context: repository policy says feature branches start from `develop`, but
  local/remote `develop` (`2312a5f`) was an ancestor missing seven commits that
  already existed on released `main` (`942e0b4`), including KAN-150 and KAN-152.
  The working tree also contained uncommitted shop/cosmetic work based on main.
- Decision: create `feature/KAN-153-meshy-club-shop` at the released main commit
  after making a complete external rollback package. Do not alter `develop`,
  reset the WIP, or pretend the stale branch is the current product baseline.
- Consequence: the final PR still targets `develop`; integration must explicitly
  reconcile its stale base and may not discard released work.

## D-002 — No Codex implementation fallback while Claude authentication is invalid

- Date: 2026-08-29
- Evidence: Claude Code 2.1.240 reported a logged-in first-party Max account, but
  session `4A38EC8E-E7C6-4352-833B-8178622BEEAD` failed before inference with
  `OAuth session expired and could not be refreshed` and exposed no model usage.
- Decision: keep production implementation blocked until a new structured run
  proves Sonnet resolution. Continue only control-plane, baseline, audit
  preparation, reference work, and Meshy read-only preflight.
- Resolution: session `06074628-263F-4B20-BCEF-2316F1A3B4C0` subsequently
  resolved to canonical model `claude-sonnet-5`. The no-Codex-fallback rule
  remains binding; task-specific Sonnet agents may now be dispatched after
  their definitions and contracts validate.

## D-003 — Audit the protected dirty baseline in place

- Date: 2026-08-29
- Jira: KAN-153
- Context: the protected working tree contains the current shop/cosmetic WIP,
  while a clean worktree at HEAD would omit those uncommitted paths and produce
  an incomplete inventory.
- Decision: the read-only repository auditor runs in the current protected
  checkout with `permissionMode: plan` and no write tools. Write-capable agents
  remain isolated in task-specific worktrees.
- Consequence: the audit can map every current path without mutating it, and the
  external rollback package remains the recovery authority.

## D-004 — Resolve design-language conflicts by authority, not convenience

- Date: 2026-08-29
- Jira: KAN-153
- Context: `DESIGN_LANGUAGE.md` permits gradients, procedural SwiftUI drawing,
  and SF Symbols in places where CONTRACT-001 prohibits them as finished
  in-scope shop/cosmetic art.
- Decision: retain the approved design language's material, color, typography,
  hierarchy, and interaction intent. For in-scope visible shop, product, effect,
  and gameplay-cosmetic art, the stricter direct-user and CONTRACT-001 Meshy
  lineage rule governs. SF Symbols, Canvas/Path drawing, and gradients may
  survive only outside the art scope or as documented functional overlays in
  the allowlists.
- Consequence: existing procedural visuals are audit/replacement inputs, not an
  implementation shortcut or visual source of truth.

## D-005 — Treat the approved bookstore mockups as the visual floor

- Date: 2026-08-29
- Jira: KAN-153
- Evidence: the user explicitly instructed the main agent to open and interact
  with both `bookstore-aisle.html` files before editing, then required the shop
  to “look like in the mockup but better” with depth, 3D assets, shadows, a
  spinning platform, and fully browseable merchandise.
- Decision: preserve the continuous bookstore room, foreground counter,
  physical category specimens, deep shelves, warm proofing light, selected-item
  rotation, and walnut/green/brass/paper identity. “Better” is constrained to
  measurable improvements in real 3D depth, Meshy asset/material fidelity,
  lighting/shadows, catalog usability, accessibility, and performance.
- Consequence: a flat list, generic card store, theme redesign, or nominal 3D
  backdrop cannot pass. `VISUAL_INVARIANTS.md` is a mandatory implementation
  and review gate.

## D-006 — Expand demo merchandise to the complete real catalog

- Date: 2026-08-29
- Jira: KAN-153
- Context: the approved interactive mockups demonstrate 5 papers, 3 grids, and
  5 number styles, while the authoritative catalog contains 13 papers, 7 grids,
  and 8 number styles.
- Decision: preserve the reference interaction/composition but replace every
  demo count with the full canonical 13/7/8 inventory. A selected number style
  must expose digits 1–9 for inspection; the player equips the style package,
  not nine independent catalog products. Do not invent a fourth “Desk” catalog
  category unless the source of truth and user scope explicitly change; a desk
  sample may remain environment/set dressing only if its provenance passes.
- Consequence: every one of the 28 IDs must be visible, reachable, selectable,
  truthfully paginated, and mapped to the same registry package used in play.

## D-007 — Count canonical leaves without semantic double-counting

- Date: 2026-08-29
- Jira: KAN-153
- Context: successive audit passes exposed that literal unique strings can
  still describe the same visible art: generic shop sample nodes versus their
  per-product replacements, and intrinsic emissive material properties versus
  the number/grid asset carrying them.
- Decision: Phase 1 contains 208 ledger rows: 71 environment replacements, 28
  unique display fixtures, 107 catalog replacement leaves, and two dead-code
  removal rows. The 107 catalog leaves are 72 digits, seven shared shop/gameplay
  grid packages, 26 distinct paper shop/gameplay deliverables, and two physical
  flame components. Generic merchandise/effect stand-ins are folded into those
  catalog rows; intrinsic neon/laser glow is part of its owning asset; a whole
  screen is a reachability defect, not an art row.
- Authority adjustments: fixed hanging paper reuses its catalog paper lineage
  rather than minting duplicate fixture art. Flame embers remain required for
  gameplay even though the current gameplay implementation is absent; that is a
  `BLOCKED` defect, not permission to reduce scope.
- Consequence: 206 visible rows require eventual approval; two additional dead
  rows require removal or deliberate Meshy registration. R5 and R6 found
  documentation defects without changing the accounting; their corrections are
  mechanically valid and R7 independently closed the Phase 1 audit gate.

## D-008 — Accept the complete Phase 1 audit chain without approving production art

- Date: 2026-08-29
- Jira: KAN-153
- Evidence: MESHY-001/R1–R7, canonical model `claude-sonnet-5`, zero nested
  agents, matching task/checksum and pre/post checkout fingerprints, synchronized
  208-row JSON/CSV ledgers, and the R7 `PASS` ruling.
- Decision: accept CONTRACT-001 Phase 1. The canonical denominator is 208 rows:
  206 visible art rows requiring eventual approval and two dead-code removal
  rows. Preserve every row as `BLOCKED` until its later production,
  integration, QA, and independent-review evidence passes.
- Consequence: repository/catalog/reference audit work is complete. This is not
  approval of any asset, does not pass Phase 0 or Phase 2–16, and does not
  authorize a paid Meshy request.

## D-009 — Make the moving camera and physical stand the shop architecture

- Date: 2026-08-29
- Jira: KAN-153
- Authority: direct user clarification after review of the approved bookstore
  mockups.
- Decision: the opening bookstore and store stand are one continuous 3D scene.
  `SHOP` performs one uninterrupted camera move to the stand with opening
  controls fading; `BACK` reverses the path and preserves category/product
  selection. The stand simultaneously presents every product in the active
  category (13 Paper, 7 Grid, or 8 Number styles), selects onto a central
  rotating proofing platform, stamps a vellum tag on successful purchase, and
  mechanically seats/equips the product with lamp/plaque feedback.
- Consequence: any flat view swap, generic card storefront, virtualized
  selected-plus-neighbors assortment, popup purchase/equip confirmation, or
  release-reachable `ClubShopView` fails. The first VISUAL-001 brief commit is
  quarantined and requires correction plus independent review.

## D-010 — Accept the corrected Phase 2 generation-brief gate only

- Date: 2026-08-29
- Jira: KAN-153
- Accepted commit: `9f9d8722f6626bcd4c25da870ecc9fbab4f2ab7f`
- Evidence: VISUAL-001 initial rejection; R1 and R3 Sonnet correction commits;
  manager rejection of the flawed R2 recommendation; R4's passing direct
  document evidence and rejected phase-conflated verdict; final R5 Sonnet PASS;
  exact structured-model, checksum, fingerprint, zero-credit, 208×46 parity,
  contradiction-scan, and clean-diff evidence.
- Decision: accept CONTRACT-001 Phase 2 as a specification gate. The accepted
  briefs make D-009 non-redesignable and measurable: one continuous opening↔
  stand camera journey, physical stand-as-store, simultaneous physical 13/7/8,
  central rotating proofing platform, persistence-gated brass-stamp BUY,
  mechanical EQUIP/lamp/plaque, reverse-path selection persistence, responsive
  browseability floors, and release-unreachable flat shop.
- Consequence: Phase 3 may begin with zero-credit Meshy pipeline preflight.
  This decision approves no runtime code, generated asset, screenshot, ledger
  row, paid call, QA result, or release gate; all 208 rows remain `BLOCKED`.

## Pending decisions

- Renderer strategy: RealityKit target versus a documented SceneKit adapter and
  migration path. Must be decided by audit evidence; it may not weaken Meshy or
  shared-registry requirements.
- Exact runtime asset budgets and category LOD limits.
- Exact Meshy generation mode per leaf/package after reference quality review.
