# Phase 0 baseline and rollback

Status: `IN_PROGRESS`

Captured: 2026-08-29 10:25–10:31 Asia/Jerusalem

## Repository state

- Repository: `/Users/daniel/NumberClub`
- Starting branch: `main`
- Starting commit: `942e0b4890645a306fc4e39140139de27b5dfbbb`
- Protected work branch: `feature/KAN-153-meshy-club-shop`
- Upstream at capture: `origin/main`, zero commits ahead/behind.
- Submodules: none.
- Existing state: 18 modified tracked files; 9 untracked files; approximately
  1,878 insertions and 861 deletions; approximately 5.2 MB untracked.
- The existing working tree was not reset, cleaned, stashed, or committed.

`develop` was an ancestor of `main` but lacked seven released/design/bookstore
commits. The protected feature branch was created at the current released
`main` commit so the active WIP and KAN-152 baseline were not rolled backward.
This deviation is recorded in `DECISIONS.md`.

## External rollback package

Directory:
`/Users/daniel/.codex/rollback/NumberClub/KAN-153/20260829T102546+0300`

Contents:

- `repository.bundle` — verified complete Git history and refs.
- `tracked-wip.patch` — binary/full-index diff from the starting commit.
- `untracked-files.tar.gz` — all nine untracked files at capture.
- `git-status.txt`, `head.txt`, and `SHA256SUMS`.

Key checksums:

- repository bundle: `6891028deb0a0e4f64c23f6eb41e103a890e3bf985b2c0e95089baaa3babe9d5`
- tracked WIP patch: `cdc41b3f280893b12fae49fc1c10ee98f2d001e8820d730d5adaa330c3739f7d`
- untracked archive: `6ba7d8c2f0dbdd130685807180025b7c515bf20475b322f702935ad4dc786b01`

## Baseline gates

| Gate | Command/evidence | Result |
|---|---|---|
| Project generation | `xcodegen generate` (2.46.0) | Passed |
| Engine tests | `cd Engine && swift test` | Passed: 136 tests, 0 failures |
| App unit tests | iPhone 17 Pro simulator, Xcode 26.2 | Passed: 28 tests, 0 failures; xcresult at `/tmp/NumberClub-KAN153-Baseline/Logs/Test/Test-ProbablySudoku-2026.08.29_10-28-39-+0300.xcresult` |
| Physical-device build | Daniel’s iPhone, Xcode UDID `00008140-0011451A1133001C` | Passed and signed |
| Build warning | Interface-orientation validation | Existing warning: all orientations required unless full-screen |
| Baseline screenshots | Compact / 17 Pro / largest / physical | Simulator compact, standard, and largest shop/gameplay captures preserved and visually reviewed; physical capture pending |
| Baseline frame time, memory, bundle size | Instruments/runtime evidence | Partial: 10-second Time Profiler traces, process memory snapshots, and simulator bundle size recorded; exact p95/min-device/thermal evidence pending |

An earlier physical build invocation used CoreDevice UUID
`536E6C2D-D5F0-54D4-8860-E6615A7DCE1C`; Xcode rejected that destination and
reported its own UDID. The corrected invocation passed. This is an environment
command mismatch, not a product build failure.

## Known temporary implementations requiring audit

- Existing turntable and `ClubTurntable.usdz`.
- Procedural flames and other procedural cosmetic effects.
- Text/font-based shop and gameplay number previews.
- Procedural bookstore/shop geometry and physical controls.
- Generic paper planes/rectangles and runtime material stand-ins.
- Any separate shop/game preview mapping or generated still thumbnail.

These paths remain available for comparison until replacements pass. They are
not approved and must be absent from the production reachability graph before
release.

## Preserved simulator screenshots

All six captures are from the protected baseline build and are recorded in
`SCREENSHOT_MATRIX.md`. Visual review confirms the current `-clubShop` route is
a flat, vertically scrolling SwiftUI catalog rather than the approved 3D
bookstore, while gameplay remains the book/grid surface with no approved Meshy
cosmetic package visible in the captured state.

| Surface | Compact 750×1334 | Standard 1206×2622 | Largest 1320×2868 |
|---|---|---|---|
| Flat Club Shop | `screenshots/baseline/KAN153-baseline-clubshop-compact.png` (`6801ad2c8442bc2a87dadcd3f5482cf18a6edefea8c26a9e34a4510469aae0ad`) | `screenshots/baseline/KAN153-baseline-clubshop-standard.png` (`8f0d32de40505acaa398da5628e6dc7c14a527ec26cf34b7185eb659ec31ec13`) | `screenshots/baseline/KAN153-baseline-clubshop-largest.png` (`5f5afe819050f9f2c1b102e001ee404ff11546ac47a530c99c83fdd7b6ec2c5b`) |
| Gameplay | `screenshots/baseline/KAN153-baseline-gameplay-compact.png` (`432a0aa839cd09054569982b292082f55c19a62d8102a0180f92ea6cb1ae2019`) | `screenshots/baseline/KAN153-baseline-gameplay-standard.png` (`fed0a7d33e160cc42ebd35b01aa0cc1bf21e5fec6fc9e77f85cfa50736ba92da`) | `screenshots/baseline/KAN153-baseline-gameplay-largest.png` (`ea2f5f326046a63c78744ffb211f9b16f79636ca8c162c3b63f4eaf1c4d2697f`) |

## Baseline performance evidence

- Simulator app bundle: approximately 52 MB (`53,560 KiB` file content).
- iPhone 17 Pro gameplay process snapshot: approximately 297,200 KB RSS;
  52 MB physical footprint and 52 MB peak physical footprint.
- iPhone 17 Pro flat-shop process snapshot: approximately 336,192 KB RSS;
  62 MB physical footprint and 65 MB peak physical footprint.
- Ten-second Time Profiler traces for gameplay and the flat shop reported no
  `potential-hangs` row above 250 ms. These traces do not establish p95 frame
  time or minimum-device sustained performance.
- Gameplay trace:
  `/Users/daniel/.codex/evidence/NumberClub/KAN-153/baseline-20260829/KAN153-baseline-gameplay-17pro.trace`
  (composite SHA-256 `b0342b28c5f4f74fac52de777c2712831edbfd13d1d6806d563522715b6e55bd`).
- Flat-shop trace:
  `/Users/daniel/.codex/evidence/NumberClub/KAN-153/baseline-20260829/KAN153-baseline-clubshop-17pro.trace`
  (composite SHA-256 `145ba1421c055b6c35ecf32930aa0e98c8a1a6dc477f5ede1e3599918d188b09`).
- The simulator Animation Hitches instrument returned “Hitches is not
  supported on this platform.” The failed-attempt trace is preserved at
  `/Users/daniel/.codex/evidence/NumberClub/KAN-153/baseline-20260829/KAN153-baseline-gameplay-hitches-17pro.trace`
  (composite SHA-256 `b8165adfdfadd1cd4bf136e5d631a1337830f7b6681325ba486e45a76e893663`) as
  environment evidence, not product-performance evidence. Per the SwiftUI
  profiling guidance, Simulator evidence uses Time Profiler; physical-device
  hitches/thermal validation remains mandatory.

## Phase 0 exit checklist

- [x] Existing work is externally recoverable.
- [x] Engine and app baseline test status is known.
- [x] Physical-device build status is known.
- [ ] Required baseline screenshots exist (simulator set complete; physical and minimum-iOS captures pending).
- [ ] Temporary implementations are fully tagged by the Sonnet audit.
- [ ] Baseline frame-time, memory, load-time, and package-size measurements are recorded where measurable (memory/bundle/10-second traces captured; p95, load time, thermal, physical-device evidence pending).

Phase 0 is not passed while any unchecked item remains.
