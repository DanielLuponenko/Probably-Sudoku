# Physical square boss paver

The runtime image is a transparent, ray-traced Blender render of a solid
square fired-clay paver, matching the supplied red paving-brick reference.
It has no holes. Dense mineral grain, slight edge wear, and a substantial
visible front wall distinguish the block from a flat colored cell.

- Source scene: `brick.blend`
- Reproducible generator: `render.py`
- Runtime image: `../../App/Assets.xcassets/BossBrick.imageset/brick.png`
- Size: 384 × 384 RGBA
- Tight visible bounds: approximately x8–375 / y9–365
- Original shallow tile: `rollback-flat-tile/`
- Rejected rectangular brick with three holes: `rollback-perforated-brick/`

Rebuild from the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python Artwork/BossBricks/render.py
```

The square top has a tiny yaw. The camera looks mostly downward while
revealing the front thickness and a narrow right edge. The generator fits
the evaluated 3D geometry into a nearly full-canvas footprint; it does not
leave the large transparent margins of the previous rectangular brick.

There is no baked background or ground shadow. The game supplies the
animated shadow and falling/impact transforms. The base extends to about
95% of the image height. Display the image at the full cell size to leave
only a small paper clearance around the paver.

Created locally with Blender. No downloaded models or textures.
