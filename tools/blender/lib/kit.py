"""Shared helpers for every Blender script that builds UNTHREADED's assets.

Scripts put this folder on the path and import it:

    import os, sys
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
    import kit

What it gives you:
- `PALETTE`: the colours in data/palette.json. Models never pick free colours; every
  face is UV-mapped onto a palette swatch (see docs/ART_BIBLE.md), so a whole model is
  one material ("Palette") and Godot swaps in its own palette shader on import.
- `Mesh`: a builder that collects low-poly parts (boxes, cylinders with rings,
  spheres, lathes, extrusions, lofts, rocks, leaves) into one mesh, each part painted
  with a swatch and, for characters, weighted to bones.
- `armature()`, `key_action()`: skeletons and keyframed actions for characters.
- `collision_*()`: shapes Godot turns into colliders on import (-colonly suffixes).
- `export_glb()`, `report()`.

Conventions: metres, Z up, bottom centre at the origin, and models face -Y. glTF
export turns Blender -Y into +Z, which is Godot's MODEL_FRONT, so in Godot an actor
faces a point with `look_at(point, Vector3.UP, true)`. A character's left is +X.
"""
import contextlib
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
ASSETS = os.path.join(ROOT, "assets")
PALETTE_JSON = os.path.join(ROOT, "data", "palette.json")
PALETTE_ALBEDO = os.path.join(ASSETS, "textures", "palette_albedo.png")
PALETTE_PARAMS = os.path.join(ASSETS, "textures", "palette_params.png")
FPS = 30


def script_args():
    """Arguments after `--` on Blender's command line."""
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def log(tag, message):
    print(f"[{tag}] {message}", flush=True)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_srgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# --- Palette ----------------------------------------------------------------

class Palette:
    def __init__(self, path=PALETTE_JSON):
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        self.grid = int(data["grid"])
        self.cell_px = int(data["cell_px"])
        self.entries = {}
        self.order = []
        for index, (name, colour, roughness, metallic, emission) in enumerate(data["swatches"]):
            self.entries[name] = {
                "index": index,
                "srgb": hex_to_srgb(colour),
                "roughness": float(roughness),
                "metallic": float(metallic),
                "emission": float(emission),
            }
            self.order.append(name)

    def __contains__(self, name):
        return name in self.entries

    def entry(self, name):
        if name not in self.entries:
            raise KeyError(f"swatch '{name}' is not in data/palette.json")
        return self.entries[name]

    def uv(self, name):
        """The centre of the swatch's cell in Blender UV space (origin bottom-left)."""
        index = self.entry(name)["index"]
        col, row = index % self.grid, index // self.grid
        return ((col + 0.5) / self.grid, 1.0 - (row + 0.5) / self.grid)

    def linear(self, name):
        return tuple(srgb_to_linear(c) for c in self.entry(name)["srgb"])


PALETTE = Palette()


# --- Scene and materials ----------------------------------------------------

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.unit_settings.system = "METRIC"


def _load_image(path, colorspace):
    name = os.path.basename(path)
    image = bpy.data.images.get(name)
    if image is None and os.path.exists(path):
        image = bpy.data.images.load(path)
    if image is not None:
        image.colorspace_settings.name = colorspace
    return image


def palette_material(name="Palette"):
    """The one material models use. Its node tree reads the palette images so Blender
    renders (icons, previews) look like the game; Godot replaces it on import."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    albedo = _load_image(PALETTE_ALBEDO, "sRGB")
    params = _load_image(PALETTE_PARAMS, "Non-Color")
    if albedo is not None and params is not None:
        tex_a = nodes.new("ShaderNodeTexImage")
        tex_a.image = albedo
        tex_a.interpolation = "Closest"
        tex_p = nodes.new("ShaderNodeTexImage")
        tex_p.image = params
        tex_p.interpolation = "Closest"
        split = nodes.new("ShaderNodeSeparateColor")
        boost = nodes.new("ShaderNodeMath")
        boost.operation = "MULTIPLY"
        boost.inputs[1].default_value = 8.0
        links.new(tex_a.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(tex_p.outputs["Color"], split.inputs["Color"])
        links.new(split.outputs[0], bsdf.inputs["Roughness"])
        links.new(split.outputs[1], bsdf.inputs["Metallic"])
        links.new(tex_a.outputs["Color"], bsdf.inputs["Emission Color"])
        links.new(split.outputs[2], boost.inputs[0])
        links.new(boost.outputs[0], bsdf.inputs["Emission Strength"])
    else:
        bsdf.inputs["Base Color"].default_value = (0.8, 0.8, 0.8, 1.0)
    return mat


def flat_material(name, swatch, alpha=1.0, emission=0.0):
    """A material of its own, for the few parts that need something the palette
    shader can't do (see-through ghost cloth). Godot maps it by name on import."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    linear = PALETTE.linear(swatch)
    mat.diffuse_color = (*linear, alpha)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = PALETTE.entry(swatch)["roughness"]
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        for attribute, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            if hasattr(mat, attribute):
                try:
                    setattr(mat, attribute, value)
                except (TypeError, ValueError):
                    pass
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*linear, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def get_material(name):
    # "Foliage" is the palette with wind in the game (plants sway); in Blender it
    # renders exactly like the palette.
    if name in ("Palette", "Foliage"):
        return palette_material(name)
    mat = bpy.data.materials.get(name)
    if mat is None:
        raise KeyError(f"material '{name}' was never made; call flat_material() first")
    return mat


# --- Matrices ---------------------------------------------------------------

def mat(location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
    """A matrix from a location, an XYZ rotation in degrees and a scale."""
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    rot = Euler(tuple(math.radians(a) for a in rotation), "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(location) @ rot @ Matrix.Diagonal((*scale, 1.0))


def look_matrix(a, b):
    """Translation to the midpoint of a→b, with local Z pointing from a to b."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    if axis.length < 1e-6:
        return Matrix.Translation(a)
    rotation = axis.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    return Matrix.Translation((a + b) / 2) @ rotation


# --- Weights ----------------------------------------------------------------

def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def along(axis, *joints, blend=0.04):
    """Weights for a part spanning several bones stacked along an axis ('x','y','z').
    `joints` are (bone above, bone below, coordinate of the joint), from the high
    coordinate to the low one; vertices within `blend` of a joint are shared."""
    k = "xyz".index(axis)

    def weigh(co):
        weights = {}
        remaining = 1.0
        for upper, _lower, at in joints:
            below = 1.0 - smoothstep(at - blend, at + blend, co[k])
            weights[upper] = weights.get(upper, 0.0) + remaining * (1.0 - below)
            remaining *= below
        last = joints[-1][1]
        weights[last] = weights.get(last, 0.0) + remaining
        return weights
    return weigh


def along_z(*joints, blend=0.04):
    return along("z", *joints, blend=blend)


# --- The mesh builder -------------------------------------------------------

class Mesh:
    """Collects parts into one mesh. Every part takes a palette swatch, optional bone
    weights (`weigh`: a bone name, a {bone: weight} dict or a function of the vertex
    position), `smooth` shading and a `material` (default "Palette").

    Parts are placed by the current matrix: `with mesh.at(location, rotation, scale):`.
    """

    def __init__(self, name, bones=None):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()
        self.bones = list(bones) if bones else []
        self.deform = self.bm.verts.layers.deform.verify() if self.bones else None
        self.materials = []
        # The material parts get unless they name one: "Foliage" for plants.
        self.material = "Palette"
        self.stack = [Matrix.Identity(4)]

    # placement
    @property
    def matrix(self):
        return self.stack[-1]

    @contextlib.contextmanager
    def at(self, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1), matrix=None):
        self.stack.append(self.matrix @ (matrix if matrix is not None else mat(location, rotation, scale)))
        try:
            yield self
        finally:
            self.stack.pop()

    def _material_index(self, name):
        if name not in self.materials:
            self.materials.append(name)
        return self.materials.index(name)

    def _weights(self, weigh, co):
        if weigh is None:
            return {}
        if isinstance(weigh, str):
            return {weigh: 1.0}
        if isinstance(weigh, dict):
            return weigh
        return weigh(co)

    def paint(self, verts, swatch, weigh=None, smooth=False, material=None, faces=None, double=False):
        """Colours, weights and shades the faces of freshly made `verts`."""
        material = material or self.material
        if faces is None:
            faces = set()
            for vert in verts:
                faces.update(vert.link_faces)
        faces = list(faces)
        u, v = PALETTE.uv(swatch)
        index = self._material_index(material)
        for face in faces:
            face.material_index = index
            face.smooth = smooth
            for loop in face.loops:
                loop[self.uv].uv = (u, v)
        if self.deform is not None and weigh is not None:
            for vert in verts:
                for bone, weight in self._weights(weigh, vert.co).items():
                    if weight > 1e-4:
                        if bone not in self.bones:
                            raise KeyError(f"bone '{bone}' is not in this mesh's skeleton")
                        vert[self.deform][self.bones.index(bone)] = weight
        if double:
            self._backfaces(faces, swatch, weigh, smooth, material)
        return faces

    def _backfaces(self, faces, swatch, weigh, smooth, material):
        copies = {}
        made = []
        for face in faces:
            verts = []
            for vert in face.verts:
                if vert not in copies:
                    copy = self.bm.verts.new(vert.co)
                    if self.deform is not None:
                        for group, weight in vert[self.deform].items():
                            copy[self.deform][group] = weight
                    copies[vert] = copy
                verts.append(copies[vert])
            made.append(self.bm.faces.new(list(reversed(verts))))
        u, v = PALETTE.uv(swatch)
        index = self._material_index(material)
        for face in made:
            face.material_index = index
            face.smooth = smooth
            for loop in face.loops:
                loop[self.uv].uv = (u, v)

    def _place(self, local_matrix):
        return self.matrix @ local_matrix

    # primitives
    def box(self, center, size, swatch, rotation=(0, 0, 0), bevel=0.0, **kw):
        before = set(self.bm.faces)
        m = self._place(mat(center, rotation, size))
        made = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        verts = made["verts"]
        if bevel > 0.0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=1,
                            profile=0.5, affect="EDGES", clamp_overlap=True)
        # Paint every face made since the box started, bevel faces included.
        faces = [f for f in self.bm.faces if f not in before]
        verts = list({v for f in faces for v in f.verts})
        return self.paint(verts, swatch, faces=faces, **kw)

    def cylinder(self, bottom, top, r_bottom, r_top, swatch, segments=8, caps=True, ring_step=0.0,
                 squash=1.0, twist=0.0, **kw):
        """A tapered cylinder from `bottom` to `top`. `ring_step` adds a ring every so
        many metres so the part can bend at joints. `squash` flattens it front-to-back."""
        bottom, top = Vector(bottom), Vector(top)
        axis = top - bottom
        length = axis.length
        frame = look_matrix(bottom, top) @ Matrix.Diagonal((1.0, squash, 1.0, 1.0))
        frame = self._place(frame)
        steps = max(1, round(length / ring_step)) if ring_step > 0 else 1
        rings = []
        for step in range(steps + 1):
            t = step / steps
            radius = r_bottom + (r_top - r_bottom) * t
            ring = []
            for k in range(segments):
                angle = math.tau * k / segments + math.radians(twist)
                local = Vector((math.cos(angle) * radius, math.sin(angle) * radius, (t - 0.5) * length))
                ring.append(self.bm.verts.new(frame @ local))
            rings.append(ring)
        faces = []
        for lower, upper in zip(rings, rings[1:]):
            for k in range(segments):
                faces.append(self.bm.faces.new((lower[k], lower[(k + 1) % segments], upper[(k + 1) % segments], upper[k])))
        if caps:
            if r_bottom > 1e-4:
                faces.append(self.bm.faces.new(list(reversed(rings[0]))))
            if r_top > 1e-4:
                faces.append(self.bm.faces.new(rings[-1]))
        verts = [v for ring in rings for v in ring]
        return self.paint(verts, swatch, faces=faces, **kw)

    def cone(self, bottom, top, radius, swatch, segments=8, **kw):
        return self.cylinder(bottom, top, radius, 0.0, swatch, segments=segments, **kw)

    def sphere(self, center, radius, swatch, scale=(1, 1, 1), segments=10, rings=7, rotation=(0, 0, 0), **kw):
        m = self._place(mat(center, rotation, scale))
        made = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings, radius=radius, matrix=m)
        return self.paint(made["verts"], swatch, **kw)

    def ico(self, center, radius, swatch, scale=(1, 1, 1), subdivisions=1, rotation=(0, 0, 0), **kw):
        m = self._place(mat(center, rotation, scale))
        made = bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=radius, matrix=m)
        return self.paint(made["verts"], swatch, **kw)

    def lathe(self, profile, swatch, segments=12, center=(0, 0, 0), caps=True, pattern=None, cap_swatch=None, **kw):
        """A round shape turned from (radius, height) points, bottom to top.
        `pattern(band, segment)` may return a swatch per face (None keeps `swatch`),
        for painted bands; `band` counts profile spans from the bottom."""
        rings = []
        for radius, height in profile:
            ring = []
            for k in range(segments):
                angle = math.tau * k / segments
                local = Vector((center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius, center[2] + height))
                ring.append(self.bm.verts.new(self.matrix @ local))
            rings.append(ring)
        faces = []
        painted = {}
        for band, (lower, upper) in enumerate(zip(rings, rings[1:])):
            for k in range(segments):
                face = self.bm.faces.new((lower[k], lower[(k + 1) % segments], upper[(k + 1) % segments], upper[k]))
                special = pattern(band, k) if pattern else None
                if special:
                    painted.setdefault(special, []).append(face)
                else:
                    faces.append(face)
        caps_made = []
        if caps and profile[0][0] > 1e-4:
            caps_made.append(self.bm.faces.new(list(reversed(rings[0]))))
        if caps and profile[-1][0] > 1e-4:
            caps_made.append(self.bm.faces.new(rings[-1]))
        verts = [v for r in rings for v in r]
        if cap_swatch:
            self.paint(verts, cap_swatch, faces=caps_made, **kw)
        else:
            faces += caps_made
        for special, special_faces in painted.items():
            self.paint(verts, special, faces=special_faces, **kw)
        return self.paint(verts, swatch, faces=faces, **kw)

    def loft(self, rings, swatch, closed=True, caps=True, **kw):
        """Skins a list of rings (each a list of points, same count) in order."""
        made = [[self.bm.verts.new(self.matrix @ Vector(p)) for p in ring] for ring in rings]
        n = len(made[0])
        faces = []
        span = n if closed else n - 1
        for lower, upper in zip(made, made[1:]):
            for k in range(span):
                faces.append(self.bm.faces.new((lower[k], lower[(k + 1) % n], upper[(k + 1) % n], upper[k])))
        if caps and closed:
            faces.append(self.bm.faces.new(list(reversed(made[0]))))
            faces.append(self.bm.faces.new(made[-1]))
        return self.paint([v for r in made for v in r], swatch, faces=faces, **kw)

    def extrude(self, outline, depth, swatch, **kw):
        """A flat shape: `outline` is (x, y) points anticlockwise seen from +Z, extruded
        from z = 0 to z = depth (in the current matrix)."""
        low = [self.bm.verts.new(self.matrix @ Vector((x, y, 0.0))) for x, y in outline]
        high = [self.bm.verts.new(self.matrix @ Vector((x, y, depth))) for x, y in outline]
        faces = [self.bm.faces.new(list(reversed(low))), self.bm.faces.new(high)]
        n = len(outline)
        for k in range(n):
            j = (k + 1) % n
            faces.append(self.bm.faces.new((low[k], low[j], high[j], high[k])))
        return self.paint(low + high, swatch, faces=faces, **kw)

    def polygon(self, points, swatch, **kw):
        """One face through 3D points (in the current matrix)."""
        verts = [self.bm.verts.new(self.matrix @ Vector(p)) for p in points]
        face = self.bm.faces.new(verts)
        return self.paint(verts, swatch, faces=[face], **kw)

    def torus(self, center, major, minor, swatch, segments=16, sides=6, rotation=(0, 0, 0), arc=360.0, **kw):
        m = self._place(mat(center, rotation))
        closed = arc >= 359.99
        count = segments if closed else segments + 1
        rings = []
        for i in range(count):
            a = math.radians(arc) * i / segments
            cx, cy = math.cos(a) * major, math.sin(a) * major
            ring = []
            for j in range(sides):
                b = math.tau * j / sides
                r = major + math.cos(b) * minor
                ring.append(self.bm.verts.new(m @ Vector((math.cos(a) * r, math.sin(a) * r, math.sin(b) * minor))))
            rings.append(ring)
        faces = []
        pairs = list(zip(rings, rings[1:] + ([rings[0]] if closed else [])))
        for lower, upper in pairs:
            for j in range(sides):
                faces.append(self.bm.faces.new((lower[j], upper[j], upper[(j + 1) % sides], lower[(j + 1) % sides])))
        if not closed:
            faces.append(self.bm.faces.new(rings[0]))
            faces.append(self.bm.faces.new(list(reversed(rings[-1]))))
        return self.paint([v for r in rings for v in r], swatch, faces=faces, **kw)

    def tube(self, points, radius, swatch, segments=6, taper=None, **kw):
        """A tube along a polyline; `taper` is a radius per point."""
        radii = taper or [radius] * len(points)
        rings = []
        pts = [Vector(p) for p in points]
        for i, p in enumerate(pts):
            a = pts[max(0, i - 1)]
            b = pts[min(len(pts) - 1, i + 1)]
            direction = (b - a).normalized()
            q = direction.to_track_quat("Z", "Y")
            ring = []
            for k in range(segments):
                ang = math.tau * k / segments
                local = Vector((math.cos(ang) * radii[i], math.sin(ang) * radii[i], 0.0))
                ring.append(tuple(p + q @ local))
            rings.append(ring)
        return self.loft(rings, swatch, closed=True, caps=True, **kw)

    def rock(self, center, radius, swatch, rng, scale=(1, 1, 1), subdivisions=1, roughness=0.22, flat_bottom=True, **kw):
        m = self._place(mat(center, (0, 0, 0), scale))
        made = bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=radius, matrix=m)
        c = m @ Vector((0, 0, 0))
        for vert in made["verts"]:
            out = (vert.co - c).normalized()
            vert.co += out * radius * rng.uniform(-roughness, roughness)
            if flat_bottom:
                vert.co.z = max(vert.co.z, (self.matrix @ Vector((0, 0, 0))).z)
        return self.paint(made["verts"], swatch, **kw)

    def leaf(self, base, direction, length, width, swatch, up=(0, 0, 1), droop=0.25, **kw):
        """A double-sided diamond leaf from `base` along `direction`."""
        base, d = Vector(base), Vector(direction).normalized()
        side = d.cross(Vector(up)).normalized() * width / 2
        mid = base + d * length * 0.45 - Vector(up) * droop * length * 0.2
        tip = base + d * length - Vector(up) * droop * length
        return self.polygon([base, mid - side, tip, mid + side], swatch, double=True, **kw)

    def finish(self, armature=None, parent=None):
        """Makes the mesh object (skinned to `armature` if given) and links it."""
        mesh = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.materials:
            mesh.materials.append(get_material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        if self.bones:
            for bone in self.bones:
                obj.vertex_groups.new(name=bone)
        if armature is not None:
            obj.parent = armature
            modifier = obj.modifiers.new("Armature", "ARMATURE")
            modifier.object = armature
        elif parent is not None:
            obj.parent = parent
        return obj


# --- Collision ----------------------------------------------------------------

def _collider(name, suffix):
    mesh = Mesh(name + suffix)
    return mesh


def collision_box(name, center, size, rotation=(0, 0, 0)):
    """A box Godot turns into a convex collision shape on import, never drawn."""
    m = _collider(name, "-convcolonly")
    m.box(center, size, "basalt", rotation=rotation)
    return m.finish()


def collision_cylinder(name, bottom, top, radius, segments=10):
    m = _collider(name, "-convcolonly")
    m.cylinder(bottom, top, radius, radius, "basalt", segments=segments)
    return m.finish()


# --- Skeletons and actions ----------------------------------------------------

def armature(name, bones):
    """`bones`: name -> (head, tail, parent, connected, roll_hint). roll_hint is the
    world direction the bone's local Z should point (default: the front, -Y, for
    upright and hanging bones; up for bones lying along Y)."""
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, spec in bones.items():
        head, tail, parent, connected = spec[:4]
        roll_hint = spec[4] if len(spec) > 4 else None
        bone = data.edit_bones.new(bone_name)
        bone.head = head
        bone.tail = tail
        direction = Vector(tail) - Vector(head)
        if roll_hint is None:
            roll_hint = (0, 0, 1) if abs(direction.z) < abs(direction.y) else (0, -1, 0)
        bone.align_roll(roll_hint)
        if parent:
            bone.parent = data.edit_bones[parent]
            bone.use_connect = connected
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in obj.pose.bones:
        bone.rotation_mode = "XYZ"
    return obj


def mirrored(name, rotation):
    """(pitch, twist, spread) in degrees → radians for bone `name`. Right-side bones
    take the same signs as left ones; twist and spread are mirrored here."""
    rotation = list(rotation) + [0.0, 0.0, 0.0]
    pitch, twist, spread = rotation[:3]
    if "Right" in name:
        twist, spread = -twist, -spread
    return (math.radians(pitch), math.radians(twist), math.radians(spread))


def key_action(arm, name, keys, loop=False, locations=("Hips", "Root"), interpolation="BEZIER"):
    """`keys` is [(frame, pose)], a pose being {bone: angle | (pitch, twist, spread)}
    plus optional {"loc:<Bone>": (x, y, z)} offsets in the bone's local axes.
    Every bone is keyed at every key, so the action fully decides the body; a loop
    gets its first pose repeated at the end."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    keys = list(keys)
    if loop and len(keys) > 1:
        step = keys[1][0] - keys[0][0]
        last = keys[-1][0]
        # A loop's length is given by an explicit end key or one step after the last.
        keys.append((last + step, keys[0][1]))
    for frame, posed in keys:
        for bone in arm.pose.bones:
            rotation = posed.get(bone.name, (0.0,))
            if isinstance(rotation, (int, float)):
                rotation = (rotation,)
            bone.rotation_euler = mirrored(bone.name, rotation)
            bone.keyframe_insert("rotation_euler", frame=frame)
            if bone.name in locations or f"loc:{bone.name}" in posed:
                bone.location = posed.get(f"loc:{bone.name}", (0.0, 0.0, 0.0))
                bone.keyframe_insert("location", frame=frame)
    if interpolation != "BEZIER":
        _set_interpolation(action, interpolation)
    return action


def _set_interpolation(action, interpolation):
    curves = []
    if hasattr(action, "layers") and len(action.layers):
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    curves.extend(bag.fcurves)
    elif hasattr(action, "fcurves"):
        curves = list(action.fcurves)
    for curve in curves:
        for point in curve.keyframe_points:
            point.interpolation = interpolation


def rest_pose(arm):
    if arm.animation_data:
        arm.animation_data.action = None
    for bone in arm.pose.bones:
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)


# --- Images -----------------------------------------------------------------

def write_png(path, width, height, rows, channels=3):
    """Writes 8-bit PNG bytes exactly as given (no colour management). `rows` are
    `bytes` of width*channels values each, top row first."""
    import struct
    import zlib

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    colour_type = {1: 0, 3: 2, 4: 6}[channels]
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    data = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)


# --- Export -----------------------------------------------------------------

def export_glb(path, animations=False, vertex_colors=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
        export_yup=True,
        export_animations=animations,
        export_vertex_color="ACTIVE" if vertex_colors else "NONE",
        export_image_format="NONE",
        export_morph=False,
    )
    if animations:
        kwargs.update(export_animation_mode="ACTIONS", export_force_sampling=True, export_anim_slide_to_zero=True,
                      export_reset_pose_bones=True, export_def_bones=False)
    bpy.ops.export_scene.gltf(**kwargs)
    return path


def model_path(category, slug):
    return os.path.join(ASSETS, "models", category, slug, slug + ".glb")


def report(tag, slug, path):
    low = Vector((math.inf,) * 3)
    high = Vector((-math.inf,) * 3)
    triangles = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or "-col" in obj.name:
            continue
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            low = Vector(map(min, low, point))
            high = Vector(map(max, high, point))
        triangles += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    size = high - low
    rel = os.path.relpath(path, ROOT)
    log(tag, f"{slug}: {size.x:.2f} x {size.y:.2f} x {size.z:.2f} m, {triangles} tris -> {rel}")


def run(main):
    """Runs a build function, exiting non-zero on any exception so npm notices."""
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
