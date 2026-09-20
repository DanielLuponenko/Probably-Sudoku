"""Rebuild with Blender --background --python Artwork/BossBricks/render.py."""
import bpy, math
from pathlib import Path
from mathutils import Vector
root = Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.render.resolution_x = scene.render.resolution_y = 384
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.world.color = (0.35, 0.35, 0.35)
mat = bpy.data.materials.new('Warm fired clay')
mat.diffuse_color = (0.48, 0.19, 0.105, 1)
mat.use_nodes = True
n = mat.node_tree.nodes
l = mat.node_tree.links
bsdf = n.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = .88
noise = n.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value = 38
noise.inputs['Detail'].default_value = 4
ramp = n.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].color = (.22, .075, .038, 1)
ramp.color_ramp.elements[1].color = (.65, .34, .19, 1)
l.new(noise.outputs['Fac'], ramp.inputs[0])
l.new(ramp.outputs[0], bsdf.inputs['Base Color'])
bump = n.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .38
bump.inputs['Distance'].default_value = .045
l.new(noise.outputs['Fac'], bump.inputs['Height'])
l.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
# A broad brick with a chipped bevel; the oblique overhead camera reveals its front face.
bpy.ops.mesh.primitive_cube_add(location=(0,0,.16))
brick=bpy.context.object
brick.name='Solid clay brick'
brick.scale=(.94,.82,.16)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
brick.data.materials.append(mat)
bevel=brick.modifiers.new('Worn edges','BEVEL')
bevel.width=.055
bevel.segments=3
brick.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
bpy.ops.object.camera_add(location=(0,-3.8,8))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=2.12
scene.camera=camera
bpy.ops.object.light_add(type='AREA', location=(-3, -4, 7))
bpy.context.object.data.energy=650
bpy.context.object.data.shape='DISK'
bpy.context.object.data.size=4
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.filepath=str(root/'App/Assets.xcassets/BossBrick.imageset/brick.png')
bpy.ops.wm.save_as_mainfile(filepath=str(root/'Artwork/BossBricks/brick.blend'))
bpy.ops.render.render(write_still=True)
