"""Authored silhouette and construction refinements to the equipment library."""
import math
from art_src.character_geometry import (CharacterMesh, Vec3, create_box,
    create_cylinder, create_ring_torus, get_uv_center)


def prism(outline, thickness, region):
    mesh=CharacterMesh()
    uv=get_uv_center(region)
    for y in (-thickness/2,thickness/2):
        for x,z in outline:
            mesh.add_vertex(Vec3(x,y,z),uv)
    n=len(outline)
    mesh.faces.append(list(range(n-1,-1,-1)))
    mesh.loop_uvs.extend([uv]*n)
    mesh.faces.append(list(range(n,n*2)))
    mesh.loop_uvs.extend([uv]*n)
    for i in range(n):
        j=(i+1)%n
        mesh.add_quad(i,j,j+n,i+n)
    return mesh


def cloak(name, length, width, region):
    mesh=CharacterMesh(name)
    # Double-sided cloth with a thin hem, rather than a solid conical volume.
    rows=6; columns=9
    for depth in (0,.006):
        for i in range(rows):
            t=i/(rows-1)
            for j in range(columns):
                u=j/(columns-1)*2-1
                x=u*(.09+(width-.09)*t)
                z=-length*t+.025*math.cos(u*4*math.pi)*t*t
                y=.025+.09*t+.018*math.cos(u*4*math.pi)+depth
                mesh.add_vertex(Vec3(x,y,z),get_uv_center(region))
    layer=rows*columns
    for i in range(rows-1):
        for j in range(columns-1):
            a=i*columns+j; b=a+1; c=b+columns; d=a+columns
            mesh.add_quad(a,b,c,d)
            mesh.add_quad(d+layer,c+layer,b+layer,a+layer)
    border=list(range(columns))+[i*columns+columns-1 for i in range(1,rows)]
    border+=list(range(rows*columns-2,(rows-1)*columns-1,-1))
    border+=[i*columns for i in range(rows-2,0,-1)]
    for i,a in enumerate(border):
        b=border[(i+1)%len(border)]
        mesh.add_quad(a,a+layer,b+layer,b)
    return mesh


def refine_gear(gear, role):
    if role=='warrior':
        round_sh=CharacterMesh('Round_Shield')
        # Open iron rim and front-facing wood disc. The former closed iron
        # cylinder completely hid its inset wood panel.
        round_sh.merge(create_cylinder(Vec3(0,0,-.015),Vec3(0,0,.016),.285,.285,20,'wood_props'))
        round_sh.merge(create_ring_torus(Vec3(0,0,0),Vec3(0,0,1),.29,.022,20,6,'armor_metal'))
        round_sh.merge(create_cylinder(Vec3(0,0,.016),Vec3(0,0,.065),.075,.025,12,'armor_metal'))
        gear['Round_Shield']=round_sh
        for name,outline,region in [
            ('Badge_Shield',[(-.22,.28),(.22,.28),(.20,-.08),(0,-.34),(-.20,-.08)],'outfit_primary'),
            ('Rectangle_Shield',[(-.23,.30),(.23,.30),(.20,-.05),(0,-.48),(-.20,-.05)],'outfit_secondary')]:
            shield=CharacterMesh(name)
            shield.merge(prism(outline,.045,'gold_trim'))
            inset=prism([(x*.88,z*.88) for x,z in outline],.049,region)
            shield.merge(inset)
            crest=prism([(0,.18),(.055,.05),(0,-.10),(-.055,.05)],.054,'gold_trim')
            shield.merge(crest)
            gear[name]=shield
        gear['Knight_Cape']=cloak('Knight_Cape',.92,.27,'outfit_primary')
        # Open face: crown and rear neck plates stop above eye level.
        helmet=CharacterMesh('Knight_Helmet')
        for i in range(8):
            theta=2*math.pi*i/8
            p=Vec3(math.cos(theta)*.115,math.sin(theta)*.105,.10)
            helmet.merge(create_cylinder(p,Vec3(p.x*.45,p.y*.45,.235),.026,.018,6,'armor_metal'))
        helmet.merge(create_ring_torus(Vec3(0,0,.10),Vec3(0,0,1),.115,.012,20,6,'gold_trim'))
        gear['Knight_Helmet']=helmet
    elif role=='mage':
        gear['Mage_Cape']=cloak('Mage_Cape',.45,.25,'outfit_secondary')
        # A genuine open crescent silhouette with two tapered tips.
        staff=CharacterMesh('2H_Staff')
        staff.merge(create_cylinder(Vec3(0,0,-.4),Vec3(0,0,1.18),.022,.018,10,'wood_props'))
        for i in range(17):
            a=math.radians(45+270*i/18)
            b=math.radians(45+270*(i+1)/18)
            p=Vec3(math.cos(a)*.14,0,1.30+math.sin(a)*.14)
            q=Vec3(math.cos(b)*.14,0,1.30+math.sin(b)*.14)
            radius=.011+.014*math.sin(math.pi*(i+.5)/18)
            staff.merge(create_cylinder(p,q,radius,radius,6,'gold_trim'))
        staff.merge(create_cylinder(Vec3(0,0,1.24),Vec3(0,0,1.35),.035,.003,6,'rune_emissive'))
        gear['2H_Staff']=staff
        book=CharacterMesh('Spellbook')
        book.merge(create_box(Vec3(-.105,-.035,-.135),Vec3(.105,.035,.135),'cloth_white'))
        for y in (-.045,.045):
            book.merge(create_box(Vec3(-.12,y-.008,-.15),Vec3(.12,y+.008,.15),'leather_dark'))
        book.merge(create_box(Vec3(-.127,-.054,-.15),Vec3(-.105,.054,.15),'gold_trim'))
        for i in range(5):
            book.merge(create_ring_torus(Vec3(-.10+i*.025,0,.18+i*.018),Vec3(0,1,0),.013,.003,8,4,'gold_trim'))
        gear['Spellbook']=book
    return gear
