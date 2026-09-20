# Raised solid square boss brick

The runtime PNG is a transparent, ray-traced Blender render of a solid
square clay block. It has no holes. The block is deliberately tall enough
for its front and right walls to remain visible in a 36–40pt Sudoku cell.
A warm, well-lit top, darker front, deeply shaded right wall, and a crisp
worn bevel provide the depth cues that disappeared in the thinner paver.

- Source scene: `brick.blend`
- Reproducible generator and small-scale proof: `render.py`
- Runtime image: `../../App/Assets.xcassets/BossBrick.imageset/brick.png`
- Size: 384 × 384 RGBA
- Small-scale proof: `preview-40px-grid.png`
- Model: square 2.4 × 2.4 top, 1.23 high; no core holes
- Camera: orthographic, about 51° elevation; visible front and right walls

Rebuild from the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python Artwork/BossBricks/render.py
```

The generator renders the production PNG, then uses that exact image in
an independent Blender scene at 40 × 40 pixels on a cream number grid.
The proof includes a larger detail view, but the left-hand grid is the
actual 40px test. The front wall occupies approximately one quarter of
the rendered silhouette height and survives at that size. The proof has
no simulated contact shadow; the app supplies its dynamic ground and
contact shadows.

The image is tightly framed. Its base extends to about 95% of canvas
height. Display it at the full cell size, leaving a small paper clearance.

Rollback evidence is retained:

- `rollback-flat-tile/`: original shallow tile
- `rollback-perforated-brick/`: rejected rectangular brick with three holes
- `rollback-thin-paver/`: rejected solid paver with insufficient depth
- `reference-user-square-paver.png`: original supplied material reference

Created locally with Blender. No downloaded models or textures.
