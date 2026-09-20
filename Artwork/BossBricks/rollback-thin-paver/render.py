"""Render the square fired-clay paver used by the two Garry bosses.

/Applications/Blender.app/Contents/MacOS/Blender --background \
    --python Artwork/BossBricks/render.py

Modelled square paver; no holes, background, or baked contact shadow.
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
scene.cycles.samples = 128
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 384
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.7, .76, .84, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .24

clay = bpy.data.materials.new('Dense gritty red fired clay')
clay.diffuse_color = (.40, .095, .062, 1)
clay.use_nodes = True
nodes, links = clay.node_tree.nodes, clay.node_tree.links
bsdf = nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = .98
bsdf.inputs['Specular IOR Level'].default_value = .16
coords = nodes.new('ShaderNodeTexCoord')

# Small mineral flecks, rather than the broad cloudy surface of the
# rejected miniature brick. The high-frequency grain remains visible
# on the large source asset while averaging naturally on the phone.
grain = nodes.new('ShaderNodeTexNoise')
grain.inputs['Scale'].default_value = 93
grain.inputs['Detail'].default_value = 2
grain.inputs['Roughness'].default_value = .8
links.new(coords.outputs['Object'], grain.inputs['Vector'])
shade = nodes.new('ShaderNodeValToRGB')
ramp = shade.color_ramp
ramp.elements.remove(ramp.elements[1])
ramp.elements[0].position = .30
ramp.elements[0].color = (.027, .008, .005, 1)
for position, color in [
    (.38, (.15, .027, .017, 1)),
    (.44, (.36, .07, .046, 1)),
    (.59, (.44, .105, .071, 1)),
    (.75, (.63, .24, .15, 1)),
]:
    element = ramp.elements.new(position)
    element.color = color
links.new(grain.outputs['Fac'], shade.inputs['Fac'])
links.new(shade.outputs['Color'], bsdf.inputs['Base Color'])
bump = nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .66
bump.inputs['Distance'].default_value = .032
links.new(grain.outputs['Fac'], bump.inputs['Height'])
links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])

# A square solid paver like the supplied reference, sized to occupy almost
# the whole Sudoku cell. Substantial front thickness carries its depth.
side, height = 2.40, .52
bpy.ops.mesh.primitive_cube_add(location=(0, 0, height / 2))
brick = bpy.context.object
brick.name = 'Solid square red-clay paver'
brick.scale = (side / 2, side / 2, height / 2)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
brick.data.materials.append(clay)
bevel = brick.modifiers.new('Small fired-clay edge wear', 'BEVEL')
bevel.width = .019
bevel.segments = 2
bpy.ops.object.modifier_apply(modifier=bevel.name)

# Restrained chips in a few exposed edges; no cavities in the top.
for index, (loc, size, angles) in enumerate([
    ((-1.18, -1.19, .50), (.035, .04, .027), (.25, .28, .42)),
    ((.72, -1.196, .49), (.028, .024, .033), (.35, .5, .2)),
    ((1.195, .62, .50), (.026, .032, .023), (.3, -.25, .3)),
]):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    chip = bpy.context.object
    chip.scale = size
    chip.rotation_euler = angles
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = brick
    cut = brick.modifiers.new(f'Worn edge {index + 1}', 'BOOLEAN')
    cut.operation = 'DIFFERENCE'
    cut.object = chip
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(chip, do_unlink=True)

bevel = brick.modifiers.new('Slightly softened chips', 'BEVEL')
bevel.width = .007
bevel.segments = 2
bevel.limit_method = 'ANGLE'
bevel.angle_limit = .45
bevel.harden_normals = True
brick.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
brick.rotation_euler.z = math.radians(-2)

# Nearly overhead with a clearly visible front wall and a narrow right
# edge. A tiny yaw preserves the square footprint of the cell.
look_at = Vector((0, 0, height / 2))
bpy.ops.object.camera_add(location=(.30, -6, 10.65))
camera = bpy.context.object
camera.name = 'Tightly framed square paver portrait'
camera.rotation_euler = (look_at - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
scene.camera = camera
bpy.context.view_layer.update()

# Fit evaluated geometry inside the requested tight bounds, with extra
# room below for the runtime contact shadow. No opaque-image crop or
# scaling is required: the original 3D render itself is tightly framed.
evaluated = brick.evaluated_get(bpy.context.evaluated_depsgraph_get())
view_matrix = camera.matrix_world.inverted()
points = [view_matrix @ (evaluated.matrix_world @ v.co) for v in evaluated.data.vertices]
x0, x1 = min(p.x for p in points), max(p.x for p in points)
y0, y1 = min(p.y for p in points), max(p.y for p in points)
camera.data.ortho_scale = max((x1 - x0) * 384 / 368, (y1 - y0) * 384 / 358)
view_x = camera.matrix_world.to_quaternion() @ Vector((1, 0, 0))
view_y = camera.matrix_world.to_quaternion() @ Vector((0, 1, 0))
camera.location += view_x * ((x0 + x1) / 2)
camera.location += view_y * ((y0 + y1) / 2 - camera.data.ortho_scale * 5 / 384)

def area(name, position, energy, size, color):
    bpy.ops.object.light_add(type='AREA', location=position)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    light.rotation_euler = (look_at - light.location).to_track_quat('-Z', 'Y').to_euler()

area('Soft window above the paper', (-3.8, -3.0, 7.8), 750, 3.0, (1.0, .95, .89))
area('Paper bounce', (4.0, 1.5, 5), 30, 4.0, (.8, .88, 1.0))
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.filepath = str(root / 'App/Assets.xcassets/BossBrick.imageset/brick.png')
bpy.ops.wm.save_as_mainfile(filepath=str(artwork / 'brick.blend'))
bpy.ops.render.render(write_still=True)
