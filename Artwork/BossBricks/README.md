# Grid-aligned solid square boss brick

The runtime PNG is a transparent Blender render of a solid square clay
brick with a clearly visible front wall. Model yaw and camera azimuth are
both exactly zero. The silhouette has horizontal top/front edges and
vertical side edges, so it aligns with the Sudoku grid. There is no
right-hand trapezoid, decorative tilt, or perforation.

- Source scene: `brick.blend`
- Reproducible generator and small-scale proof: `render.py`
- Runtime image: `../../App/Assets.xcassets/BossBrick.imageset/brick.png`
- Size: 384 × 384 RGBA
- Measured nonzero-alpha bounds: (40, 39) to (344, 345), right/bottom exclusive
- Small-scale proof: `preview-40px-grid.png`
- Model: square 2.4 × 2.4 top, 0.88 high
- Camera: orthographic, pitched only; x = 0, object yaw = 0
- Visible front wall: about 21% of the silhouette height

Rebuild from the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python Artwork/BossBricks/render.py
```

The generator renders the production PNG, then composites that exact
image at 40 × 40 pixels onto a cream number grid in a separate Blender
scene. The left-hand grid is the actual 40px proof; the right image is a
larger detail. Its axis-aligned outline remains completely inside each
cell. The material retains a warm clay top, darker front wall, small worn
bevel, and controlled gritty texture.

At least 10% of the canvas is transparent on every side. The app should
display this asset at no more than the full cell size and keep the whole
drawing, including contact shadow, inside the cell. There is no baked
ground shadow; the app supplies its dynamic ground/contact shadows.

Rollback evidence is retained:

- `rollback-flat-tile/`: original shallow tile
- `rollback-perforated-brick/`: rejected rectangular brick with three holes
- `rollback-thin-paver/`: rejected solid paver with insufficient depth
- `rollback-angled-block/`: rejected rotated block with a visible right wall
- `reference-user-square-paver.png`: original supplied material reference

Created locally with Blender. No downloaded models or textures.
