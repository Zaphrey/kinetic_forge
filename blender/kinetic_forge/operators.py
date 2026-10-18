import bpy

from .export import has_keyframes, keyframes_to_json
from .fracture import CellFractureMissing, fracture
from .physics import apply_rigid_bodies_to_selected


def rewind_simulation(context: bpy.types.Context) -> None:
    # Changing rigid bodies or constraints after the simulation has run past its
    # first frame can crash Blender, so always restart it from the beginning
    context.scene.frame_set(context.scene.frame_start)


class KINETIC_FORGE_OT_fracture(bpy.types.Operator):
    bl_idname = "kinetic_forge.fracture"
    bl_label = "Fracture"
    bl_description = "Fracture the selected meshes into connected rigid body pieces"
    bl_options = {'REGISTER', 'UNDO'}

    @classmethod
    def poll(cls, context: bpy.types.Context) -> bool:
        return context.mode == 'OBJECT' and any(o.type == 'MESH' for o in context.selected_objects)

    def execute(self, context: bpy.types.Context) -> set[str]:
        rewind_simulation(context)
        settings = context.scene.kinetic_forge
        targets = list(context.selected_objects)

        try:
            cell_collection = fracture(targets, settings.seed_count, settings.friction, settings.bounciness)
        except CellFractureMissing as error:
            self.report({'ERROR'}, str(error))
            return {'CANCELLED'}

        if cell_collection is None:
            self.report({'WARNING'}, "No mesh objects selected")
            return {'CANCELLED'}

        # Count only the pieces, not the constraint empties in the same collection
        piece_count = sum(o.type == 'MESH' for o in cell_collection.objects)
        self.report({'INFO'}, f"Fractured into {piece_count} pieces")
        return {'FINISHED'}

class KINETIC_FORGE_OT_add_rigidbodies_to_selected(bpy.types.Operator):
    bl_idname = "kinetic_forge.add_rigidbodies_to_selected"
    bl_label = "Apply"
    bl_description = "Creates or applies rigid body objects to all selected meshes"
    bl_options = {'REGISTER', 'UNDO'}

    @classmethod
    def poll(cls, context: bpy.types.Context) -> bool:
        return context.mode == 'OBJECT' and any(o.type == 'MESH' for o in context.selected_objects)

    def execute(self, context: bpy.types.Context) -> set[str]:
        rewind_simulation(context)
        settings = context.scene.kinetic_forge
        meshes = apply_rigid_bodies_to_selected(settings.friction, settings.bounciness, settings.break_threshold, settings.disable_collisions, settings.collision_margin, settings.connect_touching, settings.body_mass, settings.collision_shape, settings.use_breaking, constraint_type=settings.constraint_type, break_randomness=settings.break_randomness, break_seed=settings.break_seed, body_type=settings.body_type)

        if not meshes:
            self.report({'WARNING'}, "No mesh objects selected")
            return {'CANCELLED'}

        self.report({'INFO'}, f"Applied to {len(meshes)} objects.")
        return {'FINISHED'}


class KINETIC_FORGE_OT_bake_to_keyframes(bpy.types.Operator):
    bl_idname = "kinetic_forge.bake_to_keyframes"
    bl_label = "Bake to Keyframes"
    bl_description = "Bake the rigid body simulation of the selected objects into keyframes"
    bl_options = {'REGISTER', 'UNDO'}

    @classmethod
    def poll(cls, context: bpy.types.Context) -> bool:
        return context.mode == 'OBJECT' and any(o.rigid_body for o in context.selected_objects)

    def execute(self, context: bpy.types.Context) -> set[str]:
        rewind_simulation(context)
        scene = context.scene

        # The timeline's active range: the preview range when it's on, otherwise Start to End
        if scene.use_preview_range:
            frame_start, frame_end = scene.frame_preview_start, scene.frame_preview_end
        else:
            frame_start, frame_end = scene.frame_start, scene.frame_end

        result = bpy.ops.rigidbody.bake_to_keyframes(
            frame_start=frame_start,
            frame_end=frame_end,
            step=1,
        )

        if result != {'FINISHED'}:
            self.report({'ERROR'}, "Baking failed")
            return {'CANCELLED'}

        self.report({'INFO'}, f"Baked frames {frame_start}-{frame_end}")
        return {'FINISHED'}


class KINETIC_FORGE_OT_copy_keyframes(bpy.types.Operator):
    bl_idname = "kinetic_forge.copy_keyframes"
    bl_label = "Copy Keyframes"
    bl_description = "Copy every animated mesh's keyframes to the clipboard, ready to paste into the Roblox plugin"

    @classmethod
    def poll(cls, context: bpy.types.Context) -> bool:
        return has_keyframes(context.scene)

    def execute(self, context: bpy.types.Context) -> set[str]:
        context.window_manager.clipboard = keyframes_to_json(context.scene)
        self.report({'INFO'}, "Copied keyframes to the clipboard")
        return {'FINISHED'}