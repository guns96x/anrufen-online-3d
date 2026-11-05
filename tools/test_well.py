import zlib, struct
from PIL import Image

path = r"C:\Users\pavlo\anrufen_extracted\private\A000BA0E\map_object_well.godat"
with open(path, "rb") as f:
    d = f.read()

hdr = zlib.decompress(d[1006:1006+643])
pix = zlib.decompress(d[1665:1665+2694])
pal = zlib.decompress(d[103:103+887])

W, H = 59, 104
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
pixels = img.load()

# Palette: 256 colors
palette = []
for i in range(256):
    r, g, b, a = pal[i*4 : (i+1)*4]
    if (r == 255 and g == 0 and b == 255) or (b == 255 and g == 0 and r == 255):
        palette.append((0, 0, 0, 0))
    else:
        palette.append((r, g, b, 255))

start_y = struct.unpack("<H", hdr[:2])[0]
print(f"Start Y: {start_y}")

current_y = start_y
prev_x2 = 9999

offset = 2
spans = []
while offset + 8 <= len(hdr):
    p_off, x1, x2 = struct.unpack("<IHH", hdr[offset:offset+8])
    spans.append((p_off, x1, x2))
    offset += 8

print(f"Total spans: {len(spans)}")

for p_off, x1, x2 in spans:
    if x1 < prev_x2:
        if prev_x2 != 9999:
            current_y += 1
    
    length = x2 - x1
    for x in range(x1, x2):
        if 0 <= x < W and 0 <= current_y < H:
            p_idx = p_off + (x - x1)
            if p_idx < len(pix):
                color_idx = pix[p_idx]
                pixels[x, current_y] = palette[color_idx]
    prev_x2 = x2

out_path = r"C:\Users\pavlo\anrufen-online-3d\tools\well.png"
img.save(out_path)
print(f"Saved reconstructed well to {out_path}! Final Y: {current_y}")
