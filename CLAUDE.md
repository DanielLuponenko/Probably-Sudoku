# Probably Sudoku — project instructions

(Formerly *Probably Sudoku*; the rename is tracked in KAN-34 and is not done in
the code yet, so the target, module and bundle id still say `ProbablySudoku`.)

## This project is Jira-managed. This rule is non-negotiable.

Every change to this repository is tracked in Jira. No exceptions, no "it was
only a one-liner", no "I'll file it after".

**Site** `https://dannylovesanna.atlassian.net`
**Project** key **KAN** (its display name is "Sudoku")
**cloudId** `c1c45d84-69f7-4b8c-8f28-c39866f99afc`

Use the Atlassian MCP server (`mcp__atlassian__*`). If it is not connected, say
so and stop — do not do the work untracked and promise to file it later.

### Before you change anything

1. **Search first.** `searchJiraIssuesUsingJql` with
   `project = KAN AND text ~ "<the thing>" AND statusCategory != Done`.
   Work that fits an existing ticket goes on that ticket. Do not open a second
   ticket for something already filed.
2. **If nothing fits, create the ticket before writing code**, with
   `createJiraIssue`: `projectKey: "KAN"`, an issue type from the table below,
   `parent` set to the right epic, plus labels and priority in
   `additional_fields`.
3. **Tell the user the key and the link** — `https://dannylovesanna.atlassian.net/browse/KAN-<n>` —
   before starting, not after finishing.

### While you work

Move the ticket with `getTransitionsForJiraIssue` → `transitionJiraIssue`.
The workflow is **To Do → In Progress → In Review → Done**: In Progress when
you start, In Review when the PR is open, Done when it is merged and verified.

### When you finish

Comment on the ticket with `addCommentToJiraIssue`:

```
Implemented:
- <what changed, with file:line>

Remaining:
- <what was deliberately left, or "nothing">

Testing:
- <what was run and the result — Passed / Failed, quoted output for failures>
```

Then transition it. A ticket is only Done when the work is verified, not when
the edit is saved.

**Bugs found along the way get their own ticket**, immediately, even if you are
not going to fix them now. File it, link it (`createIssueLink`, type `Relates`
or `Blocks`), and mention it.

### One ticket or several?

- One coherent change, one system → **one ticket**.
- Several files but one intent (a rename, a refactor, one feature's vertical
  slice) → **one ticket**. Do not shard it per file.
- Work spanning several epics → **one ticket per epic**, linked with `Relates`,
  and say in each which part it covers.
- A large piece with obvious stages → parent ticket plus `Subtask`s.
- Trivial mechanical work with no behaviour change (formatting a file you were
  already in, a typo in a comment) → fold it into the ticket you are already on
  and mention it in the closing comment. Never a ticket of its own, never
  untracked.

---

## Version control — also non-negotiable

**Remote** `https://github.com/DanielLuponenko/Probably-Sudoku.git`
(The game is being renamed from Probably Sudoku to **Probably Sudoku** — KAN-34.)

Not everything goes on `main`. The model, defined in **KAN-35**:

| Branch | What it is |
|---|---|
| `main` | **Released only.** Every commit is a version that shipped or was cut. Never commit to it directly |
| `develop` | Integration branch, and the default. Day-to-day work merges here. Always buildable |
| `release/x.y` | A version being stabilised. Cut from `develop`; only fixes land on it; merges into **both** `main` and `develop` |
| `feature/KAN-<n>-<slug>` | One ticket's work. Cut from `develop` |
| `hotfix/KAN-<n>` | An emergency on a released version. Cut from `main`, merges back to both |

**How you work, every time:**

1. `git checkout develop && git pull` then `git checkout -b feature/KAN-<n>-<slug>`.
   Never start work on `main` or `develop`.
2. Commit subjects are prefixed with the key: `KAN-31: mono lockup for the studio mark`.
   The key is what ties the diff to the reasoning.
3. Open a PR into `develop` — title `KAN-<n>: <what>`, body linking
   `https://dannylovesanna.atlassian.net/browse/KAN-<n>`.
4. Nothing reaches `main` or `develop` except through a PR.

**A version is only real when it is written down.** Cutting one means all four:

- a `vX.Y.Z` tag on `main`
- a `CHANGELOG.md` section — newest first, Added / Changed / Fixed, every line
  carrying its `KAN-<n>`
- a GitHub Release with that section as its body
- a Jira version (project Releases) with the tickets set as `fixVersions`

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` live in `project.yml` and are
bumped on the release branch, never on a feature branch.

**Never** commit unrelated work-in-progress along with your change. Commit only
the paths your ticket touched — `git commit -m "…" -- <paths>` — and leave the
rest of a dirty tree alone. It belongs to someone else's ticket.

---

## The board

### Epics

| Key | Epic | Owns |
|---|---|---|
| KAN-1 | 🎮 Core Gameplay & Rules | engine, scoring, turn/hand/pool, QA tooling |
| KAN-2 | 🃏 Rogue Systems & Economy | Bookmarks, Markers, Buffs, Shop economy, skips, perks |
| KAN-3 | 📚 Books & Progression | shelf, Book editions, difficulty ladder, unlocks |
| KAN-4 | 👹 Bosses & Board Design | the 19 Boss Modifiers and their boards |
| KAN-5 | 🎨 Art, Themes & Animation | themes, Shop look, page flips, motion |
| KAN-6 | 🔊 Audio | sound effects, music |
| KAN-7 | 🍎 Apple Platform Services | Game Center, achievements, iCloud sync |
| KAN-8 | 🏷️ Brand, Icon and Store | studio logo, app icon, App Store |
| KAN-9 | 🚀 Vertical Slice | the release gate — `release-blocker` work links here |

### Issue types

`Epic` · `Feature` (a broad piece of functionality) · `Story` · `Task` ·
`Subtask`.

**There is no Bug issue type** and this is a team-managed project, so the API
cannot add one. File a bug as a **Task** with the summary prefixed `BUG:` and
labels `bug` plus one of `bug-visual` / `bug-balance` / `bug-crash`.

### Labels — use these, do not invent neighbours

System: `system-gameplay` `system-economy` `system-meta` `system-art`
`system-ui` `system-audio`
Area: `engine` `ios` `apple-services` `onboarding` `branding` `qa` `tooling`
`perf` `a11y`
Bugs: `bug` `bug-visual` `bug-balance` `bug-crash`
Release: `release` `release-blocker` `polish` `nice-to-have` `needs-design`

### API notes that cost time to rediscover

- `createJiraIssue` accepts `parent: "KAN-<epic>"` on a Task/Feature, not only
  on subtasks.
- Priority and labels go in `additional_fields`:
  `{"priority": {"name": "High"}, "labels": ["bug", "system-ui"]}`.
- Never write `&amp;` in a summary — the API stores the entity literally
  instead of decoding it. Use a plain `&`.
- Dashboards and gadgets are **not** exposed by the MCP server. They are built
  by hand in the web UI.

---

## The game itself

`~/GAME_REFERENCE.md` is the **authority on rules** — section numbers in code
comments refer to it. It wins over the old TypeScript prototype and over the
asset checklist whenever they disagree.

`REFERENCE.md` in this repo is **generated** from the catalogue
(`swift test --filter GenerateReference` with `WRITE_REFERENCE=1`) and lists
every Boss, Bookmark, Marker and Buff. Do not edit it by hand.

`README.md` covers the layout, how to build and run on a simulator and on a
device, the debug launch arguments, and the performance rules that were learned
the expensive way. Read it before touching the build or any animation.

Settled design decisions — do not re-litigate: a Marker marks a **square**, not
a digit; there is **no player-facing Undo**; `project.yml` is the source of
truth and the `.xcodeproj` is generated.
