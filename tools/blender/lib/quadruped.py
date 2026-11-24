"""The four-legged skeleton and its animations: the Styx boar and Khalkotauros, the
bronze bull (the same rig scaled).

The body faces -Y; the spine runs along Y. Bones lying along the body have local Z
up, so a positive pitch raises them (head up, chest up); legs hang with local Z to
the front, so a positive pitch swings a leg forward. A front lower leg folds back
with a negative pitch; a hind lower leg folds forward with a positive one.
Right-side bones mirror twist and spread (kit.mirrored).

Animations: idle, walk, run, gore, charge_windup, charge, hit, die, stunned,
breath, stomp, bellow.
"""
import kit

LEGS = ("FrontLeft", "FrontRight", "BackLeft", "BackRight")


class Body:
    """Key points of a quadruped `s` times the boar's size (shoulder 0.9 m)."""

    def __init__(self, s=1.0):
        self.s = s

    def p(self, x, y, z):
        return (x * self.s, y * self.s, z * self.s)


def skeleton(b):
    p = b.p
    bones = {
        "Root": (p(0, 0, 0), p(0, 0, 0.25), None, False, (0, -1, 0)),
        "Hips": (p(0, 0.15, 0.86), p(0, 0.5, 0.84), "Root", False, (0, 0, 1)),
        "Spine": (p(0, 0.15, 0.86), p(0, -0.2, 0.9), "Hips", False, (0, 0, 1)),
        "Chest": (p(0, -0.2, 0.9), p(0, -0.45, 0.88), "Spine", True, (0, 0, 1)),
        "Neck": (p(0, -0.45, 0.88), p(0, -0.66, 0.82), "Chest", True, (0, 0, 1)),
        "Head": (p(0, -0.66, 0.82), p(0, -1.0, 0.62), "Neck", True, (0, 0, 1)),
        "Tail": (p(0, 0.5, 0.84), p(0, 0.72, 0.68), "Hips", True, (0, 0, 1)),
    }
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        fx, hx = 0.17 * sx, 0.16 * sx
        bones.update({
            f"Front{side}Upper": (p(fx, -0.35, 0.72), p(fx, -0.35, 0.42), "Chest", False),
            f"Front{side}Lower": (p(fx, -0.35, 0.42), p(fx, -0.36, 0.08), f"Front{side}Upper", True),
            f"Front{side}Foot": (p(fx, -0.36, 0.08), p(fx, -0.42, 0.0), f"Front{side}Lower", True),
            f"Back{side}Upper": (p(hx, 0.4, 0.74), p(hx, 0.47, 0.44), "Hips", False),
            f"Back{side}Lower": (p(hx, 0.47, 0.44), p(hx, 0.41, 0.08), f"Back{side}Upper", True),
            f"Back{side}Foot": (p(hx, 0.41, 0.08), p(hx, 0.36, 0.0), f"Back{side}Lower", True),
        })
    return bones


def build_armature(b, name="Armature"):
    return kit.armature(name, skeleton(b))


def body_weights(b):
    """Weights along the length for the trunk, neck and head."""
    s = b.s
    return kit.along("y", ("Tail", "Hips", 0.55 * s), ("Hips", "Spine", 0.18 * s), ("Spine", "Chest", -0.2 * s),
                     ("Chest", "Neck", -0.47 * s), ("Neck", "Head", -0.68 * s), blend=0.08 * s)


def leg_weights(b, front, side):
    s = b.s
    prefix = ("Front" if front else "Back") + side
    knee = 0.42 * s
    return kit.along_z((f"{prefix}Upper", f"{prefix}Lower", knee), (f"{prefix}Lower", f"{prefix}Foot", 0.09 * s), blend=0.05 * s)


def gait(swing, fold, bob, frames, head=0.0, diagonal=True):
    """A trot: diagonal pairs (front-left with back-right) swing together."""
    half = frames // 2

    def phase(a_forward):
        out = {"Head": head, "Neck": -head * 0.5}
        pairs = (("FrontLeft", "BackRight"), ("FrontRight", "BackLeft"))
        fwd, back = pairs if a_forward else pairs[::-1]
        for leg in fwd:
            out[f"{leg}Upper"] = swing
            out[f"{leg}Lower"] = -fold * 0.3 if leg.startswith("Front") else fold * 0.3
        for leg in back:
            out[f"{leg}Upper"] = -swing
            out[f"{leg}Lower"] = -fold * 0.1 if leg.startswith("Front") else fold * 0.1
        return out

    def passing(a_forward):
        out = {"Head": head + 2, "Neck": -head * 0.5, "loc:Hips": (0, bob, 0)}
        pairs = (("FrontLeft", "BackRight"), ("FrontRight", "BackLeft"))
        lifting = pairs[1] if a_forward else pairs[0]
        for leg in lifting:
            out[f"{leg}Upper"] = swing * 0.2
            out[f"{leg}Lower"] = -fold if leg.startswith("Front") else fold
        return out

    q = frames // 4
    return [(0, phase(True)), (q, passing(True)), (half, phase(False)), (half + q, passing(False))]


def build_animations(arm):
    k = kit.key_action
    stand = {}
    k(arm, "idle", [(0, dict(stand, Head=-4)), (30, dict(stand, Head=2, Neck=2, Chest=1)), (60, dict(stand, Head=-2, Neck=(0, 6, 0))),
                    (90, dict(stand, Head=(-4, -5, 0)))], loop=True)
    k(arm, "walk", gait(18, 40, 0.02, 24, head=-4), loop=True)
    k(arm, "run", gait(32, 70, 0.05, 14, head=-10), loop=True)
    k(arm, "charge", gait(38, 80, 0.06, 12, head=-24), loop=True)
    low = dict(Head=-28, Neck=-14, Chest=-4)
    k(arm, "gore", [(0, {}), (6, dict(low, FrontLeftUpper=-10, FrontRightUpper=-10, **{"loc:Hips": (0, -0.03, -0.06)})),
                    (10, dict(Head=30, Neck=14, Chest=6, FrontLeftUpper=12, **{"loc:Hips": (0, 0.02, 0.1)})), (16, dict(Head=8)), (22, {})])
    paw = dict(low, **{"loc:Hips": (0, -0.04, 0)})
    k(arm, "charge_windup", [(0, {}), (5, paw), (9, dict(paw, FrontRightUpper=30, FrontRightLower=-60)), (14, dict(paw, FrontRightUpper=-25)),
                             (19, dict(paw, FrontRightUpper=30, FrontRightLower=-60)), (24, dict(paw, FrontRightUpper=-25)), (30, paw)])
    k(arm, "hit", [(0, {}), (3, dict(Head=14, Neck=6, Chest=4, **{"loc:Hips": (0, 0, -0.08)})), (10, {})])
    fallen = {"Root": (0, 0, 84), "FrontLeftUpper": (25, 0, 0), "BackLeftUpper": (-20, 0, 0), "Head": (-10, 15, 0), "Tail": 20,
              "FrontRightUpper": (40, 0, 0), "BackRightUpper": (-35, 0, 0), "loc:Root": (0, -0.08, 0)}
    k(arm, "die", [(0, {}), (6, dict(Head=-30, FrontLeftLower=-60, FrontRightLower=-60, **{"loc:Hips": (0, -0.15, 0)})),
                   (16, dict(fallen, Root=(0, 0, 70))), (20, dict(fallen, Root=(0, 0, 90))), (26, fallen)])
    k(arm, "stunned", [(0, dict(Head=(-25, 10, 0), Neck=-8)), (20, dict(Head=(-30, -10, 0), Neck=-8)), (40, dict(Head=(-25, 10, 0), Neck=-8))],
      loop=True)
    # The bull's breath: head forward and low, the body braced (impact 0.35).
    brace = dict(Head=-12, Neck=-10, FrontLeftUpper=14, FrontRightUpper=14, BackLeftUpper=-10, BackRightUpper=-10, **{"loc:Hips": (0, -0.06, 0.05)})
    k(arm, "breath", [(0, {}), (8, dict(Head=18, Neck=10, Chest=4)), (14, brace), (40, dict(brace, Head=-8)), (48, {})])
    # Rearing up and slamming the forelegs down (impact 0.55).
    rear = dict(Spine=28, Chest=6, Head=10, FrontLeftUpper=55, FrontRightUpper=55, FrontLeftLower=-70, FrontRightLower=-70,
                BackLeftUpper=-20, BackRightUpper=-20, **{"loc:Hips": (0, -0.08, 0)})
    slam = dict(Spine=-6, Head=-20, Neck=-8, FrontLeftUpper=-10, FrontRightUpper=-10, **{"loc:Hips": (0, -0.12, 0)})
    k(arm, "stomp", [(0, {}), (12, rear), (16, dict(rear, Spine=32)), (21, slam), (30, slam), (38, {})])
    k(arm, "bellow", [(0, {}), (8, dict(Head=35, Neck=18, Chest=4)), (30, dict(Head=38, Neck=20, Chest=6)), (40, {})])
    kit.rest_pose(arm)
