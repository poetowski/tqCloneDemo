"""Weapons: dory (spear), xiphos (leaf sword), kopis (forward-curved blade), club,
bow, and the corroded versions the Unthreaded carry.

Modelled with the grip at the origin and the blade up +Z, its flat facing ±Y, so
data/attachments.json can put any of them in any hand. Each writes
assets/models/items/<slug>/<slug>.glb.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def shift_extrude(m, outline, thickness, swatch):
    """Extrude an XZ outline (x, z points, anticlockwise seen from -Y) across Y,
    centred on y = 0."""
    with m.at(location=(0, thickness / 2, 0), rotation=(90, 0, 0)):
        m.extrude([(x, z) for x, z in outline], thickness, swatch)


def dory(slug="dory", head="bronze", shaft="wood", butt="bronze", wrap="leather"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.cylinder((0, 0, -0.95), (0, 0, 1.32), 0.019, 0.016, shaft, segments=6)
    m.cylinder((0, 0, -0.07), (0, 0, 0.12), 0.024, 0.024, wrap, segments=6)
    # Leaf spearhead with a socket.
    m.cylinder((0, 0, 1.28), (0, 0, 1.38), 0.024, 0.02, head, segments=6)
    shift_extrude(m, [(0, 1.36), (0.045, 1.46), (0.035, 1.58), (0, 1.7), (-0.035, 1.58), (-0.045, 1.46)], 0.014, head)
    m.box((0, 0, 1.53), (0.012, 0.022, 0.3), head)
    # Sauroter: the butt-spike that let a hoplite plant his spear.
    m.cylinder((0, 0, -1.12), (0, 0, -0.93), 0.004, 0.022, butt, segments=6)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def xiphos(slug="xiphos", blade="bronze", guard="bronze", grip="leather", pommel="bronze"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    outline = [(0.024, 0.1), (0.03, 0.25), (0.04, 0.45), (0.036, 0.56), (0.0, 0.7), (-0.036, 0.56), (-0.04, 0.45), (-0.03, 0.25), (-0.024, 0.1)]
    shift_extrude(m, outline, 0.012, blade)
    m.box((0, 0, 0.4), (0.008, 0.016, 0.55), blade)
    m.box((0, 0, 0.09), (0.15, 0.035, 0.026), guard, bevel=0.006)
    m.cylinder((0, 0, -0.085), (0, 0, 0.08), 0.017, 0.015, grip, segments=6)
    m.sphere((0, 0, -0.1), 0.028, pommel, scale=(1.3, 1, 0.8), segments=8, rings=5)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def kopis(slug="kopis", blade="iron", grip="wood_dark", glow=None):
    kit.clear_scene()
    m = kit.Mesh(slug)
    # The edge bulges forward (-Y in a held hand is ahead); spine curves back.
    outline = [(0.018, 0.08), (0.05, 0.25), (0.075, 0.45), (0.07, 0.56), (0.02, 0.66), (-0.012, 0.6),
               (-0.02, 0.42), (-0.022, 0.25), (-0.015, 0.08)]
    shift_extrude(m, outline, 0.012, blade)
    if glow:
        shift_extrude(m, [(0.05, 0.27), (0.068, 0.44), (0.064, 0.53), (0.04, 0.5), (0.046, 0.3)], 0.016, glow)
    m.box((0, 0, 0.075), (0.11, 0.03, 0.02), "bronze")
    # Bird-head hook handle.
    m.cylinder((0, 0, -0.09), (0, 0, 0.07), 0.016, 0.016, grip, segments=6)
    m.tube([(0, 0, -0.08), (-0.02, 0, -0.12), (-0.05, 0, -0.12), (-0.06, 0, -0.09)], 0.014, grip, segments=6)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def club(slug="club"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.lathe([(0.02, -0.12), (0.024, -0.1), (0.026, 0.1), (0.038, 0.35), (0.06, 0.6), (0.07, 0.72), (0.05, 0.8), (0.0, 0.82)],
            "olive_bark", segments=8)
    rng = __import__("random").Random(7)
    for i in range(7):
        z = 0.35 + i * 0.065
        a = i * 2.3
        r = 0.04 + (z - 0.35) * 0.07
        m.ico((math.cos(a) * r, math.sin(a) * r, z), 0.022, "wood_dark", subdivisions=1)
    m.cylinder((0, 0, -0.1), (0, 0, 0.1), 0.03, 0.03, "leather", segments=6)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def bow(slug="bow", wood="wood_dark", tips="bone", string="linen"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    # A Scythian recurve: limbs sweep back (+Y) then flick forward at the tips.
    upper = [(0, 0.0, 0.05), (0, 0.03, 0.2), (0, 0.06, 0.36), (0, 0.04, 0.5), (0, -0.02, 0.58)]
    lower = [(x, y, -z) for x, y, z in upper]
    m.tube(upper, 0.016, wood, segments=5, taper=[0.02, 0.017, 0.014, 0.011, 0.008])
    m.tube(lower, 0.016, wood, segments=5, taper=[0.02, 0.017, 0.014, 0.011, 0.008])
    m.cylinder((0, 0, -0.07), (0, 0, 0.07), 0.024, 0.024, "leather", segments=6)
    m.sphere((0, -0.02, 0.58), 0.012, tips, segments=5, rings=3)
    m.sphere((0, -0.02, -0.58), 0.012, tips, segments=5, rings=3)
    m.cylinder((0, -0.015, -0.575), (0, -0.015, 0.575), 0.003, 0.003, string, segments=3, caps=False)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def arrow(slug="arrow"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    # Ghost arrow the archers loose: along +Z, glowing Styx teal.
    m.cylinder((0, 0, -0.35), (0, 0, 0.3), 0.007, 0.007, "shade_body", segments=4)
    m.cone((0, 0, 0.28), (0, 0, 0.4), 0.02, "styx_glow", segments=4)
    for a in (0, 120, 240):
        with m.at(rotation=(0, 0, a)):
            m.polygon([(0, 0.006, -0.34), (0, 0.035, -0.32), (0, 0.006, -0.2)], "styx_glow", double=True)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def main():
    dory()
    dory("dory_rusted", head="verdigris", shaft="wood_dark", butt="bronze_rust", wrap="shade_cloth")
    dory("dory_gilded", head="gold", shaft="wood_dark", butt="gold", wrap="wool_red")
    xiphos()
    xiphos("xiphos_rusted", blade="verdigris", guard="bronze_rust", grip="shade_cloth", pommel="bronze_rust")
    kopis()
    kopis("kopis_ember", blade="bronze_dark", grip="black_glaze", glow="fire_glow")
    club()
    bow()
    arrow()


kit.run(main)
