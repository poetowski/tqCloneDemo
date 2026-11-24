"""Renders a model for review: `npm run render -- <slug|path.glb> [options]`.

Without options: three views (front three-quarter, side, back three-quarter) side by
side, next to a 1.8 m grey reference figure. Options:
  --anim=<action> --frames=0,6,12   pose an animated model at those frames (one view each)
  --view=front|side|back|top|iso     one view only
  --size=512                         pixels per view
  --noref                            leave out the reference figure
  --hide=MeshA,MeshB                 hide meshes (equipment variants)
  --attach=dory:weapon,aspis:shield  mount item models on bones as Godot does
                                     (slots from data/attachments.json)
Animated models are posed at frame 0 of "idle" unless --anim says otherwise.
Writes .shots/models/<slug>[_<anim>].png. Read the PNG to look at it.
"""
import glob
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402

VIEWS = {
    "front": (-30.0, 12.0),
    "side": (-90.0, 8.0),
    "back": (150.0, 12.0),
    "top": (-30.0, 60.0),
    "iso": (-45.0, 35.0),
}


def find_model(name):
    if name.endswith(".glb") and os.path.exists(name):
        return os.path.abspath(name)
    candidates = glob.glob(os.path.join(kit.ASSETS, "models", "**", f"{name}.glb"), recursive=True)
    if not candidates:
        raise FileNotFoundError(f"no model named {name} under assets/models")
    return candidates[0]


def options():
    opts, positional = {}, []
    for arg in kit.script_args():
        if arg.startswith("--"):
            key, _, value = arg[2:].partition("=")
            opts[key] = value or "1"
        else:
            positional.append(arg)
    return opts, positional


def setup_scene(size):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    try:
        scene.eevee.taa_render_samples = 16
    except AttributeError:
        pass
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Standard"
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.32, 0.36, 0.42, 1.0)
    background.inputs["Strength"].default_value = 0.9
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.color = (1.0, 0.9, 0.78)
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun_obj)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 0.8
    fill.color = (0.7, 0.8, 1.0)
    fill_obj = bpy.data.objects.new("Fill", fill)
    fill_obj.rotation_euler = (math.radians(60), 0, math.radians(150))
    scene.collection.objects.link(fill_obj)


def import_model(path):
    before = set(bpy.data.objects)
    materials_before = set(bpy.data.materials)
    bpy.ops.import_scene.gltf(filepath=path)
    objects = [o for o in bpy.data.objects if o not in before]
    # The glb's own "Palette" material has no textures; get it out of the way of
    # kit.palette_material(), which looks materials up by name.
    for material in set(bpy.data.materials) - materials_before:
        material.name = "Imported_" + material.name
    palette = kit.palette_material("Palette")
    for obj in objects:
        if obj.type == "MESH":
            if "-col" in obj.name or "colonly" in obj.name:
                obj.hide_render = True
                continue
            for slot in obj.material_slots:
                if slot.material and slot.material.name.startswith("Imported_Palette"):
                    slot.material = palette
    return objects


def attach(objects, spec):
    """Mounts item models on the armature like src/actors/actor_body.gd does."""
    import json
    from mathutils import Euler, Matrix
    with open(os.path.join(kit.ROOT, "data", "attachments.json"), encoding="utf-8") as handle:
        table = json.load(handle)
    arm = next(o for o in objects if o.type == "ARMATURE")
    added = []
    # Item models are made Z-up in Blender; Godot sees the same model Y-up.
    to_godot = Matrix.Rotation(math.radians(-90), 4, "X")
    for item in filter(None, spec.split(",")):
        slug, slot = item.split(":")
        entry = table[slot]
        bone = arm.data.bones[entry["bone"]]
        for obj in import_model(find_model(slug)):
            added.append(obj)
            if obj.parent is not None:
                continue
            rotation = Euler([math.radians(a) for a in entry["rotation"]], "XYZ").to_matrix().to_4x4()
            offset = Vector(entry["offset"]) - Vector((0, bone.length, 0))
            obj.parent = arm
            obj.parent_type = "BONE"
            obj.parent_bone = entry["bone"]
            obj.matrix_parent_inverse = Matrix.Identity(4)
            obj.matrix_basis = Matrix.Translation(offset) @ rotation @ to_godot
    return added


def pose(objects, action_name, frame):
    for obj in objects:
        if obj.type != "ARMATURE":
            continue
        data = obj.animation_data or obj.animation_data_create()
        for track in list(data.nla_tracks):
            data.nla_tracks.remove(track)
        action = bpy.data.actions.get(action_name)
        if action is None:
            names = ", ".join(a.name for a in bpy.data.actions)
            raise KeyError(f"no action {action_name}; have: {names}")
        data.action = action
        if hasattr(data, "action_slot") and data.action_slot is None and len(getattr(action, "slots", [])):
            data.action_slot = action.slots[0]
    bpy.context.scene.frame_set(int(frame))


def bounds(objects):
    low = Vector((math.inf,) * 3)
    high = Vector((-math.inf,) * 3)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        for vertex in mesh.vertices:
            point = evaluated.matrix_world @ vertex.co
            low = Vector(map(min, low, point))
            high = Vector(map(max, high, point))
        evaluated.to_mesh_clear()
    return low, high


def add_reference(low, high):
    ref = kit.Mesh("Reference")
    x = low.x - 0.5
    ref.cylinder((x, 0, 0.0), (x, 0, 1.5), 0.14, 0.17, "stone_dark", segments=10)
    ref.sphere((x, 0, 1.66), 0.13, "stone_dark", segments=10)
    obj = ref.finish()
    return obj


def add_ground(low, high):
    g = kit.Mesh("Ground")
    radius = max(high.x - low.x, high.y - low.y) * 0.9 + 1.0
    g.cylinder((0, 0, -0.02), (0, 0, 0.0), radius, radius, "limestone", segments=32)
    return g.finish()


def render_view(objects_low, objects_high, yaw, pitch, path, size):
    scene = bpy.context.scene
    center = (objects_low + objects_high) / 2
    extent = max((objects_high - objects_low).length, 0.5)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = extent * 1.08
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    distance = extent * 3 + 5
    yaw_r, pitch_r = math.radians(yaw), math.radians(pitch)
    offset = Vector((math.sin(yaw_r) * math.cos(pitch_r), -math.cos(yaw_r) * math.cos(pitch_r), math.sin(pitch_r))) * distance
    cam.location = center + offset
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def read_png(path):
    image = bpy.data.images.load(path)
    w, h = image.size
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(image)
    return np.flipud(pixels)


def main():
    opts, positional = options()
    if not positional:
        raise SystemExit("usage: preview.py <slug|path.glb>")
    path = find_model(positional[0])
    slug = os.path.splitext(os.path.basename(path))[0]
    size = int(opts.get("size", 512))
    kit.clear_scene()
    setup_scene(size)
    objects = import_model(path)
    if "attach" in opts:
        objects = objects + attach(objects, opts["attach"])
    hidden = set(filter(None, opts.get("hide", "").split(",")))
    for obj in objects:
        if obj.name in hidden or obj.name.split(".")[0] in hidden:
            obj.hide_render = True
    frames = [None]
    if "anim" in opts:
        frames = [int(f) for f in opts.get("frames", "0").split(",")]
    elif any(o.type == "ARMATURE" for o in objects) and bpy.data.actions.get("idle"):
        pose(objects, "idle", 0)
    views = [opts["view"]] if "view" in opts else (["front"] if "anim" in opts else ["front", "side", "back"])
    out_dir = os.path.join(kit.ROOT, ".shots", "models")
    os.makedirs(out_dir, exist_ok=True)
    tiles = []
    extra = []
    for frame in frames:
        if frame is not None:
            pose(objects, opts["anim"], frame)
        low, high = bounds(objects)
        if not extra:
            extra.append(add_ground(low, high))
            if "noref" not in opts:
                extra.append(add_reference(low, high))
        view_low, view_high = low.copy(), high.copy()
        if "noref" not in opts:
            view_low.x = min(view_low.x, low.x - 0.75)
            view_high.z = max(view_high.z, 1.85)
        view_low.z = min(view_low.z, 0.0)
        for index, view in enumerate(views):
            yaw, pitch = VIEWS[view]
            # The reference figure stands at -X: show it in the first view only.
            if len(extra) > 1:
                extra[1].hide_render = index > 0
            tile = os.path.join(out_dir, f"_tile_{len(tiles)}.png")
            render_view(view_low, view_high, yaw, pitch, tile, size)
            tiles.append(tile)
    images = [read_png(t) for t in tiles]
    sheet = np.concatenate(images, axis=1)
    rows = [bytes((np.clip(row[:, :3], 0, 1) * 255 + 0.5).astype(np.uint8).tobytes()) for row in sheet]
    name = f"{slug}_{opts['anim']}" if "anim" in opts else slug
    out = os.path.join(out_dir, f"{name}.png")
    kit.write_png(out, sheet.shape[1], sheet.shape[0], rows)
    for tile in tiles:
        os.remove(tile)
    kit.log("render", f"{os.path.relpath(out, kit.ROOT)} ({len(images)} view(s))")


kit.run(main)
