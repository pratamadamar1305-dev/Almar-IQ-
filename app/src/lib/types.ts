export type Alat = 'bodyweight' | 'tas' | 'sapu' | 'kursi' | 'pintu'
export type Tipe = 'rep' | 'hold' | 'drill'
export type DayId = 'senin' | 'selasa' | 'kamis' | 'jumat'

export interface Gerakan {
  id: string
  nama: string
  sets: number
  reps?: number
  perSisi?: boolean
  holdDetik?: number
  drillDetik?: number
  tipe: Tipe
  alat: Alat
  targetArea: string
  detikPerRep: number
  restDetik?: number
  cara: string
  salah?: string
  catatan?: string
}

export interface Blok {
  nama: string
  gerakan: Gerakan[]
  rounds?: number
  restAntarRonde?: number
}

export interface Sesi {
  day: DayId
  label: string
  tema: string
  durasiMenit: number
  opsional: boolean
  fokus: string
  blok: Blok[]
}

export interface QueueItem {
  gerakan: Gerakan
  blok: string
  round?: number
  rounds?: number
}

export interface SessionLog {
  id: string
  tanggal: string // YYYY-MM-DD waktu lokal
  day: DayId
  selesai: boolean
  valid: boolean
  itemsDone: number
  itemsTotal: number
  durasiDetik: number
  totalSet: number
  totalRep: number
  xp: number
  ts: number
}

export interface AktifSession {
  day: DayId
  tanggal: string
  startedAt: number
  index: number
  setDone: number
  doneItems: number
  totalSet: number
  totalRep: number
  elapsed: number
}

export interface AppState {
  version: number
  nama: string
  mode: 3 | 4
  restDetik: number
  suara: boolean
  getar: boolean
  izinOrtu: boolean
  izinSudahDiingatkan: boolean
  logs: SessionLog[]
  freezes: string[]
  freezeBulan: string
  freezeTerpakai: number
  streakTerbaik: number
  bonusFlame: number
  xp: number
  progres: Record<string, number>
  aktif: AktifSession | null
  seenMilestones: number[]
  tema: 'dark' | 'light'
}
