"""The Unthreaded: soldiers of a forgotten siege who cannot die. Gaunt skeletons with
a Styx-teal heart glowing through the ribs, tattered rags and corroded bronze.

Two models on the shared humanoid rig:
  shade.glb         hoplites and the captain (shambling style). Meshes: Bones, Rags,
                    Plate (corroded shoulder guards), Mantle (the captain's cloak,
                    hidden otherwise).
  shade_archer.glb  archers (bow style). Meshes: Bones, Rags, Cap, Quiver.
Helmets, weapons and shields come from the item models (rusted variants).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import humanoid  # noqa: E402
import kit  # noqa: E402

P = humanoid.Proportions(height=1.8, shoulder_x=0.22, hip_x=0.1)
BONES = list(humanoid.skeleton(P))
Z = P.z


def bone_limb(m, a, b, weigh, r=0.026, knob="bone_dark"):
    m.cylinder(a, b, r, r * 0.85, "bone", segments=6, ring_step=0.06, weigh=weigh)
    m.sphere(a, r * 1.5, knob, segments=6, rings=4, weigh=weigh)


def build_bones():
    m = kit.Mesh("Bones", BONES)
    trunk = humanoid.trunk(P)
    # Spine, pelvis, ribcage around the glowing heart.
    m.cylinder((0, 0.03, Z["hip"] - 0.02), (0, 0.03, Z["neck"] + 0.02), 0.028, 0.024, "bone_dark", segments=6, ring_step=0.06, weigh=trunk)
    m.sphere((0, 0.0, Z["hip"] + 0.02), 0.13, "bone", weigh="Hips", scale=(1.25, 0.75, 0.6), segments=8, rings=5)
    for i, (z, rx, ry) in enumerate(((1.14, 0.13, 0.1), (1.21, 0.155, 0.115), (1.28, 0.168, 0.12), (1.35, 0.165, 0.115), (1.41, 0.145, 0.1))):
        m.torus((0, 0.0, z * P.s), rx, 0.013, "bone", segments=14, sides=4, weigh="Chest" if z > 1.2 else trunk)
        if i == 0:
            continue
    m.box((0, -0.1, 1.28 * P.s), (0.035, 0.02, 0.24), "bone", weigh="Chest")
    m.sphere((0, 0.0, 1.27 * P.s), 0.065, "styx_glow", weigh="Chest", segments=8, rings=6)
    m.sphere((0, 0.06, 1.27 * P.s), 0.07, "shade_body", weigh="Chest", scale=(1.2, 0.6, 1.3), segments=8, rings=5)
    # Collarbones and shoulder knobs.
    for side, sign in (("Left", 1), ("Right", -1)):
        m.cylinder((0.02 * sign, -0.02, Z["shoulder"] - 0.03), (P.arm_x * sign, 0.0, Z["shoulder"]), 0.016, 0.016, "bone", segments=5,
                   weigh={"Chest": 0.6, f"{side}UpperArm": 0.4})
    # Skull: jaw, cheekbones, deep sockets with teal light.
    head = "Head"
    m.cylinder((0, 0, Z["neck"] - 0.02), (0, 0, Z["head"] + 0.04), 0.03, 0.028, "bone_dark", segments=6, weigh="Neck")
    m.sphere((0, 0.005, Z["head"] + 0.135), 0.11, "bone", weigh=head, scale=(0.88, 1.02, 1.0), segments=10, rings=7)
    m.box((0, -0.05, Z["head"] + 0.04), (0.11, 0.09, 0.055), "bone", weigh=head, bevel=0.01)
    for x in (-0.04, 0.04):
        m.sphere((x, -0.088, Z["head"] + 0.14), 0.03, "eye_dark", weigh=head, segments=6, rings=4)
        m.sphere((x, -0.1, Z["head"] + 0.14), 0.013, "styx_glow", weigh=head, segments=6, rings=4)
    m.box((0, -0.105, Z["head"] + 0.09), (0.04, 0.02, 0.012), "eye_dark", weigh=head)
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        x = P.arm_x * sign
        arm = humanoid.arm(P, side)
        bone_limb(m, (x, 0, Z["shoulder"]), (x, 0, Z["elbow"] + 0.02), arm, r=0.024)
        bone_limb(m, (x, 0, Z["elbow"]), (x, 0, Z["wrist"] + 0.02), arm, r=0.02)
        m.box((x, -0.01, Z["wrist"] - 0.05), (0.04, 0.06, 0.1), "bone_dark", weigh=f"{side}Hand")
        hip = P.hip_x * sign
        leg = humanoid.leg(P, side)
        bone_limb(m, (hip, 0, Z["hip"] - 0.03), (hip, 0, Z["knee"] + 0.02), leg, r=0.03)
        bone_limb(m, (hip, 0, Z["knee"]), (hip, 0, Z["ankle"] + 0.02), leg, r=0.025)
        m.box((hip, -0.05, 0.03), (0.07, 0.2, 0.05), "bone_dark", weigh=f"{side}Foot")
    return m.finish()


def build_rags():
    m = kit.Mesh("Rags", BONES)
    skirt = humanoid.skirt(P, flare_to_legs=0.7)
    # Torn chiton skirt: strips of uneven length.
    for i in range(12):
        a = math.tau * i / 12
        length = 0.22 + 0.12 * ((i * 7) % 5) / 4
        x, y = math.cos(a) * 0.19, math.sin(a) * 0.15
        m.box((x, y, Z["hip"] + 0.05 - length / 2), (0.1, 0.012, length), "shade_cloth", rotation=(0, 0, math.degrees(a) + 90),
              weigh=skirt, double=False)
    m.cylinder((0, 0, Z["hip"] + 0.02), (0, 0, Z["hip"] + 0.09), 0.17, 0.165, "leather_dark", segments=10, squash=0.8, weigh="Hips")
    # A tattered cloak hanging from one shoulder.
    rings = []
    for z, w, back in ((1.42, 0.16, 0.06), (1.2, 0.2, 0.12), (0.95, 0.22, 0.15), (0.72, 0.18, 0.17)):
        rings.append([(-0.05 - w + 2 * w * t / 4, back + 0.04 * math.sin(t * 1.7), z * P.s) for t in range(5)])
    m.loft(rings, "shade_cloth", closed=False, caps=False, weigh=humanoid.cloak(P), double=True)
    return m.finish()


def build_plate():
    m = kit.Mesh("Plate", BONES)
    for side, sign in (("Left", 1), ("Right", -1)):
        m.sphere((P.arm_x * 0.9 * sign, 0.0, Z["shoulder"] + 0.01), 0.075, "bronze_rust", weigh={"Chest": 0.4, f"{side}UpperArm": 0.6},
                 scale=(1.1, 1.0, 0.7), segments=8, rings=5)
        hip = P.hip_x * sign
        m.cylinder((hip, 0.0, 0.14), (hip, 0.0, 0.46), 0.04, 0.052, "verdigris", segments=8, squash=0.9, weigh=humanoid.leg(P, side))
    m.loft([[(math.cos(a) * 0.17, -0.05 + math.sin(a) * 0.06, z) for a in [math.radians(200 + 140 * k / 6) for k in range(7)]]
            for z in (1.12, 1.3, 1.42)], "bronze_rust", closed=False, caps=False, weigh="Chest", double=True)
    return m.finish()


def build_mantle():
    m = kit.Mesh("Mantle", BONES)
    rings = []
    for z, half_angle, radius, back in ((1.45, 80, 0.2, 0.0), (1.2, 85, 0.25, 0.06), (0.9, 88, 0.3, 0.1), (0.5, 90, 0.33, 0.13)):
        ring = []
        for i in range(9):
            a = math.radians(-half_angle + 2 * half_angle * i / 8)
            ring.append((math.sin(a) * radius, back + math.cos(a) * radius * 0.6, z * P.s))
        rings.append(ring)
    m.loft(rings, "wool_red", closed=False, caps=False, weigh=humanoid.cloak(P), double=True)
    m.torus((0, -0.02, 1.44 * P.s), 0.17, 0.02, "gold", segments=14, sides=4, weigh="Chest")
    return m.finish()


def build_cap():
    m = kit.Mesh("Cap", BONES)
    base = Z["head"] + 0.13
    m.lathe([(0.12, base - 0.03), (0.125, base + 0.04), (0.09, base + 0.12), (0.04, base + 0.2), (0.0, base + 0.24)], "leather_dark",
            segments=10, center=(0, 0.01, 0), weigh="Head")
    for sign in (1, -1):
        m.box((0.1 * sign, 0.0, base - 0.08), (0.03, 0.08, 0.12), "leather_dark", weigh="Head")
    return m.finish()


def build_quiver():
    m = kit.Mesh("Quiver", BONES)
    m.cylinder((0.08, 0.16, 0.95 * P.s), (0.14, 0.15, 1.45 * P.s), 0.05, 0.055, "leather", segments=8, weigh="Chest")
    for k in range(4):
        x = 0.12 + 0.012 * k
        m.cylinder((x, 0.15, 1.42 * P.s), (x + 0.01, 0.15, 1.56 * P.s), 0.005, 0.005, "shade_body", segments=4, weigh="Chest")
        m.cone((x + 0.01, 0.15, 1.55 * P.s), (x + 0.012, 0.15, 1.6 * P.s), 0.012, "styx_glow", segments=4, weigh="Chest")
    m.box((0.0, 0.0, 1.2 * P.s), (0.04, 0.2, 0.5), "leather_dark", rotation=(0, -35, 0), weigh="Chest")
    return m.finish()


def export(slug, builders, style):
    kit.clear_scene()
    arm = humanoid.build_armature(P)
    for build in builders:
        obj = build()
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    humanoid.build_animations(arm, style=style)
    out = kit.export_glb(kit.model_path("characters", slug), animations=True)
    kit.report("asset", slug, out)


def main():
    export("shade", (build_bones, build_rags, build_plate, build_mantle), "shade")
    export("shade_archer", (build_bones, build_rags, build_cap, build_quiver), "archer")


kit.run(main)
