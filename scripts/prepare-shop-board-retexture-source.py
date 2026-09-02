"""Prepare the original high-detail Meshy board for consistent retexturing.

The source texture GLB has the coherent UV layout that the geometry-only export
lacks.  This keeps those UVs, removes the old image payload, and decimates the
mesh to a simulator-friendly target before it is sent back through Meshy.
"""

import argparse
import sys
from pathlib import Path

import bpy


def triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


parser = argparse.ArgumentParser()
parser.add_argument("source")
parser.add_argument("destination")
parser.add_argument("--triangles", type=int, default=300_000)
script_args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else None
args = parser.parse_args(script_args)

source = Path(args.source).resolve()
destination = Path(args.destination).resolve()
destination.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))

meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if not meshes:
    raise RuntimeError(f"No mesh found in {source}")

total_before = sum(triangle_count(obj) for obj in meshes)
ratio = min(1.0, args.triangles / max(total_before, 1))

for obj in meshes:
    if not obj.data.uv_layers:
        raise RuntimeError(f"{obj.name} has no UV map; refusing destructive unwrap")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new(name="Production Decimate", type="DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)

# Keep one neutral material but discard the source's embedded 4K texture payload.
for material in list(bpy.data.materials):
    bpy.data.materials.remove(material)
neutral = bpy.data.materials.new(name="MeshyRetextureSource")
neutral.diffuse_color = (0.18, 0.18, 0.18, 1.0)
for obj in meshes:
    obj.data.materials.clear()
    obj.data.materials.append(neutral)

bpy.ops.export_scene.gltf(
    filepath=str(destination),
    export_format="GLB",
    export_materials="EXPORT",
    export_texcoords=True,
    export_normals=True,
    export_yup=True,
)

total_after = sum(triangle_count(obj) for obj in meshes)
print(f"source_triangles={total_before}")
print(f"output_triangles={total_after}")
print(f"output={destination}")
