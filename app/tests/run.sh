#!/usr/bin/env bash
# Jalankan semua test: logika, data, UI (jsdom), service worker, dan aset PWA.
set -e
cd "$(dirname "$0")/.."
mkdir -p tests/.out

echo "▶ test streak (logika)"
npx esbuild tests/streak.test.ts --bundle --platform=node --format=esm \
  --outfile=tests/.out/streak.mjs --log-level=error
node tests/.out/streak.mjs

echo "▶ test data latihan"
npx esbuild tests/data.test.ts --bundle --platform=node --format=esm \
  --outfile=tests/.out/data.mjs --log-level=error
node tests/.out/data.mjs

echo "▶ smoke test UI (jsdom)"
npx esbuild tests/smoke.test.tsx --bundle --platform=node --format=esm \
  --outfile=tests/.out/smoke.mjs --external:jsdom --jsx=automatic --log-level=error
node tests/.out/smoke.mjs

echo "▶ test ilustrasi gerakan (stick-man)"
node tests/fig.test.mjs

echo "▶ test service worker (offline/cache)"
node tests/sw.test.mjs

echo "▶ test aset PWA (manifest + ikon)"
node tests/pwa-assets.test.mjs

echo "▶ test deploy subfolder (GitHub Pages)"
node tests/subpath.test.mjs

echo "✅ semua test lulus"
