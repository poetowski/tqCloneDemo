"""Elaion: the slice's one zone (docs/LEVEL_ELAION.md). Builds
  assets/models/level/elaion_terrain/elaion_terrain.glb   ground (+ trimesh collision) and sea
  data/level/elaion_layout.json                           every prop, spawner, NPC, shrine...
  .shots/elaion_map.png                                   a top-down map to check the layout
from the design below: walkable zones (plateaus) joined by paths (ramps); outside them
the land climbs into hills and cliffs, or slopes down into the sea in the west.

Coordinates are Godot's: x east, z south (north is -z), y up. Blender gets (x, -z, y).
Rebuild the scene afterwards with `npm run level`.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402

X0, X1, Z0, Z1 = -135.0, 110.0, -135.0, 100.0
STEP = 1.25
SEA_LEVEL = 0.0

# --- the design ------------------------------------------------------------------
# name: (x, z, radius, height, kind)
ZONES = {
    "beach": (-66, 52, 11, 1.2, "coast"),
    "village": (-42, 38, 19, 1.8, "village"),
    "klotho": (-49, 17, 10, 2.3, "village"),
    "terraces": (12, 42, 30, 0.0, "terraces"),
    "terrace_top": (42, 26, 9, 9.6, "field"),
    "road_a": (53, 6, 6, 11.0, "road"),
    "road_b": (52, -17, 6, 12.4, "road"),
    "necropolis": (30, -42, 22, 13.0, "necropolis"),
    "tholos": (55, -56, 10, 13.4, "necropolis"),
    "stairs_foot": (19, -60, 4, 13.4, "necropolis"),
    "gate": (10, -79, 4, 19.8, "sanctuary"),
    "court": (6, -88, 11, 20.0, "sanctuary"),
    "arena": (4, -107, 17, 20.0, "arena"),
}
# (from, to, width, kind)
PATHS = [
    ("beach", "village", 8, "dirt"), ("village", "klotho", 7, "dirt"), ("village", "terraces", 9, "dirt"),
    ("terraces", "terrace_top", 8, "dirt"), ("terrace_top", "road_a", 8, "dirt"), ("road_a", "road_b", 8, "dirt"),
    ("road_b", "necropolis", 9, "dirt"), ("necropolis", "tholos", 8, "ash"), ("necropolis", "stairs_foot", 8, "ash"),
    ("stairs_foot", "gate", 8, "paving"), ("gate", "court", 9, "paving"), ("court", "arena", 10, "paving"),
]


TERRACE_STEP = 1.7
TERRACE_RISE = 0.12
# Each terrace's bank takes the last part of its width: wide enough to walk up
# (1.7 m over ~4 m, under 35° at its steepest), so the terraces are no maze.
BANK_START = 0.72
# Outside the walkable land a gentle verge runs this far before the hills climb:
# edges feel open, and a click just past them still finds ground.
VERGE = 3.0
VERGE_SLOPE = 0.28


def raw_terrace(x):
    """The hillside the terraces are cut into: rising eastward."""
    return 2.6 + max(0.0, x + 14.0) * TERRACE_RISE


def terrace_height(x):
    """The olive terraces climb eastward in 1.7 m steps, about 14 m apart."""
    raw = raw_terrace(x)
    level = math.floor(raw / TERRACE_STEP)
    frac = raw / TERRACE_STEP - level
    riser = kit.smoothstep(BANK_START, 1.0, frac)
    return (level + riser) * TERRACE_STEP


def riser_x(level):
    """Where the bank up to terrace `level` + 1 starts (its foot)."""
    return ((level + BANK_START) * TERRACE_STEP - 2.6) / TERRACE_RISE - 14.0


# --- noise ----------------------------------------------------------------------------

def _hash(ix, iz, seed=0):
    n = (ix * 374761393 + iz * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def noise(x, z, seed=0):
    ix, iz = math.floor(x), math.floor(z)
    fx, fz = x - ix, z - iz
    fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
    a, b = _hash(ix, iz, seed), _hash(ix + 1, iz, seed)
    c, d = _hash(ix, iz + 1, seed), _hash(ix + 1, iz + 1, seed)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fz


def fbm(x, z, seed=0, octaves=3):
    total, amp, freq = 0.0, 0.5, 1.0
    for o in range(octaves):
        total += amp * noise(x * freq, z * freq, seed + o * 17)
        amp *= 0.5
        freq *= 2.1
    return total


# --- height ---------------------------------------------------------------------------

def zone_height(name, x):
    zx, zz, r, h, kind = ZONES[name]
    return terrace_height(x) if kind == "terraces" else h


def _end_height(name, px):
    return raw_terrace(px) if ZONES[name][4] == "terraces" else ZONES[name][3]


def features(x, z):
    """(signed distance outside the walkable land, walk height, zone kind, path kind).
    Inside a zone its plateau rules, except where a path cuts a ramp through the
    terraces; paths ramp from one zone's edge to the next, easing in and out."""
    zone_d, zone_h, zone_kind = 1e9, 0.0, ""
    for name, (zx, zz, r, h, kind) in ZONES.items():
        d = math.hypot(x - zx, z - zz) - r
        if d < zone_d:
            zone_d, zone_h, zone_kind = d, zone_height(name, x), kind
    path_d, path_h, path_kind = 1e9, 0.0, ""
    for a, b, width, kind in PATHS:
        ax, az, ra = ZONES[a][0], ZONES[a][1], ZONES[a][2]
        bx, bz, rb = ZONES[b][0], ZONES[b][1], ZONES[b][2]
        vx, vz = bx - ax, bz - az
        length = math.hypot(vx, vz)
        t = max(0.0, min(1.0, ((x - ax) * vx + (z - az) * vz) / (length * length)))
        px, pz = ax + vx * t, az + vz * t
        d = math.hypot(x - px, z - pz) - width / 2
        if d < path_d:
            span = max(0.01, length - ra - rb)
            u = max(0.0, min(1.0, (t * length - ra) / span))
            s = u * u * (3 - 2 * u)
            ha, hb = _end_height(a, px), _end_height(b, px)
            path_d, path_h, path_kind = d, ha + (hb - ha) * s, kind
    if path_d < 0 and (zone_d >= 0 or zone_kind == "terraces"):
        return path_d, path_h, "path", path_kind
    if zone_d < 0:
        return zone_d, zone_h, zone_kind, path_kind if path_d < 0 else ""
    if path_d < zone_d:
        return path_d, path_h, "path", path_kind
    return zone_d, zone_h, zone_kind, ""


def height(x, z):
    d, walk, kind, path_kind = features(x, z)
    n = fbm(x * 0.045, z * 0.045)
    if d <= 0:
        return walk + (fbm(x * 0.2, z * 0.2, 5) - 0.5) * 0.25
    coast = x < -50 + 18 * math.sin(z * 0.03) and z > -20
    if coast:
        return max(-4.0, walk - d * 0.32 - (n - 0.5) * 0.6)
    if d <= VERGE:
        return walk + d * VERGE_SLOPE
    h = d - VERGE
    rise = 3.2 * (1 - math.exp(-h / 2.5)) + h * 0.55
    return walk + VERGE * VERGE_SLOPE + rise * (0.75 + n * 0.8) + (fbm(x * 0.12, z * 0.12, 9) - 0.5) * min(3.0, h * 0.4)


def surface(x, z, h, slope):
    """The palette swatch for the ground at a point, and its glow (0..1)."""
    d, walk, kind, path_kind = features(x, z)
    n = noise(x * 0.35, z * 0.35, 3)
    n2 = noise(x * 0.08, z * 0.08, 7)
    if h < SEA_LEVEL + 0.25:
        return ("rubble" if n > 0.5 else "stone_dark"), 0.0
    if h < SEA_LEVEL + 1.4 and x < -46:
        return ("plaster_warm" if n > 0.3 else "straw"), 0.0
    if slope > 0.55:
        return ("limestone" if n > 0.45 else ("rubble" if n > 0.2 else "stone_dark")), 0.0
    if d <= -0.6 and path_kind:
        if path_kind == "paving":
            return ("marble_shadow" if (int(x // 1.25) + int(z // 1.25)) % 2 else "limestone"), 0.0
        if path_kind == "ash":
            return ("stone_dark" if n > 0.5 else "ash"), 0.0
        return ("rope" if n > 0.35 else "wool_ochre" if n > 0.15 else "straw"), 0.0
    if kind in ("sanctuary", "arena") and d <= 0:
        return ("marble_shadow" if (int(x // 2.5) + int(z // 2.5)) % 2 else "limestone"), 0.0
    if kind == "necropolis" and d <= 1.0:
        if n > 0.93:
            return "styx_glow", 0.85
        return ("bone_dark" if n > 0.55 else "grass_dry" if n > 0.3 else "ash"), 0.0
    if kind == "village" and d <= 0:
        return ("rope" if n > 0.6 else "grass_dry" if n > 0.25 else "straw"), 0.0
    if kind == "terraces" and d <= 0:
        return ("grass_green" if n2 > 0.55 else "olive_leaf_dark" if n > 0.8 else "grass_dry"), 0.0
    if d > 0 and h > walk + 6:
        return ("grass_dry" if n > 0.4 else "limestone" if n > 0.25 else "olive_leaf_dark"), 0.0
    return ("grass_dry" if n2 > 0.35 else "grass_green" if n > 0.5 else "straw"), 0.0


# --- the terrain mesh ---------------------------------------------------------------------

def build_terrain():
    nx = int((X1 - X0) / STEP) + 1
    nz = int((Z1 - Z0) / STEP) + 1
    heights = [[height(X0 + i * STEP, Z0 + j * STEP) for i in range(nx)] for j in range(nz)]
    bm = bmesh.new()
    verts = [[bm.verts.new((X0 + i * STEP, -(Z0 + j * STEP), heights[j][i])) for i in range(nx)] for j in range(nz)]
    # A float colour layer holds linear values as they are; glTF wants linear COLOR_0.
    colors = bm.loops.layers.float_color.new("Color")
    rgba = {}
    for name in kit.PALETTE.order:
        lin = kit.PALETTE.linear(name)
        rgba[name] = lin
    for j in range(nz - 1):
        for i in range(nx - 1):
            a, b, c, d = verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]
            # Split each quad along the diagonal that follows the land better.
            if abs(heights[j][i] - heights[j + 1][i + 1]) < abs(heights[j][i + 1] - heights[j + 1][i]):
                tris = ((a, c, b), (a, d, c))
            else:
                tris = ((a, d, b), (b, d, c))
            for tri in tris:
                face = bm.faces.new(tri)
                cx = sum(v.co.x for v in tri) / 3
                cz = -sum(v.co.y for v in tri) / 3
                ch = sum(v.co.z for v in tri) / 3
                face.normal_update()
                if face.normal.z < 0:
                    face.normal_flip()
                slope = 1.0 - face.normal.z
                swatch, glow = surface(cx, cz, ch, slope)
                r, g, b_ = rgba[swatch]
                jitter = 0.93 + 0.14 * _hash(int(cx * 7), int(cz * 7), 11)
                for loop in face.loops:
                    loop[colors] = (min(1, r * jitter), min(1, g * jitter), min(1, b_ * jitter), 1.0 - glow)
    mesh = bpy.data.meshes.new("Terrain")
    bm.to_mesh(mesh)
    bm.free()
    # The exporter writes only the active colour attribute.
    mesh.color_attributes.active_color = mesh.color_attributes["Color"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
    mat = bpy.data.materials.new("Terrain")
    mesh.materials.append(mat)
    obj = bpy.data.objects.new("Terrain-col", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return heights, nx, nz


def build_sea():
    bm = bmesh.new()
    size, cells = 520.0, 52
    grid = [[bm.verts.new((-260 + i * size / cells - 60, -(-260 + j * size / cells), SEA_LEVEL)) for i in range(cells + 1)] for j in range(cells + 1)]
    uv = bm.loops.layers.uv.verify()
    for j in range(cells):
        for i in range(cells):
            # Anticlockwise from above (rows run toward -Y), so the water faces up.
            f = bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
            for loop in f.loops:
                loop[uv].uv = (loop.vert.co.x / 20.0, loop.vert.co.y / 20.0)
    mesh = bpy.data.meshes.new("Sea")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(bpy.data.materials.new("Water"))
    obj = bpy.data.objects.new("Sea", mesh)
    bpy.context.scene.collection.objects.link(obj)


# --- the layout --------------------------------------------------------------------------

class Layout:
    def __init__(self, heights, nx, nz):
        self.heights, self.nx, self.nz = heights, nx, nz
        self.items = []
        self.scatter = {}
        self.rng = random.Random(1234)
        self.occupied = []

    def h(self, x, z):
        fi = (x - X0) / STEP
        fj = (z - Z0) / STEP
        i, j = max(0, min(self.nx - 2, int(fi))), max(0, min(self.nz - 2, int(fj)))
        tx, tz = min(1, max(0, fi - i)), min(1, max(0, fj - j))
        hs = self.heights
        a = hs[j][i] + (hs[j][i + 1] - hs[j][i]) * tx
        b = hs[j + 1][i] + (hs[j + 1][i + 1] - hs[j + 1][i]) * tx
        return a + (b - a) * tz

    def free(self, x, z, r):
        return all(math.hypot(x - ox, z - oz) > r + orad for ox, oz, orad in self.occupied)

    def prop(self, model, x, z, rot=None, scale=1.0, group="Props", r=0.0, sink=0.05, y=None):
        rot = self.rng.uniform(0, 360) if rot is None else rot
        self.items.append({"type": "prop", "model": model, "pos": [round(x, 2), round((self.h(x, z) if y is None else y) - sink, 2), round(z, 2)],
                           "rot": round(rot, 1), "scale": round(scale, 2), "group": group})
        if r > 0:
            self.occupied.append((x, z, r))

    def thing(self, kind, x, z, **data):
        entry = {"type": kind, "pos": [round(x, 2), round(self.h(x, z), 2), round(z, 2)]}
        entry.update(data)
        self.items.append(entry)
        if data.get("r", 0):
            self.occupied.append((x, z, data["r"]))

    def scatter_point(self, kind, x, z, scale=1.0):
        self.scatter.setdefault(kind, []).append([round(x, 2), round(self.h(x, z) - 0.02, 2), round(z, 2),
                                                  round(self.rng.uniform(0, 6.283), 2), round(scale, 2)])


def walkable(x, z):
    return features(x, z)[0] <= 0


def on_path(x, z, margin=0.0):
    """Whether a point is on (or within `margin` of) a path corridor."""
    for a, b, width, _kind in PATHS:
        ax, az = ZONES[a][0], ZONES[a][1]
        bx, bz = ZONES[b][0], ZONES[b][1]
        vx, vz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * vx + (z - az) * vz) / (vx * vx + vz * vz)))
        if math.hypot(x - (ax + vx * t), z - (az + vz * t)) < width / 2 + margin:
            return True
    return False


def plan(L):
    rng = L.rng
    # --- Beach and village -------------------------------------------------------------
    L.thing("start", -66, 55, rot=30.0)
    L.prop("boat", -70, 61, rot=200, r=3.0, sink=0.3)
    L.prop("jetty", -86, 47, rot=90, r=0, sink=0.0, y=1.0)
    for x, z in ((-60, 60), (-72, 40), (-58, 66), (-75, 55)):
        L.prop("rock_medium", x, z, r=1.0)
    L.thing("shrine", -61, 62, id="hearth_village", r=2.0, name="Hearth of Hestia")
    # The shore: nets drying by the boats, driftwood at the tide line, gulls over the bay.
    L.prop("fishing_nets", -73, 47, rot=105, r=2.0, group="Village")
    for x, z, rot in ((-77, 52, 20), (-76, 58, 140), (-74, 43, 75)):
        L.prop("driftwood", x, z, rot=rot, r=0, group="Village", sink=0.08)
    L.thing("birds", -90, 44, species="gull", count=6, radius=20.0, height=12.0)
    houses = [(-46, 28, 15), (-32, 29, -10), (-27, 44, 95), (-38, 52, 180), (-52, 48, 200), (-24, 34, 80)]
    for k, (x, z, rot) in enumerate(houses):
        L.prop("house_a" if k % 2 == 0 else "house_b", x, z, rot=rot, r=4.5, group="Village")
    L.prop("well", -40, 38, rot=0, r=1.2, group="Village")
    L.thing("npc", -37, 36, id="dion", rot=210.0, r=0.8)
    # Klotho's yard: the loom under the pergola, against her house.
    L.prop("house_a", -51, 11, rot=0, r=4.5, group="Village")
    L.prop("pergola", -49, 17.5, rot=0, r=0, group="Village")
    L.prop("loom", -50.5, 15.6, rot=180, r=1.0, group="Village")
    L.thing("npc", -48, 18.5, id="klotho", rot=200.0, r=0.8)
    for x, z in ((-44, 21), (-55, 20), (-45, 14)):
        L.prop("pithos" if rng.random() < 0.5 else "amphora", x, z, r=0.6, group="Village")
    for x, z, model in ((-30, 33, "crate"), (-29, 35, "sacks"), (-44, 45, "crate"), (-50, 41, "sacks"), (-35, 47, "pithos")):
        L.prop(model, x, z, r=0.7, group="Village")
    for k, (x, z) in enumerate(((-34, 40), (-43, 33), (-36, 30), (-48, 37), (-30, 47), (-41, 47))):
        L.thing("breakable", x, z, model="amphora" if k % 3 else "pithos", table="amphora", r=0.6)
    for x, z in ((-58, 30), (-20, 22), (-62, 38), (-18, 50), (-36, 60), (-56, 6), (-40, 8)):
        L.prop(rng.choice(["olive_tree_a", "olive_tree_b"]), x, z, r=2.0, group="Village")
    for x, z in ((-28, 24), (-60, 25), (-44, 58), (-22, 42)):
        L.prop(rng.choice(["cypress_a", "cypress_b"]), x, z, r=0.9, group="Village")
    for x, z in ((-33, 37), (-46, 42), (-26, 39)):
        L.prop("bush_oleander", x, z, r=0.8, group="Village")
    for x, z in ((-57, 33), (-33, 21), (-20, 46), (-58, 55), (-45, 6)):
        if L.free(x, z, 2.6) and not on_path(x, z, 1.5):
            L.prop("fig_tree", x, z, r=2.4, group="Village", scale=rng.uniform(0.9, 1.1))
    # Smoke from the hearths of three houses (Klotho's among them).
    for x, z in ((-46, 28), (-38, 52), (-51, 11)):
        L.thing("smoke", x, z, height=4.3)
    L.thing("zone", -42, 38, name="Elaion", subtitle="An olive village above the wine-dark sea", radius=24.0, music="village", ambience="shore",
            mood="village")

    # --- Olive terraces -------------------------------------------------------------------
    L.thing("zone", 12, 42, name="The Olive Terraces", subtitle="", radius=26.0, music="field", ambience="cicadas", mood="terraces")
    # Dry-stone walls at the foot of each bank: a segment, then two segments' gap
    # (staggered from terrace to terrace), so the banks can be climbed anywhere.
    for level in range(1, 6):
        x = riser_x(level)
        for k, zz in enumerate(range(14, 74, 4)):
            z = zz + 2.0
            if (k + level) % 3 != 0:
                continue
            if math.hypot(x - 12, z - 42) > 25 or not walkable(x, z) or on_path(x, z, 2.0) or features(x, z)[0] > -4.0:
                continue
            L.prop("stone_wall", x - 0.6, z, rot=90, r=0.0, group="Terraces", sink=0.4)
    for row in range(-10, 36, 7):
        for col in range(16, 70, 7):
            x = row + rng.uniform(-1.2, 1.2)
            z = col + rng.uniform(-1.2, 1.2)
            if math.hypot(x - 12, z - 42) > 27 or on_path(x, z, 3.0) or not L.free(x, z, 2.2):
                continue
            L.prop(rng.choice(["olive_tree_a", "olive_tree_b", "olive_tree_c"]), x, z, r=2.4, scale=rng.uniform(0.85, 1.15), group="Terraces")
    for k, (x, z) in enumerate(((4, 58), (6, 60), (2, 61))):
        L.thing("breakable", x, z, model="pithos" if k == 1 else "amphora", table="amphora", r=0.7)
    L.prop("house_b", 0, 63, rot=40, r=4.5, group="Terraces")
    L.thing("chest", 24, 60, table="chest", rot=200.0, r=1.0)
    packs = [
        ((-2, 32), ["shade_hoplite", "shade_hoplite", "shade_swordsman"], 1),
        ((14, 50), ["styx_boar", "styx_boar"], 1),
        ((20, 30), ["shade_hoplite", "shade_swordsman", "shade_archer", "shade_hoplite"], 2),
        ((30, 50), ["shade_archer", "shade_hoplite", "shade_swordsman"], 2),
        ((6, 22), ["styx_boar", "styx_boar", "styx_boar"], 2),
        ((36, 36), ["shade_hoplite", "shade_hoplite", "shade_swordsman", "shade_archer", "shade_hoplite"], 3),
    ]
    for (x, z), pack, level in packs:
        L.thing("spawner", x, z, pack=pack, level=level, radius=15.0)

    # --- Cypress road ----------------------------------------------------------------------
    L.thing("zone", 52, -4, name="The Cypress Road", subtitle="", radius=12.0, music="field", ambience="wind", mood="road")
    # Cypress rows on both sides of the road, never on it.
    for a_name, b_name in (("terrace_top", "road_a"), ("road_a", "road_b"), ("road_b", "necropolis")):
        ax, az = ZONES[a_name][0], ZONES[a_name][1]
        bx, bz = ZONES[b_name][0], ZONES[b_name][1]
        length = math.hypot(bx - ax, bz - az)
        nx, nz = -(bz - az) / length, (bx - ax) / length
        for k in range(int(length / 6.0) + 1):
            t = k * 6.0 / length
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            for side in (-1, 1):
                px, pz = x + nx * side * 5.2, z + nz * side * 5.2
                if L.free(px, pz, 1.0) and not on_path(px, pz, 0.8) and L.h(px, pz) > 1.0:
                    L.prop(rng.choice(["cypress_a", "cypress_b"]), px, pz, r=1.0, group="Road", scale=rng.uniform(0.9, 1.1))
    L.prop("stele_a", 49, 2, rot=90, r=0.6, group="Road")
    # Herms, Hermes' pillars, mark the road as they marked every road in Hellas.
    for x, z, rot in ((47.6, 9.0, 80), (57.6, -13.0, 260), (45.0, -21.5, 60)):
        if L.free(x, z, 1.0) and not on_path(x, z, 0.6):
            L.prop("herm", x, z, rot=rot, r=0.8, group="Road")
    L.thing("spawner", 53, -10, pack=["shade_archer", "shade_archer", "shade_hoplite"], level=3, radius=16.0)

    # --- Necropolis -------------------------------------------------------------------------
    L.thing("zone", 30, -42, name="Necropolis of the Forgotten Siege", subtitle="Where the dead walk", radius=22.0, music="necropolis",
            ambience="necropolis", fog=True, mood="necropolis")
    # The siege's arms still standing in the earth; crows wheeling over the graves.
    placed = 0
    for i in range(60):
        if placed >= 7:
            break
        x, z = rng.uniform(12, 50), rng.uniform(-58, -28)
        if walkable(x, z) and L.free(x, z, 1.4) and not on_path(x, z, 1.0):
            L.prop("battle_debris_a" if placed % 2 else "battle_debris_b", x, z, r=1.2, group="Necropolis", sink=0.02)
            placed += 1
    L.thing("birds", 32, -44, species="crow", count=7, radius=16.0, height=11.0)
    L.thing("shrine", 42, -26, id="hearth_necropolis", r=2.0, name="Hearth of Hestia")
    L.prop("tholos", 60, -67, rot=150, r=6.5, group="Necropolis", sink=0.2)
    for row in range(5):
        for col in range(6):
            x = 14 + col * 5.0 + rng.uniform(-0.6, 0.6)
            z = -54 + row * 5.2 + rng.uniform(-0.6, 0.6)
            if not walkable(x, z) or not L.free(x, z, 0.9) or math.hypot(x - 30, z - 42) < 3:
                continue
            if abs(x - 30) < 3.5 and z > -50:
                continue
            model = rng.choice(["stele_a", "stele_b", "stele_a", "sarcophagus"])
            L.prop(model, x, z, rot=rng.uniform(-12, 12) + (90 if model == "sarcophagus" else 0), r=0.9, group="Necropolis")
    for x, z in ((20, -30), (42, -50), (26, -58), (38, -34)):
        L.prop(rng.choice(["column_broken", "column_stump"]), x, z, r=0.8, group="Necropolis")
    L.prop("column_fallen", 18, -45, rot=30, r=0, group="Necropolis")
    for x, z in ((12, -36), (48, -40), (24, -24), (40, -60), (10, -50)):
        L.prop(rng.choice(["cypress_a", "cypress_b"]), x, z, r=1.0, group="Necropolis")
    for k, (x, z) in enumerate(((44, -46), (22, -36), (34, -56))):
        L.thing("breakable", x, z, model="krater" if k == 0 else "amphora", table="amphora", r=0.6)
    L.thing("chest", 60, -50, table="chest", rot=240.0, r=1.0)
    for (x, z), pack, level in (
        ((26, -30), ["shade_hoplite", "shade_swordsman", "shade_archer", "shade_swordsman"], 3),
        ((16, -46), ["shade_hoplite", "shade_hoplite", "shade_archer"], 3),
        ((40, -48), ["shade_swordsman", "shade_swordsman", "shade_hoplite", "shade_archer", "shade_archer"], 4),
        ((30, -56), ["shade_hoplite", "shade_archer", "shade_hoplite"], 4),
    ):
        L.thing("spawner", x, z, pack=pack, level=level, radius=14.0)
    L.thing("spawner", 53, -53, pack=["captain_lykos", "shade_hoplite", "shade_hoplite", "shade_archer"], level=5, radius=15.0, no_champion=True)

    # --- Sanctuary ---------------------------------------------------------------------------
    L.thing("gate", 11.4, -76.6, rot=25.0, r=0)
    for k in range(3):
        t = k / 2
        x = 9 + (6 - 9) * t
        z = -83 + (-96 - -83) * t
        for side in (-1, 1):
            L.prop("column" if (k + side) % 3 else "column_broken", x + side * 6.0, z, rot=0, r=0.9, group="Sanctuary")
    L.thing("zone", 7, -86, name="Sanctuary of the Moirai", subtitle="", radius=12.0, music="sanctuary", ambience="wind", mood="sanctuary")
    L.prop("temple_ruin", -9, -88, rot=90, r=0, group="Sanctuary")
    for k, (model, x) in enumerate((("moira_klotho", 2.0), ("moira_lachesis", 7.0), ("moira_atropos", 12.0))):
        z = -93.5 + (1.0 if k == 1 else 0.0)
        L.prop(model, x, z, rot=0, r=1.2, group="Sanctuary")
        L.prop("votives", x, z + 1.6, rot=rng.uniform(-20, 20), r=0, group="Sanctuary", sink=0.0)
    # Acanthus, the leaf of the Corinthian capital, grows out of the ruins.
    for x, z in ((-4, -83), (-4.5, -92), (-13, -82.5), (-14, -93), (1, -77.5), (16, -82), (-2, -95.5), (14.5, -95)):
        L.scatter_point("acanthus", x, z, rng.uniform(0.9, 1.3))
    for x, z in ((0, -80), (14, -84)):
        L.thing("brazier", x, z, r=0.6)
    # A last hearth before the bull: a fallen hero wakes in the court, not back in
    # the necropolis (21 m from the arena's middle, outside its reach).
    L.thing("shrine", 0, -86, id="hearth_sanctuary", r=2.0, name="Hearth of Hestia")
    # The arena: a ring of columns the bull can be baited into.
    for k in range(10):
        a = math.tau * k / 10 + 0.3
        x, z = 4 + math.cos(a) * 13.5, -107 + math.sin(a) * 13.5
        if z > -96 and abs(x - 5) < 6:
            continue
        L.prop("column" if k % 3 else "column_broken", x, z, rot=0, r=0.9, group="Arena")
    L.prop("forge_pit", 4, -110, rot=0, r=0, group="Arena", sink=0.15)
    for k in range(6):
        a = math.tau * k / 6
        L.thing("brazier", 4 + math.cos(a) * 17.5, -107 + math.sin(a) * 17.5, r=0.6)
    # The bull fights inside the column ring (centre 4, -107; columns at 13.5 m).
    L.thing("boss", 4, -112, id="bronze_bull", level=7, arena=[4, -107], arena_radius=15.0, rot=0.0)
    L.thing("zone", 4, -105, name="Khalkotauros", subtitle="The Bronze Bull of Hephaestus", radius=13.0, music="boss", ambience="forge", boss=True,
            mood="arena")

    # --- the land around: trees and rocks on the slopes ------------------------------------------
    for i in range(1300):
        x = rng.uniform(X0 + 8, X1 - 8)
        z = rng.uniform(Z0 + 8, Z1 - 8)
        d = features(x, z)[0]
        h = L.h(x, z)
        if d < 1.5 or h < 1.0 or not L.free(x, z, 1.5):
            continue
        roll = rng.random()
        if d > 14 and roll < 0.25:
            continue
        if roll < 0.22:
            L.prop(rng.choice(["rock_large", "rock_cliff", "rock_medium"]), x, z, r=2.5, group="Wilds", scale=rng.uniform(0.8, 1.4), sink=0.4)
        elif roll < 0.47:
            L.prop(rng.choice(["olive_tree_a", "olive_tree_b", "olive_tree_c"]), x, z, r=2.2, group="Wilds", scale=rng.uniform(0.8, 1.2))
        elif roll < 0.6:
            L.prop(rng.choice(["cypress_a", "cypress_b"]), x, z, r=1.0, group="Wilds")
        elif roll < 0.66:
            L.prop("umbrella_pine", x, z, r=3.0, group="Wilds", scale=rng.uniform(0.85, 1.15))
        elif roll < 0.76:
            L.prop(rng.choice(["aleppo_pine_a", "aleppo_pine_b"]), x, z, r=2.4, group="Wilds", scale=rng.uniform(0.85, 1.2))
        else:
            L.prop(rng.choice(["bush_myrtle", "bush_dry", "bush_oleander", "bush_broom"]), x, z, r=0.8, group="Wilds", sink=0.1)
    # Rocks inside the walkable areas' edges, for silhouette.
    for i in range(160):
        x = rng.uniform(-75, 70)
        z = rng.uniform(-115, 75)
        d = features(x, z)[0]
        if -1.0 < d < 3.0 and L.free(x, z, 1.0) and L.h(x, z) > 0.8:
            L.prop(rng.choice(["rock_small", "rock_medium", "bush_dry", "bush_myrtle"]), x, z, r=0.8, group="Edges", sink=0.15)

    # --- the shore: reeds where land meets water, pebbles and dry grass above them ------------
    for i in range(3000):
        x = rng.uniform(-105, -38)
        z = rng.uniform(-25, 90)
        h = L.h(x, z)
        if not 0.15 < h < 1.3 or not L.free(x, z, 0.5):
            continue
        if h < 0.7:
            L.scatter_point("reeds" if rng.random() < 0.7 else "pebbles", x, z, rng.uniform(0.8, 1.2))
        elif rng.random() < 0.5:
            L.scatter_point(rng.choice(["pebbles", "grass_dry", "thyme"]), x, z, rng.uniform(0.8, 1.2))

    # --- grass, flowers and undergrowth --------------------------------------------------------
    for i in range(26000):
        x = rng.uniform(-90, 80)
        z = rng.uniform(-125, 85)
        d, walk, kind, path_kind = features(x, z)
        h = L.h(x, z)
        if h < 1.6 or kind in ("sanctuary", "arena") and d < 0:
            continue
        if not L.free(x, z, 0.4):
            continue
        if path_kind and d < -1.0:
            # The worn middle of a path stays bare; its edges gather pebbles.
            if d > -1.8 and rng.random() < 0.35:
                L.scatter_point("pebbles", x, z, rng.uniform(0.7, 1.1))
            continue
        if kind == "necropolis" and d < 2:
            L.scatter_point(rng.choice(["asphodel", "asphodel", "grass_dry", "grass_tall"]), x, z, rng.uniform(0.8, 1.3))
        elif kind == "terraces" and d < 0:
            L.scatter_point(rng.choice(["grass_green", "grass_green", "grass_poppy", "grass_dry", "clover", "wildflowers"]), x, z,
                            rng.uniform(0.8, 1.3))
        elif kind in ("village", "coast") and d < 1:
            L.scatter_point(rng.choice(["grass_green", "grass_dry", "clover", "thyme", "wildflowers"]), x, z, rng.uniform(0.8, 1.3))
        elif d < 2:
            L.scatter_point(rng.choice(["grass_dry", "grass_dry", "grass_green", "grass_daisy", "grass_tall", "thyme"]), x, z,
                            rng.uniform(0.8, 1.4))
        elif d < 9:
            L.scatter_point(rng.choice(["grass_dry", "grass_tall", "grass_tall", "thyme", "bush_broom", "grass_daisy"]), x, z,
                            rng.uniform(0.8, 1.4))

    # --- a route through the level for automated play-throughs -------------------------------------
    route = []
    for name in ("beach", "village", "klotho", "village", "terraces", "terrace_top", "road_a", "road_b", "necropolis", "tholos",
                 "necropolis", "stairs_foot", "gate", "court", "arena"):
        x, z = ZONES[name][0], ZONES[name][1]
        route.append([x, round(L.h(x, z), 2), z])
    return route


def write_map(L, route, nx, nz):
    """A top-down picture: ground colours, props as dots, spawners red, route gold."""
    import numpy as np
    scale = 3
    w, h = nx * scale // 2, nz * scale // 2
    img = np.zeros((h, w, 3), dtype=np.float32)
    for py in range(h):
        z = Z0 + (py / h) * (Z1 - Z0)
        for px in range(w):
            x = X0 + (px / w) * (X1 - X0)
            hh = L.h(x, z)
            sw, glow = surface(x, z, hh, 0.0)
            col = kit.PALETTE.entry(sw)["srgb"]
            shade = 0.75 + 0.25 * min(1.0, max(0.0, hh / 25.0))
            img[py, px] = (col[0] * shade, col[1] * shade, col[2] * shade) if hh > 0 else (0.15, 0.35, 0.55)

    def dot(x, z, color, r=1):
        px = int((x - X0) / (X1 - X0) * w)
        py = int((z - Z0) / (Z1 - Z0) * h)
        img[max(0, py - r):py + r + 1, max(0, px - r):px + r + 1] = color

    for item in L.items:
        x, _, z = item["pos"]
        color = {"spawner": (0.9, 0.1, 0.1), "npc": (0.2, 0.4, 1.0), "shrine": (1.0, 0.5, 0.1), "chest": (1.0, 0.9, 0.2),
                 "boss": (1.0, 0.0, 0.6), "start": (1.0, 1.0, 1.0), "gate": (0.6, 0.2, 0.9)}.get(item["type"], (0.15, 0.2, 0.1))
        dot(x, z, color, 2 if item["type"] != "prop" else 0)
    for x, _, z in route:
        dot(x, z, (1.0, 0.8, 0.2), 1)
    rows = [bytes((np.clip(row, 0, 1) * 255).astype(np.uint8).tobytes()) for row in img]
    out = os.path.join(kit.ROOT, ".shots", "elaion_map.png")
    kit.write_png(out, w, h, rows)
    return out


MINIMAP_WIDTH = 1024
# Things the game draws with a model of its own (Godot loads it in place of the mark).
THING_MODELS = {"shrine": "hearth_of_hestia", "chest": "chest", "gate": "sanctuary_gate", "brazier": "brazier"}


def render_minimap(L):
    """The level from straight above for the in-game minimap and full map: the ground
    and every prop in their palette colours, lit by the low western sun so the hills
    read. Written to assets/ui/minimap/elaion.png, covering X0..X1 (left to right) by
    Z0..Z1 (top to bottom, north up)."""
    from mathutils import Matrix
    scene = bpy.context.scene
    # The ground and the sea are in the scene already: give them materials that render.
    terrain = bpy.data.objects["Terrain-col"]
    ground = terrain.data.materials[0]
    ground.use_nodes = True
    nodes, links = ground.node_tree.nodes, ground.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    colour = nodes.new("ShaderNodeVertexColor")
    colour.layer_name = "Color"
    # Where you can walk stays bright; the wild land around falls back, so paths and
    # places read at a glance. (The terrain is exported already: darkening its colours
    # here touches only this picture.)
    mesh = terrain.data
    shade = [1.0 - 0.75 * kit.smoothstep(0.0, 4.0, features(v.co.x, -v.co.y)[0]) for v in mesh.vertices]
    attr = mesh.color_attributes["Color"]
    if attr.domain == "CORNER":
        for loop in mesh.loops:
            c = attr.data[loop.index].color
            s = shade[loop.vertex_index]
            attr.data[loop.index].color = (c[0] * s, c[1] * s, c[2] * s, c[3])
    else:
        for i, s in enumerate(shade):
            c = attr.data[i].color
            attr.data[i].color = (c[0] * s, c[1] * s, c[2] * s, c[3])
    mesh.update()  # or the render draws the copy evaluated for the export
    links.new(colour.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    water = bpy.data.objects["Sea"].data.materials[0]
    water.use_nodes = True
    wbsdf = water.node_tree.nodes.get("Principled BSDF")
    wbsdf.inputs["Base Color"].default_value = (0.014, 0.11, 0.26, 1.0)
    wbsdf.inputs["Roughness"].default_value = 0.35
    # Every prop: each model imported once, its parts stamped at every placement.
    palette = kit.palette_material("Palette")
    templates = {}
    for item in L.items:
        slug = item.get("model") if item["type"] in ("prop", "breakable") else THING_MODELS.get(item["type"])
        if not slug:
            continue
        if slug not in templates:
            path = kit.model_path("props", slug)
            if not os.path.exists(path):
                path = kit.model_path("items", slug)
            if not os.path.exists(path):
                templates[slug] = []
                continue
            before, materials = set(bpy.data.objects), set(bpy.data.materials)
            bpy.ops.import_scene.gltf(filepath=path)
            for m in set(bpy.data.materials) - materials:
                m.name = "Imported_" + m.name
            parts = []
            for obj in set(bpy.data.objects) - before:
                if obj.type == "MESH" and "col" not in obj.name.lower():
                    for i, m in enumerate(obj.data.materials):
                        if m and m.name.startswith(("Imported_Palette", "Imported_Foliage")):
                            obj.data.materials[i] = palette
                    parts.append((obj.data, obj.matrix_world.copy()))
                obj.hide_render = True  # the template itself stays at the origin, unseen
            templates[slug] = parts
        x, y, z = item["pos"]
        place = (Matrix.Translation((x, -z, y)) @ Matrix.Rotation(math.radians(item.get("rot", 0.0)), 4, "Z")
                 @ Matrix.Scale(item.get("scale", 1.0), 4))
        for data, local in templates[slug]:
            obj = bpy.data.objects.new(slug, data)
            obj.matrix_world = place @ local
            scene.collection.objects.link(obj)
    # The golden-hour sun from the west-south-west, a cool sky to fill the shade.
    sun_data = bpy.data.lights.new("MapSun", "SUN")
    sun_data.energy = 4.2
    sun_data.color = (1.0, 0.9, 0.78)
    sun_data.angle = math.radians(3.0)
    sun = bpy.data.objects.new("MapSun", sun_data)
    sun.rotation_euler = (math.radians(52), 0.0, math.radians(-67.5))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("MapSky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.38, 0.5, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    scene.world = world
    # A camera looking straight down over the whole map.
    width, depth = X1 - X0, Z1 - Z0
    cam_data = bpy.data.cameras.new("MapCamera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(width, depth)
    cam_data.clip_end = 1000.0
    cam = bpy.data.objects.new("MapCamera", cam_data)
    cam.location = ((X0 + X1) / 2, -(Z0 + Z1) / 2, 400.0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = MINIMAP_WIDTH
    scene.render.resolution_y = round(MINIMAP_WIDTH * depth / width)
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    out = os.path.join(kit.ROOT, "assets", "ui", "minimap", "elaion.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    return out


def main():
    kit.clear_scene()
    heights, nx, nz = build_terrain()
    build_sea()
    out = kit.export_glb(kit.model_path("level", "elaion_terrain"), vertex_colors=True)
    kit.log("level", f"terrain {nx} x {nz} vertices -> {os.path.relpath(out, kit.ROOT)}")
    L = Layout(heights, nx, nz)
    route = plan(L)
    layout = {"_doc": "Generated by tools/blender/level/elaion.py; npm run level turns it into src/world/elaion/elaion.tscn.",
              "bounds": [X0, Z0, X1, Z1], "items": L.items, "scatter": L.scatter, "route": route}
    path = os.path.join(kit.ROOT, "data", "level", "elaion_layout.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(layout, handle, separators=(",", ":"))
    counts = {}
    for item in L.items:
        counts[item["type"]] = counts.get(item["type"], 0) + 1
    kit.log("level", f"layout: {counts}, scatter: { {k: len(v) for k, v in L.scatter.items()} }")
    kit.log("level", f"map -> {os.path.relpath(write_map(L, route, nx, nz), kit.ROOT)}")
    kit.log("level", f"minimap -> {os.path.relpath(render_minimap(L), kit.ROOT)}")


kit.run(main)
