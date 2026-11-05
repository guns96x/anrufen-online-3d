import zlib,struct,sys
from PIL import Image
def blk(d,p):
    a,b,cl,rl=struct.unpack('<4I',d[p:p+16]); return zlib.decompress(d[p+16:p+16+cl]), p+16+cl
def decode(table,px,w,h,pal):
    im=Image.new('RGBA',(w,h),(0,0,0,0)); P=im.load(); i=0; y=0
    while i<len(table) and y<h:
        n=struct.unpack('<H',table[i:i+2])[0]; i+=2
        for s in range(n//8):
            off,x0,x1=struct.unpack('<IHH',table[i:i+8]); i+=8
            for k in range(x1-x0):
                c=px[off+k]; 
                if 0<=x0+k<w: P[x0+k,y]=pal[c]
        y+=1
    return im
def palette(raw):
    return [(raw[4*i+2],raw[4*i+1],raw[4*i],255) for i in range(256)]
if __name__=='__main__':
    d=open(sys.argv[1],'rb').read()
    hdr=struct.unpack('<9I',d[59:95]); print(hdr)
    cl,rl=struct.unpack('<II',d[95:103]); pal=palette(zlib.decompress(d[103:103+cl]))
    t,p=blk(d,103+cl); px,p=blk(d,p)
    for order in [(0,1)]:
        im=decode(t,px,hdr[3],hdr[4],pal); im=im.resize((im.width*4,im.height*4),Image.NEAREST); im.save(sys.argv[2])
