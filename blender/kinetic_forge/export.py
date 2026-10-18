import json
import math

import bpy
from bpy_extras import anim_utils
from mathutils import Euler

# Must match the multipliers in Roblox's KeyframeData
POSITION_SCALE = 10000
ROTATION_SCALE = 100000


def keyframe_channels(obj: bpy.types.Object) -> list[bpy.types.FCurve]:
    """The object's location and rotation_euler curves, or an empty list if it has none."""
    animation_data = obj.animation_data
    if obj.type != 'MESH' or not animation_data or not animation_data.action:
        return []

    # Rotations are read from rotation_euler, which quaternion and axis-angle objects don't use
    if obj.rotation_mode in ('QUATERNION', 'AXIS_ANGLE'):
        return []

    channel_bag = anim_utils.action_get_channelbag_for_slot(animation_data.action, animation_data.action_slot)
    if not channel_bag:
        return []

    return [f for f in channel_bag.fcurves if f.data_path in ("location", "rotation_euler")]


def has_keyframes(scene: bpy.types.Scene) -> bool:
    return any(keyframe_channels(obj) for obj in scene.objects)


def collect_keyframes(scene: bpy.types.Scene) -> dict:
    """
    Store keyframe data as:
    {
        fps: number,
        frames: {
            # Create a map of frames
            dict[frame] = {
                # Every object keyed on that frame
                map[obj] = [px, py, pz, qx, qy, qz]
            }
        }
    }
    """

    data = {}

    # Every animated mesh in the scene, so the export doesn't depend on what's selected
    for obj in scene.objects:
        f_curves = keyframe_channels(obj)
        if not f_curves:
            continue

        frames = sorted({math.floor(point.co[0]) for f_curve in f_curves for point in f_curve.keyframe_points})

        # Built per object first, then merged into data under each frame. Channels without a
        # curve keep the object's current value, since nothing animates them.
        obj_data = {frame: [*obj.location, *obj.rotation_euler] for frame in frames}

        for f_curve in f_curves:
            offset = 0 if f_curve.data_path == "location" else 3
            for frame in frames:
                obj_data[frame][f_curve.array_index + offset] = f_curve.evaluate(frame)

        # Convert Euler angles to quaternions:
        for frame in frames:
            quaternion = Euler(obj_data[frame][3:6], obj.rotation_mode).to_quaternion()
            w_sign = math.copysign(1, quaternion[0])
            # Drop the quaternion's w component, we can rebuild it on the other side of the pipeline
            # with w = math.sqrt(math.max(0, 1 - x*x - y*y - z*z))
            obj_data[frame][3:6] = [round(x * ROTATION_SCALE * w_sign) for x in quaternion[1:4]]
            obj_data[frame][0:3] = [round(x * POSITION_SCALE) for x in obj_data[frame][0:3]]

            data.setdefault(frame, {})[obj.name] = obj_data[frame]

    # Roblox keyframes are timed in seconds, so it needs the frame rate to convert
    render = scene.render
    return {
        "fps": render.fps / render.fps_base,
        # Objects can have different keyframes, so put the frames back in order
        "frames": dict(sorted(data.items())),
    }


def keyframes_to_json(scene: bpy.types.Scene) -> str:
    return json.dumps(collect_keyframes(scene), separators=(",", ":"))
