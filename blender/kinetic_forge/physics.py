from typing import Literal, TypedDict

import bpy
import numpy as np
from mathutils import bvhtree, Vector


TOUCH_TOLERANCE = 0.01

ConstraintType = Literal[
    "FIXED", "POINT", "HINGE", "SLIDER", "PISTON", "GENERIC", "GENERIC_SPRING", "MOTOR"
]

class AABB(TypedDict):
    min: np.ndarray
    max: np.ndarray


def get_world_aabb(verts: np.ndarray) -> AABB:
    return {"min": verts.min(axis=0), "max": verts.max(axis=0)}


def get_bvh(obj: bpy.types.Object, verts: np.ndarray) -> bvhtree.BVHTree:
    mesh = obj.data
    mesh.calc_loop_triangles()

    tris = np.empty(len(mesh.loop_triangles) * 3, dtype=np.int32)
    mesh.loop_triangles.foreach_get("vertices", tris)

    return bvhtree.BVHTree.FromPolygons(verts.tolist(), tris.reshape(-1, 3).tolist(), all_triangles=True)


def get_world_verts(obj: bpy.types.Object) -> np.ndarray:
    mesh = obj.data
    co = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    matrix = np.array(obj.matrix_world)
    return co.reshape(-1, 3) @ matrix[:3, :3].T + matrix[:3, 3]


def contact_point(tree_a: bvhtree.BVHTree, aabb_a: AABB, verts_b: np.ndarray, tolerance: float = TOUCH_TOLERANCE) -> Vector | None:
    inside = np.all((verts_b >= aabb_a["min"] - tolerance) & (verts_b <= aabb_a["max"] + tolerance), axis=1)

    midpoints = []

    for co in verts_b[inside]:
        location = tree_a.find_nearest(co, tolerance)[0]

        if location is not None:
            # Halfway across the gap between B's vertex and the closest point on A
            midpoints.append((Vector(co) + location) / 2)

    if not midpoints:
        return None

    return sum(midpoints, Vector()) / len(midpoints)


def remove_constraints_between(pieces: list[bpy.types.Object]) -> None:
    rigidbody_world = bpy.context.scene.rigidbody_world

    if rigidbody_world is None or rigidbody_world.constraints is None:
        return

    names = {piece.name for piece in pieces}

    stale = [
        empty for empty in rigidbody_world.constraints.objects
        if (rbc := empty.rigid_body_constraint) is not None
        and rbc.object1 is not None and rbc.object2 is not None
        and rbc.object1.name in names and rbc.object2.name in names
    ]

    # One batch removal is much faster than removing empties one by one
    bpy.data.batch_remove(stale)


def connect_touching_pieces(pieces: list[bpy.types.Object], break_threshold: float = 0.1, disable_collisions: bool = False, use_breaking: bool = True) -> None:
    # Rebuild from scratch so every constraint picks up the current settings
    remove_constraints_between(pieces)

    piece_verts = {piece: get_world_verts(piece) for piece in pieces}
    piece_aabbs = {piece: get_world_aabb(piece_verts[piece]) for piece in pieces}
    piece_bvh_trees = {piece: get_bvh(piece, piece_verts[piece]) for piece in pieces}

    # Test every pair of bounding boxes at once, then only run the slower BVH check on overlapping ones
    mins = np.array([piece_aabbs[p]["min"] for p in pieces])
    maxs = np.array([piece_aabbs[p]["max"] for p in pieces])

    overlap = np.all(
        (mins[:, None] - TOUCH_TOLERANCE <= maxs[None, :]) & (mins[None, :] - TOUCH_TOLERANCE <= maxs[:, None]),
        axis=2,
    )
    rows, cols = np.nonzero(np.triu(overlap, k=1))  # k=1: each pair once, no piece with itself

    touching_pairs = [
        (pieces[i], pieces[j], point)
        for i, j in zip(rows.tolist(), cols.tolist())
        if (point := contact_point(piece_bvh_trees[pieces[i]], piece_aabbs[pieces[i]], piece_verts[pieces[j]])) is not None
    ]

    add_constraints(touching_pairs, type="FIXED", break_threshold=break_threshold, disable_collisions=disable_collisions, use_breaking=use_breaking)


def add_rigid_bodies(pieces: list[bpy.types.Object], friction: float = 0.5, bounciness: float = 0, disable_collisions: bool = False, collision_margin: float = 0.04, connect_touching_pieces: bool = True, body_mass: float = 1, collision_shape: str = "CONVEX_HULL", use_breaking=True) -> None:
    bpy.ops.object.select_all(action='DESELECT')

    for cell in pieces:
        cell.select_set(True)

    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.rigidbody.objects_add(type="ACTIVE")

    for cell in pieces:
        cell.rigid_body.friction = friction
        cell.rigid_body.restitution = bounciness
        cell.rigid_body.kinematic = False
        cell.rigid_body.collision_shape = collision_shape
        cell.rigid_body.mass = body_mass
        cell.rigid_body.collision_margin = collision_margin



def apply_rigid_bodies_to_selected(friction: float = 0.5, bounciness: float = 0, break_threshold: float = 0.1, disable_collisions: bool = False, collision_margin: float = 0.04, connect_touching: bool = True, body_mass: float = 1, collision_shape: str = "CONVEX_HULL", use_breaking=True) -> list[bpy.types.Object]:
    selected = [mesh for mesh in bpy.context.selected_objects if mesh.type == "MESH"]

    if not selected:
        return selected

    add_rigid_bodies(selected, friction, bounciness, disable_collisions, collision_margin, connect_touching, body_mass, collision_shape, use_breaking)

    settings = bpy.context.scene.kinetic_forge

    if settings.connect_touching:
        connect_touching_pieces(selected, break_threshold=break_threshold, disable_collisions=disable_collisions, use_breaking=use_breaking)
    else:
        remove_constraints_between(selected)   

    return selected


def add_constraints(pairs: list[tuple[bpy.types.Object, bpy.types.Object, Vector]], type: ConstraintType = "FIXED", break_threshold: float = 0.1, disable_collisions: bool = False, use_breaking: bool = True) -> list[bpy.types.Object]:
    # Linking empties straight into the rigid body world's constraint collection makes
    # Blender create their constraints in one update, instead of one slow operator call each
    rigidbody_world = bpy.context.scene.rigidbody_world

    if rigidbody_world.constraints is None:
        rigidbody_world.constraints = bpy.data.collections.new("RigidBodyConstraints")

    empties = []

    # users_collection searches every collection on each access, so look it up once per piece
    collection_of: dict[bpy.types.Object, bpy.types.Collection] = {}

    for cell, other_cell, point in pairs:
        if cell not in collection_of:
            collection_of[cell] = cell.users_collection[0]

        empty = bpy.data.objects.new("Empty", None)
        empty.location = point
        collection_of[cell].objects.link(empty)
        rigidbody_world.constraints.objects.link(empty)
        empties.append(empty)

    bpy.context.view_layer.update()

    for empty, (cell, other_cell, point) in zip(empties, pairs):
        rbc = empty.rigid_body_constraint
        rbc.type = type
        rbc.object1 = cell
        rbc.object2 = other_cell
        rbc.disable_collisions = disable_collisions
        rbc.use_breaking = use_breaking
        rbc.breaking_threshold = break_threshold

    return empties


def add_constraint(cell: bpy.types.Object, other_cell: bpy.types.Object, type: ConstraintType = "FIXED", break_threshold: float = 0.1) -> bpy.types.Object:
    return add_constraints([(cell, other_cell)], type, break_threshold)[0]
