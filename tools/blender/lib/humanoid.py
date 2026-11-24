"""The humanoid skeleton and the animation library every humanoid shares (hero,
shades, archers, NPCs).

Bones use the names of Godot's SkeletonProfileHumanoid. The body faces -Y (glTF
turns that into Godot's MODEL_FRONT, +Z); the character's left is +X. Every bone is
rolled so that, in a pose:
  pitch  (about local X) swings the bone forward: limbs swing forward, the spine
         bows, the head nods, a knee bends with a NEGATIVE lower-leg pitch, an elbow
         with a POSITIVE lower-arm pitch, a foot's positive pitch lifts the toes;
  twist  (about the bone's length): on the spine, positive turns the chest's front
         toward the character's left (right shoulder forward);
  spread (about the bone's front axis): lifts a left limb out to its side; on the
         spine, positive leans to the character's right.
Right-side bones take the same signs as left ones (kit.mirrored flips them).
"loc:Hips" / "loc:Root" offsets are in bone axes: x left, y up, z forward.

Animations (Godot looks them up by name; see src/actors/actor_body.gd):
  idle, combat_idle, walk, run, attack_thrust, attack_slash, bash, lash, war_cry,
  lunge, cast, hit, die, rise, stunned, shoot, talk, weave
Each character script picks a `style` that changes how idle/walk/run look.
"""
import math

import kit

# Heights for a 1.85 m figure (scaled per character).
BASE = {
    "ankle": 0.09, "knee": 0.49, "hip": 0.90, "waist": 1.02, "chest": 1.22, "neck": 1.47,
    "head": 1.57, "top": 1.85, "shoulder": 1.43, "elbow": 1.14, "wrist": 0.87, "fingers": 0.77,
}


class Proportions:
    def __init__(self, height=1.85, shoulder_x=0.24, hip_x=0.105, arm_x=0.0):
        s = height / 1.85
        self.s = s
        self.z = {k: v * s for k, v in BASE.items()}
        self.shoulder_x = shoulder_x * s
        self.hip_x = hip_x * s
        # Arms hang a little out from the shoulder joint.
        self.arm_x = (arm_x or shoulder_x + 0.03) * s

    def __getitem__(self, key):
        return self.z[key]


def skeleton(p):
    z = p.z
    bones = {
        "Root": ((0, 0, 0), (0, 0, 0.2 * p.s), None, False),
        "Hips": ((0, 0, z["hip"]), (0, 0, z["waist"]), "Root", False),
        "Spine": ((0, 0, z["waist"]), (0, 0, z["chest"]), "Hips", True),
        "Chest": ((0, 0, z["chest"]), (0, 0, z["neck"]), "Spine", True),
        "Neck": ((0, 0, z["neck"]), (0, 0, z["head"]), "Chest", True),
        "Head": ((0, 0, z["head"]), (0, 0, z["top"]), "Neck", True),
    }
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        ax = p.arm_x * sign
        hx = p.hip_x * sign
        bones.update({
            f"{side}Shoulder": ((0.05 * sign * p.s, 0, z["shoulder"] - 0.03 * p.s), (ax, 0, z["shoulder"]), "Chest", False),
            f"{side}UpperArm": ((ax, 0, z["shoulder"]), (ax, 0, z["elbow"]), f"{side}Shoulder", True),
            f"{side}LowerArm": ((ax, 0, z["elbow"]), (ax, 0, z["wrist"]), f"{side}UpperArm", True),
            f"{side}Hand": ((ax, 0, z["wrist"]), (ax, 0, z["fingers"]), f"{side}LowerArm", True),
            f"{side}UpperLeg": ((hx, 0, z["hip"] - 0.03 * p.s), (hx, 0, z["knee"]), "Hips", False),
            f"{side}LowerLeg": ((hx, 0, z["knee"]), (hx, 0, z["ankle"]), f"{side}UpperLeg", True),
            f"{side}Foot": ((hx, 0, z["ankle"]), (hx, -0.12 * p.s, 0.025 * p.s), f"{side}LowerLeg", True),
            f"{side}Toes": ((hx, -0.12 * p.s, 0.025 * p.s), (hx, -0.19 * p.s, 0.025 * p.s), f"{side}Foot", True),
        })
    return bones


def build_armature(p, name="Armature"):
    return kit.armature(name, skeleton(p))


# --- Weight helpers -----------------------------------------------------------

def trunk(p):
    return kit.along_z(("Chest", "Spine", p["chest"]), ("Spine", "Hips", p["waist"]), blend=0.06 * p.s)


def arm(p, side):
    return kit.along_z((f"{side}UpperArm", f"{side}LowerArm", p["elbow"]), (f"{side}LowerArm", f"{side}Hand", p["wrist"]),
                       blend=0.04 * p.s)


def leg(p, side):
    return kit.along_z((f"{side}UpperLeg", f"{side}LowerLeg", p["knee"]), (f"{side}LowerLeg", f"{side}Foot", p["ankle"] + 0.02),
                       blend=0.05 * p.s)


def skirt(p, flare_to_legs=0.55):
    """Hips at the waist; below the hip joint, increasingly the nearer thigh, so a
    skirt follows the stride instead of being kicked through."""
    def weigh(co):
        down = kit.smoothstep(p["hip"] + 0.02, p["hip"] - 0.28 * p.s, co.z) * flare_to_legs
        side = "Left" if co.x >= 0 else "Right"
        across = min(1.0, abs(co.x) / (p.hip_x * 1.6))
        w_leg = down * (0.35 + 0.65 * across)
        weights = {"Hips": 1.0 - w_leg}
        if w_leg > 0:
            weights[f"{side}UpperLeg"] = w_leg
        if co.z > p["waist"] - 0.04:
            weights = {"Hips": 0.5, "Spine": 0.5}
        return weights
    return weigh


def cloak(p):
    """A cloak hanging down the back from the shoulders."""
    def weigh(co):
        if co.z > p["chest"] + 0.08:
            return {"Chest": 1.0}
        if co.z > p["waist"]:
            t = (co.z - p["waist"]) / (p["chest"] + 0.08 - p["waist"])
            return {"Chest": t, "Spine": 1.0 - t}
        if co.z > p["hip"] - 0.1:
            return {"Spine": 0.5, "Hips": 0.5}
        return {"Hips": 1.0}
    return weigh


# --- Poses ----------------------------------------------------------------------

def pose(**bones):
    return dict(bones)


def merge(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


def loc(dx=0.0, dy=0.0, dz=0.0, bone="Hips"):
    """An offset of the hips (or root) in metres: right/left x, up y, forward z."""
    return {f"loc:{bone}": (dx, dy, dz)}


REST_ARMS = pose(LeftUpperArm=(0, 0, 7), RightUpperArm=(0, 0, 7), LeftLowerArm=12, RightLowerArm=12)
# The hero's guard: spear level at the waist, shield across the front.
GUARD = pose(
    RightUpperArm=(18, 10, 14), RightLowerArm=78, RightHand=-62,
    LeftUpperArm=(42, -25, 8), LeftLowerArm=85, LeftHand=-10,
)
STANCE = merge(pose(LeftUpperLeg=14, LeftLowerLeg=-20, LeftFoot=6, RightUpperLeg=-8, RightLowerLeg=-14, RightFoot=-4,
                    Spine=4, Chest=2, Head=-3), loc(0, -0.035, 0))
SLUMP = pose(Spine=14, Chest=12, Neck=10, Head=8, LeftUpperArm=(12, 0, 8), RightUpperArm=(12, 0, 8),
             LeftLowerArm=24, RightLowerArm=24)


def stride(lead, arms, bob, lean, knee, frames, held=None, base=None):
    """A walk or run cycle over `frames`; the left leg leads first. `held` keeps the
    arms in a pose (weapon and shield) with only a little swing."""
    half, quarter = frames // 2, frames // 4
    base = base or {}

    def arms_for(side_lead, scale):
        if held:
            out = dict(held)
            r = out.get("RightUpperArm", (0, 0, 0))
            l_ = out.get("LeftUpperArm", (0, 0, 0))
            swing = arms * 0.25 * scale
            out["RightUpperArm"] = (r[0] + (swing if side_lead == "Left" else -swing), r[1], r[2])
            out["LeftUpperArm"] = (l_[0] + (-swing if side_lead == "Left" else swing), l_[1], l_[2])
            return out
        other = "Right" if side_lead == "Left" else "Left"
        return {f"{side_lead}UpperArm": (-arms * scale, 0, 7), f"{side_lead}LowerArm": 14,
                f"{other}UpperArm": (arms * scale, 0, 7), f"{other}LowerArm": 22 + arms * 0.45}

    def step(side_lead):
        other = "Right" if side_lead == "Left" else "Left"
        return merge(base, {
            f"{side_lead}UpperLeg": lead, f"{side_lead}LowerLeg": -knee * 0.22, f"{side_lead}Foot": 12,
            f"{other}UpperLeg": -lead * 0.75, f"{other}LowerLeg": -knee * 0.45, f"{other}Foot": -18,
            "Spine": lean, "Chest": lean * 0.4, "Head": -lean * 0.9,
            "Hips": (0, lead * 0.12 if side_lead == "Left" else -lead * 0.12, 0),
        }, arms_for(side_lead, 1.0), loc(0, 0.0, 0))

    def passing(side_up):
        return merge(base, {
            f"{side_up}UpperLeg": lead * 0.4, f"{side_up}LowerLeg": -knee, f"{side_up}Foot": 4,
            "Spine": lean, "Chest": lean * 0.4, "Head": -lean * 0.9,
        }, arms_for("Left" if side_up == "Right" else "Right", 0.15), loc(0, bob, 0))

    return [(0, step("Left")), (quarter, passing("Right")), (half, step("Right")), (half + quarter, passing("Left"))]


def build_animations(arm, style="hero"):
    """Keys every action onto `arm`. Styles: hero (spear and shield), shade
    (shambling undead with a weapon), archer (bow), villager, weaver."""
    k = kit.key_action
    if style == "hero":
        held = GUARD
        idle_base = merge(STANCE, GUARD)
    elif style in ("shade", "archer"):
        held = merge(SLUMP, pose(RightUpperArm=(20, 0, 10), RightLowerArm=60, RightHand=-50,
                                 LeftUpperArm=(30, -20, 6), LeftLowerArm=70))
        if style == "archer":
            held = merge(SLUMP, pose(LeftUpperArm=(25, 0, 10), LeftLowerArm=40, RightUpperArm=(8, 0, 8), RightLowerArm=20))
        idle_base = merge(STANCE, held)
    else:
        held = None
        idle_base = merge(REST_ARMS, pose(Spine=2))
        if style == "weaver":
            idle_base = merge(idle_base, pose(Spine=18, Chest=10, Neck=8, Head=6), loc(0, -0.02, 0))

    # idle: breathing and a slow weight shift
    breathe = merge(idle_base, pose(Chest=(idle_base.get("Chest", 0) if isinstance(idle_base.get("Chest", 0), (int, float)) else 0) - 2.5))
    k(arm, "idle", [(0, idle_base), (30, merge(breathe, loc(0, idle_base.get("loc:Hips", (0, 0, 0))[1] - 0.012, 0))),
                    (60, idle_base), (90, merge(breathe, pose(Head=-1)))], loop=True)
    k(arm, "combat_idle", [(0, merge(STANCE, held or REST_ARMS)), (20, merge(STANCE, held or REST_ARMS, pose(Chest=-1), loc(0, -0.05, 0)))], loop=True)

    walk_base = SLUMP if style in ("shade", "archer") else (pose(Spine=18, Chest=8) if style == "weaver" else {})
    k(arm, "walk", stride(lead=28, arms=20, bob=0.025, lean=4 + (8 if style in ("shade", "archer") else 0), knee=52, frames=24,
                          held=held, base=walk_base), loop=True)
    k(arm, "run", stride(lead=46, arms=40, bob=0.055, lean=12, knee=92, frames=16, held=held, base=walk_base), loop=True)

    # --- attacks: one-shots; Godot hits on the "impact" fraction noted per action.
    ready = merge(STANCE, held or REST_ARMS)
    # Spear thrust (impact 8/16 = 0.5).
    wind = merge(ready, pose(RightUpperArm=(-30, 10, 18), RightLowerArm=100, RightHand=-70, Chest=(0, -22, 0), Spine=(4, -10, 0),
                             LeftUpperArm=(48, -30, 6), LeftLowerArm=88), loc(0, -0.06, -0.04))
    strike = merge(ready, pose(RightUpperArm=(78, 6, 6), RightLowerArm=12, RightHand=-82, Chest=(8, 26, 0), Spine=(8, 12, 0),
                               LeftUpperArm=(30, -20, 20), LeftLowerArm=70,
                               LeftUpperLeg=32, LeftLowerLeg=-38, RightUpperLeg=-24, RightLowerLeg=-6, RightFoot=-20),
                   loc(0, -0.08, 0.16))
    k(arm, "attack_thrust", [(0, ready), (5, wind), (8, strike), (11, strike), (17, ready)])
    # Sword slash, right shoulder to left hip (impact 8/16 = 0.5).
    raise_ = merge(ready, pose(RightUpperArm=(150, -25, 38), RightLowerArm=55, RightHand=15, Chest=(-6, -28, 0), Spine=(0, -12, 0)),
                   loc(0, -0.03, 0))
    cut = merge(ready, pose(RightUpperArm=(55, 25, -40), RightLowerArm=10, RightHand=-15, Chest=(10, 32, 0), Spine=(6, 14, 0),
                            LeftUpperLeg=26, LeftLowerLeg=-30), loc(0, -0.07, 0.12))
    k(arm, "attack_slash", [(0, ready), (5, raise_), (8, cut), (11, cut), (17, ready)])
    # Shield bash (impact 7/15).
    bash_wind = merge(ready, pose(LeftUpperArm=(15, -10, 35), LeftLowerArm=105, Chest=(0, 20, 0), Spine=(0, 8, 0)), loc(0, -0.05, -0.05))
    bash_hit = merge(ready, pose(LeftUpperArm=(82, -10, 4), LeftLowerArm=28, LeftHand=-10, Chest=(10, -30, 0), Spine=(6, -12, 0),
                                 LeftUpperLeg=34, LeftLowerLeg=-36, RightUpperLeg=-26), loc(0, -0.08, 0.2))
    k(arm, "bash", [(0, ready), (4, bash_wind), (7, bash_hit), (10, bash_hit), (15, ready)])
    # Fate's Lash: one full turn with the thread arm out (impact ~0.4).
    out_arm = pose(RightUpperArm=(10, 0, 88), RightLowerArm=5, RightHand=0, LeftUpperArm=(40, -20, 10), LeftLowerArm=80)
    spin = []
    for i, angle in enumerate((0, 90, 180, 270, 360)):
        spin.append((3 + i * 3, merge(STANCE, out_arm, pose(Root=(0, -angle, 0), Spine=(6, 0, -8)), loc(0, -0.08, 0))))
    k(arm, "lash", [(0, ready)] + spin + [(22, ready)])
    # War cry (impact 0.35).
    cry = merge(STANCE, pose(LeftUpperArm=(55, 0, 70), RightUpperArm=(55, 0, 70), LeftLowerArm=40, RightLowerArm=40,
                             Chest=-12, Neck=-10, Head=-22, Spine=-4), loc(0, -0.06, 0))
    k(arm, "war_cry", [(0, ready), (6, merge(ready, pose(Spine=14, Chest=10), loc(0, -0.08, 0))), (11, cry), (24, cry), (32, ready)])
    # Lunge: a low dash held while the body flies forward (no impact; the dash hits).
    dash = merge(strike, pose(Spine=(24, 10, 0), Chest=(8, 20, 0), LeftUpperLeg=58, LeftLowerLeg=-64, RightUpperLeg=-38,
                              RightLowerLeg=-22), loc(0, -0.14, 0.12))
    k(arm, "lunge", [(0, merge(ready, loc(0, -0.08, 0))), (3, dash), (9, dash), (14, ready)])
    # Cast: the thread hand thrown up and forward (impact 0.5).
    lift = merge(ready, pose(RightUpperArm=(140, 0, 15), RightLowerArm=10, RightHand=10, LeftUpperArm=(20, 0, 45), LeftLowerArm=20,
                             Chest=-8, Head=-12))
    k(arm, "cast", [(0, ready), (6, merge(ready, pose(RightUpperArm=(30, 0, 30), RightLowerArm=110, Spine=10))), (11, lift), (16, lift), (22, ready)])

    # --- reactions
    flinch = merge(ready, pose(Chest=-16, Spine=-8, Head=-14, LeftUpperArm=(25, 0, 30), RightUpperArm=(10, 0, 25)), loc(0, -0.02, -0.06))
    k(arm, "hit", [(0, ready), (3, flinch), (10, ready)])
    buckle = merge(ready, pose(LeftUpperLeg=35, RightUpperLeg=30, LeftLowerLeg=-70, RightLowerLeg=-60, Spine=24, Head=20,
                               LeftUpperArm=(30, 0, 20), RightUpperArm=(30, 0, 20)), loc(0, -0.28, 0))
    fallen = merge(pose(Root=(-88, 0, 0), LeftUpperArm=(0, 0, 70), RightUpperArm=(0, 0, 60), LeftLowerArm=30, RightLowerArm=20,
                        LeftUpperLeg=12, RightUpperLeg=4, LeftLowerLeg=-20, RightLowerLeg=-8, Head=-10))
    k(arm, "die", [(0, ready), (7, buckle), (16, merge(fallen, pose(Root=(-80, 0, 0)))), (19, merge(fallen, pose(Root=(-91, 0, 0)))),
                   (23, merge(fallen, pose(Root=(-86, 0, 0)))), (28, fallen)])
    reach = pose(LeftUpperArm=(165, 0, 25), RightUpperArm=(160, 0, 20), LeftLowerArm=20, RightLowerArm=30, Head=-25, Spine=-6)
    k(arm, "rise", [(0, merge(reach, loc(0, -1.85, 0, bone="Root"))), (10, merge(reach, loc(0, -1.1, 0, bone="Root"))),
                    (20, merge(pose(Spine=32, Chest=12, LeftUpperArm=(60, 0, 30), RightUpperArm=(60, 0, 30), LeftUpperLeg=40, LeftLowerLeg=-60),
                               loc(0, -0.35, 0, bone="Root"))),
                    (30, merge(ready, loc(0, 0, 0, bone="Root")))])
    dazed = merge(ready, pose(Head=(22, 0, 12), Neck=10, Chest=12, LeftUpperArm=(5, 0, 10), RightUpperArm=(5, 0, 10)), loc(0, -0.06, 0))
    k(arm, "stunned", [(0, dazed), (15, merge(dazed, pose(Head=(22, 0, -12)))), (30, dazed), (45, merge(dazed, pose(Head=(18, 0, -6))))],
      loop=True)

    # --- ranged and NPC
    bow_up = merge(STANCE, pose(LeftUpperArm=(86, 0, 4), LeftLowerArm=4, LeftHand=0, RightUpperArm=(86, 0, -12), RightLowerArm=70,
                                Chest=(0, -12, 0)))
    drawn = merge(bow_up, pose(RightUpperArm=(84, 0, 18), RightLowerArm=150, RightHand=-10, Chest=(0, -18, 0), Head=(0, -10, 0)))
    loose = merge(drawn, pose(RightUpperArm=(70, 0, 40), RightLowerArm=90, RightHand=20))
    k(arm, "shoot", [(0, ready), (8, bow_up), (16, drawn), (20, drawn), (21, loose), (30, ready)])
    talk_a = merge(idle_base, pose(RightUpperArm=(30, 0, 12), RightLowerArm=70, RightHand=-20, Head=4))
    talk_b = merge(idle_base, pose(RightUpperArm=(22, 0, 25), RightLowerArm=50, RightHand=10, Head=(-3, 8, 0), LeftLowerArm=30))
    k(arm, "talk", [(0, talk_a), (20, talk_b), (40, merge(talk_a, pose(Head=(6, -6, 0)))), (60, talk_b)], loop=True)
    hands = pose(LeftUpperArm=(42, 0, -10), RightUpperArm=(42, 0, -10), LeftLowerArm=62, RightLowerArm=62, LeftHand=-10, RightHand=-10)
    weave_a = merge(idle_base, hands, pose(Chest=(0, 8, 0)))
    weave_b = merge(idle_base, hands, pose(Chest=(0, -8, 0), LeftUpperArm=(48, 0, -4), RightUpperArm=(36, 0, -16)))
    k(arm, "weave", [(0, weave_a), (30, weave_b)], loop=True)
    kit.rest_pose(arm)


# Seconds per action at speed 1 and the fraction of it where the blow lands; mirrored
# in src/actors/actor_body.gd (IMPACT).
IMPACT = {
    "attack_thrust": 0.47, "attack_slash": 0.47, "bash": 0.47, "lash": 0.4, "war_cry": 0.35,
    "cast": 0.5, "shoot": 0.68,
}
