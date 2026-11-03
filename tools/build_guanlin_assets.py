import bpy
import os
import math

OUT_DIR = r"C:\Users\pavlo\anrufen-online-3d\assets\models"
os.makedirs(OUT_DIR, exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_mat(name, color_rgba, roughness=0.6, metallic=0.0, emission=None):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color_rgba
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat

def export_glb(filename):
    filepath = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=False,
        export_apply=True
    )
    print(f"[Blender] Exported {filename} -> {os.path.getsize(filepath)} bytes")

# 1. MAYOR TOWN HALL (Guanlin Town Hall - 观林镇政厅)
clear_scene()
m_stone = create_mat("Stone", (0.50, 0.52, 0.56, 1.0), roughness=0.8)
m_wood = create_mat("Wood", (0.38, 0.24, 0.14, 1.0), roughness=0.7)
m_roof = create_mat("RoofBlue", (0.22, 0.38, 0.65, 1.0), roughness=0.5) # Regal blue tiled roof
m_gold = create_mat("Gold", (0.95, 0.75, 0.20, 1.0), roughness=0.3, metallic=0.7)
m_win = create_mat("Win", (0.95, 0.90, 0.50, 1.0), roughness=0.2, emission=(0.95, 0.90, 0.50, 1.0))

# Main building
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 2.5))
hall = bpy.context.active_object
hall.scale = (7.0, 5.0, 5.0)
hall.data.materials.append(m_stone)

# Roof
bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=3.8, depth=7.4, location=(0, 0, 6.2))
hroof = bpy.context.active_object
hroof.rotation_euler = (0, math.radians(90), 0)
hroof.scale = (1.0, 0.85, 1.0)
hroof.data.materials.append(m_roof)

# Bell Tower
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(2.5, 1.5, 6.5))
tower = bpy.context.active_object
tower.scale = (2.0, 2.0, 4.0)
tower.data.materials.append(m_stone)

bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.6, depth=2.5, location=(2.5, 1.5, 9.5))
troof = bpy.context.active_object
troof.data.materials.append(m_roof)

# Entrance arch pillars
for px in [-1.5, 1.5]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, -2.6, 1.8))
    col = bpy.context.active_object
    col.scale = (0.5, 0.5, 3.6)
    col.data.materials.append(m_wood)

export_glb("building_hall.glb")

# 2. CENTRAL FOUNTAIN / WELL (Town Plaza Landmark)
clear_scene()
m_stone = create_mat("FountainStone", (0.6, 0.62, 0.65, 1.0), roughness=0.7)
m_water = create_mat("Water", (0.2, 0.65, 0.9, 0.8), roughness=0.1)

# Outer basin
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=3.0, depth=0.8, location=(0, 0, 0.4))
basin = bpy.context.active_object
basin.data.materials.append(m_stone)

# Water disc
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=2.7, depth=0.1, location=(0, 0, 0.75))
water = bpy.context.active_object
water.data.materials.append(m_water)

# Center pillar
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.8, depth=2.2, location=(0, 0, 1.1))
cpillar = bpy.context.active_object
cpillar.data.materials.append(m_stone)

# Top basin
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.4, depth=0.4, location=(0, 0, 2.3))
tbasin = bpy.context.active_object
tbasin.data.materials.append(m_stone)

export_glb("prop_fountain.glb")

# 3. TRAINING DUMMY (Militia Grounds - 民兵训练人偶)
clear_scene()
m_wood = create_mat("DummyWood", (0.45, 0.30, 0.18, 1.0), roughness=0.8)
m_straw = create_mat("DummyStraw", (0.85, 0.75, 0.40, 1.0), roughness=0.9)

# Base stand
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.12, depth=2.0, location=(0, 0, 1.0))
post = bpy.context.active_object
post.data.materials.append(m_wood)

# Straw torso
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.4, depth=1.0, location=(0, 0, 1.4))
dtorso = bpy.context.active_object
dtorso.data.materials.append(m_straw)

# Head
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.28, location=(0, 0, 2.1))
dhead = bpy.context.active_object
dhead.data.materials.append(m_straw)

# Cross arm
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.08, depth=1.6, location=(0, 0, 1.6))
darms = bpy.context.active_object
darms.rotation_euler = (0, 0, math.radians(90))
darms.data.materials.append(m_wood)

export_glb("prop_training_dummy.glb")

# 4. WILD BOAR (野猪 - Starting Lv.1-2 Monster)
clear_scene()
m_boar_skin = create_mat("BoarSkin", (0.35, 0.22, 0.18, 1.0), roughness=0.8)
m_boar_belly = create_mat("BoarBelly", (0.45, 0.32, 0.26, 1.0), roughness=0.8)
m_tusk = create_mat("BoarTusk", (0.92, 0.90, 0.82, 1.0), roughness=0.4)
m_eye = create_mat("BoarEye", (0.9, 0.1, 0.1, 1.0), roughness=0.3, emission=(0.9, 0.1, 0.1, 1.0))

# Stout body
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.65))
bbody = bpy.context.active_object
bbody.scale = (0.7, 1.2, 0.65)
bbody.data.materials.append(m_boar_skin)

# Snout/Head
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.75, 0.65))
bhead = bpy.context.active_object
bhead.scale = (0.5, 0.6, 0.5)
bhead.data.materials.append(m_boar_skin)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 1.1, 0.5))
bsnout = bpy.context.active_object
bsnout.scale = (0.3, 0.25, 0.3)
bsnout.data.materials.append(m_boar_belly)

# 2 Tusks curving up
for tx in [-0.2, 0.2]:
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.06, depth=0.35, location=(tx, 1.05, 0.55))
    tusk = bpy.context.active_object
    tusk.rotation_euler = (math.radians(-35), 0, math.radians(-15 if tx < 0 else 15))
    tusk.data.materials.append(m_tusk)

# 4 Stocky legs
for lx, ly in [(-0.3, -0.4), (0.3, -0.4), (-0.3, 0.4), (0.3, 0.4)]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, ly, 0.25))
    bleg = bpy.context.active_object
    bleg.scale = (0.16, 0.2, 0.5)
    bleg.data.materials.append(m_boar_skin)

export_glb("monster_boar.glb")

# 5. GIANT SPIDER (饥饿织网者 / 蜘蛛 - Starting Lv.2-3 Monster)
clear_scene()
m_spider = create_mat("SpiderBlack", (0.12, 0.12, 0.15, 1.0), roughness=0.6)
m_spider_red = create_mat("SpiderRed", (0.85, 0.15, 0.15, 1.0), roughness=0.4, emission=(0.85, 0.15, 0.15, 1.0))

# Cephalothorax
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.4, location=(0, 0.2, 0.45))
sthorax = bpy.context.active_object
sthorax.scale = (0.8, 1.0, 0.6)
sthorax.data.materials.append(m_spider)

# Abdomen
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0, -0.6, 0.6))
sabdomen = bpy.context.active_object
sabdomen.scale = (0.9, 1.2, 0.8)
sabdomen.data.materials.append(m_spider)

# Glowing cluster of eyes
for ex in [-0.15, -0.05, 0.05, 0.15]:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=0, radius=0.04, location=(ex, 0.55, 0.5))
    eye = bpy.context.active_object
    eye.data.materials.append(m_spider_red)

# 8 Spindly Legs (4 left, 4 right)
for i in range(4):
    y_pos = 0.3 - (i * 0.25)
    for side, sign_x in [("L", -1), ("R", 1)]:
        # Upper leg
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.04, depth=0.7, location=(sign_x * 0.6, y_pos, 0.6))
        leg1 = bpy.context.active_object
        leg1.rotation_euler = (0, 0, math.radians(-45 * sign_x))
        leg1.data.materials.append(m_spider)
        # Lower leg
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.03, depth=0.8, location=(sign_x * 0.95, y_pos, 0.25))
        leg2 = bpy.context.active_object
        leg2.rotation_euler = (0, 0, math.radians(35 * sign_x))
        leg2.data.materials.append(m_spider)

export_glb("monster_spider.glb")

print("GUANLIN TOWN ASSET EXPANSION EXPORTED SUCCESSFULLY!")
