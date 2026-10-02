from typing import Literal

import bmesh
import bpy
from mathutils import bvhtree


TOUCH_TOLERANCE = 0.01

ConstraintType = Literal[
    "FIXED", "POINT", "HINGE", "SLIDER", "PISTON", "GENERIC", "GENERIC_SPRING", "MOTOR"
]


def get_bvh(obj: bpy.types.Object) -> bvhtree.BVHTree:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    bvh = bvhtree.BVHTree.FromBMesh(bm)
    bm.free()
    return bvh


def pieces_touch(tree_a: bvhtree.BVHTree, piece_b: bpy.types.Object, tolerance: float = TOUCH_TOLERANCE) -> bool:
    # Pieces are separated by the fracture margin, so check distance instead of overlap
    for v in piece_b.data.vertices:
        location, normal, index, distance = tree_a.find_nearest(piece_b.matrix_world @ v.co, tolerance)

        if location is not None:
            return True

    return False


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


def connect_touching_pieces(pieces: list[bpy.types.Object], break_threshold: float = 0.1) -> None:
    # Rebuild from scratch so every constraint picks up the current settings
    remove_constraints_between(pieces)

    piece_bvh_trees = {piece: get_bvh(piece) for piece in pieces}

    touching_pairs = [
        (piece, other_piece)
        for i, piece in enumerate(pieces)
        for other_piece in pieces[i + 1:]
        if pieces_touch(piece_bvh_trees[piece], other_piece)
    ]

    add_constraints(touching_pairs, type="FIXED", break_threshold=break_threshold)


def add_rigid_bodies(pieces: list[bpy.types.Object], friction: float = 0.5, bounciness: float = 0) -> None:
    bpy.ops.object.select_all(action='DESELECT')

    for cell in pieces:
        cell.select_set(True)

    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.rigidbody.objects_add(type="ACTIVE")

    for cell in pieces:
        cell.rigid_body.friction = friction
        cell.rigid_body.restitution = bounciness
        cell.rigid_body.kinematic = False


def apply_rigid_bodies_to_selected(friction: float = 0.5, bounciness: float = 0, break_threshold: float = 0.1) -> list[bpy.types.Object]:
    selected = [mesh for mesh in bpy.context.selected_objects if mesh.type == "MESH"]

    if not selected:
        return selected

    add_rigid_bodies(selected, friction, bounciness)

    connect_touching_pieces(selected, break_threshold=break_threshold)
    return selected


def add_constraints(pairs: list[tuple[bpy.types.Object, bpy.types.Object]], type: ConstraintType = "FIXED", break_threshold: float = 0.1) -> list[bpy.types.Object]:
    # Linking empties straight into the rigid body world's constraint collection makes
    # Blender create their constraints in one update, instead of one slow operator call each
    rigidbody_world = bpy.context.scene.rigidbody_world

    if rigidbody_world.constraints is None:
        rigidbody_world.constraints = bpy.data.collections.new("RigidBodyConstraints")

    empties = []

    for cell, other_cell in pairs:
        empty = bpy.data.objects.new("Empty", None)
        cell.users_collection[0].objects.link(empty)
        rigidbody_world.constraints.objects.link(empty)
        empties.append(empty)

    bpy.context.view_layer.update()

    for empty, (cell, other_cell) in zip(empties, pairs):
        rbc = empty.rigid_body_constraint
        rbc.type = type
        rbc.object1 = cell
        rbc.object2 = other_cell
        rbc.disable_collisions = False
        rbc.use_breaking = True
        rbc.breaking_threshold = break_threshold

    return empties


def add_constraint(cell: bpy.types.Object, other_cell: bpy.types.Object, type: ConstraintType = "FIXED", break_threshold: float = 0.1) -> bpy.types.Object:
    return add_constraints([(cell, other_cell)], type, break_threshold)[0]
