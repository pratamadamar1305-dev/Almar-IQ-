import type { SessionLog } from './types'
import { addDays, bulanKey, fromKey, startOfDay, toKey } from './utils'

export type Mode = 3 | 4

/** Hari wajib latihan berdasarkan mode. */
export function isWajib(d: Date, mode: Mode): boolean {
  const x = d.getDay()
  if (mode === 3) return x === 1 || x === 4 || x === 5 // Sen, Kam, Jum
  return x === 1 || x === 2 || x === 4 || x === 5 // + Selasa
}

/** Hari opsional (Selasa hanya opsional di mode 3 hari). */
export function isOpsional(d: Date, mode: Mode): boolean {
  return mode === 3 && d.getDay() === 2
}

/** Rest day: Rabu, Sabtu, Minggu. */
export function isLibur(d: Date): boolean {
  const x = d.getDay()
  return x === 3 || x === 6 || x === 0
}

export type DayStatus =
  | 'selesai'
  | 'ringan'
  | 'freeze'
  | 'terlewat'
  | 'libur'
  | 'opsional'
  | 'belum'

export function isLogValid(l: SessionLog | undefined): boolean {
  return !!l && l.selesai && l.valid
}

/** Map tanggal -> log valid (kalau ada beberapa, ambil yang valid). */
export function petaLog(logs: SessionLog[]): Map<string, SessionLog> {
  const m = new Map<string, SessionLog>()
  for (const l of logs) {
    const prev = m.get(l.tanggal)
    if (!prev || (!isLogValid(prev) && isLogValid(l))) m.set(l.tanggal, l)
  }
  return m
}

export interface StreakInfo {
  streak: number
  terbaik: number
  wajibHariIni: boolean
  sudahHariIni: boolean
  bisaNaikHariIni: boolean
  hariWajibTerakhir: string | null
  hariWajibBerikutnya: string | null
  terlewatTerakhir: string | null
}

/**
 * Hitung streak sesuai spesifikasi:
 * - Hanya hari WAJIB yang menambah angka streak.
 * - Rest day & hari opsional yang dilewat TIDAK memutus streak.
 * - Hari wajib yang belum selesai HARI INI tidak langsung mereset;
 *   kita mulai hitung mundur dari hari wajib sebelumnya.
 * - Freeze menutup 1 hari wajib yang terlewat.
 */
export function hitungStreak(
  logs: SessionLog[],
  freezes: string[],
  mode: Mode,
  today: Date
): number {
  const byDate = petaLog(logs)
  const freezeSet = new Set(freezes)
  const todayKey = toKey(today)

  let cursor = startOfDay(today)

  const hariIniWajib = isWajib(cursor, mode)
  const hariIniBeres =
    isLogValid(byDate.get(todayKey)) || freezeSet.has(todayKey)

  if (hariIniWajib && !hariIniBeres) {
    cursor = addDays(cursor, -1)
  }

  let streak = 0
  for (let i = 0; i < 1825; i++) {
    if (isWajib(cursor, mode)) {
      const key = toKey(cursor)
      if (isLogValid(byDate.get(key)) || freezeSet.has(key)) {
        streak++
      } else {
        break
      }
    }
    cursor = addDays(cursor, -1)
  }
  return streak
}

export function infoStreak(
  logs: SessionLog[],
  freezes: string[],
  mode: Mode,
  today: Date,
  rekorTersimpan: number
): StreakInfo {
  const byDate = petaLog(logs)
  const todayKey = toKey(today)
  const streak = hitungStreak(logs, freezes, mode, today)

  const wajibHariIni = isWajib(today, mode)
  const sudahHariIni =
    isLogValid(byDate.get(todayKey)) || freezes.includes(todayKey)

  // Hari wajib terakhir (<= hari ini)
  let hariWajibTerakhir: string | null = null
  for (let i = 0; i < 60; i++) {
    const d = addDays(today, -i)
    if (isWajib(d, mode)) {
      hariWajibTerakhir = toKey(d)
      break
    }
  }

  // Hari wajib berikutnya (>= hari ini)
  let hariWajibBerikutnya: string | null = null
  for (let i = 0; i < 14; i++) {
    const d = addDays(today, i)
    if (isWajib(d, mode)) {
      hariWajibBerikutnya = toKey(d)
      break
    }
  }

  // Terlewat terakhir (maks 7 hari ke belakang, belum di-freeze)
  let terlewatTerakhir: string | null = null
  for (let i = 1; i <= 7; i++) {
    const d = addDays(today, -i)
    const k = toKey(d)
    if (isWajib(d, mode) && !isLogValid(byDate.get(k)) && !freezes.includes(k)) {
      terlewatTerakhir = k
      break
    }
  }

  return {
    streak,
    terbaik: Math.max(rekorTersimpan, streak),
    wajibHariIni,
    sudahHariIni,
    bisaNaikHariIni: wajibHariIni && !sudahHariIni,
    hariWajibTerakhir,
    hariWajibBerikutnya,
    terlewatTerakhir,
  }
}

export function statusTanggal(
  d: Date,
  logs: SessionLog[],
  freezes: string[],
  mode: Mode,
  today: Date
): DayStatus {
  const key = toKey(d)
  const log = petaLog(logs).get(key)
  const isFuture = startOfDay(d).getTime() > startOfDay(today).getTime()

  if (freezes.includes(key)) return 'freeze'
  if (log) return log.valid ? 'selesai' : 'ringan'
  if (isFuture) return 'belum'
  if (isLibur(d)) return 'libur'
  if (isOpsional(d, mode)) return 'opsional'
  if (isWajib(d, mode)) return toKey(d) === toKey(today) ? 'belum' : 'terlewat'
  return 'belum'
}

export const MILESTONES = [3, 7, 14, 21, 30, 50, 100, 200, 365]

export function namaMilestone(n: number): string {
  const map: Record<number, string> = {
    3: 'Pemula Api',
    7: 'Seminggu Nyala',
    14: 'Dua Minggu',
    21: 'Kebiasaan Baru',
    30: 'Sebulan Penuh',
    50: 'Baja',
    100: 'Legenda Dojo',
    200: 'Dua Ratus Hari',
    365: 'Setahun Api',
  }
  return map[n] ?? `${n} Hari`
}

/** Reset kuota freeze kalau bulan berganti. */
export function sinkronFreeze(state: {
  freezeBulan: string
  freezeTerpakai: number
}, today: Date) {
  const bk = bulanKey(today)
  if (state.freezeBulan !== bk) {
    return { freezeBulan: bk, freezeTerpakai: 0 }
  }
  return { freezeBulan: state.freezeBulan, freezeTerpakai: state.freezeTerpakai }
}

export const FREEZE_PER_BULAN = 2

export function sisaFreeze(state: {
  freezeBulan: string
  freezeTerpakai: number
}, today: Date) {
  const sync = sinkronFreeze(state, today)
  return Math.max(0, FREEZE_PER_BULAN - sync.freezeTerpakai)
}

/** Validasi tanggal untuk freeze: wajib, di masa lalu, maks 7 hari, belum pernah. */
export function bisaFreeze(
  tanggal: string,
  logs: SessionLog[],
  freezes: string[],
  mode: Mode,
  today: Date
): boolean {
  if (freezes.includes(tanggal)) return false
  const d = fromKey(tanggal)
  const diff = Math.round(
    (startOfDay(today).getTime() - startOfDay(d).getTime()) / 86400000
  )
  if (diff < 1 || diff > 7) return false
  if (!isWajib(d, mode)) return false
  if (isLogValid(petaLog(logs).get(tanggal))) return false
  return true
}
