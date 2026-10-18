import bpy

from .fracture import fracture
from .operators import KINETIC_FORGE_OT_add_rigidbodies_to_selected, KINETIC_FORGE_OT_bake_to_keyframes, KINETIC_FORGE_OT_copy_keyframes, KINETIC_FORGE_OT_fracture

from .panel import KineticForgePanel
from .props import KineticForgeSettings

# Settings first since everything reads them, and operators before panels,
# since panels draw buttons for them
classes = (
    KineticForgeSettings,
    KINETIC_FORGE_OT_fracture,
    KINETIC_FORGE_OT_add_rigidbodies_to_selected,
    KINETIC_FORGE_OT_bake_to_keyframes,
    KINETIC_FORGE_OT_copy_keyframes,
    KineticForgePanel,
)


def registered_class(cls: type) -> type | None:
    # This exact class may already be registered (the add-on enabled twice)
    if cls.is_registered:
        return cls

    # Otherwise look up a stale copy from an earlier import (script re-runs or
    # add-on reloads). Property groups aren't listed in bpy.types, but Blender
    # replaces those itself, so only operators and panels need this.
    if issubclass(cls, bpy.types.Operator):
        prefix, name = cls.bl_idname.split(".")
        return getattr(bpy.types, f"{prefix.upper()}_OT_{name}", None)

    if issubclass(cls, bpy.types.Panel):
        return getattr(bpy.types, cls.bl_idname, None)

    return None


def register() -> None:
    for cls in classes:
        existing = registered_class(cls)

        if existing:
            bpy.utils.unregister_class(existing)

        bpy.utils.register_class(cls)

    bpy.types.Scene.kinetic_forge = bpy.props.PointerProperty(type=KineticForgeSettings)


def unregister() -> None:
    if hasattr(bpy.types.Scene, "kinetic_forge"):
        del bpy.types.Scene.kinetic_forge

    for cls in reversed(classes):
        existing = registered_class(cls)

        if existing:
            bpy.utils.unregister_class(existing)
