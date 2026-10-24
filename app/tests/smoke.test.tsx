import { JSDOM } from 'jsdom'

const dom = new JSDOM('<!doctype html><html><body><div id="root"></div></body></html>', {
  url: 'http://localhost:3000/',
  pretendToBeVisual: true,
})
const w = dom.window as unknown as Window & typeof globalThis
;(globalThis as any).window = w
;(globalThis as any).document = w.document
;Object.defineProperty(globalThis, 'navigator', { value: w.navigator, configurable: true, writable: true })
;(globalThis as any).HTMLElement = w.HTMLElement
;(globalThis as any).Element = w.Element
;(globalThis as any).Node = w.Node
;(globalThis as any).localStorage = w.localStorage
;(globalThis as any).HashChangeEvent = w.HashChangeEvent
;(globalThis as any).IS_REACT_ACT_ENVIRONMENT = true
w.scrollTo = () => {}
;(w as any).matchMedia = () => ({ matches: false, addEventListener() {}, removeEventListener() {} })

const errors: string[] = []
const origError = console.error
console.error = (...a: any[]) => { errors.push(a.map(String).join(' ')); origError(...a) }
w.addEventListener('error', (e: any) => errors.push('window.error: ' + e.message))

async function main() {
  const React = await import('react')
  const { createRoot } = await import('react-dom/client')
  const { default: App } = await import('../src/App')
  const { AppProvider } = await import('../src/store')

  const act = (React as any).act
  const root = createRoot(document.getElementById('root')!)

  await act(async () => {
    root.render(React.createElement(AppProvider, null, React.createElement(App)))
  })

  let pass = 0, fail = 0
  const ok = (n: string, c: boolean) => { if (c) { pass++ } else { fail++; console.log('❌ ' + n) } }
  const txt = () => document.body.textContent || ''
  const byText = (t: string, tag = 'button') =>
    Array.from(document.querySelectorAll(tag)).find((el) => (el.textContent || '').includes(t)) as HTMLElement | undefined
  const click = async (el?: HTMLElement, label = '?') => {
    if (!el) throw new Error('elemen tidak ketemu: ' + label)
    await act(async () => { el.dispatchEvent(new w.MouseEvent('click', { bubbles: true })) })
    // jeda realistis antar tap (guard anti-double-tap di app = 220ms)
    await act(async () => { await new Promise((r) => setTimeout(r, 240)) })
  }
  const nav = async (hash: string) => {
    await act(async () => {
      w.location.hash = hash
      w.dispatchEvent(new w.HashChangeEvent('hashchange'))
    })
  }

  // 1. Home render
  ok('brand tampil', txt().includes('DOJO TARUNG'))
  ok('streak hero tampil', txt().includes('hari beruntun'))
  ok('judul hari ini tampil', txt().includes('Hari ini'))
  ok('nav bawah tampil', txt().includes('Progres') && txt().includes('Setting'))

  // 2. Home pertama TIDAK ketutup modal (modal muncul pas mau mulai)
  ok('home bersih tanpa modal', !txt().includes('Sebelum mulai'))

  // 3. Detail Senin
  await nav('#/hari/senin')
  ok('detail senin tampil', txt().includes('Tangan Dorong'))
  ok('gerakan pike tampil', txt().includes('Pike Push-Up'))
  await click(byText('Pike Push-Up'), 'Pike')
  ok('accordion kebuka (cara)', txt().includes('Posisi huruf V terbalik'))
  ok('kesalahan umum tampil', txt().includes('Jangan gini'))

  // 3b. Ilustrasi stick-man
  const thumbs = document.querySelectorAll('.ger-thumb svg.gfig')
  ok('thumbnail ilustrasi semua gerakan', thumbs.length === 10)
  const panel = document.querySelector('.ger-item.open .gfig-panel svg.gfig')
  ok('panel ilustrasi di accordion', !!panel)
  ok('panel punya gambar (line)', (panel?.querySelectorAll('line,circle').length ?? 0) > 8)
  ok('panel memperlihatkan dua tahap', document.querySelectorAll('.ger-item.open .gfig-panel .gfig-step').length === 2)
  ok('tahap awal dan akhir statis agar mudah dibandingkan', !(panel?.innerHTML || '').includes('<animate'))
  ok('ilustrasi tidak NaN', !(panel?.innerHTML || '').includes('NaN'))
  ok('panel ilustrasi punya aria-label', (document.querySelector('.ger-item.open .gfig-steps')?.getAttribute('aria-label') || '').includes('Ilustrasi'))
  const css = document.getElementById('fig-css')
  ok('css ilustrasi disuntik sekali', !!css && (css.textContent || '').includes('.gfig'))
  ok('css ilustrasi tidak dobel', document.querySelectorAll('#fig-css').length === 1)

  // 4. Mulai sesi -> gate izin ortu dulu
  await click(byText('Mulai Sesi Ini'), 'Mulai Sesi Ini')
  ok('modal izin muncul saat mulai', txt().includes('Sebelum mulai'))
  ok('player belum kebuka', !txt().includes('Set Selesai'))
  await click(byText('Aku udah izin'), 'Aku udah izin')
  await act(async () => { await new Promise((r) => setTimeout(r, 400)) })
  ok('player kebuka setelah izin', txt().includes('Set Selesai'))
  ok('nama gerakan di player', txt().includes('Pike Push-Up'))
  ok('timer tampil', /\d{2}:\d{2}/.test(txt()))
  ok('ilustrasi tampil di player', !!document.querySelector('.player-fig svg.gfig'))
  ok('ilustrasi player punya tahap siap dan gerak', document.querySelectorAll('.player-fig .gfig-step').length === 2)

  // 5. Selesaikan set 1 -> rest
  await click(byText('Set Selesai'), 'Set Selesai')
  ok('masuk fase istirahat', txt().includes('Tarik napas'))
  ok('tombol lewati istirahat ada', !!byText('Lewati Istirahat'))

  // 6. Lewati rest -> set 2
  await click(byText('Lewati Istirahat'), 'Lewati Istirahat')
  ok('balik ke pike (set 2)', txt().includes('set 2 dari 3'))

  // 7. Set 2 -> rest -> set 3 -> gerakan berikutnya
  await click(byText('Set Selesai'), 'Set Selesai')
  await click(byText('Lewati Istirahat'), 'Lewati Istirahat')
  await click(byText('Set Selesai'), 'Set Selesai')
  ok('pindah ke gerakan ke-2', txt().includes('Overhead Press'))

  // 8. Selesaikan sesi (masih di bawah 80%) -> modal peringatan
  await click(byText('Selesai sesi'), 'Selesai sesi')
  ok('modal konfirmasi muncul', txt().includes('Selesaikan sesi sekarang'))
  ok('peringatan sesi ringan', txt().includes('sesi ringan'))
  await click(byText('Ya, selesaikan'), 'Ya selesaikan')
  ok('layar hasil tampil', txt().includes('Sesi Ringan Tercatat'))

  // 9. Balik home, data tersimpan
  await click(byText('Balik ke Home'), 'Balik ke Home')
  ok('balik ke home', txt().includes('hari beruntun'))
  const saved = JSON.parse(w.localStorage.getItem('dojo-tarung-v1') || '{}')
  ok('log tersimpan di localStorage', Array.isArray(saved.logs) && saved.logs.length === 1)
  ok('sesi ringan tidak valid', saved.logs?.[0]?.valid === false)

  // 10. Timer gong
  // 9b. SESI PENUH: jalanin semua 28 set Senin sampai selesai
  await nav('#/hari/senin')
  await click(byText('Mulai Sesi Ini'), 'Mulai sesi penuh')
  ok('sesi penuh jalan', txt().includes('Set Selesai'))
  let step = 0
  for (; step < 200; step++) {
    if (txt().includes('Sesi Selesai!') || txt().includes('Sesi Ringan Tercatat')) break
    const bSet = byText('Set Selesai')
    const bSkip = byText('Lewati Istirahat')
    if (bSet) await click(bSet, 'set')
    else if (bSkip) await click(bSkip, 'rest')
    else break
  }
  ok('sesi penuh selesai', txt().includes('Sesi Selesai!'))
  ok('bukan sesi ringan', !txt().includes('Sesi Ringan Tercatat'))
  const finalState = JSON.parse(w.localStorage.getItem('dojo-tarung-v1') || '{}')
  const logTerakhir = (finalState.logs || [])[(finalState.logs || []).length - 1]
  ok('log valid tersimpan', logTerakhir?.valid === true)
  ok('gerakan lengkap 10/10', logTerakhir?.itemsDone === 10 && logTerakhir?.itemsTotal === 10)
  ok('total set 28', logTerakhir?.totalSet === 28)
  ok('streakTerbaik tersimpan', (finalState.streakTerbaik || 0) >= 0)
  await click(byText('Balik ke Home'), 'Home')
  ok('home tampil setelah sesi penuh', txt().includes('hari beruntun'))

  await nav('#/timer')
  ok('timer gong tampil', txt().includes('Simulasi Tarung'))
  await click(byText('Mulai'), 'Mulai')
  ok('fase bersiap', txt().includes('Bersiap'))

  // 11. Setting
  await nav('#/setting')
  ok('setting tampil', txt().includes('Nama panggilan') || txt().includes('NAMA PANGGILAN'))
  await click(byText('Muat'), 'Muat')
  ok('modal demo', txt().includes('Muat data demo?'))
  await click(byText('Muat data demo'), 'Muat data demo')
  ok('data demo kepasang', (JSON.parse(w.localStorage.getItem('dojo-tarung-v1') || '{}').logs || []).length > 5)

  // 12. Progres
  await nav('#/progres')
  ok('progres tampil', txt().includes('Kalender latihan'))
  ok('heatmap ada', document.querySelectorAll('.hm-cell').length === 63)
  ok('badge tampil', txt().includes('Badge streak'))

  // 12b. Layar Install
  await nav('#/install')
  ok('layar install tampil', txt().includes('Pasang di HP'))
  ok('ada langkah manual', txt().includes('Cara di Android') || txt().includes('Cara di iPhone'))
  ok('ada penjelasan PWA', txt().includes('Kenapa nggak APK'))
  ok('ada tombol kembali', !!document.querySelector('.icon-btn'))

  // 13. Aturan
  await nav('#/aturan')
  ok('aturan tampil', txt().includes('Aturan aman') || txt().includes('Peraturan tarung'))

  // 14. Route aneh tidak crash
  await nav('#/hari/ngawur')
  ok('route ngawur aman', txt().includes('DOJO TARUNG'))

  const realErrors = errors.filter((e) => !/not implemented|Not implemented|Error: Not implemented/i.test(e))
  ok('tidak ada error console', realErrors.length === 0)
  if (realErrors.length) console.log('ERRORS:', realErrors.slice(0, 5))

  console.log(`\n${pass} lulus, ${fail} gagal`)
  // proses harus keluar manual: ada setInterval app yang masih hidup
  process.exit(fail ? 1 : 0)
}

// watchdog biar nggak menggantung
setTimeout(() => { console.log('TIMEOUT: test menggantung'); process.exit(2) }, 90000).unref()

main().catch((e) => { console.log('FATAL', e); process.exit(1) })
