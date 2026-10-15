import os
import sys

import bpy
from bpy_extras import anim_utils
import json
import math
from mathutils import Euler
import struct

SRC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL_COUNT = 50

if SRC_DIR not in sys.path:
    sys.path.insert(0, SRC_DIR)

def scan_selected_objects():
    """
    Store keyframe data as:
    {
        dict[obj] = {
            # Create a map of frames
            map[frame] = {
                rotation: vector3 or 3 slot array,
                position: vector3 or 3 slot array
            }
        }
    }
    """

    data = {}

    for obj in bpy.context.selected_objects:
        animation_data = obj.animation_data
        if animation_data and animation_data.action:
            channel_bag = anim_utils.action_get_channelbag_for_slot(animation_data.action, animation_data.action_slot)
            frames = set()

            data[obj.name] = {}

            for f_curve in channel_bag.fcurves:
                for keyframe_point in f_curve.keyframe_points:

                    frame = keyframe_point.co[0]

                    frame = math.floor(frame)
                    frames.add(frame)

            frames = sorted(frames)

            for f_curve in channel_bag.fcurves:
                for frame in frames:
                    if frame not in data[obj.name]:
                        data[obj.name][frame] = [None, None, None, None, None, None]
                                            
                    match f_curve.data_path:
                        case "location":
                            data[obj.name][frame][f_curve.array_index] = f_curve.evaluate(frame)
                        case "rotation_euler":
                            data[obj.name][frame][f_curve.array_index + 3] = f_curve.evaluate(frame)
                        case _:
                            pass

            # Convert Euler angles to quaternions:
            for frame in frames:
                euler = Euler(data[obj.name][frame][3:6], obj.rotation_mode)
                quaternion = euler.to_quaternion()
                w = quaternion[0]
                w_sign = math.copysign(1, w)
                # Drop the quaternion's w component, we can rebuild it on the other side of the pipeline
                # with w = math.sqrt(math.max(0, 1 - x*x - y*y - z*z))
                data[obj.name][frame][3:7] = list(map(lambda x: round(x * 100000 * w_sign), quaternion[1:4]))
                data[obj.name][frame][0:3] = list(map(lambda x: round(x * 10000), data[obj.name][frame][0:3]))
                # del data[obj.name][frame]["rotation"]

    json_string = json.dumps(data, separators=(",", ":"))
    # print(json_string)
    bpy.context.window_manager.clipboard = json_string

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

scan_selected_objects()

# reset_scene()
# bpy.ops.mesh.primitive_torus_add(location=(0, 0, 0))
# kinetic_forge.fracture([bpy.context.active_object], CELL_COUNT)A