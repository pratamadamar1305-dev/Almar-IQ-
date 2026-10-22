import { useCallback, useEffect, useRef, useState } from 'react'
import { useApp } from '../store'
import { fmtWaktu } from '../lib/utils'
import { getar, sfx } from '../lib/audio'
import { Btn, Confetti, ProgressRing, Segmented, Stepper } from '../components/ui'
import { IcBack, IcPause, IcPlay, IcRefresh } from '../components/Icon'
import { go } from '../lib/nav'

type Fase = 'idle' | 'prep' | 'round' | 'rest' | 'done'

export default function TimerGong() {
  const { state, toast } = useApp()
  const [rounds, setRounds] = useState(2)
  const [roundSec, setRoundSec] = useState(90)
  const [restSec, setRestSec] = useState(60)

  const [fase, setFase] = useState<Fase>('idle')
  const [ronde, setRonde] = useState(1)
  const [remaining, setRemaining] = useState(0)
  const [durasi, setDurasi] = useState(1)
  const [running, setRunning] = useState(false)
  const [confetti, setConfetti] = useState(0)

  const endAt = useRef(0)
  const faseRef = useRef<Fase>('idle')
  const rondeRef = useRef(1)
  const cfg = useRef({ rounds, roundSec, restSec })
  cfg.current = { rounds, roundSec, restSec }
  faseRef.current = fase
  rondeRef.current = ronde

  const beep = useCallback(
    (fn: () => void) => {
      if (state.suara) fn()
    },
    [state.suara]
  )

  const getarIf = useCallback(
    (p: number | number[]) => {
      if (state.getar) getar(p)
    },
    [state.getar]
  )

  const masuk = useCallback(
    (f: Fase, detik: number) => {
      const c = cfg.current
      setFase(f)
      setDurasi(detik)
      setRemaining(detik)
      endAt.current = Date.now() + detik * 1000
      setRunning(true)

      if (f === 'round') {
        beep(() => sfx.gong())
        getarIf([120, 60, 120])
        toast(`Ronde ${rondeRef.current} — GAS! 🔥`, 'sukses')
      } else if (f === 'rest') {
        beep(() => sfx.restEnd())
        getarIf([60, 80, 60])
        toast('Istirahat 1 menit — duduk, napas 😮‍💨', 'info')
      } else if (f === 'prep') {
        beep(() => sfx.blip())
      } else if (f === 'done') {
        beep(() => sfx.complete())
        getarIf([100, 60, 100, 60, 200])
        setConfetti((x) => x + 1)
        toast('Simulasi selesai. Juara! 🏆', 'sukses')
      }
      void c
    },
    [beep, getarIf, toast]
  )

  const lanjut = useCallback(() => {
    const c = cfg.current
    const f = faseRef.current
    if (f === 'prep') {
      rondeRef.current = 1
      setRonde(1)
      masuk('round', c.roundSec)
    } else if (f === 'round') {
      if (rondeRef.current >= c.rounds) {
        setRunning(false)
        masuk('done', 0)
      } else {
        masuk('rest', c.restSec)
      }
    } else if (f === 'rest') {
      rondeRef.current += 1
      setRonde(rondeRef.current)
      masuk('round', c.roundSec)
    }
  }, [masuk])

  const lanjutRef = useRef(lanjut)
  lanjutRef.current = lanjut

  useEffect(() => {
    if (!running || fase === 'idle' || fase === 'done') return
    let lastBeep = -1
    const tick = () => {
      const rem = Math.max(0, Math.ceil((endAt.current - Date.now()) / 1000))
      setRemaining(rem)
      if (rem <= 3 && rem > 0 && rem !== lastBeep) {
        lastBeep = rem
        if (state.suara) sfx.tick()
      }
      if (rem <= 0) {
        setRunning(false)
        lanjutRef.current()
      }
    }
    tick()
    const id = window.setInterval(tick, 120)
    return () => window.clearInterval(id)
  }, [running, fase, state.suara])

  const mulai = () => {
    setConfetti(0)
    rondeRef.current = 1
    setRonde(1)
    masuk('prep', 3)
  }

  const stop = () => {
    setRunning(false)
    setFase('idle')
    setRemaining(0)
  }

  const aktifFase = fase === 'round' || fase === 'rest' || fase === 'prep'
  const progress = durasi ? 1 - remaining / durasi : 0
  const warnaRing = fase === 'rest' ? 'url(#gradHijau)' : 'url(#gradApi)'

  return (
    <div className="screen">
      <Confetti fire={confetti} />

      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <button className="icon-btn" onClick={() => go('/')} aria-label="Kembali">
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
            Timer Gong
          </div>
          <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 2 }}>
            Simulasi Tarung
          </div>
        </div>
      </div>

      <div className="gong-wrap">
        <div className={`gong-phase${fase === 'rest' ? ' rest' : ''}`}>
          {fase === 'idle' && 'Siap-siap'}
          {fase === 'prep' && 'Bersiap…'}
          {fase === 'round' && `Ronde ${ronde} / ${rounds}`}
          {fase === 'rest' && 'Istirahat'}
          {fase === 'done' && 'Selesai 🏆'}
        </div>

        <ProgressRing progress={aktifFase ? progress : fase === 'done' ? 1 : 0} color={warnaRing}>
          <div className="ring-time">{aktifFase ? fmtWaktu(remaining) : '—:—'}</div>
          <div className="ring-sub">
            {fase === 'rest' ? 'istirahat' : fase === 'prep' ? 'mulai' : 'ronde'}
          </div>
        </ProgressRing>

        <div className="gong-rounds">
          {Array.from({ length: rounds }).map((_, i) => (
            <span
              key={i}
              className={`gong-round-dot ${
                fase === 'done' || (i + 1 < ronde) ? 'done' : i + 1 === ronde && fase === 'round' ? 'now' : ''
              }`}
            />
          ))}
        </div>

        <div style={{ width: '100%', marginTop: 22, display: 'flex', gap: 10 }}>
          {!aktifFase ? (
            <Btn size="lg" onClick={mulai} style={{ flex: 1 }}>
              <IcPlay size={17} /> {fase === 'done' ? 'Ulang Simulasi' : 'Mulai'}
            </Btn>
          ) : (
            <>
              <Btn
                variant="ghost"
                onClick={() => {
                  if (running) {
                    setRunning(false)
                  } else {
                    endAt.current = Date.now() + Math.max(1, remaining) * 1000
                    setRunning(true)
                  }
                }}
                style={{ flex: 1 }}
              >
                {running ? <IcPause size={16} /> : <IcPlay size={16} />}
                {running ? 'Pause' : 'Lanjut'}
              </Btn>
              <Btn variant="ghost" onClick={stop} style={{ flex: 1 }}>
                <IcRefresh size={16} /> Reset
              </Btn>
            </>
          )}
        </div>
      </div>

      <div className="section-title">
        <h2>Pengaturan</h2>
      </div>
      <div className="card">
        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Jumlah ronde</div>
            <div className="sr-desc">Peraturan umur kelas 6: 2 ronde</div>
          </div>
          <Stepper value={rounds} onChange={setRounds} min={1} max={10} />
        </div>
        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Durasi ronde</div>
            <div className="sr-desc">Resmi: 1 menit 30 detik</div>
          </div>
          <Stepper
            value={roundSec}
            onChange={setRoundSec}
            min={15}
            max={300}
            step={15}
            suffix=" dtk"
          />
        </div>
        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Istirahat</div>
            <div className="sr-desc">Resmi: 1 menit</div>
          </div>
          <Stepper
            value={restSec}
            onChange={setRestSec}
            min={10}
            max={180}
            step={10}
            suffix=" dtk"
          />
        </div>
        <div style={{ marginTop: 14 }}>
          <Segmented
            value={rounds === 2 && roundSec === 90 && restSec === 60 ? 'resmi' : 'custom'}
            options={[
              { value: 'resmi', label: 'Resmi 2×1:30' },
              { value: 'custom', label: 'Custom' },
            ]}
            onChange={(v) => {
              if (v === 'resmi') {
                setRounds(2)
                setRoundSec(90)
                setRestSec(60)
              }
            }}
          />
        </div>
      </div>

      <div className="card" style={{ marginTop: 14 }}>
        <div style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--orange2)' }}>
          Aturan poin tarung
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--dim)', marginTop: 8, lineHeight: 1.65 }}>
          Pukulan kena body = <b style={{ color: 'var(--txt)' }}>1 poin</b> · Tendangan body ={' '}
          <b style={{ color: 'var(--txt)' }}>2 poin</b> · Bantingan ={' '}
          <b style={{ color: 'var(--txt)' }}>3 poin</b> · Tangkis + balas ={' '}
          <b style={{ color: 'var(--txt)' }}>bonus +1</b>
        </div>
        <div className="warn-box">
          <b>Dilarang:</b> pukul kepala/leher/kemaluan, siku, dengkul, narik baju sembarangan.
        </div>
      </div>
    </div>
  )
}
