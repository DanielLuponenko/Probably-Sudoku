# Physical boss brick

The runtime image is a transparent, ray-traced Blender render of a modelled
terracotta brick. The brick has a 2:1 rectangular top, substantial height,
three deep cylindrical recesses, bevelled lips, small geometric chips, and
procedural mineral grain. The oblique camera reveals the front and right
walls at the game's small cell size.

- Source scene: `brick.blend`
- Reproducible generator: `render.py`
- Runtime image: `../../App/Assets.xcassets/BossBrick.imageset/brick.png`
- Size: 384 × 384 RGBA
- Previous flat tile, scene and generator: `rollback-flat-tile/`

Rebuild from the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python Artwork/BossBricks/render.py
```

There is no baked background or ground shadow. The game supplies the
animated shadow and falling/impact transforms. The visible base ends at
approximately 78% of the image height, leaving room for the contact shadow.

Created locally with Blender. No downloaded models or textures.
