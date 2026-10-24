import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useApp } from '../store'
import { buildQueue, durasiGerakan, getSesi } from '../lib/data'
import { go } from '../lib/nav'
import { fmtWaktu, toKey, uid } from '../lib/utils'
import { hitungStreak, isWajib, MILESTONES, namaMilestone } from '../lib/streak'
import { getar, mintaWakeLock, sfx } from '../lib/audio'
import type { Gerakan, QueueItem, SessionLog } from '../lib/types'
import { Btn, Confetti, Modal, ProgressRing } from '../components/ui'
import { GerakanFig, GerakanFigPanel } from '../components/GerakanFig'
import { IcCheck, IcPause, IcPlay, IcRefresh, IcSkip, IcX } from '../components/Icon'

type Phase = 'work' | 'rest'

interface Hasil {
  valid: boolean
  itemsDone: number
  itemsTotal: number
  totalSet: number
  totalRep: number
  durasiDetik: number
  xp: number
  streakBaru: number
  milestone: number[]
  bonus: boolean
  hariLibur: boolean
}

export default function Player() {
  const { state, set, toast } = useApp()

  const aktif = state.aktif
  const sesi = aktif ? getSesi(aktif.day) : null
  const queue = useMemo(() => (sesi ? buildQueue(sesi) : []), [sesi])

  const [phase, setPhase] = useState<Phase>('work')
  const [running, setRunning] = useState(true)
  const [endAt, setEndAt] = useState(0)
  const [durasi, setDurasi] = useState(1)
  const [remaining, setRemaining] = useState(1)
  const [showCara, setShowCara] = useState(false)
  const [hasil, setHasil] = useState<Hasil | null>(null)
  const [konfirmasi, setKonfirmasi] = useState<null | 'ringan'>(null)
  const [confetti, setConfetti] = useState(0)

  const started = useRef(false)
  const beeped = useRef(-1)
  const phaseRef = useRef<Phase>('work')
  const itemRef = useRef<QueueItem | null>(null)
  const aktifRef = useRef(aktif)
  const queueRef = useRef(queue)
  const endHandler = useRef<() => void>(() => {})
  const aksiLock = useRef(0)

  phaseRef.current = phase
  aktifRef.current = aktif
  queueRef.current = queue

  const item = aktif && queue.length ? queue[Math.min(aktif.index, queue.length - 1)] : null
  itemRef.current = item

  const totalSetsTarget = useMemo(
    () => queue.reduce((n, q) => n + q.gerakan.sets, 0),
    [queue]
  )
  const setsDone = aktif ? aktif.totalSet : 0
  const progress = totalSetsTarget ? Math.min(1, setsDone / totalSetsTarget) : 0

  const suara = state.suara
  const getarOn = state.getar

  /* ------------------------------ timer engine ------------------------------ */
  const mulaiFase = useCallback(
    (p: Phase, detik: number) => {
      beeped.current = -1
      setPhase(p)
      setDurasi(Math.max(1, detik))
      setRemaining(Math.max(1, detik))
      setEndAt(Date.now() + Math.max(1, detik) * 1000)
      setRunning(true)
    },
    []
  )

  const mulaiKerja = useCallback(
    (g: Gerakan) => mulaiFase('work', durasiGerakan(g)),
    [mulaiFase]
  )

  /* ------------------------------ aksi sesi ------------------------------ */
  const finalisasi = useCallback(
    (itemsDone: number, totalSet: number, totalRep: number) => {
      const a = aktifRef.current
      const q = queueRef.current
      if (!a) return
      const totalItems = q.length
      const ratio = totalItems > 0 ? itemsDone / totalItems : 0
      const valid = ratio >= 0.8
      const durasiDetik = Math.max(1, Math.round((Date.now() - a.startedAt) / 1000))
      const sesiAktif = getSesi(a.day)
      const bonus = !!sesiAktif?.opsional && valid
      const hariLibur = !isWajib(new Date(), state.mode)
      const xp = Math.round(totalSet * 10 + (valid ? 50 : 10) + (bonus ? 100 : 0))

      const log: SessionLog = {
        id: uid(),
        tanggal: toKey(new Date()),
        day: a.day,
        selesai: true,
        valid,
        itemsDone,
        itemsTotal: totalItems,
        durasiDetik,
        totalSet,
        totalRep,
        xp,
        ts: Date.now(),
      }

      const logsBaru = [...state.logs, log]
      const streakBaru = hitungStreak(logsBaru, state.freezes, state.mode, new Date())
      const milestone = MILESTONES.filter(
        (m) => streakBaru >= m && !state.seenMilestones.includes(m)
      )

      set((s) => ({
        ...s,
        aktif: null,
        logs: [...s.logs, log],
        xp: s.xp + xp,
        bonusFlame: s.bonusFlame + (bonus ? 1 : 0),
        streakTerbaik: Math.max(s.streakTerbaik, streakBaru),
        seenMilestones: Array.from(new Set([...s.seenMilestones, ...milestone])),
      }))

      setRunning(false)
      setHasil({
        valid,
        itemsDone,
        itemsTotal: totalItems,
        totalSet,
        totalRep,
        durasiDetik,
        xp,
        streakBaru,
        milestone,
        bonus,
        hariLibur,
      })

      if (valid) {
        setConfetti((c) => c + 1)
        if (suara) sfx.complete()
        if (getarOn) getar([60, 40, 90, 40, 140])
        if (milestone.length) window.setTimeout(() => suara && sfx.levelUp(), 700)
      }
    },
    [state.logs, state.freezes, state.mode, state.seenMilestones, set, suara, getarOn]
  )

  const selesaikanSet = useCallback(() => {
    const a = aktifRef.current
    const it = itemRef.current
    if (!a || !it) return
    // guard: cegah dobel-hit (tap ganda / tap bareng timer habis)
    const now = Date.now()
    if (now - aksiLock.current < 220) return
    aksiLock.current = now
    const ger = it.gerakan
    const nextSetDone = a.setDone + 1
    const nextTotalSet = a.totalSet + 1
    const nextTotalRep =
      a.totalRep + (ger.tipe === 'rep' ? (ger.reps ?? 0) * (ger.perSisi ? 2 : 1) : 0)

    if (suara) sfx.setDone()
    if (getarOn) getar(35)

    if (nextSetDone >= ger.sets) {
      const nextIndex = a.index + 1
      const doneItems = a.doneItems + 1
      if (nextIndex >= queueRef.current.length) {
        finalisasi(doneItems, nextTotalSet, nextTotalRep)
        return
      }
      set((s) =>
        s.aktif
          ? {
              ...s,
              aktif: {
                ...s.aktif,
                index: nextIndex,
                setDone: 0,
                doneItems,
                totalSet: nextTotalSet,
                totalRep: nextTotalRep,
              },
            }
          : s
      )
      const nextItem = queueRef.current[nextIndex]
      const bedaRonde = !!(nextItem.round && it.round && nextItem.round !== it.round)
      const restRonde = nextItem.restRonde ?? 0
      if (bedaRonde && restRonde > 0) {
        mulaiFase('rest', restRonde)
      } else {
        mulaiKerja(nextItem.gerakan)
      }
    } else {
      set((s) =>
        s.aktif
          ? {
              ...s,
              aktif: {
                ...s.aktif,
                setDone: nextSetDone,
                totalSet: nextTotalSet,
                totalRep: nextTotalRep,
              },
            }
          : s
      )
      mulaiFase('rest', ger.restDetik ?? state.restDetik)
    }
  }, [finalisasi, mulaiKerja, mulaiFase, set, suara, getarOn, state.restDetik])

  const lewatiGerakan = useCallback(() => {
    const a = aktifRef.current
    if (!a) return
    const now = Date.now()
    if (now - aksiLock.current < 220) return
    aksiLock.current = now
    const nextIndex = a.index + 1
    if (nextIndex >= queueRef.current.length) {
      setKonfirmasi('ringan')
      return
    }
    set((s) =>
      s.aktif ? { ...s, aktif: { ...s.aktif, index: nextIndex, setDone: 0 } } : s
    )
    mulaiKerja(queueRef.current[nextIndex].gerakan)
  }, [mulaiKerja, set])

  const ulangTimer = useCallback(() => {
    const it = itemRef.current
    if (!it) return
    if (phaseRef.current === 'rest') {
      mulaiFase('rest', durasi)
    } else {
      mulaiKerja(it.gerakan)
    }
  }, [durasi, mulaiFase, mulaiKerja])

  const togglePause = useCallback(() => {
    if (running) {
      setRunning(false)
    } else {
      const sisa = Math.max(1, remaining)
      setEndAt(Date.now() + sisa * 1000)
      setRunning(true)
      beeped.current = -1
    }
  }, [running, remaining])

  /* ------------------------------ tick loop ------------------------------ */
  useEffect(() => {
    if (!running || !endAt) return
    const tick = () => {
      const rem = Math.max(0, Math.ceil((endAt - Date.now()) / 1000))
      setRemaining(rem)
      if (rem <= 3 && rem > 0 && rem !== beeped.current) {
        beeped.current = rem
        if (suara) sfx.tick()
      }
      if (rem <= 0) {
        setRunning(false)
        endHandler.current()
      }
    }
    tick()
    const id = window.setInterval(tick, 120)
    return () => window.clearInterval(id)
  }, [running, endAt, suara])

  /* ------------------------- handler akhir fase ------------------------- */
  useEffect(() => {
    endHandler.current = () => {
      if (phaseRef.current === 'rest') {
        const it = itemRef.current
        if (it) {
          if (suara) sfx.restEnd()
          if (getarOn) getar([40, 60, 40])
          mulaiKerja(it.gerakan)
        }
      } else {
        selesaikanSet()
      }
    }
  })

  /* --------------------------- start / wake lock --------------------------- */
  useEffect(() => {
    if (started.current) return
    const it = itemRef.current
    if (!it) return
    started.current = true
    mulaiKerja(it.gerakan)
  }, [mulaiKerja])

  useEffect(() => {
    let lock: { release: () => Promise<void> } | null = null
    let hidup = true
    mintaWakeLock().then((l) => {
      if (hidup) lock = l
      else l?.release().catch(() => {})
    })
    return () => {
      hidup = false
      lock?.release().catch(() => {})
    }
  }, [])

  /* ------------------------------ keyboard ------------------------------ */
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Space') {
        e.preventDefault()
        togglePause()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [togglePause])

  /* ------------------------------ render ------------------------------ */
  if (hasil) {
    return (
      <div className="player" style={{ justifyContent: 'center', textAlign: 'center' }}>
        <Confetti fire={confetti} />
        <div className="pop" style={{ fontSize: 74, lineHeight: 1 }}>
          {hasil.valid ? '🏆' : '💪'}
        </div>
        <h1
          style={{
            fontSize: 30,
            fontWeight: 800,
            letterSpacing: '-0.03em',
            marginTop: 14,
          }}
        >
          {hasil.valid ? 'Sesi Selesai!' : 'Sesi Ringan Tercatat'}
        </h1>
        <p style={{ fontSize: 14, color: 'var(--dim)', marginTop: 8, maxWidth: 300 }}>
          {hasil.valid
            ? hasil.hariLibur
              ? `Sesi bonus di hari libur — tercatat, tapi streak tetap ${hasil.streakBaru} hari. Besok kita gas lagi! 💪`
              : `Mantap! Api lu sekarang ${hasil.streakBaru} hari beruntun. ${hasil.bonus ? 'Bonus Selasa masuk! ⚡' : ''}`
            : 'Baru ' +
              hasil.itemsDone +
              ' dari ' +
              hasil.itemsTotal +
              ' gerakan. Ini nggak dihitung streak, tapi tetap kesimpen di riwayat. Besok kita genapin ya!'}
        </p>

        {hasil.milestone.length > 0 && (
          <div
            className="card"
            style={{
              marginTop: 18,
              width: '100%',
              borderColor: 'rgba(255,197,66,0.45)',
              background: 'rgba(255,197,66,0.08)',
            }}
          >
            <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.12em', color: 'var(--amber)' }}>
              BADGE BARU
            </div>
            {hasil.milestone.map((m) => (
              <div key={m} style={{ fontSize: 15, fontWeight: 700, marginTop: 6 }}>
                🏅 {namaMilestone(m)} · {m} hari
              </div>
            ))}
          </div>
        )}

        <div className="stat-grid" style={{ marginTop: 18, width: '100%' }}>
          <div className="stat">
            <div className="s-label">Durasi</div>
            <div className="s-val">{Math.round(hasil.durasiDetik / 60)}<small>mnt</small></div>
          </div>
          <div className="stat">
            <div className="s-label">Set selesai</div>
            <div className="s-val">{hasil.totalSet}</div>
          </div>
          <div className="stat">
            <div className="s-label">Total rep</div>
            <div className="s-val">{hasil.totalRep}</div>
          </div>
          <div className="stat">
            <div className="s-label">XP didapat</div>
            <div className="s-val" style={{ color: 'var(--purple)' }}>+{hasil.xp}</div>
          </div>
        </div>

        <div style={{ width: '100%', marginTop: 20 }}>
          <Btn size="lg" onClick={() => go('/')}>
            Balik ke Home
          </Btn>
        </div>
      </div>
    )
  }

  if (!aktif || !item) {
    return (
      <div className="player" style={{ justifyContent: 'center' }}>
        <div className="empty">
          <div className="e-ico">🤷</div>
          <p>Nggak ada sesi aktif.</p>
          <Btn style={{ marginTop: 16 }} onClick={() => go('/')}>
            Balik ke Home
          </Btn>
        </div>
      </div>
    )
  }

  const ger = item.gerakan
  const setNow = Math.min(aktif.setDone + 1, ger.sets)
  const isRest = phase === 'rest'

  return (
    <div className={`player${isRest ? ' rest' : ''}`}>
      {/* header */}
      <div className="player-head">
        <button className="icon-btn" onClick={() => go('/')} aria-label="Keluar">
          <IcX size={19} />
        </button>
        <div className="ph-mid">
          <div className="ph-step">
            {isRest ? 'Istirahat' : `${setNow === 1 ? 'Gerakan' : 'Set'} ${Math.min(setsDone + 1, totalSetsTarget)} / ${totalSetsTarget}`}
            {item.rounds ? ` · Ronde ${item.round}/${item.rounds}` : ''}
          </div>
          <div className="ph-bar">
            <i style={{ width: `${Math.max(4, progress * 100)}%` }} />
          </div>
        </div>
        <button
          className={`icon-btn${state.suara ? ' on' : ''}`}
          onClick={() => set((s) => ({ ...s, suara: !s.suara }))}
          aria-label="Suara"
        >
          {state.suara ? '🔊' : '🔇'}
        </button>
      </div>

      {/* body */}
      <div className="player-body">
        {isRest ? (
          <>
            <div className="player-area" style={{ color: '#4ade80' }}>
              Istirahat
            </div>
            <div className="player-name">Tarik napas 😮‍💨</div>
            <div className="player-cat">
              Set berikutnya: <b style={{ color: 'var(--txt)' }}>{ger.nama}</b>
            </div>
            <ProgressRing progress={durasi ? 1 - remaining / durasi : 1} color="url(#gradHijau)">
              <div className="ring-time">{fmtWaktu(remaining)}</div>
              <div className="ring-sub">istirahat</div>
            </ProgressRing>
            <button
              className="btn btn-ghost btn-sm"
              onClick={() => {
                setEndAt((e) => e + 15000)
                setDurasi((d) => d + 15)
              }}
            >
              +15 detik
            </button>
          </>
        ) : (
          <>
            <div className="player-area">
              {item.blok} · {ger.targetArea}
            </div>
            <div className="player-name">{ger.nama}</div>
            <div className="player-cat">
              {ger.sets}×{ger.tipe === 'hold' ? `${ger.holdDetik} dtk` : ger.tipe === 'drill' ? `${Math.round((ger.drillDetik ?? 0) / 60)} mnt` : ger.reps}
              {ger.perSisi ? ' per kaki' : ''} · set {setNow} dari {ger.sets}
            </div>

            <div className="player-fig">
              <GerakanFigPanel id={ger.id} label={`Ilustrasi ${ger.nama}`} />
            </div>

            <ProgressRing progress={durasi ? 1 - remaining / durasi : 1}>
              <div className="ring-time">{fmtWaktu(remaining)}</div>
              <div className="ring-sub">{running ? 'jalan' : 'pause'}</div>
            </ProgressRing>

            <div className="set-pips">
              {Array.from({ length: ger.sets }).map((_, i) => (
                <span
                  key={i}
                  className={`set-pip ${i < aktif.setDone ? 'done' : i === aktif.setDone ? 'now' : ''}`}
                />
              ))}
            </div>

            <button className="cara-toggle" onClick={() => setShowCara((v) => !v)}>
              {showCara ? '▲ Sembunyikan cara' : '▼ Lihat cara & kesalahan umum'}
            </button>

            {showCara && (
              <div className="cara-panel" style={{ textAlign: 'left', width: '100%' }}>
                <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 10 }}>
                  <GerakanFig id={ger.id} animate size={64} />
                  <div style={{ fontSize: 11.5, color: 'var(--dim2)', lineHeight: 1.5 }}>
                    Ilustrasi: posisi <b style={{ color: 'var(--orange2)' }}>awal</b> ↔{' '}
                    <b style={{ color: 'var(--orange2)' }}>akhir</b> bergantian.
                  </div>
                </div>
                <div>
                  <b>Cara (ikuti gambar 1 → 2):</b> {ger.cara}
                </div>
                {ger.salah && (
                  <div style={{ marginTop: 10, color: '#fca5a5' }}>
                    <b>❌ Jangan:</b> {ger.salah}
                  </div>
                )}
              </div>
            )}
          </>
        )}
      </div>

      {/* actions */}
      <div className="player-actions">
        <div className="player-row">
          <Btn variant="ghost" onClick={ulangTimer} style={{ flex: 1 }}>
            <IcRefresh size={16} /> Ulang
          </Btn>
          <Btn variant="ghost" onClick={togglePause} style={{ flex: 1 }}>
            {running ? <IcPause size={16} /> : <IcPlay size={16} />}
            {running ? 'Pause' : 'Lanjut'}
          </Btn>
        </div>

        {isRest ? (
          <Btn
            size="lg"
            onClick={() => {
              if (suara) sfx.restEnd()
              mulaiKerja(ger)
            }}
          >
            <IcSkip size={17} /> Lewati Istirahat
          </Btn>
        ) : (
          <Btn size="lg" onClick={selesaikanSet}>
            <IcCheck size={19} /> Set Selesai
          </Btn>
        )}

        <div className="player-row">
          <Btn variant="ghost" size="sm" onClick={lewatiGerakan} style={{ flex: 1 }}>
            <IcSkip size={15} /> Lewati gerakan
          </Btn>
          <Btn
            variant="danger"
            size="sm"
            onClick={() => setKonfirmasi('ringan')}
            style={{ flex: 1 }}
          >
            Selesai sesi
          </Btn>
        </div>
      </div>

      <Modal
        open={konfirmasi !== null}
        onClose={() => setKonfirmasi(null)}
        title="Selesaikan sesi sekarang?"
      >
        <p>
          Kamu baru menyelesaikan <b style={{ color: 'var(--txt)' }}>{aktif.doneItems}</b> dari{' '}
          <b style={{ color: 'var(--txt)' }}>{queue.length}</b> gerakan (
          {Math.round((aktif.doneItems / Math.max(1, queue.length)) * 100)}%).
          {aktif.doneItems / Math.max(1, queue.length) < 0.8 ? (
            <>
              {' '}
              Karena di bawah 80%, sesi ini dicatat sebagai <b style={{ color: 'var(--amber)' }}>sesi ringan</b> dan{' '}
              <b style={{ color: 'var(--txt)' }}>tidak dihitung untuk streak</b>.
            </>
          ) : (
            ' Sesi ini memenuhi syarat dan akan dihitung untuk streak. 🔥'
          )}
        </p>
        <div className="modal-actions">
          <Btn
            onClick={() => {
              setKonfirmasi(null)
              finalisasi(aktif.doneItems, aktif.totalSet, aktif.totalRep)
            }}
          >
            Ya, selesaikan
          </Btn>
          <Btn variant="ghost" onClick={() => setKonfirmasi(null)}>
            Lanjut latihan
          </Btn>
        </div>
      </Modal>
    </div>
  )
}
