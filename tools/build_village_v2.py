"""Reproducible mobile village kit. Run with Blender --background --python.

1 unit = 1m; ground pivots, +Y up on GLB export. Original assets are retained.
Buildings <12k triangles, tree <3k. Four shared 1k material maps, tiled UVs.
"""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/v2'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(75)
report = {}

def vertex_palette(o):
    colors=[tuple(m.diffuse_color) for m in o.data.materials]
    attr=o.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
    for poly in o.data.polygons:
        for li in poly.loop_indices:attr.data[li].color=colors[poly.material_index]
    mat=material('Vertex palette',(1,1,1))
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node=mat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Color'
    mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    o.data.materials.clear();o.data.materials.append(mat)
    for poly in o.data.polygons:poly.material_index=0

def reset(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection = bpy.data.collections.new('COL_' + name)
    bpy.context.scene.collection.children.link(collection)
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children[collection.name]

def material(name, color, texture=None, metal=0, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .82 if not metal else .35
    bs.inputs['Metallic'].default_value = metal
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    if texture:
        p = ROOT / 'assets/textures' / (texture + '.png')
        if p.exists():
            n = m.node_tree.nodes.new('ShaderNodeTexImage')
            n.image = bpy.data.images.load(str(p))
            m.node_tree.links.new(n.outputs['Color'], bs.inputs['Base Color'])
    return m

def finish(o, name, mat, bevel=0):
    o.name = name
    o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Soft crafted edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # World-consistent box projection, retained as actual glTF UV coordinates.
    if o.type == 'MESH':
        uv = o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
        for face in o.data.polygons:
            axis = max(range(3), key=lambda a: abs(face.normal[a]))
            axes = [(1,2),(0,2),(0,1)][axis]
            for li in face.loop_indices:
                p = o.matrix_world @ o.data.vertices[o.data.loops[li].vertex_index].co
                uv.data[li].uv = (p[axes[0]] / 2, p[axes[1]] / 2)
    return o

def box(name, p, size, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p)
    o = bpy.context.object
    o.scale = size
    return finish(o, name, mat, bevel)

def ico(name, p, scale, mat, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=p)
    o = bpy.context.object
    o.scale = scale
    return finish(o, name, mat)

def beam(name, a, b, r, mat, vertices=8, r2=None):
    d = Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r, radius2=r if r2 is None else r2, depth=d.length, location=(Vector(a)+Vector(b))/2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat('Z','Y').to_euler()
    return finish(o, name, mat)

def roof(width, depth, base, rise, mat, wood, x=0, y=0):
    # Two pitched planes with lifted eaves, layered shingle courses and ridge caps.
    verts=[]; faces=[]
    for sign in [-1,1]:
        for j in range(9):
            t0=j/9; t1=(j+1)/9
            xa=sign*(width*.5)*(1-t0); xb=sign*(width*.5)*(1-t1)
            za=base+rise*t0+(.13 if j==0 else 0); zb=base+rise*t1+.035
            for k in range(8):
                ya=-depth/2+depth*k/8; yb=ya+depth/8+.025
                idx=len(verts)
                verts += [(x+xa,y+ya,za),(x+xb,y+ya,zb),(x+xb,y+yb,zb),(x+xa,y+yb,za)]
                faces.append((idx,idx+1,idx+2,idx+3) if sign>0 else (idx+3,idx+2,idx+1,idx))
    mesh=bpy.data.meshes.new('ShingleCourses');mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new('Slate_roof',mesh);bpy.context.collection.objects.link(o)
    finish(o,o.name,mat)
    for yy in [-depth/2,depth/2]:
        beam('Carved verge',(x-width/2,y+yy,base+.1),(x,y+yy,base+rise+.1),.09,wood)
        beam('Carved verge',(x,y+yy,base+rise+.1),(x+width/2,y+yy,base+.1),.09,wood)
    beam('Ridge cap',(x,y-depth/2-.12,base+rise+.1),(x,y+depth/2+.12,base+rise+.1),.13,wood)

def arch_face(x,y,z,w,h,mat):
    points=[(x-w/2,y,z),(x+w/2,y,z),(x+w/2,y,z+h-w/2)]
    for i in range(9):
        a=i*math.pi/8
        points.append((x+math.cos(a)*w/2,y,z+h-w/2+math.sin(a)*w/2))
    mesh=bpy.data.meshes.new('Arch');mesh.from_pydata(points,[],[tuple(range(len(points)))]);mesh.update()
    o=bpy.data.objects.new('Arched opening',mesh);bpy.context.collection.objects.link(o)
    return finish(o,o.name,mat)

def building(hall=False):
    reset('Hall' if hall else 'Cottage')
    stone=material('Limestone',(.56,.55,.48),'cobble')
    plaster=material('Ivory plaster',(.88,.80,.61),'plaster')
    wood=material('Oak beams',(.22,.105,.045),'wood')
    slate=material('Teal slate',(.10,.26,.28),'slate')
    dark=material('Recess',(.045,.055,.052))
    glass=material('Amber glass',(1,.64,.22),emission=.55)
    iron=material('Forged iron',(.13,.19,.19),metal=.65)
    leaf=material('Garden leaves',(.20,.35,.13))
    w,d,h=(7,5.5,5.2) if hall else (4.8,4.2,3.4)
    box('Stone foundation',(0,0,.35),(w+.22,d+.22,.7),stone,.08)
    box('Plaster walls',(0,0,h/2+.35),(w,d,h-.7),plaster,.055)
    # Filled gables under pitched roof.
    for yy in [-d/2,d/2]:
        verts=[(-w/2,yy,h-.05),(w/2,yy,h-.05),(0,yy,h+1.7)]
        me=bpy.data.meshes.new('Gable');me.from_pydata(verts,[],[(0,1,2),(2,1,0)]);me.update()
        ob=bpy.data.objects.new('Gable',me);bpy.context.collection.objects.link(ob);finish(ob,ob.name,plaster)
    roof(w+1,d+1,h-.12,2,slate,wood)
    for xx in [-w/2,-w/4,0,w/4,w/2]:
        for yy in [-d/2-.035,d/2+.035]:
            box('Timber upright',(xx,yy,h/2),(.15,.16,h),wood)
    for z in [.75,h-.12,h*.55]:
        box('Facade cross beam',(0,-d/2-.09,z),(w+.1,.18,.18),wood)
    for xx in [-w/2,w/2]:
        box('Side cross beam',(xx,0,h*.55),(.18,d,.18),wood)
        for yy in [-d/2,d/2]:
            beam('Diagonal brace',(xx,yy*.45,1),(xx,yy,h*.55),.07,wood,6)
    arch_face(0,-d/2-.19,.4,1.25,2.2,dark)
    for xx in [-.52,-.26,0,.26,.52]:
        box('Door plank',(xx,-d/2-.205,1.27),(.22,.06,1.7),wood,.012)
    for zz in [.6,1.8]: box('Door iron strap',(0,-d/2-.25,zz),(1.1,.06,.07),iron)
    ico('Door handle',(.35,-d/2-.30,1.2),(.07,.05,.07),iron,2)
    for xx in [-w*.31,w*.31]:
        for zz in ([1.7,3.8] if hall else [1.7]):
            arch_face(xx,-d/2-.14,zz-.5,.85,1.25,dark)
            box('Glowing window',(xx,-d/2-.17,zz),(.62,.035,.83),glass,.01)
            box('Window mullion',(xx,-d/2-.23,zz),(.055,.04,.9),wood)
            box('Window rail',(xx,-d/2-.24,zz),(.72,.04,.055),wood)
            for side in [-1,1]: box('Shutter',(xx+side*.47,-d/2-.15,zz),(.23,.12,.95),wood)
            box('Stone sill',(xx,-d/2-.29,zz-.53),(1.05,.4,.12),stone)
    for i in range(3):box('Entry step',(0,-d/2-.45-i*.28,.32-i*.1),(1.8+i*.25,.65,.22),stone,.04)
    roof(2.6,1.65,2.65,.5,slate,wood,y=-d/2-.4)
    for xx in [-1.1,1.1]:beam('Porch post',(xx,-d/2-1.05,.2),(xx,-d/2-1.05,2.7),.08,wood)
    box('Chimney',(w*.28,d*.16,h+1.3),(.65,.7,2.7),stone,.05)
    box('Chimney crown',(w*.28,d*.16,h+2.68),(.88,.9,.22),stone,.04)
    for xx in [-w*.34,w*.34]:
        box('Planter',(xx,-d/2-.44,.4),(1.2,.65,.5),wood)
        for j in range(4):ico('Shrub',(xx+random.uniform(-.45,.45),-d/2-.44,.85),(.3,.28,.3),leaf,1)
    if hall:
        box('Bell tower',(2.25,1,h+1.8),(1.5,1.7,3.4),plaster)
        for xx in [1.5,3]:
            for yy in [.15,1.85]:beam('Belfry pillar',(xx,yy,h+3),(xx,yy,h+4.1),.09,wood)
        beam('Bell',(2.25,1,h+3.1),(2.25,1,h+3.7),.4,iron,12,r2=.18)
        roof(2.5,2.7,h+4.1,1.3,slate,wood,x=2.25,y=1)
        box('Civic blue banner',(-2,-d/2-.28,3.7),(.65,.06,1.6),slate)
    export('hall' if hall else 'cottage')

def tree():
    reset('Oak')
    bark=material('Oak bark',(.23,.13,.065),'wood')
    leaves=[material('Canopy %d'%i,c) for i,c in enumerate([(.035,.085,.022),(.055,.13,.03),(.085,.18,.045),(.14,.23,.065)])]
    beam('Trunk',(0,0,0),(.12,.08,3.9),.32,bark,9,r2=.13)
    for a in range(7):
        ang=a*math.tau/7
        end=(math.cos(ang)*1.45,math.sin(ang)*1.45,3.5+random.random())
        beam('Branch',(.04,0,1.8+random.random()),end,.13,bark,6,r2=.045)
        ico('Leaf crown',end,(1.5,1.4,1.1),leaves[a%4],2)
    ico('Top crown',(0,0,4.8),(1.65,1.5,1.3),leaves[2],2)
    for a in range(5):
        ang=a*math.tau/5
        beam('Root',(0,0,.4),(math.cos(ang)*.75,math.sin(ang)*.75,.07),.13,bark,6,r2=.03)
    export('oak')

def jackal():
    reset('Jackal')
    fur=material('Ochre fur',(.43,.29,.13));dark=material('Dark fur',(.15,.14,.12))
    ivory=material('Fangs',(.87,.80,.59));eye=material('Eyes',(.95,.43,.08),emission=.5)
    ico('Body',(0,0,.82),(.42,.8,.43),fur,2)
    ico('Mane',(0,-.43,1.03),(.45,.4,.47),dark,2)
    ico('Head',(0,-.75,1.23),(.30,.36,.32),fur,2)
    ico('Muzzle',(0,-1.06,1.14),(.19,.34,.15),fur,1)
    ico('Nose',(0,-1.35,1.16),(.13,.09,.09),dark)
    for side in [-1,1]:
        beam('Pointed ear',(side*.22,-.66,1.4),(side*.26,-.65,1.87),.18,fur,3,r2=0)
        ico('Eye',(side*.24,-.94,1.32),(.055,.065,.045),eye)
        beam('Fang',(side*.12,-1.17,1.12),(side*.12,-1.18,.96),.035,ivory,6,r2=0)
        for yy in [-.5,.5]:
            beam('Leg',(side*.28,yy,.75),(side*.3,yy+.14,.12),.105,fur,7,r2=.065)
            ico('Paw',(side*.3,yy+.05,.13),(.13,.22,.12),dark)
    beam('Tail',(0,.65,.9),(0,1.3,.58),.14,fur,7,r2=.05)
    export('jackal')

def character(elder=False, role=None):
    reset('Elder' if elder else 'Wayfarer')
    skin=material('Warm skin',(.66,.42,.26))
    cloth=material('Covenant teal',(.20,.075,.035) if role=='bandit' else ((.075,.24,.27) if not elder else (.29,.19,.31)))
    leather=material('Leather',(.19,.095,.045))
    steel=material('Blue steel',(.35,.47,.49),metal=.65)
    trim=material('Old gold',(.70,.47,.18),metal=.6)
    hair=material('Hair',(.12,.065,.035) if not elder or role=='anna' else (.70,.70,.62))
    eyes=material('Eyes',(.035,.045,.043))
    ivory=material('Eye white',(.91,.86,.72))
    # Broad readable chest, layered coat and fitted belt.
    ico('Coat torso',(0,0,1.12),(.30,.19,.38),cloth,2)
    beam('Coat hem',(0,0,.64),(0,0,1.05),.31,cloth,8,r2=.24)
    box('Belt',(0,-.015,.91),(.53,.40,.08),leather,.025)
    box('Buckle',(0,-.23,.91),(.12,.055,.1),trim,.012)
    if not elder:
        ico('Breastplate',(0,-.12,1.21),(.26,.105,.25),steel,2)
        for x in [-.29,.29]:ico('Shoulder plate',(x,0,1.39),(.18,.20,.15),steel,1)
        # Back cloak has a shaped hem, visible above the waist.
        me=bpy.data.meshes.new('Cloak')
        me.from_pydata([(-.24,.16,1.4),(.24,.16,1.4),(.36,.28,.62),(0,.30,.56),(-.36,.28,.62)],[],[(0,1,2,3,4),(4,3,2,1,0)]);me.update()
        ob=bpy.data.objects.new('Cloak',me);bpy.context.collection.objects.link(ob);finish(ob,ob.name,cloth)
    beam('Neck',(0,0,1.4),(0,0,1.55),.10,skin,10)
    ico('Face',(0,-.025,1.68),(.205,.175,.245),skin,2)
    ico('Hair cap',(0,.018,1.83),(.216,.183,.13),hair,2)
    for x in [-.18,.18]:ico('Ear',(x,-.015,1.68),(.05,.065,.08),skin,1)
    ico('Nose',(0,-.188,1.66),(.05,.065,.065),skin,1)
    for x in [-.082,.082]:
        ico('Eye',(x,-.179,1.725),(.048,.027,.035),ivory,1)
        ico('Pupil',(x,-.204,1.725),(.021,.009,.026),eyes,1)
        box('Brow',(x,-.184,1.77),(.09,.027,.018),hair,.002)
    if elder and role!='anna':ico('Beard',(0,-.12,1.52),(.145,.12,.18),hair,1)
    if role=='anna':
        beam('Long skirt',(0,0,.15),(0,0,.85),.36,cloth,10,r2=.26)
        for side in [-1,1]:ico('Hair lock',(side*.16,.04,1.64),(.09,.16,.22),hair,2)
    def pivot(name,p,items):
        bpy.ops.object.select_all(action='DESELECT')
        for o in items:o.select_set(True)
        bpy.context.view_layer.objects.active=items[0]
        bpy.ops.object.join()
        items=[bpy.context.object]
        vertex_palette(items[0])
        parent=bpy.data.objects.new(name,None);parent.location=p
        bpy.context.collection.objects.link(parent)
        bpy.context.view_layer.update()
        for o in items:
            world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
    for side in [-1,1]:
        x=side*.32
        arm=[beam('Sleeve',(x,0,1.37),(side*.39,-.02,1.04),.11,cloth,8,r2=.08),beam('Bracer',(side*.39,-.02,1.04),(side*.42,-.07,.84),.085,leather,8),ico('Hand',(side*.42,-.07,.80),(.085,.075,.10),skin,1)]
        if side==1 and not elder:
            arm += [box('Sword grip',(.43,-.10,.81),(.06,.07,.30),leather,.01),box('Sword crossguard',(.43,-.10,.96),(.32,.09,.06),trim,.01)]
            me=bpy.data.meshes.new('Blade')
            me.from_pydata([(.36,-.1,1),(.5,-.1,1),(.5,-.1,1.65),(.43,-.1,1.82),(.36,-.1,1.65),(.43,-.15,1.25)],[],[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5),(4,3,2,1,0)]);me.update()
            ob=bpy.data.objects.new('Sword blade',me);bpy.context.collection.objects.link(ob);finish(ob,ob.name,steel);arm.append(ob)
        if side==-1 and not elder:
            arm.append(ico('Shield',(-.49,-.14,1.02),(.08,.30,.39),steel,2))
            arm.append(ico('Shield boss',(-.57,-.14,1.02),(.045,.11,.11),trim,1))
        pivot('Arm_L' if side<0 else 'Arm_R',(x,0,1.39),arm)
        leg=[beam('Trouser',(side*.14,0,.76),(side*.14,0,.35),.11,cloth,8,r2=.085),beam('Boot',(side*.14,0,.37),(side*.14,0,.12),.10,leather,8),ico('Foot',(side*.14,-.07,.1),(.12,.22,.1),leather,1)]
        pivot('Leg_L' if side<0 else 'Leg_R',(side*.14,0,.76),leg)
    # Join static torso meshes, leave the four articulated limbs independent.
    static=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.parent]
    bpy.ops.object.select_all(action='DESELECT')
    for o in static:o.select_set(True)
    bpy.context.view_layer.objects.active=static[0];bpy.ops.object.join()
    bpy.context.object.name='Body'
    vertex_palette(bpy.context.object)
    for root in [o for o in bpy.context.scene.objects if not o.parent]:
        root.rotation_euler.z+=math.pi
        root.location.x*=-1;root.location.y*=-1
    tris=sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    name=role if role else ('elder' if elder else 'wayfarer')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_apply=True,export_yup=True)
    report[name]={'polygons':tris,'articulated_limbs':4}

def fountain():
    reset('Fountain')
    stone=material('Weathered limestone',(.28,.30,.25),'cobble')
    dark=material('Wet stone',(.10,.15,.13))
    bronze=material('Aged bronze',(.16,.24,.17),metal=.65)
    for i in range(12):
        a=i*math.tau/12
        o=box('Basin coping',(math.cos(a)*2.15,math.sin(a)*2.15,.48),(1.16,.52,.6),stone,.045)
        o.rotation_euler.z=a+math.pi/2
    beam('Pool floor',(0,0,.1),(0,0,.23),2.16,dark,48)
    beam('Pedestal',(0,0,.2),(0,0,1.55),.35,stone,8,r2=.25)
    for zz,r in [(.4,.65),(1.5,.8),(1.68,.9)]:beam('Carved bowl',(0,0,zz),(0,0,zz+.15),r,stone,12,r2=r*.9)
    beam('Spout',(0,0,1.68),(0,0,2.35),.14,bronze,10,r2=.08)
    ico('Acorn finial',(0,0,2.35),(.24,.24,.35),bronze,2)
    export('fountain')

def export(name):
    # One mesh with shared material surfaces to limit scene nodes/draw overhead.
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.ops.object.join()
    o=bpy.context.object
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    o.name='SM_'+name
    o.data.calc_loop_triangles()
    tris=len(o.data.loop_triangles)
    assert tris<16000,(name,tris)
    # Consolidate duplicate material slots inherited by joining primitives.
    mats=list(o.data.materials); unique=[]; remap={}
    for i,m in enumerate(mats):
        if m not in unique:unique.append(m)
        remap[i]=unique.index(m)
    indices=[remap[p.material_index] for p in o.data.polygons]
    o.data.materials.clear()
    for m in unique:o.data.materials.append(m)
    for p,i in zip(o.data.polygons,indices):p.material_index=i
    if name in ['oak','boar','spider']:vertex_palette(o)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    report[name]={'triangles':tris,'materials':len(unique),'dimensions_m':list(o.dimensions)}
    print('ASSET',name,report[name])

building(False)
building(True)
tree()
jackal()
character(False)
character(True)
character(True,'anna')
character(False,'bandit')
fountain()
for name in ['boar','spider']:
    reset('Optimized_'+name)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models'/('monster_'+name+'.glb')))
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':
            world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
    export(name)
(OUT/'budgets.json').write_text(json.dumps(report,indent=2))
