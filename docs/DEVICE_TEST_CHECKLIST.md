# Checklist uji perangkat JedaSholat

Gunakan APK debug dari artefak CI `JedaSholat-debug` atau build lokal. Catat merek/model, versi Android, patch keamanan, versi aplikasi, zona, lokasi, izin, dan hasil aktual. Jangan menandai lulus hanya karena kompilasi berhasil.

## Matriks minimum

| Perangkat | Android | Fokus | Status |
|---|---:|---|---|
| Emulator CI Pixel 6, Android 15 | 35 | overlay selected/unselected, strict auto-unlock, snooze persisten | otomatis di workflow |
| Samsung Galaxy (One UI) | 13/14/15 | battery manager, restricted settings, exact alarm | perlu perangkat |
| Xiaomi/POCO (HyperOS/MIUI) | 13/14/15 | autostart, battery saver, overlay/accessibility survival | perlu perangkat |
| OPPO/realme/vivo | 13/14/15 | OEM background limits, permission revocation | perlu perangkat |
| Pixel/AOSP | 10 dan 15 | minSdk dan targetSdk, reboot, time/timezone change | perlu perangkat |

## Sebelum uji

1. Install APK, buka onboarding, pilih kota/koordinat dan zona yang benar.
2. Pilih satu aplikasi uji yang tidak berbahaya (misalnya browser/game ringan) dan satu aplikasi kontrol yang tidak dipilih.
3. Masukkan satu aplikasi ke whitelist. Pastikan telepon, alarm, Home, Settings, permission controller, dan uninstall dapat dibuka.
4. Aktifkan notifikasi dan exact alarm bila tersedia. Baca disclosure sebelum mengaktifkan Layanan Aksesibilitas.
5. Cocokkan lima waktu sholat dengan referensi setempat; catat selisih dan gunakan koreksi bila perlu.
6. Gunakan simulasi 30 detik untuk smoke test awal, lalu uji jendela asli yang pendek (1–2 menit) pada waktu yang aman.

## Skenario wajib

- [ ] Di luar jendela: aplikasi pilihan, game, browser, dan kamera tetap normal.
- [ ] Tepat sebelum start: belum ada overlay. Tepat pada start: overlay muncul pada aplikasi pilihan yang sudah terbuka maupun yang baru dibuka.
- [ ] Aplikasi tidak dipilih dan whitelist tidak pernah ditutup.
- [ ] Telepon/darurat, Home, Settings, pencabutan izin, dan uninstall tetap dapat diakses saat Mode Tegas.
- [ ] Tepat pada end: overlay hilang dan aplikasi bisa dipakai tanpa membuka JedaSholat. Tidak ada perpanjangan timer.
- [ ] Pengingat: tunda hanya satu kali, maksimal 5 menit dan tidak melewati end; setelah tunda habis pengingat muncul lagi.
- [ ] Tegas: tidak ada tombol tunda/lanjut main; tombol Home dan telepon berfungsi.
- [ ] Dua jendela bertumpang tindih: keselamatan/whitelist menang; Tegas menang atas Pengingat; akhir terjauh dipakai.
- [ ] Ubah durasi/mode saat sesi berjalan: sesi berjalan tidak berubah; sesi mendatang mengikuti pengaturan baru.
- [ ] Matikan perlindungan saat sesi: overlay hilang, sesi INTERRUPTED, aplikasi bebas.
- [ ] Cabut Layanan Aksesibilitas saat sesi: enforcement berhenti; tidak ada crash/overlay tertinggal.
- [ ] Cabut notifikasi: fungsi jeda tetap berjalan tanpa crash; notifikasi tidak dikirim.
- [ ] Cabut exact alarm: UI memperingatkan keterlambatan; fallback tetap merekonsiliasi saat proses berjalan.
- [ ] Reboot di tengah sesi: hanya sisa waktu sampai end asli yang dilanjutkan.
- [ ] Reboot setelah end: tidak mengunci ulang; sesi missed/completed sesuai keadaan.
- [ ] Ubah jam maju melewati sesi: sesi berakhir/missed, tidak mengunci ulang.
- [ ] Ubah jam mundur: tidak memperpanjang sesi yang sudah selesai; sesi mendatang dihitung terhadap waktu baru.
- [ ] Ubah zona/timezone dan pindah kota: jadwal dihitung ulang; sesi lama tidak menggantung.
- [ ] Lewat tengah malam: jadwal hari berikutnya tersedia dan alarm lama dibatalkan.
- [ ] Leap day dan lokasi WIB/WITA/WIT menghasilkan lima waktu berurutan tanpa Sunrise.
- [ ] Force stop lalu buka aplikasi: state direkonsiliasi; tidak ada timer baru yang dibuat dari awal.
- [ ] Doze/screen off dan battery saver OEM: catat keterlambatan aktual; jangan menjanjikan always-on.
- [ ] Hapus riwayat: riwayat hilang, pengaturan tetap. Reset data: pilihan/izin aplikasi kembali default; izin Android tetap dikelola manual.
- [ ] Tidak ada trafik jaringan aplikasi: periksa izin INTERNET tidak ada dan tidak ada akun/ads/analytics.

## Kriteria lulus rilis

- Semua skenario wajib pada minimal tiga OEM berbeda lulus tanpa mengunci aplikasi non-pilihan atau akses darurat.
- Tidak ada crash pada pencabutan izin, reboot, perubahan waktu/zona, dan akhir sesi.
- Selisih jadwal terhadap referensi lokal dicatat dan dapat dikoreksi; tidak ada klaim “resmi Kemenag”.
- Disclosure, kebijakan privasi, Data Safety, dan deklarasi Play Console lengkap sebelum distribusi publik.
- Keterbatasan OEM/Doze ditampilkan jujur di UI dan dokumentasi.

## Template catatan

```text
Tanggal / penguji:
Perangkat / OS / versi aplikasi:
Lokasi / zona / referensi jadwal:
Izin aktif:
Skenario:
Langkah:
Hasil yang diharapkan:
Hasil aktual:
Lulus / gagal / tertunda:
Log atau screenshot:
```
