import { useApp } from '../store'
import { go } from '../lib/nav'
import { Btn } from '../components/ui'
import { IcBack, IcShield } from '../components/Icon'

const AMAN = [
  { i: '🎒', t: 'Tas sekolah max 4 kg', d: '1–2 buku tebal + botol air 1.5L. Ganjal handuk biar nggak nusuk punggung.' },
  { i: '🥢', t: 'Sapu gak retak / licin', d: 'Cek sebelum latihan. Kalau retak, ganti — jangan dipaksa.' },
  { i: '🦶', t: 'Lantai gak licin', d: 'Pakai alas kaki atau pastikan lantai kering.' },
  { i: '💧', t: 'Minum tiap 15 menit', d: 'Jangan tunggu haus. Botol air taruh deket.' },
  { i: '😴', t: 'Tidur 8–9 jam', d: 'Otot tumbuh pas tidur, bukan pas latihan.' },
  { i: '🚨', t: 'Nyeri tajam di sendi = STOP 2 hari', d: 'Pegal biasa beda sama nyeri tajam. Kalau ragu, lapor ortu.' },
  { i: '🙋', t: 'Lapor ortu/pelatih sebelum simulasi Jumat', d: 'Simulasi tarung butuh pengawasan orang dewasa.' },
]

const POIN = [
  { p: '1', t: 'Pukulan kena body', d: 'dada / perut / punggung pakai body protector' },
  { p: '2', t: 'Tendangan kena body', d: 'tendangan lurus, T, atau sabit setinggi perut' },
  { p: '3', t: 'Bantingan berhasil', d: 'tangkap kaki lalu banting pelan' },
  { p: '+1', t: 'Tangkis + langsung balas', d: 'bonus, jadi 1+1 atau 1+2' },
]

export default function Aturan() {
  const { state, set, toast } = useApp()

  return (
    <div className="screen">
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <button className="icon-btn" onClick={() => go('/')} aria-label="Kembali">
          <IcBack size={19} />
        </button>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.14em', color: 'var(--dim2)', textTransform: 'uppercase' }}>
            Aturan
          </div>
          <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 2 }}>
            Aman & Peraturan Tarung
          </div>
        </div>
      </div>

      <div className="card" style={{ borderColor: 'rgba(255,107,26,0.3)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontSize: 22 }}>🥋</span>
          <div style={{ fontSize: 13.5, fontWeight: 800 }}>
            Kelas 6 · BB 33 kg · Kelas D Usia Dini / Kelas B Pra Remaja
          </div>
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--dim)', marginTop: 10, lineHeight: 1.6 }}>
          Lu masih pertumbuhan! Jangan kejar berat tas. Fokus gerakan benar + repetisi banyak.
        </div>
      </div>

      <div className="section-title">
        <h2>Peraturan tarung</h2>
        <span style={{ fontSize: 11, color: 'var(--dim2)', fontWeight: 600 }}>2 ronde × 1:30</span>
      </div>

      <div className="card">
        <div style={{ fontSize: 12.5, color: 'var(--dim)', marginBottom: 14, lineHeight: 1.55 }}>
          Main <b style={{ color: 'var(--txt)' }}>2 babak × 1,5 menit</b>, istirahat 1 menit. Menang
          poin terbanyak.
        </div>
        {POIN.map((p) => (
          <div
            key={p.t}
            style={{
              display: 'flex',
              gap: 12,
              alignItems: 'flex-start',
              padding: '10px 0',
              borderBottom: '1px solid var(--line)',
            }}
          >
            <span
              style={{
                minWidth: 42,
                height: 30,
                borderRadius: 10,
                display: 'grid',
                placeItems: 'center',
                background: 'rgba(255,107,26,0.13)',
                color: 'var(--orange2)',
                fontWeight: 800,
                fontSize: 13,
              }}
            >
              {p.p}
            </span>
            <div>
              <div style={{ fontSize: 13.5, fontWeight: 700 }}>{p.t}</div>
              <div style={{ fontSize: 11.5, color: 'var(--dim)', marginTop: 2 }}>{p.d}</div>
            </div>
          </div>
        ))}
        <div className="warn-box" style={{ marginTop: 14 }}>
          <b>DILARANG KERAS:</b> pukul kepala/leher/kemaluan, siku, dengkul, narik baju sembarangan.
          Umur lu cuma boleh tangkap kaki lalu banting.
        </div>
        <div className="tip-box">
          🥇 <b>Kunci menang:</b> jangan adu pukulan doang! Banyakin tendangan bersih +
          tangkis-balas = poin auto gede.
        </div>
      </div>

      <div className="section-title">
        <h2>Aturan aman</h2>
      </div>

      <div className="card">
        {AMAN.map((a) => (
          <div
            key={a.t}
            style={{
              display: 'flex',
              gap: 12,
              alignItems: 'flex-start',
              padding: '11px 0',
              borderBottom: '1px solid var(--line)',
            }}
          >
            <span style={{ fontSize: 18, lineHeight: '22px' }}>{a.i}</span>
            <div>
              <div style={{ fontSize: 13.5, fontWeight: 700 }}>{a.t}</div>
              <div style={{ fontSize: 11.5, color: 'var(--dim)', marginTop: 2, lineHeight: 1.5 }}>
                {a.d}
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="section-title">
        <h2>Progres 4 minggu</h2>
      </div>
      <div className="card">
        <div style={{ fontSize: 12.5, color: 'var(--dim)', lineHeight: 1.7 }}>
          <b style={{ color: 'var(--txt)' }}>Minggu 1–2:</b> ikut reps apa adanya.
          <br />
          <b style={{ color: 'var(--txt)' }}>Minggu 3:</b> tambah 2 reps / +10 detik hold.
          <br />
          <b style={{ color: 'var(--txt)' }}>Minggu 4:</b> tambah 1 set tiap blok.
          <br />
          <b style={{ color: 'var(--amber)' }}>Enteng? Tambah reps dulu, JANGAN tambah berat.</b>
        </div>
      </div>

      <div className="section-title">
        <h2>Cara pakai tas sekolah</h2>
      </div>
      <div className="card">
        <div style={{ fontSize: 12.5, color: 'var(--dim)', lineHeight: 1.7 }}>
          <b style={{ color: 'var(--txt)' }}>PELUK</b> di dada → Squat, Press, Lunge
          <br />
          <b style={{ color: 'var(--txt)' }}>TARIK</b> 2 tali pundak → Row, Curl
          <br />
          <b style={{ color: 'var(--txt)' }}>JINJING</b> 1 tali tebal → Farmer Walk
          <br />
          <b style={{ color: 'var(--txt)' }}>CUBIT</b> ujung kain → Pinch Grip
        </div>
      </div>

      <div style={{ marginTop: 18 }}>
        <Btn
          onClick={() => {
            set((s) => ({ ...s, izinOrtu: true, izinSudahDiingatkan: true }))
            toast('Sip! Jangan lupa lapor ortu/pelatih ya 🙏', 'sukses')
          }}
          disabled={state.izinOrtu}
        >
          <IcShield size={17} />
          {state.izinOrtu ? 'Izin sudah dicatat ✅' : 'Aku udah izin ortu/pelatih'}
        </Btn>
      </div>

      <p className="small-note">
        Kalau ragu sama gerakan atau ada nyeri, tanya pelatih. Latihan yang bener itu yang aman.
      </p>
    </div>
  )
}
