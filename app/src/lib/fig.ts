/**
 * Renderer stick-man untuk ilustrasi gerakan.
 *
 * Kanvas 120 x 130, lantai di y = 112.
 * Output: string SVG. Dipakai bareng oleh komponen React dan script preview,
 * jadi yang tampil di app = persis yang di-preview.
 *
 * Animasi pakai SMIL (<animate>): sendi bergerak halus dari fase awal ke
 * fase akhir lalu balik. Nol JavaScript, jalan di semua browser modern.
 */
import poses from './poses.json'

export type Pt = [number, number]

export interface Pose {
  h: Pt // kepala (pusat)
  n: Pt // leher / pangkal bahu
  p: Pt // panggul
  e: Pt // siku dekat
  w: Pt // pergelangan dekat
  k: Pt // lutut dekat
  a: Pt // mata kaki dekat
  t?: Pt // ujung kaki dekat
  e2?: Pt // siku jauh
  w2?: Pt // pergelangan jauh
  k2?: Pt // lutut jauh
  a2?: Pt // mata kaki jauh
  t2?: Pt // ujung kaki jauh
  br?: [Pt, Pt] // sapu
  tas?: [number, number, number, number] // tas: x, y, w, h
  mv?: [Pt, Pt, Pt] // panah gerak: dari, ke, kontrol
  mat?: number
  wall?: number
  door?: number
  ch?: number // kursi
  grip?: 'open' | 'fist'
  brBehind?: number
}

type NodeKey =
  | 'h' | 'n' | 'p' | 'e' | 'w' | 'k' | 'a' | 't'
  | 'e2' | 'w2' | 'k2' | 'a2' | 't2'

const FLOOR = 112
const DUR = '3.2s'
const POSE = poses as unknown as Record<string, { a: Pose; b: Pose }>

export const FIG_W = 120
export const FIG_H = 130

const TW = { torso: 7, thigh: 6.2, shin: 5.2, arm: 5, forearm: 4.4 }
const r1 = (v: number) => Math.round(v * 10) / 10

type Bone = [NodeKey, NodeKey, number]

const BONES: Bone[] = [
  ['p', 'k', TW.thigh],
  ['k', 'a', TW.shin],
  ['a', 't', TW.shin * 0.82],
  ['n', 'e', TW.arm],
  ['e', 'w', TW.forearm],
  ['p', 'k2', TW.thigh * 0.82],
  ['k2', 'a2', TW.shin * 0.82],
  ['a2', 't2', TW.shin * 0.72],
  ['n', 'e2', TW.arm * 0.82],
  ['e2', 'w2', TW.forearm * 0.82],
]

function has(p: Pose, k: NodeKey): boolean {
  return !!p[k]
}

/** Ambil titik; kalau kosong di satu frame, pinjam dari frame lain supaya sendi nggak lompat. */
function at(a: Pose, b: Pose, k: NodeKey): Pt {
  return (a[k] ?? b[k] ?? a.n) as Pt
}

/* ------------------------------------------------------------------ */
/*  Animasi SMIL                                                      */
/* ------------------------------------------------------------------ */
function anim(attr: string, va: number, vb: number, dur: string): string {
  if (Math.abs(va - vb) < 0.01) return ''
  const A = r1(va)
  const B = r1(vb)
  // maju -> tahan -> balik -> tahan
  return `<animate attributeName="${attr}" values="${A};${B};${B};${A}" keyTimes="0;0.45;0.55;1" dur="${dur}" repeatCount="indefinite" calcMode="spline" keySplines="0.4 0 0.6 1;0 0 1 1;0.4 0 0.6 1"/>`
}

function line(
  a1: Pt, b1: Pt, a2: Pt, b2: Pt, w: number, dur?: string
): string {
  const inner = dur
    ? anim('x1', a1[0], a2[0], dur) +
      anim('y1', a1[1], a2[1], dur) +
      anim('x2', b1[0], b2[0], dur) +
      anim('y2', b1[1], b2[1], dur)
    : ''
  return `<line x1="${r1(a1[0])}" y1="${r1(a1[1])}" x2="${r1(b1[0])}" y2="${r1(b1[1])}" stroke-width="${w}">${inner}</line>`
}

function circle(
  a1: Pt, a2: Pt, rad: number, cls = '', dur?: string
): string {
  const inner = dur
    ? anim('cx', a1[0], a2[0], dur) + anim('cy', a1[1], a2[1], dur)
    : ''
  return `<circle cx="${r1(a1[0])}" cy="${r1(a1[1])}" r="${rad}" class="${cls}">${inner}</circle>`
}

function bodyTransform(p: Pose): string {
  const dx = p.p[0] - p.n[0]
  const dy = p.p[1] - p.n[1]
  const angle = r1((Math.atan2(dy, dx) * 180) / Math.PI - 90)
  return `translate(${r1(p.n[0])} ${r1(p.n[1])}) rotate(${angle})`
}

/** Baju silat sederhana yang mengikuti arah badan pada semua pose. */
function uniform(a: Pose, b: Pose, dur?: string): string {
  const transform = bodyTransform(a)
  const motion = dur
    ? `<animate attributeName="transform" values="${transform};${bodyTransform(b)};${bodyTransform(b)};${transform}" keyTimes="0;0.45;0.55;1" dur="${dur}" repeatCount="indefinite" calcMode="spline" keySplines="0.4 0 0.6 1;0 0 1 1;0.4 0 0.6 1"/>`
    : ''
  return `<g class="fig-uniform" transform="${transform}">${motion}<path class="fig-shirt" d="M-5.8 1 Q0 -1.5 5.8 1 L4.8 22 L4.2 26 Q0 30 -4.2 26 L-4.8 22Z"/><path class="fig-shorts" d="M-4.8 21 L4.8 21 L5 29 Q0 33 -5 29Z"/><path class="fig-belt" d="M-4.9 21.5 L4.9 21.5"/></g>`
}

function head(p: Pose, q: Pose, dur?: string): string {
  const transform = (pt: Pt) => `translate(${r1(pt[0])} ${r1(pt[1])})`
  const motion = dur
    ? `<animate attributeName="transform" values="${transform(p.h)};${transform(q.h)};${transform(q.h)};${transform(p.h)}" keyTimes="0;0.45;0.55;1" dur="${dur}" repeatCount="indefinite" calcMode="spline" keySplines="0.4 0 0.6 1;0 0 1 1;0.4 0 0.6 1"/>`
    : ''
  return `<g class="fig-head-g" transform="${transform(p.h)}">${motion}<circle r="7.4" class="fig-head"/><path d="M-6.4 -2 Q-5.6 -8 0 -7.5 Q5.6 -8 6.4 -2 Q3.6 -4.3 0 -3.2 Q-3.6 -4.3 -6.4 -2Z" class="fig-hair"/><circle cx="-2.3" cy="0.6" r="0.7" class="fig-eye"/><circle cx="2.3" cy="0.6" r="0.7" class="fig-eye"/><path d="M-1.5 3.2 Q0 4.2 1.5 3.2" class="fig-smile"/></g>`
}

/* ------------------------------------------------------------------ */
/*  Props                                                             */
/* ------------------------------------------------------------------ */
function sapu(brA: [Pt, Pt], brB: [Pt, Pt], dur?: string): string {
  const [a1, b1] = brA
  const [a2, b2] = brB
  const dx = b1[0] - a1[0]
  const dy = b1[1] - a1[1]
  const L = Math.hypot(dx, dy) || 1
  const nx = -dy / L
  const ny = dx / L
  const bx = b1[0] + (dx / L) * 5
  const by = b1[1] + (dy / L) * 5
  const bristles = [-3, 0, 3]
    .map(
      (o) =>
        `<line x1="${r1(b1[0])}" y1="${r1(b1[1])}" x2="${r1(bx + nx * o)}" y2="${r1(by + ny * o)}" class="fig-prop-b" stroke-width="2.6"/>`
    )
    .join('')
  return (
    `<line x1="${r1(a1[0])}" y1="${r1(a1[1])}" x2="${r1(b1[0])}" y2="${r1(b1[1])}" class="fig-prop" stroke-width="4.6">` +
    (dur
      ? anim('x1', a1[0], a2[0], dur) +
        anim('y1', a1[1], a2[1], dur) +
        anim('x2', b1[0], b2[0], dur) +
        anim('y2', b1[1], b2[1], dur)
      : '') +
    `</line>` +
    circle(a1, a2, 2.8, 'fig-prop-f', dur) +
    bristles
  )
}

function tas(
  tA: number[], tB: number[], dur?: string
): string {
  const [x, y, w, h] = tA
  const [x2, y2] = tB
  const inner = dur ? anim('x', x, x2, dur) + anim('y', y, y2, dur) : ''
  return (
    `<g class="fig-tas-g"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="4.5" class="fig-tas">${inner}</rect>` +
    `<path d="M${x + w / 2 - 4} ${y + 2} q4 -5 8 0" class="fig-tas-line" stroke-width="2"/>` +
    `<line x1="${x + 3.5}" y1="${y + h * 0.46}" x2="${x + w - 3.5}" y2="${y + h * 0.46}" class="fig-tas-line"/>` +
    `<rect x="${x + w * 0.3}" y="${y + h * 0.62}" width="${w * 0.4}" height="${h * 0.24}" rx="1.6" class="fig-tas-line"/></g>`
  )
}

function scenery(p: Pose): string {
  const o: string[] = []
  if (p.wall) {
    o.push(`<rect x="96" y="4" width="5" height="${FLOOR - 4}" rx="2.5" class="fig-wall"/>`)
    for (let y = 10; y < FLOOR - 4; y += 11) {
      o.push(`<line x1="97" y1="${y}" x2="100" y2="${y + 5}" class="fig-wall-hatch"/>`)
    }
  }
  if (p.door) {
    o.push(`<rect x="82" y="14" width="27" height="${FLOOR - 14}" rx="3" class="fig-door"/>`)
    o.push(`<circle cx="103" cy="${FLOOR - 36}" r="1.7" class="fig-door-knob"/>`)
  }
  if (p.ch) {
    o.push(`<path d="M12 84 h27 M39 84 v${FLOOR - 84} M12 84 v${FLOOR - 84} M12 84 v-15 h23" class="fig-chair"/>`)
  }
  if (p.mat) {
    o.push(`<rect x="12" y="${FLOOR - 3}" width="96" height="9" rx="4.5" class="fig-mat"/>`)
  } else if (!p.wall && !p.door) {
    o.push(`<line x1="10" y1="${FLOOR}" x2="110" y2="${FLOOR}" class="fig-floor"/>`)
  }
  return o.join('')
}

function arrow(mv: [Pt, Pt, Pt]): string {
  const [from, to, c] = mv
  const ang = Math.atan2(to[1] - c[1], to[0] - c[0])
  const L = 6
  const tip = `M${r1(to[0] - Math.cos(ang - 0.5) * L)} ${r1(to[1] - Math.sin(ang - 0.5) * L)} L${r1(to[0])} ${r1(to[1])} L${r1(to[0] - Math.cos(ang + 0.5) * L)} ${r1(to[1] - Math.sin(ang + 0.5) * L)}`
  return (
    `<path d="M${from[0]} ${from[1]} Q${c[0]} ${c[1]} ${to[0]} ${to[1]}" class="fig-arc" stroke-width="2"/>` +
    `<path d="${tip}" class="fig-arc-head" stroke-width="2"/>`
  )
}

/* ------------------------------------------------------------------ */
/*  Rakit satu pose (atau animasi a->b)                               */
/* ------------------------------------------------------------------ */
export function poseFig(a: Pose, b?: Pose): string {
  const B = b ?? a
  const dur = b ? DUR : undefined

  const far: string[] = []
  const nearCore: string[] = []
  const joints: string[] = []

  for (const [n1, n2, w] of BONES) {
    if (!has(a, n1) && !has(B, n1)) continue
    if (!has(a, n2) && !has(B, n2)) continue
    // kaki/tangan sisi jauh tidak digambar kalau dua-duanya kosong
    const isFar = n1.endsWith('2') || n2.endsWith('2')
    const s = line(at(a, B, n1), at(a, B, n2), at(B, a, n1), at(B, a, n2), w, dur)
    if (isFar) far.push(s)
    else nearCore.push(s)
  }

  for (const k of ['k', 'a', 'e', 'w'] as NodeKey[]) {
    if (!has(a, k) && !has(B, k)) continue
    const rad = k === 'w' && (a.grip === 'open' || B.grip === 'open') ? 3.4 : k === 'w' ? 2.6 : 2.3
    joints.push(circle(at(a, B, k), at(B, a, k), rad, k === 'w' ? 'fig-hand' : '', dur))
  }

  const farJoints: string[] = []
  for (const k of ['k2', 'e2'] as NodeKey[]) {
    if (!has(a, k) && !has(B, k)) continue
    farJoints.push(circle(at(a, B, k), at(B, a, k), 2.1, k === 'e2' ? 'fig-far-f' : 'fig-hand', dur))
  }

  const neck = line(a.h, a.n, B.h, B.n, 3.2, dur)
  const body = uniform(a, B, dur)
  const face = head(a, B, dur)
  const bar = a.br ? sapu(a.br, B.br ?? a.br, dur) : ''
  const bag = a.tas ? tas(a.tas, B.tas ?? a.tas, dur) : ''

  return [
    `<g class="fig-bg">${scenery(a)}</g>`,
    `<g class="fig-far" stroke-linecap="round" stroke-linejoin="round">${far.join('')}${farJoints.join('')}</g>`,
    a.brBehind ? bar : '',
    `<g class="fig-near" stroke-linecap="round" stroke-linejoin="round">${body}<g class="fig-neck">${neck}</g>${nearCore.join('')}${joints.join('')}${face}</g>`,
    a.brBehind ? '' : bar,
    bag,
    a.mv ? `<g class="fig-mv">${arrow(a.mv)}</g>` : '',
  ]
    .filter(Boolean)
    .join('')
}

export function frameOf(id: string, frame: 'a' | 'b'): Pose | null {
  const x = POSE[id]
  if (!x) return null
  return x[frame] ?? x.a ?? null
}

export function hasPose(id: string): boolean {
  return !!POSE[id]
}

export interface FigOpts {
  animate?: boolean
}

/** Isi SVG (tanpa tag <svg> pembungkus). */
export function figMarkup(id: string, opts: FigOpts = {}): string {
  const x = POSE[id]
  if (!x) return ''
  return poseFig(x.a, opts.animate ? x.b ?? x.a : undefined)
}

/** CSS wajib untuk ilustrasi. Disuntik sekali oleh komponen. */
export const FIG_CSS = `
.gfig{display:block;overflow:visible}
.gfig .fig-bg line,.gfig .fig-bg path{stroke:var(--fig-line);fill:none;stroke-linecap:round;stroke-linejoin:round}
.gfig .fig-bg .fig-floor{stroke-width:2.4}
.gfig .fig-bg .fig-mat{fill:var(--fig-line);stroke:none;opacity:.6}
.gfig .fig-bg .fig-wall{fill:var(--fig-line);stroke:none;opacity:.55}
.gfig .fig-bg .fig-wall-hatch{stroke:var(--fig-bg);stroke-width:1.4;opacity:.7}
.gfig .fig-bg .fig-door{fill:none;stroke:var(--fig-line);stroke-width:2.6}
.gfig .fig-bg .fig-door-knob{fill:var(--fig-line);stroke:none}
.gfig .fig-bg .fig-chair{fill:none;stroke:var(--fig-line);stroke-width:3}
.gfig .fig-near{fill:none;stroke:var(--fig-ink);stroke-linecap:round;stroke-linejoin:round}
.gfig .fig-uniform{stroke:none}
.gfig .fig-shirt{fill:var(--fig-shirt);stroke:var(--fig-shirt-edge);stroke-width:1.2;stroke-linejoin:round}
.gfig .fig-shorts{fill:var(--fig-shorts);stroke:var(--fig-shirt-edge);stroke-width:1.1;stroke-linejoin:round}
.gfig .fig-belt{fill:none;stroke:var(--fig-accent);stroke-width:2.2;stroke-linecap:round}
.gfig .fig-neck{stroke:var(--fig-skin);stroke-width:3.6}
.gfig .fig-near .fig-head{fill:var(--fig-skin);stroke:var(--fig-head-edge);stroke-width:1.2}
.gfig .fig-head-g{stroke:none}
.gfig .fig-head-g .fig-hair{fill:var(--fig-hair)}
.gfig .fig-head-g .fig-eye{fill:var(--fig-hair)}
.gfig .fig-head-g .fig-smile{fill:none;stroke:var(--fig-hair);stroke-width:.7;stroke-linecap:round}
.gfig .fig-near circle{fill:var(--fig-ink);stroke:none}
.gfig .fig-near .fig-hand{fill:var(--fig-skin);stroke:var(--fig-head-edge);stroke-width:.8}
.gfig .fig-far{fill:none;stroke:var(--fig-far);stroke-linecap:round;stroke-linejoin:round}
.gfig .fig-far .fig-far-f{fill:var(--fig-far);stroke:none}
.gfig .fig-far .fig-hand{fill:var(--fig-skin);stroke:var(--fig-head-edge);stroke-width:.7}
.gfig .fig-prop{stroke:var(--fig-accent);stroke-linecap:round;fill:none}
.gfig .fig-prop-b{stroke:var(--fig-accent);stroke-linecap:round;fill:none;opacity:.85}
.gfig .fig-prop-f{fill:var(--fig-accent);stroke:none}
.gfig .fig-tas{fill:var(--fig-accent);opacity:.92}
.gfig .fig-tas-line{stroke:var(--fig-bg);stroke-width:1.6;opacity:.55;stroke-linecap:round;fill:none}
.gfig .fig-mv .fig-arc{fill:none;stroke:var(--fig-accent);stroke-dasharray:3 3.4;stroke-linecap:round;opacity:.8}
.gfig .fig-mv .fig-arc-head{fill:none;stroke:var(--fig-accent);stroke-linecap:round;stroke-linejoin:round}

/* panel ilustrasi */
.gfig-panel{position:relative;display:flex;flex-direction:column;align-items:center;
  border-radius:18px;border:1px solid var(--line);background:var(--fig-bg);
  padding:10px 0 8px;overflow:hidden}
.gfig-grid{position:absolute;inset:0;
  background-image:linear-gradient(var(--fig-line) 1px,transparent 1px),
    linear-gradient(90deg,var(--fig-line) 1px,transparent 1px);
  background-size:22px 22px;opacity:.5;
  mask-image:radial-gradient(circle at 50% 45%,#000 35%,transparent 78%);
  -webkit-mask-image:radial-gradient(circle at 50% 45%,#000 35%,transparent 78%)}
.gfig-panel .gfig{position:relative;z-index:1}
.gfig-hint{position:relative;z-index:1;display:flex;align-items:center;gap:6px;
  font-size:10px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;
  color:var(--dim2);margin-top:2px}
.gfig-dot{width:5px;height:5px;border-radius:50%;background:var(--fig-accent);
  animation:gfigPulse 3.2s ease-in-out infinite}
@keyframes gfigPulse{0%,40%{opacity:1}50%,90%{opacity:.35}100%{opacity:1}}
@media (prefers-reduced-motion:reduce){.gfig-dot{animation:none}}
`

/* Suntik sekali di browser. Di node (test/preview) di-skip. */
if (typeof document !== 'undefined' && !document.getElementById('fig-css')) {
  const el = document.createElement('style')
  el.id = 'fig-css'
  el.textContent = FIG_CSS
  document.head.appendChild(el)
}
