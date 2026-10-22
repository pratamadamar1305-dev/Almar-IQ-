import { SESI, buildQueue, durasiGerakan, URUTAN_HARI } from '../src/lib/data'

let pass=0, fail=0
const eq=(n:string,g:unknown,e:unknown)=>{ if(JSON.stringify(g)===JSON.stringify(e))pass++; else {fail++;console.log(`❌ ${n}: ${JSON.stringify(g)} != ${JSON.stringify(e)}`)} }
const ok=(n:string,c:boolean)=>{ if(c)pass++; else {fail++;console.log(`❌ ${n}`)} }

const ids = new Set<string>()
let totalGerakan = 0
for (const day of URUTAN_HARI) {
  const s = SESI[day]
  ok(`${day} punya tema`, s.tema.length > 5)
  ok(`${day} durasi > 0`, s.durasiMenit > 0)
  for (const b of s.blok) {
    for (const g of b.gerakan) {
      totalGerakan++
      ok(`${g.id} id unik`, !ids.has(g.id)); ids.add(g.id)
      ok(`${g.id} punya cara`, g.cara.length > 15)
      ok(`${g.id} sets > 0`, g.sets > 0)
      ok(`${g.id} durasi > 0`, durasiGerakan(g) > 0)
      if (g.tipe === 'rep') ok(`${g.id} punya reps`, (g.reps ?? 0) > 0)
      if (g.tipe === 'hold') ok(`${g.id} punya holdDetik`, (g.holdDetik ?? 0) > 0)
      if (g.tipe === 'drill') ok(`${g.id} punya drillDetik`, (g.drillDetik ?? 0) > 0)
    }
  }
}

eq('jumlah gerakan total = 38', totalGerakan, 38)
eq('queue senin = 10', buildQueue(SESI.senin).length, 10)
eq('queue selasa = 8', buildQueue(SESI.selasa).length, 8)
eq('queue kamis = 10', buildQueue(SESI.kamis).length, 10)
eq('queue jumat = 26 (8x3 ronde + 2)', buildQueue(SESI.jumat).length, 26)

const qj = buildQueue(SESI.jumat)
eq('ronde pertama mulai dari pike', qj[0].gerakan.id, 'jumat-pike')
eq('ronde 2 mulai dari pike lagi', qj[8].gerakan.id, 'jumat-pike')
eq('ronde 2 label', qj[8].round, 2)
eq('ronde 3 label', qj[16].round, 3)
eq('item terakhir finisher', qj[25].gerakan.id, 'jumat-finisher')

// total set target
const setSenin = buildQueue(SESI.senin).reduce((n,q)=>n+q.gerakan.sets,0)
eq('total set senin = 28', setSenin, 28)

console.log(`\n${pass} lulus, ${fail} gagal`)
if (fail) process.exit(1)
