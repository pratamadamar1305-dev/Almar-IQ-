import { useMemo } from 'react'
import { useApp } from '../store'
import { SESI } from '../lib/data'
import { go } from '../lib/nav'
import {
  addDays,
  bulanKey,
  HARI_NAMA,
  startOfDay,
  tanggalPanjang,
  toKey,
} from '../lib/utils'
import { isOpsional, isWajib, infoStreak, isLogValid, petaLog } from '../lib/streak'
import type { DayId } from '../lib/types'
import { mintaIzin } from '../lib/izin'
import { Btn, useNow } from '../components/ui'
import { IcFlame, IcMoon, IcPlay, IcTimer, IcTrophy } from '../components/Icon'

const URUT: Array<{ day: DayId; dow: number; short: string }> = [
  { day: 'senin', dow: 1, short: 'Sen' },
  { day: 'selasa', dow: 2, short: 'Sel' },
  { day: 'kamis', dow: 4, short: 'Kam' },
  { day: 'jumat', dow: 5, short: 'Jum' },
]

function dayIdFor(dow: number): DayId | null {
  if (dow === 1) return 'senin'
  if (dow === 2) return 'selasa'
  if (dow === 4) return 'kamis'
  if (dow === 5) return 'jumat'
  return null
}

export default function Home() {
  const { state, set, streak, sisaFreezeBulan, level, xpDiLevel, xpLevelMax, toast } = useApp()

  const now = useNow(60000)
  const today = startOfDay(now)
  const todayKey = toKey(today)
  const dow = today.getDay()
  const dayId = dayIdFor(dow)

  const byDate = useMemo(() => petaLog(state.logs), [state.logs])
  const info = useMemo(
    () => infoStreak(state.logs, state.freezes, state.mode, now, state.streakTerbaik),
    [state.logs, state.freezes, state.mode, now, state.streakTerbaik]
  )

  const doneHariIni = isLogValid(byDate.get(todayKey))
  const sesiHariIni = dayId ? SESI[dayId] : null
  const opsionalHariIni = dayId ? isOpsional(now, state.mode) : false
  const wajibHariIni = isWajib(now, state.mode)

  // Tanggal untuk tiap hari di minggu berjalan (Senin sebagai awal)
  const minggu = useMemo(() => {
    const offsetKeSenin = (dow + 6) % 7
    const senin = addDays(today, -offsetKeSenin)
    return URUT.map((u) => {
      const tanggal = addDays(senin, u.dow - 1)
      const log = byDate.get(toKey(tanggal))
      return {
        ...u,
        tanggal,
        key: toKey(tanggal),
        done: isLogValid(log),
        ringan: !!log && !log.valid,
        isToday: toKey(tanggal) === todayKey,
        wajib: isWajib(tanggal, state.mode),
      }
    })
  }, [today, dow, byDate, todayKey, state.mode])

  const jalankanSesi = (d: DayId) => {
    const sesi = SESI[d]
    set((s) => ({
      ...s,
      aktif: {
        day: d,
        tanggal: toKey(new Date()),
        startedAt: Date.now(),
        index: 0,
        setDone: 0,
        doneItems: 0,
        totalSet: 0,
        totalRep: 0,
        elapsed: 0,
      },
    }))
    toast(`Sesi ${sesi.label} dimulai. Gas! 💪`, 'sukses')
    go('/player')
  }

  const mulai = (d: DayId) => {
    if (!state.izinSudahDiingatkan) mintaIzin(() => jalankanSesi(d))
    else jalankanSesi(d)
  }

  const lanjutkan = () => go('/player')

  const flameSize = streak === 0 ? 0.72 : streak < 3 ? 0.85 : streak < 7 ? 1 : streak < 14 ? 1.12 : 1.25
  const heroBorder =
    streak >= 30
      ? 'rgba(168,85,247,0.5)'
      : streak >= 14
        ? 'rgba(239,68,68,0.5)'
        : 'rgba(255,107,26,0.28)'

  return (
    <div className="screen">
      {/* ---------------- STREAK HERO ---------------- */}
      <div className="streak-hero fade-in" style={{ borderColor: heroBorder }}>
        <div className="streak-top">
          <div>
            <div className="streak-label">
              {streak === 0 ? 'Api belum nyala' : 'Streak latihan'}
            </div>
            <div className="streak-num-row">
              <span className="streak-num">{streak}</span>
              <span className="streak-unit">hari beruntun</span>
            </div>
          </div>
          <div className="streak-flame" style={{ fontSize: 42 * flameSize }}>
            {streak === 0 ? '🕯️' : streak >= 30 ? '🔥' : '🔥'}
          </div>
        </div>

        <div className="streak-sub">
          <span className="pill amber">
            <IcTrophy size={13} /> Rekor {info.terbaik}
          </span>
          <span className="pill cyan">🧊 {sisaFreezeBulan}</span>
          <span className="pill green">⚡ {state.bonusFlame} bonus</span>
        </div>

        <div className="streak-progress">
          <div className="xp-top">
            <span>
              Level {level} · {['Pemula', 'Rajin', 'Kuat', 'Petarung', 'Jagoan'][level - 1] ?? 'Legenda'}
            </span>
            <span>
              {xpDiLevel}/{xpLevelMax} XP
            </span>
          </div>
          <div className="xp-bar">
            <i style={{ width: `${(xpDiLevel / xpLevelMax) * 100}%` }} />
          </div>
        </div>

        {info.bisaNaikHariIni ? (
          <div className="streak-cta">
            <div
              style={{
                fontSize: 12.5,
                color: 'rgba(255,255,255,0.72)',
                marginBottom: 10,
                lineHeight: 1.5,
              }}
            >
              {streak > 0
                ? `Selesaikan latihan hari ini biar api lu lanjut ke ${streak + 1} hari.`
                : 'Selesaikan latihan hari ini buat nyalain api pertama lu.'}
            </div>
            {state.aktif ? (
              <Btn size="sm" onClick={lanjutkan} style={{ width: '100%' }}>
                <IcPlay size={15} /> Lanjutkan sesi
              </Btn>
            ) : null}
          </div>
        ) : doneHariIni ? (
          <div className="streak-cta">
            <div className="pill green" style={{ fontSize: 12.5, padding: '9px 14px' }}>
              ✅ Hari ini beres — api lu aman!
            </div>
          </div>
        ) : wajibHariIni ? null : (
          <div className="streak-cta">
            <div className="pill amber" style={{ fontSize: 12.5, padding: '9px 14px' }}>
              <IcMoon size={13} /> Hari libur — istirahat juga bagian dari latihan
            </div>
          </div>
        )}
      </div>

      {/* ---------------- SESI HARI INI ---------------- */}
      <div className="section-title">
        <h2>Hari ini · {HARI_NAMA[dow]}</h2>
        <span style={{ fontSize: 11.5, color: 'var(--dim2)', fontWeight: 600 }}>
          {tanggalPanjang(today).split(', ')[1]}
        </span>
      </div>

      {state.aktif ? (
        <div className="sesi-card" style={{ borderColor: 'rgba(255,107,26,0.4)' }}>
          <span className="sesi-badge">⏸ Sesi tertunda</span>
          <div className="sesi-title">
            {SESI[state.aktif.day]?.label} — {SESI[state.aktif.day]?.tema}
          </div>
          <div className="sesi-meta">
            <span>📍 Gerakan ke-{state.aktif.index + 1}</span>
            <span>✅ {state.aktif.totalSet} set selesai</span>
          </div>
          <Btn style={{ marginTop: 16 }} onClick={lanjutkan}>
            <IcPlay size={16} /> Lanjutkan Sesi
          </Btn>
        </div>
      ) : sesiHariIni ? (
        <div className="sesi-card">
          {doneHariIni ? (
            <span className="sesi-badge done">✅ Selesai hari ini</span>
          ) : opsionalHariIni ? (
            <span className="sesi-badge opsional">Opsional</span>
          ) : (
            <span className="sesi-badge">Hari wajib</span>
          )}

          <div className="sesi-title">{sesiHariIni.tema}</div>

          <div className="sesi-meta">
            <span>
              <IcTimer size={13} /> {sesiHariIni.durasiMenit} menit
            </span>
            <span>
              🎯{' '}
              {sesiHariIni.blok.reduce(
                (n, b) => n + b.gerakan.length * (b.rounds ?? 1),
                0
              )}{' '}
              gerakan
            </span>
            <span>🧰 sapu + tas</span>
          </div>

          <div
            style={{
              fontSize: 12.5,
              color: 'var(--dim)',
              marginTop: 12,
              lineHeight: 1.55,
            }}
          >
            {sesiHariIni.fokus}
          </div>

          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <Btn onClick={() => mulai(sesiHariIni.day)} style={{ flex: 1 }}>
              <IcPlay size={16} /> {doneHariIni ? 'Ulangi' : 'Mulai Latihan'}
            </Btn>
            <Btn variant="ghost" onClick={() => go(`/hari/${sesiHariIni.day}`)} style={{ width: 'auto' }}>
              Detail
            </Btn>
          </div>
        </div>
      ) : (
        <div className="sesi-card libur">
          <span className="sesi-badge" style={{ background: 'var(--card3)', color: 'var(--dim)', borderColor: 'var(--line2)' }}>
            <IcMoon size={11} /> Hari libur
          </span>
          <div className="sesi-title">Istirahat dulu, besok gas lagi 💪</div>
          <div className="sesi-meta">
            <span>Rabu–Sabtu–Minggu = recovery</span>
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <Btn variant="ghost" onClick={() => go('/hari/kamis')}>
              Lihat jadwal Kamis
            </Btn>
          </div>
        </div>
      )}

      {/* ---------------- MINGGU INI ---------------- */}
      <div className="section-title">
        <h2>Minggu ini</h2>
        <button className="link" onClick={() => go('/progres')}>
          Lihat progres →
        </button>
      </div>

      <div className="week-row">
        {minggu.map((m) => {
          const isOps = isOpsional(m.tanggal, state.mode)
          return (
            <button
              key={m.day}
              className={`week-dot ${m.done ? 'done' : ''} ${m.isToday && !m.done ? 'active' : ''}`}
              onClick={() => go(`/hari/${m.day}`)}
            >
              <span className="wd-abbr">{m.short}</span>
              <span className="wd-ico">
                {m.done ? '✅' : m.ringan ? '🟡' : isOps ? '⭐' : m.isToday ? '🔥' : '·'}
              </span>
              <span
                style={{
                  fontSize: 9.5,
                  color: 'var(--dim2)',
                  fontWeight: 700,
                  letterSpacing: '0.04em',
                }}
              >
                {m.wajib ? 'WAJIB' : isOps ? 'OPS' : 'LIBUR'}
              </span>
            </button>
          )
        })}
      </div>

      {/* ---------------- QUICK ACTIONS ---------------- */}
      <div className="section-title">
        <h2>Cepat</h2>
      </div>

      <div className="stat-grid">
        <button
          className="stat"
          style={{ textAlign: 'left' }}
          onClick={() => go('/timer')}
        >
          <div className="s-label">Timer Gong</div>
          <div className="s-val">2 × 1:30</div>
          <div style={{ fontSize: 11, color: 'var(--dim2)', marginTop: 4 }}>
            Simulasi tarung →
          </div>
        </button>
        <button className="stat" style={{ textAlign: 'left' }} onClick={() => go('/progres')}>
          <div className="s-label">Total sesi</div>
          <div className="s-val">
            {state.logs.filter((l) => l.valid).length}
            <small>sesi</small>
          </div>
          <div style={{ fontSize: 11, color: 'var(--dim2)', marginTop: 4 }}>
            Lihat heatmap →
          </div>
        </button>
      </div>

      <div style={{ marginTop: 10 }}>
        <Btn variant="ghost" onClick={() => go('/aturan')}>
          <IcFlame size={16} /> Aturan aman & peraturan tarung
        </Btn>
      </div>

      <p className="small-note">
        Alat cuma sapu kayu + tas sekolah 2–4 kg. Selalu izin ortu/pelatih sebelum latihan.
      </p>
    </div>
  )
}
