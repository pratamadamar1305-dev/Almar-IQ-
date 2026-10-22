/* Service worker DOJO TARUNG
 * Strategi:
 *  - asset ber-hash (/assets/*)  → cache-first (immutable)
 *  - navigasi & HTML            → network-first, fallback ke cache (offline)
 *  - ikon/manifest              → stale-while-revalidate
 * Versi dinaikkan otomatis oleh proses build (__BUILD_ID__).
 */
const VERSION = '__BUILD_ID__'
const SHELL = `dojo-shell-${VERSION}`
const RUNTIME = `dojo-runtime-${VERSION}`

// Basis absolut: jangan andalkan resolusi URL relatif di Cache API,
// karena perilakunya beda-beda antar browser.
const BASE = self.location.href
const abs = (p) => new URL(p, BASE).href
const INDEX_URL = abs('./index.html')

const PRECACHE = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/maskable-192.png',
  './icons/maskable-512.png',
  './icons/apple-touch-180.png',
  './icons/favicon-32.png',
]

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL)
      // satu per satu supaya satu file gagal tidak menggagalkan semuanya
      await Promise.all(
        PRECACHE.map((url) =>
          cache.add(new Request(abs(url), { cache: 'reload' })).catch(() => {})
        )
      )
      await self.skipWaiting()
    })()
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys()
      await Promise.all(
        keys
          .filter((k) => k !== SHELL && k !== RUNTIME)
          .map((k) => caches.delete(k))
      )
      if (self.registration.navigationPreload) {
        await self.registration.navigationPreload.enable()
      }
      await self.clients.claim()
    })()
  )
})

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting()
  if (event.data === 'GET_VERSION') {
    event.source?.postMessage({ type: 'VERSION', version: VERSION })
  }
})

const isAsset = (url) => /\/assets\/.*\.(js|css|woff2?|png|svg|webp)$/.test(url.pathname)
const isIcon = (url) => url.pathname.includes('/icons/') || url.pathname.endsWith('manifest.webmanifest')

self.addEventListener('fetch', (event) => {
  const req = event.request
  if (req.method !== 'GET') return

  const url = new URL(req.url)
  if (url.origin !== self.location.origin) return

  // HTML / navigasi → network-first, fallback cache
  if (req.mode === 'navigate' || req.destination === 'document') {
    event.respondWith(
      (async () => {
        try {
          const preload = await event.preloadResponse
          if (preload) {
            const cache = await caches.open(SHELL)
            cache.put(INDEX_URL, preload.clone()).catch(() => {})
            return preload
          }
          const fresh = await fetch(req)
          if (fresh && fresh.ok) {
            const cache = await caches.open(SHELL)
            cache.put(INDEX_URL, fresh.clone()).catch(() => {})
          }
          return fresh
        } catch {
          const cache = await caches.open(SHELL)
          return (
            (await cache.match(INDEX_URL)) ||
            (await cache.match(abs('./'))) ||
            new Response(
              '<h1>DOJO TARUNG</h1><p>Butuh internet sekali lagi untuk membuka halaman ini.</p>',
              { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
            )
          )
        }
      })()
    )
    return
  }

  // asset ber-hash → cache-first
  if (isAsset(url)) {
    event.respondWith(
      (async () => {
        const cache = await caches.open(SHELL)
        const hit = await cache.match(req)
        if (hit) return hit
        try {
          const res = await fetch(req)
          if (res && res.ok) cache.put(req, res.clone()).catch(() => {})
          return res
        } catch {
          const empty = await caches.match(req)
          return (
            empty ||
            new Response('', { status: 504, statusText: 'Offline' })
          )
        }
      })()
    )
    return
  }

  // ikon / manifest → stale-while-revalidate
  if (isIcon(url)) {
    event.respondWith(
      (async () => {
        const cache = await caches.open(SHELL)
        const hit = await cache.match(req)
        const network = fetch(req)
          .then((res) => {
            if (res && res.ok) cache.put(req, res.clone()).catch(() => {})
            return res
          })
          .catch(() => null)
        return hit || (await network) || new Response('', { status: 504 })
      })()
    )
  }
})
