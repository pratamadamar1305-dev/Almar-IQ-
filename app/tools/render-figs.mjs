/**
 * Render semua pose ke PNG lewat resvg — PERSIS markup yang dipakai app.
 * Jalankan: node tools/render-figs.mjs
 */
import { execSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const OUT = path.join(ROOT, 'tools/out')
fs.mkdirSync(OUT, { recursive: true })

// bundle fig.ts supaya bisa dipakai dari node
const tmp = path.join(os.tmpdir(), 'fig-bundle.mjs')
execSync(
  `npx esbuild src/lib/fig.ts --bundle --format=esm --platform=node --outfile=${tmp} --log-level=error`,
  { cwd: ROOT, stdio: 'inherit' }
)
const fig = await import(`file://${tmp}?t=${Date.now()}`)

const { Resvg } = await import('@resvg/resvg-js')

const DARK = {
  '--fig-ink': '#eef3fb',
  '--fig-far': '#6b7789',
  '--fig-shirt': '#35c9b7',
  '--fig-shirt-edge': '#147e78',
  '--fig-shorts': '#30435c',
  '--fig-skin': '#f3bd91',
  '--fig-head-edge': '#965c43',
  '--fig-hair': '#263244',
  '--orange': '#ff6b1a',
  '--amber': '#ffc542',
  '--line': '#232b3a',
}
const LIGHT = {
  '--fig-ink': '#1a2233',
  '--fig-far': '#9aa6b8',
  '--fig-shirt': '#10ae9d',
  '--fig-shirt-edge': '#08786e',
  '--fig-shorts': '#cbdce9',
  '--fig-skin': '#f5c49e',
  '--fig-head-edge': '#a9684b',
  '--fig-hair': '#334155',
  '--orange': '#f2610f',
  '--amber': '#e0a01c',
  '--line': '#dbe2ee',
}

function vars(v) {
  return Object.entries(v)
    .map(([k, val]) => `${k}:${val}`)
    .join(';')
}

const STYLE = fig.FIG_CSS + `
.fig-bg line{stroke:var(--line);stroke-width:2;stroke-linecap:round}
.fig-bg .fig-floor{stroke:var(--line);stroke-width:2.4}
.fig-bg .fig-mat{fill:var(--line);opacity:.55}
.fig-bg .fig-wall{fill:var(--line);opacity:.5}
.fig-bg .fig-wall-hatch{stroke:#0d1117;stroke-width:1.4;opacity:.55}
.fig-bg .fig-door{fill:none;stroke:var(--line);stroke-width:2.6}
.fig-bg .fig-door-knob{fill:var(--line)}
.fig-bg .fig-chair{fill:none;stroke:var(--line);stroke-width:3;stroke-linecap:round;stroke-linejoin:round}
.fig-near{fill:none;stroke:var(--fig-ink);stroke-linecap:round;stroke-linejoin:round}
.fig-head{fill:var(--fig-skin);stroke:var(--fig-head-edge);stroke-width:1.2}
.fig-head-g{stroke:none}
.fig-head-g .fig-hair,.fig-head-g .fig-eye{fill:var(--fig-hair)}
.fig-head-g .fig-smile{fill:none;stroke:var(--fig-hair);stroke-width:.7}
.fig-uniform{stroke:none}
.fig-shirt{fill:var(--fig-shirt);stroke:var(--fig-shirt-edge);stroke-width:1.2}
.fig-shorts{fill:var(--fig-shorts);stroke:var(--fig-shirt-edge);stroke-width:1.1}
.fig-belt{fill:none;stroke:var(--amber);stroke-width:2.2}
.fig-neck{stroke:var(--fig-skin);stroke-width:3.6}
.fig-near circle{fill:var(--fig-ink);stroke:none}
.fig-near .fig-hand{fill:var(--fig-skin);stroke:var(--fig-head-edge);stroke-width:.8}
.fig-far{fill:none;stroke:var(--fig-far);stroke-linecap:round;stroke-linejoin:round;opacity:.85}
.fig-far .fig-hand{fill:var(--fig-skin);stroke:var(--fig-head-edge);stroke-width:.7}
.fig-far .fig-far-f{fill:var(--fig-far);stroke:none}
.fig-prop{stroke:var(--amber);stroke-linecap:round}
.fig-prop-b{stroke:var(--amber);stroke-linecap:round;opacity:.85}
.fig-prop-f{fill:var(--amber);stroke:none}
.fig-tas{fill:var(--orange);opacity:.9}
.fig-tas-line{stroke:#0d1117;stroke-width:1.6;opacity:.45;stroke-linecap:round}
.fig-mv .fig-arc{fill:none;stroke:var(--orange);stroke-dasharray:3 3.4;stroke-linecap:round;opacity:.85}
.fig-mv .fig-arc-head{fill:none;stroke:var(--orange);stroke-linecap:round;stroke-linejoin:round}
`

const posesJson = JSON.parse(fs.readFileSync(path.join(ROOT, 'src/lib/poses.json'), 'utf8'))
const ids = Object.keys(posesJson).filter((k) => !k.startsWith('_'))

// resvg nggak resolve CSS custom property -> substitusi manual untuk preview
function subst(css, theme) {
  return css.replace(/var\((--[a-z0-9-]+)(?:\s*,\s*([^)]+))?\)/g, (_, name, fb) => theme[name] || fb || 'transparent')
}

function svgFor(id, theme, frame = 'a') {
  const pos = posesJson[id]?.[frame] ?? posesJson[id]?.a
  const body = subst(fig.poseFig(pos), theme)
  return `<svg xmlns="http://www.w3.org/2000/svg" width="120" height="130" viewBox="0 0 120 130" style="${vars(theme)}">
  <style>${subst(STYLE, theme)}</style>
  ${body}
</svg>`
}


// interpolasi linear semua node -> cek pose tengah animasi
function lerpPose(a, b, t) {
  const keys = ['h','n','p','e','w','k','a','t','e2','w2','k2','a2','t2']
  const out = { ...a }
  for (const k of keys) {
    const A = a[k], B = b[k]
    if (!A && !B) continue
    const p0 = A || B, p1 = B || A
    out[k] = [p0[0] + (p1[0]-p0[0])*t, p0[1] + (p1[1]-p0[1])*t]
  }
  if (a.br && b.br) out.br = [
    [a.br[0][0]+(b.br[0][0]-a.br[0][0])*t, a.br[0][1]+(b.br[0][1]-a.br[0][1])*t],
    [a.br[1][0]+(b.br[1][0]-a.br[1][0])*t, a.br[1][1]+(b.br[1][1]-a.br[1][1])*t],
  ]
  if (a.tas && b.tas) out.tas = [
    a.tas[0]+(b.tas[0]-a.tas[0])*t, a.tas[1]+(b.tas[1]-a.tas[1])*t,
    a.tas[2], a.tas[3],
  ]
  return out
}

function svgPose(pos, theme) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="120" height="130" viewBox="0 0 120 130" style="${vars(theme)}">
  <style>${subst(STYLE, theme)}</style>
  ${subst(fig.poseFig(pos), theme)}
</svg>`
}

function png(svg, w = 300) {
  const r = new Resvg(svg, { fitTo: { mode: 'width', value: w } })
  return r.render().asPng()
}

// --- render per gerakan (dark) ke folder ---
const dir = path.join(OUT, 'fig')
fs.rmSync(dir, { recursive: true, force: true })
fs.mkdirSync(dir, { recursive: true })

for (const id of ids) {
  fs.writeFileSync(path.join(dir, `${id}.png`), png(svgFor(id, DARK), 300))
}

// --- lembar kontak per hari ---
const GROUPS = {
  senin: ids.filter((i) => i.startsWith('senin')),
  selasa: ids.filter((i) => i.startsWith('selasa')),
  kamis: ids.filter((i) => i.startsWith('kamis')),
  jumat: ids.filter((i) => i.startsWith('jumat')),
}

const COLS = 5
const CELL = 300
const PAD = 8
const LABEL_H = 18
const THIRD = Math.round(CELL / 3)
const CELL_H = Math.round((THIRD * 130) / 120)

function sheet(list, file, theme, frame) {
  const rows = Math.ceil(list.length / COLS)
  const W = COLS * (CELL + PAD) + PAD
  const H = rows * (CELL_H + PAD + LABEL_H) + PAD
  const bg = theme === DARK ? '#0d1117' : '#f6f8fd'
  const fg = theme === DARK ? '#8a94a6' : '#64708a'
  let inner = ''
  list.forEach((id, i) => {
    const x = PAD + (i % COLS) * (CELL + PAD)
    const y = PAD + Math.floor(i / COLS) * (CELL_H + PAD + LABEL_H)
    const third = THIRD
    const P = posesJson[id]
    const frames = [P.a, lerpPose(P.a, P.b, 0.5), P.b]
    const lab = ['a', 'mid', 'b']
    for (let fi = 0; fi < 3; fi++) {
      const b64 = png(svgPose(frames[fi], theme), third).toString('base64')
      inner += `<image x="${x + fi * third}" y="${y}" width="${third}" height="${Math.round((third * 130) / 120)}" xlink:href="data:image/png;base64,${b64}" href="data:image/png;base64,${b64}"/>`
      inner += `<text x="${x + fi * third + 3}" y="${y + CELL_H - 2}" font-family="monospace" font-size="8" fill="${fg}" opacity=".55">${lab[fi]}</text>`
    }
    inner += `<text x="${x + 4}" y="${y + CELL_H + 15}" font-family="monospace" font-size="11" fill="${fg}">${id}</text>`
  })
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}"><rect width="${W}" height="${H}" fill="${bg}"/>${inner}</svg>`
  fs.writeFileSync(file, png(svg, W))
}

for (const [name, list] of Object.entries(GROUPS)) {
  sheet(list, path.join(OUT, `fig-${name}.png`), DARK, 'a')
}
sheet(ids, path.join(OUT, 'fig-semua.png'), DARK, 'a')

console.log('ok:', ids.length, 'gerakan')
