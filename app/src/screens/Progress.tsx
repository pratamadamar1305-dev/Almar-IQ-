import { useMemo, useState } from 'react'
import { useApp } from '../store'
import {
  addDays,
  fmtDurasi,
  fromKey,
  HARI_NAMA,
  HARI_SINGKAT,
  startOfDay,
  tanggalPanjang,
  toKey,
} from '../lib/utils'
import {
  bisaFreeze,
  hitungStreak,
  MILESTONES,
  namaMilestone,
  petaLog,
  statusTanggal,
} from '../lib/streak'
import { Btn, Modal, Stepper } from '../components/ui'
import { IcBack, IcSnow, IcTrash } from '../components/Icon'
import { go } from '../lib/nav'

const TARGETS = [
  { key: 'pike', nama: 'Pike Push-Up', satuan: 'rep', awal: 8, target: 12, step: 1 },
  { key: 'kuda', nama: 'Kuda-Kuda Hold', satuan: 'dtk', awal: 30, target: 50, step: 5 },
  { key: 'finger', nama: 'Finger Push-Up Dinding', satuan: 'rep', awal: 8, target: 12, step: 1 },
  { key: 'tendangan', nama: 'Tendangan Stabil', satuan: '/5', awal: 1, target: 5, step: 1 },
]

export default function Progress() {
  const { state, set, streak, sisaFreezeBulan, toast, reset } = useApp()
  const today = startOfDay(new Date())
  const byDate = useMemo(() => petaLog(state.logs), [state.logs])
  const [edit, setEdit] = useState<string | null>(null)
  const [konfirmasiHapus, setKonfirmasiHapus] = useState(false)

  /* ------------------------------- heatmap ------------------------------- */
  const minggu = 9
  const cols = useMemo(() => {
    const offsetKeSenin = (today.getDay() + 6) % 7
    const senin = addDays(today, -offsetKeSenin)
    const start = addDays(senin, -7 * (minggu - 1))
    const out: Array<{ key: string; date: Date; status: string }[]> = []
    for (let w = 0; w < minggu; w++) {
      const col: Array<{ key: string; date: Date; status: string }> = []
      for (let d = 0; d < 7; d++) {
        const date = addDays(start, w * 7 + d)
        const key = toKey(date)
        col.push({
          key,
          date,
          status: statusTanggal(date, state.logs, state.freezes, state.mode, today),
        })
      }
      out.push(col)
    }
    return out
  }, [today, state.logs, state.freezes, state.mode, byDate])

  /* ------------------------------ freeze list ------------------------------ */
  const kandidatFreeze = useMemo(() => {
    const out: string[] = []
    for (let i = 1; i <= 7; i++) {
      const d = addDays(today, -i)
      const k = toKey(d)
      if (bisaFreeze(k, state.logs, state.freezes, state.mode, today) && !state.freezes.includes(k)) {
        out.push(k)
      }
    }
    return out
  }, [today, state.logs, state.freezes, state.mode])

  const pakaiFreeze = (tanggal: string) => {
    if (sisaFreezeBulan <= 0) {
      toast('Kuota Streak Freeze bulan ini habis (2/bulan).', 'peringatan')
      return
    }
    set((s) => ({
      ...s,
      freezes: [...s.freezes, tanggal],
      freezeTerpakai: s.freezeTerpakai + 1,
    }))
    const streakBaru = hitungStreak(state.logs, [...state.freezes, tanggal], state.mode, new Date())
    toast(`Freeze dipakai. Streak sekarang ${streakBaru} hari 🧊`, 'sukses')
  }

  const totalSesi = state.logs.filter((l) => l.valid).length
  const totalMenit = Math.round(state.logs.reduce((n, l) => n + l.durasiDetik, 0) / 60)
  const logsSorted = [...state.logs].sort((a, b) => b.ts - a.ts).slice(0, 12)

  const tanggalTarget = (key: string) => {
    const t = TARGETS.find((x) => x.key === key)
    if (!t) return 0
    return state.progres[key] ?? t.awal
  }

  return (
    <div className="screen">
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
            Progres
          </div>
          <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 2 }}>
            {state.nama ? `Punye ${state.nama}` : 'Perjalanan lu'}
          </div>
        </div>
      </div>

      <div className="stat-grid">
        <div className="stat">
          <div className="s-label">Streak sekarang</div>
          <div className="s-val" style={{ color: 'var(--orange2)' }}>
            {streak}
            <small>hari</small>
          </div>
        </div>
        <div className="stat">
          <div className="s-label">Rekor terbaik</div>
          <div className="s-val">
            {Math.max(state.streakTerbaik, streak)}
            <small>hari</small>
          </div>
        </div>
        <div className="stat">
          <div className="s-label">Sesi valid</div>
          <div className="s-val">{totalSesi}</div>
        </div>
        <div className="stat">
          <div className="s-label">Total waktu</div>
          <div className="s-val">
            {totalMenit}
            <small>mnt</small>
          </div>
        </div>
      </div>

      {/* heatmap */}
      <div className="section-title">
        <h2>Kalender latihan</h2>
        <span style={{ fontSize: 11, color: 'var(--dim2)', fontWeight: 600 }}>
          {minggu} minggu terakhir
        </span>
      </div>
      <div className="card tight">
        <div style={{ display: 'flex', gap: 8 }}>
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
              paddingTop: 2,
              fontSize: 8.5,
              fontWeight: 700,
              color: 'var(--dim2)',
            }}
          >
            {HARI_SINGKAT.map((h, i) => (
              <span key={i} style={{ height: 15, lineHeight: '15px', width: 8 }}>
                {h}
              </span>
            ))}
          </div>
          <div className="heatmap" style={{ flex: 1 }}>
            {cols.map((col, ci) => (
              <div className="hm-col" key={ci}>
                {col.map((cell) => (
                  <div
                    key={cell.key}
                    className={`hm-cell ${cell.status} ${
                      cell.key === toKey(today) ? 'today' : ''
                    }`}
                    title={`${tanggalPanjang(cell.date)} — ${cell.status}`}
                  />
                ))}
              </div>
            ))}
          </div>
        </div>

        <div className="hm-legend">
          <span>
            <i style={{ background: 'linear-gradient(145deg,#ff8f4d,#e85d0b)' }} /> Selesai
          </span>
          <span>
            <i style={{ background: '#7a5a2e' }} /> Ringan
          </span>
          <span>
            <i style={{ background: '#1e4e5e', border: '1px solid #22d3ee55' }} /> Freeze
          </span>
          <span>
            <i style={{ background: 'rgba(239,68,68,0.35)' }} /> Terlewat
          </span>
          <span>
            <i style={{ background: 'var(--card2)', border: '1px solid var(--line2)' }} /> Libur
          </span>
          <span>
            <i style={{ background: 'var(--card3)' }} /> Belum
          </span>
        </div>
      </div>

      {/* freeze */}
      <div className="section-title">
        <h2>Streak Freeze</h2>
        <span style={{ fontSize: 11.5, color: 'var(--cyan)', fontWeight: 700 }}>
          🧊 {sisaFreezeBulan} sisa
        </span>
      </div>

      {kandidatFreeze.length === 0 ? (
        <div className="card tight" style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <IcSnow size={20} style={{ color: 'var(--cyan)' }} />
          <div style={{ fontSize: 12.5, color: 'var(--dim)', lineHeight: 1.5 }}>
            Nggak ada hari wajib yang terlewat dalam 7 hari terakhir. Streak lu aman!
          </div>
        </div>
      ) : (
        <div className="card tight">
          <div style={{ fontSize: 12, color: 'var(--dim)', marginBottom: 10, lineHeight: 1.5 }}>
            Ada hari wajib yang kelewat. Pakai freeze biar streak nggak putus (maks 2/bulan).
          </div>
          {kandidatFreeze.map((k) => (
            <div key={k} className="set-row">
              <div className="sr-main">
                <div className="sr-title">{tanggalPanjang(fromKey(k))}</div>
                <div className="sr-desc">Hari wajib terlewat</div>
              </div>
              <Btn
                size="sm"
                variant="soft"
                onClick={() => pakaiFreeze(k)}
                disabled={sisaFreezeBulan <= 0}
              >
                <IcSnow size={14} /> Bekukan
              </Btn>
            </div>
          ))}
        </div>
      )}

      {/* target */}
      <div className="section-title">
        <h2>Target 1 bulan</h2>
      </div>
      <div className="card">
        {TARGETS.map((t) => {
          const val = tanggalTarget(t.key)
          const pct = Math.min(100, Math.max(0, ((val - t.awal) / (t.target - t.awal)) * 100))
          return (
            <div className="target-row" key={t.key}>
              <div className="target-head">
                <b>{t.nama}</b>
                <span>
                  {val} {t.satuan} / {t.target}
                </span>
              </div>
              <div className="target-bar">
                <i style={{ width: `${pct}%` }} />
              </div>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginTop: 8,
                }}
              >
                <span style={{ fontSize: 10.5, color: 'var(--dim2)' }}>
                  mulai dari {t.awal} {t.satuan}
                </span>
                <Btn size="sm" variant="ghost" onClick={() => setEdit(t.key)}>
                  Update
                </Btn>
              </div>
            </div>
          )
        })}
      </div>

      {/* badge */}
      <div className="section-title">
        <h2>Badge streak</h2>
      </div>
      <div className="badge-grid">
        {MILESTONES.map((m) => {
          const unlocked = Math.max(state.streakTerbaik, streak) >= m
          return (
            <div key={m} className={`badge ${unlocked ? 'unlocked' : 'locked'}`}>
              <div className="b-ico">{unlocked ? '🏅' : '🔒'}</div>
              <div className="b-num">{m} hari</div>
              <div className="b-lbl">{namaMilestone(m)}</div>
            </div>
          )
        })}
      </div>

      {/* riwayat */}
      <div className="section-title">
        <h2>Riwayat sesi</h2>
      </div>
      <div className="card tight">
        {logsSorted.length === 0 ? (
          <div className="empty" style={{ padding: '22px 10px' }}>
            <div className="e-ico">📋</div>
            <p>Belum ada sesi. Ayo mulai latihan pertama!</p>
          </div>
        ) : (
          logsSorted.map((l) => (
            <div className="log-item" key={l.id}>
              <div className={`log-ico ${l.valid ? 'valid' : ''}`}>{l.valid ? '✅' : '🟡'}</div>
              <div className="log-main">
                <b>
                  {HARI_NAMA[fromKey(l.tanggal).getDay()]} ·{' '}
                  {l.itemsDone}/{l.itemsTotal} gerakan
                </b>
                <span>
                  {l.tanggal} · {fmtDurasi(l.durasiDetik)} · {l.totalSet} set · +{l.xp} XP
                </span>
              </div>
              {!l.valid && (
                <span style={{ fontSize: 10, fontWeight: 800, color: 'var(--amber)' }}>RINGAN</span>
              )}
            </div>
          ))
        )}
      </div>

      <div style={{ marginTop: 14 }}>
        <Btn variant="danger" onClick={() => setKonfirmasiHapus(true)}>
          <IcTrash size={16} /> Reset semua data
        </Btn>
      </div>

      <p className="small-note">
        Data disimpan di HP lu sendiri (localStorage). Nggak dikirim ke mana-mana.
      </p>

      {/* modal update target */}
      <Modal
        open={edit !== null}
        onClose={() => setEdit(null)}
        title={TARGETS.find((t) => t.key === edit)?.nama ?? ''}
      >
        {edit && (
          <>
            <p>
              Masukin hasil terbaik lu sekarang. Target 1 bulan:{' '}
              <b style={{ color: 'var(--txt)' }}>
                {TARGETS.find((t) => t.key === edit)?.target}{' '}
                {TARGETS.find((t) => t.key === edit)?.satuan}
              </b>
            </p>
            <div style={{ display: 'flex', justifyContent: 'center', padding: '18px 0' }}>
              <Stepper
                value={tanggalTarget(edit)}
                onChange={(v) =>
                  set((s) => ({ ...s, progres: { ...s.progres, [edit]: v } }))
                }
                min={1}
                max={200}
                step={TARGETS.find((t) => t.key === edit)?.step ?? 1}
              />
            </div>
            <Btn onClick={() => setEdit(null)}>Simpan</Btn>
          </>
        )}
      </Modal>

      <Modal
        open={konfirmasiHapus}
        onClose={() => setKonfirmasiHapus(false)}
        title="Hapus semua data?"
      >
        <p>
          Semua riwayat, streak, XP, dan badge bakal hilang permanen. Yakin?
        </p>
        <div className="modal-actions">
          <Btn
            variant="danger"
            onClick={() => {
              setKonfirmasiHapus(false)
              reset()
              toast('Semua data sudah dihapus. Mulai dari nol lagi 💪', 'info')
              go('/')
            }}
          >
            Ya, hapus semua
          </Btn>
          <Btn variant="ghost" onClick={() => setKonfirmasiHapus(false)}>
            Batal
          </Btn>
        </div>
      </Modal>
    </div>
  )
}
