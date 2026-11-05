import struct,zlib,os,sys,glob
from sprite import decode,palette,blk
B=r'C:/Users/pavlo/anrufen_extracted/private/A000BA0E/'
out='img'; os.makedirs(out,exist_ok=True); ok=0; bad=[]
for f in sorted(glob.glob(B+'*.godat')):
    d=open(f,'rb').read()
    if not d.startswith(b'sy2dr'): continue
    n=struct.unpack('<I',d[15:19])[0]
    if n>5000: continue
    name=os.path.basename(f)[:-6]
    for i in range(n):
        rid,o,_=struct.unpack('<III',d[23+12*i:35+12*i])
        if o+36>len(d): continue
        h=struct.unpack('<9I',d[o:o+36])
        if h[0]!=0 or h[1]!=8 or h[5]!=2 or not(0<h[3]<5000 and 0<h[4]<5000): continue
        try:
            cl,rl=struct.unpack('<II',d[o+36:o+44]); pal=palette(zlib.decompress(d[o+44:o+44+cl]))
            t,p=blk(d,o+44+cl); px,p=blk(d,p)
            decode(t,px,h[3],h[4],pal).save(f'{out}/{name}__{rid}.png'); ok+=1
        except Exception as e: bad.append((name,rid,str(e)[:60]))
print('ok',ok,'bad',len(bad)); print(bad[:10])
