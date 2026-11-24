"""The living land of Elaion: olive trees, cypresses, an umbrella pine, oleander and
myrtle bushes, limestone rocks, grass tufts, poppies and asphodel (the flower of the
underworld, for the necropolis). Silhouettes first: twisted olive trunks with silver
clumps, black-green cypress spindles. Each variant is its own .glb.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def export(slug, report=True):
    out = kit.export_glb(kit.model_path("props", slug))
    if report:
        kit.report("asset", slug, out)


def branch(m, rng, start, direction, length, radius, swatch, depth, leaves, clumps):
    """A crooked branch: a tapered tube with a kink, splitting into smaller ones."""
    points = [start]
    radii = [radius]
    p = list(start)
    d = list(direction)
    steps = 4
    for i in range(steps):
        d = [d[0] + rng.uniform(-0.35, 0.35), d[1] + rng.uniform(-0.35, 0.35), d[2] + rng.uniform(-0.1, 0.25)]
        n = math.sqrt(sum(c * c for c in d))
        d = [c / n for c in d]
        p = [p[k] + d[k] * length / steps for k in range(3)]
        points.append(tuple(p))
        radii.append(radius * (1.0 - 0.6 * (i + 1) / steps))
    m.tube(points, radius, swatch, segments=6, taper=radii)
    if depth > 0:
        for _ in range(2):
            nd = [d[0] + rng.uniform(-0.8, 0.8), d[1] + rng.uniform(-0.8, 0.8), d[2] + rng.uniform(0.0, 0.6)]
            branch(m, rng, points[-2], nd, length * 0.6, radii[-2] * 0.8, swatch, depth - 1, leaves, clumps)
    else:
        clumps.append(points[-1])


def olive(slug, seed):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    # The trunk: two or three twisted stems from one gnarled base.
    m.ico((0, 0, 0.25), 0.55, "olive_bark", scale=(1.2, 1.0, 0.7), subdivisions=1)
    clumps = []
    for k in range(rng.randint(2, 3)):
        a = rng.uniform(0, math.tau)
        lean = (math.cos(a) * 0.35, math.sin(a) * 0.35, 1.0)
        branch(m, rng, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.2), lean, rng.uniform(2.0, 2.6), 0.24, "olive_bark", 1, None, clumps)
    # Silver-green clumps of leaves at the branch ends: many small, airy, uneven.
    for c in clumps:
        for j in range(5):
            off = (rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), rng.uniform(-0.35, 0.45))
            r = rng.uniform(0.38, 0.7)
            m.rock((c[0] + off[0], c[1] + off[1], c[2] + off[2]), r, "olive_leaf" if j % 3 else "olive_leaf_dark", rng,
                   scale=(1.35, 1.35, 0.7), subdivisions=1, roughness=0.3, flat_bottom=False)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.2), 0.4, segments=8)
    export(slug)


def cypress(slug, seed, height):
    """The Mediterranean cypress: a dense dark flame, widest a third of the way up."""
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    m.cylinder((0, 0, 0), (0, 0, 0.9), 0.17, 0.14, "olive_bark", segments=6)
    h = height
    m.lathe([(0.0, 0.55), (0.5, 0.75), (0.78, 0.25 * h), (0.8, 0.42 * h), (0.66, 0.62 * h), (0.42, 0.8 * h), (0.16, 0.94 * h), (0.0, h)],
            "cypress_dark", segments=9)
    # Clumps on the column break the outline into a living, flickering shape.
    for i in range(11):
        t = rng.uniform(0.12, 0.88)
        width = 0.8 * (1.0 - abs(t - 0.38) * 1.3)
        a = rng.uniform(0, math.tau)
        m.rock((math.cos(a) * width * 0.55, math.sin(a) * width * 0.55, t * h), max(0.2, width * 0.55), "cypress" if i % 3 else "cypress_dark",
               rng, scale=(1.0, 1.0, 2.4), roughness=0.2, flat_bottom=False)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.0), 0.45, segments=8)
    export(slug)


def umbrella_pine(slug, seed):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    pts = [(0, 0, 0), (0.15, 0.05, 2.0), (0.4, 0.1, 4.0), (0.55, 0.0, 6.0), (0.6, -0.1, 7.2)]
    m.tube(pts, 0.28, "olive_bark", segments=7, taper=[0.34, 0.28, 0.22, 0.18, 0.14])
    for a in (0.3, 2.4, 4.4):
        m.tube([(0.5, 0, 5.8), (0.5 + math.cos(a) * 1.6, math.sin(a) * 1.6, 6.9)], 0.1, "olive_bark", segments=5)
    # The flat crown: wide, shallow clumps.
    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.2, 0.2)
        d = rng.uniform(0.8, 2.6)
        m.rock((0.55 + math.cos(a) * d, math.sin(a) * d, 7.4 + rng.uniform(-0.2, 0.3)), rng.uniform(1.1, 1.5),
               "cypress" if i % 3 else "olive_leaf_dark", rng, scale=(1.4, 1.4, 0.45), roughness=0.2, flat_bottom=False)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.5), 0.4)
    export(slug)


def bush(slug, seed, swatch, flower=None, size=1.0):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    for i in range(6):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.45) * size
        r = rng.uniform(0.35, 0.55) * size
        m.rock((math.cos(a) * d, math.sin(a) * d, r * 0.7), r, swatch, rng, scale=(1, 1, 0.85), roughness=0.25, flat_bottom=True)
    if flower:
        for i in range(14):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(0.2, 0.7) * size
            m.ico((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.5, 1.0) * size), 0.07 * size, flower, subdivisions=0)
    m.finish()
    export(slug)


def rock(slug, seed, radius, swatch, stretch=(1.0, 1.0, 0.7), parts=3, collide=True):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    for i in range(parts):
        off = (rng.uniform(-0.4, 0.4) * radius, rng.uniform(-0.4, 0.4) * radius, 0.0) if i else (0, 0, 0)
        r = radius * (1.0 if i == 0 else rng.uniform(0.45, 0.7))
        m.rock(off, r, swatch if i != 2 else "stone_dark", rng, scale=stretch, subdivisions=1, roughness=0.18)
    m.finish()
    if collide:
        kit.collision_cylinder(slug, (0, 0, 0), (0, 0, radius * stretch[2] * 1.4), radius * 0.95, segments=8)
    export(slug)


def grass(slug, seed, swatches, count=9, height=0.45, flowers=None, flower_height=0.5):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    for i in range(count):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.18)
        base = (math.cos(a) * d, math.sin(a) * d, 0.0)
        h = height * rng.uniform(0.7, 1.2)
        lean = rng.uniform(0, math.tau)
        tip = (base[0] + math.cos(lean) * h * 0.35, base[1] + math.sin(lean) * h * 0.35, h)
        side = (math.cos(lean + 1.57) * 0.03, math.sin(lean + 1.57) * 0.03, 0)
        m.polygon([(base[0] - side[0], base[1] - side[1], 0), (base[0] + side[0], base[1] + side[1], 0), tip],
                  swatches[i % len(swatches)], double=True)
    if flowers:
        for i in range(3):
            a = rng.uniform(0, math.tau)
            p = (math.cos(a) * 0.12, math.sin(a) * 0.12, flower_height * rng.uniform(0.8, 1.1))
            m.cylinder((p[0], p[1], 0), p, 0.008, 0.008, "grass_green", segments=3, caps=False)
            m.ico(p, 0.045, flowers, subdivisions=0)
    m.finish()
    export(slug, report=False)


def asphodel(slug, seed):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    for i in range(4):
        a = rng.uniform(0, math.tau)
        base = (math.cos(a) * 0.12, math.sin(a) * 0.12, 0)
        h = rng.uniform(0.55, 0.85)
        m.cylinder(base, (base[0], base[1], h), 0.012, 0.008, "grass_green", segments=3)
        for k in range(5):
            z = h * (0.55 + 0.09 * k)
            m.ico((base[0] + rng.uniform(-0.03, 0.03), base[1] + rng.uniform(-0.03, 0.03), z), 0.035, "asphodel", subdivisions=0)
    for i in range(5):
        lean = rng.uniform(0, math.tau)
        m.polygon([(0, 0, 0), (math.cos(lean + 1.57) * 0.04, math.sin(lean + 1.57) * 0.04, 0),
                   (math.cos(lean) * 0.25, math.sin(lean) * 0.25, 0.3)], "grass_green", double=True)
    m.finish()
    export(slug, report=False)


def main():
    olive("olive_tree_a", 11)
    olive("olive_tree_b", 23)
    olive("olive_tree_c", 37)
    cypress("cypress_a", 5, 8.0)
    cypress("cypress_b", 9, 6.2)
    umbrella_pine("umbrella_pine", 3)
    bush("bush_oleander", 4, "oleander_leaf", flower="oleander")
    bush("bush_myrtle", 8, "cypress", size=0.8)
    bush("bush_dry", 12, "olive_leaf_dark", flower="flower_yellow", size=0.7)
    rock("rock_small", 1, 0.45, "limestone", collide=False)
    rock("rock_medium", 2, 1.0, "limestone")
    rock("rock_large", 3, 2.2, "rubble", stretch=(1.2, 1.0, 0.8))
    rock("rock_cliff", 4, 3.4, "limestone", stretch=(1.0, 0.8, 1.4), parts=4)
    rock("rock_dark", 5, 1.4, "basalt")
    grass("grass_dry", 1, ["grass_dry", "straw", "grass_dry"])
    grass("grass_green", 2, ["grass_green", "olive_leaf_dark", "grass_green"])
    grass("grass_poppy", 3, ["grass_green", "grass_dry"], count=7, flowers="poppy")
    grass("grass_daisy", 4, ["grass_green", "grass_dry"], count=7, flowers="flower_yellow", flower_height=0.35)
    asphodel("asphodel", 6)
    kit.log("asset", "grass tufts and asphodel written")


kit.run(main)
