# pyright: reportInvalidTypeForm=false
import bpy

class KineticForgeSettings(bpy.types.PropertyGroup):
    friction: bpy.props.FloatProperty(name="Friction", default=0.5, min=0, soft_max=1)
    bounciness: bpy.props.FloatProperty(name="Bounciness", default=0, min=0, soft_max=1)
    seed_count: bpy.props.IntProperty(name="Cells", default=10, min=2, soft_max=100)
    break_threshold: bpy.props.FloatProperty(name="Breaking Threshold", default=0.1, min=0, soft_max=1)
    disable_collisions: bpy.props.BoolProperty(name="Disable Collisions", default=False)
    collision_margin: bpy.props.FloatProperty(name="Collision Margin", default=0, min=0, soft_max=1)
    body_mass: bpy.props.FloatProperty(name="Rigid Body Mass", default=1, min=0, soft_max=10)
    connect_touching: bpy.props.BoolProperty(name="Connect Touching Objects", default=True)
    use_breaking: bpy.props.BoolProperty(name="Use Breaking", default=True)
    collision_shape: bpy.props.EnumProperty(
        name="Collision Shape",
        items=[
            ("CONVEX_HULL", "Convex Hull", "Tight convex wrap around the mesh"),
            ("MESH", "Mesh", "Exact mesh surface (slowest)"),
            ("BOX", "Box", "Bounding box"),
            ("SPHERE", "Sphere", "Bounding sphere"),
            ("CAPSULE", "Capsule", "Bounding capsule"),
            ("CYLINDER", "Cylinder", "Bounding cylinder"),
            ("CONE", "Cone", "Bounding cone"),
            ("COMPOUND", "Compound", "Combine child shapes"),
        ],
        default="CONVEX_HULL",
    )