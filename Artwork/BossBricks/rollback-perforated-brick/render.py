"""Render NumberClub's physical boss brick.

Rebuild with:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python Artwork/BossBricks/render.py

The image is an actual ray-traced 3D clay brick, with three recessed core
holes and thick bevelled walls. Runtime owns the falling transform and
contact shadow; this transparent asset intentionally has no baked plane.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
artwork = root / 'Artwork/BossBricks'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 384
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.65, .74, .88, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .22

clay = bpy.data.materials.new('Fired terracotta with mineral grain')
clay.diffuse_color = (.57, .145, .055, 1)
clay.use_nodes = True
nodes, links = clay.node_tree.nodes, clay.node_tree.links
bsdf = nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = .92
bsdf.inputs['Specular IOR Level'].default_value = .24
coords = nodes.new('ShaderNodeTexCoord')
coarse = nodes.new('ShaderNodeTexNoise')
coarse.inputs['Scale'].default_value = 6
coarse.inputs['Detail'].default_value = 3
coarse.inputs['Roughness'].default_value = .7
links.new(coords.outputs['Object'], coarse.inputs['Vector'])
shade = nodes.new('ShaderNodeValToRGB')
shade.color_ramp.elements[0].position = .12
shade.color_ramp.elements[0].color = (.32, .06, .022, 1)
shade.color_ramp.elements[1].position = .9
shade.color_ramp.elements[1].color = (.65, .215, .078, 1)
links.new(coarse.outputs['Fac'], shade.inputs['Fac'])
links.new(shade.outputs['Color'], bsdf.inputs['Base Color'])
grain = nodes.new('ShaderNodeTexNoise')
grain.inputs['Scale'].default_value = 72
ngrain = grain
ngrain.inputs['Detail'].default_value = 3
ngrain.inputs['Roughness'].default_value = .8
links.new(coords.outputs['Object'], grain.inputs['Vector'])
bump = nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .45
bump.inputs['Distance'].default_value = .042
links.new(grain.outputs['Fac'], bump.inputs['Height'])
links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

# True 2:1 plan proportions. The height is deliberately substantial, so the
# object remains recognizably masonry at a 36 pt Sudoku cell size.
length, width, height = 2.52, 1.26, .83
bpy.ops.mesh.primitive_cube_add(location=(0, 0, height / 2))
brick = bpy.context.object
brick.name = 'Physical terracotta brick — three deep cores'
brick.scale = (length / 2, width / 2, height / 2)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
brick.data.materials.append(clay)
bevel = brick.modifiers.new('Tumbled outer edges', 'BEVEL')
bevel.width = .065
bevel.segments = 3
bpy.ops.object.modifier_apply(modifier=bevel.name)

# Deep circular recesses provide unmistakable scale and shadow cues. Leave
# a clay floor beneath each core, rather than showing the board through it.
for index, x in enumerate((-.77, 0, .77)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=.247,
        depth=1.2, location=(x, 0, .71))
    cutter = bpy.context.object
    cutter.name = f'Core cutter {index + 1}'
    bpy.context.view_layer.objects.active = brick
    cut = brick.modifiers.new(f'Deep core {index + 1}', 'BOOLEAN')
    cut.operation = 'DIFFERENCE'
    cut.solver = 'EXACT'
    cut.object = cutter
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

# A handful of broad, quiet chips in the lip make the brick feel tangible.
# These cuts are modelled geometry, not black painted texture marks.
for index, (loc, size, angles) in enumerate([
    ((-1.205, -.58, .81), (.13, .13, .10), (.25, .28, .42)),
    ((.42, -.626, .77), (.075, .068, .07), (.35, .5, .2)),
    ((1.23, .57, .765), (.09, .105, .10), (.3, -.25, .3)),
]):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    chip = bpy.context.object
    chip.scale = size
    chip.rotation_euler = angles
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = brick
    cut = brick.modifiers.new(f'Small chipped edge {index + 1}', 'BOOLEAN')
    cut.operation = 'DIFFERENCE'
    cut.object = chip
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(chip, do_unlink=True)

bevel = brick.modifiers.new('Soft core lips and exposed chips', 'BEVEL')
bevel.width = .023
bevel.segments = 3
bevel.limit_method = 'ANGLE'
bevel.angle_limit = .45
bevel.harden_normals = True
brick.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
brick.rotation_euler.z = math.radians(-12)

# An oblique view, not a top-down tile: the front wall and right end cap
# are visible, while the three top holes stay readable at thumbnail size.
look_at = Vector((0, 0, .40))
bpy.ops.object.camera_add(location=(0, -6.2, 5.6))
camera = bpy.context.object
camera.name = 'Orthographic brick portrait'
camera.rotation_euler = (look_at - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.95
scene.camera = camera

def area(name, position, energy, size, color):
    bpy.ops.object.light_add(type='AREA', location=position)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    light.rotation_euler = (look_at - light.location).to_track_quat('-Z', 'Y').to_euler()

area('Warm window at upper left', (-3.2, -4.0, 7.0), 650, 3.0, (1.0, .89, .76))
area('Cool paper bounce', (3.8, 1.5, 4.0), 60, 4.0, (.7, .8, 1.0))
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.filepath = str(root / 'App/Assets.xcassets/BossBrick.imageset/brick.png')
bpy.ops.wm.save_as_mainfile(filepath=str(artwork / 'brick.blend'))
bpy.ops.render.render(write_still=True)
