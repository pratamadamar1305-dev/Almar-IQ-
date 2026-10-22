import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import type { AppState, SessionLog, DayId, AktifSession } from './lib/types'
import { bulanKey, toKey } from './lib/utils'
import { hitungStreak, MILESTONES, sisaFreeze } from './lib/streak'

const KEY = 'dojo-tarung-v1'

const defaultState: AppState = {
  version: 1,
  nama: '',
  mode: 3,
  restDetik: 45,
  suara: true,
  getar: true,
  izinOrtu: false,
  izinSudahDiingatkan: false,
  logs: [],
  freezes: [],
  freezeBulan: bulanKey(new Date()),
  freezeTerpakai: 0,
  streakTerbaik: 0,
  bonusFlame: 0,
  xp: 0,
  progres: {},
  aktif: null,
  seenMilestones: [],
  tema: 'dark',
}

function angka(n: unknown, fallback: number): number {
  return typeof n === 'number' && Number.isFinite(n) ? n : fallback
}

function sanitize(raw: unknown): AppState {
  if (!raw || typeof raw !== 'object') return { ...defaultState }
  const o = raw as Record<string, unknown>

  const logs: SessionLog[] = Array.isArray(o.logs)
    ? (o.logs as unknown[])
        .filter((x): x is Record<string, unknown> => !!x && typeof x === 'object')
        .map((x) => ({
          id: String(x.id ?? Math.random().toString(36).slice(2)),
          tanggal: String(x.tanggal ?? ''),
          day: (x.day as DayId) ?? 'senin',
          selesai: Boolean(x.selesai),
          valid: Boolean(x.valid),
          itemsDone: angka(x.itemsDone, 0),
          itemsTotal: angka(x.itemsTotal, 0),
          durasiDetik: angka(x.durasiDetik, 0),
          totalSet: angka(x.totalSet, 0),
          totalRep: angka(x.totalRep, 0),
          xp: angka(x.xp, 0),
          ts: angka(x.ts, 0),
        }))
        .filter((l) => /^\d{4}-\d{2}-\d{2}$/.test(l.tanggal))
    : []

  const aktifRaw = o.aktif as Record<string, unknown> | null | undefined
  let aktif: AktifSession | null = null
  if (aktifRaw && typeof aktifRaw === 'object' && typeof aktifRaw.day === 'string') {
    aktif = {
      day: aktifRaw.day as DayId,
      tanggal: String(aktifRaw.tanggal ?? toKey(new Date())),
      startedAt: angka(aktifRaw.startedAt, Date.now()),
      index: angka(aktifRaw.index, 0),
      setDone: angka(aktifRaw.setDone, 0),
      doneItems: angka(aktifRaw.doneItems, 0),
      totalSet: angka(aktifRaw.totalSet, 0),
      totalRep: angka(aktifRaw.totalRep, 0),
      elapsed: angka(aktifRaw.elapsed, 0),
    }
  }

  const progresRaw = (o.progres ?? {}) as Record<string, unknown>
  const progres: Record<string, number> = {}
  for (const k of Object.keys(progresRaw)) {
    const v = progresRaw[k]
    if (typeof v === 'number' && Number.isFinite(v)) progres[k] = v
  }

  return {
    version: 1,
    nama: typeof o.nama === 'string' ? o.nama : '',
    mode: o.mode === 4 ? 4 : 3,
    restDetik: Math.min(180, Math.max(10, angka(o.restDetik, 45))),
    suara: o.suara !== false,
    getar: o.getar !== false,
    izinOrtu: Boolean(o.izinOrtu),
    izinSudahDiingatkan: Boolean(o.izinSudahDiingatkan),
    logs,
    freezes: Array.isArray(o.freezes)
      ? (o.freezes as unknown[]).filter((x): x is string => typeof x === 'string')
      : [],
    freezeBulan:
      typeof o.freezeBulan === 'string' ? o.freezeBulan : bulanKey(new Date()),
    freezeTerpakai: Math.max(0, angka(o.freezeTerpakai, 0)),
    streakTerbaik: Math.max(0, angka(o.streakTerbaik, 0)),
    bonusFlame: Math.max(0, angka(o.bonusFlame, 0)),
    xp: Math.max(0, angka(o.xp, 0)),
    progres,
    aktif,
    seenMilestones: Array.isArray(o.seenMilestones)
      ? (o.seenMilestones as unknown[]).filter(
          (x): x is number => typeof x === 'number'
        )
      : [],
    tema: o.tema === 'light' ? 'light' : 'dark',
  }
}

function loadState(): AppState {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return { ...defaultState }
    return sanitize(JSON.parse(raw))
  } catch {
    return { ...defaultState }
  }
}

export interface Toast {
  id: number
  pesan: string
  tipe: 'sukses' | 'info' | 'peringatan'
}

interface Ctx {
  state: AppState
  set: (updater: (s: AppState) => AppState) => void
  reset: () => void
  toasts: Toast[]
  toast: (pesan: string, tipe?: Toast['tipe']) => void
  hapusToast: (id: number) => void
  level: number
  xpDiLevel: number
  xpLevelMax: number
  streak: number
  sisaFreezeBulan: number
  ambilMilestoneBaru: (streak: number) => number[]
}

const AppCtx = createContext<Ctx | null>(null)

export function AppProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AppState>(() => loadState())
  const [toasts, setToasts] = useState<Toast[]>([])
  const toastId = useRef(1)

  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify(state))
    } catch {
      /* storage penuh / private mode */
    }
  }, [state])

  useEffect(() => {
    document.documentElement.dataset.tema = state.tema
  }, [state.tema])

  useEffect(() => {
    setState((s) => {
      const bk = bulanKey(new Date())
      if (s.freezeBulan !== bk) return { ...s, freezeBulan: bk, freezeTerpakai: 0 }
      return s
    })
  }, [])

  const set = useCallback((updater: (s: AppState) => AppState) => {
    setState((prev) => updater(prev))
  }, [])

  const reset = useCallback(() => {
    try {
      localStorage.removeItem(KEY)
    } catch {
      /* noop */
    }
    setState({ ...defaultState, freezeBulan: bulanKey(new Date()) })
  }, [])

  const toast = useCallback((pesan: string, tipe: Toast['tipe'] = 'info') => {
    const id = toastId.current++
    setToasts((t) => [...t, { id, pesan, tipe }])
    window.setTimeout(() => {
      setToasts((t) => t.filter((x) => x.id !== id))
    }, 3200)
  }, [])

  const hapusToast = useCallback((id: number) => {
    setToasts((t) => t.filter((x) => x.id !== id))
  }, [])

  const streak = useMemo(
    () => hitungStreak(state.logs, state.freezes, state.mode, new Date()),
    [state.logs, state.freezes, state.mode]
  )

  useEffect(() => {
    if (streak > state.streakTerbaik) {
      setState((s) => (streak > s.streakTerbaik ? { ...s, streakTerbaik: streak } : s))
    }
  }, [streak, state.streakTerbaik])

  const ambilMilestoneBaru = useCallback(
    (streakNow: number) =>
      MILESTONES.filter(
        (m) => streakNow >= m && !state.seenMilestones.includes(m)
      ),
    [state.seenMilestones]
  )

  const level = Math.floor(state.xp / 500) + 1
  const xpDiLevel = state.xp % 500
  const xpLevelMax = 500
  const sisaFreezeBulan = sisaFreeze(state, new Date())

  const value: Ctx = {
    state,
    set,
    reset,
    toasts,
    toast,
    hapusToast,
    level,
    xpDiLevel,
    xpLevelMax,
    streak,
    sisaFreezeBulan,
    ambilMilestoneBaru,
  }

  return <AppCtx.Provider value={value}>{children}</AppCtx.Provider>
}

export function useApp(): Ctx {
  const c = useContext(AppCtx)
  if (!c) throw new Error('useApp harus dipakai di dalam AppProvider')
  return c
}
