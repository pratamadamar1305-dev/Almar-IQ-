# PROMPT — Bikin Aplikasi "DOJO TARUNG" dari File MD Jadwal Latihan

> ✅ **SUDAH DIBANGUN.** Aplikasi hasil prompt ini ada di folder **`app/`** (React + Vite + TypeScript).
> Jalankan: `cd app && npm install && npm run dev` → http://localhost:3000
> Test: `npm test` (streak, data latihan, dan smoke test UI).

> **Cara pakai:** copy semua isi mulai dari garis `===== START PROMPT =====` sampai `===== END PROMPT =====`, lalu tempel ke AI app builder (Lovable, v0, Bolt, Cursor, Claude Code, Replit Agent, dll).
> Sumber data: `Jadwal-FINAL-Tangan-Kaki-Tarung-Kelas6-TasSekolah (1).md`

---

## ===== START PROMPT =====

Kamu adalah senior full-stack developer + product designer. Buatkan satu aplikasi web **mobile-first, offline-first, PWA-ready** bernama **"DOJO TARUNG"** — asisten latihan harian untuk anak kelas 6 SD (BB 33 kg) yang latihan silat/tarung di rumah pakai alat seadanya: **sapu kayu + tas sekolah 2–4 kg**.

Aplikasi ini BUKAN sekadar viewer markdown. Ini harus **interaktif**: user menjalankan sesi latihan gerakan per gerakan, timer jalan sendiri, progresnya kecatat, dan ada **fitur STREAK** sebagai motivasi utama biar anak mau latihan tiap hari latihan.

Bahasa UI: **Indonesia, santai, singkat, ramah anak**. Gaya bahasa: "ayo", "gas", "keren", bukan bahasa formal korporat. Hindari kata menakutkan.

---

### 1. STACK & BATASAN TEKNIS

- **React 18 + Vite + TypeScript + CSS custom** (implementasi di `app/`). Kalau pakai Next.js, boleh — logikanya sama.
- **Tanpa backend, tanpa login, tanpa database server.** Semua data disimpan di `localStorage` (key: `dojo-tarung-v1`). Harus tetap jalan tanpa internet setelah load pertama.
- **Zero dependency berat**: cukup `date-fns` atau util tanggal buatan sendiri, `lucide-react` untuk ikon, `framer-motion` (opsional) untuk animasi.
- **Mobile-first**: target layar 360–430 px. Semua tombol minimal **48×48 px** (jari anak), font body minimal **16 px**.
- **Tanpa iklan, tanpa tracking, tanpa link keluar.**
- **Aksesibilitas**: kontras memadai, `aria-label` pada tombol ikon, dukung `prefers-reduced-motion`.
- **Struktur folder** yang rapi (hash router, tanpa dependency router tambahan):
  ```
  src/
    App.tsx                  → routing #/ , #/hari/:day , #/player ,
                               #/timer , #/progres , #/setting , #/aturan
    lib/    data.ts · streak.ts · storage(store) · audio.ts · utils.ts · nav.ts
    screens/Home · Detail · Player · TimerGong · Progress · Settings · Aturan
    components/ Icon.tsx · ui.tsx
  ```
- Kalau repo ini dipakai, taruh aplikasi di folder **`app/`** supaya file `.md` dan `.lua` tidak terganggu.

---

### 2. DATA LATIHAN (SUMBER KEBENARAN — JANGAN DIUBAH ANGKANYA)

Semua data ini harus masuk ke `lib/workout-data.ts` sebagai objek terstruktur.

#### HARI 1 — SENIN | "Tangan Dorong + Kaki Power + Tarung Pukulan" | 50 menit
Fokus: Bahu depan, dada, triceps, ujung jari + paha meledak.
| # | Nama | Set × Rep | Tipe | Alat |
|---|---|---|---|---|
| 1 | Pike Push-Up | 3×8 | rep | bodyweight |
| 2 | Tas Sekolah Overhead Press | 3×10 | rep | tas |
| 3 | Sapu Front Raise | 3×12 | rep | sapu |
| 4 | Diamond Push-Up (boleh lutut nempel lantai) | 3×10 | rep | bodyweight |
| 5 | Sapu Wrist Twist | 3×15 | rep | sapu |
| 6 | Finger Push-Up Dinding | 3×8 | rep | bodyweight |
| 7 | Tas Sekolah Goblet Squat | 3×12 | rep | tas |
| 8 | Jump Squat | 3×8 | rep | bodyweight |
| 9 | Kuda-Kuda Tengah Hold | 3×30–40 detik | hold | bodyweight |
| 10 | Drill Tarung Senin — Pukulan Bersih | 5 menit | drill | sapu |

#### HARI 2 — SELASA (OPSIONAL) | "Bikin Jari Jadi Senjata" | 35 menit
Fokus: Punggung, biceps, forearm, grip + keseimbangan.
| # | Nama | Set × Rep | Tipe | Alat |
|---|---|---|---|---|
| 1 | Tas Sekolah Row Bungkuk | 3×10 | rep | tas + kursi |
| 2 | Tas Sekolah Curl | 3×12 | rep | tas |
| 3 | Sapu Reverse Curl | 3×12 | rep | sapu |
| 4 | Sapu Lever Hold | 3×10 detik/sisi | hold | sapu |
| 5 | Tas Sekolah Farmer Walk | 3×30 langkah | rep | tas |
| 6 | Sapu Finger Roll | 3×12 | rep | sapu |
| 7 | Tas Sekolah Bulgarian Split Squat | 3×8/kaki | rep | tas + kursi |
| 8 | Sapu Balance + Tangkisan | 8 menit (balance 20 dtk/kaki + tangkisan 10× kanan-kiri) | drill | sapu |

#### HARI 3 — KAMIS | "Tangan Komplit + Kaki Speed + Tarung Tendangan" | 50 menit
Fokus: Bahu belakang, lengan full + tendangan cepat.
| # | Nama | Set × Rep | Tipe | Alat |
|---|---|---|---|---|
| 1 | Sapu Reverse Fly | 3×12 | rep | sapu |
| 2 | Tas Sekolah Floor Press | 3×10 | rep | tas |
| 3 | Sapu Shoulder Pass | 3×8 | rep | sapu |
| 4 | Tas Sekolah Overhead Extension | 3×10 | rep | tas |
| 5 | Sapu Putar Tangkisan | 3×10/sisi | rep | sapu |
| 6 | Tas Sekolah Pinch Grip | 3×15 detik | hold | tas |
| 7 | Plank Ujung Jari | 3×20 detik | hold | bodyweight |
| 8 | Tendangan Bayangan + Lunge Jalan | 4×8/kaki | rep | tas |
| 9 | Sapu Hurdle Jump | 3×8 | rep | sapu |
| 10 | Drill Tarung Kamis — Tendangan Poin | 5 menit | drill | tas + pintu |

#### HARI 4 — JUMAT | "Hari Juara — Simulasi Lomba Beneran" | 45 menit
**Blok A — Ronde Gabungan (ulang 3×, istirahat 60 detik antar ronde):**
1. Pike Push-Up ×8
2. Tas Sekolah Squat ×10
3. Tas Sekolah Row ×10
4. Jump Lunge ×6/kaki
5. Sapu Wrist Twist ×15
6. Kuda Tengah Hold 30 detik
7. Finger Push-Up Dinding ×8
8. Tendangan Depan ×6/kaki

**Blok B — Simulasi Tarung (pakai Timer Gong):**
- Ronde 1 → 1,5 menit nonstop: 2 pukulan – 1 tendangan – 1 tangkisan bayangan – balik pasang, ulang.
- Istirahat 1 menit (duduk).
- Ronde 2 → 1,5 menit: pukulan + tendangan + tangkap kaki + 20 detik kuda hold di akhir.
- Finisher: Sapu pass 1 menit + calf stretch.

**Setiap gerakan WAJIB punya 2 field teks:** `cara` (instruksi langkah) dan `salah` (kesalahan umum). Ambil dari file MD apa adanya (sudah bagus bahasanya). Contoh format:
```ts
{
  id: "pike-pushup",
  nama: "Pike Push-Up",
  sets: 3, reps: 8, tipe: "rep",
  alat: "bodyweight",
  targetArea: "Bahu Depan",
  detikPerRep: 3,
  cara: "Posisi huruf V terbalik, pantat di atas, tangan & kaki lurus, tangan selebar bahu. Tekuk siku pelan turunin kepala hampir ke lantai, dorong naik. Buang napas pas dorong.",
  salah: "Pinggang melengkung / siku lebar ke samping. Harus siku 45° ke belakang. Kalau berat tekuk kaki dikit gapapa."
}
```

---

### 3. HALAMAN & FITUR

#### A. HOME — "Hari Ini Latihan Apa?"
1. **Kartu streak raksasa di paling atas** (lihat §4): api 🔥 + angka besar + label "hari beruntun".
2. **Kartu sesi hari ini**:
   - Senin/Kamis/Jumat → tombol besar **"MULAI LATIHAN"**.
   - Selasa → badge **"OPSIONAL"** warna beda + tombol "Latihan Bonus".
   - Rabu/Sabtu/Minggu → kartu **"HARI LIBUR"** dengan pesan santai ("Istirahat juga bagian dari latihan. Besok kita gas lagi 💪") + tombol "Lihat jadwal".
3. **Progress minggu ini**: 3–4 lingkaran (Sen/Kam/Jum[/Sel]) berisi centang atau kosong.
4. **Tombol cepat**: "Timer Gong Tarung", "Progres", "Aturan Aman".
5. **Banner kecil yang bisa ditutup**: "Minta izin ortu/pelatih dulu sebelum latihan ya!"

#### B. DETAIL SESI
- Header: nama hari, tema, estimasi durasi, jumlah gerakan, tombol **MULAI**.
- Daftar gerakan sebagai accordion. Tiap baris: nomor, nama, set×rep, area target, ikon alat. Kalau dibuka → tampil `cara` + `salah` (kotak merah "Jangan gini"), plus tombol "Ganti ke mode latihan".
- Checklist: user bisa centang gerakan manual.

#### C. WORKOUT PLAYER (JANTUNG APLIKASI)
Full-screen, satu gerakan per layar, **tidak boleh scroll jauh**:
1. **Progress bar** di atas (`Gerakan 3 dari 10`).
2. **Nama gerakan besar** + area target + ikon alat.
3. **Kotak set**: `Set 1 dari 3` — tap tombol besar **"SET SELESAI"** per set. Set yang sudah selesai jadi centang hijau.
4. **Timer**:
   - Tipe `rep` → estimasi otomatis `reps × detikPerRep` (default 3 dtk/rep), timer countdown berjalan, tombol pause/reset. Ada juga mode **"Hitung Manual"** (counter tap +1 per rep).
   - Tipe `hold` → countdown durasi (`30–40 dtk`) dengan bunyi di 3 detik terakhir.
   - Tipe `drill` → countdown sesuai durasi blok (misal 5 menit).
5. **Rest timer otomatis** setelah tiap set (default 45 dtk, bisa diubah 30/45/60/90): overlay besar dengan angka, tombol "+15 dtk" dan "Lewati".
6. Tombol: `Sebelumnya` · `Pause` · `Lewati` · `Selesai Sesi`.
7. **Instruksi "Cara" bisa di-expand** tanpa keluar dari player.
8. **Suara & getar**: beep 3 detik terakhir, getar saat ganti set (`navigator.vibrate`), pakai Web Audio API (tanpa file audio eksternal). Ada toggle on/off.
9. **Screen Wake Lock** saat player aktif supaya layar tidak mati.
10. **Simpan otomatis**: kalau user keluar di tengah sesi, tawarkan "Lanjutkan sesi tadi".
11. Di akhir: layar **SELESAI** dengan confetti, ringkasan (durasi, total set, total rep), update streak, dan tombol share teks hasil (pakai `navigator.share` kalau ada).

#### D. TIMER GONG TARUNG (standalone)
- Preset: **2 ronde × 1:30, istirahat 1:00** (sesuai peraturan tarung umur 6 SD).
- Bisa custom: jumlah ronde, durasi ronde, durasi istirahat.
- Suara gong di awal & akhir ronde (Web Audio API, synthesizer, tanpa file).
- Countdown besar, lingkar progress, warna beda per fase (ronde = merah, istirahat = hijau).
- Hitung mundur 3-2-1 sebelum mulai.
- Sisa waktu tetap akurat walau tab di-background (pakai `Date.now()` sebagai basis, bukan `setInterval` murni).

#### E. PROGRES
1. **Kartu streak** (angka sekarang, rekor terbaik, kalender heatmap 8 minggu ke belakang).
2. **Grafik progres 4 minggu** untuk 4 metrik target:
   - Pike Push-Up: target 8 → 12 rep
   - Kuda-Kuda Hold: 30 → 50 detik
   - Finger Push-Up Dinding: 8 → 12 rep
   - Tendangan: "tidak oleng" (skala 1–5, input manual)
3. **Log sesi**: daftar sesi yang sudah selesai (tanggal, hari, durasi, gerakan selesai X/Y).
4. **Badge/lencana** yang terbuka.

#### F. ATURAN AMAN (statis, dari MD)
- Tas sekolah **max 4 kg**, isi 1–2 buku tebal + botol air, ganjal handuk.
- Sapu tidak retak/licin, lantai tidak licin.
- Minum tiap 15 menit, tidur 8–9 jam.
- **Nyeri tajam di sendi → STOP 2 hari.**
- Sebelum simulasi Jumat, lapor ortu/pelatih.
- Peraturan tarung (poin body 1, tendangan body 2, bantingan 3, tangkis+balas bonus 1; DILARANG pukul kepala/leher/kemaluan, siku, dengkul).
- Tampilkan juga sebagai modal konfirmasi **"Aku udah izin ortu/pelatih"** sebelum sesi pertama hari itu dimulai (bisa dimatikan di Setting).

#### G. SETTING
- Nama panggilan.
- Mode jadwal: **3 hari (Sen/Kam/Jum)** atau **4 hari (+Selasa)**.
- Durasi istirahat default: 30/45/60/90 detik.
- Suara: on/off. Getar: on/off.
- Pengingat harian (jam) — pakai Notification API kalau diizinkan, kalau tidak tampilkan info saja.
- Reset data (dengan konfirmasi 2 langkah).

---

### 4. FITUR STREAK — SPESIFIKASI KETAT (INI FITUR UTAMA)

#### 4.1 Definisi
**Streak = jumlah hari latihan WAJIB yang diselesaikan berturut-turut tanpa bolong.**
Bukan "jumlah hari kalender berturut-turut". Hari libur tidak memutus streak.

#### 4.2 Aturan penentuan hari
- Mode **3 hari** (default): wajib = **Senin, Kamis, Jumat**. Opsional = Selasa.
- Mode **4 hari**: wajib = **Senin, Selasa, Kamis, Jumat**.
- **Rabu, Sabtu, Minggu = REST DAY.** Tidak menambah, **tidak memutus**.
- Hari opsional yang **tidak** dikerjakan → **tidak memutus** streak.
- Hari opsional yang dikerjakan → tetap menambah **+1 hari ke streak**? **TIDAK.** Cukup beri **+1 "Bonus Flame"** (total bonus terpisah), supaya adil. Bonus flame ditampilkan sebagai badge kecil di kartu streak.

#### 4.3 Kapan sesi dianggap "SELESAI"
Sesi valid jika **keduanya** benar:
1. User menekan **"Selesaikan Sesi"**, dan
2. Minimal **80% gerakan inti** (blok utama hari itu) sudah ditandai selesai — untuk Jumat, dihitung dari Blok A (8 gerakan) + Blok B (2 ronde simulasi) = 10 item.

Kalau kurang dari 80%, tampilkan dialog:
> "Baru 5 dari 10 gerakan. Kalau berhenti sekarang, sesi ini dicatat sebagai *sesi ringan* dan **tidak dihitung untuk streak**. Lanjut atau tetap selesai?"

#### 4.4 Pseudocode evaluasi streak (WAJIB diimplementasikan persis)

```ts
type DayStatus = "selesai" | "terlewat" | "libur" | "belum";

function isWajib(date: Date, mode: 3 | 4): boolean {
  const d = date.getDay(); // 0=Min, 1=Sen, 2=Sel, 3=Rab, 4=Kam, 5=Jum, 6=Sab
  if (mode === 3) return d === 1 || d === 4 || d === 5;
  return d === 1 || d === 2 || d === 4 || d === 5;
}

function hitungStreak(logs: SessionLog[], mode: 3 | 4, today: Date) {
  // logs: { tanggal: "YYYY-MM-DD", hari: "senin"|..., selesai: boolean, valid: boolean }
  let streak = 0;
  let cursor = startOfDay(today);

  // Kalau hari ini hari wajib dan BELUM selesai, jangan langsung reset.
  // Mulai hitung dari hari wajib terakhir sebelum hari ini.
  if (isWajib(cursor, mode) && !adaLogValid(cursor)) {
    cursor = hariSebelumnya(cursor);
    // beri status "harus diselesaikan hari ini" → tampilkan CTA mendesak
  }

  while (true) {
    if (isWajib(cursor, mode)) {
      if (adaLogValid(cursor)) {
        streak++;
      } else if (adaStreakFreeze(cursor)) {
        streak++; // hari dibekukan, streak tetap jalan
      } else {
        break; // bolong → streak berhenti
      }
    }
    // rest day & hari opsional: lewati tanpa menambah/memutus
    cursor = hariSebelumnya(cursor);

    // pengaman: maksimal 5 tahun ke belakang
    if (selisihHari(today, cursor) > 1825) break;
  }
  return streak;
}
```

#### 4.5 Streak Freeze (pengaman)
- User dapat **2 token freeze per bulan kalender**.
- Dipakai untuk 1 hari wajib yang terlewat (misal sakit/ada acara).
- Cara pakai: di Profil/Progres, tap hari yang terlewat (maksimal 7 hari ke belakang) → **"Pakai Streak Freeze"**. Token berkurang, hari itu dianggap aman dan streak tidak putus.
- Tampilkan sisa token di kartu streak: 🧊 ×2.

#### 4.6 Reset & pemulihan
- Kalau hari wajib terlewat dan tidak ada freeze → streak **reset ke 0**, tapi:
  - Simpan `streakTerbaik` (rekor sepanjang masa, tidak pernah turun).
  - Tampilkan layar **"Streak putus 💔"** yang SUPPORTIF, bukan menghakimi:
    > "Nggak apa-apa, semua atlet pernah bolong. Rekor lu 12 hari — ayo mulai lagi dari 1. 💪"
  - Beri tombol besar **"Mulai Lagi"**.
- **Jangan pernah pakai kata "gagal", "malas", "dosa".**

#### 4.7 Tampilan streak
1. **Kartu utama** (di Home, posisi teratas):
   - Angka besar (font 64 px) + ikon api animasi (pulse halus, matikan kalau `prefers-reduced-motion`).
   - Label: `🔥 5 hari beruntun` / `Belum mulai — ayo nyalakan api!`
   - Sub-info: `Rekor: 12 hari` · `🧊 2` · `⚡ 3 bonus`.
2. **Skala api**: 0 = abu-abu, 1–2 = kuning, 3–6 = oranye, 7–13 = merah, 14–29 = merah menyala + glow, 30+ = ungu/legenda.
3. **Heatmap kalender** 8 minggu (kolom = minggu, baris = Sen–Min):
   - 🟩 selesai · 🟨 sesi ringan · 🟦 libur/opsional · ⬜ belum · 🧊 freeze · 🟥 terlewat.
4. **Milestone badge** (auto terbuka saat streak mencapai): 3 → "Pemula Api", 7 → "Seminggu Nyala", 14 → "Dua Minggu", 21 → "Kebiasaan Baru", 30 → "Sebulan Penuh", 50 → "Baja", 100 → "Legenda Dojo". Saat terbuka → modal + confetti + suara.
5. **Animasi kenaikan**: saat sesi selesai, angka streak "naik" dengan animasi count-up + percikan api.

#### 4.8 Edge case yang WAJIB ditangani
- Sesi diselesaikan **dua kali di hari yang sama** → streak tetap dihitung **1**.
- User mengerjakan sesi **kemarin** hari ini (backfill) → boleh dicatat, tapi **tidak menambah streak hari ini**; hanya memperbaiki riwayat (maksimal 3 hari ke belakang).
- Ganti zona waktu /device date berubah → selalu hitung pakai **tanggal lokal device** (`YYYY-MM-DD` dari `new Date()`), jangan simpan timestamp UTC untuk penentuan hari.
- Data `localStorage` korup → fallback ke state kosong tanpa crash.
- Mode jadwal diganti (3 ↔ 4 hari) → hitung ulang streak dari log historis; jangan hapus log.
- Sesi dimulai 23:55 dan selesai 00:05 → dihitung **tanggal selesai**.

---

### 5. GAMIFIKASI PENDUKUNG
- **XP**: 10 XP per set selesai, +50 XP per sesi valid, +100 XP bonus Selasa, +200 XP milestone streak.
- **Level**: `level = Math.floor(XP / 500) + 1`, judul: 1 Pemula, 2 Rajin, 3 Kuat, 4 Petarung, 5 Jagoan, 6+ Legenda.
- XP bar di Home, level-up modal.
- **Confetti** saat sesi selesai & milestone (canvas/CSS, tanpa library berat).

---

### 6. DESAIN VISUAL
- Tema **dark mode default** (nyaman malam), opsi light.
- Palet: latar `#0B0E14`, kartu `#151A23`, aksen utama **oranye-api `#FF6B1A`**, sekunder **kuning `#FFC542`**, sukses `#22C55E`, bahaya `#EF4444`.
- Font: **Inter / Plus Jakarta Sans** untuk UI, angka timer pakai **tabular-nums** besar.
- Sudut membulat 20px, shadow lembut, garis tipis `#1F2632`.
- Ikon garis (lucide): `flame`, `snowflake`, `zap`, `timer`, `trophy`, `shield`, `dumbbell`, `footprints`.
- Nuansa "dojo": aksen garis diagonal halus di header, tapi tetap bersih, bukan norak.
- Semua state kosong harus punya ilustrasi/emoji + CTA ("Belum ada sesi. Ayo mulai latihan pertama!").

---

### 7. ACCEPTANCE CRITERIA (harus lulus semua)
1. Buka di HP 375 px, semua tombol nyaman ditekan, tidak ada horizontal scroll.
2. Bisa menyelesaikan sesi Senin dari awal sampai akhir tanpa reload; timer, rest timer, dan suara jalan.
3. Setelah sesi selesai valid → **streak naik 1** dan tersimpan setelah refresh & tutup browser.
4. Menyelesaikan sesi di hari libur / hari opsional → **streak tidak berubah** (tidak naik), tapi tetap tercatat di log.
5. Melewatkan hari wajib (simulasi dengan mengubah tanggal device) → streak reset, `streakTerbaik` tetap, muncul layar supportif.
6. Streak Freeze bisa dipakai dan token berkurang serta tersimpan.
7. Timer Gong Tarung preset 2×1:30 + rest 1:00 akurat (drift < 1 detik), berbunyi di tiap transisi.
8. Refresh di tengah sesi → ditawari "Lanjutkan sesi".
9. Semua data tetap ada saat offline.
10. Tidak ada error di console; TypeScript strict lolos build.

---

### 8. URUTAN PENGERJAAN YANG DIMINTA
1. Buat `lib/workout-data.ts` berisi **seluruh** data latihan §2 (10 + 8 + 10 + 10 item) lengkap dengan `cara` & `salah`.
2. Buat `lib/storage.ts` (load/save state, migrasi versi, guard korup).
3. Buat `lib/streak.ts` (implementasi persis §4.4 + freeze + edge case).
4. Bangun komponen UI dasar (kartu, tombol, modal, progress ring).
5. Bangun Home → Detail → Player → Timer Gong → Progres → Setting.
6. Terakhir: polish animasi, suara, confetti, empty state.

Tampilkan hasil sebagai **kode lengkap yang bisa langsung dijalankan** (`npm install && npm run dev`), bukan potongan snippet. Sertakan juga `README.md` singkat berisi cara jalanin dan cara pakai.

===== END PROMPT =====

---

## Catatan untuk kamu (bukan bagian prompt)

- **Kalau builder-nya punya batas panjang prompt** (Lovable/v0 kadang pendek), pakai versi ringkas di bawah ini saja.
- Kalau mau, prompt ini juga bisa langsung aku pakai untuk **membangun aplikasinya di repo ini**.

### Versi ringkas (kalau prompt kepanjangan)

> Buat aplikasi web PWA mobile-first bernama **"DOJO TARUNG"** (Next.js + TypeScript + Tailwind, data di localStorage, tanpa backend) untuk anak kelas 6 SD yang latihan tarung di rumah pakai sapu kayu + tas sekolah 2–4 kg. Isinya: 4 sesi latihan (Senin 50 mnt 10 gerakan, Selasa opsional 35 mnt 8 gerakan, Kamis 50 mnt 10 gerakan, Jumat 45 mnt = ronde gabungan 3× + simulasi tarung 2 ronde × 1:30 istirahat 1:00). Tiap gerakan wajib punya field `cara` dan `salah` (kesalahan umum) yang bisa dibuka saat latihan.
>
> Fitur interaktif wajib: workout player full-screen satu gerakan per layar dengan timer per rep/hold/drill, tap "SET SELESAI" per set, rest timer otomatis (45 dtk, bisa diubah), beep 3 detik terakhir + getar (Web Audio API, tanpa file audio), auto-save & tombol "Lanjutkan sesi", screen wake lock, confetti saat selesai. Plus halaman **Timer Gong Tarung** terpisah (preset 2 ronde × 1:30, istirahat 1:00, suara gong, countdown 3-2-1, akurat pakai `Date.now()`).
>
> **FITUR UTAMA — STREAK:** streak = jumlah hari latihan WAJIB berturut-turut yang diselesaikan. Hari wajib: Sen, Kam, Jum (mode 3 hari) atau + Selasa (mode 4 hari). Rabu/Sabtu/Minggu = rest day: tidak menambah tapi **tidak memutus**. Selasa opsional yang dilewat tidak memutus. Sesi dianggap selesai jika user tekan "Selesaikan Sesi" DAN ≥80% gerakan ditandai; kalau kurang, catat sebagai "sesi ringan" dan tidak dihitung streak. Kalau hari wajib belum selesai hari ini, jangan langsung reset (mulai hitung dari hari wajib sebelumnya). Sediakan **Streak Freeze**: 2 token/bulan untuk menutup 1 hari wajib yang terlewat (maks 7 hari ke belakang). Simpan `streakTerbaik` yang tidak pernah turun. Kalau putus, tampilkan layar supportif ("Nggak apa-apa, rekor lu 12 hari — ayo mulai lagi"), jangan pakai kata "gagal". Tampilan: kartu api raksasa di atas Home dengan skala warna (0 abu, 1–2 kuning, 3–6 oranye, 7–13 merah, 14–29 menyala, 30+ ungu/legenda), heatmap kalender 8 minggu, dan badge milestone 3/7/14/21/30/50/100 hari.
>
> Tambahan: XP & level, halaman Progres dengan grafik target 4 minggu (Pike 8→12 rep, Kuda hold 30→50 dtk, Finger dinding 8→12 rep), halaman Aturan Aman (tas maks 4 kg, nyeri tajam stop 2 hari, izin ortu/pelatih), Setting (mode 3/4 hari, durasi rest, suara, getar). Bahasa Indonesia santai ramah anak, dark mode oranye-api, tombol minimal 48 px, offline-first.
