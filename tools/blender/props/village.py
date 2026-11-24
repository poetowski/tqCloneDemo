"""Elaion the village: whitewashed houses under terracotta hipped roofs, a well, Klotho's
warp-weighted loom (gold threads in the warp), a vine pergola, dry-stone walls and
terrace stairs, a beached fishing boat with the painted eye at its bow, a jetty,
crates and sacks. Bronze-age, not Cycladic: no blue doors.
"""
import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def export(slug):
    out = kit.export_glb(kit.model_path("props", slug))
    kit.report("asset", slug, out)


def facing_up(points):
    """Orders a face's points so its normal points up/out of the roof."""
    a, b, c = (Vector(p) for p in points[:3])
    normal = (b - a).cross(c - a)
    return points if normal.z >= 0 else list(reversed(points))


def lerp(a, b, t):
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


def roof_face(m, a, b, c, d, bands, swatches):
    for i in range(bands):
        t0, t1 = i / bands, (i + 1) / bands
        p0, p1 = lerp(a, d, t0), lerp(b, c, t0)
        p2, p3 = lerp(b, c, t1), lerp(a, d, t1)
        pts = [p0, p1, p2, p3] if Vector(p2) != Vector(p3) else [p0, p1, p2]
        m.polygon(facing_up(pts), swatches[i % len(swatches)])


def hipped_roof(m, cx, cy, w, d, z0, z1, overhang=0.45, bands=5):
    hw, hd = w / 2 + overhang, d / 2 + overhang
    ridge = max(0.0, hw - hd)
    tiles = ["terracotta", "terracotta_dark"]
    e = [(cx - hw, cy - hd, z0), (cx + hw, cy - hd, z0), (cx + hw, cy + hd, z0), (cx - hw, cy + hd, z0)]
    r0, r1 = (cx - ridge, cy, z1), (cx + ridge, cy, z1)
    roof_face(m, e[0], e[1], r1, r0, bands, tiles)      # front
    roof_face(m, e[2], e[3], r0, r1, bands, tiles)      # back
    roof_face(m, e[1], e[2], r1, r1, bands, tiles)      # right end
    roof_face(m, e[3], e[0], r0, r0, bands, tiles)      # left end
    if ridge > 0:
        m.cylinder(r0, r1, 0.09, 0.09, "terracotta_dark", segments=5)
    m.polygon([e[3], e[2], e[1], e[0]], "wood_dark")    # soffit, seen from below


def walls(m, cx, cy, w, d, h, rng, door_side=-1):
    m.box((cx, cy, 0.15), (w + 0.3, d + 0.3, 0.3), "rubble")
    m.box((cx, cy, 0.3 + h / 2), (w, d, h), "whitewash")
    m.box((cx, cy, 0.3 + h - 0.12), (w + 0.04, d + 0.04, 0.14), "wool_ochre")
    face_y = cy + door_side * (d / 2 + 0.02)
    m.box((cx - w * 0.15, face_y, 1.25), (1.2, 0.08, 2.0), "limestone")
    m.box((cx - w * 0.15, face_y + door_side * 0.02, 1.2), (0.95, 0.08, 1.85), "wood")
    m.box((cx - w * 0.15 + 0.3, face_y + door_side * 0.05, 1.2), (0.06, 0.04, 0.06), "bronze")
    for wx in (cx + w * 0.22,):
        m.box((wx, face_y, 1.7), (0.7, 0.06, 0.6), "eye_dark")
        m.box((wx - 0.42, face_y + door_side * 0.03, 1.7), (0.16, 0.05, 0.66), "wood")
        m.box((wx + 0.42, face_y + door_side * 0.03, 1.7), (0.16, 0.05, 0.66), "wood")
    # Stones showing through worn plaster.
    for _ in range(7):
        side = rng.choice((-1, 1))
        on_x = rng.random() < 0.5
        x = cx + (side * (w / 2 + 0.01) if on_x else rng.uniform(-w / 2 + 0.4, w / 2 - 0.4))
        y = cy + (rng.uniform(-d / 2 + 0.4, d / 2 - 0.4) if on_x else side * (d / 2 + 0.01))
        m.box((x, y, rng.uniform(0.5, h)), (0.35 if not on_x else 0.04, 0.04 if not on_x else 0.35, 0.22), "plaster_warm")


def house(slug, seed, w, d, h, annex=False):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    walls(m, 0, 0, w, d, h, rng)
    hipped_roof(m, 0, 0, w, d, 0.3 + h, 0.3 + h + 1.5)
    if annex:
        walls(m, w / 2 + 1.6, 0.8, 3.2, 3.4, h - 0.6, rng)
        hipped_roof(m, w / 2 + 1.6, 0.8, 3.2, 3.4, 0.3 + h - 0.6, 0.3 + h + 0.4, overhang=0.35, bands=3)
        # A low courtyard wall.
        m.box((w / 2 + 1.6, -2.6, 0.55), (3.2, 0.4, 1.1), "whitewash")
    m.finish()
    kit.collision_box(slug, (0, 0, (h + 0.3) / 2), (w + 0.3, d + 0.3, h + 0.3))
    if annex:
        kit.collision_box(slug + "_annex", (w / 2 + 1.6, 0.8, h / 2), (3.3, 3.5, h))
        kit.collision_box(slug + "_yard", (w / 2 + 1.6, -2.6, 0.55), (3.2, 0.4, 1.1))
    export(slug)


def well(slug="well"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.lathe([(0.95, 0.0), (0.95, 0.85), (0.98, 0.9), (0.72, 0.9), (0.68, 0.0)], "rubble", segments=14, caps=False)
    m.cylinder((0, 0, 0.3), (0, 0, 0.32), 0.7, 0.7, "basalt", segments=14)
    for x in (-0.85, 0.85):
        m.box((x, 0, 1.3), (0.14, 0.14, 1.9), "wood")
    m.cylinder((-0.95, 0, 2.15), (0.95, 0, 2.15), 0.07, 0.07, "wood_dark", segments=6)
    m.cylinder((0, 0, 1.2), (0, 0, 2.1), 0.012, 0.012, "rope", segments=4)
    m.lathe([(0.12, 0.95), (0.16, 1.2), (0.0, 1.2)], "wood", segments=8)
    m.finish()
    kit.collision_cylinder(slug, (0, 0, 0), (0, 0, 1.0), 1.0, segments=10)
    export(slug)


def loom(slug="loom"):
    """A warp-weighted loom: posts leaning on the wall, cloth rolled on the top beam,
    a warp held taut by clay weights. A few warp threads are gold: Klotho's."""
    kit.clear_scene()
    m = kit.Mesh(slug)
    lean = 0.35
    for x in (-1.0, 1.0):
        m.cylinder((x, 0, 0), (x, lean, 2.4), 0.07, 0.06, "wood", segments=6)
    m.cylinder((-1.15, lean * 0.92, 2.2), (1.15, lean * 0.92, 2.2), 0.08, 0.08, "wood_dark", segments=6)
    # Woven cloth on the beam: indigo with a gold meander band.
    m.box((0, lean * 0.88 - 0.02, 1.85), (1.8, 0.03, 0.7), "wool_indigo", rotation=(-8, 0, 0))
    m.box((0, lean * 0.86 - 0.04, 1.65), (1.8, 0.03, 0.1), "gold", rotation=(-8, 0, 0))
    m.cylinder((-1.0, lean * 0.5, 1.2), (1.0, lean * 0.5, 1.2), 0.025, 0.025, "wood", segments=5)
    for i in range(23):
        x = -0.88 + i * 0.08
        glow = i % 6 == 2
        m.cylinder((x, lean * 0.82, 1.5), (x, lean * 0.18, 0.45), 0.006 if not glow else 0.01, 0.006 if not glow else 0.01,
                   "ichor_glow" if glow else "linen", segments=3, caps=False)
    for i in range(12):
        x = -0.84 + i * 0.153
        m.cone((x, lean * 0.15, 0.25), (x, lean * 0.16, 0.45), 0.06, "clay", segments=4)
    # A basket of spun thread and a spindle at the foot.
    m.lathe([(0.0, 0.0), (0.22, 0.02), (0.26, 0.25), (0.22, 0.25)], "straw", segments=10, center=(1.5, -0.4, 0))
    for k in range(3):
        m.sphere((1.45 + k * 0.08, -0.38, 0.27), 0.07, ["gold", "linen", "wool_red"][k], segments=8, rings=5)
    m.finish()
    kit.collision_box(slug, (0, lean * 0.4, 1.0), (2.3, 0.7, 2.0))
    export(slug)


def pergola(slug="pergola"):
    kit.clear_scene()
    rng = random.Random(5)
    m = kit.Mesh(slug)
    for x in (-1.6, 1.6):
        for y in (-1.4, 1.4):
            m.cylinder((x, y, 0), (x, y, 2.6), 0.09, 0.08, "wood", segments=6)
    for y in (-1.4, 1.4):
        m.box((0, y, 2.62), (3.7, 0.14, 0.14), "wood_dark")
    for i in range(7):
        m.box((-1.65 + i * 0.55, 0, 2.74), (0.08, 3.4, 0.08), "wood")
    for i in range(14):
        p = (rng.uniform(-1.7, 1.7), rng.uniform(-1.5, 1.5), 2.85)
        m.rock(p, rng.uniform(0.3, 0.5), "olive_leaf_dark" if i % 3 else "grass_green", rng, scale=(1.3, 1.3, 0.5), flat_bottom=False)
    for i in range(6):
        p = (rng.uniform(-1.4, 1.4), rng.uniform(-1.2, 1.2), 2.5)
        m.sphere(p, 0.08, "wool_violet", scale=(1, 1, 1.4), segments=6, rings=4)
    m.finish()
    for x in (-1.6, 1.6):
        for y in (-1.4, 1.4):
            kit.collision_cylinder(f"{slug}_post_{x}_{y}", (x, y, 0), (x, y, 2.0), 0.15, segments=6)
    export(slug)


def stone_wall(slug, length, seed, height=1.0):
    kit.clear_scene()
    rng = random.Random(seed)
    m = kit.Mesh(slug)
    rows = 3
    for r in range(rows):
        x = -length / 2
        z = r * height / rows
        while x < length / 2 - 0.05:
            w = min(rng.uniform(0.35, 0.7), length / 2 - x)
            m.box((x + w / 2, rng.uniform(-0.03, 0.03), z + height / rows / 2), (w - 0.03, 0.62 - r * 0.06, height / rows - 0.03),
                  rng.choice(["rubble", "limestone", "rubble", "stone_dark"]), rotation=(0, rng.uniform(-3, 3), rng.uniform(-3, 3)))
            x += w
    m.box((0, 0, height + 0.06), (length, 0.5, 0.12), "limestone")
    m.finish()
    kit.collision_box(slug, (0, 0, (height + 0.12) / 2), (length, 0.62, height + 0.12))
    export(slug)


def stairs(slug, width, rise, steps, swatch="limestone"):
    """Steps climbing toward -Y (the model's front), `rise` metres in all."""
    kit.clear_scene()
    m = kit.Mesh(slug)
    run = 0.45
    for i in range(steps):
        z = rise * (i + 1) / steps
        m.box((0, -run * i - run / 2, z / 2), (width, run, z), swatch if i % 2 == 0 else "marble_shadow" if swatch == "marble" else "limestone")
    for x in (-width / 2 - 0.25, width / 2 + 0.25):
        m.box((x, -run * steps / 2, rise / 2 + 0.1), (0.5, run * steps, rise + 0.2), "rubble")
    m.finish()
    # A smooth ramp to walk on, so the hero glides instead of stepping.
    c = kit.Mesh(slug + "-convcolonly")
    length = run * steps
    pts = [(-width / 2, 0.3, 0.0), (width / 2, 0.3, 0.0), (width / 2, -length, rise), (-width / 2, -length, rise),
           (-width / 2, -length - 0.5, rise), (width / 2, -length - 0.5, rise), (width / 2, -length - 0.5, 0.0), (-width / 2, -length - 0.5, 0.0)]
    verts = [c.bm.verts.new(p) for p in pts]
    for face in ((0, 1, 2, 3), (3, 2, 5, 4), (4, 5, 6, 7), (7, 6, 1, 0), (0, 3, 4, 7), (1, 6, 5, 2)):
        c.bm.faces.new([verts[k] for k in face])
    c.paint(verts, "basalt")
    c.finish()
    export(slug)


def boat(slug="boat"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    rings = []
    length = 5.2
    for i in range(9):
        t = i / 8
        y = (t - 0.5) * length
        beam = 0.95 * math.sin(math.pi * (0.08 + 0.84 * t)) ** 0.7
        sheer = 0.85 + 0.45 * abs(t - 0.5) ** 2 * 4
        ring = []
        for k in range(7):
            a = math.pi * k / 6
            ring.append((math.cos(a) * beam, y, sheer - math.sin(a) * 0.75 * (0.3 + 0.7 * beam)))
        rings.append(ring)
    m.loft(rings, "black_glaze", closed=False, caps=False, double=True)
    # Red sheer strake and the apotropaic eye at the bow.
    m.loft([[(p[0] * 1.01, p[1], p[2] - 0.05) for p in (ring[0], ring[-1])] for ring in rings], "wool_red", closed=False, caps=False, double=True)
    for side in (-1, 1):
        m.cylinder((side * 0.62, -2.15, 0.88), (side * 0.66, -2.15, 0.88), 0.13, 0.13, "linen", segments=10)
        m.cylinder((side * 0.66, -2.15, 0.88), (side * 0.68, -2.15, 0.88), 0.06, 0.06, "black_glaze", segments=8)
    m.cylinder((0, -0.4, 0.3), (0, -0.4, 3.6), 0.06, 0.05, "wood", segments=6)
    m.cylinder((-1.1, -0.4, 3.3), (1.1, -0.4, 3.3), 0.04, 0.04, "wood", segments=5)
    m.box((0, -0.4, 3.15), (2.0, 0.15, 0.35), "linen")
    for y in (-1.2, 0.3, 1.4):
        m.box((0, y, 0.75), (1.4, 0.25, 0.06), "wood")
    m.finish()
    kit.collision_box(slug, (0, 0, 0.6), (1.8, 5.0, 1.2))
    export(slug)


def jetty(slug="jetty"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    for i in range(16):
        m.box((0, -i * 0.62, 1.2), (2.2, 0.56, 0.1), "wood" if i % 2 else "wood_dark", rotation=(0, 0, (i % 3 - 1) * 1.5))
    for i in range(5):
        for x in (-1.0, 1.0):
            m.cylinder((x, -i * 2.4, -1.5), (x, -i * 2.4, 1.35), 0.11, 0.1, "wood_dark", segments=6)
    m.finish()
    kit.collision_box(slug, (0, -4.6, 0.6), (2.2, 10.0, 1.3))
    export(slug)


def crate(slug="crate"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.box((0, 0, 0.35), (0.8, 0.6, 0.7), "wood", bevel=0.02)
    for z in (0.12, 0.58):
        m.box((0, 0, z), (0.82, 0.62, 0.06), "bronze_dark")
    m.finish()
    kit.collision_box(slug, (0, 0, 0.35), (0.8, 0.6, 0.7))
    export(slug)


def sacks(slug="sacks"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    for p, s in (((0, 0, 0.3), "linen"), ((0.55, 0.1, 0.28), "straw"), ((0.25, 0.05, 0.75), "linen_shadow")):
        m.sphere(p, 0.36, s, scale=(1, 0.8, 0.85), segments=9, rings=6, smooth=True)
        m.cylinder((p[0], p[1], p[2] + 0.28), (p[0], p[1], p[2] + 0.4), 0.08, 0.04, "rope", segments=5)
    m.finish()
    export(slug)


def main():
    house("house_a", 1, 6.4, 4.6, 2.7)
    house("house_b", 2, 5.4, 4.2, 2.5, annex=True)
    well()
    loom()
    pergola()
    stone_wall("stone_wall", 4.0, 3)
    stone_wall("stone_wall_low", 4.0, 4, height=0.6)
    stairs("stairs_stone", 3.0, 1.8, 6)
    stairs("stairs_marble", 8.0, 2.4, 8, swatch="marble")
    boat()
    jetty()
    crate()
    sacks()


kit.run(main)
