export const pad2 = (n: number) => String(n).padStart(2, '0')

export const HARI_NAMA = [
  'Minggu',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
] as const

// urutan Senin → Minggu (dipakai heatmap yang mulai dari Senin)
export const HARI_SINGKAT = ['S', 'S', 'R', 'K', 'J', 'S', 'M'] as const

export function startOfDay(d: Date): Date {
  const x = new Date(d.getTime())
  x.setHours(0, 0, 0, 0)
  return x
}

export function addDays(d: Date, n: number): Date {
  const x = startOfDay(d)
  x.setDate(x.getDate() + n)
  return x
}

export function toKey(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}

export function fromKey(k: string): Date {
  const [y, m, dd] = k.split('-').map(Number)
  return new Date(y, (m ?? 1) - 1, dd ?? 1)
}

export function bulanKey(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}`
}

export function selisihHari(a: Date, b: Date): number {
  return Math.round((startOfDay(a).getTime() - startOfDay(b).getTime()) / 86400000)
}

export function fmtWaktu(totalDetik: number): string {
  const s = Math.max(0, Math.round(totalDetik))
  const m = Math.floor(s / 60)
  const r = s % 60
  return `${pad2(m)}:${pad2(r)}`
}

export function fmtDurasi(totalDetik: number): string {
  const s = Math.max(0, Math.round(totalDetik))
  if (s < 60) return `${s} dtk`
  const m = Math.floor(s / 60)
  const r = s % 60
  if (m < 60) return r ? `${m} mnt ${r} dtk` : `${m} mnt`
  const j = Math.floor(m / 60)
  return `${j} jam ${m % 60} mnt`
}

export function tanggalPanjang(d: Date): string {
  return `${HARI_NAMA[d.getDay()]}, ${d.getDate()} ${[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ][d.getMonth()]} ${d.getFullYear()}`
}

export function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n))
}

export function uid(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`
}
