import bpy

class KineticForgeSettings(bpy.types.PropertyGroup):
    friction: bpy.props.FloatProperty(name="Friction", default=0.5, min=0, soft_max=1)
    bounciness: bpy.props.FloatProperty(name="Bounciness", default=0, min=0, soft_max=1)
    seed_count: bpy.props.IntProperty(name="Cells", default=10, min=2, soft_max=100)
    break_threshold: bpy.props.FloatProperty(name="Breaking Threshold", default=0.1, min=0, soft_max=1)
