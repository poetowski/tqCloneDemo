"""Renders the game's pictures (docs/ART_BIBLE.md#ui), transparent PNGs:
  assets/icons/items/<icon>.png    every item base and mythic, from its own model,
                                   64 px per inventory cell (a 1x4 spear is 64x256)
  assets/icons/skills/<icon>.png   black-figure emblems on terracotta medallions
  assets/ui/title_logo.png         UNTHREADED in archaic straight-stroke capitals,
                                   built from geometry (no font files)
  assets/ui/icon.png               the window icon: a spindle wound with gold
Run with `npm run icons` (after `npm run models`).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402

CELL = 64
ITEM_DIR = os.path.join(kit.ASSETS, "icons", "items")
SKILL_DIR = os.path.join(kit.ASSETS, "icons", "skills")
UI_DIR = os.path.join(kit.ASSETS, "ui")


def setup(width, height, ambient=0.6):
    kit.clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = bpy.data.worlds.new("IconWorld")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.45, 0.52, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = ambient
    for name, energy, rot, colour in (("Key", 3.2, (50, 10, -40), (1.0, 0.93, 0.82)), ("Fill", 1.0, (60, 0, 140), (0.7, 0.8, 1.0)),
                                      ("Rim", 2.0, (-35, 0, 180), (1.0, 0.85, 0.6))):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        light.color = colour
        obj = bpy.data.objects.new(name, light)
        obj.rotation_euler = Euler([math.radians(a) for a in rot])
        scene.collection.objects.link(obj)


def import_glb(path):
    before = set(bpy.data.objects)
    mats_before = set(bpy.data.materials)
    bpy.ops.import_scene.gltf(filepath=path)
    for m in set(bpy.data.materials) - mats_before:
        m.name = "Imported_" + m.name
    palette = kit.palette_material("Palette")
    objects = [o for o in bpy.data.objects if o not in before]
    for obj in objects:
        if obj.type == "MESH":
            if "col" in obj.name.lower():
                obj.hide_render = True
            for slot in obj.material_slots:
                if slot.material and slot.material.name.startswith("Imported_Palette"):
                    slot.material = palette
    return objects


def pivot(objects, rotation):
    """Parents the model to an empty and turns it for its portrait."""
    empty = bpy.data.objects.new("Pivot", None)
    bpy.context.scene.collection.objects.link(empty)
    for obj in objects:
        if obj.parent is None:
            obj.parent = empty
    empty.rotation_euler = Euler([math.radians(a) for a in rotation])
    bpy.context.view_layer.update()
    return empty


def bounds(objects):
    low = Vector((math.inf,) * 3)
    high = Vector((-math.inf,) * 3)
    for obj in objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            low = Vector(map(min, low, p))
            high = Vector(map(max, high, p))
    return low, high


def shoot(low, high, path, width, height, margin=1.12):
    """An orthographic camera looking along +Y at the box, filling the frame."""
    scene = bpy.context.scene
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    size_x, size_z = high.x - low.x, high.z - low.z
    aspect = width / height
    data.ortho_scale = max(size_x, size_z * aspect) * margin if aspect >= 1 else max(size_x / aspect, size_z) * margin
    cam = bpy.data.objects.new("Cam", data)
    scene.collection.objects.link(cam)
    center = (low + high) / 2
    cam.location = (center.x, low.y - 10.0, center.z)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)


def item_icons():
    with open(os.path.join(kit.ROOT, "data", "items", "bases.json"), encoding="utf-8") as handle:
        bases = json.load(handle)
    with open(os.path.join(kit.ROOT, "data", "items", "uniques.json"), encoding="utf-8") as handle:
        uniques = json.load(handle)
    jobs = []
    for bid, base in bases.items():
        if bid.startswith("_"):
            continue
        jobs.append((base.get("icon", bid), base.get("model", bid), base.get("size", [1, 1]), base.get("slot", "")))
    for uid, data in uniques.items():
        if uid.startswith("_") or "model" not in data:
            continue
        base = bases[data["base"]]
        jobs.append((data["model"], data["model"], base.get("size", [1, 1]), base.get("slot", "")))
    done = 0
    for icon, model, size, slot in jobs:
        path = kit.model_path("items", model)
        if not os.path.exists(path):
            kit.log("icons", f"no model for {icon}")
            continue
        w, h = int(size[0]) * CELL, int(size[1]) * CELL
        setup(w, h)
        objects = import_glb(path)
        # Portrait angles: blades upright and flat to us, armour three-quarters.
        rotation = {"weapon": (0, -12, 8), "shield": (0, 0, -18), "head": (8, 0, -32), "chest": (6, 0, -25), "legs": (4, 0, -20),
                    "ring": (10, 0, -15), "amulet": (0, 0, -10), "potion": (8, 0, -20), "quest": (0, -20, 0)}.get(slot, (8, 0, -25))
        pivot(objects, rotation)
        low, high = bounds(objects)
        shoot(low, high, os.path.join(ITEM_DIR, f"{icon}.png"), w, h, margin=1.08 if slot == "weapon" else 1.2)
        done += 1
    # Coins for the purse.
    setup(CELL, CELL)
    objects = import_glb(kit.model_path("items", "coins"))
    pivot(objects, (35, 0, 0))
    low, high = bounds(objects)
    shoot(low, high, os.path.join(ITEM_DIR, "coins.png"), CELL, CELL, margin=1.25)
    kit.log("icons", f"{done + 1} item icons -> assets/icons/items/")


# --- skill emblems -------------------------------------------------------------------------

def medallion(m):
    """The terracotta disc with a black rim and a meander band, facing -Y."""
    with m.at(rotation=(90, 0, 0)):
        m.cylinder((0, 0, -0.05), (0, 0, 0.0), 1.0, 1.0, "black_glaze", segments=40)
        m.cylinder((0, 0, 0.0), (0, 0, 0.02), 0.92, 0.92, "clay", segments=40)
        for i in range(24):
            a = math.tau * i / 24
            with m.at(location=(math.cos(a) * 0.84, math.sin(a) * 0.84, 0.03), rotation=(0, 0, math.degrees(a))):
                m.box((0, 0, 0), (0.06, 0.13, 0.02), "black_glaze")
                m.box((0.04, 0.05, 0), (0.08, 0.03, 0.02), "black_glaze")


def flat(m, points, swatch, depth=0.04, z=0.05):
    """A flat black-figure shape on the medallion: points (x, up) seen from the front."""
    with m.at(location=(0, -z, 0), rotation=(90, 0, 0)):
        m.extrude(points, depth, swatch)


def stroke(m, a, b, width, swatch, z=0.06):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    nx, ny = -dy / length * width / 2, dx / length * width / 2
    flat(m, [(ax + nx, ay + ny), (ax - nx, ay - ny), (bx - nx, by - ny), (bx + nx, by + ny)][::-1], swatch, z=z)


def emblem(slug, draw):
    setup(128, 128, ambient=0.9)
    m = kit.Mesh(slug)
    medallion(m)
    draw(m)
    m.finish()
    low, high = bounds([o for o in bpy.data.objects if o.type == "MESH"])
    shoot(low, high, os.path.join(SKILL_DIR, f"{slug}.png"), 128, 128, margin=1.02)


def draw_lunge(m):
    stroke(m, (-0.62, -0.42), (0.55, 0.38), 0.07, "black_glaze")
    flat(m, [(0.5, 0.29), (0.72, 0.5), (0.58, 0.27)], "black_glaze", z=0.07)
    for k in range(3):
        stroke(m, (-0.65 + k * 0.08, -0.05 - k * 0.15), (-0.2 + k * 0.08, 0.25 - k * 0.15), 0.035, "gold", z=0.07)


def draw_bash(m):
    with m.at(location=(-0.08, -0.07, 0.02), rotation=(90, 0, 0)):
        m.cylinder((0, 0, 0), (0, 0, 0.05), 0.46, 0.46, "black_glaze", segments=28)
        m.cylinder((0, 0, 0.05), (0, 0, 0.07), 0.16, 0.16, "gold", segments=16)
    for a in (-35, 0, 35):
        r = math.radians(a)
        stroke(m, (0.45 * math.cos(r), 0.45 * math.sin(r)), (0.72 * math.cos(r), 0.72 * math.sin(r)), 0.05, "gold", z=0.07)


def draw_lash(m):
    pts = []
    for i in range(60):
        t = i / 59
        a = t * math.tau * 1.6
        r = 0.12 + 0.55 * t
        pts.append((math.cos(a) * r, -0.08, math.sin(a) * r))
    m.tube(pts, 0.035, "ichor_glow", segments=5)
    m.sphere((0, -0.1, 0), 0.1, "black_glaze", segments=10, rings=6)


def draw_war_cry(m):
    # A crested Corinthian helm in profile, shouting rays.
    flat(m, [(-0.3, -0.35), (0.25, -0.35), (0.3, 0.05), (0.2, 0.3), (-0.05, 0.4), (-0.3, 0.3), (-0.38, 0.0)], "black_glaze")
    flat(m, [(-0.35, 0.35), (0.3, 0.32), (0.35, 0.55), (-0.1, 0.62), (-0.45, 0.5)], "wool_red", z=0.07)
    flat(m, [(-0.05, -0.08), (0.12, -0.08), (0.12, 0.02), (-0.05, 0.02)], "clay", z=0.08)
    for a in (-30, -10, 10):
        r = math.radians(a)
        stroke(m, (0.38 * math.cos(r) + 0.05, 0.38 * math.sin(r) - 0.1), (0.7 * math.cos(r), 0.7 * math.sin(r) - 0.1), 0.045, "gold", z=0.07)


def draw_bound(m):
    for x in (-0.3, 0.3):
        flat(m, [(x - 0.17, -0.5), (x + 0.17, -0.5), (x + 0.14, 0.05), (x + 0.2, 0.25), (x, 0.42), (x - 0.2, 0.25), (x - 0.14, 0.05)],
             "black_glaze")
        with m.at(location=(x - 0.06, -0.1, 0.24), rotation=(90, 0, 0)):
            m.cylinder((0, 0, 0), (0, 0, 0.02), 0.035, 0.035, "styx_glow", segments=8)
        with m.at(location=(x + 0.06, -0.1, 0.24), rotation=(90, 0, 0)):
            m.cylinder((0, 0, 0), (0, 0, 0.02), 0.035, 0.035, "styx_glow", segments=8)
    m.tube([(-0.6, -0.1, -0.1), (-0.3, -0.1, 0.0), (0.0, -0.1, -0.2), (0.3, -0.1, 0.0), (0.6, -0.1, -0.1)], 0.03, "ichor_glow", segments=5)


def draw_mercy(m):
    # Shears closing on a gold thread.
    flat(m, [(-0.55, 0.5), (-0.45, 0.58), (0.12, 0.02), (0.02, -0.06)], "black_glaze")
    flat(m, [(-0.55, -0.5), (-0.45, -0.58), (0.12, -0.02), (0.02, 0.06)], "black_glaze", z=0.08)
    with m.at(location=(0.28, -0.06, 0.12), rotation=(90, 0, 0)):
        m.torus((0, 0, 0.02), 0.13, 0.035, "black_glaze", segments=16, sides=4)
    with m.at(location=(0.28, -0.06, -0.12), rotation=(90, 0, 0)):
        m.torus((0, 0, 0.02), 0.13, 0.035, "black_glaze", segments=16, sides=4)
    m.tube([(-0.75, -0.12, 0.25), (-0.2, -0.12, 0.0)], 0.025, "ichor_glow", segments=4)
    m.tube([(-0.12, -0.12, -0.04), (0.2, -0.12, -0.35)], 0.025, "ichor_glow", segments=4)


# --- the title -----------------------------------------------------------------------------

# Archaic capitals as straight strokes on a 0..1 x 0..1.4 box (curves are cut in facets).
LETTERS = {
    "U": [[(0, 1.4), (0, 0.25), (0.15, 0.0), (0.85, 0.0), (1.0, 0.25), (1.0, 1.4)]],
    "N": [[(0, 0), (0, 1.4), (1.0, 0.0), (1.0, 1.4)]],
    "T": [[(0, 1.4), (1.0, 1.4)], [(0.5, 1.4), (0.5, 0.0)]],
    "H": [[(0, 0), (0, 1.4)], [(1.0, 0), (1.0, 1.4)], [(0, 0.7), (1.0, 0.7)]],
    "R": [[(0, 0), (0, 1.4), (0.75, 1.4), (1.0, 1.15), (1.0, 0.95), (0.75, 0.7), (0.0, 0.7)], [(0.45, 0.7), (1.0, 0.0)]],
    "E": [[(1.0, 1.4), (0, 1.4), (0, 0), (1.0, 0)], [(0, 0.7), (0.75, 0.7)]],
    "A": [[(0, 0), (0.5, 1.4), (1.0, 0.0)], [(0.2, 0.55), (0.8, 0.55)]],
    "D": [[(0, 0), (0, 1.4), (0.6, 1.4), (1.0, 1.0), (1.0, 0.4), (0.6, 0.0), (0, 0)]],
}


def title_logo():
    width, height = 1600, 420
    setup(width, height, ambient=1.4)
    # Lit gold rather than mirror-metal: a mirror shows only the dark studio.
    letters = kit.flat_material("LogoGold", "gold", emission=0.35)
    letters.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = 0.35
    letters.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.35
    m = kit.Mesh("Title")
    text = "UNTHREADED"
    advance = 1.36
    total = advance * len(text) - 0.36
    stroke_w = 0.2
    for i, ch in enumerate(text):
        ox = i * advance - total / 2
        for path in LETTERS[ch]:
            for a, b in zip(path, path[1:]):
                ax, ay, bx, by = ox + a[0], a[1] - 0.7, ox + b[0], b[1] - 0.7
                dx, dy = bx - ax, by - ay
                length = math.hypot(dx, dy)
                ang = math.degrees(math.atan2(dy, dx))
                with m.at(location=((ax + bx) / 2, 0, (ay + by) / 2), rotation=(0, -ang, 0)):
                    m.box((0, 0, 0), (length + stroke_w, 0.22, stroke_w), "gold", bevel=0.03, material="LogoGold")
    # A gold thread weaves through the letters, cut in the middle.
    pts = [(-total / 2 - 0.8 + k * 0.4, -0.25 * math.cos(k * 0.9), math.sin(k * 0.7) * 0.55) for k in range(int((total + 1.6) / 0.4) + 1)]
    half = len(pts) // 2
    m.tube(pts[:half], 0.05, "ichor_glow", segments=5)
    m.tube(pts[half + 1:], 0.05, "ichor_glow", segments=5)
    m.finish()
    low, high = bounds([o for o in bpy.data.objects if o.type == "MESH"])
    shoot(low, high, os.path.join(UI_DIR, "title_logo.png"), width, height, margin=1.05)


def app_icon():
    setup(256, 256, ambient=0.9)
    m = kit.Mesh("Icon")
    medallion(m)
    stroke(m, (0.0, -0.62), (0.0, 0.62), 0.06, "black_glaze")
    with m.at(location=(0, -0.08, -0.35), rotation=(90, 0, 0)):
        m.cylinder((0, 0, 0), (0, 0, 0.06), 0.22, 0.22, "black_glaze", segments=20)
    pts = [(math.cos(t * 0.5) * (0.12 + 0.02 * math.sin(t)), -0.12, -0.1 + t * 0.03) for t in range(0, 22)]
    m.tube(pts, 0.03, "ichor_glow", segments=5)
    m.finish()
    low, high = bounds([o for o in bpy.data.objects if o.type == "MESH"])
    shoot(low, high, os.path.join(UI_DIR, "icon.png"), 256, 256, margin=1.02)


def main():
    item_icons()
    for slug, draw in (("lunge", draw_lunge), ("aspis_bash", draw_bash), ("fates_lash", draw_lash), ("war_cry", draw_war_cry),
                       ("bound_shades", draw_bound), ("atropos_mercy", draw_mercy)):
        emblem(slug, draw)
    kit.log("icons", "6 skill emblems -> assets/icons/skills/")
    title_logo()
    app_icon()
    kit.log("icons", "title logo and window icon -> assets/ui/")


kit.run(main)
