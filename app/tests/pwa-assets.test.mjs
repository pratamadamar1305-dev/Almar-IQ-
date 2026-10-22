/**
 * Validasi aset PWA tanpa browser.
 * Memastikan syarat installability terpenuhi (Chrome + iOS):
 *   - manifest valid, field wajib lengkap
 *   - ikon 192 & 512 ada, ukurannya benar, dan benar-benar PNG
 *   - index.html memasang manifest, apple-touch-icon, theme-color
 *   - sw.js punya handler fetch (syarat installable Chrome)
 *
 * Jalankan: node tests/pwa-assets.test.mjs
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const ROOT = path.resolve(__dirname, '..')
const PUB = path.join(ROOT, 'public')

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

/** Baca lebar/tinggi dari header PNG (IHDR). */
function ukuranPng(file) {
  const b = fs.readFileSync(file)
  if (b.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') return null
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20), bit: b[24], colorType: b[25] }
}

console.log('\n▶ aset PWA')

/* ---------------- manifest ---------------- */
const mPath = path.join(PUB, 'manifest.webmanifest')
ok('manifest.webmanifest ada', fs.existsSync(mPath))

let m = {}
try {
  m = JSON.parse(fs.readFileSync(mPath, 'utf8'))
} catch (e) {
  ok('manifest valid JSON', false, e.message)
}

ok('name terisi', typeof m.name === 'string' && m.name.length > 3)
ok('short_name <= 12 karakter (biar nggak kepotong)', (m.short_name || '').length <= 12, m.short_name)
ok('start_url ada di dalam scope', typeof m.start_url === 'string' && m.start_url.startsWith('./'))
ok('scope ./', m.scope === './')
ok('display standalone', m.display === 'standalone')
ok('orientation portrait', m.orientation === 'portrait')
ok('background_color hex', /^#[0-9a-fA-F]{6}$/.test(m.background_color || ''))
ok('theme_color hex', /^#[0-9a-fA-F]{6}$/.test(m.theme_color || ''))
ok('lang id', m.lang === 'id')
ok('prefer_related_applications false', m.prefer_related_applications === false)

const icons = m.icons || []
ok('punya minimal 192 & 512', ['192x192', '512x512'].every((s) => icons.some((i) => i.sizes === s)))
ok('punya ikon maskable', icons.filter((i) => (i.purpose || '').includes('maskable')).length >= 2)
ok('semua ikon di manifest benar-benar ada', icons.every((i) => fs.existsSync(path.join(PUB, i.src.replace('./', '')))), icons.map((i) => i.src).join(','))

/* ---------------- file ikon ---------------- */
const wajib = [
  ['icons/icon-192.png', 192],
  ['icons/icon-512.png', 512],
  ['icons/maskable-192.png', 192],
  ['icons/maskable-512.png', 512],
  ['icons/apple-touch-180.png', 180],
  ['icons/favicon-32.png', 32],
]

for (const [rel, size] of wajib) {
  const f = path.join(PUB, rel)
  const info = fs.existsSync(f) ? ukuranPng(f) : null
  ok(`${rel} PNG ${size}×${size}`, !!info && info.w === size && info.h === size, info ? `${info.w}×${info.h}` : 'hilang/bukan PNG')
}

/* ---------------- index.html ---------------- */
const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8')
ok('index.html memasang manifest', /rel="manifest"[^>]*manifest\.webmanifest/.test(html))
ok('apple-touch-icon terpasang', /rel="apple-touch-icon"[^>]*apple-touch-180\.png/.test(html))
ok('theme-color terpasang', /name="theme-color"/.test(html))
ok('apple-mobile-web-app-capable', /apple-mobile-web-app-capable"\s+content="yes"/.test(html))
ok('mobile-web-app-capable', /mobile-web-app-capable"\s+content="yes"/.test(html))
ok('viewport pakai viewport-fit=cover', /viewport-fit=cover/.test(html))
ok('title ada', /<title>.*<\/title>/.test(html))

/* ---------------- sw.js ---------------- */
const sw = fs.readFileSync(path.join(PUB, 'sw.js'), 'utf8')
ok('sw.js punya handler install', sw.includes("addEventListener('install'"))
ok('sw.js punya handler fetch (syarat installable)', sw.includes("addEventListener('fetch'"))
ok('sw.js punya handler activate', sw.includes("addEventListener('activate'"))
ok('sw.js punya placeholder versi build', sw.includes('__BUILD_ID__'))
try {
  new Function(sw) // cek sintaks
  ok('sw.js sintaks valid', true)
} catch (e) {
  ok('sw.js sintaks valid', false, e.message)
}

/* ---------------- registrasi di kode app ---------------- */
const pwaTs = fs.readFileSync(path.join(ROOT, 'src/lib/pwa.ts'), 'utf8')
ok('SW didaftarkan dari app', pwaTs.includes('serviceWorker') && pwaTs.includes('register'))
ok('SW tidak didaftarkan saat dev', /import\.meta\.env\.DEV/.test(pwaTs))
ok('deteksi iOS ada', pwaTs.includes('iPad|iPhone|iPod'))
ok('deteksi standalone ada', pwaTs.includes('display-mode: standalone'))

console.log(`\n${pass} lulus, ${fail} gagal`)
process.exit(fail ? 1 : 0)
