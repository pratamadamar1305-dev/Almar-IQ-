import { useMemo, useState } from 'react'
import { useApp } from '../store'
import { getSesi } from '../lib/data'
import { go } from '../lib/nav'
import { toKey } from '../lib/utils'
import type { Alat, DayId } from '../lib/types'
import { mintaIzin } from '../lib/izin'
import { Btn } from '../components/ui'
import { IcBack, IcChevron, IcPlay, IcShield, IcTimer } from '../components/Icon'

const ALAT_ICON: Record<Alat, string> = {
  bodyweight: '🤸',
  tas: '🎒',
  sapu: '🥢',
  kursi: '🪑',
  pintu: '🚪',
}

const ALAT_LABEL: Record<Alat, string> = {
  bodyweight: 'Tanpa alat',
  tas: 'Tas sekolah',
  sapu: 'Sapu kayu',
  kursi: 'Kursi',
  pintu: 'Gagang pintu',
}

export default function Detail({ day }: { day: DayId }) {
  const { state, set, toast } = useApp()
  const sesi = getSesi(day)
  const [open, setOpen] = useState<string | null>(null)

  const totalLatihan = useMemo(
    () => (sesi ? sesi.blok.reduce((n, b) => n + b.gerakan.length * (b.rounds ?? 1), 0) : 0),
    [sesi]
  )

  if (!sesi) {
    return (
      <div className="screen">
        <div className="empty">
          <div className="e-ico">🤔</div>
          <p>Hari itu nggak ada di jadwal.</p>
          <Btn style={{ marginTop: 16 }} onClick={() => go('/')}>
            Balik ke Home
          </Btn>
        </div>
      </div>
    )
  }

  const jalankanSesi = () => {
    set((s) => ({
      ...s,
      aktif: {
        day: sesi.day,
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

  const mulai = () => {
    if (!state.izinSudahDiingatkan) mintaIzin(jalankanSesi)
    else jalankanSesi()
  }

  return (
    <div className="screen">
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <button className="icon-btn" onClick={() => go('/')} aria-label="Kembali">
          <IcBack size={19} />
        </button>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.14em', color: 'var(--dim2)', textTransform: 'uppercase' }}>
            Jadwal {sesi.label}
          </div>
          <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 2 }}>
            {sesi.durasiMenit} menit · {totalLatihan} gerakan
          </div>
        </div>
        <span className={`sesi-badge ${sesi.opsional ? 'opsional' : ''}`}>
          {sesi.opsional ? 'Opsional' : 'Wajib'}
        </span>
      </div>

      <div className="card" style={{ padding: 18 }}>
        <div style={{ fontSize: 21, fontWeight: 800, letterSpacing: '-0.025em', lineHeight: 1.25 }}>
          {sesi.tema}
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--dim)', marginTop: 8, lineHeight: 1.55 }}>
          <b style={{ color: 'var(--txt)' }}>Fokus:</b> {sesi.fokus}
        </div>
        <div className="sesi-meta" style={{ marginTop: 12 }}>
          <span>
            <IcTimer size={13} /> ± {sesi.durasiMenit} menit
          </span>
          <span>🧰 sapu + tas sekolah</span>
        </div>
        <Btn style={{ marginTop: 16 }} onClick={mulai}>
          <IcPlay size={16} /> Mulai Sesi Ini
        </Btn>
        {state.aktif && (
          <div style={{ fontSize: 11.5, color: 'var(--amber)', marginTop: 10, textAlign: 'center' }}>
            ⚠️ Ada sesi lain yang belum selesai — mulai sesi baru akan menghapusnya.
          </div>
        )}
      </div>

      {sesi.blok.map((blok, bi) => (
        <div key={`${blok.nama}-${bi}`}>
          <div className="ger-block-label">
            {blok.nama}
            {blok.rounds && blok.rounds > 1 ? ` · ${blok.rounds} ronde` : ''}
          </div>

          <div className="ger-list">
            {blok.gerakan.map((ger, gi) => {
              const key = `${bi}-${gi}`
              const isOpen = open === key
              return (
                <div key={key} className={`ger-item ${isOpen ? 'open' : ''}`}>
                  <button className="ger-head" onClick={() => setOpen(isOpen ? null : key)}>
                    <span className="ger-num">{gi + 1}</span>
                    <span className="ger-main">
                      <span className="ger-nama">{ger.nama}</span>
                      <span className="ger-sub">
                        {ger.sets}×{ger.tipe === 'hold' ? `${ger.holdDetik} dtk` : ger.tipe === 'drill' ? `${Math.round((ger.drillDetik ?? 0) / 60)} mnt` : ger.reps}
                        {ger.perSisi ? '/kaki' : ''} · {ger.targetArea} · {ALAT_ICON[ger.alat]}{' '}
                        {ALAT_LABEL[ger.alat]}
                      </span>
                    </span>
                    <IcChevron size={17} className="ger-chev" />
                  </button>
                  {isOpen && (
                    <div className="ger-body">
                      <div className="ger-text">
                        <b>Cara:</b> {ger.cara}
                      </div>
                      {ger.salah && (
                        <div className="warn-box">
                          <b>❌ Jangan gini:</b> {ger.salah}
                        </div>
                      )}
                      {ger.catatan && <div className="tip-box">💡 {ger.catatan}</div>}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      ))}

      <div className="card" style={{ marginTop: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span
            style={{
              width: 34,
              height: 34,
              borderRadius: 11,
              display: 'grid',
              placeItems: 'center',
              background: 'rgba(255,107,26,0.13)',
              color: 'var(--orange2)',
              flex: 'none',
            }}
          >
            <IcShield size={18} />
          </span>
          <div style={{ fontSize: 13.5, fontWeight: 700 }}>Reminder aman</div>
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--dim)', marginTop: 10, lineHeight: 1.6 }}>
          Tas max 4 kg · lantai jangan licin · minum tiap 15 menit · nyeri tajam di sendi = STOP 2 hari.
        </div>
        <Btn variant="ghost" size="sm" style={{ marginTop: 12, width: '100%' }} onClick={() => go('/aturan')}>
          Baca aturan lengkap
        </Btn>
      </div>
    </div>
  )
}
