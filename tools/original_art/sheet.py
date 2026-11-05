import sys,glob
from PIL import Image,ImageDraw
pat,out=sys.argv[1],sys.argv[2]; W=int(sys.argv[3]) if len(sys.argv)>3 else 1600
fs=sorted(glob.glob('img/'+pat)); ims=[(f,Image.open(f)) for f in fs]
x=y=rowh=0; pos=[]
for f,im in ims:
    s=min(1.0,(W-10)/im.width); im2=im.resize((max(1,int(im.width*s)),max(1,int(im.height*s))))
    if x+im2.width>W: x=0;y+=rowh+14;rowh=0
    pos.append((x,y,im2,f)); x+=im2.width+6; rowh=max(rowh,im2.height)
S=Image.new('RGB',(W,y+rowh+14),(60,60,70)); D=ImageDraw.Draw(S)
for x,y,im,f in pos: S.paste(im,(x,y+12),im); D.text((x,y),f.split('__')[-1][:-4],fill=(255,255,0))
S.save(out); print(S.size,len(pos))
