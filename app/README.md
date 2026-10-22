# DOJO TARUNG 🔥

Aplikasi latihan harian mobile-first untuk anak kelas 6 SD (BB 33 kg) yang latihan
silat/tarung di rumah cuma pakai **sapu kayu + tas sekolah 2–4 kg**.

Dibangun dari file `Jadwal-FINAL-Tangan-Kaki-Tarung-Kelas6-TasSekolah (1).md`.
Sudah berbentuk **PWA** — bisa dipasang ke layar utama Android/iPhone, tanpa Play Store,
tanpa APK, dan jalan **offline**.

## Jalanin

```bash
cd app
npm install
npm run dev      # http://localhost:3000
```

> Di mode dev, service worker sengaja tidak didaftarkan supaya hot-reload tidak kacau.
> Untuk mencoba fitur install/offline, pakai build produksi:

```bash
npm run build
npm run preview  # http://localhost:3000 (SW aktif)
# atau
npm run serve    # server statis sederhana dari folder dist
```

Test:

```bash
npm test         # 342 assertion (logika, data, UI, service worker, aset PWA)
```

## 📲 Cara pasang ke layar HP (tanpa Play Store)

1. Buka aplikasinya di **Chrome (Android)** atau **Safari (iPhone)** lewat `https://`.
2. **Android:** tap menu **⋮** → **Install app** / **Tambahkan ke Layar Utama**.
   Kalau banner install muncul di bawah, bisa langsung tap itu.
3. **iPhone:** tap **Share** → **Add to Home Screen** → **Add**.
4. Ikon api muncul di layar utama. Dibuka dari situ → tampil **full-screen**
   tanpa address bar, persis aplikasi native.

Panduan visual lengkap ada **di dalam aplikasi**: `Setting → Aplikasi → Install`
(atau `#/install`).

### Syarat supaya tombol install muncul

| Syarat | Status di project ini |
|---|---|
| Disajikan lewat **HTTPS** (atau `localhost`) | ✅ wajib dipenuhi hosting |
| `manifest.webmanifest` valid + `display: standalone` | ✅ sudah |
| Ikon 192×192 & 512×512 (+ maskable) | ✅ sudah |
| Service worker dengan handler `fetch` | ✅ sudah (`public/sw.js`) |
| Dikunjungi 2× / ada interaksi | ⏳ tergantung browser |

Kalau tombol belum muncul, tetap bisa pakai cara manual di atas — hasilnya sama.

## Deploy (pilih salah satu)

> **Kenyataan hari ini:** dua jalur di bawah butuh 1 klik dari pemilik repo,
> karena koneksi GitHub/Vercel yang dipakai agent nggak punya izin
> `pages: write`. Aplikasinya sendiri sudah siap dan sudah lolos test.

**A. GitHub Pages — 1 toggle**
1. Buka `Settings → Pages` di repo.
2. Bagian **Source**, pilih **GitHub Actions**.
3. Selanjutnya tiap push ke `main`, workflow `deploy-pwa.yml` otomatis
   build + test + deploy. URL: `https://<user>.github.io/<repo>/`
   (base path sudah relatif, jadi aman di subfolder).

**B. Vercel — 1 klik import**
1. Buka [vercel.com/new](https://vercel.com/new) → import repo ini.
2. Nggak perlu setting apa pun — `vercel.json` di root sudah mengatur
   install/build/output (root `app/`, output `app/dist`).
3. Dapat URL `https://<project>.vercel.app` + HTTPS otomatis (syarat install terpenuhi).

**C. Netlify / Cloudflare Pages**
Build command `npm run build`, publish directory `app/dist`.
`public/_headers` & `public/_redirects` ikut ter-copy ke `dist`.

**D. Lokal**
```bash
npm run build && npm run preview   # http://localhost:3000
```
Catatan: install PWA **butuh HTTPS atau localhost**. Kalau mau tes di HP lewat
Wi-Fi (`http://<IP-laptop>:3000`), tombol install nggak akan muncul —
pakai `ngrok http 3000` / `cloudflared` atau hosting di atas.

## Fitur

- **Streak** — hari wajib berturut-turut; rest day tidak memutus; Streak Freeze 2×/bulan
- **Workout Player** — timer per set, rest otomatis, beep 3 detik terakhir, getar,
  auto-save (bisa "Lanjutkan sesi"), screen wake lock
- **Timer Gong Tarung** — preset 2 ronde × 1:30 + istirahat 1:00
- **Progres** — heatmap 9 minggu, target 1 bulan, badge milestone, riwayat sesi
- **Aturan aman** & peraturan tarung
- **PWA** — installable, offline-first, auto-update (banner "Versi baru tersedia")

## Struktur

```
src/
  lib/        types · data latihan · streak · audio · pwa · izin · util · navigasi
  screens/    Home · Detail · Player · TimerGong · Progress · Settings · Aturan · Install
  components/ Icon · ui (Modal, Btn, Confetti, ProgressRing, Toast…)
  store.tsx   state global + persist localStorage
public/
  sw.js                    service worker (cache-first asset, network-first HTML)
  manifest.webmanifest     metadata install
  icons/                   ikon 192/512 + maskable + apple-touch
tools/make-icons.py        generator ikon (pillow)
tests/                     streak · data · smoke UI (jsdom) · service worker · aset PWA
```

## Catatan

- Data latihan ada di `src/lib/data.ts` — 38 gerakan dengan `cara` & `salah`.
- Semua data pengguna di `localStorage` (`dojo-tarung-v1`), tidak dikirim ke mana pun.
- Ganti ikon: edit `tools/make-icons.py` lalu jalankan dengan Python + pillow,
  atau timpa langsung file di `public/icons/`.
