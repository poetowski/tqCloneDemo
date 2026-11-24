"""Birds that circle over the land: gulls over the bay, crows over the necropolis.
No rig: a body and two wings, each wing its own object ("WingL", "WingR") whose
origin is the shoulder, so the game flaps them by turning them about the body's long
axis (src/world/birds.gd). The bird faces -Y in Blender (+Z in Godot).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def wing(name, side, span, chord, swatch, tip):
    """A wing reaching out along +X (side 1) or -X (side -1) from its shoulder at the
    object's origin: an inner panel and a swept tip, both double-sided."""
    m = kit.Mesh(name)
    s = side
    inner = [(0, 0.06, 0), (s * span * 0.55, 0.02, 0.02), (s * span * 0.55, chord * 0.85, 0.0), (0, chord, 0)]
    outer = [(s * span * 0.55, 0.02, 0.02), (s * span, chord * 0.3, 0.05), (s * span * 0.9, chord * 0.75, 0.03), (s * span * 0.55, chord * 0.85, 0.0)]
    m.polygon(inner if s > 0 else list(reversed(inner)), swatch, double=True)
    m.polygon(outer if s > 0 else list(reversed(outer)), tip, double=True)
    return m


def bird(slug, size, body, belly, wings, tips, beak):
    kit.clear_scene()
    m = kit.Mesh("Body")
    m.sphere((0, 0, 0), 0.12 * size, body, scale=(0.9, 2.1, 0.85), segments=8, rings=5)
    m.sphere((0, 0.02 * size, -0.03 * size), 0.1 * size, belly, scale=(0.85, 1.6, 0.7), segments=8, rings=4)
    m.sphere((0, -0.27 * size, 0.04 * size), 0.075 * size, body, segments=8, rings=5)
    m.cone((0, -0.33 * size, 0.035 * size), (0, -0.43 * size, 0.02 * size), 0.025 * size, beak, segments=5)
    m.polygon([(-0.06 * size, 0.22 * size, 0.0), (0.06 * size, 0.22 * size, 0.0), (0.09 * size, 0.38 * size, 0.0),
               (-0.09 * size, 0.38 * size, 0.0)], tips, double=True)  # the tail
    m.finish()
    for name, side in (("WingL", -1), ("WingR", 1)):
        w = wing(name, side, 0.6 * size, 0.24 * size, wings, tips).finish()
        w.location = (side * 0.07 * size, -0.12 * size, 0.04 * size)
    out = kit.export_glb(kit.model_path("characters", slug))
    kit.report("asset", slug, out)


def main():
    bird("gull", 1.0, "whitewash", "linen", "linen", "stone_dark", "wool_ochre")
    bird("crow", 0.8, "black_glaze", "basalt", "black_glaze", "ash", "basalt")


kit.run(main)
