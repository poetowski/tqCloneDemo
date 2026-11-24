"""Helmets: Corinthian (closed, eye slits, horsehair crest), Attic (open face, cheek
guards), pilos (conical cap), plus the Unthreaded's corroded Corinthian and the
captain's crested one.

Modelled facing -Y with the origin at the head bone's base (top of the neck); the
hero's head centre is 0.135 m above it. data/attachments.json puts them on "Head".
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402

SEG = 24
# Segment k of a lathe spans angles k*15..(k+1)*15 degrees from +X; the face
# (-Y) is at 270 degrees, between segments 17 and 18.
FACE = {17, 18}
EYES = {16, 19}


def crest(m, swatch, holder, height=1.0, back=0.0):
    pts = [(-0.13, 0.28), (-0.12, 0.38 * height + 0.0), (0.0, 0.3 + 0.14 * height), (0.15, 0.3 + 0.12 * height),
           (0.26 + back, 0.33), (0.22 + back, 0.27), (0.1, 0.31), (0.0, 0.325), (-0.08, 0.31)]
    with m.at(location=(-0.024, 0, 0), rotation=(90, 0, 90)):
        m.extrude(list(reversed(pts)), 0.048, swatch)
    m.box((0, 0.02, 0.315), (0.03, 0.2, 0.03), holder)


def corinthian(slug, metal="bronze", dark="eye_dark", plume="horsehair_red", holder="bronze_dark", plume_height=1.0):
    kit.clear_scene()
    m = kit.Mesh(slug)
    profile = [(0.128, -0.03), (0.148, 0.03), (0.156, 0.09), (0.158, 0.13), (0.157, 0.17), (0.15, 0.215), (0.135, 0.258),
               (0.1, 0.296), (0.05, 0.316), (0.0, 0.32)]

    def pattern(band, k):
        if band in (2, 3) and k in EYES:
            return dark
        if band in (0, 1) and k in FACE:
            return dark
        if band == 4 and k in (15, 16, 19, 20):
            return "bronze_dark" if metal == "bronze" else None
        return None

    with m.at(location=(0, 0.01, 0), scale=(0.97, 1.1, 1.0)):
        m.lathe(profile, metal, segments=SEG, caps=False, pattern=pattern)
    # Nose guard and the flared nape.
    m.box((0, -0.172, 0.11), (0.028, 0.02, 0.09), metal)
    m.lathe([(0.15, -0.02), (0.17, -0.06)], metal, segments=SEG, caps=False, center=(0, 0.02, 0))
    if plume:
        crest(m, plume, holder, height=plume_height)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def attic(slug="helm_attic", metal="bronze", plume=None):
    kit.clear_scene()
    m = kit.Mesh(slug)
    with m.at(location=(0, 0.01, 0), scale=(0.97, 1.1, 1.0)):
        m.lathe([(0.157, 0.15), (0.155, 0.19), (0.148, 0.23), (0.13, 0.266), (0.095, 0.298), (0.045, 0.316), (0.0, 0.32)], metal,
                segments=SEG, caps=False)
        # Brow ridge.
        m.torus((0, 0, 0.152), 0.157, 0.012, "bronze_dark", segments=SEG, sides=4)
        # Neck guard at the back.
        m.lathe([(0.157, 0.15), (0.16, 0.06), (0.18, 0.01)], metal, segments=SEG, caps=False,
                pattern=lambda band, k: "black_glaze" if 13 <= k <= 22 else None)
    # Hinged cheek guards, hanging down the sides of the face.
    for sign in (1, -1):
        with m.at(location=(0.148 * sign, -0.06, 0.0), rotation=(90, 0, 90)):
            m.extrude([(-0.07, 0.0), (0.06, 0.0), (0.07, 0.14), (0.0, 0.16), (-0.08, 0.15)] if sign > 0 else
                      [(-0.07, 0.0), (0.06, 0.0), (0.07, 0.14), (0.0, 0.16), (-0.08, 0.15)], 0.012, metal)
    if plume:
        crest(m, plume, "bronze_dark", height=0.7)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def pilos(slug="helm_pilos", metal="bronze"):
    kit.clear_scene()
    m = kit.Mesh(slug)
    with m.at(location=(0, 0.01, 0), scale=(0.97, 1.05, 1.0)):
        m.lathe([(0.168, 0.135), (0.16, 0.15), (0.15, 0.2), (0.12, 0.27), (0.07, 0.35), (0.02, 0.41), (0.0, 0.42)], metal, segments=SEG)
        m.torus((0, 0, 0.14), 0.166, 0.012, "bronze_dark", segments=SEG, sides=4)
    m.finish()
    out = kit.export_glb(kit.model_path("items", slug))
    kit.report("asset", slug, out)


def main():
    corinthian("helm_corinthian")
    corinthian("helm_corinthian_rusted", metal="verdigris", dark="styx_glow", plume="shade_cloth", holder="bronze_rust",
               plume_height=0.6)
    corinthian("helm_corinthian_captain", metal="bronze_dark", dark="styx_glow", plume="horsehair_black", holder="gold",
               plume_height=1.5)
    attic()
    attic("helm_attic_crested", plume="horsehair_red")
    pilos()


kit.run(main)
