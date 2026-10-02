import random

import bpy
from mathutils import Vector, bvhtree

SAMPLE_ITER_FAIL_LIMIT = 1000


def world_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    ws = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    bb_min = Vector(map(min, zip(*ws)))
    bb_max = Vector(map(max, zip(*ws)))
    return bb_min, bb_max


def sample_seeds(obj: bpy.types.Object, seed_count: int, bb_min: Vector, bb_max: Vector) -> list[Vector]:
    seeds = []
    sample_iterations = 0

    world_to_local = obj.matrix_world.inverted()
    deps_graph = bpy.context.evaluated_depsgraph_get()
    sample_tree = bvhtree.BVHTree.FromObject(obj, deps_graph)

    while len(seeds) < seed_count and sample_iterations < SAMPLE_ITER_FAIL_LIMIT:
        sample = Vector((
            random.uniform(bb_min[0], bb_max[0]),
            random.uniform(bb_min[1], bb_max[1]),
            random.uniform(bb_min[2], bb_max[2])
        ))

        local = world_to_local @ sample

        location, normal, index, distance = sample_tree.find_nearest(local)

        if location is not None and (local - location).dot(normal) < 0:
            seeds.append(sample)
            sample_iterations = 0
        else:
            sample_iterations += 1

    return seeds


def create_seed_object(seeds: list[Vector], obj: bpy.types.Object) -> bpy.types.Object:
    me = bpy.data.meshes.new("Seeds")
    me.from_pydata(seeds, [], [])

    seed_obj = bpy.data.objects.new("Seeds", me)
    obj.users_collection[0].objects.link(seed_obj)

    # Parent without moving, so the seed verts stay in world space
    seed_obj.parent = obj
    seed_obj.matrix_parent_inverse = obj.matrix_world.inverted()
    return seed_obj
