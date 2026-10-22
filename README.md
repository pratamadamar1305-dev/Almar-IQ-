# Almar-IQ-

Kumpulan file pribadi + aplikasi latihan harian.

## 📱 DOJO TARUNG (aplikasi)

Aplikasi web mobile-first untuk menjalankan jadwal latihan
`Jadwal-FINAL-Tangan-Kaki-Tarung-Kelas6-TasSekolah (1).md` — silat/tarung di rumah
pakai **sapu kayu + tas sekolah 2–4 kg**.

**Jalanin:**

```bash
cd app
npm install
npm run dev     # http://localhost:3000
```

**Test:** `cd app && npm test` → 342 assertion.

### 📲 Pasang di HP (tanpa Play Store)

Aplikasi ini **PWA** — bisa masuk layar utama Android/iPhone, jalan offline,
tanpa APK dan tanpa upload ke Google Play.

**Android (Chrome):** buka app-nya → menu **⋮** → **Install app** / *Tambahkan ke Layar Utama*
**iPhone (Safari):** tombol **Share** → **Add to Home Screen** → **Add**

Lewat mana buka-nya? Pilih salah satu:

| Cara | Perintah / langkah |
|---|---|
| Lokal (laptop) | `cd app && npm run build && npm run preview` → http://localhost:3000 |
| Online gratis | `Settings → Pages → Source: GitHub Actions` (1 toggle, workflow sudah ada) |
| Vercel | [vercel.com/new](https://vercel.com/new) import repo — `vercel.json` sudah disiapkan |
| Netlify | build `npm run build`, publish `app/dist` |
| HP & laptop satu Wi-Fi | `npm run serve`, buka `http://<IP-laptop>:3000` — *install butuh HTTPS* |

Panduan lengkap: [`app/README.md`](app/README.md)

**Fitur utama**

| Fitur | Detail |
|---|---|
| 🔥 Streak | Hari wajib berturut-turut · rest day tidak memutus · 2 Streak Freeze/bulan · badge milestone 3→365 hari |
| ▶️ Workout Player | Timer per set, rest otomatis, beep 3 detik terakhir, getar, auto-save "Lanjutkan sesi", wake lock |
| 🥁 Timer Gong | Preset resmi 2 ronde × 1:30 + istirahat 1:00 |
| 📊 Progres | Heatmap 9 minggu, target 1 bulan (Pike 8→12, Kuda 30→50 dtk, dll), riwayat sesi |
| 🛡️ Aturan aman | Aturan tarung + keselamatan, gate izin ortu/pelatih |
| 📲 Install | PWA installable, offline, auto-update, shortcut Timer & Progres |

Semua data disimpan lokal di `localStorage` — tanpa backend, bisa offline.

Detail teknis: [`app/README.md`](app/README.md) · prompt pembuatnya: [`PROMPT-Aplikasi-Latihan-Tarung.md`](PROMPT-Aplikasi-Latihan-Tarung.md)

---

## 📄 Isi lain

- `Dds.lua` — script GUI Roblox *Drag Drive Simulator*
- `Dueling.lua` — script auto-parry (DG Hub v44)
- `Jadwal-FINAL-...md` — sumber jadwal latihan
- `PROMPT-Aplikasi-Latihan-Tarung.md` — prompt lengkap untuk generate aplikasinya
