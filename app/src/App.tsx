import { useEffect, useState } from 'react'
import { useApp } from './store'
import { go, useRoute } from './lib/nav'
import { EVENT_IZIN, ambilAksiIzin, buangAksiIzin } from './lib/izin'
import { unlockAudio } from './lib/audio'
import type { DayId } from './lib/types'
import { Btn, Modal, ToastHost } from './components/ui'
import { IcChart, IcGear, IcHome, IcMoon, IcSun, IcTimer } from './components/Icon'
import Home from './screens/Home'
import Detail from './screens/Detail'
import Player from './screens/Player'
import TimerGong from './screens/TimerGong'
import Progress from './screens/Progress'
import Settings from './screens/Settings'
import Aturan from './screens/Aturan'
import Install from './screens/Install'
import InstallBanner from './components/InstallBanner'
import { useSWUpdate } from './lib/pwa'

const HARI_VALID: DayId[] = ['senin', 'selasa', 'kamis', 'jumat']

function Topbar() {
  const { state, set } = useApp()
  return (
    <div className="topbar">
      <div className="brand">
        <div className="brand-mark">{state.nama ? '🥋' : '🔥'}</div>
        <div className="brand-txt">
          <b>DOJO TARUNG</b>
          <span>{state.nama ? `Punyanya ${state.nama}` : 'Latihan harian'}</span>
        </div>
      </div>
      <button
        className="icon-btn"
        onClick={() => set((s) => ({ ...s, tema: s.tema === 'dark' ? 'light' : 'dark' }))}
        aria-label="Ganti tema"
      >
        {state.tema === 'dark' ? <IcSun size={19} /> : <IcMoon size={19} />}
      </button>
    </div>
  )
}

function BottomNav({ route }: { route: string }) {
  const items = [
    { path: '/', label: 'Home', icon: IcHome, match: ['/', '/hari'] },
    { path: '/timer', label: 'Timer', icon: IcTimer, match: ['/timer'] },
    { path: '/progres', label: 'Progres', icon: IcChart, match: ['/progres'] },
    { path: '/setting', label: 'Setting', icon: IcGear, match: ['/setting', '/aturan'] },
  ]
  return (
    <nav className="bottom-nav">
      {items.map((it) => {
        const active = it.match.some(
          (m) => (m === '/' ? route === '/' || route.startsWith('/hari') : route.startsWith(m))
        )
        const Ico = it.icon
        return (
          <button
            key={it.path}
            className={`nav-item${active ? ' active' : ''}`}
            onClick={() => go(it.path)}
          >
            <Ico size={21} strokeWidth={active ? 2.2 : 1.9} />
            <span>{it.label}</span>
          </button>
        )
      })}
    </nav>
  )
}

function IzinGate() {
  const { set } = useApp()
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const onMinta = () => setOpen(true)
    window.addEventListener(EVENT_IZIN, onMinta)
    return () => window.removeEventListener(EVENT_IZIN, onMinta)
  }, [])

  const tutup = (izinkan: boolean) => {
    set((s) => ({
      ...s,
      izinSudahDiingatkan: true,
      izinOrtu: izinkan ? true : s.izinOrtu,
    }))
    setOpen(false)
    if (izinkan) {
      const aksi = ambilAksiIzin()
      window.setTimeout(() => aksi?.(), 260)
    } else {
      buangAksiIzin()
    }
  }

  return (
    <Modal
      open={open}
      onClose={() => tutup(false)}
      title="Sebelum mulai 🥋"
      actions={
        <>
          <Btn onClick={() => tutup(true)}>Aku udah izin — mulai!</Btn>
          <Btn variant="ghost" onClick={() => tutup(false)}>
            Batal
          </Btn>
        </>
      }
    >
      <p>
        Latihan ini pakai <b style={{ color: 'var(--txt)' }}>sapu kayu + tas sekolah</b>. Pastikan:
      </p>
      <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          'Tas isi max 4 kg (1–2 buku + botol air)',
          'Lantai nggak licin, sapu nggak retak',
          'Ada ortu/pelatih yang tahu lu latihan',
          'Minum tiap 15 menit',
        ].map((t) => (
          <div
            key={t}
            style={{
              display: 'flex',
              gap: 9,
              alignItems: 'center',
              fontSize: 13,
              color: 'var(--dim)',
            }}
          >
            <span style={{ color: 'var(--green)' }}>✓</span>
            {t}
          </div>
        ))}
      </div>
    </Modal>
  )
}

function UpdateToast() {
  const { tersedia, terapkan } = useSWUpdate()
  if (!tersedia) return null
  return (
    <div
      style={{
        position: 'fixed',
        left: '50%',
        transform: 'translateX(-50%)',
        top: 'max(12px, env(safe-area-inset-top))',
        zIndex: 220,
        width: '100%',
        maxWidth: 440,
        padding: '0 14px',
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '10px 12px',
          borderRadius: 14,
          background: 'var(--card3)',
          border: '1px solid rgba(255,107,26,0.4)',
          boxShadow: '0 16px 40px -14px rgba(0,0,0,0.8)',
          fontSize: 12.5,
          fontWeight: 600,
        }}
      >
        <span style={{ flex: 1 }}>Versi baru tersedia</span>
        <button
          className="btn btn-primary btn-sm"
          style={{ minHeight: 34, padding: '0 12px' }}
          onClick={terapkan}
        >
          Muat ulang
        </button>
      </div>
    </div>
  )
}

export default function App() {
  const route = useRoute()

  // unlock audio pada interaksi pertama (kebijakan autoplay browser)
  useEffect(() => {
    const onFirst = () => unlockAudio()
    window.addEventListener('pointerdown', onFirst, { once: true })
    window.addEventListener('keydown', onFirst, { once: true })
    return () => {
      window.removeEventListener('pointerdown', onFirst)
      window.removeEventListener('keydown', onFirst)
    }
  }, [])

  if (route.startsWith('/player')) {
    return (
      <>
        <Player />
        <ToastHost />
      </>
    )
  }

  let screen = <Home />
  if (route.startsWith('/hari/')) {
    const day = route.split('/')[2] as DayId
    screen = <Detail day={HARI_VALID.includes(day) ? day : 'senin'} />
  } else if (route.startsWith('/timer')) {
    screen = <TimerGong />
  } else if (route.startsWith('/progres')) {
    screen = <Progress />
  } else if (route.startsWith('/setting')) {
    screen = <Settings />
  } else if (route.startsWith('/aturan')) {
    screen = <Aturan />
  } else if (route.startsWith('/install')) {
    screen = <Install />
  }

  return (
    <>
      <div className="app-shell">
        <Topbar />
        <InstallBanner />
        {screen}
      </div>
      <BottomNav route={route} />
      <ToastHost />
      <UpdateToast />
      <IzinGate />
    </>
  )
}
