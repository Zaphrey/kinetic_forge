import bpy

def apply_scale(collection: bpy.types.Collection) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    for object in collection.objects:
        object.select_set(True)

    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)