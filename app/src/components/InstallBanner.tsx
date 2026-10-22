import { useEffect, useState } from 'react'
import { usePWA } from '../lib/pwa'
import { go } from '../lib/nav'
import { IcX } from './Icon'

const KEY = 'dojo-install-banner'

/**
 * Banner ajakan install di Home.
 * Muncul kalau: belum terpasang, belum pernah ditutup, dan halaman dibuka
 * di HP (bukan desktop lebar). Tidak pernah menutupi konten penting.
 */
export default function InstallBanner() {
  const { status } = usePWA()
  const [visible, setVisible] = useState(false)
  const [closing, setClosing] = useState(false)

  useEffect(() => {
    if (status !== 'bisa-install') return
    let sudah = false
    try {
      sudah = localStorage.getItem(KEY) === 'tutup'
    } catch {
      /* noop */
    }
    if (sudah) return
    const t = window.setTimeout(() => setVisible(true), 1200)
    return () => window.clearTimeout(t)
  }, [status])

  if (!visible || status !== 'bisa-install') return null

  const tutup = () => {
    setClosing(true)
    try {
      localStorage.setItem(KEY, 'tutup')
    } catch {
      /* noop */
    }
    window.setTimeout(() => setVisible(false), 220)
  }

  return (
    <div
      style={{
        margin: '14px 18px 0',
        padding: '13px 14px',
        borderRadius: 16,
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        background: 'linear-gradient(135deg, rgba(255,107,26,0.16), rgba(255,197,66,0.06))',
        border: '1px solid rgba(255,107,26,0.3)',
        opacity: closing ? 0 : 1,
        transform: closing ? 'translateY(-6px)' : 'none',
        transition: 'opacity 0.2s, transform 0.2s',
      }}
    >
      <img
        src="./icons/icon-192.png"
        alt=""
        width={38}
        height={38}
        style={{ borderRadius: 11, flex: 'none' }}
      />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12.5, fontWeight: 800 }}>Pasang di layar HP lu</div>
        <div style={{ fontSize: 11, color: 'var(--dim)', marginTop: 2 }}>
          Buka kayak aplikasi biasa, bisa offline
        </div>
      </div>
      <button
        onClick={() => go('/install')}
        style={{
          padding: '9px 13px',
          borderRadius: 11,
          background: 'linear-gradient(145deg, #ff7c31, var(--orange))',
          color: '#1b0a02',
          fontSize: 12,
          fontWeight: 800,
          flex: 'none',
        }}
      >
        Install
      </button>
      <button
        onClick={tutup}
        aria-label="Tutup"
        style={{
          width: 28,
          height: 28,
          borderRadius: 9,
          display: 'grid',
          placeItems: 'center',
          color: 'var(--dim2)',
          flex: 'none',
        }}
      >
        <IcX size={14} />
      </button>
    </div>
  )
}
