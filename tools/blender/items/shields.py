"""Shields: the hoplite aspis (round, bowl-shaped, bronze rim, a painted emblem),
the light crescent pelte, and the Unthreaded's corroded aspis.

Modelled facing -Y (the front) with the centre at the origin and the arm band
behind (+Y); data/attachments.json straps them to the left forearm.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def front(m):
    """A frame whose +Z points out of the shield's face (world -Y)."""
    return m.at(rotation=(90, 0, 0))


def emblem_lambda(m, swatch, z):
    """Λ for Lakedaimon, painted on the face."""
    with front(m):
        with m.at(location=(0, 0, z)):
            m.extrude([(-0.17, -0.16), (-0.11, -0.16), (0.0, 0.1), (0.11, -0.16), (0.17, -0.16), (0.03, 0.18), (-0.03, 0.18)], 0.008, swatch)


def emblem_spindle(m, swatch, accent, z):
    """The hero's own sign: a spindle with a wound thread."""
    with front(m):
        with m.at(location=(0, 0, z)):
            m.extrude([(-0.012, -0.22), (0.012, -0.22), (0.012, 0.22), (-0.012, 0.22)], 0.008, swatch)
            m.cylinder((0, -0.1, 0.0), (0, -0.1, 0.012), 0.06, 0.06, swatch, segments=10)
            m.torus((0, 0.12, 0.009), 0.045, 0.008, accent, segments=12, sides=4)
            m.torus((0, 0.0, 0.009), 0.075, 0.008, accent, segments=14, sides=4)


def aspis(slug="aspis", rim="bronze", face="terracotta", emblem="lambda", ink="black_glaze", accent="gold"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    radius = 0.45
    with front(m):
        # Convex face: a shallow bowl, then the flat rim (itea) of the hoplon.
        m.lathe([(0.0, 0.075), (0.12, 0.07), (0.26, 0.052), (0.37, 0.02), (radius - 0.04, 0.0)], face, segments=24, caps=False)
        m.lathe([(radius - 0.04, 0.0), (radius, 0.005), (radius + 0.004, -0.02), (radius - 0.05, -0.03)], rim, segments=24, caps=False)
        # Back: the inside of the bowl.
        m.lathe([(radius - 0.05, -0.03), (0.36, -0.006), (0.22, 0.03), (0.0, 0.045)], "wood_dark", segments=24, caps=False)
        m.torus((0, 0, 0.004), radius - 0.01, 0.012, rim, segments=28, sides=5)
    if emblem == "lambda":
        emblem_lambda(m, ink, 0.07)
    elif emblem == "spindle":
        emblem_spindle(m, ink, accent, 0.07)
    elif emblem == "eye":
        with front(m):
            m.cylinder((0, 0, 0.068), (0, 0, 0.078), 0.13, 0.13, ink, segments=16)
            m.cylinder((0, 0, 0.074), (0, 0, 0.084), 0.06, 0.06, accent, segments=12)
    # Porpax (arm band) and antilabe (hand grip) behind.
    m.box((0, 0.05, 0.0), (0.06, 0.03, 0.24), "bronze_dark")
    m.box((0.3, 0.045, 0.0), (0.03, 0.02, 0.1), "rope")
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def pelte(slug="pelte"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    # Crescent: the outer arc anticlockwise round the bottom, then the notch back
    # across the top.
    outline = []
    for i in range(17):
        a = math.radians(140 + 260 * i / 16)
        outline.append((math.cos(a) * 0.33, math.sin(a) * 0.33))
    for i in range(1, 8):
        b = math.radians(-20 - 140 * i / 8)
        outline.append((math.cos(b) * 0.2, 0.3 + math.sin(b) * 0.2))
    with front(m):
        m.extrude(outline, 0.03, "straw")
        with m.at(location=(0, 0, 0.03)):
            m.extrude([(x * 0.84, y * 0.84 - 0.01) for x, y in outline], 0.006, "wool_ochre")
    m.box((0, 0.03, 0.0), (0.05, 0.03, 0.2), "leather")
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def main():
    aspis()
    aspis("aspis_hero", face="clay", emblem="spindle", ink="black_glaze", accent="ichor_glow")
    aspis("aspis_rusted", rim="verdigris", face="stone_dark", emblem="eye", ink="shade_body", accent="styx_glow")
    pelte()


kit.run(main)
