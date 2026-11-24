"""Stone of the old sanctuary and the necropolis: Doric columns (whole, broken,
fallen), a temple ruin with faded polychrome, the three Moirai on their plinths
(Atropos' hands are empty), grave stelae, a sarcophagus, a beehive tholos tomb and
the sanctuary gate (its two bronze doors are separate meshes so they can swing).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402

FLUTES = 16


def export(slug):
    out = kit.export_glb(kit.model_path("props", slug))
    kit.report("asset", slug, out)


def fluted(band, k):
    return "marble_shadow" if k % 2 else None


def shaft(m, z0, z1, r0, r1, broken=False, rng=None):
    m.lathe([(r0, z0), (r1, z1)], "marble", segments=FLUTES, caps=not broken, pattern=fluted)
    if broken and rng:
        # A jagged top: a few marble shards sticking up.
        for i in range(5):
            a = math.tau * i / 5 + rng.uniform(-0.3, 0.3)
            h = rng.uniform(0.1, 0.45)
            m.cone((math.cos(a) * r1 * 0.5, math.sin(a) * r1 * 0.5, z1 - 0.05), (math.cos(a) * r1 * 0.45, math.sin(a) * r1 * 0.45, z1 + h),
                   r1 * 0.45, "marble", segments=4)
        m.cylinder((0, 0, z1 - 0.02), (0, 0, z1), r1 * 0.98, r1 * 0.98, "marble_shadow", segments=FLUTES)


def capital(m, z, r):
    m.lathe([(r * 1.02, z), (r * 1.35, z + 0.22), (r * 1.4, z + 0.3)], "marble", segments=FLUTES)
    m.box((0, 0, z + 0.4), (r * 2.9, r * 2.9, 0.2), "marble")
    m.box((0, 0, z + 0.3), (r * 2.82, r * 2.82, 0.02), "gold")


def column(slug, height=6.0, broken_at=None, seed=1):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    r = 0.5
    top = broken_at if broken_at else height - 0.5
    shaft(m, 0.0, top, r, r - 0.08 * top / height, broken=broken_at is not None, rng=rng)
    if not broken_at:
        capital(m, top, r - 0.08)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, min(top, 3.0)), r * 1.05, segments=10)
    export(slug)


def column_fallen(slug="column_fallen", seed=4):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    x = -2.4
    for i in range(4):
        with m.at(location=(x, rng.uniform(-0.15, 0.15), 0.47), rotation=(0, 90, rng.uniform(-12, 12))):
            m.lathe([(0.47, -0.55), (0.47, 0.55)], "marble", segments=FLUTES, pattern=fluted)
        x += 1.25 + rng.uniform(0.0, 0.25)
    with m.at(location=(x + 0.4, 0.4, 0.2), rotation=(0, 0, 20)):
        m.box((0, 0, 0), (1.3, 1.3, 0.4), "marble")
    m.finish()
    kit.collision_box(slug, (0.3, 0, 0.45), (5.8, 1.2, 0.9))
    export(slug)


def temple_ruin(slug="temple_ruin", seed=7):
    """Three steps, a row of columns (two broken), a stretch of architrave with a
    triglyph frieze still showing red and blue paint."""
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    w, d = 14.0, 8.0
    for i in range(3):
        m.box((0, 0, 0.2 + i * 0.4), (w + 1.6 - i * 0.8, d + 1.6 - i * 0.8, 0.4), "limestone" if i % 2 else "marble")
    base = 1.2
    xs = [-6.0, -3.6, -1.2, 1.2, 3.6, 6.0]
    for j, y in enumerate((-d / 2 + 0.8, d / 2 - 0.8)):
        for i, x in enumerate(xs):
            broken = (i, j) in ((1, 0), (4, 1), (5, 0))
            with m.at(location=(x, y, base)):
                if broken:
                    shaft(m, 0.0, rng.uniform(1.2, 3.0), 0.5, 0.46, broken=True, rng=rng)
                else:
                    shaft(m, 0.0, 5.0, 0.5, 0.43)
                    capital(m, 5.0, 0.43)
    # Architrave and frieze over the standing front columns (x -6..-1.2) and back.
    for y in (-d / 2 + 0.8, d / 2 - 0.8):
        m.box((-3.6, y, base + 5.65), (6.0, 1.1, 0.55), "marble")
        for i in range(9):
            x = -6.3 + i * 0.68
            m.box((x, y - 0.56 * (1 if y < 0 else -1), base + 6.22), (0.3, 0.06, 0.6), "wool_indigo" if i % 2 == 0 else "marble_shadow")
            m.box((x + 0.34, y - 0.56 * (1 if y < 0 else -1), base + 6.22), (0.36, 0.05, 0.6), "terracotta_dark" if i % 3 == 0 else "marble")
        m.box((-3.6, y, base + 6.6), (6.2, 1.2, 0.18), "marble")
    for i in range(6):
        m.box((rng.uniform(-5, 6), rng.uniform(-3, 3), base + 0.25), (rng.uniform(0.5, 1.2), rng.uniform(0.4, 0.9), 0.5), "marble",
              rotation=(rng.uniform(-8, 8), rng.uniform(-8, 8), rng.uniform(0, 90)))
    m.finish()
    kit.collision_box(slug + "_steps", (0, 0, 0.6), (w + 1.6, d + 1.6, 1.2))
    for j, y in enumerate((-d / 2 + 0.8, d / 2 - 0.8)):
        for i, x in enumerate(xs):
            kit.collision_cylinder(f"{slug}_col_{i}_{j}", (x, y, base), (x, y, base + 2.5), 0.55, segments=8)
    export(slug)


def moira(slug, holding, seed):
    """A robed Fate on a plinth: Klotho with a spindle, Lachesis with a measuring
    rod, Atropos with empty hands where the shears were."""
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.box((0, 0, 0.5), (1.5, 1.5, 1.0), "limestone")
    m.box((0, 0, 1.05), (1.35, 1.35, 0.1), "marble")
    z = 1.1
    m.lathe([(0.48, z), (0.52, z + 0.2), (0.42, z + 1.2), (0.36, z + 1.9), (0.3, z + 2.15), (0.16, z + 2.3)], "marble", segments=14,
            pattern=lambda band, k: "marble_shadow" if k % 3 == 0 else None)
    m.sphere((0, -0.02, z + 2.5), 0.2, "marble", scale=(0.9, 1.0, 1.1), segments=10, rings=7)
    m.sphere((0, 0.06, z + 2.55), 0.22, "marble_shadow", scale=(1.0, 1.0, 0.95), segments=10, rings=6)
    for side in (-1, 1):
        m.cylinder((side * 0.32, 0, z + 2.05), (side * 0.3, -0.32, z + 1.5), 0.08, 0.07, "marble", segments=6)
    hand = (0.0, -0.42, z + 1.45)
    m.sphere(hand, 0.09, "marble", segments=6, rings=4)
    if holding == "spindle":
        m.cylinder((0, -0.45, z + 1.1), (0, -0.45, z + 1.9), 0.02, 0.02, "gold", segments=5)
        m.sphere((0, -0.45, z + 1.25), 0.07, "gold", segments=8, rings=5)
        m.tube([(0, -0.45, z + 1.85), (0.3, -0.5, z + 1.6), (0.5, -0.5, z + 0.9), (0.55, -0.4, z + 0.1)], 0.01, "ichor_glow", segments=3)
    elif holding == "rod":
        m.cylinder((-0.35, -0.45, z + 0.2), (0.3, -0.45, z + 2.0), 0.025, 0.025, "gold", segments=5)
    else:
        # The shears are gone; only their gilded mark remains on her open palms.
        m.sphere((0.12, -0.44, z + 1.48), 0.05, "gold", segments=6, rings=4)
    m.finish()
    kit.collision_box(slug, (0, 0, 1.6), (1.5, 1.5, 3.2))
    export(slug)


def stele(slug, seed, tall=1.9):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    m.box((0, 0, 0.15), (1.0, 0.5, 0.3), "rubble")
    with m.at(rotation=(rng.uniform(-6, 6), rng.uniform(-6, 6), 0)):
        m.box((0, 0, 0.3 + tall / 2), (0.75, 0.16, tall), "marble")
        with m.at(location=(0, 0.09, 0.3 + tall), rotation=(90, 0, 0)):
            m.extrude([(-0.42, 0.0), (0.42, 0.0), (0.0, 0.26)], 0.18, "marble_shadow")
        # The dead in relief: a seated figure and a standing one, in dark paint.
        m.box((-0.15, -0.085, 0.3 + tall * 0.45), (0.18, 0.02, 0.55), "stone_dark")
        m.sphere((-0.15, -0.09, 0.3 + tall * 0.66), 0.07, "stone_dark", scale=(1, 0.3, 1), segments=6, rings=4)
        m.box((0.16, -0.085, 0.3 + tall * 0.38), (0.16, 0.02, 0.62), "stone_dark")
        m.sphere((0.16, -0.09, 0.3 + tall * 0.6), 0.065, "stone_dark", scale=(1, 0.3, 1), segments=6, rings=4)
    m.finish()
    kit.collision_box(slug, (0, 0, 0.8), (0.9, 0.5, 1.6))
    export(slug)


def sarcophagus(slug="sarcophagus"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.box((0, 0, 0.5), (2.3, 1.1, 1.0), "limestone", bevel=0.03)
    m.box((0, 0, 0.75), (2.34, 1.14, 0.16), "stone_dark")
    for i in range(6):
        m.sphere((-0.95 + i * 0.38, -0.57, 0.75), 0.07, "verdigris", segments=6, rings=4)
    with m.at(location=(0.1, 0.05, 1.0), rotation=(0, -4, 6)):
        m.box((0, 0, 0.12), (2.4, 1.2, 0.24), "marble")
        with m.at(location=(-1.15, 0, 0.24), rotation=(90, 0, 90)):
            m.extrude([(-0.6, 0.0), (0.6, 0.0), (0.0, 0.25)], 2.3, "marble_shadow")
    m.finish()
    kit.collision_box(slug, (0, 0, 0.6), (2.4, 1.2, 1.2))
    export(slug)


def tholos(slug="tholos"):
    """A beehive tomb: an earth mound over a corbelled dome, a stone doorway at the
    end of a walled passage (dromos). Teal light leaks from the door."""
    kit.clear_scene()
    rng = random.Random(9)
    m = kit.Mesh(slug)
    m.lathe([(6.5, 0.0), (6.0, 1.5), (5.0, 3.2), (3.4, 4.6), (1.6, 5.4), (0.0, 5.6)], "grass_dry", segments=18,
            pattern=lambda band, k: "grass_green" if (band + k) % 4 == 0 else None)
    for i in range(10):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(2.0, 5.5)
        m.rock((math.cos(a) * r, math.sin(a) * r, 5.6 - r * 0.8), rng.uniform(0.3, 0.6), "limestone", rng)
    # The doorway facing -Y: jambs, a huge lintel, the relieving triangle above.
    y = -5.6
    for x in (-1.0, 1.0):
        m.box((x, y, 1.6), (0.6, 1.4, 3.2), "limestone")
    m.box((0, y, 3.45), (3.0, 1.5, 0.6), "marble")
    with m.at(location=(0, y - 0.72, 3.75), rotation=(90, 0, 0)):
        m.extrude([(-1.0, 0.0), (1.0, 0.0), (0.0, 1.3)], 0.2, "black_glaze")
    m.box((0, y + 0.3, 1.5), (1.4, 0.4, 3.0), "eye_dark")
    m.box((0, y + 0.45, 1.5), (1.2, 0.2, 2.8), "styx_glow")
    # The dromos walls.
    for x in (-2.2, 2.2):
        for k in range(4):
            m.box((x, y - 1.2 - k * 1.3, 1.0 - k * 0.15), (0.8, 1.25, 2.0 - k * 0.3), "rubble" if k % 2 else "limestone")
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 4.0), 6.2, segments=14)
    for x in (-2.2, 2.2):
        kit.collision_box(f"{slug}_dromos_{x}", (x, y - 3.0, 0.8), (0.8, 5.2, 1.6))
    export(slug)


def gate(slug="sanctuary_gate"):
    """Two pylons and a lintel; the doors are separate meshes (DoorLeft, DoorRight)
    hinged at their outer edges so Godot can swing them open."""
    kit.clear_scene()
    m = kit.Mesh(slug)
    for x in (-3.2, 3.2):
        m.box((x, 0, 2.6), (1.6, 1.8, 5.2), "limestone")
        m.box((x, 0, 5.3), (1.8, 2.0, 0.2), "marble")
        m.box((x, -0.92, 2.6), (1.0, 0.05, 3.4), "marble_shadow")
    m.box((0, 0, 5.75), (8.4, 2.0, 0.7), "marble")
    m.box((0, -1.01, 5.75), (8.2, 0.04, 0.3), "wool_indigo")
    for i in range(12):
        m.box((-3.85 + i * 0.7, -1.02, 5.75), (0.12, 0.05, 0.3), "gold")
    with m.at(location=(0, -1.0, 6.4), rotation=(90, 0, 0)):
        m.extrude([(-4.3, 0.0), (4.3, 0.0), (0.0, 1.3)], 2.0, "marble_shadow")
    # The spindle sign of the Moirai over the gate.
    m.torus((0, -1.07, 6.75), 0.35, 0.05, "gold", segments=16, sides=4, rotation=(90, 0, 0))
    m.finish()
    for name, hinge in (("DoorLeft", -2.4), ("DoorRight", 2.4)):
        d = kit.Mesh(name)
        side = 1 if hinge < 0 else -1
        d.box((side * 1.2, 0, 2.3), (2.36, 0.22, 4.6), "bronze")
        for z in (0.9, 2.3, 3.7):
            d.box((side * 1.2, -0.12, z), (2.2, 0.04, 0.12), "bronze_dark")
        for z in (1.6, 3.0):
            for k in range(3):
                d.sphere((side * (0.45 + k * 0.7), -0.13, z), 0.06, "gold", segments=6, rings=4)
        d.box((side * 2.15, -0.14, 2.3), (0.12, 0.05, 0.4), "gold")
        obj = d.finish()
        obj.location = (hinge, 0, 0)
    for x in (-3.2, 3.2):
        kit.collision_box(f"{slug}_pylon_{x}", (x, 0, 2.6), (1.6, 1.8, 5.2))
    export(slug)


def altar(slug="altar"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.box((0, 0, 0.1), (2.0, 1.3, 0.2), "limestone")
    m.box((0, 0, 0.6), (1.6, 1.0, 0.8), "marble")
    for x in (-0.65, 0.65):
        with m.at(location=(x, 0, 1.05), rotation=(90, 0, 0)):
            m.lathe([(0.18, -0.5), (0.18, 0.5)], "marble_shadow", segments=8)
    m.box((0, 0, 1.02), (1.3, 1.0, 0.08), "stone_dark")
    m.finish()
    kit.collision_box(slug, (0, 0, 0.55), (2.0, 1.3, 1.1))
    export(slug)


def main():
    column("column", seed=1)
    column("column_broken", broken_at=2.6, seed=2)
    column("column_stump", broken_at=1.1, seed=3)
    column_fallen()
    temple_ruin()
    moira("moira_klotho", "spindle", 1)
    moira("moira_lachesis", "rod", 2)
    moira("moira_atropos", "empty", 3)
    stele("stele_a", 1)
    stele("stele_b", 2, tall=1.5)
    sarcophagus()
    tholos()
    gate()
    altar()


kit.run(main)
