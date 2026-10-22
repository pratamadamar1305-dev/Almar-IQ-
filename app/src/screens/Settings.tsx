import { useState } from 'react'
import { useApp } from '../store'
import { addDays, startOfDay, toKey, uid } from '../lib/utils'
import { isWajib } from '../lib/streak'
import type { DayId, SessionLog } from '../lib/types'
import { Btn, Modal, Segmented, Switch } from '../components/ui'
import { IcBack, IcTrash } from '../components/Icon'
import { usePWA } from '../lib/pwa'
import { go } from '../lib/nav'

export default function Settings() {
  const { state, set, reset, toast } = useApp()
  const [hapus, setHapus] = useState(false)
  const [demo, setDemo] = useState(false)
  const pwa = usePWA()

  const totalLog = state.logs.length

  const isiDemo = () => {
    const today = startOfDay(new Date())
    const logs: SessionLog[] = []
    // 28 hari ke belakang: isi semua hari wajib + sebagian Selasa
    for (let i = 28; i >= 0; i--) {
      const d = addDays(today, -i)
      if (!isWajib(d, 3)) continue
      // sengaja bolong 1 hari di 20 hari lalu biar kelihatan realistis
      if (i === 20) continue
      const day: DayId = d.getDay() === 1 ? 'senin' : d.getDay() === 4 ? 'kamis' : 'jumat'
      const gerakan = day === 'senin' ? 10 : day === 'kamis' ? 10 : 26
      logs.push({
        id: uid(),
        tanggal: toKey(d),
        day,
        selesai: true,
        valid: true,
        itemsDone: gerakan,
        itemsTotal: gerakan,
        durasiDetik: 2400 + Math.round(Math.random() * 900),
        totalSet: 22 + Math.round(Math.random() * 6),
        totalRep: 140 + Math.round(Math.random() * 40),
        xp: 270 + Math.round(Math.random() * 60),
        ts: d.getTime() + 17 * 3600000,
      })
    }
    // satu sesi ringan contoh
    const ringan = addDays(today, -26)
    logs.push({
      id: uid(),
      tanggal: toKey(ringan),
      day: 'jumat',
      selesai: true,
      valid: false,
      itemsDone: 10,
      itemsTotal: 26,
      durasiDetik: 900,
      totalSet: 9,
      totalRep: 60,
      xp: 100,
      ts: ringan.getTime() + 17 * 3600000,
    })

    set((s) => ({
      ...s,
      logs,
      xp: logs.reduce((n, l) => n + l.xp, 0),
      bonusFlame: 2,
      progres: { pike: 11, kuda: 42, finger: 10, tendangan: 3 },
    }))
    setDemo(false)
    toast('Data demo dimuat. Cek Home & Progres! 🎉', 'sukses')
    go('/')
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
            Pengaturan
          </div>
          <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 2 }}>
            Dojo lu
          </div>
        </div>
      </div>

      {/* profil */}
      <div className="card">
        <div style={{ fontSize: 12, fontWeight: 800, letterSpacing: '0.1em', color: 'var(--dim2)' }}>
          NAMA PANGGILAN
        </div>
        <input
          className="text-input"
          style={{ marginTop: 10 }}
          placeholder="Contoh: Almar"
          maxLength={20}
          value={state.nama}
          onChange={(e) => set((s) => ({ ...s, nama: e.target.value }))}
        />
        <div style={{ marginTop: 16, fontSize: 12, fontWeight: 800, letterSpacing: '0.1em', color: 'var(--dim2)' }}>
          JADWAL
        </div>
        <div style={{ marginTop: 10 }}>
          <Segmented
            value={state.mode}
            options={[
              { value: 3, label: '3 hari (Sen·Kam·Jum)' },
              { value: 4, label: '4 hari (+Selasa)' },
            ]}
            onChange={(v) => set((s) => ({ ...s, mode: v as 3 | 4 }))}
          />
        </div>
        <div style={{ fontSize: 11.5, color: 'var(--dim2)', marginTop: 9, lineHeight: 1.5 }}>
          Mode 3 hari: Selasa jadi bonus opsional, nggak bikin streak putus kalau dilewat.
        </div>
      </div>

      {/* latihan */}
      <div className="section-title">
        <h2>Sesi latihan</h2>
      </div>
      <div className="card">
        <div className="set-row" style={{ paddingTop: 0 }}>
          <div className="sr-main">
            <div className="sr-title">Istirahat antar set</div>
            <div className="sr-desc">Dipakai di semua gerakan (bisa dioverride per gerakan)</div>
          </div>
        </div>
        <div style={{ marginTop: 12 }}>
          <Segmented
            value={state.restDetik}
            options={[
              { value: 30, label: '30 dtk' },
              { value: 45, label: '45 dtk' },
              { value: 60, label: '60 dtk' },
              { value: 90, label: '90 dtk' },
            ]}
            onChange={(v) => set((s) => ({ ...s, restDetik: v }))}
          />
        </div>

        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Suara</div>
            <div className="sr-desc">Beep 3 detik terakhir, gong, dan suara set selesai</div>
          </div>
          <Switch on={state.suara} onChange={(v) => set((s) => ({ ...s, suara: v }))} />
        </div>

        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Getar</div>
            <div className="sr-desc">Haptic feedback tiap set selesai (kalau HP support)</div>
          </div>
          <Switch on={state.getar} onChange={(v) => set((s) => ({ ...s, getar: v }))} />
        </div>

        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Izin ortu/pelatih</div>
            <div className="sr-desc">Centang kalau udah dapat izin sebelum latihan</div>
          </div>
          <Switch on={state.izinOrtu} onChange={(v) => set((s) => ({ ...s, izinOrtu: v }))} />
        </div>
      </div>

      {/* install */}
      <div className="section-title">
        <h2>Aplikasi</h2>
        {pwa.status === 'sudah-terpasang' && (
          <span style={{ fontSize: 11.5, color: 'var(--green)', fontWeight: 700 }}>
            ✅ terpasang
          </span>
        )}
      </div>
      <div className="card">
        <div className="set-row" style={{ paddingTop: 0 }}>
          <div className="sr-main">
            <div className="sr-title">Pasang di layar utama</div>
            <div className="sr-desc">
              {pwa.status === 'sudah-terpasang'
                ? 'Aplikasi sudah jalan dalam mode standalone'
                : pwa.status === 'bisa-install'
                  ? 'Browser lu siap — tinggal tap install'
                  : 'Ikuti cara manual di panduan install'}
            </div>
          </div>
          <Btn size="sm" variant={pwa.status === 'bisa-install' ? 'primary' : 'ghost'} onClick={() => go('/install')}>
            {pwa.status === 'sudah-terpasang' ? 'Info' : 'Install'}
          </Btn>
        </div>
        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Mode offline</div>
            <div className="sr-desc">
              Service worker aktif — aplikasi bisa dibuka tanpa internet
            </div>
          </div>
          <span style={{ fontSize: 18 }}>📶</span>
        </div>
      </div>

      {/* tampilan */}
      <div className="section-title">
        <h2>Tampilan</h2>
      </div>
      <div className="card">
        <div className="set-row" style={{ paddingTop: 0 }}>
          <div className="sr-main">
            <div className="sr-title">Tema</div>
            <div className="sr-desc">Dark cocok buat latihan malam</div>
          </div>
        </div>
        <div style={{ marginTop: 12 }}>
          <Segmented
            value={state.tema}
            options={[
              { value: 'dark', label: '🌙 Dark' },
              { value: 'light', label: '☀️ Light' },
            ]}
            onChange={(v) =>
              set((s) => ({ ...s, tema: v === 'light' ? 'light' : 'dark' }))
            }
          />
        </div>
      </div>

      {/* data */}
      <div className="section-title">
        <h2>Data</h2>
      </div>
      <div className="card">
        <div className="set-row" style={{ paddingTop: 0 }}>
          <div className="sr-main">
            <div className="sr-title">Data demo</div>
            <div className="sr-desc">
              Isi riwayat 4 minggu biar bisa lihat tampilan streak & heatmap penuh
            </div>
          </div>
          <Btn size="sm" variant="soft" onClick={() => setDemo(true)}>
            Muat
          </Btn>
        </div>
        <div className="set-row">
          <div className="sr-main">
            <div className="sr-title">Total data tersimpan</div>
            <div className="sr-desc">
              {totalLog} sesi · {state.xp} XP · {state.freezes.length} freeze terpakai
            </div>
          </div>
        </div>
        <div style={{ marginTop: 14 }}>
          <Btn variant="danger" onClick={() => setHapus(true)}>
            <IcTrash size={16} /> Reset semua data
          </Btn>
        </div>
      </div>

      <p className="small-note">
        DOJO TARUNG v1.0 · dibuat dari jadwal latihan pribadi.
        <br />
        Semua data tersimpan lokal di HP lu, aman & offline.
      </p>

      <Modal open={demo} onClose={() => setDemo(false)} title="Muat data demo?">
        <p>
          Ini bakal <b style={{ color: 'var(--red)' }}>menimpa</b> riwayat yang ada dengan data
          contoh 4 minggu (biar kelihatan streak, heatmap, dan badge-nya).
        </p>
        <div className="modal-actions">
          <Btn onClick={isiDemo}>Muat data demo</Btn>
          <Btn variant="ghost" onClick={() => setDemo(false)}>
            Batal
          </Btn>
        </div>
      </Modal>

      <Modal open={hapus} onClose={() => setHapus(false)} title="Hapus semua data?">
        <p>
          Semua riwayat, streak, XP, badge, dan sesi yang lagi jalan bakal hilang permanen.
        </p>
        <div className="modal-actions">
          <Btn
            variant="danger"
            onClick={() => {
              setHapus(false)
              reset()
              toast('Semua data sudah dihapus 💪', 'info')
              go('/')
            }}
          >
            Ya, hapus semua
          </Btn>
          <Btn variant="ghost" onClick={() => setHapus(false)}>
            Batal
          </Btn>
        </div>
      </Modal>

      <div style={{ height: 8 }} />
    </div>
  )
}
