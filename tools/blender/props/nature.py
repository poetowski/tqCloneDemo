"""The living land of Elaion: olive, fig and pine trees, cypresses, maquis shrubs
(oleander, myrtle, broom, thyme), acanthus on the ruins, reeds on the shore, grass,
clover, wildflowers and asphodel (the flower of the underworld, for the necropolis),
limestone rocks, pebbles and driftwood. Silhouettes first: twisted olive trunks with
silver clumps, black-green cypress spindles, the flat crowns of pines.

Everything alive is painted with the "Foliage" material: the palette with wind in
the game (src/shaders/palette.gdshader), so leaves and grass sway; stone and dead
wood stay on "Palette". Each variant is its own .glb.
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


def plant(slug):
    """A fresh mesh for something alive: it sways in the wind."""
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.material = "Foliage"
    return m


def branch(m, rng, start, direction, length, radius, swatch, depth, clumps, splits=2):
    """A crooked branch: a tapered tube with kinks, splitting into smaller ones."""
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
        for _ in range(splits):
            nd = [d[0] + rng.uniform(-0.8, 0.8), d[1] + rng.uniform(-0.8, 0.8), d[2] + rng.uniform(0.0, 0.6)]
            branch(m, rng, points[-2], nd, length * 0.6, radii[-2] * 0.8, swatch, depth - 1, clumps, splits)
    else:
        clumps.append((points[-1], d))


def sprigs(m, rng, center, count, swatch, length=0.28, width=0.07, spread=0.6):
    """Narrow leaves poking out of a clump: they feather its outline."""
    for _ in range(count):
        a = rng.uniform(0, math.tau)
        out = (math.cos(a), math.sin(a), rng.uniform(-0.2, 0.6))
        base = (center[0] + out[0] * spread, center[1] + out[1] * spread, center[2] + out[2] * spread * 0.5)
        m.leaf(base, out, length * rng.uniform(0.8, 1.2), width, swatch, droop=0.15)


def olive(slug, seed):
    m = plant(slug)
    rng = random.Random(seed)
    # A gnarled boss of a base, roots gripping the ground.
    m.ico((0, 0, 0.3), 0.55, "olive_bark", scale=(1.25, 1.05, 0.75), subdivisions=1)
    for k in range(5):
        a = math.tau * k / 5 + rng.uniform(-0.3, 0.3)
        reach = rng.uniform(0.85, 1.15)
        m.tube([(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.35), (math.cos(a) * 0.7 * reach, math.sin(a) * 0.7 * reach, 0.12),
                (math.cos(a) * 1.0 * reach, math.sin(a) * 1.0 * reach, -0.06)], 0.13, "olive_bark", segments=5, taper=[0.16, 0.1, 0.05])
    # Two or three twisted stems, each splitting twice.
    clumps = []
    stems = rng.randint(2, 3)
    for k in range(stems):
        a = math.tau * k / stems + rng.uniform(-0.4, 0.4)
        lean = (math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0)
        branch(m, rng, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.3), lean, rng.uniform(2.0, 2.5), 0.24, "olive_bark", 2, clumps)
        m.ico((math.cos(a) * 0.35, math.sin(a) * 0.35, 1.0), 0.2, "olive_bark", subdivisions=0)  # a burl
    # Silver-green clumps at the branch ends: light on top, dark beneath; narrow
    # silver leaves break their outline.
    for c, d in clumps:
        for j in range(4):
            off = (rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), rng.uniform(-0.3, 0.4))
            r = rng.uniform(0.34, 0.58)
            centre = (c[0] + off[0], c[1] + off[1], c[2] + off[2])
            m.rock(centre, r, "olive_leaf" if off[2] > -0.05 else "olive_leaf_dark", rng,
                   scale=(1.35, 1.35, 0.68), subdivisions=1, roughness=0.3, flat_bottom=False)
            sprigs(m, rng, centre, 3, "olive_leaf", spread=r * 1.05)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.2), 0.4, segments=8)
    export(slug)


def cypress(slug, seed, height):
    """The Mediterranean cypress: a dense dark flame, widest a third of the way up."""
    m = plant(slug)
    rng = random.Random(seed)
    m.cylinder((0, 0, 0), (0, 0, 0.9), 0.17, 0.14, "olive_bark", segments=6)
    h = height
    m.lathe([(0.0, 0.55), (0.5, 0.75), (0.78, 0.25 * h), (0.8, 0.42 * h), (0.66, 0.62 * h), (0.42, 0.8 * h), (0.16, 0.94 * h), (0.0, h)],
            "cypress_dark", segments=9)
    # Clumps spiralling up the column break the outline into a living, flickering shape.
    for i in range(22):
        t = 0.1 + 0.8 * i / 21 + rng.uniform(-0.03, 0.03)
        width = 0.8 * (1.0 - abs(t - 0.38) * 1.3)
        a = i * 2.4 + rng.uniform(-0.4, 0.4)
        m.rock((math.cos(a) * width * 0.6, math.sin(a) * width * 0.6, t * h), max(0.16, width * 0.45), "cypress" if i % 3 else "cypress_dark",
               rng, scale=(1.0, 1.0, 2.2), roughness=0.22, flat_bottom=False)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.0), 0.45, segments=8)
    export(slug)


def umbrella_pine(slug, seed):
    m = plant(slug)
    rng = random.Random(seed)
    pts = [(0, 0, 0), (0.15, 0.05, 2.0), (0.4, 0.1, 4.0), (0.55, 0.0, 6.0), (0.6, -0.1, 7.2)]
    m.tube(pts, 0.28, "olive_bark", segments=7, taper=[0.34, 0.28, 0.22, 0.18, 0.14])
    for a in (0.3, 2.4, 4.4):
        m.tube([(0.5, 0, 5.8), (0.5 + math.cos(a) * 1.6, math.sin(a) * 1.6, 6.9)], 0.1, "olive_bark", segments=5)
    # The flat crown: wide, shallow clumps, darker beneath.
    for i in range(14):
        a = math.tau * i / 14 + rng.uniform(-0.2, 0.2)
        d = rng.uniform(0.6, 2.7)
        lower = i % 4 == 0
        m.rock((0.55 + math.cos(a) * d, math.sin(a) * d, (7.0 if lower else 7.5) + rng.uniform(-0.2, 0.3)), rng.uniform(0.9, 1.35),
               "cypress_dark" if lower else ("cypress" if i % 3 else "olive_leaf_dark"), rng, scale=(1.4, 1.4, 0.42), roughness=0.22,
               flat_bottom=False)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.5), 0.4)
    export(slug)


def aleppo_pine(slug, seed):
    """A wind-bent pine of the dry hills: a leaning trunk, a few long branches with
    tufts of needles at their ends, light showing through."""
    m = plant(slug)
    rng = random.Random(seed)
    lean = rng.uniform(0, math.tau)
    lx, ly = math.cos(lean), math.sin(lean)
    trunk = [(0, 0, 0), (lx * 0.3, ly * 0.3, 1.6), (lx * 0.9, ly * 0.9, 3.2), (lx * 1.4, ly * 1.4, 4.6), (lx * 1.6, ly * 1.6, 5.6)]
    m.tube(trunk, 0.22, "olive_bark", segments=6, taper=[0.26, 0.22, 0.17, 0.13, 0.09])
    for k in range(5):
        t = 2 + k % 3
        base = trunk[t]
        a = rng.uniform(0, math.tau)
        length = rng.uniform(1.4, 2.4)
        tip = (base[0] + math.cos(a) * length, base[1] + math.sin(a) * length, base[2] + rng.uniform(0.4, 1.2))
        m.tube([base, tip], 0.08, "olive_bark", segments=5, taper=[0.09, 0.04])
        for j in range(3):
            m.rock((tip[0] + rng.uniform(-0.5, 0.5), tip[1] + rng.uniform(-0.5, 0.5), tip[2] + rng.uniform(-0.15, 0.25)),
                   rng.uniform(0.45, 0.75), "cypress" if j % 2 else "olive_leaf_dark", rng, scale=(1.3, 1.3, 0.5),
                   roughness=0.28, flat_bottom=False)
    m.rock((trunk[-1][0], trunk[-1][1], trunk[-1][2] + 0.2), 0.9, "cypress", rng, scale=(1.5, 1.5, 0.5), roughness=0.25, flat_bottom=False)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.0), 0.35, segments=8)
    export(slug)


def fig(slug, seed):
    """The village fig: smooth grey stems spreading from the ground, a low wide dome
    of big hand-shaped leaves, a few dark figs underneath."""
    m = plant(slug)
    rng = random.Random(seed)
    tops = []
    for k in range(4):
        a = math.tau * k / 4 + rng.uniform(-0.4, 0.4)
        top = (math.cos(a) * 1.3, math.sin(a) * 1.3, rng.uniform(2.0, 2.6))
        m.tube([(0, 0, 0), (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.9), top], 0.16, "stone_dark", segments=6, taper=[0.2, 0.14, 0.08])
        tops.append(top)
    for top in tops:
        for j in range(4):
            centre = (top[0] + rng.uniform(-0.8, 0.8), top[1] + rng.uniform(-0.8, 0.8), top[2] + rng.uniform(-0.2, 0.5))
            m.rock(centre, rng.uniform(0.6, 0.85), "oleander_leaf" if j % 2 else "olive_leaf_dark", rng, scale=(1.3, 1.3, 0.75),
                   roughness=0.25, flat_bottom=False)
            for _ in range(4):
                a = rng.uniform(0, math.tau)
                out = (math.cos(a), math.sin(a), rng.uniform(0.0, 0.8))
                m.leaf((centre[0] + out[0] * 0.6, centre[1] + out[1] * 0.6, centre[2] + out[2] * 0.4), out, 0.45, 0.36,
                       "grass_green" if rng.random() < 0.4 else "oleander_leaf", droop=0.2)
        for _ in range(3):
            m.ico((top[0] + rng.uniform(-0.6, 0.6), top[1] + rng.uniform(-0.6, 0.6), top[2] - 0.35), 0.06, "wool_violet", subdivisions=0)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 2.0), 0.45, segments=8)
    export(slug)


def bush(slug, seed, swatch, flower=None, size=1.0, leaves=None):
    m = plant(slug)
    rng = random.Random(seed)
    for i in range(7):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.45) * size
        r = rng.uniform(0.33, 0.55) * size
        centre = (math.cos(a) * d, math.sin(a) * d, r * 0.7)
        m.rock(centre, r, swatch, rng, scale=(1, 1, 0.85), roughness=0.25, flat_bottom=True)
        if leaves:
            sprigs(m, rng, centre, 3, leaves, length=0.22 * size, width=0.06 * size, spread=r)
    if flower:
        for i in range(18):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(0.2, 0.75) * size
            m.ico((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.5, 1.05) * size), 0.07 * size, flower, subdivisions=0)
    m.finish()
    export(slug)


def broom(slug, seed):
    """Spanish broom of the dry slopes: whippy green rods tipped with yellow flowers."""
    m = plant(slug)
    rng = random.Random(seed)
    m.rock((0, 0, 0.25), 0.35, "olive_leaf_dark", rng, scale=(1.2, 1.2, 0.8), roughness=0.3)
    for _ in range(16):
        a = rng.uniform(0, math.tau)
        lean = rng.uniform(0.15, 0.5)
        h = rng.uniform(0.9, 1.4)
        tip = (math.cos(a) * lean * h, math.sin(a) * lean * h, h)
        m.cylinder((0, 0, 0.2), tip, 0.02, 0.012, "grass_green", segments=3, caps=False)
        for k in range(3):
            t = 0.65 + 0.15 * k
            m.ico((tip[0] * t, tip[1] * t, 0.2 + (tip[2] - 0.2) * t), 0.06, "flower_yellow", subdivisions=0)
    m.finish()
    export(slug)


def thyme(slug, seed):
    """A low cushion of wild thyme, dotted with pink flowers."""
    m = plant(slug)
    rng = random.Random(seed)
    for i in range(3):
        a = rng.uniform(0, math.tau)
        m.rock((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.05), rng.uniform(0.16, 0.24), "olive_leaf_dark" if i else "olive_leaf", rng,
               scale=(1.3, 1.3, 0.55), roughness=0.3)
    for _ in range(10):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.25)
        m.ico((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.1, 0.17)), 0.03, "oleander", subdivisions=0)
    m.finish()
    export(slug, report=False)


def acanthus(slug, seed):
    """Acanthus, the leaf of the Corinthian capital: a rosette of long, deep-cut
    leaves arching out of the ruins, and a spike of white and violet flowers."""
    m = plant(slug)
    rng = random.Random(seed)
    for k in range(9):
        a = math.tau * k / 9 + rng.uniform(-0.15, 0.15)
        out = (math.cos(a), math.sin(a), 0.55)
        for s in range(3):  # each leaf in three lobes along its rib
            base = (out[0] * 0.18 * s, out[1] * 0.18 * s, 0.05 + 0.1 * s)
            m.leaf(base, (out[0], out[1], 0.5 - 0.25 * s), 0.32, 0.22 - 0.04 * s, "oleander_leaf" if (k + s) % 2 else "olive_leaf_dark",
                   droop=0.35)
    for spike in range(2):
        a = rng.uniform(0, math.tau)
        base = (math.cos(a) * 0.1, math.sin(a) * 0.1, 0)
        h = rng.uniform(0.9, 1.2)
        m.cylinder(base, (base[0], base[1], h), 0.02, 0.012, "grass_green", segments=3, caps=False)
        for k in range(7):
            z = h * (0.45 + 0.08 * k)
            m.ico((base[0] + rng.uniform(-0.04, 0.04), base[1] + rng.uniform(-0.04, 0.04), z), 0.045,
                  "asphodel" if k % 2 else "wool_violet", subdivisions=0)
    m.finish()
    export(slug, report=False)


def reeds(slug, seed):
    """A stand of reeds at the water's edge: tall blades and feathery plumes."""
    m = plant(slug)
    rng = random.Random(seed)
    for i in range(14):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.35)
        base = (math.cos(a) * d, math.sin(a) * d, 0.0)
        h = rng.uniform(1.3, 2.1)
        lean = rng.uniform(0, math.tau)
        tip = (base[0] + math.cos(lean) * h * 0.12, base[1] + math.sin(lean) * h * 0.12, h)
        side = (math.cos(lean + 1.57) * 0.035, math.sin(lean + 1.57) * 0.035, 0)
        m.polygon([(base[0] - side[0], base[1] - side[1], 0), (base[0] + side[0], base[1] + side[1], 0), tip],
                  "grass_green" if i % 3 else "grass_dry", double=True)
        if i % 4 == 0:
            m.rock(tip, 0.09, "rope", rng, scale=(0.6, 0.6, 1.8), subdivisions=0, roughness=0.2, flat_bottom=False)
    m.finish()
    export(slug, report=False)


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


def pebbles(slug, seed):
    """A scatter of small stones (no collision): paths' edges, the shore."""
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    for i in range(7):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.45)
        m.rock((math.cos(a) * d, math.sin(a) * d, 0.0), rng.uniform(0.05, 0.14), ["limestone", "rubble", "stone_dark", "marble_shadow"][i % 4],
               rng, scale=(1.2, 1.0, 0.6), subdivisions=0, roughness=0.2)
    m.finish()
    export(slug, report=False)


def driftwood(slug, seed):
    """A sea-bleached log with a broken branch (no collision)."""
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    m.tube([(-1.1, 0, 0.12), (-0.3, 0.1, 0.16), (0.5, -0.05, 0.13), (1.2, 0.1, 0.1)], 0.16, "bone_dark", segments=6,
           taper=[0.17, 0.16, 0.13, 0.08])
    m.tube([(0.2, 0.0, 0.18), (0.6, 0.5, 0.35), (0.8, 0.8, 0.3)], 0.06, "bone", segments=5, taper=[0.07, 0.05, 0.03])
    m.rock((-1.1, 0, 0.14), 0.2, "bone_dark", rng, scale=(0.6, 1.0, 0.9), subdivisions=0, roughness=0.25)
    m.finish()
    export(slug)


def grass(slug, seed, swatches, count=9, height=0.45, flowers=None, flower_height=0.5, heads=None):
    m = plant(slug)
    rng = random.Random(seed)
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
        if heads and i % 2 == 0:
            m.rock(tip, 0.035, heads, rng, scale=(0.7, 0.7, 2.0), subdivisions=0, roughness=0.15, flat_bottom=False)
    if flowers:
        for i in range(3):
            a = rng.uniform(0, math.tau)
            p = (math.cos(a) * 0.12, math.sin(a) * 0.12, flower_height * rng.uniform(0.8, 1.1))
            m.cylinder((p[0], p[1], 0), p, 0.008, 0.008, "grass_green", segments=3, caps=False)
            m.ico(p, 0.045, flowers if isinstance(flowers, str) else flowers[i % len(flowers)], subdivisions=0)
    m.finish()
    export(slug, report=False)


def clover(slug, seed):
    """Low clover: three-leaved sprigs hugging the ground, a few white heads."""
    m = plant(slug)
    rng = random.Random(seed)
    for _ in range(9):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.22)
        c = (math.cos(a) * d, math.sin(a) * d, rng.uniform(0.05, 0.1))
        for k in range(3):
            b = rng.uniform(0, math.tau) + k * 2.09
            m.leaf(c, (math.cos(b), math.sin(b), 0.1), 0.07, 0.06, "grass_green", droop=0.1)
    for _ in range(3):
        a = rng.uniform(0, math.tau)
        m.ico((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.13), 0.03, "asphodel", subdivisions=0)
    m.finish()
    export(slug, report=False)


def asphodel(slug, seed):
    m = plant(slug)
    rng = random.Random(seed)
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
    aleppo_pine("aleppo_pine_a", 14)
    aleppo_pine("aleppo_pine_b", 29)
    fig("fig_tree", 7)
    bush("bush_oleander", 4, "oleander_leaf", flower="oleander", leaves="oleander_leaf")
    bush("bush_myrtle", 8, "cypress", size=0.8, leaves="cypress")
    bush("bush_dry", 12, "olive_leaf_dark", flower="flower_yellow", size=0.7)
    broom("bush_broom", 15)
    rock("rock_small", 1, 0.45, "limestone", collide=False)
    rock("rock_medium", 2, 1.0, "limestone")
    rock("rock_large", 3, 2.2, "rubble", stretch=(1.2, 1.0, 0.8))
    rock("rock_cliff", 4, 3.4, "limestone", stretch=(1.0, 0.8, 1.4), parts=4)
    rock("rock_dark", 5, 1.4, "basalt")
    driftwood("driftwood", 3)
    grass("grass_dry", 1, ["grass_dry", "straw", "grass_dry"])
    grass("grass_green", 2, ["grass_green", "olive_leaf_dark", "grass_green"])
    grass("grass_poppy", 3, ["grass_green", "grass_dry"], count=7, flowers="poppy")
    grass("grass_daisy", 4, ["grass_green", "grass_dry"], count=7, flowers="flower_yellow", flower_height=0.35)
    grass("grass_tall", 5, ["grass_dry", "grass_dry", "straw"], count=11, height=0.95, heads="straw")
    grass("wildflowers", 8, ["grass_green", "grass_green"], count=6, height=0.35, flowers=["poppy", "asphodel", "flower_yellow"],
          flower_height=0.4)
    clover("clover", 6)
    thyme("thyme", 9)
    acanthus("acanthus", 10)
    reeds("reeds", 12)
    pebbles("pebbles", 13)
    asphodel("asphodel", 6)
    kit.log("asset", "grass, flowers, shrubs and pebbles written")


kit.run(main)
