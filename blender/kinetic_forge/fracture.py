import secrets

import addon_utils
import bpy

from .physics import add_rigid_bodies
from .seeds import create_seed_object, sample_seeds, world_bounds

# Module names Cell Fracture has had: the current extension and the old bundled add-on
CELL_FRACTURE_MODULE_NAMES = ("cell_fracture", "object_fracture_cell")
CELL_FRACTURE_MARGIN = 0.001


class CellFractureMissing(Exception):
    pass


def cell_fracture_loaded() -> bool:
    return hasattr(bpy.types, "OBJECT_OT_add_fracture_cell_objects")


def ensure_cell_fracture() -> None:
    if cell_fracture_loaded():
        return

    # Enable it if it's installed but turned off, whichever repository it came from
    for module in addon_utils.modules():
        if module.__name__.split(".")[-1] in CELL_FRACTURE_MODULE_NAMES:
            bpy.ops.preferences.addon_enable(module=module.__name__)
            break

    if not cell_fracture_loaded():
        raise CellFractureMissing(
            "Kinetic Forge needs the Cell Fracture extension. "
            "Install it from Edit > Preferences > Get Extensions."
        )


def fracture_object(obj: bpy.types.Object, seed_count: int, cell_collection: bpy.types.Collection) -> list[bpy.types.Object]:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bb_min, bb_max = world_bounds(obj)
    seeds = sample_seeds(obj, seed_count, bb_min, bb_max)
    seed_obj = create_seed_object(seeds, obj)

    existing = set(cell_collection.objects)

    with bpy.context.temp_override(collection=cell_collection):
        bpy.ops.object.add_fracture_cell_objects(
            source={'VERT_CHILD'},
            source_limit=0,
            margin=CELL_FRACTURE_MARGIN,
            use_debug_redraw=False,
        )

    pieces = [o for o in cell_collection.objects if o not in existing and o.type == 'MESH']

    bpy.data.meshes.remove(seed_obj.data)
    bpy.data.objects.remove(obj)
    return pieces


def fracture(objects: list[bpy.types.Object], seed_count: int = 50, friction: float = 0.5, bounciness: float = 0) -> bpy.types.Collection | None:
    objects = [o for o in objects if o.type == 'MESH']

    if not objects:
        return None

    ensure_cell_fracture()

    cell_collection = bpy.data.collections.new(name=f"kinetic_forge_cells_{secrets.token_hex(8)}")
    bpy.context.scene.collection.children.link(cell_collection)

    pieces_per_object = [fracture_object(obj, seed_count, cell_collection) for obj in objects]
    all_pieces = [piece for pieces in pieces_per_object for piece in pieces]

    if not all_pieces:
        return cell_collection

    # add_rigid_bodies(all_pieces, friction, bounciness)

    # Only connect pieces that came from the same original object
    # for pieces in pieces_per_object:
    #     connect_touching_cells(pieces, cell_collection)

    return cell_collection
