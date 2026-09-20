# Garry brick landing prototype — 2026-09-16

Historical prototype evidence. The current sequential falls and impact dust are documented in [boss motion v2](../boss-motion-v2/verification.md); its intentional airborne travel supersedes the all-phase cell crop described below.

Current revision: both Garry bosses use solid square clay blocks with zero model yaw, zero camera azimuth, and no runtime rotation. Horizontal/vertical edges align with the grid. The asset has a 10% inset on every side and a visible front wall. Known numbers remain exposed.

The landing is projected toward the paper: apparent size decreases by up to 12%, the ground shadow contracts, and a small rebound follows impact at 0.56 seconds. There is no travel across neighboring squares. Every brick, shadow and dust frame is clipped to its own cell. Printed grid boundaries render above the layer.

Blocks land 45 ms apart. The event includes the turn number, so repeated rows or boxes land again. Initial mounting defers the trigger until the animator exists; pending blocks remain hidden. Reduce Motion shows the settled blocks immediately. Covering the board or leaving the app settles an interrupted animation without replaying it on return.

The asset is a Blender-rendered image animated in SwiftUI, not a live physics simulation. Rules, boss selection, and save state are unchanged.

Source: `Artwork/BossBricks/brick.blend`; reproducible generator: `Artwork/BossBricks/render.py`. Rejected assets and their source scenes are preserved in that artwork directory. Earlier screenshots in this folder preserve iteration evidence.

Local iPhone 17 Pro simulator: `223A4227-A28E-4939-BB5E-3AAB820EB635`.
Built app: `/tmp/numberclub-bricks/build/Build/Products/Debug-iphonesimulator/ProbablySudoku.app`.

Open either encounter:

```sh
xcrun simctl launch --terminate-running-process 223A4227-A28E-4939-BB5E-3AAB820EB635 com.numberclub.app -skipStartScreen -seed BRICK-PREVIEW -qaBoss grayTheGarry
xcrun simctl launch --terminate-running-process 223A4227-A28E-4939-BB5E-3AAB820EB635 com.numberclub.app -skipStartScreen -seed BRICK-PREVIEW -qaBoss garryTheGray
```

Press End Turn to relocate the bricks. These existing debug routes apply a boss to an easy puzzle for visual inspection; they do not represent completion of a normal boss encounter.

Validation:
- BossBoardVisualTests includes 23 checks, covering the new distinct airborne/impact/rebound/settled frames, same-square replay on later turns, Reduce Motion, and the existing boss render checks.
- The earlier 8 BossBoardRestrictionTests passed; no engine files changed in the visual revisions.
- Frame-by-frame simulator video confirmed the initial encounter drop and next-turn drop. Live UI verifies that only blocked blanks are disabled and released cells become available.

Final raised-block verification:
- `raised-square-box.png`: current resting block treatment in the simulator.
- `brick-landing.mp4`: 3.7-second live simulator capture of the next-turn landing, including airborne blocks, detached shadows, impact and settle.
- Latest simulator test run: 23/23 passed. Log: `/tmp/numberclub-bricks/raised-brick-tests.log`.
- The visible front wall now occupies approximately a quarter of the silhouette. The right wall and bevel retain contrast at a 40px cell size; source preview: `Artwork/BossBricks/preview-40px-grid.png`.

Current aligned revision validation:
- `cell-aligned-box.png` and `cell-aligned-landing.mp4` show the current simulator build. Earlier files are preserved revision evidence.
- 25/25 BossBoardVisualTests passed: `/tmp/numberclub-bricks/aligned-brick-tests.log`.
- 60 pixel-render samples at 28/40/64pt, 2×/3×, across ten landing phases show zero pixels outside the cell while retaining visible blocks.
- For both bosses, blocked blanks reject selection while adjacent unblocked blanks remain selectable; inspection leaves game state unchanged.
