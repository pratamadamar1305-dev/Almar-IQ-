#!/usr/bin/env python3
"""
Eksplorasi desain logo DOJO TARUNG — beberapa konsep sekaligus.
Jalankan: python3 tools/logo-concepts.py
Butuh: pillow
Output: tools/out/logo-konsep.png (lembar perbandingan) + file per konsep
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)

SS = 4                      # supersampling
BASE = 512
W = BASE * SS
S = W / 512.0

BG_TOP = (18, 14, 12)
BG_BOT = (7, 9, 14)

INK = (26, 32, 44)
ORANGE = (255, 107, 26)
AMBER = (255, 197, 66)
DEEP = (240, 78, 0)
CORE = (255, 246, 216)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def bez(p0, p1, p2, p3, n=60):
    out = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        x = (mt**3 * p0[0] + 3 * mt**2 * t * p1[0]
             + 3 * mt * t**2 * p2[0] + t**3 * p3[0])
        y = (mt**3 * p0[1] + 3 * mt**2 * t * p1[1]
             + 3 * mt * t**2 * p2[1] + t**3 * p3[1])
        out.append((x * S, y * S))
    return out


def poly(segs):
    pts = []
    for seg in segs:
        pts += bez(*seg)
    return pts


# ------------------------------------------------------------------ #
#  Bentuk api
# ------------------------------------------------------------------ #
FLAME = [
    ((288, 40), (308, 92), (322, 128), (334, 170)),
    ((334, 170), (368, 224), (396, 288), (394, 334)),
    ((394, 334), (390, 396), (340, 440), (262, 444)),
    ((262, 444), (238, 447), (214, 446), (194, 440)),
    ((194, 440), (140, 424), (108, 370), (112, 306)),
    ((112, 306), (114, 262), (136, 222), (168, 188)),
    ((168, 188), (190, 226), (210, 248), (236, 254)),
    ((236, 254), (250, 192), (264, 114), (288, 40)),
]

CORE_SHAPE = [
    ((266, 252), (292, 296), (306, 328), (304, 358)),
    ((304, 358), (302, 388), (284, 410), (258, 414)),
    ((258, 414), (232, 410), (216, 388), (214, 358)),
    ((214, 358), (212, 328), (226, 296), (244, 268)),
    ((244, 268), (254, 258), (260, 254), (266, 252)),
]

def vgrad(size, stops):
    """Gradient vertikal penuh; stops = [(posisi 0-1, warna), ...]"""
    img = Image.new("RGB", (1, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        # cari dua stop mengapit t
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                k = (t - p0) / max(1e-6, p1 - p0)
                c = lerp(c0, c1, k)
                break
        else:
            c = stops[-1][1]
        d.point((0, y), fill=c)
    return img.resize((size, size))


def paint_polygon(img, points, grad):
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    img.paste(grad, (0, 0), mask)


def base_canvas():
    img = Image.new("RGB", (W, W), BG_BOT)
    d = ImageDraw.Draw(img)
    for y in range(W):
        c = lerp(BG_TOP, BG_BOT, y / (W - 1))
        d.line([(0, y), (W, y)], fill=c)
    return img


def add_glow(img, cx=256, cy=215, r=210, strength=1.0, color=ORANGE):
    glow = Image.new("L", (W, W), 0)
    g = ImageDraw.Draw(glow)
    steps = 46
    for i in range(steps, 0, -1):
        t = i / steps
        rr = r * S * t
        a = int(150 * strength * (1 - t) ** 2.4)
        g.ellipse([cx * S - rr, cy * S - rr, cx * S + rr, cy * S + rr], fill=a)
    glow = glow.filter(ImageFilter.GaussianBlur(W * 0.045))
    tint = Image.new("RGB", (W, W), color)
    return Image.composite(tint, img, glow.point(lambda v: int(v * 0.9)))


def draw_flame(img, scale=1.0, dy=0.0, core=True):
    cx = W / 2

    def tf(pts):
        return [(cx + (p[0] - cx) * scale, W / 2 + (p[1] - W / 2) * scale + dy * S)
                for p in pts]

    outer = tf(poly(FLAME))
    grad = vgrad(W, [
        (0.06, (255, 209, 92)),
        (0.30, (255, 168, 72)),
        (0.55, (255, 122, 48)),
        (0.85, (232, 74, 0)),
        (1.00, (196, 52, 0)),
    ])
    paint_polygon(img, outer, grad)

    if core:
        inner = tf(poly(CORE_SHAPE))
        grad2 = vgrad(W, [
            (0.30, (255, 252, 235)),
            (0.55, (255, 236, 180)),
            (0.85, (255, 199, 116)),
        ])
        paint_polygon(img, inner, grad2)
    return img


# ------------------------------------------------------------------ #
#  Konsep A — Dojo Seal (ring tebal bersegmen)
# ------------------------------------------------------------------ #
def konsep_a():
    img = add_glow(base_canvas(), strength=0.85)
    d = ImageDraw.Draw(img)
    R = 196 * S
    cx = cy = W / 2
    lw = int(17 * S)
    # 4 segmen dengan celah di diagonal
    for start, end in [(8, 82), (98, 172), (188, 262), (278, 352)]:
        d.arc([cx - R, cy - R, cx + R, cy + R],
              start=start, end=end, fill=ORANGE, width=lw)
    draw_flame(img, scale=0.80, dy=6, core=True)
    return img


# ------------------------------------------------------------------ #
#  Konsep B — Bold Flame (tanpa ring, api besar)
# ------------------------------------------------------------------ #
def konsep_b():
    img = add_glow(base_canvas(), strength=1.25, r=250)
    draw_flame(img, scale=1.02, dy=4, core=True)
    return img


# ------------------------------------------------------------------ #
#  Konsep C — Rising Sun (sinar radial + api)
# ------------------------------------------------------------------ #
def konsep_c():
    img = base_canvas()
    d = ImageDraw.Draw(img)
    cx = cy = W / 2
    # sinar
    rays = 16
    for i in range(rays):
        a0 = (360 / rays) * i
        a1 = a0 + (360 / rays) * 0.42
        r0, r1 = 150 * S, 300 * S
        for k, alpha in ((1.0, 30), (0.72, 18)):
            p = []
            for a in (a0, a1):
                rad = math.radians(a)
                p.append((cx + math.cos(rad) * r0, cy + math.sin(rad) * r0))
                p.append((cx + math.cos(rad) * r1 * k, cy + math.sin(rad) * r1 * k))
            pts = [p[0], p[1], p[3], p[2]]
            d.polygon(pts, fill=lerp(BG_BOT, ORANGE, alpha / 255) if False else None,
                      outline=None)
            # gambar manual dengan alpha
    # rays dengan layer transparan
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for i in range(rays):
        a0 = (360 / rays) * i
        a1 = a0 + (360 / rays) * 0.42
        r0, r1 = 148 * S, 306 * S
        pts = []
        for a in (a0, a1):
            rad = math.radians(a)
            pts.append((cx + math.cos(rad) * r1, cy + math.sin(rad) * r1))
        for a in (a1, a0):
            rad = math.radians(a)
            pts.append((cx + math.cos(rad) * r0, cy + math.sin(rad) * r0))
        ld.polygon(pts, fill=(255, 107, 26, 22))
    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")

    img = add_glow(img, strength=1.0, r=225)
    d = ImageDraw.Draw(img)
    R = 172 * S
    d.ellipse([cx - R, cy - R, cx + R, cy + R],
              outline=lerp(BG_BOT, ORANGE, 0.55), width=int(5 * S))
    draw_flame(img, scale=0.76, dy=4, core=True)
    return img


# ------------------------------------------------------------------ #
#  Konsep D — Emblem chevron (naik / progres)
# ------------------------------------------------------------------ #
def konsep_d():
    img = add_glow(base_canvas(), strength=0.9)
    draw_flame(img, scale=0.74, dy=-16, core=True)
    d = ImageDraw.Draw(img)
    # chevron bawah, tebal, membungkus api
    for spread, lw in ((118, 20), (86, 20)):
        y = 372
        pts = [(W / 2 - spread * S, (y + 34) * S),
               (W / 2, y * S),
               (W / 2 + spread * S, (y + 34) * S)]
        d.line(pts, fill=ORANGE, width=int(lw * S), joint="curve")
        for p in (pts[0], pts[2]):
            r = lw * S / 2
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=ORANGE)
    return img


CONCEPTS = {"A": ("Dojo Seal", konsep_a),
            "B": ("Bold Flame", konsep_b),
            "C": ("Rising Sun", konsep_c),
            "D": ("Emblem", konsep_d)}


def main():
    tiles = []
    for key, (name, fn) in CONCEPTS.items():
        big = fn().resize((512, 512), Image.LANCZOS)
        big.save(os.path.join(OUT, f"logo-{key}.png"))

        # versi kecil untuk uji keterbacaan
        small = big.resize((64, 64), Image.LANCZOS)
        tiny = big.resize((32, 32), Image.LANCZOS)

        tile = Image.new("RGB", (512, 620), (14, 16, 22))
        tile.paste(big, (0, 0))
        d = ImageDraw.Draw(tile)
        d.text((16, 528), f"{key}. {name}", fill=(230, 236, 246))
        tile.paste(small, (16, 552))
        tile.paste(tiny, (96, 568))
        tiles.append(tile)

    sheet = Image.new("RGB", (512 * 2, 620 * 2), (8, 10, 14))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * 512, (i // 2) * 620))
    sheet.save(os.path.join(OUT, "logo-konsep.png"))
    print("→", os.path.join(OUT, "logo-konsep.png"), sheet.size)


if __name__ == "__main__":
    main()
