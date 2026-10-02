import os
import sys

import bpy

SRC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL_COUNT = 50

if SRC_DIR not in sys.path:
    sys.path.insert(0, SRC_DIR)

# Blender keeps modules cached between runs, so drop them to pick up edits
for name in list(sys.modules):
    if name == "kinetic_forge" or name.startswith("kinetic_forge."):
        del sys.modules[name]

import kinetic_forge

def reset_scene() -> None:
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    collections_to_remove = [collection.id_data for collection in bpy.data.collections if collection.name.startswith("kinetic_forge")]
    bpy.data.batch_remove(collections_to_remove)

kinetic_forge.register()

# reset_scene()
# bpy.ops.mesh.primitive_torus_add(location=(0, 0, 0))
# kinetic_forge.fracture([bpy.context.active_object], CELL_COUNT)A