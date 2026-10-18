import random
from typing import Literal, NamedTuple, TypedDict

import bpy
import numpy as np
from mathutils import bvhtree, Matrix, Vector


TOUCH_TOLERANCE = 0.01

ConstraintType = Literal[
    "FIXED", "POINT", "HINGE", "SLIDER", "PISTON", "GENERIC", "GENERIC_SPRING", "MOTOR"
]

class AABB(TypedDict):
    min: np.ndarray
    max: np.ndarray


class Contact(NamedTuple):
    point: Vector
    normal: Vector     # points from piece A toward piece B
    long_axis: Vector  # longest direction of the shared face, perpendicular to normal


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


def find_contact(tree_a: bvhtree.BVHTree, aabb_a: AABB, verts_b: np.ndarray, tolerance: float = TOUCH_TOLERANCE) -> Contact | None:
    inside = np.all((verts_b >= aabb_a["min"] - tolerance) & (verts_b <= aabb_a["max"] + tolerance), axis=1)

    midpoints = []
    normal_sum = Vector()

    for co in verts_b[inside]:
        location, normal, _index, _distance = tree_a.find_nearest(co, tolerance)

        if location is not None:
            # Halfway across the gap between B's vertex and the closest point on A
            midpoints.append((Vector(co) + location) / 2)
            normal_sum += normal

    if not midpoints:
        return None

    point = sum(midpoints, Vector()) / len(midpoints)

    # The contact sits on A's surface, so the direction out from A's center points toward B
    center_a = Vector((aabb_a["min"] + aabb_a["max"]) / 2)
    toward_b = point - center_a

    # Only used when the contact points don't define a plane. Opposing hit normals
    # (e.g. pieces meeting only at a corner) can cancel out, hence the further fallbacks
    fallback_normal = next(
        (v.normalized() for v in (normal_sum, toward_b) if v.length > 1e-6),
        Vector((0, 0, 1)),
    )

    normal, long_axis = contact_axes(midpoints, point, fallback_normal)

    if normal.dot(toward_b) < 0:
        normal = -normal

    return Contact(point, normal, long_axis)


def contact_axes(midpoints: list[Vector], center: Vector, fallback_normal: Vector) -> tuple[Vector, Vector]:
    # Returns (normal, long_axis). Contact points are the shared face's corners, where
    # find_nearest can report a side face's normal, so fit the face's plane to the points instead
    if len(midpoints) >= 3:
        offsets = np.array(midpoints) - np.array(center)
        values, vectors = np.linalg.eigh(offsets.T @ offsets)  # ascending: least spread first

        # The least-spread direction is the face's normal, the most-spread is its long axis.
        # Points along a single line (middle value ~0) don't define a plane, though
        if values[1] > 1e-6 * values[2]:
            return Vector(vectors[:, 0]).normalized(), Vector(vectors[:, 2]).normalized()

        long_axis = Vector(vectors[:, 2])
    elif len(midpoints) == 2:
        long_axis = midpoints[1] - midpoints[0]
    else:
        long_axis = fallback_normal.orthogonal()

    # Remove any part along the normal so the two axes are exactly perpendicular
    long_axis -= fallback_normal * long_axis.dot(fallback_normal)

    if long_axis.length < 1e-6:
        long_axis = fallback_normal.orthogonal()

    return fallback_normal, long_axis.normalized()


def constraint_rotation(type: ConstraintType, normal: Vector, long_axis: Vector) -> Matrix:
    match type:
        case "HINGE":
            # Rotates around local Z, so Z runs along the shared face
            x, y, z = normal, long_axis.cross(normal), long_axis
        case "SLIDER":
            # Slides along local X, so X runs along the shared face
            x, y, z = long_axis, normal, long_axis.cross(normal)
        case "PISTON" | "GENERIC" | "GENERIC_SPRING":
            # X pulls the pieces apart; Y and Z slide them along the face
            x, y, z = normal, long_axis, normal.cross(long_axis)
        case _:
            # Fixed and Point don't use the orientation
            return Matrix.Identity(3)

    # Matrix() takes rows, but each axis has to be a column
    return Matrix((x, y, z)).transposed()


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


def connect_touching_pieces(pieces: list[bpy.types.Object], break_threshold: float = 0.1, disable_collisions: bool = False, use_breaking: bool = True, constraint_type: ConstraintType = "FIXED", break_randomness: float = 0, break_seed: int = 0) -> None:
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
        (pieces[i], pieces[j], contact)
        for i, j in zip(rows.tolist(), cols.tolist())
        if (contact := find_contact(piece_bvh_trees[pieces[i]], piece_aabbs[pieces[i]], piece_verts[pieces[j]])) is not None
    ]

    add_constraints(touching_pairs, type=constraint_type, break_threshold=break_threshold, disable_collisions=disable_collisions, use_breaking=use_breaking, break_randomness=break_randomness, break_seed=break_seed)


def add_rigid_bodies(pieces: list[bpy.types.Object], friction: float = 0.5, bounciness: float = 0, disable_collisions: bool = False, collision_margin: float = 0.04, connect_touching_pieces: bool = True, body_mass: float = 1, collision_shape: str = "CONVEX_HULL", use_breaking=True, body_type: str = "ACTIVE") -> None:
    bpy.ops.object.select_all(action='DESELECT')

    for cell in pieces:
        cell.select_set(True)

    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.rigidbody.objects_add(type=body_type)

    for cell in pieces:
        # objects_add skips pieces that already have a rigid body, so set the type on those too
        cell.rigid_body.type = body_type
        cell.rigid_body.friction = friction
        cell.rigid_body.restitution = bounciness
        cell.rigid_body.kinematic = False
        cell.rigid_body.collision_shape = collision_shape
        cell.rigid_body.mass = body_mass
        cell.rigid_body.use_margin = collision_margin > 0
        cell.rigid_body.collision_margin = collision_margin




def apply_rigid_bodies_to_selected(friction: float = 0.5, bounciness: float = 0, break_threshold: float = 0.1, disable_collisions: bool = False, collision_margin: float = 0.04, connect_touching: bool = True, body_mass: float = 1, collision_shape: str = "CONVEX_HULL", use_breaking=True, constraint_type: ConstraintType = "FIXED", break_randomness: float = 0, break_seed: int = 0, body_type: str = "ACTIVE") -> list[bpy.types.Object]:
    selected = [mesh for mesh in bpy.context.selected_objects if mesh.type == "MESH"]

    if not selected:
        return selected

    add_rigid_bodies(selected, friction, bounciness, disable_collisions, collision_margin, connect_touching, body_mass, collision_shape, use_breaking, body_type=body_type)

    settings = bpy.context.scene.kinetic_forge

    if settings.connect_touching:
        connect_touching_pieces(selected, break_threshold=break_threshold, disable_collisions=disable_collisions, use_breaking=use_breaking, constraint_type=constraint_type, break_randomness=break_randomness, break_seed=break_seed)
    else:
        remove_constraints_between(selected)   

    return selected


def add_constraints(pairs: list[tuple[bpy.types.Object, bpy.types.Object, Contact]], type: ConstraintType = "FIXED", break_threshold: float = 0.1, disable_collisions: bool = False, use_breaking: bool = True, break_randomness: float = 0, break_seed: int = 0) -> list[bpy.types.Object]:
    # Linking empties straight into the rigid body world's constraint collection makes
    # Blender create their constraints in one update, instead of one slow operator call each
    rigidbody_world = bpy.context.scene.rigidbody_world

    if rigidbody_world.constraints is None:
        rigidbody_world.constraints = bpy.data.collections.new("RigidBodyConstraints")

    empties = []

    # users_collection searches every collection on each access, so look it up once per piece
    collection_of: dict[bpy.types.Object, bpy.types.Collection] = {}

    for cell, other_cell, contact in pairs:
        if cell not in collection_of:
            collection_of[cell] = cell.users_collection[0]

        empty = bpy.data.objects.new("Empty", None)
        empty.location = contact.point
        empty.rotation_euler = constraint_rotation(type, contact.normal, contact.long_axis).to_euler()
        collection_of[cell].objects.link(empty)
        rigidbody_world.constraints.objects.link(empty)
        empties.append(empty)

    bpy.context.view_layer.update()

    # Seeded, so applying again with the same settings gives the same breaks
    rng = random.Random(break_seed)

    for empty, (cell, other_cell, _contact) in zip(empties, pairs):
        rbc = empty.rigid_body_constraint
        rbc.type = type
        rbc.object1 = cell
        rbc.object2 = other_cell
        rbc.disable_collisions = disable_collisions
        rbc.use_breaking = use_breaking
        # Scale rather than offset, so the variation stays proportional to the threshold
        rbc.breaking_threshold = break_threshold * (1 + rng.uniform(-break_randomness, break_randomness))

    return empties


def add_constraint(cell: bpy.types.Object, other_cell: bpy.types.Object, contact: Contact, type: ConstraintType = "FIXED", break_threshold: float = 0.1) -> bpy.types.Object:
    return add_constraints([(cell, other_cell, contact)], type, break_threshold)[0]
