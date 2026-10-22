import { useEffect, useState } from 'react'

/* ------------------------------------------------------------------ */
/*  Tipe event install prompt (belum ada di lib.dom bawaan TS)          */
/* ------------------------------------------------------------------ */
interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[]
  readonly userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>
  prompt: () => Promise<void>
}

type Listener = () => void

let deferredPrompt: BeforeInstallPromptEvent | null = null
const listeners = new Set<Listener>()

function emit() {
  listeners.forEach((l) => l())
}

/** Dipasang sekali di main.tsx, sebelum React render. */
export function pasangListenerInstall() {
  if (typeof window === 'undefined') return

  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault()
    deferredPrompt = e as BeforeInstallPromptEvent
    emit()
  })

  window.addEventListener('appinstalled', () => {
    deferredPrompt = null
    try {
      localStorage.setItem('dojo-installed', '1')
    } catch {
      /* noop */
    }
    emit()
  })

  const onVis = () => emit()
  document.addEventListener('visibilitychange', onVis)
}

export function punyaPrompt(): boolean {
  return !!deferredPrompt
}

export type StatusInstall = 'bisa-install' | 'sudah-terpasang' | 'manual'

export function statusInstall(): StatusInstall {
  if (typeof window === 'undefined') return 'manual'
  if (isStandalone()) return 'sudah-terpasang'
  if (deferredPrompt) return 'bisa-install'
  return 'manual'
}

export function isStandalone(): boolean {
  if (typeof window === 'undefined') return false
  const mq = window.matchMedia?.('(display-mode: standalone)')?.matches ?? false
  const iosStandalone = (window.navigator as Navigator & { standalone?: boolean }).standalone
  const androidApp = document.referrer.startsWith('android-app://')
  return mq || !!iosStandalone || androidApp
}

export function isIOS(): boolean {
  if (typeof navigator === 'undefined') return false
  const ua = navigator.userAgent || ''
  const iOS = /iPad|iPhone|iPod/.test(ua)
  const iPadOS = navigator.platform === 'MacIntel' && (navigator.maxTouchPoints ?? 0) > 1
  return iOS || iPadOS
}

/** True kalau browser mendukung install (Chrome/Edge/Samsung Internet di Android). */
export function dukungInstall(): boolean {
  return typeof window !== 'undefined' && 'onbeforeinstallprompt' in window
}

export async function mulaiInstall(): Promise<'accepted' | 'dismissed' | 'tidak-tersedia'> {
  if (!deferredPrompt) return 'tidak-tersedia'
  const ev = deferredPrompt
  try {
    await ev.prompt()
    const { outcome } = await ev.userChoice
    if (outcome === 'accepted') deferredPrompt = null
    emit()
    return outcome
  } catch {
    return 'tidak-tersedia'
  }
}

export function usePWA() {
  const [, force] = useState(0)
  const [standalone, setStandalone] = useState(() => isStandalone())

  useEffect(() => {
    const l = () => force((n) => n + 1)
    listeners.add(l)
    const mq = window.matchMedia?.('(display-mode: standalone)')
    const onMq = () => setStandalone(isStandalone())
    mq?.addEventListener?.('change', onMq)
    onMq()
    return () => {
      listeners.delete(l)
      mq?.removeEventListener?.('change', onMq)
    }
  }, [])

  return {
    status: statusInstall(),
    standalone,
    ios: isIOS(),
    didukung: dukungInstall(),
    install: mulaiInstall,
  }
}

/* ------------------------------------------------------------------ */
/*  Update service worker                                               */
/* ------------------------------------------------------------------ */
export function daftarkanSW() {
  if (typeof window === 'undefined') return
  if (!('serviceWorker' in navigator)) return
  // di dev server SW sengaja tidak didaftarkan (biar HMR tidak kacau)
  if (import.meta.env.DEV) return

  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register(new URL('sw.js', document.baseURI).href, { scope: './' })
      .catch(() => {
        /* offline pertama / hosting tanpa https */
      })
  })
}

export function useSWUpdate() {
  const [tersedia, setTersedia] = useState(false)
  const [waiting, setWaiting] = useState<ServiceWorker | null>(null)

  useEffect(() => {
    if (!('serviceWorker' in navigator)) return
    let done = false

    const cek = async () => {
      const reg = await navigator.serviceWorker.getRegistration()
      if (!reg || done) return
      if (reg.waiting) {
        setWaiting(reg.waiting)
        setTersedia(true)
      }
      reg.addEventListener('updatefound', () => {
        const baru = reg.installing
        if (!baru) return
        baru.addEventListener('statechange', () => {
          if (baru.state === 'installed' && navigator.serviceWorker.controller) {
            setWaiting(baru)
            setTersedia(true)
          }
        })
      })
    }
    void cek()

    const onController = () => {
      done = true
    }
    navigator.serviceWorker.addEventListener('controllerchange', onController)
    return () => navigator.serviceWorker.removeEventListener('controllerchange', onController)
  }, [])

  const terapkan = () => {
    waiting?.postMessage('SKIP_WAITING')
    window.setTimeout(() => window.location.reload(), 320)
  }

  return { tersedia, terapkan }
}
