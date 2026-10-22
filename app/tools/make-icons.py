#!/usr/bin/env python3
"""
Generator ikon DOJO TARUNG.
Jalankan: python3 tools/make-icons.py
Butuh: pillow  (pip install pillow)

Menghasilkan di public/icons/:
  icon-192.png, icon-512.png         -> ikon biasa (any)
  maskable-192.png, maskable-512.png -> versi maskable (safe zone 80%)
  apple-touch-180.png                -> iOS home screen
  favicon-32.png
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "public", "icons")
SS = 4  # supersampling

BASE = 512


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def bez(p0, p1, p2, p3, n=42):
    """Sample cubic bezier."""
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


# Api utama: lidah api asimetris.
# Sisi kiri naik lurus, puncak melengkung ke kanan lalu jatuh
# membentuk lidah yang menjilat ke atas-kanan.
FLAME_OUTER = [
    # puncak (ujung kiri-atas) turun mengikuti sisi luar kiri
    ((166, 250), (172, 200), (196, 160), (238, 118)),
    # naik ke puncak
    ((238, 118), (262, 92), (292, 74), (306, 62)),
    # puncak jatuh ke kanan (lekuk lidah api)
    ((306, 62), (298, 104), (312, 132), (342, 154)),
    # menonjol keluar kanan
    ((342, 154), (372, 178), (388, 220), (388, 262)),
    # turun ke dasar kanan
    ((388, 262), (388, 330), (352, 392), (288, 414)),
    # dasar (gelombang)
    ((288, 414), (262, 420), (232, 416), (208, 404)),
    # dasar kiri naik
    ((208, 404), (176, 386), (156, 344), (156, 300)),
    # sisi kiri
    ((156, 300), (156, 282), (160, 266), (166, 250)),
]

# Lidah api dalam
FLAME_INNER = [
    ((232, 246), (258, 214), (280, 194), (288, 176)),
    ((288, 176), (284, 212), (296, 238), (310, 256)),
    ((310, 256), (326, 276), (330, 306), (322, 336)),
    ((322, 336), (308, 372), (276, 392), (240, 390)),
    ((240, 390), (210, 386), (190, 360), (188, 326)),
    ((188, 326), (186, 300), (202, 272), (232, 246)),
]

def flame_polygon(segs, s):
    pts = []
    for seg in segs:
        pts += bez(*[[c * s for c in p] for p in seg])
    return pts


def build(size=1024, scale_art=1.0, rounded=False, radius_ratio=0.22):
    W = size * SS
    img = Image.new("RGB", (W, W), (7, 9, 16))
    d = ImageDraw.Draw(img)

    # --- latar: gradien vertikal gelap ---
    c1, c2 = (26, 16, 8), (7, 9, 16)
    for y in range(W):
        d.line([(0, y), (W, y)], fill=lerp(c1, c2, y / (W - 1)))

    # --- glow oranye di tengah atas ---
    glow = Image.new("L", (W, W), 0)
    gd = ImageDraw.Draw(glow)
    cx, cy, r = W * 0.5, W * 0.40, W * 0.55
    steps = 60
    for i in range(steps, 0, -1):
        t = i / steps
        rr = r * t
        alpha = int(150 * (1 - t) ** 2)
        gd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=alpha)
    glow = glow.filter(ImageFilter.GaussianBlur(W * 0.05))
    orange = Image.new("RGB", (W, W), (255, 107, 26))
    img = Image.composite(orange, img, glow.point(lambda v: int(v * 0.85)))

    d = ImageDraw.Draw(img)
    s = W / 512.0
    # flame_polygon() sudah mengalikan dengan s, jadi di sini hanya
    # perlu scaling tambahan terhadap pusat (untuk versi maskable).
    def tx(p):
        return (W / 2 + (p[0] - W / 2) * scale_art,
                W / 2 + (p[1] - W / 2) * scale_art)

    # --- cincin dojo ---
    for rr, alpha, wid in ((196, 26, 3), (168, 56, 6)):
        R = rr * s * scale_art
        box = [W / 2 - R, W / 2 - R, W / 2 + R, W / 2 + R]
        d.ellipse(box, outline=(255, 107, 26, alpha), width=max(2, int(wid * s * scale_art)))

    # --- api luar: gradien vertikal, di-mask polygon ---
    poly = [tx(p) for p in flame_polygon(FLAME_OUTER, s)]
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)

    ys = [p[1] for p in poly]
    top, bot = min(ys), max(ys)
    fgrad = Image.new("RGB", (W, W))
    fgd = ImageDraw.Draw(fgrad)
    ctop, cmid, cbot = (255, 209, 92), (255, 143, 61), (240, 78, 0)
    for y in range(W):
        t = max(0.0, min(1.0, (y - top) / max(1, bot - top)))
        c = lerp(ctop, cmid, t / 0.45) if t < 0.45 else lerp(cmid, cbot, (t - 0.45) / 0.55)
        fgd.line([(0, y), (W, y)], fill=c)
    img.paste(fgrad, (0, 0), mask)

    # --- api dalam ---
    poly2 = [tx(p) for p in flame_polygon(FLAME_INNER, s)]
    mask2 = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask2).polygon(poly2, fill=242)
    ys2 = [p[1] for p in poly2]
    top2, bot2 = min(ys2), max(ys2)
    fgrad2 = Image.new("RGB", (W, W))
    fgd2 = ImageDraw.Draw(fgrad2)
    for y in range(W):
        t = max(0.0, min(1.0, (y - top2) / max(1, bot2 - top2)))
        fgd2.line([(0, y), (W, y)], fill=lerp((255, 243, 196), (255, 182, 72), t))
    img.paste(fgrad2, (0, 0), mask2)

    img = img.resize((size, size), Image.LANCZOS)

    if rounded:
        r = int(size * radius_ratio)
        m = Image.new("L", (size, size), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.paste(img, (0, 0), m)
        return out

    return img


def main():
    os.makedirs(OUT, exist_ok=True)

    # ikon "any" full-bleed (Android memotong sendiri sesuai bentuk launcher)
    build(512).save(os.path.join(OUT, "icon-512.png"))
    build(192).save(os.path.join(OUT, "icon-192.png"))

    # maskable: seni diperkecil ke 78% supaya aman dari crop lingkaran/squircle
    build(512, scale_art=0.78).save(os.path.join(OUT, "maskable-512.png"))
    build(192, scale_art=0.78).save(os.path.join(OUT, "maskable-192.png"))

    # iOS (iOS membulatkan sendiri, jadi pakai full-bleed kotak)
    build(180).save(os.path.join(OUT, "apple-touch-180.png"))

    # favicon
    build(32).save(os.path.join(OUT, "favicon-32.png"))

    # versi rounded buat dipakai di web/README
    build(256, rounded=True).save(os.path.join(OUT, "icon-rounded-256.png"))

    for f in sorted(os.listdir(OUT)):
        p = os.path.join(OUT, f)
        print(f"{f:28s} {os.path.getsize(p) // 1024} KB")


if __name__ == "__main__":
    main()
