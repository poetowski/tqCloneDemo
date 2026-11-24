"""The Threadless: the hero, a young bearded hoplite of Elaion with a red chlamys and a
golden thread wound around the right forearm (docs/LORE.md).

One armature, several skinned meshes Godot shows or hides by equipment:
  Body (skin, head, linen chiton, sandals), Cloak, Thread,
  Cuirass_Linen, Cuirass_Bronze, Greaves_Bronze, Wraps_Leather.
Helmets, weapons and shields are separate item models attached to bones.
Writes assets/models/characters/hero/hero.glb with every humanoid animation.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import humanoid  # noqa: E402
import kit  # noqa: E402

P = humanoid.Proportions(height=1.85, shoulder_x=0.24, hip_x=0.105)
BONES = list(humanoid.skeleton(P))


def ellipse(z, rx, ry, n=12, cy=0.0, phase=0.0):
    return [(math.cos(math.tau * i / n + phase) * rx, cy + math.sin(math.tau * i / n + phase) * ry, z) for i in range(n)]


def torso_rings(scale=1.0, lift=0.0):
    s = scale
    return [
        ellipse(0.9 + lift, 0.165 * s, 0.125 * s),
        ellipse(1.0, 0.16 * s, 0.12 * s),
        ellipse(1.12, 0.18 * s, 0.128 * s),
        ellipse(1.25, 0.215 * s, 0.148 * s),
        ellipse(1.36, 0.232 * s, 0.15 * s),
        ellipse(1.43, 0.205 * s, 0.13 * s),
        ellipse(1.475, 0.1 * s, 0.08 * s),
    ]


def build_body():
    m = kit.Mesh("Body", BONES)
    trunk = humanoid.trunk(P)
    m.loft(torso_rings(), "linen", weigh=trunk)
    # Belt.
    m.cylinder((0, 0, 0.985), (0, 0, 1.035), 0.172, 0.168, "leather", segments=12, squash=0.76, weigh=trunk)
    m.box((0, -0.13, 1.01), (0.06, 0.02, 0.045), "bronze", weigh="Hips")
    # Chiton skirt, red hem.
    skirt = humanoid.skirt(P)
    m.loft([ellipse(0.99, 0.172, 0.13), ellipse(0.88, 0.205, 0.165), ellipse(0.72, 0.245, 0.2)], "linen", caps=False, weigh=skirt, double=True)
    m.loft([ellipse(0.72, 0.245, 0.2), ellipse(0.68, 0.252, 0.206)], "wool_red", caps=False, weigh=skirt, double=True)
    # Neck and head (the face looks toward -Y).
    m.cylinder((0, 0, 1.43), (0, 0, 1.6), 0.062, 0.056, "skin", segments=8,
               weigh=kit.along_z(("Neck", "Chest", 1.48), blend=0.03))
    head = "Head"
    m.sphere((0, -0.005, 1.705), 0.122, "skin", weigh=head, scale=(0.92, 1.0, 1.12), segments=12, rings=8, smooth=True)
    m.sphere((0, 0.02, 1.745), 0.13, "hair_dark", weigh=head, scale=(0.96, 1.0, 0.86), segments=12, rings=7)
    m.sphere((0, 0.06, 1.68), 0.115, "hair_dark", weigh=head, scale=(0.95, 0.8, 1.0), segments=10, rings=6)
    # Beard and moustache: a short dark beard, as on Archaic warriors.
    m.sphere((0, -0.055, 1.615), 0.085, "hair_dark", weigh=head, scale=(1.05, 0.95, 0.85), segments=10, rings=6)
    m.box((0, -0.118, 1.655), (0.075, 0.02, 0.016), "hair_dark", weigh=head)
    m.box((0, -0.125, 1.70), (0.026, 0.035, 0.06), "skin", weigh=head, rotation=(12, 0, 0))
    for x in (-0.042, 0.042):
        m.sphere((x, -0.108, 1.722), 0.016, "eye_dark", weigh=head, segments=6, rings=4)
        m.box((x, -0.112, 1.748), (0.04, 0.012, 0.012), "hair_dark", weigh=head)
        m.sphere((x * 2.9, 0.0, 1.70), 0.024, "skin", weigh=head, scale=(0.5, 1, 1.3), segments=6, rings=4)
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        x = P.arm_x * sign
        arm = humanoid.arm(P, side)
        m.sphere((x * 0.93, 0.0, 1.405), 0.082, "skin", weigh={"Chest": 0.35, f"{side}UpperArm": 0.65}, segments=10, rings=6, smooth=True)
        m.cylinder((x, 0, 1.115), (x, 0, 1.42), 0.056, 0.068, "skin", segments=8, ring_step=0.05, weigh=arm, smooth=True)
        m.cylinder((x, 0, 0.875), (x, 0, 1.14), 0.043, 0.054, "skin", segments=8, ring_step=0.05, weigh=arm, smooth=True)
        m.box((x, -0.008, 0.82), (0.058, 0.085, 0.105), "skin", weigh=f"{side}Hand", bevel=0.012)
        m.box((x - 0.035 * sign, -0.035, 0.85), (0.025, 0.03, 0.05), "skin", weigh=f"{side}Hand")
        # Leather bracer on the shield arm.
        if side == "Left":
            m.cylinder((x, 0, 0.9), (x, 0, 1.02), 0.05, 0.056, "leather", segments=8, weigh=arm)
        hip = P.hip_x * sign
        leg = humanoid.leg(P, side)
        m.cylinder((hip, 0, 0.47), (hip, 0, 0.93), 0.068, 0.092, "skin", segments=9, ring_step=0.05, weigh=leg, smooth=True)
        m.cylinder((hip, 0.008, 0.1), (hip, 0.008, 0.5), 0.046, 0.066, "skin", segments=9, ring_step=0.05, weigh=leg, smooth=True)
        m.sphere((hip, 0.02, 0.33), 0.06, "skin", weigh=leg, scale=(0.95, 0.9, 1.6), segments=8, rings=5, smooth=True)
        # Sandals: sole, straps.
        m.box((hip, -0.045, 0.03), (0.1, 0.25, 0.04), "leather", weigh=f"{side}Foot", bevel=0.01)
        m.box((hip, -0.03, 0.065), (0.085, 0.16, 0.05), "skin", weigh=f"{side}Foot")
        m.box((hip, -0.15, 0.045), (0.088, 0.07, 0.035), "skin", weigh=f"{side}Toes")
        m.cylinder((hip, 0.005, 0.08), (hip, 0.005, 0.15), 0.052, 0.05, "leather_dark", segments=8, weigh=leg)
    return m.finish()


def build_cloak():
    m = kit.Mesh("Cloak", BONES)
    rings = []
    for z, half_angle, radius, back in ((1.47, 75, 0.2, 0.0), (1.3, 82, 0.25, 0.05), (1.05, 86, 0.29, 0.08),
                                         (0.8, 88, 0.32, 0.11), (0.56, 90, 0.34, 0.13)):
        ring = []
        for i in range(9):
            a = math.radians(-half_angle + 2 * half_angle * i / 8)
            ring.append((math.sin(a) * radius, back + math.cos(a) * radius * 0.62, z))
        rings.append(ring)
    m.loft(rings, "wool_red", closed=False, caps=False, weigh=humanoid.cloak(P), double=True)
    # Gold fibula on the right shoulder.
    m.sphere((-0.17, -0.06, 1.44), 0.028, "gold", weigh="Chest", segments=8, rings=5)
    return m.finish()


def build_thread():
    m = kit.Mesh("Thread", BONES)
    x = -P.arm_x
    points = []
    for i in range(29):
        t = i / 28
        a = t * math.tau * 4
        points.append((x + math.cos(a) * 0.056, math.sin(a) * 0.056, 0.92 + t * 0.15))
    m.tube(points, 0.0075, "ichor_glow", segments=4, weigh="RightLowerArm")
    # A loose end hanging from the wrist.
    m.tube([(x + 0.05, 0.0, 0.93), (x + 0.07, -0.02, 0.86), (x + 0.06, -0.01, 0.79)], 0.005, "ichor_glow", segments=4,
           weigh={"RightLowerArm": 0.6, "RightHand": 0.4})
    return m.finish()


def pteruges(m, swatch_a, swatch_b):
    skirt = humanoid.skirt(P, flare_to_legs=0.7)
    for i in range(14):
        a = math.tau * i / 14
        x, y = math.cos(a) * 0.21, math.sin(a) * 0.165
        m.box((x * 1.05, y * 1.05, 0.83), (0.075, 0.018, 0.2), swatch_a if i % 2 == 0 else swatch_b,
              rotation=(0, 0, math.degrees(a) + 90), weigh=skirt)


def build_linen_cuirass():
    m = kit.Mesh("Cuirass_Linen", BONES)
    trunk = humanoid.trunk(P)
    rings = torso_rings(scale=1.075)[1:6]
    m.loft(rings, "linen", weigh=trunk)
    m.loft([ellipse(1.27, 0.235, 0.163), ellipse(1.31, 0.247, 0.164)], "wool_red", caps=False, weigh=trunk)
    m.loft([ellipse(1.0, 0.175, 0.13), ellipse(1.035, 0.176, 0.131)], "wool_red", caps=False, weigh=trunk)
    for sign in (1, -1):
        m.box((0.13 * sign, 0.0, 1.455), (0.13, 0.29, 0.04), "linen", rotation=(0, -18 * sign, 0), weigh="Chest")
        m.box((0.13 * sign, -0.13, 1.44), (0.11, 0.03, 0.05), "wool_red", rotation=(0, -18 * sign, 0), weigh="Chest")
    pteruges(m, "linen", "linen_shadow")
    return m.finish()


def build_bronze_cuirass():
    m = kit.Mesh("Cuirass_Bronze", BONES)
    trunk = humanoid.trunk(P)
    m.loft(torso_rings(scale=1.09)[1:6], "bronze", weigh=trunk)
    for x in (-0.09, 0.09):
        m.sphere((x, -0.13, 1.31), 0.085, "bronze", weigh="Chest", scale=(1.1, 0.45, 0.75), segments=10, rings=6, smooth=True)
    for z in (1.08, 1.15):
        m.box((0, -0.138, z), (0.17, 0.02, 0.022), "bronze_dark", weigh=trunk)
    m.box((0, -0.14, 1.215), (0.02, 0.02, 0.2), "bronze_dark", weigh=trunk)
    pteruges(m, "leather", "leather_dark")
    return m.finish()


def build_greaves(name, swatch, swatch_b):
    m = kit.Mesh(name, BONES)
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        hip = P.hip_x * sign
        leg = humanoid.leg(P, side)
        if swatch == "bronze":
            m.cylinder((hip, 0.0, 0.13), (hip, 0.0, 0.5), 0.056, 0.075, swatch, segments=9, ring_step=0.06, weigh=leg, squash=0.92)
            m.sphere((hip, -0.04, 0.5), 0.055, swatch_b, weigh=leg, scale=(1, 0.7, 0.8), segments=8, rings=5)
        else:
            for i in range(5):
                z0 = 0.13 + i * 0.07
                m.cylinder((hip, 0.008, z0), (hip, 0.008, z0 + 0.06), 0.053 + i * 0.003, 0.055 + i * 0.003,
                           swatch if i % 2 == 0 else swatch_b, segments=9, weigh=leg)
    return m.finish()


def main():
    kit.clear_scene()
    arm = humanoid.build_armature(P)
    for build in (build_body, build_cloak, build_thread, build_linen_cuirass, build_bronze_cuirass):
        obj = build()
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    for args in (("Greaves_Bronze", "bronze", "bronze_dark"), ("Wraps_Leather", "leather", "leather_dark")):
        obj = build_greaves(*args)
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    humanoid.build_animations(arm, style="hero")
    out = kit.export_glb(kit.model_path("characters", "hero"), animations=True)
    kit.report("asset", "hero", out)


kit.run(main)
