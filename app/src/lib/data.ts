import type { Gerakan, Sesi } from './types'

const g = (o: Omit<Gerakan, 'detikPerRep'> & { detikPerRep?: number }): Gerakan => ({
  detikPerRep: 3,
  ...o,
})

/* ------------------------------------------------------------------ */
/*  SENIN — Tangan Dorong + Kaki Power + Tarung Pukulan (50 menit)      */
/* ------------------------------------------------------------------ */
const senin: Sesi = {
  day: 'senin',
  label: 'Senin',
  tema: 'Tangan Dorong + Kaki Power + Tarung Pukulan',
  durasiMenit: 50,
  opsional: false,
  fokus: 'Bahu depan, dada, triceps, ujung jari + paha meledak',
  blok: [
    {
      nama: 'Blok Tangan',
      gerakan: [
        g({
          id: 'senin-pike',
          nama: 'Pike Push-Up',
          sets: 3,
          reps: 8,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Bahu Depan',
          detikPerRep: 4,
          cara:
            'Posisi huruf V terbalik: tangan di lantai selebar bahu dan pinggul di atas. Tekuk siku perlahan; arahkan kepala ke lantai di antara tangan. Dorong lantai sampai siku lurus lagi. Minta orang dewasa melihat punggungmu.',
          salah:
            'Jangan biarkan punggung melengkung atau siku membuka lurus ke samping. Arahkan siku serong ke belakang. Jika terasa sakit, berhenti.',
        }),
        g({
          id: 'senin-press',
          nama: 'Tas Sekolah Overhead Press',
          sets: 3,
          reps: 10,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Bahu Full',
          detikPerRep: 3,
          cara:
            'Berdiri kuda depan, PELUK tas sekolah di dada 2 tangan. Dorong lurus ke atas sampai tangan lurus, turun pelan ke dada. Tarik napas pas turun, buang pas dorong.',
          salah: 'Punggung melengkung ke belakang, atau tas kegedean. Tas 2–3 kg aja!',
        }),
        g({
          id: 'senin-front-raise',
          nama: 'Sapu Front Raise',
          sets: 3,
          reps: 12,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Bahu Depan',
          detikPerRep: 3,
          cara:
            'Berdiri tegak, pegang sapu lurus depan 2 tangan selebar bahu, telapak menghadap bawah. Angkat pelan sampai mata, turun pelan.',
          salah: 'Ayun badan / siku nekuk. Jangan ayun badan, angkat pakai bahu.',
        }),
        g({
          id: 'senin-diamond',
          nama: 'Diamond Push-Up',
          sets: 3,
          reps: 10,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Triceps',
          detikPerRep: 3,
          cara:
            'Mulai dengan tangan di lantai dekat bawah dada; ibu jari dan telunjuk membentuk segitiga kecil. Jaga badan lurus. Tekuk siku perlahan, lalu dorong lantai untuk kembali ke atas. Boleh mulai dengan lutut menyentuh alas.',
          salah: 'Jangan biarkan pinggul turun atau pantat terlalu tinggi. Jangan paksa jari atau pergelangan; berhenti jika terasa sakit.',
        }),
        g({
          id: 'senin-wrist-twist',
          nama: 'Sapu Wrist Twist',
          sets: 3,
          reps: 15,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Pergelangan',
          detikPerRep: 2,
          cara:
            'Pegang tengah sapu horizontal 1 tangan lurus depan, putar kayak gas motor kanan-kiri. Cuma pergelangan gerak, siku nempel badan.',
          salah: 'Siku ikut gerak. Biar tangkisan gak kram, isolasi pergelangan doang.',
        }),
        g({
          id: 'senin-finger',
          nama: 'Finger Push-Up Dinding',
          sets: 3,
          reps: 8,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Jari',
          detikPerRep: 4,
          cara:
            'Hadap dinding jarak 1 lengan, tempel UJUNG JARI doang (bukan telapak)! Tekuk siku pelan deketin dinding, dorong balik. Jari lurus & kuat.',
          salah: 'Pakai telapak atau jari ditekuk. Level: Dinding → Meja → Lantai lutut (naik tiap 2 minggu).',
        }),
      ],
    },
    {
      nama: 'Blok Kaki + Tarung',
      gerakan: [
        g({
          id: 'senin-goblet',
          nama: 'Tas Sekolah Goblet Squat',
          sets: 3,
          reps: 12,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Paha',
          detikPerRep: 4,
          cara:
            'PELUK tas di dada, kaki buka selebar bahu ujung serong 30°. Jongkok pelan sampai paha sejajar lantai (kuda tengah), punggung lurus, lutut jangan lewat jauh ujung kaki. Naik dorong tumit.',
          salah: 'Lutut masuk ke dalam / tumit naik. Punggung wajib lurus.',
        }),
        g({
          id: 'senin-jump-squat',
          nama: 'Jump Squat',
          sets: 3,
          reps: 8,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Power',
          detikPerRep: 3,
          cara:
            'Squat setengah, lompat lurus atas, mendarat pelan langsung jadi kuda tengah lagi, lutut agak tekuk!',
          salah: 'Mendarat kaku. Jangan tinggi dulu, yang penting stabil & pelan pas mendarat.',
        }),
        g({
          id: 'senin-kuda',
          nama: 'Kuda-Kuda Tengah Hold',
          sets: 3,
          holdDetik: 35,
          tipe: 'hold',
          alat: 'bodyweight',
          targetArea: 'Kuda-kuda',
          cara:
            'Berdiri dengan kaki lebih lebar dari bahu dan ujung kaki sedikit mengarah keluar. Tekuk lutut, turunkan pinggul sedikit, lalu tegakkan badan dan angkat tangan ke depan. Tahan sambil bernapas biasa; jangan memaksa turun terlalu rendah.',
          salah: 'Jangan biarkan lutut jatuh ke dalam atau punggung membungkuk. Kalau keseimbangan hilang atau terasa sakit, berdiri dan istirahat.',
          catatan: 'Target: 30–40 detik per set',
        }),
        g({
          id: 'senin-drill',
          nama: 'Drill Tarung Senin — Pukulan Bersih',
          sets: 1,
          drillDetik: 300,
          tipe: 'drill',
          alat: 'sapu',
          targetArea: 'Drill Tarung',
          cara:
            'Sandarin sapu vertikal ke dinding jadi target. Pasang → 4 pukulan lurus kanan-kiri ke sapu → balik pasang 1 detik → ulang.',
          salah: 'Pukul keras sampai tangan sakit / lupa balik pasang. Fokus CEPAT & BALIK, bukan keras.',
        }),
      ],
    },
  ],
}

/* ------------------------------------------------------------------ */
/*  SELASA (OPSIONAL) — Jari Jadi Senjata (35 menit)                    */
/* ------------------------------------------------------------------ */
const selasa: Sesi = {
  day: 'selasa',
  label: 'Selasa',
  tema: 'Jari, genggaman, dan keseimbangan',
  durasiMenit: 35,
  opsional: true,
  fokus: 'Punggung, lengan, genggaman, dan keseimbangan',
  blok: [
    {
      nama: 'Blok Tarik + Grip',
      gerakan: [
        g({
          id: 'selasa-row',
          nama: 'Tas Sekolah Row Bungkuk',
          sets: 3,
          reps: 10,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Punggung',
          detikPerRep: 3,
          cara:
            'Bungkuk 45° punggung lurus, kaki kuda depan, 1 tangan pegang kursi, 1 tangan TARIK tas (pegang 2 tali jadi satu) dari lantai ke pinggang, siku dekat badan. Turun pelan.',
          salah: 'Punggung bungkuk / narik pakai tangan doang. Siku dekat badan, tarik pakai punggung.',
        }),
        g({
          id: 'selasa-curl',
          nama: 'Tas Sekolah Curl',
          sets: 3,
          reps: 12,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Biceps',
          detikPerRep: 4,
          cara:
            'Berdiri, tas di 1 tangan (pegang atas tas), siku nempel pinggang, curl ke bahu pelan, turun 3 detik.',
          salah: 'Ayun badan. Jangan ayun badan — kalau harus ngayun, tasnya kegedean.',
        }),
        g({
          id: 'selasa-reverse-curl',
          nama: 'Sapu Reverse Curl',
          sets: 3,
          reps: 12,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Forearm',
          detikPerRep: 3,
          cara: 'Pegang tengah sapu telapak menghadap bawah, curl ke atas pelan. Forearm atas!',
          salah: 'Pergelangan nekuk. Jaga pergelangan lurus sejajar sapu.',
        }),
        g({
          id: 'selasa-lever',
          nama: 'Sapu Lever Hold',
          sets: 3,
          holdDetik: 10,
          tipe: 'hold',
          alat: 'sapu',
          targetArea: 'Pergelangan',
          cara:
            'Pegang UJUNG sapu 1 tangan lurus depan horizontal, tahan! Ganti tangan tiap set.',
          salah: 'Sapu miring turun. Kalau miring, turunin dikit — pedes tapi pergelangan jadi baja.',
          catatan: '10 detik per sisi',
        }),
        g({
          id: 'selasa-farmer',
          nama: 'Tas Sekolah Farmer Walk',
          sets: 3,
          reps: 30,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Grip',
          detikPerRep: 1.5,
          cara:
            'Pegang tas ringan di satu tangan dan biarkan menggantung di samping paha. Berdiri tegak, bahu tetap rata, lalu berjalan pelan. Ganti tangan setelah selesai.',
          salah: 'Jangan miringkan badan atau bahu untuk menahan tas. Jika tas membuat badan miring, kosongkan atau hentikan latihan.',
          catatan: '30 langkah per set',
        }),
        g({
          id: 'selasa-finger-roll',
          nama: 'Sapu Finger Roll',
          sets: 3,
          reps: 12,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Jari',
          detikPerRep: 2,
          cara:
            'Pegang sapu vertikal 1 tangan, buka jari lebar → genggam cepat → buka lagi. Kayak main piano.',
          salah: 'Genggam setengah. Buka harus lebar banget, genggam harus penuh.',
        }),
        g({
          id: 'selasa-bulgarian',
          nama: 'Tas Sekolah Bulgarian Split Squat',
          sets: 3,
          reps: 8,
          perSisi: true,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Paha',
          detikPerRep: 4,
          cara:
            'Kaki belakang di kursi, kaki depan jauh, PELUK tas di dada, turun pelan lutut depan 90°, naik.',
          salah: 'Lutut lewat jari kaki. Lutut jangan lewat jari kaki, badan tegak.',
          catatan: '8 rep per kaki',
        }),
      ],
    },
    {
      nama: 'Blok Keseimbangan',
      gerakan: [
        g({
          id: 'selasa-balance',
          nama: 'Sapu Balance + Tangkisan',
          sets: 1,
          drillDetik: 480,
          tipe: 'drill',
          alat: 'sapu',
          targetArea: 'Keseimbangan',
          cara:
            'A. Balance: berdiri 1 kaki, sapu lurus di atas kepala 2 tangan, tahan 20 detik/kaki. B. Tangkisan: pegang sapu horizontal 2 tangan depan dada, buang ke luar/dalam bayangin tendangan datang + balas 1 pukulan. 10x kanan-kiri.',
          salah: 'Badan goyang berlebihan. Fokus ke satu titik di depan biar stabil.',
        }),
      ],
    },
  ],
}

/* ------------------------------------------------------------------ */
/*  KAMIS — Tangan Komplit + Kaki Speed + Tarung Tendangan (50 menit)   */
/* ------------------------------------------------------------------ */
const kamis: Sesi = {
  day: 'kamis',
  label: 'Kamis',
  tema: 'Tangan Komplit + Kaki Speed + Tarung Tendangan',
  durasiMenit: 50,
  opsional: false,
  fokus: 'Bahu belakang, lengan full + tendangan cepat',
  blok: [
    {
      nama: 'Blok Tangan Komplit',
      gerakan: [
        g({
          id: 'kamis-reverse-fly',
          nama: 'Sapu Reverse Fly',
          sets: 3,
          reps: 12,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Bahu Belakang',
          detikPerRep: 3,
          cara:
            'Berdiri, tekuk lutut sedikit, lalu condongkan badan dari pinggul dengan punggung lurus. Pegang sapu lebar di depan badan. Buka kedua siku ke samping sampai sejajar bahu, lalu turunkan perlahan.',
          salah: 'Jangan membulatkan punggung, mengayun badan, atau mengangkat siku lebih tinggi dari bahu. Hentikan jika terasa sakit.',
        }),
        g({
          id: 'kamis-floor-press',
          nama: 'Tas Sekolah Floor Press',
          sets: 3,
          reps: 10,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Dada',
          detikPerRep: 3,
          cara:
            'Tiduran punggung di lantai lutut tekuk, dorong tas dari dada lurus ke atas, turun pelan siku sentuh lantai.',
          salah: 'Siku nggak nyentuh lantai / punggung melengkung.',
        }),
        g({
          id: 'kamis-shoulder-pass',
          nama: 'Sapu Shoulder Pass',
          sets: 3,
          reps: 8,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Bahu',
          detikPerRep: 4,
          cara:
            'Pegang sapu dengan dua tangan jauh satu sama lain. Angkat perlahan dari depan, lewat atas kepala, lalu sejauh yang nyaman ke belakang. Kembalikan lewat atas ke depan.',
          salah: 'Jangan menekuk siku atau memaksa bahu. Jika sapu tidak bisa lewat tanpa sakit, hentikan dan minta orang dewasa membantu.',
        }),
        g({
          id: 'kamis-overhead-ext',
          nama: 'Tas Sekolah Overhead Extension',
          sets: 3,
          reps: 10,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Triceps',
          detikPerRep: 3,
          cara:
            'Berdiri atau duduk tegak, pegang tas ringan dengan dua tangan di atas kepala. Tekuk siku perlahan dan turunkan tas ke belakang kepala. Luruskan siku untuk mengangkat tas kembali. Minta orang dewasa menjaga tas tetap aman.',
          salah: 'Jangan melengkungkan punggung atau menurunkan tas terlalu jauh. Jika bahu atau siku terasa sakit, berhenti.',
        }),
        g({
          id: 'kamis-putar-tangkisan',
          nama: 'Sapu Putar Tangkisan',
          sets: 3,
          reps: 10,
          perSisi: true,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Pergelangan',
          detikPerRep: 2,
          cara:
            'Berdiri tegak. Pegang sapu vertikal di samping badan dengan satu tangan, siku ditekuk dan dekat pinggang. Putar lengan bawah perlahan ke dalam, lalu kembali ke posisi awal. Ulangi di sisi lain.',
          salah: 'Jangan memutar seluruh badan atau memaksa pergelangan. Gerakkan pelan; berhenti jika terasa sakit.',
          catatan: '10x per sisi',
        }),
        g({
          id: 'kamis-pinch',
          nama: 'Tas Sekolah Pinch Grip',
          sets: 3,
          holdDetik: 15,
          tipe: 'hold',
          alat: 'tas',
          targetArea: 'Jari',
          cara:
            'CUBIT ujung bawah tas pakai ujung jari doang (jempol vs 4 jari), angkat 5cm tahan!',
          salah: 'Pakai telapak. Kalau jatuh, coba lagi — jari makin kuat.',
          catatan: '15 detik per set',
        }),
        g({
          id: 'kamis-plank-finger',
          nama: 'Plank Ujung Jari',
          sets: 3,
          holdDetik: 20,
          tipe: 'hold',
          alat: 'bodyweight',
          targetArea: 'Core + Jari',
          cara: 'Plank biasa tapi tumpuan ujung jari! Badan lurus.',
          salah: 'Pinggang turun. Gak kuat? Lutut di lantai dulu.',
        }),
      ],
    },
    {
      nama: 'Blok Kaki Speed + Tarung',
      gerakan: [
        g({
          id: 'kamis-tendangan',
          nama: 'Tendangan Bayangan + Lunge Jalan',
          sets: 4,
          reps: 8,
          perSisi: true,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Tendangan + Paha',
          detikPerRep: 3,
          cara:
            'Tendangan: dari pasang angkat lutut tinggi, tendang lurus/T/sabit setinggi PERUT aja (biar poin!), tarik balik cepat ke pasang. Sapu taruh di lantai jadi patokan jarak. Lunge: PELUK tas di dada, langkah panjang depan, lutut belakang hampir sentuh lantai.',
          salah: 'Tendang terlalu tinggi sampai oleng / badan miring. Setinggi perut aja, balik cepat ke pasang.',
          catatan: '8x per kaki',
        }),
        g({
          id: 'kamis-hurdle',
          nama: 'Sapu Hurdle Jump',
          sets: 3,
          reps: 8,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Kaki + Koordinasi',
          detikPerRep: 2,
          cara: 'Letakkan sapu rata di lantai sebagai garis. Berdiri di satu sisi, tekuk lutut sedikit, lalu lompat kecil melewati sapu dengan dua kaki. Mendarat pelan dengan lutut lentur, lalu kembali dengan langkah kecil.',
          salah: 'Jangan melompat tinggi, mendarat kaku, atau memakai sapu licin/bergulir. Lakukan hanya dengan lantai kering dan orang dewasa mendampingi.'
        }),
        g({
          id: 'kamis-drill',
          nama: 'Drill Tarung Kamis — Tendangan Poin',
          sets: 1,
          drillDetik: 300,
          tipe: 'drill',
          alat: 'pintu',
          targetArea: 'Drill Tarung',
          cara:
            'Gantung tas sekolah (kosongin biar enteng) di gagang pintu ikat kuat! Mundur 1 langkah, tendangan T pelan kena tengah tas, balik pasang. Kanan-kiri!',
          salah: 'Nendang keras tanpa balik pasang. Fokus tendangan bersih + langsung pasang lagi.',
        }),
      ],
    },
  ],
}

/* ------------------------------------------------------------------ */
/*  JUMAT — Hari Juara, Simulasi Lomba Beneran (45 menit)               */
/* ------------------------------------------------------------------ */
const jumat: Sesi = {
  day: 'jumat',
  label: 'Jumat',
  tema: 'Hari Juara — Simulasi Lomba Beneran',
  durasiMenit: 45,
  opsional: false,
  fokus: 'Gabungan tangan + kaki + simulasi 2 ronde',
  blok: [
    {
      nama: 'Ronde Gabungan',
      rounds: 3,
      restAntarRonde: 60,
      gerakan: [
        g({
          id: 'jumat-pike',
          nama: 'Pike Push-Up',
          sets: 1,
          reps: 8,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Bahu Depan',
          detikPerRep: 4,
          cara: 'Sama kayak Senin. Pike push-up 8 rep, jangan buru-buru.',
          salah: 'Pinggang melengkung, siku melebar.',
        }),
        g({
          id: 'jumat-squat',
          nama: 'Tas Sekolah Squat',
          sets: 1,
          reps: 10,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Paha',
          detikPerRep: 4,
          cara: 'Peluk tas di dada, jongkok paha sejajar lantai, naik dorong tumit. 10 rep.',
          salah: 'Lutut masuk ke dalam.',
        }),
        g({
          id: 'jumat-row',
          nama: 'Tas Sekolah Row',
          sets: 1,
          reps: 10,
          tipe: 'rep',
          alat: 'tas',
          targetArea: 'Punggung',
          detikPerRep: 3,
          cara: 'Bungkuk 45°, tarik tas ke pinggang, siku dekat badan. 10 rep.',
          salah: 'Punggung bungkuk.',
        }),
        g({
          id: 'jumat-jump-lunge',
          nama: 'Jump Lunge',
          sets: 1,
          reps: 6,
          perSisi: true,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Kaki + Power',
          detikPerRep: 3,
          cara: 'Lunge terus lompat ganti kaki. 6x per kaki.',
          salah: 'Capek? Ganti lunge biasa aja — yang penting selesai.',
        }),
        g({
          id: 'jumat-wrist',
          nama: 'Sapu Wrist Twist',
          sets: 1,
          reps: 15,
          tipe: 'rep',
          alat: 'sapu',
          targetArea: 'Pergelangan',
          detikPerRep: 2,
          cara: 'Putar sapu kayak gas motor, cuma pergelangan yang gerak. 15x.',
          salah: 'Siku ikut gerak.',
        }),
        g({
          id: 'jumat-kuda',
          nama: 'Kuda Tengah Hold',
          sets: 1,
          holdDetik: 30,
          tipe: 'hold',
          alat: 'bodyweight',
          targetArea: 'Kuda-kuda',
          cara: 'Kuda tengah, punggung tegak, tahan 30 detik. Napas biasa.',
          salah: 'Punggung bungkuk.',
        }),
        g({
          id: 'jumat-finger',
          nama: 'Finger Push-Up Dinding',
          sets: 1,
          reps: 8,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Jari',
          detikPerRep: 4,
          cara: 'Tumpuan ujung jari di dinding, dorong balik. 8 rep.',
          salah: 'Pakai telapak.',
        }),
        g({
          id: 'jumat-tendangan',
          nama: 'Tendangan Depan',
          sets: 1,
          reps: 6,
          perSisi: true,
          tipe: 'rep',
          alat: 'bodyweight',
          targetArea: 'Tendangan',
          detikPerRep: 3,
          cara: 'Tendangan depan setinggi perut, tarik balik ke pasang. 6x per kaki.',
          salah: 'Tendang terlalu tinggi sampai oleng.',
        }),
      ],
    },
    {
      nama: 'Simulasi Tarung',
      gerakan: [
        g({
          id: 'jumat-simulasi',
          nama: 'Simulasi Tarung — 2 Ronde',
          sets: 2,
          drillDetik: 90,
          restDetik: 60,
          tipe: 'drill',
          alat: 'bodyweight',
          targetArea: 'Simulasi',
          cara:
            'Ronde 1 (1:30): nonstop 2 pukulan → 1 tendangan → 1 tangkisan bayangan → balik pasang, ulang terus. Ronde 2 (1:30): pukulan + tendangan + tangkap kaki (sandarin sapu miring ke dinding pura-pura kaki lawan, tangkap tarik pelan) + 20 detik kuda hold di akhir. Istirahat 1 menit duduk di antaranya.',
          salah: 'Berhenti di tengah ronde. Nonstop sampai gong — itu inti latihan juara.',
        }),
        g({
          id: 'jumat-finisher',
          nama: 'Finisher — Sapu Pass + Calf Stretch',
          sets: 1,
          drillDetik: 60,
          tipe: 'drill',
          alat: 'sapu',
          targetArea: 'Pendinginan',
          cara:
            'Sapu pass 1 menit (angkat sapu dari depan lewat atas ke belakang tanpa nekuk siku), lanjut calf stretch.',
          salah: 'Skip pendinginan. Ini yang bikin besok nggak pegal.',
        }),
      ],
    },
  ],
}

export const SESI: Record<'senin' | 'selasa' | 'kamis' | 'jumat', Sesi> = {
  senin,
  selasa,
  kamis,
  jumat,
}

export const URUTAN_HARI: Array<'senin' | 'selasa' | 'kamis' | 'jumat'> = [
  'senin',
  'selasa',
  'kamis',
  'jumat',
]

export function getSesi(day: string): Sesi | null {
  return (SESI as Record<string, Sesi>)[day] ?? null
}

export function buildQueue(sesi: Sesi) {
  const out: Array<{
    gerakan: Gerakan
    blok: string
    round?: number
    rounds?: number
    restRonde?: number
  }> = []
  for (const blok of sesi.blok) {
    const rounds = blok.rounds ?? 1
    for (let r = 0; r < rounds; r++) {
      for (const gerakan of blok.gerakan) {
        out.push({
          gerakan,
          blok: blok.nama,
          round: rounds > 1 ? r + 1 : undefined,
          rounds: rounds > 1 ? rounds : undefined,
          restRonde: blok.restAntarRonde,
        })
      }
    }
  }
  return out
}

export function durasiGerakan(ger: Gerakan): number {
  if (ger.tipe === 'hold') return Math.max(5, ger.holdDetik ?? 30)
  if (ger.tipe === 'drill') return Math.max(10, ger.drillDetik ?? 120)
  return Math.max(5, Math.round((ger.reps ?? 10) * (ger.detikPerRep ?? 3)))
}
