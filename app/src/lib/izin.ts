/**
 * Gate izin ortu/pelatih.
 * Modal-nya hidup di App; layar lain minta lewat event supaya nggak
 * nge-blok tampilan Home di kunjungan pertama.
 */
type Aksi = () => void

let pending: Aksi | null = null

export const EVENT_IZIN = 'dojo:minta-izin'

export function mintaIzin(aksi: Aksi) {
  pending = aksi
  // pakai window.Event, bukan Event global: aman di semua environment
  window.dispatchEvent(new window.Event(EVENT_IZIN))
}

/** Ambil aksi yang tertunda (sekali pakai). */
export function ambilAksiIzin(): Aksi | null {
  const a = pending
  pending = null
  return a
}

export function buangAksiIzin() {
  pending = null
}
