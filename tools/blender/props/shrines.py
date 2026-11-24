"""Fire and treasure: the Hearth of Hestia (respawn shrine: a round altar with a bronze
bowl; Godot adds the flame), a bronze tripod brazier, a loot chest whose lid is its
own mesh ("Lid", hinged at the back), the forge pit at the heart of the bull's arena,
and the shards a smashed pot leaves.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def export(slug):
    out = kit.export_glb(kit.model_path("props", slug))
    kit.report("asset", slug, out)


def hearth(slug="hearth_of_hestia"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.lathe([(1.3, 0.0), (1.3, 0.25), (1.1, 0.3)], "limestone", segments=18)
    m.lathe([(0.95, 0.3), (0.9, 0.95), (1.0, 1.05), (0.75, 1.1)], "marble", segments=18,
            pattern=lambda band, k: "terracotta_dark" if band == 1 and k % 3 == 0 else None)
    m.lathe([(0.75, 1.1), (0.85, 1.35), (0.6, 1.3), (0.2, 1.15)], "bronze", segments=18)
    for i in range(8):
        a = math.tau * i / 8
        m.box((math.cos(a) * 0.5, math.sin(a) * 0.5, 1.2), (0.25, 0.12, 0.1), "ash", rotation=(0, 0, math.degrees(a)))
    m.sphere((0, 0, 1.18), 0.32, "furnace", scale=(1, 1, 0.35), segments=10, rings=5)
    for i in range(4):
        a = math.tau * i / 4 + 0.4
        m.box((math.cos(a) * 1.55, math.sin(a) * 1.55, 0.1), (0.6, 0.4, 0.2), "limestone", rotation=(0, 0, math.degrees(a)))
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 1.3), 1.15, segments=12)
    export(slug)


def brazier(slug="brazier"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    for i in range(3):
        a = math.tau * i / 3
        m.cylinder((math.cos(a) * 0.45, math.sin(a) * 0.45, 0), (math.cos(a) * 0.2, math.sin(a) * 0.2, 1.2), 0.035, 0.03, "bronze_dark", segments=5)
        m.sphere((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.04), 0.06, "bronze", segments=6, rings=4)
    m.lathe([(0.12, 1.1), (0.4, 1.25), (0.48, 1.42), (0.42, 1.42)], "bronze", segments=12)
    m.sphere((0, 0, 1.38), 0.36, "furnace", scale=(1, 1, 0.25), segments=10, rings=4)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 1.4), 0.45, segments=8)
    export(slug)


def chest(slug="chest"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.box((0, 0, 0.32), (1.2, 0.75, 0.64), "wood", bevel=0.02)
    for x in (-0.45, 0.45):
        m.box((x, 0, 0.32), (0.08, 0.78, 0.66), "bronze")
    m.box((0, -0.39, 0.5), (0.16, 0.04, 0.18), "gold")
    m.finish()
    lid = kit.Mesh("Lid")
    # Modelled hinged at the back edge (local origin), so rotating X opens it.
    lid.box((0, -0.375, 0.1), (1.24, 0.79, 0.2), "wood_dark", bevel=0.02)
    for x in (-0.45, 0.45):
        lid.box((x, -0.375, 0.1), (0.08, 0.82, 0.22), "bronze")
    obj = lid.finish()
    obj.location = (0, 0.375, 0.64)
    kit.collision_box(slug, (0, 0, 0.4), (1.2, 0.75, 0.8))
    export(slug)


def forge_pit(slug="forge_pit"):
    """The heart of the bull's arena: a ring of basalt around a grate over embers."""
    kit.clear_scene()
    rng = random.Random(2)
    m = kit.Mesh(slug)
    m.lathe([(3.2, 0.0), (3.2, 0.35), (2.7, 0.4), (2.6, 0.1)], "basalt", segments=24)
    m.cylinder((0, 0, 0.02), (0, 0, 0.06), 2.65, 2.65, "furnace", segments=24)
    for i in range(-5, 6):
        m.box((i * 0.46, 0, 0.12), (0.1, 5.0 * math.sqrt(max(0.0, 1 - (i * 0.46 / 2.6) ** 2)), 0.08), "iron")
    for i in range(10):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.4, 2.2)
        m.ico((math.cos(a) * r, math.sin(a) * r, 0.08), rng.uniform(0.1, 0.22), "fire_glow" if i % 2 else "ash", subdivisions=0)
    for i in range(8):
        a = math.tau * i / 8
        m.box((math.cos(a) * 3.0, math.sin(a) * 3.0, 0.5), (0.5, 0.5, 0.3), "bronze_dark", rotation=(0, 0, math.degrees(a)))
    m.finish()
    export(slug)


def shards(slug="shards"):
    """Pieces of a smashed pot (several meshes: Shard0..Shard5) for Godot to scatter."""
    kit.clear_scene()
    rng = random.Random(4)
    for i in range(6):
        s = kit.Mesh(f"Shard{i}")
        a0 = rng.uniform(0, math.tau)
        a1 = a0 + rng.uniform(0.6, 1.1)
        z0, z1 = rng.uniform(0.0, 0.4), rng.uniform(0.5, 0.9)
        pts = []
        for a, z in ((a0, z0), (a1, z0), (a1, z1), (a0, z1)):
            pts.append((math.cos(a) * 0.22, math.sin(a) * 0.22, z))
        s.polygon(pts, "clay" if i % 2 else "black_glaze", double=True)
        s.finish()
    export(slug)


def main():
    hearth()
    brazier()
    chest()
    forge_pit()
    shards()


kit.run(main)
