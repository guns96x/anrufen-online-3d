import struct,zlib
def recs(path):
    d=open(path,'rb').read(); n=struct.unpack('<I',d[15:19])[0]; p=23; ents=[]
    for i in range(n):
        rid,off,nl=struct.unpack('<III',d[p:p+12]); nm=d[p+12:p+12+nl].decode('gbk','replace'); p+=12+nl; ents.append((rid,off,nm))
    offs=sorted(set(o for _,o,_ in ents))+[len(d)]
    out=[]
    for rid,o,nm in ents:
        e=offs[offs.index(o)+1]; b=d[o:e]
        try:
            a,bb,cl,rl=struct.unpack('<4I',b[:16]); z=zlib.decompress(b[16:16+cl]) if rl else b[16:16+cl]
        except Exception: z=b
        out.append((rid,nm,z))
    return out
