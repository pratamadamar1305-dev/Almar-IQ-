import { hitungStreak, isWajib, isOpsional, isLibur, bisaFreeze, infoStreak, MILESTONES } from '../src/lib/streak'
import type { SessionLog } from '../src/lib/types'

let pass = 0, fail = 0
function eq(nama: string, got: unknown, exp: unknown) {
  const ok = JSON.stringify(got) === JSON.stringify(exp)
  if (ok) { pass++ } else { fail++; console.log(`❌ ${nama}: dapat ${JSON.stringify(got)} harap ${JSON.stringify(exp)}`) }
}

function log(tanggal: string, valid = true): SessionLog {
  return { id: tanggal + Math.random(), tanggal, day: 'senin', selesai: true, valid,
    itemsDone: 10, itemsTotal: 10, durasiDetik: 2400, totalSet: 20, totalRep: 120, xp: 250, ts: 0 }
}
const D = (s: string) => new Date(s + 'T12:00:00')

// sanity: hari
eq('2026-10-21 = Rabu', D('2026-10-21').getDay(), 3)
eq('2026-10-19 = Senin', D('2026-10-19').getDay(), 1)

// --- klasifikasi hari
eq('Sen wajib mode3', isWajib(D('2026-10-19'), 3), true)
eq('Sel opsional mode3', isOpsional(D('2026-10-20'), 3), true)
eq('Sel wajib mode4', isWajib(D('2026-10-20'), 4), true)
eq('Rab libur', isLibur(D('2026-10-21')), true)
eq('Min libur', isLibur(D('2026-10-25')), true)

// --- A: streak melintasi rest day
eq('A streak=4', hitungStreak(
  [log('2026-10-19'), log('2026-10-16'), log('2026-10-15'), log('2026-10-12')],
  [], 3, D('2026-10-21')), 4)

// --- B: bolong Senin -> 0
eq('B streak=0', hitungStreak(
  [log('2026-10-16'), log('2026-10-15'), log('2026-10-12')],
  [], 3, D('2026-10-21')), 0)

// --- C: hari ini wajib belum dikerjakan -> jangan reset
eq('C streak=3 (belum reset)', hitungStreak(
  [log('2026-10-16'), log('2026-10-15'), log('2026-10-12')],
  [], 3, D('2026-10-19')), 3)

// --- D: freeze menutup hari bolong
eq('D freeze=4', hitungStreak(
  [log('2026-10-16'), log('2026-10-15'), log('2026-10-12')],
  ['2026-10-19'], 3, D('2026-10-21')), 4)

// --- E: log ringan tidak dihitung
eq('E ringan=0', hitungStreak(
  [log('2026-10-19', false), log('2026-10-16')],
  [], 3, D('2026-10-21')), 0)

// --- F: sesi dobel di hari sama tetap 1
eq('F dobel=1', hitungStreak(
  [log('2026-10-19'), log('2026-10-19')],
  [], 3, D('2026-10-21')), 1)

// --- G: mode 4, Selasa jadi wajib
eq('G mode4 bolong selasa=0', hitungStreak(
  [log('2026-10-19'), log('2026-10-16')],
  [], 4, D('2026-10-21')), 0)
eq('G2 mode4 lengkap=3', hitungStreak(
  [log('2026-10-20'), log('2026-10-19'), log('2026-10-16')],
  [], 4, D('2026-10-21')), 3)

// --- H: latihan di hari LIBUR (Rabu) tidak menambah & tidak memutus streak
eq('H libur tambahan tidak menambah=1', hitungStreak(
  [log('2026-10-19'), log('2026-10-21')],
  [], 3, D('2026-10-21')), 1)
eq('H2 hari wajib selesai ikut dihitung=2', hitungStreak(
  [log('2026-10-16'), log('2026-10-19')],
  [], 3, D('2026-10-19')), 2)

// --- I: tanpa data sama sekali
eq('I kosong=0', hitungStreak([], [], 3, D('2026-10-21')), 0)

// --- J: bisaFreeze aturan
eq('J freeze hari wajib bolong', bisaFreeze('2026-10-19', [], [], 3, D('2026-10-21')), true)
eq('J freeze hari libur ditolak', bisaFreeze('2026-10-18', [], [], 3, D('2026-10-21')), false)
eq('J freeze hari ini ditolak', bisaFreeze('2026-10-21', [], [], 3, D('2026-10-21')), false)
eq('J freeze >7hari ditolak', bisaFreeze('2026-10-05', [], [], 3, D('2026-10-21')), false)
eq('J freeze sudah selesai ditolak', bisaFreeze('2026-10-19', [log('2026-10-19')], [], 3, D('2026-10-21')), false)
eq('J freeze dobel ditolak', bisaFreeze('2026-10-19', [], ['2026-10-19'], 3, D('2026-10-21')), false)

// --- K: infoStreak
const inf = infoStreak([log('2026-10-19')], [], 3, D('2026-10-21'), 9)
eq('K streak', inf.streak, 1)
eq('K terbaik pakai rekor', inf.terbaik, 9)
eq('K wajibHariIni (Rabu=false)', inf.wajibHariIni, false)
eq('K hariWajibBerikutnya=Kamis', inf.hariWajibBerikutnya, '2026-10-22')

const inf2 = infoStreak([log('2026-10-19')], [], 3, D('2026-10-19'), 0)
eq('K2 bisaNaikHariIni false (sudah)', inf2.bisaNaikHariIni, false)
eq('K2 wajibHariIni true', inf2.wajibHariIni, true)

// --- L: milestone list
eq('L milestones', MILESTONES.includes(7), true)

console.log(`\n${pass} lulus, ${fail} gagal`)
if (fail) process.exit(1)
