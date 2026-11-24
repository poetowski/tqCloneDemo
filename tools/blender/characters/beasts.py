"""Beasts on the quadruped rig:
  boar.glb         the Styx-touched boar: bristled hide, white tusks, teal-glowing eyes
                   and Styx cracks along its flanks.
  bronze_bull.glb  Khalkotauros, Hephaestus' bronze bull: riveted plates, gilded horns,
                   ember eyes, and a chest grille over its furnace heart. The furnace is
                   its own mesh ("Furnace") so Godot can make it flare in phase two.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402
import quadruped  # noqa: E402


def rings(b, spec, n=10):
    """spec: (y, z centre, half width, half height) from the snout back."""
    out = []
    for y, zc, rx, rz in spec:
        out.append([(math.cos(math.tau * i / n) * rx * b.s, y * b.s, (zc + math.sin(math.tau * i / n) * rz) * b.s) for i in range(n)])
    return out


def legs(m, b, bones, swatch, hoof, thick=1.0):
    for front in (True, False):
        for side, sx in (("Left", 1.0), ("Right", -1.0)):
            y = -0.35 if front else 0.42
            x = (0.17 if front else 0.16) * sx
            w = quadruped.leg_weights(b, front, side)
            top = 0.74 if front else 0.78
            m.cylinder(b.p(x, y, 0.42), b.p(x, y + (0.0 if front else 0.04), top), 0.065 * thick * b.s, 0.095 * thick * b.s, swatch,
                       segments=8, ring_step=0.08 * b.s, weigh=w)
            m.cylinder(b.p(x, y, 0.09), b.p(x, y, 0.44), 0.045 * thick * b.s, 0.06 * thick * b.s, swatch, segments=7, ring_step=0.08 * b.s, weigh=w)
            m.box(b.p(x, y - 0.02, 0.045), (0.11 * thick * b.s, 0.14 * thick * b.s, 0.09 * b.s), hoof,
                  weigh=f"{'Front' if front else 'Back'}{side}Foot")


def boar():
    kit.clear_scene()
    b = quadruped.Body(1.0)
    arm = quadruped.build_armature(b)
    bones = list(quadruped.skeleton(b))
    m = kit.Mesh("Boar", bones)
    body = quadruped.body_weights(b)
    spec = [(-1.02, 0.55, 0.06, 0.06), (-0.94, 0.58, 0.1, 0.1), (-0.78, 0.68, 0.17, 0.2), (-0.58, 0.8, 0.25, 0.3),
            (-0.36, 0.83, 0.28, 0.36), (-0.05, 0.77, 0.27, 0.31), (0.3, 0.75, 0.25, 0.28), (0.52, 0.73, 0.15, 0.17)]
    m.loft(rings(b, spec), "boar_hide", weigh=body)
    m.cylinder(b.p(0, -1.05, 0.55), b.p(0, -1.02, 0.55), 0.075, 0.075, "skin_old", segments=8, weigh="Head")
    for sx in (1, -1):
        # Tusks curving up, eyes glowing teal, small ears.
        m.tube([b.p(0.06 * sx, -0.95, 0.52), b.p(0.11 * sx, -1.0, 0.56), b.p(0.12 * sx, -0.98, 0.65)], 0.016, "tusk", segments=5,
               taper=[0.02, 0.014, 0.004], weigh="Head")
        m.sphere(b.p(0.11 * sx, -0.8, 0.76), 0.025, "styx_glow", segments=6, rings=4, weigh="Head")
        m.polygon([b.p(0.1 * sx, -0.68, 0.9), b.p(0.17 * sx, -0.62, 1.02), b.p(0.16 * sx, -0.6, 0.88)], "boar_bristle", double=True, weigh="Head")
        # Styx cracks on the flanks.
        for k, (y, z) in enumerate(((-0.25, 0.8), (0.0, 0.72), (0.2, 0.82))):
            m.box(b.p(0.27 * sx, y, z), (0.02, 0.18, 0.025), "styx_glow", rotation=(25 * (k - 1), 0, 0), weigh=body)
    for i in range(10):
        y = -0.62 + i * 0.1
        h = 0.12 if i < 5 else 0.07
        m.box(b.p(0, y, 1.08 - abs(y + 0.3) * 0.25), (0.05, 0.09, h), "boar_bristle", rotation=(-20, 0, 0), weigh=body)
    m.tube([b.p(0, 0.55, 0.78), b.p(0, 0.66, 0.66), b.p(0.02, 0.7, 0.55)], 0.015, "boar_bristle", segments=4, weigh="Tail")
    legs(m, b, bones, "boar_hide", "black_glaze")
    obj = m.finish(armature=arm)
    quadruped.build_animations(arm)
    out = kit.export_glb(kit.model_path("characters", "boar"), animations=True)
    kit.report("asset", "boar", out)


def bull():
    kit.clear_scene()
    b = quadruped.Body(2.9)
    arm = quadruped.build_armature(b)
    bones = list(quadruped.skeleton(b))
    m = kit.Mesh("Bull", bones)
    body = quadruped.body_weights(b)
    spec = [(-1.02, 0.6, 0.09, 0.1), (-0.95, 0.63, 0.13, 0.14), (-0.82, 0.7, 0.16, 0.18), (-0.62, 0.82, 0.24, 0.27),
            (-0.4, 0.86, 0.3, 0.36), (-0.15, 0.82, 0.28, 0.32), (0.15, 0.8, 0.26, 0.29), (0.42, 0.8, 0.25, 0.27), (0.56, 0.8, 0.15, 0.17)]
    m.loft(rings(b, spec, n=12), "bronze", weigh=body)
    # Plate seams and rivets.
    for y, zc, rx, rz in spec[2:-1]:
        ring = rings(b, [(y, zc, rx * 1.03, rz * 1.03)], n=12)[0]
        m.tube(ring + [ring[0]], 0.025 * b.s, "bronze_dark", segments=4, weigh=body)
        for p in ring[::2]:
            m.sphere(p, 0.012 * b.s, "gold", segments=5, rings=3, weigh=body)
    # The chest grille over the furnace, and the horns.
    for k in range(5):
        x = (-0.12 + k * 0.06) * b.s
        m.box((x, -0.62 * b.s, 0.78 * b.s), (0.025 * b.s, 0.03 * b.s, 0.3 * b.s), "iron", weigh="Chest")
    for sx in (1, -1):
        m.tube([b.p(0.08 * sx, -0.86, 0.82), b.p(0.2 * sx, -0.9, 0.86), b.p(0.3 * sx, -0.98, 0.95), b.p(0.3 * sx, -1.06, 1.06)], 0.035 * b.s,
               "gold", segments=6, taper=[0.04 * b.s, 0.032 * b.s, 0.02 * b.s, 0.006 * b.s], weigh="Head")
        m.sphere(b.p(0.12 * sx, -0.92, 0.76), 0.022 * b.s, "fire_glow", segments=6, rings=4, weigh="Head")
        m.sphere(b.p(0.04 * sx, -1.04, 0.6), 0.018 * b.s, "fire_glow", segments=5, rings=3, weigh="Head")
        # Gear joints at the shoulders and hips.
        for y, z in ((-0.35, 0.68), (0.42, 0.7)):
            m.torus(b.p(0.27 * sx, y, z), 0.07 * b.s, 0.018 * b.s, "bronze_dark", segments=10, sides=4, rotation=(0, 90, 0), weigh=body)
    for i in range(7):
        y = -0.7 + i * 0.09
        m.box(b.p(0, y, 1.14 - abs(y + 0.45) * 0.35), (0.05 * b.s, 0.12 * b.s, 0.1 * b.s), "bronze_dark", rotation=(-25, 0, 0), weigh=body)
    m.tube([b.p(0, 0.56, 0.86), b.p(0, 0.7, 0.7), b.p(0.03, 0.74, 0.45), b.p(0.0, 0.72, 0.3)], 0.02 * b.s, "bronze_dark", segments=5, weigh="Tail")
    m.sphere(b.p(0.0, 0.72, 0.28), 0.04 * b.s, "fire_glow", segments=6, rings=4, weigh="Tail")
    legs(m, b, bones, "bronze", "bronze_dark", thick=1.2)
    m.finish(armature=arm)
    furnace = kit.Mesh("Furnace", bones)
    furnace.sphere(b.p(0, -0.52, 0.8), 0.17 * b.s, "furnace", scale=(1.0, 0.6, 1.1), segments=10, rings=6, weigh="Chest")
    furnace.finish(armature=arm)
    quadruped.build_animations(arm)
    out = kit.export_glb(kit.model_path("characters", "bronze_bull"), animations=True)
    kit.report("asset", "bronze_bull", out)


def main():
    boar()
    bull()


kit.run(main)
