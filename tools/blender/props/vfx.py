"""Meshes for effects, all in one file (assets/models/vfx/vfx_kit/vfx_kit.glb). Godot's
effect shaders (src/shaders/vfx_*.gdshader) draw colour and fades from their UVs:

  Shard  a spark: thin diamond along +Z (Godot +Y)
  Mote   a tiny icosphere: Styx motes, embers
  Ring   flat annulus, radius 1, on the ground; u around, v across (0 inner, 1 outer)
  Disc   flat disc, radius 1; u = angle / 360 from +Y (Godot -Z... see vfx.gd), v = radius
  Lane   flat strip 1 wide, 1 long ahead (-Y here, Godot +Z); v = along
  Arc    a 180-degree crescent ribbon for weapon swings; u = along the arc, v across
  Beam   open cylinder radius 1, height 1; v = height
They use a material named "VFX", which the import leaves alone.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def mesh_object(name, build):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    build(bm, uv)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mat = bpy.data.materials.get("VFX") or bpy.data.materials.new("VFX")
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def quad(bm, uv, corners, uvs):
    verts = [bm.verts.new(c) for c in corners]
    face = bm.faces.new(verts)
    for loop, coords in zip(face.loops, uvs):
        loop[uv].uv = coords
    return face


def shard(bm, uv):
    pts = [(0, 0, 0.0), (0.025, 0, 0.05), (0, 0.025, 0.05), (-0.025, 0, 0.05), (0, -0.025, 0.05), (0, 0, 0.16)]
    v = [bm.verts.new(p) for p in pts]
    for a, b in ((1, 2), (2, 3), (3, 4), (4, 1)):
        for f in (bm.faces.new((v[0], v[b], v[a])), bm.faces.new((v[5], v[a], v[b]))):
            for loop in f.loops:
                loop[uv].uv = (0.5, loop.vert.co.z / 0.16)


def mote(bm, uv):
    made = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.05)
    for face in {f for v in made["verts"] for f in v.link_faces}:
        for loop in face.loops:
            loop[uv].uv = (0.5, 0.5)


def ring(bm, uv, segments=48, inner=0.9):
    for i in range(segments):
        a0, a1 = math.tau * i / segments, math.tau * (i + 1) / segments
        corners = [(math.cos(a0) * inner, math.sin(a0) * inner, 0), (math.cos(a0), math.sin(a0), 0),
                   (math.cos(a1), math.sin(a1), 0), (math.cos(a1) * inner, math.sin(a1) * inner, 0)]
        quad(bm, uv, corners, [(i / segments, 0), (i / segments, 1), ((i + 1) / segments, 1), ((i + 1) / segments, 0)])


def disc(bm, uv, segments=48, rings_=4):
    # Angle measured from -Y (the front, Godot +Z), so shaders can cut sectors ahead.
    for r in range(rings_):
        r0, r1 = r / rings_, (r + 1) / rings_
        for i in range(segments):
            a0, a1 = math.tau * i / segments, math.tau * (i + 1) / segments

            def p(a, rad):
                return (math.sin(a) * rad, -math.cos(a) * rad, 0)
            quad(bm, uv, [p(a0, r0), p(a1, r0), p(a1, r1), p(a0, r1)],
                 [(i / segments, r0), ((i + 1) / segments, r0), ((i + 1) / segments, r1), (i / segments, r1)])


def lane(bm, uv, steps=8):
    for i in range(steps):
        y0, y1 = -i / steps, -(i + 1) / steps
        quad(bm, uv, [(-0.5, y0, 0), (0.5, y0, 0), (0.5, y1, 0), (-0.5, y1, 0)], [(0, -y0), (1, -y0), (1, -y1), (0, -y1)])


def arc(bm, uv, segments=24):
    for i in range(segments):
        t0, t1 = i / segments, (i + 1) / segments
        a0, a1 = math.pi * t0 - math.pi / 2, math.pi * t1 - math.pi / 2

        def w(t):
            return 0.08 + 0.22 * math.sin(math.pi * t) ** 0.7

        def p(a, rad):
            return (math.sin(a) * rad, -math.cos(a) * rad, 0)
        quad(bm, uv, [p(a0, 1 - w(t0)), p(a1, 1 - w(t1)), p(a1, 1), p(a0, 1)], [(t0, 0), (t1, 0), (t1, 1), (t0, 1)])


def beam(bm, uv, segments=16):
    for i in range(segments):
        a0, a1 = math.tau * i / segments, math.tau * (i + 1) / segments
        quad(bm, uv, [(math.cos(a0), math.sin(a0), 0), (math.cos(a1), math.sin(a1), 0), (math.cos(a1), math.sin(a1), 1), (math.cos(a0), math.sin(a0), 1)],
             [(i / segments, 0), ((i + 1) / segments, 0), ((i + 1) / segments, 1), (i / segments, 1)])


def main():
    kit.clear_scene()
    for name, build in (("Shard", shard), ("Mote", mote), ("Ring", ring), ("Disc", disc), ("Lane", lane), ("Arc", arc), ("Beam", beam)):
        mesh_object(name, build)
    out = kit.export_glb(kit.model_path("vfx", "vfx_kit"))
    kit.log("asset", f"vfx_kit: 7 meshes -> {os.path.relpath(out, kit.ROOT)}")


kit.run(main)
