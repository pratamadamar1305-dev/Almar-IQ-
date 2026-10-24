/**
 * Test ilustrasi gerakan (stick-man).
 *
 * Yang dijaga:
 *   - SETIAP gerakan di data punya pose (biar nggak ada gerakan tanpa gambar)
 *   - koordinat pose ada di dalam kanvas (nggak kepotong)
 *   - panjang tulang konsisten antar pose (anatomi nggak melar)
 *   - SVG yang digenerate valid & punya animasi saat animate=true
 *
 * Jalankan: node tests/fig.test.mjs
 */
import fs from 'node:fs'
import path from 'node:path'
import { execSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import os from 'node:os'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const ROOT = path.resolve(__dirname, '..')

let pass = 0
let fail = 0
const ok = (nama, kondisi, extra = '') => {
  if (kondisi) {
    pass++
    console.log(`  ✓ ${nama}`)
  } else {
    fail++
    console.log(`  ✗ ${nama} ${extra}`)
  }
}

/* ---------- muat fig.ts (di-bundle dulu) ---------- */
const tmp = path.join(os.tmpdir(), `fig-test-${Date.now()}.mjs`)
execSync(
  `npx esbuild src/lib/fig.ts --bundle --format=esm --platform=node --outfile=${tmp} --log-level=error`,
  { cwd: ROOT, stdio: 'inherit' }
)
const fig = await import(`file://${tmp}`)

const poses = JSON.parse(fs.readFileSync(path.join(ROOT, 'src/lib/poses.json'), 'utf8'))
const ids = Object.keys(poses).filter((k) => !k.startsWith('_'))

/* ---------- kumpulkan id gerakan dari data.ts ---------- */
const dataSrc = fs.readFileSync(path.join(ROOT, 'src/lib/data.ts'), 'utf8')
const gerakanIds = [...dataSrc.matchAll(/id:\s*'([a-z0-9-]+)'/g)].map((m) => m[1])

console.log(`\n  gerakan di data: ${gerakanIds.length}, pose tersedia: ${ids.length}`)

/* 1. kelengkapan */
ok('jumlah gerakan = 38', gerakanIds.length === 38, `dapat ${gerakanIds.length}`)
for (const id of gerakanIds) {
  ok(`pose ada: ${id}`, ids.includes(id))
}
for (const id of ids) {
  ok(`pose dipakai: ${id}`, gerakanIds.includes(id))
}

/* 2. koordinat di dalam kanvas */
const CANVAS = { w: 120, h: 130 }
const NODES = ['h', 'n', 'p', 'e', 'w', 'k', 'a', 't', 'e2', 'w2', 'k2', 'a2', 't2']
for (const id of ids) {
  const p = poses[id]
  for (const fr of ['a', 'b']) {
    const pose = p[fr] ?? p.a
    let minX = 999
    let maxX = -999
    let minY = 999
    let maxY = -999
    for (const n of NODES) {
      const pt = pose[n]
      if (!pt) continue
      minX = Math.min(minX, pt[0])
      maxX = Math.max(maxX, pt[0])
      minY = Math.min(minY, pt[1])
      maxY = Math.max(maxY, pt[1])
    }
    const inside = minX >= 6 && maxX <= CANVAS.w - 6 && minY >= -2 && maxY <= CANVAS.h - 2
    ok(
      `${id}.${fr} di dalam kanvas`,
      inside,
      `x ${minX}..${maxX}, y ${minY}..${maxY}`
    )
  }
}

/* 3. anatomi konsisten (panjang tulang) */
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1])
const THIGH = 18.5
const SHIN = 18.5
const TORSO = 30
const UPPER = 15
const FORE = 13
const TOL = 0.6

for (const id of ids) {
  const p = poses[id]
  for (const fr of ['a', 'b']) {
    const s = p[fr] ?? p.a
    const checks = []
    if (s.p && s.k) checks.push(['paha', dist(s.p, s.k), THIGH])
    if (s.k && s.a) checks.push(['betis', dist(s.k, s.a), SHIN])
    if (s.p && s.k2) checks.push(['paha jauh', dist(s.p, s.k2), THIGH])
    if (s.k2 && s.a2) checks.push(['betis jauh', dist(s.k2, s.a2), SHIN])
    if (s.p && s.n) checks.push(['badan', dist(s.p, s.n), TORSO])
    if (s.n && s.e) checks.push(['lengan atas', dist(s.n, s.e), UPPER])
    if (s.e && s.w) checks.push(['lengan bawah', dist(s.e, s.w), FORE])
    if (s.n && s.e2) checks.push(['lengan atas jauh', dist(s.n, s.e2), UPPER])
    if (s.e2 && s.w2) checks.push(['lengan bawah jauh', dist(s.e2, s.w2), FORE])

    const bad = checks.filter(([, got, want]) => Math.abs(got - want) > TOL)
    ok(
      `${id}.${fr} anatomi konsisten`,
      bad.length === 0,
      bad.map(([n, g, w]) => `${n} ${g.toFixed(1)}≠${w}`).join(', ')
    )
  }
}

/* 4. Gerakan yang dulu terlihat keliru: jaga arah dan titik pentingnya. */
const jarak = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1])
for (const id of ['senin-pike', 'jumat-pike']) {
  ok(`${id} benar-benar turun di fase akhir`, poses[id].b.h[1] - poses[id].a.h[1] >= 4)
}
const fly = poses['kamis-reverse-fly']
ok('reverse fly membungkuk dari pinggul', Math.abs(fly.b.p[0] - fly.b.n[0]) > 18 && jarak(fly.b.p, fly.b.n) <= 30.6)
ok('reverse fly sapu berhenti setinggi dada, bukan kepala', fly.b.br[0][1] > fly.b.h[1] + 12 && Math.abs(fly.b.br[0][1] - fly.b.br[1][1]) < 1)
const ext = poses['kamis-overhead-ext']
ok('overhead extension mulai dengan tas di atas kepala', ext.a.tas[1] < ext.a.h[1] - 15)
ok('overhead extension akhir menurunkan tas di belakang kepala', ext.b.tasBehind === 1 && ext.b.tas[1] > ext.b.h[1])
const hurdle = poses['kamis-hurdle']
ok('hurdle mulai di satu sisi sapu', hurdle.a.t[0] < hurdle.a.br[0][0])
ok('hurdle melompat melewati sapu pada fase akhir', hurdle.b.a[1] < hurdle.b.br[0][1] && hurdle.b.a2[1] < hurdle.b.br[0][1])
for (const id of ['senin-kuda', 'jumat-kuda']) {
  ok(`${id} kuda-kuda punya pijakan lebar`, Math.abs(poses[id].b.a[0] - poses[id].b.a2[0]) > 40)
}
ok('tas farmer walk menggantung dekat tangan', Math.abs(poses['selasa-farmer'].a.tas[0] - poses['selasa-farmer'].a.w[0]) < 4 && Math.abs(poses['selasa-farmer'].a.tas[1] - poses['selasa-farmer'].a.w[1]) < 4)

/* 5. markup SVG */
for (const id of ids) {
  const still = fig.figMarkup(id, {})
  ok(`${id} markup statis tidak kosong`, still.length > 100)
  ok(`${id} markup statis tanpa <animate>`, !still.includes('<animate'))
  ok(`${id} markup statis tanpa NaN`, !still.includes('NaN'))

  const anim = fig.figMarkup(id, { animate: true })
  ok(`${id} markup animasi tanpa NaN`, !anim.includes('NaN'))
  ok(`${id} markup punya tag animate`, anim.includes('<animate'))
}

ok('id tak dikenal -> string kosong', fig.figMarkup('nggak-ada', {}) === '')

/* 5. semua gerakan punya b (fase akhir) berbeda dari a */
for (const id of ids) {
  const p = poses[id]
  const beda =
    NODES.some((n) => JSON.stringify(p.a[n]) !== JSON.stringify(p.b[n])) ||
    JSON.stringify(p.a.br) !== JSON.stringify(p.b.br) ||
    JSON.stringify(p.a.tas) !== JSON.stringify(p.b.tas) ||
    p.a.grip !== p.b.grip
  ok(`${id} punya fase akhir berbeda`, beda)
}

console.log(`\n${pass} lulus, ${fail} gagal`)
if (fail > 0) process.exit(1)
