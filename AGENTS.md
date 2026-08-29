# Meshy production governance

The binding contract for KAN-153 is `/Users/daniel/meshy_club_shop_master_prompt.md`.
Read it in full before working on the permanent Club Shop or gameplay cosmetics.
The existing repository rules in `CLAUDE.md`, including Jira tracking and branch
policy, remain mandatory.

## Authority and roles

- The main Codex agent owns product scope, project sequencing, design direction,
  task contracts, review, testing, ledger approvals, release evidence, and final
  reporting.
- Codex may author only control-plane artifacts: this file, Claude agent
  definitions, task contracts, ledgers, manifests, decisions, risks, blockers,
  review logs, checklists, and non-production orchestration files.
- All production Swift, rendering, pipeline, test, mesh, texture, thumbnail, and
  cosmetic-effect work must be authored by a verified Claude Sonnet agent.
- A worker is accepted only when its run record contains a unique session ID,
  resolved Sonnet model identity, branch/worktree, and commit or immutable patch
  checksum. Alias-only or self-reported model claims are insufficient.
- Do not use Haiku, Opus, `inherit`, an unidentified model, Codex workers, or an
  automatic fallback as a substitute for Sonnet.
- Do not add `--max-budget-usd`, artificial turn ceilings, or silent retry loops.
- Agents may not spawn nested agents. Their tool allowlists must omit `Agent`.

## Production invariants

- Every in-scope visible Club Shop or gameplay-cosmetic asset must have direct,
  auditable Meshy task lineage, preserved provider output, checksums, registry
  mapping, runtime use, screenshots, tests, and independent approval.
- No procedural primitive, SwiftUI drawing, font glyph, system symbol, gradient,
  generated shader noise, fake thumbnail, placeholder, or unrelated asset may
  replace required Meshy-origin art.
- Gameplay clue digits, entered digits, and pencil marks are assets, not dynamic
  text. Prices, names, descriptions, categories, balances, state copy, and
  accessibility labels may remain dynamic text.
- Shop, gameplay, and runtime thumbnails resolve through one canonical registry
  and the same source lineage. Mechanically derived LODs are allowed; unrelated
  replacements are not.
- The audited catalog is authoritative when larger than the remembered floor.
  The hard floor is eight number styles times digits 1–9 (72), seven complete
  grid packages, and thirteen complete paper packages.
- Preserve the approved private-bookstore direction: walnut cabinetry, bottle
  green, aged brass, vellum/paper, proofing-counter hierarchy, and controlled
  theatrical light. Do not drift into generic cards, casino, military, arcade,
  or sci-fi-store presentation.
- Purchase and equip behavior must preserve balance accuracy, single charging,
  ownership persistence, equip-only-when-owned, distinct selected/owned/equipped
  states, and shop-to-game consistency.

## Work isolation and approval

- Jira workstreams are KAN-153 (art/rendering), KAN-155 (economy/persistence),
  and KAN-154 (release evidence). Link discovered bugs immediately under the
  applicable repository rules.
- Every delegated task has a written contract under
  `docs/meshy-production/tasks/` before the run starts.
- No more than two write-capable Sonnet agents may run concurrently. One owner
  per shared file or subsystem at a time; write agents use isolated branches or
  worktrees.
- Agents may update only their evidence fields. Only Codex may change a coverage
  row to `APPROVED`.
- Every production result requires an independent read-only Sonnet review. The
  author may not approve its own work.
- Preserve existing work and rollback evidence. Never use destructive reset,
  clean, force checkout, or force push.
- Shell commands must follow the user-level Boost rule: wrap the command and pipe
  its output to `boost`.

## Completion

Only `APPROVED` ledger rows count as complete. A compiling build, master sample,
partial catalog, attractive screenshot, or agent assertion is not completion.
Do not declare `STATUS: COMPLETE` until every artifact and gate in the binding
contract is present and independently proven.
