# JedaSholat Android

JedaSholat membatasi **hanya aplikasi yang dipilih pengguna** selama jendela waktu sholat yang dikonfigurasi, lalu membuka kembali akses secara otomatis. Di luar jendela tersebut telepon tidak dibatasi. Ini bukan kunci perangkat seharian dan bukan alat anti-bypass.

## Status rilis

- `android/`: aplikasi native Kotlin + Jetpack Compose, `applicationId id.jedasholat.app`, minSdk 29, target/compileSdk 35.
- `preview/`: pratinjau web interaktif untuk mencoba UI dan simulasi. Browser **tidak** memblokir aplikasi Android.
- Proyek Dojo Tarung yang sudah ada di `app/` tidak diubah.
- Debug APK dihasilkan workflow **Build JedaSholat Android** sebagai artefak `JedaSholat-debug`. APK debug bukan rilis Play Store dan belum ditandatangani dengan kunci rilis.
- Jangan menyamakan lulus build/unit test dengan lulus uji perangkat fisik. Lihat `docs/DEVICE_TEST_CHECKLIST.md`.

## Menjalankan dan membuild

Kebutuhan: JDK 17, Android SDK 35, Android Gradle Plugin 8.7.3, Gradle wrapper 8.9.

```bash
cd android
./gradlew :core:test :app:testDebugUnitTest
./gradlew :app:lintDebug :app:assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

Uji instrumentasi membutuhkan emulator/perangkat dan APK target uji terpisah:

```bash
./gradlew :testtarget:assembleDebug
adb install -r testtarget/build/outputs/apk/debug/testtarget-debug.apk
./gradlew :app:connectedDebugAndroidTest
```

`testtarget` adalah aplikasi launcher biasa khusus pengujian overlay; bukan bagian dari APK JedaSholat. Workflow CI menyediakan smoke test ini pada emulator Android 15 sebagai pemeriksaan advisory; binding Layanan Aksesibilitas di emulator CI belum cukup stabil untuk dijadikan gate rilis. Uji OEM, Doze, reboot fisik, dan pencabutan izin tetap perlu dilakukan pada perangkat nyata.

Pratinjau web:

```bash
cd preview
npm ci
npm run dev       # http://localhost:3001
npm test
npm run build
node tests/browser.mjs   # membutuhkan dev server dan Playwright Chromium
```

## Perilaku produk

1. Pengguna menyelesaikan onboarding, memilih lokasi/koordinat dan zona IANA, lalu memilih aplikasi. Tidak ada aplikasi yang dipilih otomatis pada versi Android.
2. Lima jendela tersedia: Subuh, Dzuhur, Ashar, Maghrib, Isya. Default 20 menit per sholat; durasi 1–120 menit, koreksi per sholat −30..+30 menit, pengingat 0–30 menit sebelumnya.
3. Mode **Pengingat** menampilkan layar jeda dengan tunda 5 menit satu kali per sesi. Tunda tidak pernah memperpanjang akhir asli. Setelah tunda dipakai, pengguna boleh melanjutkan tanpa pengingat sampai sesi berakhir.
4. Mode **Tegas** tidak mempunyai tombol lanjut main/tunda. Tombol layar utama dan telepon/darurat tetap ada. Izin Android tetap dapat dicabut; tidak ada root, device admin, pencegahan uninstall, atau full-screen intent.
5. Awal sesi: `start <= now < end`. Tepat pada `end`, aplikasi pilihan diizinkan kembali. Sesi yang sedang berjalan mempertahankan mode dan akhir asli walaupun pengaturan diubah.
6. Bila beberapa jendela bertumpang tindih, aturan keselamatan/whitelist/tidak dipilih menang lebih dulu; di antara sesi aktif, Mode Tegas menang atas Pengingat. Untuk mode yang sama dipilih akhir terjauh.
7. Riwayat adalah status sesi aplikasi, bukan catatan ibadah. Data disimpan lokal dan dipangkas setelah 90 hari.

## Perhitungan sholat

- Pustaka Adhan 1.2.1, profil kustom Subuh 20° / Isya 18°, Ashar standar/Syafi'i dengan opsi Hanafi, aturan lintang tinggi `TWILIGHT_ANGLE`.
- Perhitungan offline setelah pengaturan. Lokasi GPS hanya diambil saat diminta; kota/koordinat manual tersedia. Zona waktu eksplisit: Asia/Jakarta, Asia/Makassar, Asia/Jayapura, atau IANA lain yang valid.
- Hasil adalah estimasi astronomis, **bukan jadwal resmi Kemenag**. Koreksi per sholat disediakan agar pengguna dapat mencocokkan referensi masjid/setempat. Jangan memakai kriteria MABIMS untuk sudut sholat.
- Tanggal dihitung dari komponen kalender dan zona IANA, bukan timezone default JVM. Jika hasil tidak lengkap/tanggal tidak cocok, UI menampilkan kesalahan alih-alih Diam-diam memakai jadwal salah.
- Sunrise bukan sholat dan tidak membuat jendela pembatasan.

## Penjadwalan dan pemulihan

- `SessionCoordinator` merekonsiliasi sesi terhadap jam saat ini, izin, dan pengaturan. State persisten: SCHEDULED, ACTIVE, SNOOZED, COMPLETED, CANCELLED, INTERRUPTED, MISSED.
- Alarm tepat waktu dipakai bila `canScheduleExactAlarms()` mengizinkan; jika tidak, alarm inexact dan WorkManager menjadi fallback dengan keterlambatan yang mungkin terjadi.
- Batas awal/akhir/tunda dan pengingat didaftarkan ulang setelah boot, perubahan waktu/zona, update aplikasi, serta rekonsiliasi berkala. Alarm lama dibatalkan agar tidak ada jadwal basi.
- Reboot di tengah sesi melanjutkan **sisa** sesi sampai akhir asli, bukan memulai 20 menit baru. Jika seluruh jendela sudah terlewat saat proses hidup kembali, sesi ditandai MISSED dan tidak mengunci ulang.
- Pencabutan izin/mematikan perlindungan menghentikan enforcement. Sesi aktif ditandai INTERRUPTED; pemulihan izin hanya melanjutkan bila masih di dalam jendela asli.
- Force stop, penghemat baterai OEM, Doze, dan penghapusan proses dapat menunda alarm/event. Aplikasi tidak menjanjikan always-on atau ketepatan detik pada semua perangkat.

## Layanan Aksesibilitas dan privasi

- Layanan hanya menerima `TYPE_WINDOW_STATE_CHANGED` dan nama paket. `canRetrieveWindowContent=false`, `isAccessibilityTool=false`; tidak membaca isi layar, pesan, ketikan, atau gesto.
- Disclosure dan persetujuan eksplisit mendahului pembukaan Pengaturan Aksesibilitas. Menolak izin tetap memungkinkan penggunaan jadwal.
- Paket sendiri, System UI/Settings/pemanggil izin/uninstall, default dialer/telepon/alarm/home, serta whitelist pengguna selalu diizinkan. Aplikasi tidak dipilih tidak pernah ditutup.
- Overlay hanya tampil ketika aplikasi foreground yang dipilih terkena sesi aktif. Pada saat layanan baru tersambung, event perpindahan berikutnya dipakai; akses penggunaan opsional dengan persetujuan terpisah dapat mengenali aplikasi yang sudah terbuka.
- Tidak ada izin INTERNET, QUERY_ALL_PACKAGES, device admin, root, atau full-screen intent. Tidak ada akun, iklan, analytics, maupun backend.
- DataStore/Room/SharedPreferences lokal; backup cloud dan device-transfer dikecualikan. Hapus riwayat dan reset data tersedia. Reset aplikasi tidak mencabut izin Android secara otomatis.
- Sebelum distribusi publik, lengkapi kebijakan privasi, Data Safety, deklarasi Aksesibilitas di Play Console, dan video demo sesuai kebijakan Google Play saat itu.

## Batas yang disengaja

- Tidak mencegah pengguna membuka Pengaturan, mencabut izin, force stop, atau uninstall.
- Tidak mengklaim jadwal resmi, ketepatan detik tanpa izin alarm, atau kompatibilitas semua OEM tanpa uji perangkat.
- Tidak menilai kualitas ibadah, tidak memberi skor pahala, dan tidak memaksa mode tertentu.
- Pratinjau web memakai katalog aplikasi contoh dan localStorage; ia bukan bukti enforcement native.
