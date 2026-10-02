import bpy


class KineticForgePanel(bpy.types.Panel):
    bl_idname = "OBJECT_PT_kinetic_forge"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Kinetic Forge"
    bl_label = "Kinetic Forge"

    @classmethod
    def poll(cls, context: bpy.types.Context) -> bool:
        return (context.object is not None)

    def draw_header(self, context: bpy.types.Context) -> None:
        layout = self.layout

    def draw(self, context: bpy.types.Context) -> None:
        layout = self.layout

        settings = context.scene.kinetic_forge

        box = layout.box()
        box.label(text="Fracture Mesh")
        # row = layout.row(text="asd")
        box.prop(settings, "seed_count", slider=True)
        box.operator("kinetic_forge.fracture", icon='MOD_EXPLODE')

        box = layout.box()
        box.label(text="Apply Rigid Body Constraints")
        box.prop(settings, "friction", slider=True)
        box.prop(settings, "bounciness", slider=True)
        box.prop(settings, "break_threshold", slider=True)
        box.operator("kinetic_forge.add_rigidbodies_to_selected", icon='MOD_EXPLODE')

        box = layout.box()
        box.label(text="Adjust Rigid Body Settings")
