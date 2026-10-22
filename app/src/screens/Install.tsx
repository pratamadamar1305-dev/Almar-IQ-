import { useState } from 'react'
import { useApp } from '../store'
import { go } from '../lib/nav'
import { usePWA } from '../lib/pwa'
import { Btn } from '../components/ui'
import { IcBack, IcCheck, IcInfo } from '../components/Icon'

function Langkah({
  no,
  judul,
  detail,
  aktif,
}: {
  no: number
  judul: string
  detail: string
  aktif?: boolean
}) {
  return (
    <div
      style={{
        display: 'flex',
        gap: 12,
        padding: '14px 0',
        borderBottom: '1px solid var(--line)',
      }}
    >
      <span
        style={{
          width: 28,
          height: 28,
          borderRadius: 9,
          display: 'grid',
          placeItems: 'center',
          fontSize: 12.5,
          fontWeight: 800,
          flex: 'none',
          background: aktif ? 'rgba(255,107,26,0.16)' : 'var(--card3)',
          color: aktif ? 'var(--orange2)' : 'var(--dim)',
        }}
      >
        {no}
      </span>
      <div>
        <div style={{ fontSize: 13.5, fontWeight: 700 }}>{judul}</div>
        <div style={{ fontSize: 12, color: 'var(--dim)', marginTop: 3, lineHeight: 1.55 }}>
          {detail}
        </div>
      </div>
    </div>
  )
}

export default function Install() {
  const { toast } = useApp()
  const { status, ios, didukung, install } = usePWA()
  const [sibuk, setSibuk] = useState(false)

  const tombol = async () => {
    setSibuk(true)
    const hasil = await install()
    setSibuk(false)
    if (hasil === 'accepted') toast('Mantap! Dojo Tarung masuk ke layar HP lu 🎉', 'sukses')
    else if (hasil === 'dismissed') toast('Oke, nanti aja kalau udah siap.', 'info')
    else toast('Browser ini belum bisa install otomatis — ikuti langkah manual di bawah.', 'info')
  }

  return (
    <div className="screen">
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <button className="icon-btn" onClick={() => go('/setting')} aria-label="Kembali">
          <IcBack size={19} />
        </button>
        <div style={{ flex: 1 }}>
          <div
            style={{
              fontSize: 11,
              fontWeight: 800,
              letterSpacing: '0.14em',
              color: 'var(--dim2)',
              textTransform: 'uppercase',
            }}
          >
            Install
          </div>
          <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 2 }}>
            Pasang di HP
          </div>
        </div>
      </div>

      {/* Hero */}
      <div className="card" style={{ textAlign: 'center', padding: '26px 20px' }}>
        <img
          src="./icons/icon-rounded-256.png"
          alt=""
          width={92}
          height={92}
          style={{
            borderRadius: 24,
            boxShadow: '0 16px 40px -16px rgba(255,107,26,0.9)',
          }}
        />
        <div style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 16 }}>
          DOJO TARUNG
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--dim)', marginTop: 6, lineHeight: 1.55 }}>
          Tanpa Play Store, tanpa download. Cukup tambah ke layar utama — langsung jadi ikon
          aplikasi yang bisa dibuka kayak app biasa.
        </div>

        {status === 'sudah-terpasang' ? (
          <div
            className="pill green"
            style={{ marginTop: 18, padding: '10px 16px', fontSize: 12.5 }}
          >
            <IcCheck size={14} /> Sudah terpasang di HP ini
          </div>
        ) : status === 'bisa-install' ? (
          <Btn size="lg" style={{ marginTop: 20 }} onClick={tombol} disabled={sibuk}>
            {sibuk ? 'Membuka dialog…' : '⬇️ Install ke Layar Utama'}
          </Btn>
        ) : (
          <Btn
            size="lg"
            style={{ marginTop: 20 }}
            onClick={() =>
              toast('Ikuti langkah manual di bawah ya 👇', 'info')
            }
          >
            Lihat cara manual
          </Btn>
        )}
      </div>

      {/* Android */}
      <div className="section-title">
        <h2>{ios ? 'Cara di iPhone' : 'Cara di Android (Chrome)'}</h2>
      </div>

      {ios ? (
        <div className="card">
          <Langkah
            no={1}
            judul="Buka di Safari"
            detail="Install cuma bisa lewat Safari di iPhone/iPad, bukan Chrome."
            aktif
          />
          <Langkah
            no={2}
            judul="Tap tombol Share (kotak dengan panah ke atas)"
            detail="Ada di toolbar bawah Safari."
            aktif
          />
          <Langkah
            no={3}
            judul='Pilih "Add to Home Screen" / "Tambah ke Layar Utama"'
            detail="Scroll daftar menu ke bawah kalau nggak kelihatan."
            aktif
          />
          <Langkah
            no={4}
            judul='Tap "Add"'
            detail="Ikon api muncul di layar utama. Buka dan langsung bisa dipakai offline."
            aktif
          />
        </div>
      ) : (
        <div className="card">
          <Langkah
            no={1}
            judul="Buka aplikasi ini di Chrome"
            detail={
              didukung
                ? 'Browser lu support install otomatis. Kalau dialog nggak muncul, lanjut langkah 2.'
                : 'Pakai Chrome, Edge, atau Samsung Internet versi terbaru.'
            }
            aktif
          />
          <Langkah
            no={2}
            judul="Tap menu ⋮ di kanan atas"
            detail="Kalau tombol Install muncul di banner bawah, bisa langsung tap itu."
            aktif
          />
          <Langkah
            no={3}
            judul='Pilih "Install app" atau "Tambahkan ke Layar Utama"'
            detail='Di beberapa HP tulisannya "Add to Home screen".'
            aktif
          />
          <Langkah
            no={4}
            judul='Tap "Install"'
            detail="Ikon api muncul di layar utama, bisa dibuka full-screen tanpa address bar."
            aktif
          />
        </div>
      )}

      {/* Kenapa PWA */}
      <div className="section-title">
        <h2>Kenapa nggak APK?</h2>
      </div>
      <div className="card">
        <div style={{ fontSize: 12.5, color: 'var(--dim)', lineHeight: 1.7 }}>
          Buat aplikasi seperti ini, <b style={{ color: 'var(--txt)' }}>PWA lebih pas</b>:
        </div>
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 9 }}>
          {[
            'Nggak perlu upload ke Google Play, nggak perlu review',
            'Ukuran cuma ±250 KB, nggak makan storage',
            'Update otomatis tiap buka — nggak perlu install ulang',
            'Semua data tetap di HP lu (offline)',
            'Bisa juga dipakai di iPhone & laptop',
          ].map((t) => (
            <div
              key={t}
              style={{ display: 'flex', gap: 9, alignItems: 'flex-start', fontSize: 12.5 }}
            >
              <span style={{ color: 'var(--green)', flex: 'none' }}>✓</span>
              <span style={{ color: 'var(--dim)' }}>{t}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="tip-box" style={{ marginTop: 14 }}>
        <IcInfo size={13} /> <b>Kalau tombol install nggak muncul:</b> pastikan halaman dibuka
        lewat <b>https://</b> (bukan http), lalu refresh. Chrome Android biasanya langsung
        nawarin sendiri lewat banner di bawah.
      </div>

      <p className="small-note">
        Setelah dipasang, buka dari ikon di layar utama — jangan dari browser — biar
        tampilannya full-screen dan timer tetap akurat.
      </p>
    </div>
  )
}
