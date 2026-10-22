/**
 * Uji deploy di SUBFOLDER (kasus GitHub Pages: /<repo>/).
 *
 * Ini menangkap kesalahan paling mahal: aplikasi jalan di localhost tapi
 * blank/404 setelah di-deploy ke GitHub Pages karena path absolut.
 *
 * Butuh hasil build (folder dist). Kalau belum ada, test di-skip.
 *
 * Jalankan: npm run build && node tests/subpath.test.mjs
 */
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'

const ROOT = path.resolve('dist')
if (!fs.existsSync(path.join(ROOT, 'index.html'))) {
  console.log('\n▶ simulasi subfolder: SKIP (folder dist belum ada — jalankan npm run build dulu)')
  process.exit(0)
}
const BASE = '/Almar-IQ-/'
const MIME = { '.html':'text/html; charset=utf-8', '.js':'text/javascript', '.css':'text/css',
  '.png':'image/png', '.webmanifest':'application/manifest+json', '.json':'application/json' }

const server = http.createServer((req, res) => {
  let url = decodeURIComponent(new URL(req.url, 'http://x').pathname)
  // GitHub Pages: aplikasi hidup di subfolder /Almar-IQ-/
  if (!url.startsWith(BASE)) { res.writeHead(404); return res.end('404 di luar base') }
  let rel = url.slice(BASE.length - 1)          // '/Almar-IQ-/x' -> '/x'
  if (rel === '/' ) rel = '/index.html'
  const f = path.join(ROOT, rel.replace(/^\//, ''))
  if (fs.existsSync(f) && fs.statSync(f).isFile()) {
    res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' })
    res.end(fs.readFileSync(f))
  } else {
    res.writeHead(404); res.end('404 ' + rel)
  }
})
await new Promise(r => server.listen(4177, '127.0.0.1', r))

const get = (p) => fetch('http://127.0.0.1:4177' + p)

let pass = 0, fail = 0
const ok = (n, c, extra='') => { if (c) { pass++; console.log('  ✓', n) } else { fail++; console.log('  ✗', n, extra) } }

console.log('\n▶ simulasi GitHub Pages (subfolder ' + BASE + ')')

const idx = await get(BASE)
const html = await idx.text()
ok('halaman utama 200', idx.status === 200)

// setiap referensi relatif harus bisa diambil dari subfolder
const refs = [...html.matchAll(/(?:src|href)="(\.\/[^"]+)"/g)].map(m => m[1])
ok('index.html punya referensi relatif', refs.length >= 6, String(refs.length))
for (const r of refs) {
  const url = BASE + r.replace('./', '')
  const res = await get(url)
  ok(`referensi ${r} dapat diakses dari subfolder`, res.status === 200, 'status ' + res.status)
}

// manifest
const man = await (await get(BASE + 'manifest.webmanifest')).json()
ok('manifest 200 & valid', !!man.name)
ok('start_url relatif (aman subfolder)', man.start_url.startsWith('./'), man.start_url)
ok('scope relatif', man.scope === './', man.scope)
for (const ic of man.icons) {
  const res = await get(BASE + ic.src.replace('./', ''))
  ok(`ikon ${ic.src} ada`, res.status === 200)
}

// service worker: precache harus resolve ke subfolder
const sw = await (await get(BASE + 'sw.js')).text()
ok('sw.js 200', sw.length > 500)
ok('sw pakai base absolut dari self.location.href', sw.includes('const BASE = self.location.href'))
ok('sw punya abs() untuk precache', sw.includes('new URL(p, BASE).href'))
ok('semua item precache relatif', !/caches?\.add\(['"]\//.test(sw))
const precache = [...sw.matchAll(/'\.\/([^']+)'/g)].map(m => m[1])
ok('precache punya minimal 6 entri', precache.length >= 6, String(precache.length))
for (const p of ['index.html', 'manifest.webmanifest', 'icons/icon-192.png']) {
  const res = await get(BASE + p)
  ok(`precache target ${p} ada di subfolder`, res.status === 200)
}

// 404 di luar base (perilaku Pages)
const luar = await fetch('http://127.0.0.1:4177/index.html')
ok('halaman di root tidak tersedia (sesuai Pages subfolder)', luar.status === 404)

server.close()
console.log(`\n${pass} lulus, ${fail} gagal`)
process.exit(fail ? 1 : 0)
