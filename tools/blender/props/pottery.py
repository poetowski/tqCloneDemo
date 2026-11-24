"""Black-figure pottery: amphora, pithos (storage jar) and krater (mixing bowl).
Breakable props in Elaion: clicking one shatters it (see src/world/props/breakable.gd).

Bands follow the black-figure scheme (docs/ART_BIBLE.md): clay body, black glaze
foot and neck, a tongue band on the shoulder and a checker band on the belly.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402

SEGMENTS = 14


def bands(spec):
    """spec: list of (band index set, pattern function or swatch)."""
    def pattern(band, segment):
        for indices, rule in spec:
            if band in indices:
                return rule(segment) if callable(rule) else rule
        return None
    return pattern


def tongues(segment):
    return "black_glaze" if segment % 2 == 0 else None


def checker(segment):
    return "black_glaze" if segment % 2 == 1 else None


def meander_a(segment):
    return "black_glaze" if segment % 4 in (0, 1) else None


def meander_b(segment):
    return "black_glaze" if segment % 4 in (1, 2) else None


def amphora():
    kit.clear_scene()
    m = kit.Mesh("Amphora")
    profile = [
        (0.08, 0.0), (0.09, 0.025), (0.055, 0.05),            # foot (bands 0-1)
        (0.075, 0.09), (0.14, 0.17), (0.195, 0.28),           # lower body, black (2-4)
        (0.218, 0.38), (0.222, 0.43), (0.222, 0.47),          # meander band (5-7)
        (0.21, 0.56), (0.185, 0.64),                          # figure zone (8-9)
        (0.15, 0.7), (0.1, 0.75),                             # shoulder tongues (10-11)
        (0.07, 0.79), (0.066, 0.91),                          # neck (12-13)
        (0.092, 0.94), (0.088, 0.98), (0.055, 0.98),          # lip (14-16)
    ]
    m.lathe(profile, "clay", segments=20, cap_swatch="black_glaze", pattern=bands([
        ({0, 1, 2, 3, 4, 12, 13, 14, 15, 16}, "black_glaze"),
        ({5}, "black_glaze"),
        ({6}, meander_a),
        ({7}, meander_b),
        ({10}, tongues),
    ]))
    for side in (-1, 1):
        points = [(side * 0.07, 0, 0.92), (side * 0.15, 0, 0.93), (side * 0.19, 0, 0.86), (side * 0.18, 0, 0.74), (side * 0.15, 0, 0.67)]
        m.tube(points, 0.018, "black_glaze", segments=6)
    m.finish()
    kit.collision_cylinder("Amphora", (0, 0, 0), (0, 0, 1.0), 0.2)
    out = kit.export_glb(kit.model_path("props", "amphora"))
    kit.report("asset", "amphora", out)


def pithos():
    kit.clear_scene()
    m = kit.Mesh("Pithos")
    profile = [
        (0.16, 0.0), (0.2, 0.05), (0.33, 0.25), (0.42, 0.55), (0.43, 0.8),
        (0.38, 1.05), (0.28, 1.25), (0.22, 1.32), (0.26, 1.36), (0.25, 1.42), (0.18, 1.42),
    ]
    m.lathe(profile, "terracotta", segments=16, cap_swatch="black_glaze", pattern=bands([
        ({0}, "terracotta_dark"),
        ({3}, lambda k: "clay" if k % 4 < 2 else None),
        ({7, 8}, "terracotta_dark"),
    ]))
    # Rope-moulded ribs: bands of raised clay, as on Cretan storage jars.
    for z, r in ((0.55, 0.425), (0.82, 0.435), (1.05, 0.385)):
        m.torus((0, 0, z), r, 0.022, "clay", segments=20, sides=4)
    m.finish()
    kit.collision_cylinder("Pithos", (0, 0, 0), (0, 0, 1.42), 0.42, segments=12)
    out = kit.export_glb(kit.model_path("props", "pithos"))
    kit.report("asset", "pithos", out)


def krater():
    kit.clear_scene()
    m = kit.Mesh("Krater")
    profile = [
        (0.13, 0.0), (0.14, 0.03), (0.06, 0.08), (0.06, 0.16), (0.12, 0.2),
        (0.24, 0.32), (0.3, 0.46), (0.31, 0.56), (0.34, 0.62), (0.33, 0.66), (0.29, 0.62),
    ]
    m.lathe(profile, "clay", segments=SEGMENTS + 2, caps=True, cap_swatch="black_glaze", pattern=bands([
        ({0, 1, 2, 3, 4, 8, 9}, "black_glaze"),
        ({6}, tongues),
    ]))
    # Volute handles.
    for side in (-1, 1):
        m.tube([(side * 0.27, 0, 0.42), (side * 0.37, 0, 0.5), (side * 0.38, 0, 0.62), (side * 0.32, 0, 0.66)], 0.02, "black_glaze")
    # Dark wine inside.
    m.cylinder((0, 0, 0.6), (0, 0, 0.605), 0.3, 0.3, "wool_red", segments=SEGMENTS + 2)
    m.finish()
    kit.collision_cylinder("Krater", (0, 0, 0), (0, 0, 0.66), 0.3)
    out = kit.export_glb(kit.model_path("props", "krater"))
    kit.report("asset", "krater", out)


def main():
    amphora()
    pithos()
    krater()


kit.run(main)
