"""Items seen only on the ground and in the bag (the hero wears armour as mesh
variants of hero.glb): chiton, linothorax, muscle cuirass, leather wraps, bronze
greaves, rings, the owl pendant, the two draughts, a pile of drachmae, and the quest
items: the Seal of the Sanctuary and the First Blade of Atropos.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def export(slug):
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def ellipse(z, rx, ry, n=12):
    return [(math.cos(math.tau * i / n) * rx, math.sin(math.tau * i / n) * ry, z) for i in range(n)]


def torso(m, swatch, bands=(), flaps=None):
    m.loft([ellipse(0.0, 0.17, 0.13), ellipse(0.12, 0.19, 0.135), ellipse(0.26, 0.23, 0.155), ellipse(0.38, 0.245, 0.16),
            ellipse(0.46, 0.21, 0.14)], swatch, caps=False, double=True)
    for z, sw in bands:
        m.loft([ellipse(z, 0.235, 0.158), ellipse(z + 0.035, 0.24, 0.16)], sw, caps=False)
    if flaps:
        for sx in (1, -1):
            m.box((0.13 * sx, 0.0, 0.48), (0.13, 0.3, 0.04), flaps, rotation=(0, -18 * sx, 0))


def chiton():
    kit.clear_scene()
    m = kit.Mesh("chiton")
    # Folded linen with a red border.
    for i in range(3):
        m.box((0, 0, 0.04 + i * 0.07), (0.6 - i * 0.04, 0.42 - i * 0.03, 0.06), "linen" if i % 2 == 0 else "linen_shadow", bevel=0.015)
    m.box((0, -0.19, 0.18), (0.56, 0.02, 0.04), "wool_red")
    m.finish()
    export("chiton")


def linothorax():
    kit.clear_scene()
    m = kit.Mesh("linothorax")
    torso(m, "linen", bands=((0.3, "wool_red"), (0.04, "wool_red")), flaps="linen")
    for i in range(10):
        a = math.tau * i / 10
        m.box((math.cos(a) * 0.19, math.sin(a) * 0.14, -0.1), (0.07, 0.015, 0.2), "linen" if i % 2 else "linen_shadow",
              rotation=(0, 0, math.degrees(a) + 90))
    m.finish()
    export("linothorax")


def muscle_cuirass():
    kit.clear_scene()
    m = kit.Mesh("muscle_cuirass")
    torso(m, "bronze", flaps=None)
    for x in (-0.09, 0.09):
        m.sphere((x, -0.135, 0.33), 0.08, "bronze", scale=(1.1, 0.45, 0.75), segments=10, rings=6, smooth=True)
    for z in (0.12, 0.19):
        m.box((0, -0.15, z), (0.16, 0.02, 0.02), "bronze_dark")
    m.box((0, -0.15, 0.24), (0.02, 0.02, 0.2), "bronze_dark")
    for i in range(10):
        a = math.tau * i / 10
        m.box((math.cos(a) * 0.19, math.sin(a) * 0.14, -0.1), (0.07, 0.015, 0.2), "leather" if i % 2 else "leather_dark",
              rotation=(0, 0, math.degrees(a) + 90))
    m.finish()
    export("muscle_cuirass")


def bronze_greaves():
    kit.clear_scene()
    m = kit.Mesh("bronze_greaves")
    for x in (-0.09, 0.09):
        with m.at(location=(x, 0, 0)):
            m.lathe([(0.05, 0.0), (0.06, 0.12), (0.075, 0.26), (0.06, 0.4), (0.07, 0.44)], "bronze", segments=10)
            m.sphere((0, -0.05, 0.42), 0.04, "bronze_dark", scale=(1, 0.6, 0.8), segments=6, rings=4)
    m.finish()
    export("bronze_greaves")


def leather_wraps():
    kit.clear_scene()
    m = kit.Mesh("leather_wraps")
    for x in (-0.09, 0.09):
        for i in range(5):
            with m.at(location=(x, 0, 0)):
                m.cylinder((0, 0, i * 0.08), (0, 0, i * 0.08 + 0.07), 0.055 + i * 0.003, 0.057 + i * 0.003, "leather" if i % 2 == 0 else "leather_dark",
                           segments=9)
    m.finish()
    export("leather_wraps")


def ring(slug, metal, stone):
    kit.clear_scene()
    m = kit.Mesh(slug)
    m.torus((0, 0, 0.1), 0.09, 0.022, metal, segments=16, sides=6, rotation=(90, 0, 0))
    m.ico((0, 0, 0.21), 0.035, stone, subdivisions=1)
    m.finish()
    export(slug)


def owl_pendant():
    kit.clear_scene()
    m = kit.Mesh("owl_pendant")
    m.tube([(-0.14, 0, 0.32), (-0.08, 0, 0.42), (0.0, 0, 0.45), (0.08, 0, 0.42), (0.14, 0, 0.32)], 0.008, "rope", segments=4)
    with m.at(location=(0, 0, 0.18), rotation=(90, 0, 0)):
        m.cylinder((0, 0, -0.015), (0, 0, 0.015), 0.12, 0.12, "silver", segments=16)
        m.cylinder((0, 0, 0.015), (0, 0, 0.022), 0.09, 0.09, "bronze", segments=14)
        for x in (-0.035, 0.035):
            m.cylinder((x, 0.02, 0.022), (x, 0.02, 0.03), 0.025, 0.025, "gold", segments=10)
            m.cylinder((x, 0.02, 0.03), (x, 0.02, 0.034), 0.01, 0.01, "black_glaze", segments=8)
    m.finish()
    export("owl_pendant")


def potion(slug, liquid, body):
    kit.clear_scene()
    m = kit.Mesh(slug)
    # An aryballos: a round oil flask with a narrow neck, sealed with wax.
    m.lathe([(0.04, 0.0), (0.11, 0.04), (0.13, 0.12), (0.11, 0.2), (0.04, 0.25), (0.035, 0.31), (0.06, 0.33), (0.0, 0.34)], body, segments=12,
            pattern=lambda band, k: "black_glaze" if band == 2 and k % 2 == 0 else None)
    m.sphere((0, 0, 0.34), 0.045, liquid, scale=(1, 1, 0.6), segments=8, rings=4)
    m.box((0, -0.12, 0.13), (0.07, 0.03, 0.07), liquid)
    m.finish()
    export(slug)


def coins():
    kit.clear_scene()
    rng = random.Random(3)
    m = kit.Mesh("coins")
    for i in range(9):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, 0.12)
        z = 0.008 + (i // 3) * 0.016
        m.cylinder((math.cos(a) * d, math.sin(a) * d, z), (math.cos(a) * d, math.sin(a) * d, z + 0.012), 0.05, 0.05, "gold" if i % 3 else "silver",
                   segments=10)
    m.finish()
    export("coins")


def seal():
    kit.clear_scene()
    m = kit.Mesh("seal_of_sanctuary")
    with m.at(location=(0, 0, 0.14), rotation=(90, 0, 0)):
        m.cylinder((0, 0, -0.02), (0, 0, 0.02), 0.14, 0.14, "bronze", segments=18)
        m.torus((0, 0, 0.022), 0.11, 0.008, "gold", segments=18, sides=4)
        m.cylinder((0, -0.08, 0.022), (0, 0.08, 0.022), 0.008, 0.008, "gold", segments=4)
        m.cylinder((0, 0.02, 0.022), (0, 0.02, 0.032), 0.03, 0.03, "ichor_glow", segments=10)
    m.finish()
    export("seal_of_sanctuary")


def blade_of_atropos():
    kit.clear_scene()
    m = kit.Mesh("blade_of_atropos")
    # One blade of the shears: a long curved golden blade with its ring handle.
    outline = [(0.0, 0.0), (0.05, 0.05), (0.07, 0.25), (0.06, 0.45), (0.02, 0.62), (-0.01, 0.6), (0.0, 0.4), (-0.01, 0.2)]
    with m.at(location=(0, 0.006, 0.12), rotation=(90, 0, 0)):
        m.extrude(outline, 0.012, "gold")
        m.extrude([(0.03, 0.1), (0.05, 0.12), (0.055, 0.45), (0.03, 0.55)], 0.016, "ichor_glow")
    m.torus((0.0, 0, 0.06), 0.07, 0.014, "gold", segments=14, sides=4, rotation=(90, 0, 0))
    m.finish()
    export("blade_of_atropos")


def main():
    chiton()
    linothorax()
    muscle_cuirass()
    bronze_greaves()
    leather_wraps()
    ring("bronze_ring", "bronze", "wool_red")
    ring("silver_ring", "silver", "styx_glow")
    owl_pendant()
    potion("potion_health", "poppy", "clay")
    potion("potion_ichor", "ichor_glow", "black_glaze")
    coins()
    seal()
    blade_of_atropos()


kit.run(main)
