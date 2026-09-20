"""Render the solid, grid-aligned square boss brick and its 40px paper-grid proof.

/Applications/Blender.app/Contents/MacOS/Blender --background \
    --python Artwork/BossBricks/render.py

The production PNG is a ray-traced physical model, with no baked plane.
The second scene composites that same PNG at exactly 40px onto a cream
number grid, so depth must survive the actual game's display scale.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
artwork = root / 'Artwork/BossBricks'
asset_path = root / 'App/Assets.xcassets/BossBrick.imageset/brick.png'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.name = 'Physical square brick'
scene.render.engine = 'CYCLES'
scene.cycles.samples = 160
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 384
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.7, .77, .9, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .13


def clay_material(name, base):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*base, 1)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .87
    bsdf.inputs['Specular IOR Level'].default_value = .24
    coords = nodes.new('ShaderNodeTexCoord')
    coarse = nodes.new('ShaderNodeTexNoise')
    coarse.inputs['Scale'].default_value = 3.5
    coarse.inputs['Detail'].default_value = 4
    links.new(coords.outputs['Object'], coarse.inputs['Vector'])
    variation = nodes.new('ShaderNodeValToRGB')
    variation.color_ramp.elements[0].color = tuple(c * .72 for c in base) + (1,)
    variation.color_ramp.elements[1].color = tuple(c * 1.16 for c in base) + (1,)
    links.new(coarse.outputs['Fac'], variation.inputs['Fac'])
    grain = nodes.new('ShaderNodeTexNoise')
    grain.inputs['Scale'].default_value = 77
    grain.inputs['Detail'].default_value = 3
    grain.inputs['Roughness'].default_value = .75
    links.new(coords.outputs['Object'], grain.inputs['Vector'])
    grit = nodes.new('ShaderNodeValToRGB')
    grit.color_ramp.elements[0].position = .28
    grit.color_ramp.elements[0].color = (.17, .17, .17, 1)
    grit.color_ramp.elements[1].position = .47
    grit.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(grain.outputs['Fac'], grit.inputs['Fac'])
    multiply = nodes.new('ShaderNodeMixRGB')
    multiply.blend_type = 'MULTIPLY'
    multiply.inputs[0].default_value = .62
    links.new(variation.outputs['Color'], multiply.inputs[1])
    links.new(grit.outputs['Color'], multiply.inputs[2])
    links.new(multiply.outputs['Color'], bsdf.inputs['Base Color'])
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .48
    bump.inputs['Distance'].default_value = .026
    links.new(grain.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    return material

# The broad top is slightly more weathered, and the fresh side clay is
# richer. Directional light strengthens this real three-face distinction.
top_clay = clay_material('Sun-worn warm clay top', (.58, .177, .083))
front_clay = clay_material('Rich fired-clay walls', (.385, .091, .04))
edge_clay = clay_material('Worn bevel highlight', (.68, .255, .135))

# The previous paver's shallow wall disappeared at 40px. This solid block
# has enough real height to show ~1/5 of its silhouette as front wall.
side, height = 2.40, .88
bpy.ops.mesh.primitive_cube_add(location=(0, 0, height / 2))
brick = bpy.context.object
brick.name = 'Grid-aligned solid square clay brick'
brick.scale = (side / 2, side / 2, height / 2)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for material in (front_clay, top_clay, edge_clay):
    brick.data.materials.append(material)
for face in brick.data.polygons:
    face.material_index = 1 if face.normal.z > .5 else 0
bevel = brick.modifiers.new('Visible worn edge highlight', 'BEVEL')
bevel.width = .042
bevel.segments = 3
bevel.material = 2
bpy.ops.object.modifier_apply(modifier=bevel.name)

# Small geometric chips establish material without interrupting a solid
# square top or repeating the rejected perforated-brick design.
for index, (loc, size, angles) in enumerate([
    ((-1.175, -1.18, height - .025), (.055, .045, .042), (.25, .28, .42)),
    ((.68, -1.195, height - .03), (.038, .03, .046), (.35, .5, .2)),
    ((1.19, .58, height - .028), (.036, .043, .037), (.3, -.25, .3)),
    ((1.18, -1.18, .055), (.055, .045, .05), (.35, .2, .4)),
]):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    chip = bpy.context.object
    chip.scale = size
    chip.rotation_euler = angles
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = brick
    cut = brick.modifiers.new(f'Fired edge chip {index + 1}', 'BOOLEAN')
    cut.operation = 'DIFFERENCE'
    cut.object = chip
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(chip, do_unlink=True)
bevel = brick.modifiers.new('Soft chip lips', 'BEVEL')
bevel.width = .009
bevel.segments = 2
bevel.limit_method = 'ANGLE'
bevel.angle_limit = .45
bevel.harden_normals = True
brick.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
brick.rotation_euler.z = 0

# Pitch only: exactly zero yaw and azimuth align the brick to the grid.
# Top/front edges are horizontal and left/right edges are vertical.
# A front wall of about 21% of the silhouette height supplies depth.
look_at = Vector((0, 0, height / 2))
bpy.ops.object.camera_add(location=(0, -6, 8.8))
camera = bpy.context.object
camera.name = 'Grid-aligned square brick with front thickness'
camera.rotation_euler = (look_at - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
scene.camera = camera
bpy.context.view_layer.update()
evaluated = brick.evaluated_get(bpy.context.evaluated_depsgraph_get())
view_matrix = camera.matrix_world.inverted()
points = [view_matrix @ (evaluated.matrix_world @ v.co) for v in evaluated.data.vertices]
x0, x1 = min(p.x for p in points), max(p.x for p in points)
y0, y1 = min(p.y for p in points), max(p.y for p in points)
camera.data.ortho_scale = max((x1 - x0) * 384 / 304, (y1 - y0) * 384 / 304)
view_x = camera.matrix_world.to_quaternion() @ Vector((1, 0, 0))
view_y = camera.matrix_world.to_quaternion() @ Vector((0, 1, 0))
camera.location += view_x * ((x0 + x1) / 2)
camera.location += view_y * ((y0 + y1) / 2)

def area(name, position, energy, size, color):
    bpy.ops.object.light_add(type='AREA', location=position)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.size = size
    light.data.color = color
    light.rotation_euler = (look_at - light.location).to_track_quat('-Z', 'Y').to_euler()

area('Warm upper-left window', (-3.7, -3.7, 7.5), 850, 2.8, (1, .95, .88))
area('Soft paper fill', (3.7, .8, 4.5), 18, 4.0, (.76, .84, 1))
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.filepath = str(asset_path)
bpy.ops.wm.save_as_mainfile(filepath=str(artwork / 'brick.blend'))
bpy.ops.render.render(write_still=True)

# Independent flat orthographic scene displays the actual asset at 40px
# on cream graph paper. This is a Blender composite, not a new large
# isolated beauty render pretending to prove the small-screen result.
preview = bpy.data.scenes.new('Forty-pixel paper-grid proof')
bpy.context.window.scene = preview
preview.render.engine = 'BLENDER_EEVEE'
preview.render.resolution_x, preview.render.resolution_y = 640, 320
preview.render.resolution_percentage = 100
preview.world = bpy.data.worlds.new('Preview background')
preview.view_settings.view_transform = 'Standard'
preview.view_settings.look = 'None'
preview.render.image_settings.file_format = 'PNG'
preview.render.image_settings.color_mode = 'RGBA'

def flat_material(name, rgba):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    emission = nodes.new('ShaderNodeEmission')
    emission.inputs['Color'].default_value = rgba
    links.new(emission.outputs[0], out.inputs['Surface'])
    return mat

def rect(name, x, y, w, h, z, material):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (w, h, 1)
    obj.data.materials.append(material)
    return obj

cream = flat_material('Cream paper', (.83, .79, .67, 1))
grid_mat = flat_material('Pencil grid', (.31, .29, .24, 1))
ink = flat_material('Pencil labels', (.11, .105, .085, 1))
rect('Cream background', 0, 0, 640, 320, 0, cream)
bpy.ops.object.camera_add(location=(0, 0, 500))
preview.camera = bpy.context.object
preview.camera.data.type = 'ORTHO'
preview.camera.data.ortho_scale = 640
for x in range(-288, -47, 40):
    rect('Grid vertical', x, 0, 1, 240, .02, grid_mat)
for y in range(-120, 121, 40):
    rect('Grid horizontal', -168, y, 240, 1, .02, grid_mat)

image_mat = bpy.data.materials.new('Actual transparent production image')
image_mat.use_nodes = True
nodes, links = image_mat.node_tree.nodes, image_mat.node_tree.links
nodes.clear()
out = nodes.new('ShaderNodeOutputMaterial')
texture = nodes.new('ShaderNodeTexImage')
texture.image = bpy.data.images.load(str(asset_path), check_existing=False)
texture.interpolation = 'Linear'
emission = nodes.new('ShaderNodeEmission')
transparent = nodes.new('ShaderNodeBsdfTransparent')
mix = nodes.new('ShaderNodeMixShader')
links.new(texture.outputs['Color'], emission.inputs['Color'])
links.new(texture.outputs['Alpha'], mix.inputs[0])
links.new(transparent.outputs[0], mix.inputs[1])
links.new(emission.outputs[0], mix.inputs[2])
links.new(mix.outputs[0], out.inputs['Surface'])
image_mat.surface_render_method = 'DITHERED'
for index, (x, y) in enumerate([(-228, 60), (-148, 60), (-188, 20), (-148, 20), (-188, -60)]):
    rect(f'40px block {index}', x, y, 40, 40, .2, image_mat)
rect('200px detail', 150, 0, 200, 200, .2, image_mat)

def label(body, x, y, size):
    bpy.ops.object.text_add(location=(x, y, .3))
    obj = bpy.context.object
    obj.data.body = body
    obj.data.size = size
    obj.data.materials.append(ink)

for body, x, y in [('7', -276, 90), ('3', -236, 90), ('4', -116, 90),
                    ('2', -276, 50), ('9', -196, 50), ('1', -116, 50),
                    ('8', -236, 10), ('6', -116, 10), ('5', -276, -30),
                    ('4', -236, -30), ('9', -156, -30), ('7', -76, -30)]:
    label(body, x, y, 21)
label('40 px / cell', -285, 134, 15)
label('Enlarged geometry', 56, 134, 15)
label('Aligned to the grid / visible front wall / 10% inset', -284, -148, 13)
preview.render.filepath = str(artwork / 'preview-40px-grid.png')
bpy.ops.render.render(write_still=True)
