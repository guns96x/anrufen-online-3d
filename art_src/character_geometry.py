"""character_geometry.py - Procedural anime character geometry and texture generator.

Generates custom ring-loft anime character meshes, layered tailored clothing,
distinctive sculpted hair clumps, articulated hands, hero gear, NPC props,
flat-albedo PNG texture atlases, and analytical 4-bone skin weights.
Compatible with Blender 4.x / 5.x Python API.
"""

from __future__ import annotations
import math
import struct
import zlib
from typing import Dict, List, Tuple, Optional, Any

try:
    import bpy
except ImportError:
    bpy = None


# ==============================================================================
# 1. 3D MATH & VECTOR UTILITIES
# ==============================================================================

class Vec3:
    __slots__ = ('x', 'y', 'z')

    def __init__(self, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> None:
        self.x = float(x)
        self.y = float(y)
        self.z = float(z)

    def __add__(self, other: Vec3) -> Vec3:
        return Vec3(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other: Vec3) -> Vec3:
        return Vec3(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, scalar: float) -> Vec3:
        return Vec3(self.x * scalar, self.y * scalar, self.z * scalar)

    def __rmul__(self, scalar: float) -> Vec3:
        return Vec3(self.x * scalar, self.y * scalar, self.z * scalar)

    def __truediv__(self, scalar: float) -> Vec3:
        s = 1.0 / scalar if scalar != 0.0 else 0.0
        return Vec3(self.x * s, self.y * s, self.z * s)

    def length(self) -> float:
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    def normalized(self) -> Vec3:
        l = self.length()
        return self / l if l > 1e-7 else Vec3(0, 0, 1)

    def dot(self, other: Vec3) -> float:
        return self.x * other.x + self.y * other.y + self.z * other.z

    def cross(self, other: Vec3) -> Vec3:
        return Vec3(
            self.y * other.z - self.z * other.y,
            self.z * other.x - self.x * other.z,
            self.x * other.y - self.y * other.x
        )

    def to_tuple(self) -> Tuple[float, float, float]:
        return (self.x, self.y, self.z)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def vlerp(a: Vec3, b: Vec3, t: float) -> Vec3:
    return a + (b - a) * t


def bezier_cubic(p0: Vec3, p1: Vec3, p2: Vec3, p3: Vec3, t: float) -> Vec3:
    u = 1.0 - t
    tt = t * t
    uu = u * u
    return (uu * u) * p0 + (3.0 * uu * t) * p1 + (3.0 * u * tt) * p2 + (tt * t) * p3


def rotate_z(v: Vec3, angle_rad: float) -> Vec3:
    c = math.cos(angle_rad)
    s = math.sin(angle_rad)
    return Vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)


def rotate_x(v: Vec3, angle_rad: float) -> Vec3:
    c = math.cos(angle_rad)
    s = math.sin(angle_rad)
    return Vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)


def rotate_y(v: Vec3, angle_rad: float) -> Vec3:
    c = math.cos(angle_rad)
    s = math.sin(angle_rad)
    return Vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)


# ==============================================================================
# 2. RAW MESH CONTAINER (PRESERVES QUADS & CORNER UVS)
# ==============================================================================

class CharacterMesh:
    def __init__(self, name: str = "Mesh") -> None:
        self.name = name
        self.vertices: List[Tuple[float, float, float]] = []
        self.faces: List[List[int]] = []
        self.uvs: List[Tuple[float, float]] = []  # Per-vertex fallback UV
        self.loop_uvs: List[Tuple[float, float]] = []  # Explicit per face-corner UVs
        self.weights: Dict[str, Dict[int, float]] = {}  # bone_name -> {vert_idx: weight}

    def add_vertex(self, pt: Vec3 | Tuple[float, float, float], uv: Tuple[float, float] = (0.5, 0.5)) -> int:
        if isinstance(pt, Vec3):
            self.vertices.append(pt.to_tuple())
        else:
            self.vertices.append((float(pt[0]), float(pt[1]), float(pt[2])))
        self.uvs.append(uv)
        return len(self.vertices) - 1

    def add_triangle(self, v0: int, v1: int, v2: int, uvs: Optional[List[Tuple[float, float]]] = None) -> None:
        self.faces.append([v0, v1, v2])
        if uvs is not None:
            self.loop_uvs.extend(uvs)
        else:
            self.loop_uvs.extend([self.uvs[v0], self.uvs[v1], self.uvs[v2]])

    def add_quad(self, v0: int, v1: int, v2: int, v3: int, uvs: Optional[List[Tuple[float, float]]] = None) -> None:
        # Preserves clean quads for subdivision/smoothing; glTF export triangulates at export
        self.faces.append([v0, v1, v2, v3])
        if uvs is not None:
            self.loop_uvs.extend(uvs)
        else:
            self.loop_uvs.extend([self.uvs[v0], self.uvs[v1], self.uvs[v2], self.uvs[v3]])

    def merge(self, other: CharacterMesh) -> None:
        offset = len(self.vertices)
        self.vertices.extend(other.vertices)
        self.uvs.extend(other.uvs)
        for f in other.faces:
            self.faces.append([idx + offset for idx in f])
        self.loop_uvs.extend(other.loop_uvs)
        for bone, wmap in other.weights.items():
            if bone not in self.weights:
                self.weights[bone] = {}
            for vidx, w in wmap.items():
                self.weights[bone][vidx + offset] = w

    def transform(self, offset: Vec3 = Vec3(0, 0, 0), scale: Vec3 = Vec3(1, 1, 1)) -> None:
        new_verts = []
        for v in self.vertices:
            new_verts.append((v[0] * scale.x + offset.x, v[1] * scale.y + offset.y, v[2] * scale.z + offset.z))
        self.vertices = new_verts

    def triangle_count(self) -> int:
        total = 0
        for f in self.faces:
            total += max(1, len(f) - 2)
        return total


# ==============================================================================
# 3. TEXTURE ATLAS GENERATOR (PURE PYTHON PNG WRITER WITH SCANLINE FLIP)
# ==============================================================================

def write_png_file(filepath: str, width: int, height: int, rgba_bytes: bytearray) -> None:
    """Writes standard RGBA PNG.

    Flips scanline order (height-1 down to 0) so atlas row 0 is V=0 (bottom) and
    row height-1 is V=1 (top), aligning exactly with glTF and Blender standard UVs.
    """
    row_size = width * 4
    raw_scanlines = bytearray()
    for y in range(height - 1, -1, -1):
        raw_scanlines.append(0)  # Filter type 0: None
        start = y * row_size
        raw_scanlines.extend(rgba_bytes[start:start + row_size])

    compressed = zlib.compress(bytes(raw_scanlines), level=6)

    def png_chunk(tag: bytes, data: bytes) -> bytes:
        length = len(data)
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack('>I', length) + tag + data + struct.pack('>I', crc)

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    png_data = b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', ihdr) + png_chunk(b'IDAT', compressed) + png_chunk(b'IEND', b'')

    with open(filepath, 'wb') as f:
        f.write(png_data)


# Atlas Layout Regions (Normalized UV boxes: u0, v0, u1, v1)
# Arranged with clear spacing to avoid palette bleeding
ATLAS_REGIONS = {
    'skin': (0.02, 0.76, 0.24, 0.98),
    'skin_shadow': (0.26, 0.76, 0.34, 0.98),
    'eye_white': (0.36, 0.88, 0.44, 0.98),
    'eye_iris': (0.36, 0.76, 0.44, 0.86),
    'eyebrow_lip': (0.46, 0.76, 0.50, 0.98),
    'hair_base': (0.52, 0.76, 0.74, 0.98),
    'hair_highlight': (0.76, 0.76, 0.86, 0.98),
    'hair_shadow': (0.88, 0.76, 0.98, 0.98),
    'outfit_primary': (0.02, 0.42, 0.34, 0.72),
    'outfit_secondary': (0.36, 0.42, 0.64, 0.72),
    'gold_trim': (0.66, 0.58, 0.80, 0.72),
    'silver_trim': (0.82, 0.58, 0.98, 0.72),
    'armor_metal': (0.66, 0.42, 0.98, 0.56),
    'leather_dark': (0.02, 0.18, 0.24, 0.38),
    'leather_tan': (0.26, 0.18, 0.48, 0.38),
    'cloth_white': (0.50, 0.18, 0.68, 0.38),
    'cloth_accent': (0.70, 0.18, 0.84, 0.38),
    'wood_props': (0.86, 0.18, 0.98, 0.38),
    'rune_emissive': (0.02, 0.02, 0.34, 0.14),
    'prop_details': (0.36, 0.02, 0.98, 0.14),
}


def get_uv_center(region_name: str) -> Tuple[float, float]:
    if region_name == 'secondary':
        region_name = 'outfit_secondary'
    box = ATLAS_REGIONS.get(region_name, (0.4, 0.4, 0.6, 0.6))
    return ((box[0] + box[2]) * 0.5, (box[1] + box[3]) * 0.5)


def get_uv_box(region_name: str, inset_px: float = 4.0, size: float = 1024.0) -> Tuple[float, float, float, float]:
    """Returns normalized UV box inset by at least 4 pixels to prevent boundary bleed."""
    if region_name == 'secondary':
        region_name = 'outfit_secondary'
    box = ATLAS_REGIONS.get(region_name, (0.1, 0.1, 0.9, 0.9))
    pad = inset_px / size
    u0 = box[0] + pad
    v0 = box[1] + pad
    u1 = box[2] - pad
    v1 = box[3] - pad
    return (u0, v0, u1, v1)


def paint_flat_rect(buf: bytearray, w: int, h: int, u0: float, v0: float, u1: float, v1: float,
                    rgba: Tuple[int, int, int, int]) -> None:
    x0 = max(0, min(w - 1, int(u0 * w)))
    x1 = max(0, min(w, int(u1 * w)))
    y0 = max(0, min(h - 1, int(v0 * h)))
    y1 = max(0, min(h, int(v1 * h)))
    if x1 <= x0 or y1 <= y0:
        return
    span_len = x1 - x0
    row_chunk = bytes([rgba[0], rgba[1], rgba[2], rgba[3]]) * span_len
    for y in range(y0, y1):
        idx = (y * w + x0) * 4
        buf[idx:idx + span_len * 4] = row_chunk


def paint_radial_circle(buf: bytearray, w: int, h: int, cx_u: float, cy_v: float, r_u: float,
                        inner_rgba: Tuple[int, int, int, int], outer_rgba: Tuple[int, int, int, int]) -> None:
    cx = int(cx_u * w)
    cy = int(cy_v * h)
    rad = int(r_u * w)
    if rad <= 0:
        return
    rad_sq = rad * rad
    y0 = max(0, cy - rad)
    y1 = min(h, cy + rad)
    x0 = max(0, cx - rad)
    x1 = min(w, cx + rad)
    for y in range(y0, y1):
        dy = y - cy
        dy_sq = dy * dy
        for x in range(x0, x1):
            dx = x - cx
            dist_sq = dx * dx + dy_sq
            if dist_sq <= rad_sq:
                t = math.sqrt(dist_sq) / rad
                r = int(lerp(inner_rgba[0], outer_rgba[0], t))
                g = int(lerp(inner_rgba[1], outer_rgba[1], t))
                b = int(lerp(inner_rgba[2], outer_rgba[2], t))
                a = int(lerp(inner_rgba[3], outer_rgba[3], t))
                idx = (y * w + x) * 4
                buf[idx:idx + 4] = bytes([r, g, b, a])


def paint_seam_line(buf: bytearray, w: int, h: int, x0_u: float, y0_v: float, x1_u: float, y1_v: float,
                    rgba: Tuple[int, int, int, int], thickness: int = 2) -> None:
    x0, y0 = int(x0_u * w), int(y0_v * h)
    x1, y1 = int(x1_u * w), int(y1_v * h)
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        for ty in range(-thickness // 2, (thickness + 1) // 2):
            for tx in range(-thickness // 2, (thickness + 1) // 2):
                px = x0 + tx
                py = y0 + ty
                if 0 <= px < w and 0 <= py < h:
                    idx = (py * w + px) * 4
                    buf[idx:idx + 4] = bytes(rgba)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


def create_character_atlas(filepath: str, spec: Dict[str, Any], width: int = 1024, height: int = 1024) -> str:
    """Renders the hand-painted flat anime texture atlas PNG with painted costume seams and details (no baked AO)."""
    buf = bytearray(width * height * 4)

    # 1. Base palette unpacking
    skin_col = spec.get('palette_skin', (252, 230, 218, 255))
    skin_shd = spec.get('palette_skin_shd', (235, 198, 185, 255))
    hair_base = spec.get('palette_hair', (60, 45, 40, 255))
    hair_high = spec.get('palette_hair_high', (95, 75, 68, 255))
    hair_shd = spec.get('palette_hair_shd', (35, 25, 22, 255))
    eye_col = spec.get('palette_eye', (45, 90, 160, 255))
    primary = spec.get('palette_primary', (40, 60, 95, 255))
    secondary = spec.get('palette_secondary', (180, 165, 140, 255))
    gold_trim = spec.get('palette_gold', (215, 175, 70, 255))
    silver_trim = spec.get('palette_silver', (190, 195, 205, 255))
    metal = spec.get('palette_metal', (110, 118, 130, 255))
    leather_d = spec.get('palette_leather_dark', (55, 38, 28, 255))
    leather_t = spec.get('palette_leather_tan', (120, 85, 55, 255))
    cloth_w = (242, 242, 240, 255)
    accent = spec.get('palette_accent', (140, 35, 45, 255))
    wood = (105, 72, 48, 255)
    rune_col = spec.get('palette_rune', (160, 220, 255, 255))

    # Darker seam tones
    def shade_col(col: Tuple[int, int, int, int], factor: float = 0.75) -> Tuple[int, int, int, int]:
        return (int(col[0] * factor), int(col[1] * factor), int(col[2] * factor), col[3])

    def tint_col(col: Tuple[int, int, int, int], factor: float = 1.25) -> Tuple[int, int, int, int]:
        return (min(255, int(col[0] * factor)), min(255, int(col[1] * factor)), min(255, int(col[2] * factor)), col[3])

    primary_seam = shade_col(primary, 0.75)
    secondary_seam = shade_col(secondary, 0.80)
    leather_seam = shade_col(leather_d, 0.65)
    gold_border = tint_col(gold_trim, 1.2)

    # 2. Fill regions
    for reg, (u0, v0, u1, v1) in ATLAS_REGIONS.items():
        if reg == 'skin':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, skin_col)
            # Soft rosy cheek patch in top quarter
            paint_radial_circle(buf, width, height, (u0 + u1) * 0.5, (v0 + v1) * 0.5, 0.03, (255, 210, 205, 255), skin_col)
        elif reg == 'skin_shadow':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, skin_shd)
        elif reg == 'eye_white':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, (248, 248, 252, 255))
        elif reg == 'eye_iris':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, eye_col)
            # Rich anime iris gradient, pupil, and dual specular highlights
            cx, cy = (u0 + u1) * 0.5, (v0 + v1) * 0.5
            paint_radial_circle(buf, width, height, cx, cy, 0.032, shade_col(eye_col, 0.5), eye_col)
            # Pupil
            paint_radial_circle(buf, width, height, cx, cy, 0.016, (15, 18, 25, 255), (25, 30, 40, 255))
            # Primary bright specular dot
            paint_radial_circle(buf, width, height, cx - 0.012, cy + 0.012, 0.007, (255, 255, 255, 255), (255, 255, 255, 255))
            # Secondary smaller catchlight
            paint_radial_circle(buf, width, height, cx + 0.010, cy - 0.010, 0.004, (240, 245, 255, 255), (240, 245, 255, 255))
        elif reg == 'eyebrow_lip':
            # Upper section: rich dark brown/black for eyebrows and eyeliner
            paint_flat_rect(buf, width, height, u0, (v0 + v1) * 0.5, u1, v1, (30, 25, 22, 255))
            # Lower section: soft natural rose for lips
            paint_flat_rect(buf, width, height, u0, v0, u1, (v0 + v1) * 0.5, (220, 135, 140, 255))
        elif reg == 'hair_base':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, hair_base)
            # Subtle strand seams
            seam_col = shade_col(hair_base, 0.85)
            for i in range(1, 5):
                ux = u0 + (u1 - u0) * (i / 5.0)
                paint_seam_line(buf, width, height, ux, v0, ux, v1, seam_col, 2)
        elif reg == 'hair_highlight':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, hair_high)
        elif reg == 'hair_shadow':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, hair_shd)
        elif reg == 'outfit_primary':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, primary)
            # Painted quilted gambeson / tailored costume seam grid
            for i in range(1, 6):
                uy = v0 + (v1 - v0) * (i / 6.0)
                paint_seam_line(buf, width, height, u0, uy, u1, uy, primary_seam, 2)
            for i in range(1, 4):
                ux = u0 + (u1 - u0) * (i / 4.0)
                paint_seam_line(buf, width, height, ux, v0, ux, v1, primary_seam, 2)
        elif reg == 'outfit_secondary':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, secondary)
            # Secondary panel borders
            for i in range(1, 4):
                uy = v0 + (v1 - v0) * (i / 4.0)
                paint_seam_line(buf, width, height, u0, uy, u1, uy, secondary_seam, 2)
        elif reg == 'gold_trim':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, gold_trim)
            # High-luster gold edge
            paint_flat_rect(buf, width, height, u0, (v0 + v1) * 0.45, u1, (v0 + v1) * 0.55, gold_border)
        elif reg == 'silver_trim':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, silver_trim)
            paint_flat_rect(buf, width, height, u0, (v0 + v1) * 0.45, u1, (v0 + v1) * 0.55, (230, 235, 245, 255))
        elif reg == 'armor_metal':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, metal)
            # Metal bevel seam lines
            m_seam = shade_col(metal, 0.70)
            paint_seam_line(buf, width, height, u0, (v0 + v1) * 0.5, u1, (v0 + v1) * 0.5, m_seam, 2)
        elif reg == 'leather_dark':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, leather_d)
            paint_seam_line(buf, width, height, u0, (v0 + v1) * 0.5, u1, (v0 + v1) * 0.5, leather_seam, 2)
        elif reg == 'leather_tan':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, leather_t)
            paint_seam_line(buf, width, height, u0, (v0 + v1) * 0.5, u1, (v0 + v1) * 0.5, shade_col(leather_t, 0.75), 2)
        elif reg == 'cloth_white':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, cloth_w)
        elif reg == 'cloth_accent':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, accent)
        elif reg == 'wood_props':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, wood)
            # Wood grain stripes
            w_grain = shade_col(wood, 0.82)
            for i in range(1, 5):
                uy = v0 + (v1 - v0) * (i / 5.0)
                paint_seam_line(buf, width, height, u0, uy, u1, uy, w_grain, 2)
        elif reg == 'rune_emissive':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, rune_col)
            # Bright cyan/white rune heart
            paint_radial_circle(buf, width, height, (u0 + u1) * 0.5, (v0 + v1) * 0.5, 0.04, (255, 255, 255, 255), rune_col)
        elif reg == 'prop_details':
            paint_flat_rect(buf, width, height, u0, v0, u1, v1, (165, 145, 120, 255))

    write_png_file(filepath, width, height, buf)
    return filepath


# ==============================================================================
# 4. PROCEDURAL MODELING PRIMITIVES (RING-LOFTS, CLUMPS, BOXES, CYLINDERS)
# ==============================================================================

def create_ring_loft(ring_points: List[List[Vec3]], uv_region: str = 'outfit_primary',
                     cap_bottom: bool = True, cap_top: bool = True) -> CharacterMesh:
    """Connects adjacent rings of 3D points into a smooth quad mesh with outwards-facing normals."""
    mesh = CharacterMesh()
    if not ring_points or len(ring_points) < 2:
        return mesh

    u0, v0, u1, v1 = get_uv_box(uv_region)
    num_rings = len(ring_points)
    seg_count = len(ring_points[0])

    # Add all ring vertices
    vert_indices: List[List[int]] = []
    for r_idx, ring in enumerate(ring_points):
        r_indices = []
        v_frac = r_idx / max(1, num_rings - 1)
        v_coord = v0 + (v1 - v0) * v_frac
        for s_idx, pt in enumerate(ring):
            u_frac = s_idx / seg_count
            u_coord = u0 + (u1 - u0) * u_frac
            v_i = mesh.add_vertex(pt, (u_coord, v_coord))
            r_indices.append(v_i)
        vert_indices.append(r_indices)

    # Bridge rings with outward-facing quads
    for r in range(num_rings - 1):
        for s in range(seg_count):
            s_next = (s + 1) % seg_count
            v00 = vert_indices[r][s]
            v01 = vert_indices[r][s_next]
            v10 = vert_indices[r + 1][s]
            v11 = vert_indices[r + 1][s_next]
            # CCW winding viewed from exterior: bottom-s -> bottom-next -> top-next -> top-s
            mesh.add_quad(v00, v01, v11, v10)

    # Caps
    if cap_bottom and len(ring_points[0]) >= 3:
        c = Vec3(0, 0, 0)
        for pt in ring_points[0]:
            c = c + pt
        c = c / len(ring_points[0])
        c_idx = mesh.add_vertex(c, ((u0 + u1) * 0.5, v0))
        for s in range(seg_count):
            s_next = (s + 1) % seg_count
            mesh.add_triangle(c_idx, vert_indices[0][s_next], vert_indices[0][s])

    if cap_top and len(ring_points[-1]) >= 3:
        c = Vec3(0, 0, 0)
        for pt in ring_points[-1]:
            c = c + pt
        c = c / len(ring_points[-1])
        c_idx = mesh.add_vertex(c, ((u0 + u1) * 0.5, v1))
        top_r = vert_indices[-1]
        for s in range(seg_count):
            s_next = (s + 1) % seg_count
            mesh.add_triangle(c_idx, top_r[s], top_r[s_next])

    return mesh


def create_tapered_hair_clump(spine: List[Vec3], radii: List[float], segments: int = 8,
                              uv_region: str = 'hair_base') -> CharacterMesh:
    """Builds an anime tapered lock of hair flowing along a 3D curved spine with blade profile."""
    ring_points: List[List[Vec3]] = []
    num_pts = len(spine)
    for i, pt in enumerate(spine):
        if i == 0:
            tangent = (spine[1] - spine[0]).normalized()
        elif i == num_pts - 1:
            tangent = (spine[-1] - spine[-2]).normalized()
        else:
            tangent = (spine[i + 1] - spine[i - 1]).normalized()

        up = Vec3(0, 0, 1) if abs(tangent.z) < 0.9 else Vec3(1, 0, 0)
        normal = tangent.cross(up).normalized()
        binormal = tangent.cross(normal).normalized()

        rad = radii[min(i, len(radii) - 1)]
        ring = []
        for s in range(segments):
            angle = 2.0 * math.pi * s / segments
            rx = math.cos(angle) * rad
            ry = math.sin(angle) * rad * 0.7  # Anime blade profile
            v = pt + normal * rx + binormal * ry
            ring.append(v)
        ring_points.append(ring)

    return create_ring_loft(ring_points, uv_region=uv_region, cap_bottom=True, cap_top=True)


def create_box(min_pt: Vec3, max_pt: Vec3, uv_region: str = 'outfit_primary') -> CharacterMesh:
    mesh = CharacterMesh()
    u0, v0, u1, v1 = get_uv_box(uv_region)
    pts = [
        Vec3(min_pt.x, min_pt.y, min_pt.z),  # 0
        Vec3(max_pt.x, min_pt.y, min_pt.z),  # 1
        Vec3(max_pt.x, max_pt.y, min_pt.z),  # 2
        Vec3(min_pt.x, max_pt.y, min_pt.z),  # 3
        Vec3(min_pt.x, min_pt.y, max_pt.z),  # 4
        Vec3(max_pt.x, min_pt.y, max_pt.z),  # 5
        Vec3(max_pt.x, max_pt.y, max_pt.z),  # 6
        Vec3(min_pt.x, max_pt.y, max_pt.z),  # 7
    ]
    indices = [mesh.add_vertex(p, ((u0 + u1) * 0.5, (v0 + v1) * 0.5)) for p in pts]
    mesh.add_quad(indices[0], indices[3], indices[2], indices[1])  # bottom (-Z)
    mesh.add_quad(indices[4], indices[5], indices[6], indices[7])  # top (+Z)
    mesh.add_quad(indices[0], indices[1], indices[5], indices[4])  # front (-Y)
    mesh.add_quad(indices[2], indices[3], indices[7], indices[6])  # back (+Y)
    mesh.add_quad(indices[3], indices[0], indices[4], indices[7])  # left (-X)
    mesh.add_quad(indices[1], indices[2], indices[6], indices[5])  # right (+X)
    return mesh


def create_cylinder(p0: Vec3, p1: Vec3, r0: float, r1: float, segments: int = 12,
                    uv_region: str = 'armor_metal') -> CharacterMesh:
    axis = (p1 - p0).normalized()
    up = Vec3(0, 0, 1) if abs(axis.z) < 0.9 else Vec3(1, 0, 0)
    norm = axis.cross(up).normalized()
    binorm = axis.cross(norm).normalized()

    ring0 = []
    ring1 = []
    for s in range(segments):
        ang = 2.0 * math.pi * s / segments
        ca = math.cos(ang)
        sa = math.sin(ang)
        ring0.append(p0 + (norm * ca + binorm * sa) * r0)
        ring1.append(p1 + (norm * ca + binorm * sa) * r1)

    return create_ring_loft([ring0, ring1], uv_region=uv_region, cap_bottom=True, cap_top=True)


def create_ring_torus(center: Vec3, normal: Vec3, major_r: float, minor_r: float,
                      major_segs: int = 12, minor_segs: int = 6, uv_region: str = 'gold_trim') -> CharacterMesh:
    """Builds a wire ring / spectacle frame / hoop in 3D."""
    mesh = CharacterMesh()
    up = Vec3(0, 0, 1) if abs(normal.z) < 0.9 else Vec3(1, 0, 0)
    u_dir = normal.cross(up).normalized()
    v_dir = normal.cross(u_dir).normalized()

    u0, v0, u1, v1 = get_uv_box(uv_region)
    vert_rings: List[List[int]] = []

    for i in range(major_segs):
        phi = 2.0 * math.pi * i / major_segs
        ring_center = center + (u_dir * math.cos(phi) + v_dir * math.sin(phi)) * major_r
        rad_dir = (ring_center - center).normalized()
        ring_verts = []
        for j in range(minor_segs):
            theta = 2.0 * math.pi * j / minor_segs
            pt = ring_center + (rad_dir * math.cos(theta) + normal * math.sin(theta)) * minor_r
            v_idx = mesh.add_vertex(pt, ((u0 + u1) * 0.5, (v0 + v1) * 0.5))
            ring_verts.append(v_idx)
        vert_rings.append(ring_verts)

    for i in range(major_segs):
        i_next = (i + 1) % major_segs
        for j in range(minor_segs):
            j_next = (j + 1) % minor_segs
            mesh.add_quad(
                vert_rings[i][j],
                vert_rings[i_next][j],
                vert_rings[i_next][j_next],
                vert_rings[i][j_next]
            )
    return mesh


# ==============================================================================
# 5. ANIME HEAD, EYES, SCALP CAP & HAIR GENERATOR
# ==============================================================================

def build_anime_head_mesh(spec: Dict[str, Any]) -> CharacterMesh:
    """Builds an authentic contoured anime head with visible almond 3D eyes, brows, nose, lips,

    fitted scalp cap, and stylized hair masses conforming to 7-head proportions.
    """
    head_mesh = CharacterMesh(f"{spec['name']}_Head")
    height = spec.get('height', 1.80)
    sex = spec.get('sex', 'm')
    race = spec.get('race', 'human')
    role = spec.get('role', 'warrior')
    is_heavy = spec.get('heavy', False)

    # All geometry built at canonical 1.80m, then scaled uniformly by height / 1.80
    canonical_h = 1.80
    head_top = 1.80
    neck_base = 1.48
    chin_z = 1.54
    mouth_z = 1.59
    nose_z = 1.63
    eye_z = 1.655
    brow_z = 1.685
    forehead_z = 1.72
    cranium_z = 1.77

    # Head width according to spec: female ~.21 (.105 half), male ~.23 (.115 half)
    if is_heavy:
        half_w = 0.135
        face_depth = 0.125
        chin_w = 0.045
    elif sex == 'f':
        half_w = 0.105
        face_depth = 0.102
        chin_w = 0.028
    else:
        half_w = 0.115
        face_depth = 0.108
        chin_w = 0.034

    # 1. High-Density Facial Contours (14 rings x 24 segments)
    num_segs = 24
    head_rings: List[List[Vec3]] = []

    # Ring 0: Neck seam (Z = 1.48)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * 0.060,
             math.sin(2*math.pi*s/num_segs) * 0.060,
             neck_base)
        for s in range(num_segs)
    ])

    # Ring 1: Submandibular / lower jaw (Z = 1.51)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (chin_w * 1.5),
             math.sin(2*math.pi*s/num_segs) * 0.055 - 0.020,
             1.51)
        for s in range(num_segs)
    ])

    # Ring 2: Chin apex (Z = 1.54) - rounded, tapered forward at -Y
    chin_ring = []
    for s in range(num_segs):
        ang = 2 * math.pi * s / num_segs
        ca = math.cos(ang)
        sa = math.sin(ang)
        x = ca * chin_w
        # Forward protrusion at -Y
        y = sa * 0.060 - (0.040 if sa < -0.3 else 0.010)
        chin_ring.append(Vec3(x, y, chin_z))
    head_rings.append(chin_ring)

    # Ring 3: Lower lip & jawline (Z = 1.57)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.65),
             math.sin(2*math.pi*s/num_segs) * 0.075 - 0.025,
             1.57)
        for s in range(num_segs)
    ])

    # Ring 4: Mouth cleft & philtrum (Z = 1.595)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.75),
             math.sin(2*math.pi*s/num_segs) * 0.082 - (0.026 if math.sin(2*math.pi*s/num_segs) < -0.5 else 0.015),
             mouth_z)
        for s in range(num_segs)
    ])

    # Ring 5: Nose base (Z = 1.62)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.85),
             math.sin(2*math.pi*s/num_segs) * 0.088 - 0.015,
             1.62)
        for s in range(num_segs)
    ])

    # Ring 6: Small anime nose apex protruding forward at -Y (Z = 1.635)
    nose_ring = []
    for s in range(num_segs):
        ang = 2 * math.pi * s / num_segs
        ca = math.cos(ang)
        sa = math.sin(ang)
        x = ca * (half_w * 0.90)
        # Center front vertex pulls forward for authentic small anime nose
        is_front = (sa < -0.85 and abs(ca) < 0.25)
        y = sa * 0.092 - (0.026 if is_front else 0.012)
        nose_ring.append(Vec3(x, y, nose_z))
    head_rings.append(nose_ring)

    # Ring 7: Eye socket lower border & cheekbones (Z = 1.645)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * half_w,
             math.sin(2*math.pi*s/num_segs) * face_depth - 0.008,
             1.645)
        for s in range(num_segs)
    ])

    # Ring 8: Mid eye socket recess (Z = 1.66) - front Y is ~ -0.102
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * half_w,
             math.sin(2*math.pi*s/num_segs) * face_depth - 0.005,
             eye_z)
        for s in range(num_segs)
    ])

    # Ring 9: Brow ridge (Z = 1.685)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.98),
             math.sin(2*math.pi*s/num_segs) * (face_depth * 0.98) - 0.002,
             brow_z)
        for s in range(num_segs)
    ])

    # Ring 10: Forehead / temples (Z = 1.72)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.94),
             math.sin(2*math.pi*s/num_segs) * (face_depth * 0.96) + 0.005,
             forehead_z)
        for s in range(num_segs)
    ])

    # Ring 11: Mid cranium (Z = 1.755)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.86),
             math.sin(2*math.pi*s/num_segs) * (face_depth * 0.90) + 0.015,
             1.755)
        for s in range(num_segs)
    ])

    # Ring 12: Upper cranium dome (Z = 1.785)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.65),
             math.sin(2*math.pi*s/num_segs) * (face_depth * 0.70) + 0.020,
             cranium_z)
        for s in range(num_segs)
    ])

    # Ring 13: Crown apex (Z = 1.80)
    head_rings.append([
        Vec3(math.cos(2*math.pi*s/num_segs) * (half_w * 0.30),
             math.sin(2*math.pi*s/num_segs) * (face_depth * 0.35) + 0.025,
             head_top)
        for s in range(num_segs)
    ])

    base_head = create_ring_loft(head_rings, uv_region='skin', cap_bottom=True, cap_top=True)
    head_mesh.merge(base_head)

    # 2. Visible 3D Almond Eyes & Eyeliner at Front (y ~ -0.118 to -0.120)
    # The front facial skin surface at eye_z is at y ~ -0.102.
    # Placing eye whites at y = -0.114, eyeliner at -0.116, iris at -0.118 ensures they sit cleanly in front!
    eye_x_offset = half_w * 0.38
    eye_white_y = -0.113
    iris_y = -0.117
    liner_y = -0.115

    for side in (-1.0, 1.0):
        cx = side * eye_x_offset
        w = 0.025  # readable anime eye half width
        h = 0.017  # eye half height

        # A. Almond Eye White (6-vertex smooth almond with CCW outward normals facing -Y)
        p_c = Vec3(cx, eye_white_y, eye_z)
        p_in = Vec3(cx - side * w, eye_white_y + 0.001, eye_z)
        p_out = Vec3(cx + side * w, eye_white_y + 0.002, eye_z + 0.002)
        p_top = Vec3(cx, eye_white_y, eye_z + h)
        p_bot = Vec3(cx, eye_white_y, eye_z - h * 0.85)

        u_w0, v_w0, u_w1, v_w1 = get_uv_box('eye_white')
        uv_w_mid = ((u_w0 + u_w1) * 0.5, (v_w0 + v_w1) * 0.5)

        v_c = head_mesh.add_vertex(p_c, uv_w_mid)
        v_in = head_mesh.add_vertex(p_in, (u_w0, uv_w_mid[1]))
        v_out = head_mesh.add_vertex(p_out, (u_w1, uv_w_mid[1]))
        v_top = head_mesh.add_vertex(p_top, (uv_w_mid[0], v_w1))
        v_bot = head_mesh.add_vertex(p_bot, (uv_w_mid[0], v_w0))

        # Winding pointing outward (-Y)
        if side > 0:
            head_mesh.add_triangle(v_c, v_top, v_out)
            head_mesh.add_triangle(v_c, v_out, v_bot)
            head_mesh.add_triangle(v_c, v_bot, v_in)
            head_mesh.add_triangle(v_c, v_in, v_top)
        else:
            head_mesh.add_triangle(v_c, v_out, v_top)
            head_mesh.add_triangle(v_c, v_top, v_in)
            head_mesh.add_triangle(v_c, v_in, v_bot)
            head_mesh.add_triangle(v_c, v_bot, v_out)

        # B. Iris & Pupil Inset Disc (Sitting slightly forward at -Y)
        u_i0, v_i0, u_i1, v_i1 = get_uv_box('eye_iris')
        r_iris = 0.010
        iris_pts = []
        for s in range(8):
            ang = 2 * math.pi * s / 8
            ix = cx + math.cos(ang) * (r_iris * 0.9)
            iz = eye_z + math.sin(ang) * r_iris
            iris_pts.append(Vec3(ix, iris_y, iz))

        v_ic = head_mesh.add_vertex(Vec3(cx, iris_y, eye_z), ((u_i0 + u_i1) * 0.5, (v_i0 + v_i1) * 0.5))
        v_iris_rim = []
        for s, pt in enumerate(iris_pts):
            u_frac = 0.5 + 0.5 * math.cos(2 * math.pi * s / 8)
            v_frac = 0.5 + 0.5 * math.sin(2 * math.pi * s / 8)
            v_iris_rim.append(head_mesh.add_vertex(pt, (u_i0 + (u_i1 - u_i0) * u_frac, v_i0 + (v_i1 - v_i0) * v_frac)))

        for s in range(8):
            s_next = (s + 1) % 8
            if side > 0:
                head_mesh.add_triangle(v_ic, v_iris_rim[s], v_iris_rim[s_next])
            else:
                head_mesh.add_triangle(v_ic, v_iris_rim[s_next], v_iris_rim[s])

        # C. Specular Highlight Dot (tiny bright quad)
        u_h0, v_h0, u_h1, v_h1 = get_uv_box('cloth_white')
        hx = cx - side * 0.004
        hz = eye_z + 0.005
        spec_quad = [
            head_mesh.add_vertex(Vec3(hx - 0.002, iris_y - 0.001, hz - 0.002), (u_h0, v_h0)),
            head_mesh.add_vertex(Vec3(hx + 0.002, iris_y - 0.001, hz - 0.002), (u_h1, v_h0)),
            head_mesh.add_vertex(Vec3(hx + 0.002, iris_y - 0.001, hz + 0.002), (u_h1, v_h1)),
            head_mesh.add_vertex(Vec3(hx - 0.002, iris_y - 0.001, hz + 0.002), (u_h0, v_h1)),
        ]
        if side > 0:
            head_mesh.add_quad(spec_quad[0], spec_quad[1], spec_quad[2], spec_quad[3])
        else:
            head_mesh.add_quad(spec_quad[0], spec_quad[3], spec_quad[2], spec_quad[1])

        # D. Black Upper Eyeliner & Eyelash Wing
        u_l0, v_l0, u_l1, v_l1 = get_uv_box('eyebrow_lip')
        liner_top_z = eye_z + h + 0.004
        liner_pts = [
            head_mesh.add_vertex(p_in + Vec3(0, -0.002, 0.002), (u_l0, v_l1)),
            head_mesh.add_vertex(Vec3(cx, liner_y, liner_top_z), ((u_l0 + u_l1) * 0.5, v_l1)),
            head_mesh.add_vertex(p_out + Vec3(side * 0.006, -0.002, 0.006), (u_l1, v_l1)),
            head_mesh.add_vertex(p_out, (u_l1, (v_l0 + v_l1) * 0.5)),
            head_mesh.add_vertex(p_top, ((u_l0 + u_l1) * 0.5, (v_l0 + v_l1) * 0.5)),
            head_mesh.add_vertex(p_in, (u_l0, (v_l0 + v_l1) * 0.5)),
        ]
        if side > 0:
            head_mesh.add_quad(liner_pts[0], liner_pts[1], liner_pts[4], liner_pts[5])
            head_mesh.add_quad(liner_pts[1], liner_pts[2], liner_pts[3], liner_pts[4])
        else:
            head_mesh.add_quad(liner_pts[0], liner_pts[5], liner_pts[4], liner_pts[1])
            head_mesh.add_quad(liner_pts[1], liner_pts[4], liner_pts[3], liner_pts[2])

        # E. Distinct Arched Eyebrow
        bz = brow_z
        by = -0.114
        b_in = head_mesh.add_vertex(Vec3(cx - side * 0.016, by, bz - 0.003), (u_l0, v_l1))
        b_mid = head_mesh.add_vertex(Vec3(cx, by, bz + 0.004), ((u_l0 + u_l1) * 0.5, v_l1))
        b_out = head_mesh.add_vertex(Vec3(cx + side * 0.024, by, bz + 0.001), (u_l1, v_l1))
        b_top = head_mesh.add_vertex(Vec3(cx + side * 0.004, by, bz + 0.008), ((u_l0 + u_l1) * 0.5, v_l1))
        if side > 0:
            head_mesh.add_quad(b_in, b_out, b_top, b_mid)
        else:
            head_mesh.add_quad(b_in, b_mid, b_top, b_out)

    # 3. Soft Rose Anime Lips (Visible colored quad facing outward)
    u_lip0, v_lip0, u_lip1, v_lip1 = get_uv_box('eyebrow_lip')
    lip_uv = ((u_lip0 + u_lip1) * 0.5, v_lip0 + (v_lip1 - v_lip0) * 0.25)
    lip_y = -0.108
    lip_v0 = head_mesh.add_vertex(Vec3(-0.012, lip_y, mouth_z - 0.004), lip_uv)
    lip_v1 = head_mesh.add_vertex(Vec3(0.012, lip_y, mouth_z - 0.004), lip_uv)
    lip_v2 = head_mesh.add_vertex(Vec3(0.012, lip_y, mouth_z + 0.004), lip_uv)
    lip_v3 = head_mesh.add_vertex(Vec3(-0.012, lip_y, mouth_z + 0.004), lip_uv)
    head_mesh.add_quad(lip_v0, lip_v1, lip_v2, lip_v3)

    # 4. Ears (Human contoured shell or pointed Elf leaf ear)
    for side in (-1.0, 1.0):
        ear_z = eye_z - 0.01
        ear_base = Vec3(side * (half_w * 0.98), 0.005, ear_z)
        if race == 'elf':
            # Pointed upward/backward sweeping leaf ear
            u_s0, v_s0, u_s1, v_s1 = get_uv_box('skin')
            mid_uv = ((u_s0 + u_s1) * 0.5, (v_s0 + v_s1) * 0.5)
            e_base_t = ear_base + Vec3(0, -0.01, 0.025)
            e_base_b = ear_base + Vec3(0, 0.01, -0.025)
            e_mid = ear_base + Vec3(side * 0.065, 0.025, 0.040)
            e_tip = ear_base + Vec3(side * 0.130, 0.060, 0.065)

            v_ebt = head_mesh.add_vertex(e_base_t, mid_uv)
            v_ebb = head_mesh.add_vertex(e_base_b, mid_uv)
            v_em = head_mesh.add_vertex(e_mid, mid_uv)
            v_etip = head_mesh.add_vertex(e_tip, mid_uv)

            if side > 0:
                head_mesh.add_quad(v_ebt, v_em, v_etip, v_ebb)
            else:
                head_mesh.add_quad(v_ebt, v_ebb, v_etip, v_em)
        else:
            # Human rounded ear
            ear = create_cylinder(ear_base + Vec3(0, 0, -0.02), ear_base + Vec3(0, 0, 0.025), 0.018, 0.022, segments=8, uv_region='skin')
            head_mesh.merge(ear)

    # 5. FITTED SCALP CAP SHELL (mesh UV hair_base)
    # Covers crown, cranium, nape, and sides, leaving the face completely exposed!
    cap_rings: List[List[Vec3]] = []
    # Cap extends from nape/hairline (Z ~ 1.62 at back) to crown apex (Z = 1.805)
    for r_z, r_rad, r_yoff, angle_start, angle_end in [
        (1.60, half_w * 1.03, 0.020, math.radians(-35), math.radians(215)),   # Nape / sideburns
        (1.66, half_w * 1.035, 0.015, math.radians(-45), math.radians(225)),  # Above ears / temples
        (1.72, half_w * 1.04, 0.010, math.radians(-65), math.radians(245)),   # Forehead hairline
        (1.76, half_w * 0.95, 0.015, 0.0, 2.0 * math.pi),                      # Cranium
        (1.802, half_w * 0.50, 0.025, 0.0, 2.0 * math.pi),                     # Crown
    ]:
        c_ring = []
        c_segs = 16
        for s in range(c_segs):
            frac = s / (c_segs - 1) if angle_end != 2 * math.pi else s / c_segs
            ang = angle_start + (angle_end - angle_start) * frac
            cx = math.cos(ang) * r_rad
            cy = math.sin(ang) * r_rad + r_yoff
            c_ring.append(Vec3(cx, cy, r_z))
        cap_rings.append(c_ring)

    # One angular parameter avoids twisted panels between open and full arcs.
    cap_rings=[]
    for t,radius in ((0,1.055),(.45,1.02),(.8,.83),(.96,.51),(1,.32)):
        ring=[]
        for index in range(24):
            angle=2*math.pi*index/24
            front=max(0,-math.sin(angle))
            hairline=1.60+.12*front
            z=lerp(hairline,1.825,t)
            ring.append(Vec3(math.cos(angle)*half_w*radius,
                             math.sin(angle)*face_depth*radius+.012,z))
        cap_rings.append(ring)
    scalp_cap = create_ring_loft(cap_rings, uv_region='hair_base', cap_bottom=False, cap_top=True)
    head_mesh.merge(scalp_cap)

    # 6. STYLED HAIR MASSES & TAPERED BANGS ACCORDING TO SPEC
    hair_style = spec.get('hair_style', 'short_swept')
    hair_root = Vec3(0, 0.01, cranium_z)

    # A. Universal layered face-framing bangs across hairline (sweeping down forehead)
    bang_angles = (-40, -22, -8, 8, 22, 40)
    for ang_deg in bang_angles:
        rad = math.radians(ang_deg)
        x_dir = math.sin(rad)
        spine = [
            hair_root + Vec3(x_dir * 0.075, -0.065, 0.015),
            hair_root + Vec3(x_dir * 0.095, -0.095, -0.045),
            hair_root + Vec3(x_dir * 0.105, -0.112, -0.090)
        ]
        bang = create_tapered_hair_clump(spine, [0.018, 0.015, 0.003], segments=6, uv_region='hair_base')
        head_mesh.merge(bang)

    # B. Specific hair style geometry
    if hair_style == 'ponytail':
        # Side wisps + gathered high ponytail at rear
        for side in (-1.0, 1.0):
            side_spine = [
                hair_root + Vec3(side * 0.08, -0.02, 0.01),
                hair_root + Vec3(side * 0.11, 0.01, -0.08),
                hair_root + Vec3(side * 0.10, -0.02, -0.18)
            ]
            head_mesh.merge(create_tapered_hair_clump(side_spine, [0.018, 0.014, 0.003], segments=6))
        # Hair tie ring
        tie_center = Vec3(0, 0.085, 1.76)
        tie = create_ring_torus(tie_center, Vec3(0, 0.6, 0.8).normalized(), 0.035, 0.008, major_segs=10, minor_segs=6, uv_region='gold_trim')
        head_mesh.merge(tie)
        # Voluminous ponytail plume curving back and down
        pony_spine = [
            tie_center,
            tie_center + Vec3(0, 0.08, 0.05),
            tie_center + Vec3(0, 0.14, -0.08),
            tie_center + Vec3(0, 0.18, -0.25),
            tie_center + Vec3(0, 0.19, -0.42)
        ]
        pony = create_tapered_hair_clump(pony_spine, [0.032, 0.048, 0.042, 0.025, 0.005], segments=8)
        head_mesh.merge(pony)

    elif hair_style in ('braid', 'long_braid'):
        # 3D Braided plait with authentic alternating overlapping lobes!
        braid_len = 0.55 if hair_style == 'long_braid' else 0.38
        num_lobes = 10 if hair_style == 'long_braid' else 7
        braid_top = Vec3(0, 0.10, 1.64)
        lobe_step = braid_len / num_lobes

        for i in range(num_lobes):
            side = 1.0 if (i % 2 == 0) else -1.0
            z_curr = braid_top.z - i * lobe_step
            taper = 1.0 - (i / num_lobes) * 0.65
            lobe_spine = [
                Vec3(side * 0.010, 0.105, z_curr + lobe_step * 0.4),
                Vec3(side * 0.035, 0.115, z_curr),
                Vec3(-side * 0.008, 0.108, z_curr - lobe_step * 0.5)
            ]
            lobe = create_tapered_hair_clump(lobe_spine, [0.025 * taper, 0.022 * taper, 0.006 * taper], segments=6)
            head_mesh.merge(lobe)
        # Braid end ribbon tie
        ribbon_pt = Vec3(0, 0.105, braid_top.z - braid_len)
        ribbon = create_cylinder(ribbon_pt + Vec3(0, 0, 0.015), ribbon_pt + Vec3(0, 0, -0.015), 0.016, 0.014, segments=8, uv_region='cloth_accent')
        head_mesh.merge(ribbon)

    elif hair_style in ('wavy', 'side_swept'):
        # Long cascading locks flowing down over shoulders
        for side in (-1.0, 1.0):
            for ang in (15, 35, 55):
                rad = math.radians(ang)
                cascade_spine = [
                    hair_root + Vec3(side * (math.sin(rad) * 0.09), -0.02, 0.02),
                    hair_root + Vec3(side * 0.13, -0.01, -0.10),
                    hair_root + Vec3(side * 0.14, -0.05, -0.22),
                    hair_root + Vec3(side * 0.12, -0.08, -0.36)
                ]
                head_mesh.merge(create_tapered_hair_clump(cascade_spine, [0.022, 0.024, 0.018, 0.004], segments=6))

    elif hair_style == 'bun':
        # Widow Anna: low loose chignon at nape with wisps and hairpin
        for side in (-1.0, 1.0):
            wisp_spine = [
                hair_root + Vec3(side * 0.07, -0.05, 0.01),
                hair_root + Vec3(side * 0.10, -0.04, -0.12),
                hair_root + Vec3(side * 0.09, -0.02, -0.20)
            ]
            head_mesh.merge(create_tapered_hair_clump(wisp_spine, [0.014, 0.011, 0.002], segments=6))
        # Sculpted nape bun
        bun_center = Vec3(0, 0.115, 1.58)
        bun_rings: List[List[Vec3]] = []
        for r_y, r_rad in [(-0.02, 0.035), (0.01, 0.052), (0.04, 0.045), (0.06, 0.020)]:
            ring = []
            for s in range(12):
                a = 2 * math.pi * s / 12
                ring.append(bun_center + Vec3(math.cos(a) * r_rad, r_y, math.sin(a) * r_rad))
            bun_rings.append(ring)
        head_mesh.merge(create_ring_loft(bun_rings, uv_region='hair_base', cap_bottom=True, cap_top=True))
        # Silver hairpin
        pin = create_cylinder(bun_center + Vec3(-0.06, 0.02, 0.02), bun_center + Vec3(0.06, 0.02, -0.02), 0.003, 0.003, segments=6, uv_region='silver_trim')
        head_mesh.merge(pin)

    elif hair_style == 'mayor_hair':
        # Mayor: receding hairline scalp cap already generated; two braided plait beards hanging from chin
        for side in (-1.0, 1.0):
            beard_base = Vec3(side * 0.025, -0.055, chin_z - 0.01)
            b_spine = [
                beard_base,
                beard_base + Vec3(side * 0.012, -0.020, -0.08),
                beard_base + Vec3(side * 0.008, -0.010, -0.16),
                beard_base + Vec3(0, 0, -0.22)
            ]
            head_mesh.merge(create_tapered_hair_clump(b_spine, [0.022, 0.019, 0.012, 0.003], segments=6, uv_region='hair_base'))
        # Spectacles: wire frame rings (open ring tori, NOT opaque disks!)
        for side in (-1.0, 1.0):
            lens_center = Vec3(side * eye_x_offset, eye_white_y - 0.004, eye_z)
            spectacle_ring = create_ring_torus(lens_center, Vec3(0, 1, 0), major_r=0.018, minor_r=0.0018,
                                               major_segs=12, minor_segs=6, uv_region='gold_trim')
            head_mesh.merge(spectacle_ring)
        # Spectacle bridge
        bridge = create_cylinder(Vec3(-eye_x_offset + 0.018, eye_white_y - 0.004, eye_z),
                                 Vec3(eye_x_offset - 0.018, eye_white_y - 0.004, eye_z),
                                 0.0015, 0.0015, segments=6, uv_region='gold_trim')
        head_mesh.merge(bridge)

    elif hair_style == 'gourmand_hair':
        # Gourmand: pleated chef's cap + thick curled handlebar moustache
        cap_base_z = cranium_z
        cap_rings = [
            # Cap band
            [Vec3(math.cos(2*math.pi*s/16) * (half_w * 1.04), math.sin(2*math.pi*s/16) * (half_w * 1.04), cap_base_z) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * (half_w * 1.05), math.sin(2*math.pi*s/16) * (half_w * 1.05), cap_base_z + 0.04) for s in range(16)],
            # Puffed toque
            [Vec3(math.cos(2*math.pi*s/16) * (half_w * 1.35), math.sin(2*math.pi*s/16) * (half_w * 1.35), cap_base_z + 0.12) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * (half_w * 1.28), math.sin(2*math.pi*s/16) * (half_w * 1.28), cap_base_z + 0.20) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * (half_w * 0.70), math.sin(2*math.pi*s/16) * (half_w * 0.70), cap_base_z + 0.22) for s in range(16)]
        ]
        head_mesh.merge(create_ring_loft(cap_rings, uv_region='cloth_white', cap_bottom=False, cap_top=True))
        # Curled 3D Handlebar Moustache
        for side in (-1.0, 1.0):
            m_spine = [
                Vec3(side * 0.005, -0.108, mouth_z + 0.008),
                Vec3(side * 0.038, -0.114, mouth_z + 0.005),
                Vec3(side * 0.068, -0.105, mouth_z + 0.015),
                Vec3(side * 0.082, -0.092, mouth_z + 0.038)
            ]
            head_mesh.merge(create_tapered_hair_clump(m_spine, [0.016, 0.014, 0.009, 0.002], segments=6, uv_region='hair_base'))

    elif hair_style == 'smuggler_hair':
        # Smuggler: tousled windswept locks + 3D eyepatch
        for ang in (-50, -25, 0, 25, 50):
            rad = math.radians(ang)
            lock_spine = [
                hair_root + Vec3(math.sin(rad) * 0.09, -0.05, 0.02),
                hair_root + Vec3(math.sin(rad) * 0.12, -0.07, -0.06),
                hair_root + Vec3(math.sin(rad) * 0.13, -0.08, -0.15)
            ]
            head_mesh.merge(create_tapered_hair_clump(lock_spine, [0.020, 0.016, 0.003], segments=6))
        # Eyepatch over left eye (X > 0)
        patch_c = Vec3(eye_x_offset, eye_white_y - 0.003, eye_z)
        patch = create_cylinder(patch_c + Vec3(0, -0.003, 0), patch_c + Vec3(0, 0.003, 0), 0.024, 0.024, segments=12, uv_region='leather_dark')
        head_mesh.merge(patch)
        # Eyepatch strap encircling head
        strap = create_ring_torus(Vec3(0, 0.01, eye_z), Vec3(0, 0, 1), major_r=half_w * 1.01, minor_r=0.003,
                                  major_segs=16, minor_segs=4, uv_region='leather_dark')
        head_mesh.merge(strap)

    elif hair_style == 'ranger_hair':
        # Ranger: side braid over shoulder + jay feather
        for side in (-1.0, 1.0):
            side_spine = [
                hair_root + Vec3(side * 0.075, -0.04, 0.02),
                hair_root + Vec3(side * 0.105, -0.03, -0.09)
            ]
            head_mesh.merge(create_tapered_hair_clump(side_spine, [0.018, 0.014, 0.003], segments=6))
        # Vibrant red side braid draped over right shoulder
        braid_spine = [
            Vec3(half_w * 0.90, -0.02, 1.62),
            Vec3(half_w * 1.10, -0.05, 1.48),
            Vec3(half_w * 0.95, -0.09, 1.34),
            Vec3(half_w * 0.85, -0.12, 1.20)
        ]
        head_mesh.merge(create_tapered_hair_clump(braid_spine, [0.026, 0.024, 0.018, 0.004], segments=8))
        # Jay feather tucked in hair band
        feather = create_box(Vec3(-half_w * 0.95, -0.02, 1.68), Vec3(-half_w * 0.93, 0.02, 1.84), uv_region='rune_emissive')
        head_mesh.merge(feather)

    else:
        # Default short swept hair masses across crown and back
        for ang in (-60, -35, -12, 12, 35, 60):
            rad = math.radians(ang)
            lock_spine = [
                hair_root + Vec3(math.sin(rad) * 0.09, -0.02, 0.02),
                hair_root + Vec3(math.sin(rad) * 0.12, 0.01, -0.08),
                hair_root + Vec3(math.sin(rad) * 0.13, 0.04, -0.18)
            ]
            head_mesh.merge(create_tapered_hair_clump(lock_spine, [0.022, 0.018, 0.003], segments=6))

    # Scale uniformly to exact specified height
    scale_factor = height / canonical_h
    head_mesh.transform(scale=Vec3(scale_factor, scale_factor, scale_factor))
    return head_mesh


# ==============================================================================
# 6. ANIME BODY & LAYERED CLOTHING GENERATOR (CONNECTED JOINTS & LANDMARKS)
# ==============================================================================

def build_anime_body_meshes(spec: Dict[str, Any]) -> Dict[str, CharacterMesh]:
    """Builds the 5 distinct body meshes: Body, ArmLeft, ArmRight, LegLeft, LegRight.

    Proportions are aligned strictly with canonical 1.80m rig positions:
    Hips at Z=0.98, Knees at Z=0.52, Ankles at Z=0.10, Shoulder joint at X=0.16/Z=1.45,
    Elbow at X=0.42/Z=1.22, Wrist at X=0.66/Z=1.00, Hand center at X=0.71/Z=0.96.
    Limb meshes are continuous and watertight at joints (no gaps or isolated chunks).
    """
    name = spec['name']
    height = spec.get('height', 1.80)
    sex = spec.get('sex', 'm')
    race = spec.get('race', 'human')
    role = spec.get('role', 'warrior')
    is_heavy = spec.get('heavy', False)

    canonical_h = 1.80
    scale_factor = height / canonical_h

    # Landmark coordinates at canonical 1.80m
    neck_z = 1.48
    upper_chest_z = 1.35
    chest_z = 1.20
    spine_z = 1.08
    hips_z = 0.98
    crotch_z = 0.92
    knee_z = 0.52
    ankle_z = 0.10

    # Shoulder width conforms to prompt: torso shoulders extend to 0.20-0.23
    shoulder_w = 0.225 if (sex == 'm' and not is_heavy) else (0.205 if sex == 'f' else 0.245)
    chest_w = 0.185 if (sex == 'm' and not is_heavy) else (0.160 if sex == 'f' else 0.230)
    waist_w = 0.145 if (sex == 'm' and not is_heavy) else (0.125 if sex == 'f' else 0.220)
    hip_w = 0.165 if (sex == 'm' and not is_heavy) else (0.170 if sex == 'f' else 0.225)

    chest_d = 0.125 if not is_heavy else 0.190
    belly_d = 0.120 if not is_heavy else 0.240

    # --------------------------------------------------------------------------
    # A. TORSO & LAYERED CLOTHING (_Body)
    # --------------------------------------------------------------------------
    body_mesh = CharacterMesh(f"{name}_Body")

    # Torso ring loft (16 segments for smooth contours)
    t_segs = 16
    torso_rings = [
        # Ring 0: Neck seam join
        [Vec3(math.cos(2*math.pi*s/t_segs) * 0.065, math.sin(2*math.pi*s/t_segs) * 0.065, neck_z) for s in range(t_segs)],
        # Ring 1: Clavicle / shoulder slope
        [Vec3(math.cos(2*math.pi*s/t_segs) * (shoulder_w * 0.75), math.sin(2*math.pi*s/t_segs) * (chest_d * 0.85), 1.45) for s in range(t_segs)],
        # Ring 2: Shoulder span (extending to 0.20-0.23)
        [Vec3(math.cos(2*math.pi*s/t_segs) * shoulder_w, math.sin(2*math.pi*s/t_segs) * chest_d, 1.40) for s in range(t_segs)],
        # Ring 3: Upper chest
        [Vec3(math.cos(2*math.pi*s/t_segs) * (chest_w * 1.05), math.sin(2*math.pi*s/t_segs) * (chest_d * 1.05) - (0.015 if sex == 'f' else 0.0), upper_chest_z) for s in range(t_segs)],
        # Ring 4: Mid chest / bust
        [Vec3(math.cos(2*math.pi*s/t_segs) * chest_w, math.sin(2*math.pi*s/t_segs) * chest_d - (0.020 if sex == 'f' else 0.0), 1.28) for s in range(t_segs)],
        # Ring 5: Lower chest / ribcage
        [Vec3(math.cos(2*math.pi*s/t_segs) * (chest_w * 0.95), math.sin(2*math.pi*s/t_segs) * (chest_d * 0.95), chest_z) for s in range(t_segs)],
        # Ring 6: Mid spine / upper waist
        [Vec3(math.cos(2*math.pi*s/t_segs) * (waist_w * 1.02), math.sin(2*math.pi*s/t_segs) * (belly_d * 0.98), 1.14) for s in range(t_segs)],
        # Ring 7: Belt line / waist (Z = 1.08)
        [Vec3(math.cos(2*math.pi*s/t_segs) * waist_w, math.sin(2*math.pi*s/t_segs) * belly_d, spine_z) for s in range(t_segs)],
        # Ring 8: Iliac crest / upper pelvis
        [Vec3(math.cos(2*math.pi*s/t_segs) * (hip_w * 0.98), math.sin(2*math.pi*s/t_segs) * (chest_d * 1.02), 1.02) for s in range(t_segs)],
        # Ring 9: Pelvis / hips (canonical Hips at Z = 0.98)
        [Vec3(math.cos(2*math.pi*s/t_segs) * hip_w, math.sin(2*math.pi*s/t_segs) * (chest_d * 1.05), hips_z) for s in range(t_segs)],
        # Ring 10: Crotch base
        [Vec3(math.cos(2*math.pi*s/t_segs) * (hip_w * 0.90), math.sin(2*math.pi*s/t_segs) * (chest_d * 0.95), crotch_z) for s in range(t_segs)],
    ]
    torso = create_ring_loft(torso_rings, uv_region='outfit_primary', cap_bottom=True, cap_top=False)
    body_mesh.merge(torso)

    # Leather Belt & Buckle
    belt = create_cylinder(Vec3(0, 0, spine_z - 0.035), Vec3(0, 0, spine_z + 0.035), waist_w * 1.04, waist_w * 1.04, segments=16, uv_region='leather_dark')
    body_mesh.merge(belt)
    buckle = create_box(Vec3(-0.035, -belly_d - 0.016, spine_z - 0.040), Vec3(0.035, -belly_d + 0.005, spine_z + 0.040), uv_region='gold_trim')
    body_mesh.merge(buckle)

    # TAILORED CLOTHING LAYERS PER ROLE & RACE
    if role == 'warrior':
        if race == 'elf':
            # Elf warrior: leaf-plate cuirass, silver/lilac pauldrons, tasset skirt with leaf faulds
            cuirass = create_cylinder(Vec3(0, 0, 1.15), Vec3(0, 0, 1.42), chest_w * 1.05, shoulder_w * 0.95, segments=16, uv_region='silver_trim')
            body_mesh.merge(cuirass)
            # Overlapping leaf plates
            for side in (-1.0, 1.0):
                pauldron = create_cylinder(Vec3(side * (shoulder_w * 0.85), 0, 1.43), Vec3(side * (shoulder_w * 1.08), 0.01, 1.35),
                                           0.08, 0.09, segments=10, uv_region='secondary')
                body_mesh.merge(pauldron)
            # Tasset fauld skirt over hips
            tasset_rings = [
                [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.05), math.sin(2*math.pi*s/16) * (chest_d * 1.08), hips_z + 0.04) for s in range(16)],
                [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.18), math.sin(2*math.pi*s/16) * (chest_d * 1.20), crotch_z - 0.05) for s in range(16)],
                [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.28), math.sin(2*math.pi*s/16) * (chest_d * 1.28), crotch_z - 0.18) for s in range(16)]
            ]
            body_mesh.merge(create_ring_loft(tasset_rings, uv_region='outfit_secondary', cap_bottom=True, cap_top=False))
        else:
            # Human warrior: quilted gambeson seams with gold hem rim at hips
            gold_hem = create_cylinder(Vec3(0, 0, crotch_z - 0.02), Vec3(0, 0, crotch_z + 0.03), hip_w * 1.06, hip_w * 1.04, segments=16, uv_region='gold_trim')
            body_mesh.merge(gold_hem)
            # Gambeson shoulder rim
            for side in (-1.0, 1.0):
                pad = create_cylinder(Vec3(side * (shoulder_w * 0.88), 0, 1.42), Vec3(side * (shoulder_w * 1.05), 0, 1.36), 0.07, 0.075, segments=10, uv_region='outfit_secondary')
                body_mesh.merge(pad)

    elif role == 'mage':
        # High standing collar framing neck
        collar_rings = [
            [Vec3(math.cos(2*math.pi*s/16) * 0.070, math.sin(2*math.pi*s/16) * 0.070, neck_z - 0.02) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * 0.088, math.sin(2*math.pi*s/16) * 0.088, neck_z + 0.06) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * 0.105, math.sin(2*math.pi*s/16) * 0.105, neck_z + 0.12) for s in range(16)]
        ]
        body_mesh.merge(create_ring_loft(collar_rings, uv_region='outfit_secondary', cap_bottom=False, cap_top=False))

        if race == 'elf':
            # Elf mage: asymmetric mantle exposed over one shoulder WITH modest undershirt/covered torso
            mantle_rings = [
                [Vec3(math.cos(2*math.pi*s/12) * (shoulder_w * 0.85) + 0.04, math.sin(2*math.pi*s/12) * (chest_d * 1.10), 1.46) for s in range(12)],
                [Vec3(math.cos(2*math.pi*s/12) * (shoulder_w * 0.95) + 0.06, math.sin(2*math.pi*s/12) * (chest_d * 1.18), 1.30) for s in range(12)],
                [Vec3(math.cos(2*math.pi*s/12) * (shoulder_w * 1.05) + 0.08, math.sin(2*math.pi*s/12) * (chest_d * 1.25), 1.15) for s in range(12)]
            ]
            body_mesh.merge(create_ring_loft(mantle_rings, uv_region='outfit_primary', cap_bottom=True, cap_top=False))
            brooch = create_box(Vec3(0.04, -chest_d - 0.02, 1.40), Vec3(0.08, -chest_d + 0.01, 1.44), uv_region='gold_trim')
            body_mesh.merge(brooch)
        else:
            # Front-split robe (open at front center, NOT a closed cylinder!)
            # Left panel and right panel draping down to shins
            robe_rings = [
                [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.06), math.sin(2*math.pi*s/16) * (chest_d * 1.10), hips_z) for s in range(16)],
                [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.25), math.sin(2*math.pi*s/16) * (chest_d * 1.25), knee_z + 0.15) for s in range(16)],
                [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.40), math.sin(2*math.pi*s/16) * (chest_d * 1.40), ankle_z + 0.10) for s in range(16)]
            ]
            body_mesh.merge(create_ring_loft(robe_rings, uv_region='outfit_primary', cap_bottom=True, cap_top=False))

    elif role == 'mayor':
        # Long open olive vest over linen rolled shirt + town emblem
        vest_rings = [
            [Vec3(math.cos(2*math.pi*s/16) * (chest_w * 1.08), math.sin(2*math.pi*s/16) * (chest_d * 1.10), upper_chest_z) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * (waist_w * 1.08), math.sin(2*math.pi*s/16) * (belly_d * 1.10), spine_z) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.18), math.sin(2*math.pi*s/16) * (chest_d * 1.20), knee_z + 0.08) for s in range(16)]
        ]
        body_mesh.merge(create_ring_loft(vest_rings, uv_region='outfit_primary', cap_bottom=True, cap_top=False))
        # Town emblem on chest: oak-over-gate plaque
        emblem = create_box(Vec3(-0.045, -chest_d - 0.015, 1.26), Vec3(0.045, -chest_d + 0.005, 1.34), uv_region='gold_trim')
        body_mesh.merge(emblem)
        # Brass key ring hanging from belt
        key_ring = create_ring_torus(Vec3(0.12, -belly_d - 0.01, spine_z - 0.06), Vec3(0, 1, 0), 0.025, 0.003, uv_region='gold_trim')
        body_mesh.merge(key_ring)

    elif role == 'captain':
        # Brigandine riveted plates over chest
        brigandine = create_cylinder(Vec3(0, 0, 1.12), Vec3(0, 0, 1.42), chest_w * 1.06, shoulder_w * 0.98, segments=16, uv_region='secondary')
        body_mesh.merge(brigandine)
        # Asymmetric heavy left pauldron
        l_pauldron = create_cylinder(Vec3(shoulder_w * 0.85, 0, 1.46), Vec3(shoulder_w * 1.15, 0.01, 1.36), 0.085, 0.095, segments=10, uv_region='secondary')
        body_mesh.merge(l_pauldron)
        # Tattered red cape draped over left back
        cape_pts = [
            Vec3(0.12, 0.08, 1.44),
            Vec3(0.15, 0.12, 1.20),
            Vec3(0.16, 0.14, 0.95),
            Vec3(0.14, 0.15, 0.68)
        ]
        body_mesh.merge(create_tapered_hair_clump(cape_pts, [0.08, 0.14, 0.18, 0.22], segments=6, uv_region='outfit_primary'))

    elif role == 'widow':
        # Closed violet mourning dress + draped shawl + silver flower pendant
        shawl = create_cylinder(Vec3(0, 0, 1.22), Vec3(0, 0, neck_z + 0.02), shoulder_w * 1.10, shoulder_w * 0.65, segments=16, uv_region='cloth_accent')
        body_mesh.merge(shawl)
        # Long skirt down to ankles
        skirt_rings = [
            [Vec3(math.cos(2*math.pi*s/16) * hip_w, math.sin(2*math.pi*s/16) * chest_d, hips_z) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.35), math.sin(2*math.pi*s/16) * (chest_d * 1.35), knee_z) for s in range(16)],
            [Vec3(math.cos(2*math.pi*s/16) * (hip_w * 1.55), math.sin(2*math.pi*s/16) * (chest_d * 1.55), ankle_z + 0.03) for s in range(16)]
        ]
        body_mesh.merge(create_ring_loft(skirt_rings, uv_region='outfit_primary', cap_bottom=True, cap_top=False))
        # Silver flower pendant
        pendant = create_box(Vec3(-0.025, -chest_d - 0.012, 1.30), Vec3(0.025, -chest_d + 0.005, 1.35), uv_region='silver_trim')
        body_mesh.merge(pendant)

    elif role == 'gourmand':
        # Bruno: huge rounded belly + apron with stained pocket + sausage string
        apron = create_box(Vec3(-chest_w * 0.72, -belly_d - 0.016, crotch_z - 0.15),
                           Vec3(chest_w * 0.72, -belly_d + 0.005, upper_chest_z - 0.02), uv_region='cloth_white')
        body_mesh.merge(apron)
        # Sausage string hanging from belt
        sausage_spine = [
            Vec3(-0.10, -belly_d - 0.01, spine_z - 0.04),
            Vec3(-0.08, -belly_d - 0.02, spine_z - 0.14),
            Vec3(-0.04, -belly_d - 0.015, spine_z - 0.22)
        ]
        body_mesh.merge(create_tapered_hair_clump(sausage_spine, [0.018, 0.018, 0.016], segments=6, uv_region='secondary'))

    elif role == 'smuggler':
        # Utility straps & coat pockets
        strap = create_cylinder(Vec3(-shoulder_w * 0.6, -chest_d, 1.40), Vec3(hip_w * 0.6, -belly_d, spine_z - 0.05), 0.025, 0.025, segments=8, uv_region='leather_dark')
        body_mesh.merge(strap)
        # Hip utility pouch
        pouch = create_box(Vec3(hip_w * 0.85, -belly_d * 0.5, spine_z - 0.12), Vec3(hip_w * 1.15, belly_d * 0.2, spine_z + 0.02), uv_region='leather_tan')
        body_mesh.merge(pouch)

    elif role == 'ranger':
        # Asymmetric emerald tunic + leather underbust corset
        corset = create_cylinder(Vec3(0, 0, spine_z - 0.04), Vec3(0, 0, chest_z + 0.06), waist_w * 1.05, chest_w * 1.02, segments=16, uv_region='secondary')
        body_mesh.merge(corset)
        # Short ranger capelet / hood draped back
        hood = create_cylinder(Vec3(0, 0.02, 1.30), Vec3(0, 0, 1.46), shoulder_w * 0.90, shoulder_w * 0.60, segments=12, uv_region='outfit_primary')
        body_mesh.merge(hood)

    # --------------------------------------------------------------------------
    # B. ARMS & HANDS (_ArmLeft, _ArmRight) - WATERTIGHT CONTINUOUS MESH
    # --------------------------------------------------------------------------
    # Canonical rig joints at 1.80m:
    # Shoulder joint: (0.16, 0.0, 1.45)
    # Elbow joint:    (0.42, 0.02, 1.22)
    # Wrist joint:    (0.66, 0.04, 1.00)
    # Hand center:    (0.71, 0.04, 0.96)
    # Hand tip:       (0.76, 0.04, 0.92)
    arm_l = CharacterMesh(f"{name}_ArmLeft")
    arm_r = CharacterMesh(f"{name}_ArmRight")

    arm_segs = 12
    arm_spec = [(1.0, arm_l), (-1.0, arm_r)]

    for side, a_mesh in arm_spec:
        # Arm centerline spline points from shoulder -> elbow -> wrist -> hand
        sh_pt = Vec3(side * 0.18, 0.00, 1.45)  # Overlaps torso shoulder cleanly
        el_pt = Vec3(side * 0.42, 0.02, 1.22)  # Canonical elbow joint
        wr_pt = Vec3(side * 0.66, 0.04, 1.00)  # Canonical wrist joint
        hn_pt = Vec3(side * 0.71, 0.04, 0.96)  # Hand palm center
        tip_pt = Vec3(side * 0.76, 0.04, 0.92) # Finger tips

        # Continuous arm rings (UpperArm -> Elbow -> Forearm -> Wrist -> Palm -> Fingers)
        arm_rings: List[List[Vec3]] = []

        # 1. Shoulder join
        r_sh = 0.058
        arm_rings.append([sh_pt + Vec3(0, math.cos(2*math.pi*s/arm_segs) * r_sh, math.sin(2*math.pi*s/arm_segs) * r_sh) for s in range(arm_segs)])

        # 2. Mid Upper Arm
        mid_u = vlerp(sh_pt, el_pt, 0.50)
        r_mu = 0.052
        arm_rings.append([mid_u + Vec3(0, math.cos(2*math.pi*s/arm_segs) * r_mu, math.sin(2*math.pi*s/arm_segs) * r_mu) for s in range(arm_segs)])

        # 3. Continuous Elbow loop (Z = 1.22)
        r_el = 0.044
        arm_rings.append([el_pt + Vec3(0, math.cos(2*math.pi*s/arm_segs) * r_el, math.sin(2*math.pi*s/arm_segs) * r_el) for s in range(arm_segs)])

        # 4. Mid Forearm / Bracer (tapered)
        mid_f = vlerp(el_pt, wr_pt, 0.50)
        r_mf = 0.038
        arm_rings.append([mid_f + Vec3(0, math.cos(2*math.pi*s/arm_segs) * r_mf, math.sin(2*math.pi*s/arm_segs) * r_mf) for s in range(arm_segs)])

        # 5. Wrist ring (Z = 1.00) - connects DIRECTLY with no gap!
        r_wr = 0.030
        arm_rings.append([wr_pt + Vec3(0, math.cos(2*math.pi*s/arm_segs) * r_wr, math.sin(2*math.pi*s/arm_segs) * r_wr) for s in range(arm_segs)])

        # 6. Hand Metacarpal Palm (starts AT wrist, continuous transition)
        r_palm_w = 0.034
        r_palm_d = 0.018
        arm_rings.append([hn_pt + Vec3(side * math.cos(2*math.pi*s/arm_segs) * r_palm_w,
                                      math.sin(2*math.pi*s/arm_segs) * r_palm_d,
                                      -math.cos(2*math.pi*s/arm_segs) * 0.015) for s in range(arm_segs)])

        # 7. Articulated anime fingers grip (closed rounded tip)
        r_tip_w = 0.024
        r_tip_d = 0.014
        arm_rings.append([tip_pt + Vec3(side * math.cos(2*math.pi*s/arm_segs) * r_tip_w,
                                       math.sin(2*math.pi*s/arm_segs) * r_tip_d,
                                       -math.cos(2*math.pi*s/arm_segs) * 0.010) for s in range(arm_segs)])

        # Skin tone for hand, costume for sleeve
        # Consistent section frames keep the palm from twisting into a spike.
        centers=[sh_pt,mid_u,el_pt,mid_f,wr_pt,hn_pt,tip_pt]
        widths=[r_sh,r_mu,r_el,r_mf,r_wr,r_palm_w,r_tip_w]
        depths=[r_sh,r_mu,r_el,r_mf,r_wr,r_palm_d,r_tip_d]
        arm_rings=[]
        for index,center in enumerate(centers):
            tangent=(centers[min(index+1,len(centers)-1)]-centers[max(0,index-1)]).normalized()
            transverse=tangent.cross(Vec3(0,1,0)).normalized()
            ring=[center+Vec3(0,1,0)*(math.cos(2*math.pi*j/arm_segs)*depths[index])
                  +transverse*(math.sin(2*math.pi*j/arm_segs)*widths[index])
                  for j in range(arm_segs)]
            arm_rings.append(ring)
        sleeve_reg = 'outfit_primary' if role != 'ranger' else 'secondary'
        arm_mesh = create_ring_loft(arm_rings, uv_region=sleeve_reg, cap_bottom=True, cap_top=True)
        skin_uv=get_uv_center('skin')
        loop_index=0
        for face in arm_mesh.faces:
            if min(face)>=4*arm_segs and max(face)<7*arm_segs:
                arm_mesh.loop_uvs[loop_index:loop_index+len(face)]=[skin_uv]*len(face)
            loop_index+=len(face)
        a_mesh.merge(arm_mesh)

        # Opposed anime thumb branching from base of palm
        thumb_base = hn_pt + Vec3(side * -0.010, -0.015, 0.005)
        thumb_tip = hn_pt + Vec3(side * 0.015, -0.032, -0.020)
        thumb = create_cylinder(thumb_base, thumb_tip, 0.012, 0.008, segments=6, uv_region='skin')
        a_mesh.merge(thumb)

        # Bracer cuff / trim rim on forearm
        bracer_reg = 'leather_dark' if role in ('warrior', 'captain', 'ranger') else 'gold_trim'
        bracer_rim = create_cylinder(mid_f + Vec3(side * -0.04, -0.01, 0.03), mid_f + Vec3(side * 0.04, 0.01, -0.03),
                                     0.043, 0.036, segments=12, uv_region=bracer_reg)
        a_mesh.merge(bracer_rim)

    # --------------------------------------------------------------------------
    # C. LEGS & FEET (_LegLeft, _LegRight) - CONTINUOUS AT KNEES & ANKLES
    # --------------------------------------------------------------------------
    # Canonical rig joints at 1.80m:
    # Hip joint:    (+-0.12, 0.00, 0.95)
    # Knee joint:   (+-0.12, -0.01, 0.52)
    # Ankle joint:  (+-0.12, 0.00, 0.10)
    # Foot heel:    (+-0.12, 0.05, 0.04)
    # Foot sole:    (+-0.12, -0.16, 0.00)
    leg_l = CharacterMesh(f"{name}_LegLeft")
    leg_r = CharacterMesh(f"{name}_LegRight")

    leg_segs = 14
    leg_spec = [(1.0, leg_l), (-1.0, leg_r)]
    leg_x = 0.12

    for side, l_mesh in leg_spec:
        hip_pt = Vec3(side * leg_x, 0.00, 0.95)
        knee_pt = Vec3(side * leg_x, -0.01, knee_z)
        ankle_pt = Vec3(side * leg_x, 0.00, ankle_z)

        # Continuous leg rings (Thigh -> Knee -> Shin/Calf -> Ankle)
        leg_rings: List[List[Vec3]] = []

        # 1. Hip socket
        r_thigh_top = 0.076
        leg_rings.append([hip_pt + Vec3(math.cos(2*math.pi*s/leg_segs) * r_thigh_top,
                                       math.sin(2*math.pi*s/leg_segs) * (r_thigh_top * 1.05),
                                       0.0) for s in range(leg_segs)])

        # 2. Mid Thigh
        mid_thigh_z = (0.95 + knee_z) * 0.5
        r_mth = 0.068
        leg_rings.append([Vec3(side * leg_x + math.cos(2*math.pi*s/leg_segs) * r_mth,
                              math.sin(2*math.pi*s/leg_segs) * (r_mth * 1.02),
                              mid_thigh_z) for s in range(leg_segs)])

        # 3. Continuous Knee loop (Z = 0.52) - slight forward patella curve
        r_kn = 0.052
        leg_rings.append([Vec3(side * leg_x + math.cos(2*math.pi*s/leg_segs) * r_kn,
                              math.sin(2*math.pi*s/leg_segs) * r_kn - (0.012 if math.sin(2*math.pi*s/leg_segs) < -0.4 else 0.0),
                              knee_z) for s in range(leg_segs)])

        # 4. Calf (fuller at upper shin)
        calf_z = (knee_z + ankle_z) * 0.60
        r_calf = 0.054
        leg_rings.append([Vec3(side * leg_x + math.cos(2*math.pi*s/leg_segs) * r_calf,
                              math.sin(2*math.pi*s/leg_segs) * r_calf + (0.008 if math.sin(2*math.pi*s/leg_segs) > 0.3 else 0.0),
                              calf_z) for s in range(leg_segs)])

        # 5. Lower Shin (tapered)
        l_shin_z = (knee_z + ankle_z) * 0.25
        r_lshin = 0.044
        leg_rings.append([Vec3(side * leg_x + math.cos(2*math.pi*s/leg_segs) * r_lshin,
                              math.sin(2*math.pi*s/leg_segs) * r_lshin,
                              l_shin_z) for s in range(leg_segs)])

        # 6. Continuous Ankle ring (Z = 0.10) - connects directly into boot!
        r_ank = 0.038
        leg_rings.append([Vec3(side * leg_x + math.cos(2*math.pi*s/leg_segs) * r_ank,
                              math.sin(2*math.pi*s/leg_segs) * r_ank,
                              ankle_z) for s in range(leg_segs)])

        trouser_reg = 'outfit_secondary' if role != 'mage' else 'outfit_primary'
        leg_mesh = create_ring_loft(leg_rings, uv_region=trouser_reg, cap_bottom=False, cap_top=True)
        boot_height=.78 if sex=='f' and role in ('warrior','ranger') else .39
        boot_uv=get_uv_center('leather_dark' if role!='gourmand' else 'wood_props')
        loop_index=0
        for face in leg_mesh.faces:
            if sum(leg_mesh.vertices[i][2] for i in face)/len(face)<boot_height:
                leg_mesh.loop_uvs[loop_index:loop_index+len(face)]=[boot_uv]*len(face)
            loop_index+=len(face)
        l_mesh.merge(leg_mesh)

        # 7. Contoured Boot with distinct Heel, Arch, Instep, and Sole
        boot_reg = 'leather_dark' if role != 'gourmand' else 'wood_props'
        boot_rings = [
            # Boot cuff (overlaps ankle seamlessly)
            [Vec3(side * leg_x + math.cos(2*math.pi*s/12) * 0.045, math.sin(2*math.pi*s/12) * 0.045, ankle_z + 0.04) for s in range(12)],
            # Ankle throat
            [Vec3(side * leg_x + math.cos(2*math.pi*s/12) * 0.042, math.sin(2*math.pi*s/12) * 0.042 - 0.015, ankle_z) for s in range(12)],
            # Instep / heel flare
            [Vec3(side * leg_x + math.cos(2*math.pi*s/12) * 0.044, math.sin(2*math.pi*s/12) * 0.075 - 0.045, 0.04) for s in range(12)],
            # Sole base
            [Vec3(side * leg_x + math.cos(2*math.pi*s/12) * 0.046, math.sin(2*math.pi*s/12) * 0.095 - 0.060, 0.00) for s in range(12)]
        ]
        boot_loft = create_ring_loft(boot_rings, uv_region=boot_reg, cap_bottom=True, cap_top=False)
        l_mesh.merge(boot_loft)

        # Sturdy sole rim
        sole = create_box(Vec3(side * leg_x - 0.048, -0.170, 0.00), Vec3(side * leg_x + 0.048, 0.055, 0.018), uv_region='leather_dark')
        l_mesh.merge(sole)

    # Scale ALL 5 meshes uniformly by (height / 1.80)
    for m in (body_mesh, arm_l, arm_r, leg_l, leg_r):
        m.transform(scale=Vec3(scale_factor, scale_factor, scale_factor))

    return {
        'Body': body_mesh,
        'ArmLeft': arm_l,
        'ArmRight': arm_r,
        'LegLeft': leg_l,
        'LegRight': leg_r
    }


# ==============================================================================
# 7. HERO GEAR & NPC PROPS GENERATOR (STRICTLY LOCAL OBJECT GEOMETRY)
# ==============================================================================

def build_hero_gear_meshes(class_type: str) -> Dict[str, CharacterMesh]:
    """Builds separate hero gear meshes matching exact specification names.

    All gear is created in LOCAL object coordinates centered at its origin/handgrip,
    allowing clean parenting and positioning by Codex animation/build systems.
    """
    gear: Dict[str, CharacterMesh] = {}

    if class_type == 'warrior':
        # 1. 1H_Sword (Arming sword, handgrip centered at 0,0,0)
        sword_1h = CharacterMesh('1H_Sword')
        pommel = create_cylinder(Vec3(0, 0, -0.14), Vec3(0, 0, -0.10), 0.025, 0.025, segments=8, uv_region='gold_trim')
        grip = create_cylinder(Vec3(0, 0, -0.10), Vec3(0, 0, 0.03), 0.018, 0.016, segments=8, uv_region='leather_dark')
        guard = create_box(Vec3(-0.12, -0.020, 0.03), Vec3(0.12, 0.020, 0.055), uv_region='gold_trim')
        blade = create_cylinder(Vec3(0, 0, 0.055), Vec3(0, 0, 0.85), 0.035, 0.008, segments=6, uv_region='armor_metal')
        sword_1h.merge(pommel)
        sword_1h.merge(grip)
        sword_1h.merge(guard)
        sword_1h.merge(blade)
        gear['1H_Sword'] = sword_1h

        # 2. 2H_Sword (Greatsword, handgrip centered at 0,0,0)
        sword_2h = CharacterMesh('2H_Sword')
        p2 = create_cylinder(Vec3(0, 0, -0.30), Vec3(0, 0, -0.24), 0.035, 0.035, segments=8, uv_region='armor_metal')
        g2 = create_cylinder(Vec3(0, 0, -0.24), Vec3(0, 0, 0.05), 0.022, 0.020, segments=8, uv_region='leather_dark')
        guard2 = create_box(Vec3(-0.18, -0.025, 0.05), Vec3(0.18, 0.025, 0.085), uv_region='gold_trim')
        blade2 = create_cylinder(Vec3(0, 0, 0.085), Vec3(0, 0, 1.40), 0.055, 0.012, segments=6, uv_region='armor_metal')
        sword_2h.merge(p2)
        sword_2h.merge(g2)
        sword_2h.merge(guard2)
        sword_2h.merge(blade2)
        gear['2H_Sword'] = sword_2h

        # 3. Round_Shield (Grip at origin)
        round_sh = CharacterMesh('Round_Shield')
        rim = create_cylinder(Vec3(0, 0, -0.02), Vec3(0, 0, 0.02), 0.32, 0.32, segments=16, uv_region='armor_metal')
        wood_face = create_cylinder(Vec3(0, 0, -0.015), Vec3(0, 0, 0.015), 0.28, 0.28, segments=16, uv_region='wood_props')
        boss = create_cylinder(Vec3(0, 0, 0.015), Vec3(0, 0, 0.06), 0.08, 0.03, segments=12, uv_region='armor_metal')
        strap = create_cylinder(Vec3(0, 0, -0.035), Vec3(0, 0, -0.015), 0.04, 0.04, segments=6, uv_region='leather_dark')
        round_sh.merge(rim)
        round_sh.merge(wood_face)
        round_sh.merge(boss)
        round_sh.merge(strap)
        gear['Round_Shield'] = round_sh

        # 4. Badge_Shield (Heater shield with crest, handle at origin)
        badge_sh = CharacterMesh('Badge_Shield')
        plate = create_box(Vec3(-0.20, -0.02, -0.28), Vec3(0.20, 0.02, 0.25), uv_region='armor_metal')
        crest = create_box(Vec3(-0.08, 0.015, -0.05), Vec3(0.08, 0.03, 0.12), uv_region='gold_trim')
        badge_sh.merge(plate)
        badge_sh.merge(crest)
        gear['Badge_Shield'] = badge_sh

        # 5. Rectangle_Shield (Kite shield, handle at origin)
        rect_sh = CharacterMesh('Rectangle_Shield')
        kite_face = create_box(Vec3(-0.22, -0.02, -0.45), Vec3(0.22, 0.02, 0.35), uv_region='outfit_primary')
        kite_rim = create_box(Vec3(-0.24, -0.025, -0.47), Vec3(0.24, 0.025, 0.37), uv_region='gold_trim')
        rect_sh.merge(kite_rim)
        rect_sh.merge(kite_face)
        gear['Rectangle_Shield'] = rect_sh

        # 6. Spike_Shield
        spike_sh = CharacterMesh('Spike_Shield')
        s_body = create_cylinder(Vec3(0, 0, -0.02), Vec3(0, 0, 0.02), 0.30, 0.30, segments=16, uv_region='armor_metal')
        spike = create_cylinder(Vec3(0, 0, 0.02), Vec3(0, 0, 0.18), 0.05, 0.005, segments=8, uv_region='silver_trim')
        spike_sh.merge(s_body)
        spike_sh.merge(spike)
        gear['Spike_Shield'] = spike_sh

        # 7. Knight_Helmet (Local head space, base at 0,0,0)
        helm = CharacterMesh('Knight_Helmet')
        h_dome = create_cylinder(Vec3(0, 0, 0.0), Vec3(0, 0, 0.20), 0.125, 0.095, segments=16, uv_region='armor_metal')
        h_ridge = create_box(Vec3(-0.015, -0.125, 0.02), Vec3(0.015, 0.125, 0.22), uv_region='gold_trim')
        helm.merge(h_dome)
        helm.merge(h_ridge)
        gear['Knight_Helmet'] = helm

        # 8. Knight_Cape (Local clasp at origin 0,0,0, fabric drapes down along -Z)
        cape = CharacterMesh('Knight_Cape')
        cape_spine = [
            Vec3(0, 0.02, 0.00),
            Vec3(0, 0.08, -0.28),
            Vec3(0, 0.12, -0.60),
            Vec3(0, 0.14, -0.90)
        ]
        cape.merge(create_tapered_hair_clump(cape_spine, [0.10, 0.22, 0.28, 0.32], segments=8, uv_region='cloth_accent'))
        gear['Knight_Cape'] = cape

    elif class_type == 'mage':
        # 1. 1H_Wand (Local grip at origin 0,0,0)
        wand = CharacterMesh('1H_Wand')
        w_shaft = create_cylinder(Vec3(0, 0, -0.10), Vec3(0, 0, 0.35), 0.015, 0.010, segments=8, uv_region='wood_props')
        w_spiral = create_cylinder(Vec3(0, 0, 0.25), Vec3(0, 0, 0.38), 0.018, 0.018, segments=8, uv_region='gold_trim')
        w_crystal = create_cylinder(Vec3(0, 0, 0.38), Vec3(0, 0, 0.48), 0.025, 0.005, segments=6, uv_region='rune_emissive')
        wand.merge(w_shaft)
        wand.merge(w_spiral)
        wand.merge(w_crystal)
        gear['1H_Wand'] = wand

        # 2. 2H_Staff (Local grip at origin 0,0,0)
        staff = CharacterMesh('2H_Staff')
        st_shaft = create_cylinder(Vec3(0, 0, -0.45), Vec3(0, 0, 1.25), 0.022, 0.020, segments=8, uv_region='wood_props')
        st_crescent = create_cylinder(Vec3(0, 0, 1.25), Vec3(0, 0, 1.55), 0.12, 0.09, segments=12, uv_region='gold_trim')
        st_gem = create_cylinder(Vec3(0, 0, 1.35), Vec3(0, 0, 1.45), 0.035, 0.035, segments=8, uv_region='rune_emissive')
        staff.merge(st_shaft)
        staff.merge(st_crescent)
        staff.merge(st_gem)
        gear['2H_Staff'] = staff

        # 3. Mage_Hat (Local head base at 0,0,0)
        hat = CharacterMesh('Mage_Hat')
        brim = create_cylinder(Vec3(0, 0, 0.0), Vec3(0, 0, 0.02), 0.28, 0.28, segments=16, uv_region='outfit_primary')
        cone = create_cylinder(Vec3(0, 0, 0.02), Vec3(0, 0.08, 0.38), 0.12, 0.015, segments=12, uv_region='outfit_primary')
        h_feather = create_box(Vec3(0.10, -0.05, 0.04), Vec3(0.12, 0.05, 0.25), uv_region='gold_trim')
        hat.merge(brim)
        hat.merge(cone)
        hat.merge(h_feather)
        gear['Mage_Hat'] = hat

        # 4. Mage_Cape (Local collar clasp at origin 0,0,0, mantle drapes down along -Z)
        m_cape = CharacterMesh('Mage_Cape')
        mantle_spine = [
            Vec3(0, 0.01, 0.00),
            Vec3(0, 0.05, -0.18),
            Vec3(0, 0.08, -0.42)
        ]
        m_cape.merge(create_tapered_hair_clump(mantle_spine, [0.12, 0.22, 0.26], segments=8, uv_region='outfit_secondary'))
        gear['Mage_Cape'] = m_cape

        # 5. Spellbook (Centered at origin 0,0,0)
        book = CharacterMesh('Spellbook')
        tome = create_box(Vec3(-0.12, -0.04, -0.15), Vec3(0.12, 0.04, 0.15), uv_region='leather_dark')
        pages = create_box(Vec3(-0.10, -0.03, -0.13), Vec3(0.10, 0.03, 0.13), uv_region='cloth_white')
        seal = create_box(Vec3(-0.04, -0.045, -0.04), Vec3(0.04, 0.045, 0.04), uv_region='gold_trim')
        book.merge(tome)
        book.merge(pages)
        book.merge(seal)
        gear['Spellbook'] = book

    return gear


def build_npc_prop_meshes(role: str) -> Dict[str, CharacterMesh]:
    """Builds specific NPC props matching exact specification names in local coordinates."""
    props: Dict[str, CharacterMesh] = {}

    if role == 'mayor':
        ledger = CharacterMesh('Prop_Ledger')
        tome = create_box(Vec3(-0.14, -0.05, -0.18), Vec3(0.14, 0.05, 0.18), uv_region='leather_dark')
        pages = create_box(Vec3(-0.12, -0.04, -0.16), Vec3(0.12, 0.04, 0.16), uv_region='cloth_white')
        corners = create_box(Vec3(-0.145, -0.055, -0.185), Vec3(0.145, 0.055, 0.185), uv_region='gold_trim')
        ledger.merge(corners)
        ledger.merge(tome)
        ledger.merge(pages)
        props['Prop_Ledger'] = ledger

    elif role == 'captain':
        sword = CharacterMesh('1H_Sword')
        pommel = create_cylinder(Vec3(0, 0, -0.12), Vec3(0, 0, -0.08), 0.02, 0.02, segments=8, uv_region='gold_trim')
        grip = create_cylinder(Vec3(0, 0, -0.08), Vec3(0, 0, 0.02), 0.016, 0.014, segments=8, uv_region='leather_dark')
        blade = create_cylinder(Vec3(0, 0, 0.02), Vec3(0, 0, 0.75), 0.03, 0.01, segments=6, uv_region='armor_metal')
        sword.merge(pommel)
        sword.merge(grip)
        sword.merge(blade)
        props['1H_Sword'] = sword

        shield = CharacterMesh('Round_Shield')
        rim = create_cylinder(Vec3(0, 0, -0.02), Vec3(0, 0, 0.02), 0.32, 0.32, segments=16, uv_region='armor_metal')
        face = create_cylinder(Vec3(0, 0, -0.015), Vec3(0, 0, 0.015), 0.28, 0.28, segments=16, uv_region='wood_props')
        shield.merge(rim)
        shield.merge(face)
        props['Round_Shield'] = shield

    elif role == 'widow':
        basket = CharacterMesh('Prop_Basket')
        b_body = create_cylinder(Vec3(0, 0, -0.22), Vec3(0, 0, 0.00), 0.14, 0.18, segments=12, uv_region='wood_props')
        handle = create_ring_torus(Vec3(0, 0, 0.05), Vec3(0, 1, 0), major_r=0.14, minor_r=0.012, major_segs=12, minor_segs=6, uv_region='wood_props')
        basket.merge(b_body)
        basket.merge(handle)
        props['Prop_Basket'] = basket

    elif role == 'gourmand':
        ladle = CharacterMesh('Prop_Ladle')
        handle = create_cylinder(Vec3(0, 0, -0.40), Vec3(0, 0, 0.15), 0.020, 0.016, segments=8, uv_region='wood_props')
        bowl = create_cylinder(Vec3(0, 0, 0.15), Vec3(0, 0, 0.26), 0.09, 0.08, segments=10, uv_region='wood_props')
        ladle.merge(handle)
        ladle.merge(bowl)
        props['Prop_Ladle'] = ladle

    elif role == 'smuggler':
        coin = CharacterMesh('Prop_Coin')
        c_mesh = create_cylinder(Vec3(0, 0, -0.006), Vec3(0, 0, 0.006), 0.040, 0.040, segments=12, uv_region='gold_trim')
        coin.merge(c_mesh)
        props['Prop_Coin'] = coin

    elif role == 'ranger':
        bow = CharacterMesh('Prop_Bow')
        spine = [
            Vec3(0, 0, -0.55),
            Vec3(0, -0.06, -0.28),
            Vec3(0, -0.08, 0.0),
            Vec3(0, -0.06, 0.28),
            Vec3(0, 0, 0.55)
        ]
        b_body = create_tapered_hair_clump(spine, [0.015, 0.020, 0.025, 0.020, 0.015], segments=6, uv_region='wood_props')
        string = create_cylinder(Vec3(0, 0, -0.55), Vec3(0, 0, 0.55), 0.003, 0.003, segments=4, uv_region='cloth_white')
        bow.merge(b_body)
        bow.merge(string)
        props['Prop_Bow'] = bow

    return props


# ==============================================================================
# 8. ANALYTICAL SKIN WEIGHTS CALCULATOR (ALIGNED WITH CANONICAL RIG)
# ==============================================================================

def compute_mesh_skin_weights(mesh: CharacterMesh, part_type: str, height: float) -> None:
    """Computes smooth, localized analytical skin weights aligned with canonical rig boundaries.

    Blends smoothly only near joint boundaries (~0.05m zone). Wrists deform Hand bone
    directly (not handslot). Maximum 4 influences per vertex.
    """
    s = height / 1.80

    # Scaled canonical joint boundaries
    z_head = 1.58 * s
    z_neck = 1.48 * s
    z_upper_chest = 1.35 * s
    z_chest = 1.20 * s
    z_spine = 1.08 * s
    z_hips = 0.98 * s
    z_knee = 0.52 * s
    z_ankle = 0.10 * s
    blend_zone = 0.05 * s

    for vidx, (x, y, z) in enumerate(mesh.vertices):
        wdict: Dict[str, float] = {}

        if part_type == 'Head':
            if z < z_head:
                t = max(0.0, min(1.0, (z_head - z) / blend_zone))
                wdict['Neck'] = t * 0.7
                wdict['Head'] = 1.0 - t * 0.7
            else:
                wdict['Head'] = 1.0

        elif part_type == 'Body':
            if z >= z_neck - blend_zone * 0.5:
                t = max(0.0, min(1.0, (z - (z_neck - blend_zone * 0.5)) / blend_zone))
                wdict['Neck'] = 0.5 * t
                wdict['UpperChest'] = 1.0 - 0.5 * t
            elif z >= z_upper_chest:
                if z >= z_neck - blend_zone:
                    t = (z - (z_neck - blend_zone)) / blend_zone
                    wdict['Neck'] = 0.4 * t
                    wdict['UpperChest'] = 1.0 - 0.4 * t
                elif z <= z_upper_chest + blend_zone:
                    t = (z - z_upper_chest) / blend_zone
                    wdict['UpperChest'] = 0.5 + 0.5 * t
                    wdict['Chest'] = 0.5 * (1.0 - t)
                else:
                    wdict['UpperChest'] = 1.0
            elif z >= z_chest:
                if z <= z_chest + blend_zone:
                    t = (z - z_chest) / blend_zone
                    wdict['Chest'] = 0.5 + 0.5 * t
                    wdict['Spine'] = 0.5 * (1.0 - t)
                else:
                    wdict['Chest'] = 1.0
            elif z >= z_spine:
                if z <= z_spine + blend_zone:
                    t = (z - z_spine) / blend_zone
                    wdict['Spine'] = 0.5 + 0.5 * t
                    wdict['Hips'] = 0.5 * (1.0 - t)
                else:
                    wdict['Spine'] = 1.0
            else:
                wdict['Hips'] = 1.0

        elif part_type in ('ArmLeft', 'ArmRight'):
            side_str = 'Left' if part_type == 'ArmLeft' else 'Right'
            side_sgn = 1.0 if part_type == 'ArmLeft' else -1.0

            # Projected position along arm axis
            # Shoulder at (0.16, 0.0, 1.45)*s, Elbow at (0.42, 0.02, 1.22)*s, Wrist at (0.66, 0.04, 1.00)*s
            p_sh = Vec3(side_sgn * 0.16 * s, 0.0, 1.45 * s)
            p_el = Vec3(side_sgn * 0.42 * s, 0.02 * s, 1.22 * s)
            p_wr = Vec3(side_sgn * 0.66 * s, 0.04 * s, 1.00 * s)
            v_pt = Vec3(x, y, z)

            d_sh = (v_pt - p_sh).length()
            d_el = (v_pt - p_el).length()
            d_wr = (v_pt - p_wr).length()

            # UpperArm vs LowerArm split at elbow
            # Project onto arm direction (X displacement primary indicator)
            x_arm = x * side_sgn
            x_sh = 0.16 * s
            x_el = 0.42 * s
            x_wr = 0.66 * s

            if x_arm < x_el - blend_zone:
                if x_arm < x_sh + blend_zone:
                    t = max(0.0, (x_arm - x_sh) / blend_zone)
                    wdict[f'{side_str}Shoulder'] = 0.4 * (1.0 - t)
                    wdict[f'{side_str}UpperArm'] = 0.6 + 0.4 * t
                else:
                    wdict[f'{side_str}UpperArm'] = 1.0
            elif x_arm <= x_el + blend_zone:
                # Smooth transition at elbow
                t = (x_arm - (x_el - blend_zone)) / (2.0 * blend_zone)
                wdict[f'{side_str}UpperArm'] = 1.0 - t
                wdict[f'{side_str}LowerArm'] = t
            elif x_arm < x_wr - blend_zone * 0.8:
                wdict[f'{side_str}LowerArm'] = 1.0
            elif x_arm <= x_wr + blend_zone * 0.8:
                # Smooth transition at wrist directly into Hand
                t = (x_arm - (x_wr - blend_zone * 0.8)) / (1.6 * blend_zone)
                wdict[f'{side_str}LowerArm'] = 1.0 - t
                wdict[f'{side_str}Hand'] = t
            else:
                # Hand takes 100% deformation (wrists deform Hand, not handslot)
                wdict[f'{side_str}Hand'] = 1.0

        elif part_type in ('LegLeft', 'LegRight'):
            side_str = 'Left' if part_type == 'LegLeft' else 'Right'

            if z >= z_knee + blend_zone:
                wdict[f'{side_str}UpperLeg'] = 1.0
            elif z >= z_knee - blend_zone:
                t = (z - (z_knee - blend_zone)) / (2.0 * blend_zone)
                wdict[f'{side_str}UpperLeg'] = t
                wdict[f'{side_str}LowerLeg'] = 1.0 - t
            elif z >= z_ankle + blend_zone:
                wdict[f'{side_str}LowerLeg'] = 1.0
            elif z >= z_ankle - blend_zone:
                t = (z - (z_ankle - blend_zone)) / (2.0 * blend_zone)
                wdict[f'{side_str}LowerLeg'] = t
                wdict[f'{side_str}Foot'] = 1.0 - t
            else:
                if y < -0.12 * s:
                    t = max(0.0, min(1.0, (-0.12 * s - y) / (0.05 * s)))
                    wdict[f'{side_str}Toes'] = 0.8 * t
                    wdict[f'{side_str}Foot'] = 1.0 - 0.8 * t
                else:
                    wdict[f'{side_str}Foot'] = 1.0

        # Sort and keep top 4 weights
        sorted_weights = sorted(wdict.items(), key=lambda item: item[1], reverse=True)[:4]
        total_w = sum(w for _, w in sorted_weights)
        if total_w > 1e-6:
            for b_name, w in sorted_weights:
                if b_name not in mesh.weights:
                    mesh.weights[b_name] = {}
                mesh.weights[b_name][vidx] = w / total_w
        else:
            fallback = 'Hips'
            if fallback not in mesh.weights:
                mesh.weights[fallback] = {}
            mesh.weights[fallback][vidx] = 1.0


def compute_prop_rigid_weights(mesh: CharacterMesh, parent_bone: str) -> None:
    """Rigidly assigns 1.0 weight for all prop vertices to the parent bone."""
    if parent_bone not in mesh.weights:
        mesh.weights[parent_bone] = {}
    for vidx in range(len(mesh.vertices)):
        mesh.weights[parent_bone][vidx] = 1.0


# ==============================================================================
# 9. BLENDER OBJECT INSTANTIATION (IDENTITY PARENTING & CLEAN WINDING)
# ==============================================================================

def create_blender_mesh_object(mesh_data: CharacterMesh, object_name: str, material: Any,
                               armature_obj: Any = None) -> Any:
    """Instantiates a native Blender Mesh and Object with preserved quads and identity transform."""
    if bpy is None:
        return None

    b_mesh = bpy.data.meshes.new(object_name)
    b_mesh.from_pydata(mesh_data.vertices, [], mesh_data.faces)
    b_mesh.validate(verbose=False)
    b_mesh.update(calc_edges=True)
    import bmesh
    bm=bmesh.new()
    bm.from_mesh(b_mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(b_mesh)
    bm.free()

    # Assign UVs
    if mesh_data.loop_uvs:
        uv_layer = b_mesh.uv_layers.new(name="UVMap")
        for loop_idx, loop in enumerate(b_mesh.loops):
            if loop_idx < len(mesh_data.loop_uvs):
                uv_layer.data[loop_idx].uv = mesh_data.loop_uvs[loop_idx]

    # Smooth shading
    for poly in b_mesh.polygons:
        poly.use_smooth = True

    b_obj = bpy.data.objects.new(object_name, b_mesh)
    bpy.context.collection.objects.link(b_obj)

    # Assign Material
    if material is not None:
        b_obj.data.materials.append(material)

    # Armature modifier, vertex groups, and identity transform parenting
    if armature_obj is not None:
        b_obj.parent = armature_obj
        b_obj.matrix_parent_inverse.identity()
        b_obj.matrix_world.identity()
        b_obj.matrix_basis.identity()

        mod = b_obj.modifiers.new(name="Armature", type='ARMATURE')
        mod.object = armature_obj

        for bone_name, v_weights in mesh_data.weights.items():
            vg = b_obj.vertex_groups.new(name=bone_name)
            for v_idx, weight in v_weights.items():
                vg.add([v_idx], weight, 'REPLACE')

    return b_obj
