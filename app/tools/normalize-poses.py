#!/usr/bin/env python3
"""
Normalisasi anatomi stick-man.

Masalah yang diselesaikan: kalau titik sendi dikarang pakai mata, panjang
tulang jadi beda-beda tiap pose (kaki "melar" 36px padahal harusnya 18px).
Akibatnya karakter terlihat berubah proporsi antar gerakan.

Cara kerja:
  1. ARAH tiap tulang dipertahankan (itu yang bikin pose punya makna)
  2. PANJANG tulang dipaksa seragam
  3. Sendi tengah (lutut/siku) dihitung ulang pakai IK 2-batang

Bone reference:
  badan (panggul->leher) 30 | kepala +10 dari leher
  paha 18.5 | betis 18.5 | ujung kaki bebas
  lengan atas 15 | lengan bawah 13

Jalankan: python3 tools/normalize-poses.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "src/lib/poses.json")

TORSO = 30.0
NECK_HEAD = 10.0
THIGH = 18.5
SHIN = 18.5
UPPER = 15.0
FORE = 13.0


def unit(dx, dy):
    n = math.hypot(dx, dy)
    if n < 1e-6:
        return 0.0, 1.0
    return dx / n, dy / n


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def ik(root, end, l1, l2, hint):
    """Titik sendi antara root & end, dengan panjang l1/l2, di sisi hint."""
    rx, ry = root
    ex, ey = end
    dx, dy = ex - rx, ey - ry
    d = math.hypot(dx, dy)
    if d < 1e-6:
        return list(hint)
    d = clamp(d, abs(l1 - l2) + 0.05, l1 + l2 - 0.05)
    a = (d * d + l1 * l1 - l2 * l2) / (2 * d)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    ux, uy = dx / math.hypot(dx, dy), dy / math.hypot(dx, dy)
    mx, my = rx + ux * a, ry + uy * a
    px, py = -uy, ux
    c1 = (mx + px * h, my + py * h)
    c2 = (mx - px * h, my - py * h)
    hx, hy = hint
    c = c1 if (c1[0] - hx) ** 2 + (c1[1] - hy) ** 2 <= (c2[0] - hx) ** 2 + (c2[1] - hy) ** 2 else c2
    return [round(c[0], 1), round(c[1], 1)]


def put(v, maxlen):
    """Paksa titik tetap sejauh maxlen dari asal (arah dipertahankan)."""
    return [round(v[0], 1), round(v[1], 1)]


def norm_pose(p):
    q = {k: list(v) if isinstance(v, list) else v for k, v in p.items()}
    if "p" not in q or "n" not in q:
        return q

    # --- 1. badan: panggul tetap, leher dijarakkan TORSO ---
    ux, uy = unit(q["n"][0] - q["p"][0], q["n"][1] - q["p"][1])
    q["n"] = [round(q["p"][0] + ux * TORSO, 1), round(q["p"][1] + uy * TORSO, 1)]

    # --- 2. kepala mengikuti arah badan ---
    if "h" in q:
        q["h"] = [round(q["n"][0] + ux * NECK_HEAD, 1), round(q["n"][1] + uy * NECK_HEAD, 1)]

    # --- 3. kaki: arah mata kaki dipertahankan, panjang dipaksa ---
    for hip, ank, knee, toe in (("p", "a", "k", "t"), ("p", "a2", "k2", "t2")):
        if hip not in q or ank not in q:
            continue
        vx, vy = unit(q[ank][0] - q[hip][0], q[ank][1] - q[hip][1])
        reach = clamp(
            math.hypot(q[ank][0] - q[hip][0], q[ank][1] - q[hip][1]),
            abs(THIGH - SHIN) + 1,
            THIGH + SHIN - 0.2,
        )
        # offset ujung kaki relatif mata kaki (dijaga)
        toe_off = None
        if toe in q:
            toe_off = (q[toe][0] - q[ank][0], q[toe][1] - q[ank][1])
        q[ank] = [round(q[hip][0] + vx * reach, 1), round(q[hip][1] + vy * reach, 1)]
        hint = q.get(knee, [q[hip][0] + vx * THIGH, q[hip][1] + vy * THIGH])
        q[knee] = ik(q[hip], q[ank], THIGH, SHIN, hint)
        if toe in q and toe_off:
            q[toe] = [round(q[ank][0] + toe_off[0], 1), round(q[ank][1] + toe_off[1], 1)]

    # --- 4. lengan: arah pergelangan dipertahankan, panjang dipaksa ---
    for neu, wri, elb in (("n", "w", "e"), ("n", "w2", "e2")):
        if neu not in q or wri not in q:
            continue
        vx, vy = unit(q[wri][0] - q[neu][0], q[wri][1] - q[neu][1])
        reach = clamp(
            math.hypot(q[wri][0] - q[neu][0], q[wri][1] - q[neu][1]),
            abs(UPPER - FORE) + 1,
            UPPER + FORE - 0.2,
        )
        q[wri] = [round(q[neu][0] + vx * reach, 1), round(q[neu][1] + vy * reach, 1)]
        hint = q.get(elb, [q[neu][0] + vx * UPPER, q[neu][1] + vy * UPPER])
        q[elb] = ik(q[neu], q[wri], UPPER, FORE, hint)

    return q


def main():
    data = json.load(open(P))
    changed = 0
    for k, v in data.items():
        if k.startswith("_"):
            continue
        for fr in ("a", "b"):
            if fr not in v:
                continue
            before = json.dumps(v[fr], sort_keys=True)
            v[fr] = norm_pose(v[fr])
            if json.dumps(v[fr], sort_keys=True) != before:
                changed += 1
    json.dump(data, open(P, "w"), ensure_ascii=False, indent=2)
    print(f"normalisasi selesai: {changed} pose disesuaikan")


if __name__ == "__main__":
    main()
