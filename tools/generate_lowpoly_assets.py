import bpy
import os
import math

OUT_DIR = r"C:\Users\pavlo\anrufen-online-3d\assets\models"
os.makedirs(OUT_DIR, exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_mat(name, color_rgba, roughness=0.6, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color_rgba
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
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

# 1. COTTAGE HOUSE (Stylized Medieval Village)
clear_scene()
mat_stone = create_mat("Stone", (0.55, 0.58, 0.62, 1.0), roughness=0.8)
mat_wood = create_mat("Wood", (0.42, 0.28, 0.16, 1.0), roughness=0.7)
mat_roof = create_mat("Roof", (0.78, 0.25, 0.18, 1.0), roughness=0.5) # Warm reddish-orange roof
mat_door = create_mat("Door", (0.28, 0.18, 0.10, 1.0), roughness=0.6)
mat_window = create_mat("Window", (0.95, 0.85, 0.40, 1.0), roughness=0.2) # Warm glowing yellow

# Base stone walls
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.5))
base = bpy.context.active_object
base.scale = (3.5, 2.5, 3.0)
base.data.materials.append(mat_stone)

# Roof (Pyramid/Prism)
bpy.ops.mesh.primitive_cylinder_add(vertices=3, radius=2.6, depth=4.0, location=(0, 0, 3.8))
roof = bpy.context.active_object
roof.rotation_euler = (0, math.radians(90), 0)
roof.scale = (1.0, 0.9, 1.0)
roof.data.materials.append(mat_roof)

# Chimney
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.0, 0.6, 4.2))
chimney = bpy.context.active_object
chimney.scale = (0.5, 0.5, 1.5)
chimney.data.materials.append(mat_stone)

# Door
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.26, 0.9))
door = bpy.context.active_object
door.scale = (0.8, 0.1, 1.8)
door.data.materials.append(mat_door)

# Windows
for wx in [-1.0, 1.0]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wx, -1.26, 1.8))
    win = bpy.context.active_object
    win.scale = (0.6, 0.1, 0.6)
    win.data.materials.append(mat_window)

export_glb("house_cottage.glb")

# 2. FANTASY TREE (Low Poly Stylized)
clear_scene()
mat_trunk = create_mat("Trunk", (0.35, 0.22, 0.12, 1.0), roughness=0.8)
mat_leaves1 = create_mat("Leaves1", (0.22, 0.58, 0.24, 1.0), roughness=0.6) # Vibrant green
mat_leaves2 = create_mat("Leaves2", (0.18, 0.48, 0.20, 1.0), roughness=0.6)

# Trunk
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.35, depth=2.5, location=(0, 0, 1.25))
trunk = bpy.context.active_object
trunk.data.materials.append(mat_trunk)

# Foliage Cones/Puffs (3 tiers)
tiers = [(2.0, 1.5, 1.2, mat_leaves1), (2.8, 1.2, 1.0, mat_leaves2), (3.6, 0.8, 0.9, mat_leaves1)]
for z, r, h, m in tiers:
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=r, depth=h, location=(0, 0, z))
    puff = bpy.context.active_object
    puff.data.materials.append(m)

export_glb("tree_fantasy.glb")

# 3. ROCK BOULDER
clear_scene()
mat_rock = create_mat("Rock", (0.45, 0.47, 0.50, 1.0), roughness=0.7)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=(0, 0, 0.6))
rock = bpy.context.active_object
rock.scale = (1.2, 0.9, 0.7)
rock.data.materials.append(mat_rock)
export_glb("rock_boulder.glb")

# 4. WOODEN FENCE
clear_scene()
mat_fence = create_mat("FenceWood", (0.48, 0.32, 0.18, 1.0), roughness=0.7)
# Posts
for px in [-1.0, 1.0]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, 0, 0.5))
    post = bpy.context.active_object
    post.scale = (0.12, 0.12, 1.0)
    post.data.materials.append(mat_fence)
# Rails
for rz in [0.35, 0.75]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, rz))
    rail = bpy.context.active_object
    rail.scale = (2.1, 0.06, 0.08)
    rail.data.materials.append(mat_fence)
export_glb("prop_fence.glb")

# 5. HERO WARRIOR (Stylized Low Poly)
clear_scene()
mat_skin = create_mat("Skin", (0.92, 0.76, 0.62, 1.0), roughness=0.5)
mat_armor = create_mat("Armor", (0.28, 0.45, 0.72, 1.0), roughness=0.3, metallic=0.4) # Royal blue steel
mat_boots = create_mat("Boots", (0.20, 0.14, 0.10, 1.0), roughness=0.7)
mat_sword = create_mat("SwordBlade", (0.85, 0.88, 0.92, 1.0), roughness=0.2, metallic=0.9)
mat_gold = create_mat("GoldHilt", (0.92, 0.75, 0.20, 1.0), roughness=0.3, metallic=0.8)

# Torso / Armor
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.1))
torso = bpy.context.active_object
torso.scale = (0.5, 0.3, 0.6)
torso.data.materials.append(mat_armor)

# Head
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.6))
head = bpy.context.active_object
head.scale = (0.35, 0.35, 0.35)
head.data.materials.append(mat_skin)

# Helmet plume
bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.2, depth=0.3, location=(0, 0, 1.85))
plume = bpy.context.active_object
plume.data.materials.append(mat_gold)

# Legs & Boots
for lx in [-0.15, 0.15]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, 0, 0.45))
    leg = bpy.context.active_object
    leg.scale = (0.18, 0.22, 0.7)
    leg.data.materials.append(mat_boots)

# Arms
for ax, side in [(-0.35, -1), (0.35, 1)]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ax, 0, 1.05))
    arm = bpy.context.active_object
    arm.scale = (0.15, 0.18, 0.5)
    arm.data.materials.append(mat_armor)

# Sword (Right hand)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.45, 0.3, 1.1))
blade = bpy.context.active_object
blade.scale = (0.06, 0.03, 0.9)
blade.data.materials.append(mat_sword)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.45, 0.3, 0.7))
hilt = bpy.context.active_object
hilt.scale = (0.22, 0.06, 0.06)
hilt.data.materials.append(mat_gold)

# Shield (Left hand)
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.35, depth=0.08, location=(-0.45, 0.15, 1.05))
shield = bpy.context.active_object
shield.rotation_euler = (math.radians(90), 0, 0)
shield.data.materials.append(mat_armor)

export_glb("hero_warrior.glb")

# 6. NPC VILLAGE ELDER (Stylized Robes & Staff)
clear_scene()
mat_skin = create_mat("Skin", (0.92, 0.76, 0.62, 1.0), roughness=0.5)
mat_robe = create_mat("ElderRobe", (0.20, 0.48, 0.45, 1.0), roughness=0.7) # Sage teal robe
mat_beard = create_mat("WhiteBeard", (0.95, 0.95, 0.95, 1.0), roughness=0.8)
mat_staff = create_mat("MagicStaff", (0.35, 0.20, 0.10, 1.0), roughness=0.6)
mat_gem = create_mat("GemGlow", (0.20, 0.85, 0.95, 1.0), roughness=0.1) # Glowing cyan crystal

# Robe Body
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.45, depth=1.3, location=(0, 0, 0.65))
robe = bpy.context.active_object
robe.data.materials.append(mat_robe)

# Head
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.5))
ehead = bpy.context.active_object
ehead.scale = (0.32, 0.32, 0.32)
ehead.data.materials.append(mat_skin)

# Long Beard
bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.2, depth=0.5, location=(0, -0.15, 1.25))
beard = bpy.context.active_object
beard.rotation_euler = (math.radians(-15), 0, 0)
beard.data.materials.append(mat_beard)

# Staff
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.04, depth=1.8, location=(0.4, -0.1, 0.9))
staff = bpy.context.active_object
staff.data.materials.append(mat_staff)

# Crystal Gem on top
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.12, location=(0.4, -0.1, 1.85))
gem = bpy.context.active_object
gem.data.materials.append(mat_gem)

export_glb("npc_elder.glb")

# 7. MONSTER: FOREST BEAST / WOLF (Stylized Low Poly)
clear_scene()
mat_fur = create_mat("WolfFur", (0.40, 0.30, 0.28, 1.0), roughness=0.8) # Earthy brown/grey
mat_snout = create_mat("WolfSnout", (0.25, 0.18, 0.16, 1.0), roughness=0.7)
mat_eye = create_mat("WolfEye", (0.95, 0.25, 0.15, 1.0), roughness=0.2) # Glowing red eye

# Body
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.7))
mbody = bpy.context.active_object
mbody.scale = (0.5, 1.0, 0.5)
mbody.data.materials.append(mat_fur)

# Head
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.65, 0.9))
mhead = bpy.context.active_object
mhead.scale = (0.35, 0.4, 0.35)
mhead.data.materials.append(mat_fur)

# Snout
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.95, 0.8))
msnout = bpy.context.active_object
msnout.scale = (0.2, 0.3, 0.2)
msnout.data.materials.append(mat_snout)

# Ears
for ex in [-0.15, 0.15]:
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.1, depth=0.25, location=(ex, 0.65, 1.15))
    ear = bpy.context.active_object
    ear.data.materials.append(mat_fur)

# Eyes
for eyx in [-0.12, 0.12]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(eyx, 0.85, 0.95))
    eye = bpy.context.active_object
    eye.scale = (0.05, 0.05, 0.05)
    eye.data.materials.append(mat_eye)

# 4 Legs
for lx, ly in [(-0.2, -0.35), (0.2, -0.35), (-0.2, 0.35), (0.2, 0.35)]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, ly, 0.25))
    leg = bpy.context.active_object
    leg.scale = (0.12, 0.15, 0.5)
    leg.data.materials.append(mat_fur)

# Tail
bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.06, depth=0.6, location=(0, -0.7, 0.8))
tail = bpy.context.active_object
tail.rotation_euler = (math.radians(-45), 0, 0)
tail.data.materials.append(mat_fur)

export_glb("monster_beast.glb")

print("ALL 7 LOW-POLY 3D ASSETS SUCCESSFULLY GENERATED & EXPORTED!")
