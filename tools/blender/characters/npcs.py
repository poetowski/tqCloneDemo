"""The people of Elaion, on the humanoid rig:
  klotho.glb  "old Klothia": the Spinner in disguise. Hunched, an indigo veil over
              white hair, a violet dress, a golden spindle in hand ("weaver" style).
  dion.glb    Dion the fisherman: ochre chiton, straw petasos hat, a short beard
              ("villager" style).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import humanoid  # noqa: E402
import kit  # noqa: E402


def ellipse(z, rx, ry, n=12, cy=0.0):
    return [(math.cos(math.tau * i / n) * rx, cy + math.sin(math.tau * i / n) * ry, z) for i in range(n)]


def person(name, p, robe, robe_hem, skin, hair, long_robe=True):
    bones = list(humanoid.skeleton(p))
    m = kit.Mesh(name, bones)
    z = p.z
    s = p.s
    trunk = humanoid.trunk(p)
    m.loft([ellipse(z["hip"] - 0.02, 0.16 * s, 0.12 * s), ellipse(z["waist"], 0.15 * s, 0.115 * s), ellipse(z["chest"], 0.19 * s, 0.13 * s),
            ellipse(z["shoulder"] - 0.02, 0.2 * s, 0.13 * s), ellipse(z["neck"] + 0.01, 0.09 * s, 0.07 * s)], robe, weigh=trunk)
    skirt = humanoid.skirt(p, flare_to_legs=0.45)
    bottom = 0.06 if long_robe else z["knee"] - 0.02
    m.loft([ellipse(z["waist"], 0.155 * s, 0.12 * s), ellipse(z["hip"] - 0.1, 0.21 * s, 0.17 * s), ellipse(bottom + 0.08, 0.27 * s, 0.22 * s)],
           robe, caps=False, weigh=skirt, double=True)
    m.loft([ellipse(bottom + 0.08, 0.27 * s, 0.22 * s), ellipse(bottom, 0.275 * s, 0.225 * s)], robe_hem, caps=False, weigh=skirt, double=True)
    m.cylinder((0, 0, z["waist"] - 0.02), (0, 0, z["waist"] + 0.03), 0.158 * s, 0.155 * s, "rope", segments=10, squash=0.78, weigh=trunk)
    m.cylinder((0, 0, z["neck"] - 0.03), (0, 0, z["head"] + 0.04), 0.05 * s, 0.045 * s, skin, segments=7, weigh="Neck")
    hz = z["head"] + 0.13 * s
    m.sphere((0, -0.005, hz), 0.115 * s, skin, scale=(0.92, 1.0, 1.1), segments=10, rings=7, weigh="Head", smooth=True)
    m.sphere((0, 0.02, hz + 0.03 * s), 0.12 * s, hair, scale=(0.97, 1.0, 0.9), segments=10, rings=6, weigh="Head")
    for x in (-0.04, 0.04):
        m.sphere((x * s, -0.1 * s, hz + 0.01), 0.014 * s, "eye_dark", segments=6, rings=4, weigh="Head")
    m.box((0, -0.118 * s, hz - 0.01), (0.024 * s, 0.03 * s, 0.05 * s), skin, weigh="Head")
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        x = p.arm_x * sign
        arm = humanoid.arm(p, side)
        m.cylinder((x, 0, z["elbow"] - 0.02), (x, 0, z["shoulder"] + 0.02), 0.055 * s, 0.065 * s, robe, segments=8, ring_step=0.05, weigh=arm)
        m.cylinder((x, 0, z["wrist"]), (x, 0, z["elbow"] + 0.02), 0.04 * s, 0.05 * s, skin, segments=7, ring_step=0.05, weigh=arm)
        m.box((x, -0.005, z["wrist"] - 0.05 * s), (0.05 * s, 0.075 * s, 0.09 * s), skin, weigh=f"{side}Hand")
        hip = p.hip_x * sign
        leg = humanoid.leg(p, side)
        m.cylinder((hip, 0, 0.1), (hip, 0, z["hip"]), 0.045 * s, 0.075 * s, skin, segments=7, ring_step=0.06, weigh=leg)
        m.box((hip, -0.04, 0.03), (0.09 * s, 0.22 * s, 0.06), "leather", weigh=f"{side}Foot")
    return m


def klotho():
    kit.clear_scene()
    p = humanoid.Proportions(height=1.6, shoulder_x=0.2, hip_x=0.09)
    arm = humanoid.build_armature(p)
    m = person("Klotho", p, "wool_violet", "gold", "skin_old", "hair_white")
    # The indigo veil over head and shoulders.
    z = p.z
    hz = z["head"] + 0.13 * p.s
    m.loft([ellipse(hz + 0.14, 0.05, 0.05, cy=0.02), ellipse(hz + 0.07, 0.14, 0.14, cy=0.02), ellipse(hz - 0.05, 0.15, 0.15, cy=0.04),
            ellipse(z["neck"], 0.21, 0.16, cy=0.03), ellipse(z["chest"] + 0.05, 0.26, 0.19, cy=0.04)], "wool_indigo", caps=False,
           weigh=kit.along_z(("Head", "Neck", z["head"] + 0.02), ("Neck", "Chest", z["neck"] - 0.04)), double=True)
    # The spindle and its golden thread.
    x = -p.arm_x
    m.cylinder((x, -0.06, z["wrist"] - 0.25), (x, -0.06, z["wrist"] + 0.12), 0.012, 0.012, "wood", segments=5, weigh="RightHand")
    m.sphere((x, -0.06, z["wrist"] - 0.2), 0.05, "gold", scale=(1, 1, 0.5), segments=8, rings=4, weigh="RightHand")
    m.tube([(x, -0.06, z["wrist"] + 0.12), (x + 0.15, -0.12, z["wrist"] + 0.3), (x + 0.3, -0.1, z["wrist"] + 0.2)], 0.006, "ichor_glow",
           segments=3, weigh="RightHand")
    obj = m.finish(armature=arm)
    humanoid.build_animations(arm, style="weaver")
    out = kit.export_glb(kit.model_path("characters", "klotho"), animations=True)
    kit.report("asset", "klotho", out)


def dion():
    kit.clear_scene()
    p = humanoid.Proportions(height=1.78, shoulder_x=0.23, hip_x=0.1)
    arm = humanoid.build_armature(p)
    m = person("Dion", p, "wool_ochre", "terracotta_dark", "skin", "hair_dark", long_robe=False)
    z = p.z
    hz = z["head"] + 0.13 * p.s
    m.sphere((0, -0.05, hz - 0.08), 0.08, "hair_dark", scale=(1.05, 0.95, 0.8), segments=8, rings=5, weigh="Head")
    # A straw petasos: the wide-brimmed traveller's hat.
    m.lathe([(0.0, hz + 0.16), (0.1, hz + 0.15), (0.13, hz + 0.08), (0.3, hz + 0.05), (0.3, hz + 0.035), (0.12, hz + 0.06), (0.0, hz + 0.06)],
            "straw", segments=14, weigh="Head")
    m.cylinder((0, 0, hz + 0.075), (0, 0, hz + 0.095), 0.122, 0.122, "wool_red", segments=14, weigh="Head")
    obj = m.finish(armature=arm)
    humanoid.build_animations(arm, style="villager")
    out = kit.export_glb(kit.model_path("characters", "dion"), animations=True)
    kit.report("asset", "dion", out)


def main():
    klotho()
    dion()


kit.run(main)
