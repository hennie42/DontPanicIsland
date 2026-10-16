"""Blender: the two intro gags, low-poly and flat-coloured like the Kenney kits (director-made, ticket C1).

blender -b -P tools/make_intro_props.py   -> assets/generated/whale.glb, assets/generated/petunias.glb
Units: about 1 tile = 1.0. The whale is ~1.6 long, the bowl ~0.35 tall. Origins at the bottom centre.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/generated")
os.makedirs(OUT, exist_ok=True)


def mat(name, rgb, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def srgb(h):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))


def obj_from_bm(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def ellipsoid(name, size, segs, rings, material, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return obj_from_bm(name, bm, material)


def cone(name, r1, r2, depth, segs, material, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    m = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return obj_from_bm(name, bm, material)


def export(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo = Vector((min(v.co.x for v in o.data.vertices), min(v.co.y for v in o.data.vertices), min(v.co.z for v in o.data.vertices)))
    hi = Vector((max(v.co.x for v in o.data.vertices), max(v.co.y for v in o.data.vertices), max(v.co.z for v in o.data.vertices)))
    o.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")
    print("wrote", path, "size", tuple(round(x, 2) for x in (hi - lo)))


# ---------------------------------------------------------------- the whale (surprised, mid-fall)
bpy.ops.wm.read_factory_settings(use_empty=True)
blue = mat("whale_blue", srgb("#5b7fa6"))
belly = mat("whale_belly", srgb("#d9e4ef"))
white = mat("eye_white", srgb("#ffffff"), 0.4)
black = mat("eye_black", srgb("#1c1c22"), 0.3)
# +X is the front. A blocky sperm-whale head: a big box-ish front, tapering body
ellipsoid("body", (0.75, 0.3, 0.3), 10, 7, blue, (-0.15, 0, 0.34))
# the sperm whale's big square head: a bevelled box, flat at the front
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.12, segments=2, affect="EDGES")
bmesh.ops.scale(bm, vec=Vector((0.95, 0.62, 0.7)), verts=bm.verts)
bmesh.ops.translate(bm, vec=Vector((0.5, 0, 0.42)), verts=bm.verts)
obj_from_bm("head", bm, blue)
ellipsoid("belly", (0.62, 0.26, 0.16), 10, 6, belly, (0.1, 0, 0.18))
cone("tail", 0.18, 0.05, 0.55, 8, blue, (-0.95, 0, 0.36), (0, math.radians(90), 0))
# tail flukes: two flattened cones spread sideways
for side in (-1, 1):
    cone(f"fluke{side}", 0.16, 0.02, 0.38, 6, blue, (-1.25, side * 0.18, 0.36), (0, math.radians(90), math.radians(side * 50)))
    bpy.context.active_object
# flippers
for side in (-1, 1):
    cone(f"flipper{side}", 0.1, 0.02, 0.3, 6, blue, (0.25, side * 0.36, 0.2), (math.radians(side * 60), 0, 0))
# big surprised eyes
for side in (-1, 1):
    ellipsoid(f"eye{side}", (0.075, 0.03, 0.075), 8, 6, white, (0.55, side * 0.315, 0.45))
    ellipsoid(f"pupil{side}", (0.035, 0.02, 0.035), 6, 4, black, (0.58, side * 0.34, 0.46))
# open "oh no" mouth
ellipsoid("mouth", (0.06, 0.13, 0.045), 8, 4, black, (0.95, 0, 0.2))
for o in bpy.context.scene.objects:
    o.scale = (1, 1, 1)
export(os.path.join(OUT, "whale.glb"))

# ---------------------------------------------------------------- the bowl of petunias ("oh no, not again")
bpy.ops.wm.read_factory_settings(use_empty=True)
terracotta = mat("pot", srgb("#c9653b"))
soil = mat("soil", srgb("#5a3a22"))
leaf = mat("leaf", srgb("#3f9b4a"))
petal_a = mat("petal_pink", srgb("#e85fa7"))
petal_b = mat("petal_purple", srgb("#9b5de5"))
centre = mat("centre", srgb("#fde74c"))
cone("bowl", 0.11, 0.17, 0.16, 10, terracotta, (0, 0, 0.08))
cone("soil", 0.155, 0.155, 0.02, 10, soil, (0, 0, 0.155))
for i in range(7):
    a = i / 7 * math.tau
    r = 0.09 if i else 0.0
    x, y = math.cos(a) * r, math.sin(a) * r
    h = 0.24 + 0.03 * math.sin(i * 1.7)
    cone(f"stem{i}", 0.008, 0.008, h - 0.16, 4, leaf, (x, y, 0.16 + (h - 0.16) / 2))
    cone(f"leaf{i}", 0.04, 0.0, 0.08, 4, leaf, (x * 1.3, y * 1.3, 0.2), (math.radians(70), 0, a))
    pm = petal_a if i % 2 else petal_b
    for k in range(5):
        b = k / 5 * math.tau
        ellipsoid(f"petal{i}_{k}", (0.03, 0.018, 0.01), 6, 4, pm, (x + math.cos(b) * 0.025, y + math.sin(b) * 0.025, h))
    ellipsoid(f"centre{i}", (0.012, 0.012, 0.012), 6, 4, centre, (x, y, h + 0.008))
export(os.path.join(OUT, "petunias.glb"))
