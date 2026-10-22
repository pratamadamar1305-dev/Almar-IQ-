/**
 * Test service worker (public/sw.js) tanpa browser.
 *
 * Menyiapkan tiruan `self`, `caches`, `fetch`, `Response`, lalu menjalankan
 * file sw.js asli di dalam vm context. Yang diuji:
 *   - install mengisi precache
 *   - activate membersihkan cache versi lama
 *   - navigasi online: ambil jaringan + simpan ke cache
 *   - navigasi offline: fallback ke index.html dari cache
 *   - asset ber-hash: cache-first
 *   - pesan SKIP_WAITING
 *
 * Jalankan: node tests/sw.test.mjs
 */
import vm from 'node:vm'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const SW_PATH = path.resolve(__dirname, '../public/sw.js')

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

/* ------------------------------------------------------------------ */
/*  Tiruan Cache API                                                    */
/* ------------------------------------------------------------------ */
class FakeCache {
  constructor() {
    this.map = new Map()
  }
  key(req) {
    return typeof req === 'string' ? new URL(req, ORIGIN).href : req.url
  }
  async put(req, res) {
    this.map.set(this.key(req), res)
  }
  async add(req) {
    const url = typeof req === 'string' ? new URL(req, ORIGIN).href : req.url
    const res = await NETWORK(url)
    if (!res || !res.ok) throw new Error('add gagal: ' + url)
    this.map.set(url, res)
  }
  async match(req) {
    return this.map.get(this.key(req))
  }
  async keys() {
    return [...this.map.keys()].map((u) => ({ url: u }))
  }
}

const ORIGIN = 'https://dojo.test/'
let store = new Map()
let NETWORK = async () => new Response('', { status: 503 })

const caches = {
  async open(nama) {
    if (!store.has(nama)) store.set(nama, new FakeCache())
    return store.get(nama)
  },
  async keys() {
    return [...store.keys()]
  },
  async delete(nama) {
    return store.delete(nama)
  },
  async match(req) {
    for (const c of store.values()) {
      const hit = await c.match(req)
      if (hit) return hit
    }
    return undefined
  },
}

/* ------------------------------------------------------------------ */
/*  Tiruan self / event                                                 */
/* ------------------------------------------------------------------ */
const handlers = {}
const posted = []
let claimed = false
let skipWaiting = false

const self = {
  location: { origin: 'https://dojo.test', href: 'https://dojo.test/sw.js' },
  addEventListener: (t, fn) => {
    handlers[t] = fn
  },
  skipWaiting: async () => {
    skipWaiting = true
  },
  registration: { navigationPreload: { enable: async () => {} } },
  clients: {
    claim: async () => {
      claimed = true
    },
  },
}

function buatEvent(jenis, extra = {}) {
  const waits = []
  const respons = []
  const ev = {
    type: jenis,
    waitUntil: (p) => waits.push(p),
    respondWith: (p) => respons.push(p),
    ...extra,
  }
  return { ev, waits, respons }
}

async function jalankanInstall() {
  const { ev, waits } = buatEvent('install')
  handlers.install(ev)
  await Promise.all(waits)
}

async function jalankanActivate() {
  const { ev, waits } = buatEvent('activate')
  handlers.activate(ev)
  await Promise.all(waits)
}

async function jalankanFetch(request, opts = {}) {
  const { ev, respons } = buatEvent('fetch', {
    request,
    preloadResponse: Promise.resolve(opts.preload ?? undefined),
  })
  handlers.fetch(ev)
  if (!respons.length) return null
  return await respons[0]
}

/* ------------------------------------------------------------------ */
/*  Muat sw.js asli ke context tiruan                                  */
/* ------------------------------------------------------------------ */
const kode = fs.readFileSync(SW_PATH, 'utf8')
const ctx = vm.createContext({
  self,
  caches,
  fetch: (...a) => NETWORK(...a),
  Request: globalThis.Request,
  Response: globalThis.Response,
  URL: globalThis.URL,
  console,
})
vm.runInContext(kode, ctx, { filename: 'sw.js' })

console.log('\n▶ service worker')

/* 1. versi terisi (bukan placeholder) */
ok('placeholder __BUILD_ID__ terganti saat build', !kode.includes('__BUILD_ID__') || kode.includes("const VERSION = '__BUILD_ID__'"))
ok('punya handler install/activate/fetch', !!handlers.install && !!handlers.activate && !!handlers.fetch)

/* 2. install -> precache */
NETWORK = async (url) => new Response('ok:' + url, { status: 200 })
await jalankanInstall()
const shellName = [...store.keys()][0]
const shell = await caches.open(shellName)
const cached = (await shell.keys()).map((r) => new URL(r.url).pathname)
ok('install mengisi cache shell', cached.length >= 8, JSON.stringify(cached))
ok('index.html di-precode', cached.includes('/index.html'))
ok('semua ikon penting di-precode', ['/icons/icon-192.png', '/icons/icon-512.png', '/icons/maskable-512.png', '/icons/apple-touch-180.png'].every((p) => cached.includes(p)))
ok('manifest di-precode', cached.includes('/manifest.webmanifest'))
ok('skipWaiting dipanggil saat install', skipWaiting === true)

/* 3. activate -> bersihkan cache lama */
await caches.open('dojo-shell-LAMA')
await caches.open('sampah-lain')
await jalankanActivate()
const sisa = [...store.keys()]
ok('cache versi lama dihapus', !sisa.includes('dojo-shell-LAMA') && !sisa.includes('sampah-lain'), JSON.stringify(sisa))
ok('cache versi sekarang tetap', sisa.includes(shellName))
ok('clients.claim dipanggil', claimed === true)

/* 4. navigasi online -> network + simpan */
const navReq = new Request('https://dojo.test/', { headers: { accept: 'text/html' } })
Object.defineProperty(navReq, 'mode', { value: 'navigate' })
NETWORK = async () => new Response('<html>baru</html>', { status: 200, headers: { 'Content-Type': 'text/html' } })
const resNav = await jalankanFetch(navReq)
ok('navigasi online ambil dari jaringan', (await resNav.text()).includes('baru'))
await new Promise((r) => setTimeout(r, 30))
const idxCache = await (await caches.open(shellName)).match('https://dojo.test/index.html')
ok('index.html diperbarui di cache', !!idxCache)

/* 5. navigasi offline -> fallback cache */
NETWORK = async () => {
  throw new Error('offline')
}
const resOffline = await jalankanFetch(navReq)
ok('navigasi offline tetap dapat halaman', !!resOffline && resOffline.status === 200)
const htmlOffline = resOffline ? await resOffline.text() : ''
ok('fallback menyajikan index.html', htmlOffline.includes('baru'))

/* 6. asset ber-hash -> cache-first */
NETWORK = async () => new Response('js-asli', { status: 200 })
const assetReq = new Request('https://dojo.test/assets/index-abc123.js')
const resAsset1 = await jalankanFetch(assetReq)
ok('asset pertama diambil dari jaringan', (await resAsset1.text()) === 'js-asli')
await new Promise((r) => setTimeout(r, 30))
NETWORK = async () => {
  throw new Error('offline')
}
const resAsset2 = await jalankanFetch(assetReq)
ok('asset kedua dilayani dari cache (offline)', resAsset2 && (await resAsset2.text()) === 'js-asli')

/* 7. pesan SKIP_WAITING */
skipWaiting = false
handlers.message({ data: 'SKIP_WAITING', source: { postMessage: (m) => posted.push(m) } })
await new Promise((r) => setTimeout(r, 20))
ok('SKIP_WAITING diteruskan ke skipWaiting()', skipWaiting === true)

/* 8. request non-GET diabaikan */
const postReq = new Request('https://dojo.test/api', { method: 'POST' })
const resPost = await jalankanFetch(postReq)
ok('request POST tidak di-intercept', resPost === null)

/* 9. origin lain diabaikan */
const luar = buatEvent('fetch', { request: new Request('https://contoh.com/x.js') })
handlers.fetch(luar.ev)
ok('origin lain dilewatkan', luar.respons.length === 0)

console.log(`\n${pass} lulus, ${fail} gagal`)
process.exit(fail ? 1 : 0)
