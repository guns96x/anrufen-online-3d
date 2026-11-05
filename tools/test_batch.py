import zlib, struct, os
from PIL import Image

def test_extract_file(godat_path):
    with open(godat_path, "rb") as f:
        d = f.read()
    
    # Check sy2dr header
    if not d.startswith(b"sy2dr2.6"):
        return f"Not a sy2dr file: {godat_path}"
    
    num_records = struct.unpack("<I", d[15:19])[0]
    print(f"File {os.path.basename(godat_path)}: {num_records} internal records, total size: {len(d)} bytes")

for name in ["map_object_capital_palace.godat", "map_ground_forest.godat", "map_ground_capital_square.godat", "ani_kni_body_lv1.godat"]:
    p = os.path.join(r"C:\Users\pavlo\anrufen_extracted\private\A000BA0E", name)
    if os.path.exists(p):
        test_extract_file(p)
