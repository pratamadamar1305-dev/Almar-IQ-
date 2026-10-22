import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'

const BUILD_ID = Date.now().toString(36)

/**
 * Ganti placeholder __BUILD_ID__ di sw.js hasil build.
 * Tujuannya: tiap deploy dapat nama cache baru → service worker lama
 * otomatis dibersihkan, tapi pengguna lama tetap dapat versi baru.
 */
function serviceWorkerVersion(): Plugin {
  return {
    name: 'sw-version',
    apply: 'build',
    closeBundle() {
      const p = resolve(__dirname, 'dist/sw.js')
      if (!existsSync(p)) return
      writeFileSync(p, readFileSync(p, 'utf8').replace(/__BUILD_ID__/g, BUILD_ID))
    },
  }
}

export default defineConfig({
  // base relatif -> aman ditaruh di subfolder / GitHub Pages / hosting apa pun
  base: './',
  plugins: [react(), serviceWorkerVersion()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    allowedHosts: true,
  },
  preview: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    allowedHosts: true,
  },
})
