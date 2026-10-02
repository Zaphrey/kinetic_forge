import bpy

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
        meshes = apply_rigid_bodies_to_selected(settings.friction, settings.bounciness, settings.break_threshold)

        if not meshes:
            self.report({'WARNING'}, "No mesh objects selected")
            return {'CANCELLED'}

        self.report({'INFO'}, f"Applied to {len(meshes)} objects.")
        return {'FINISHED'}