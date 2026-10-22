import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { useApp } from '../store'
import { IcX } from './Icon'

/* ------------------------------- Button ------------------------------- */
export function Btn({
  children,
  onClick,
  variant = 'primary',
  size,
  disabled,
  style,
  type = 'button',
}: {
  children: ReactNode
  onClick?: () => void
  variant?: 'primary' | 'ghost' | 'soft' | 'danger'
  size?: 'sm' | 'lg'
  disabled?: boolean
  style?: React.CSSProperties
  type?: 'button' | 'submit'
}) {
  return (
    <button
      type={type}
      className={`btn btn-${variant}${size ? ` btn-${size}` : ''}`}
      onClick={onClick}
      disabled={disabled}
      style={style}
    >
      {children}
    </button>
  )
}

/* -------------------------------- Modal -------------------------------- */
export function Modal({
  open,
  onClose,
  title,
  children,
  actions,
  dismissable = true,
}: {
  open: boolean
  onClose: () => void
  title?: string
  children?: ReactNode
  actions?: ReactNode
  dismissable?: boolean
}) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && dismissable) onClose()
    }
    window.addEventListener('keydown', onKey)
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = prev
    }
  }, [open, onClose, dismissable])

  if (!open) return null

  return (
    <div
      className="modal-back"
      onClick={(e) => {
        if (e.target === e.currentTarget && dismissable) onClose()
      }}
    >
      <div className="modal" role="dialog" aria-modal="true" aria-label={title}>
        {dismissable && (
          <button
            className="icon-btn"
            style={{ position: 'absolute', right: 16, top: 16, width: 34, height: 34 }}
            onClick={onClose}
            aria-label="Tutup"
          >
            <IcX size={17} />
          </button>
        )}
        <div className="modal-grab" />
        {title && <h3 style={{ paddingRight: 40 }}>{title}</h3>}
        {children}
        {actions && <div className="modal-actions">{actions}</div>}
      </div>
    </div>
  )
}

/* ------------------------------- Toast host ------------------------------- */
export function ToastHost() {
  const { toasts, hapusToast } = useApp()
  return (
    <div className="toast-wrap">
      {toasts.map((t) => (
        <div key={t.id} className={`toast ${t.tipe}`} onClick={() => hapusToast(t.id)}>
          <span>{t.tipe === 'sukses' ? '✅' : t.tipe === 'peringatan' ? '⚠️' : 'ℹ️'}</span>
          <span style={{ flex: 1 }}>{t.pesan}</span>
        </div>
      ))}
    </div>
  )
}

/* ----------------------------- Progress ring ----------------------------- */
export function ProgressRing({
  progress,
  children,
  size = 260,
  stroke = 12,
  color = 'url(#gradApi)',
  trackColor,
}: {
  progress: number
  children?: ReactNode
  size?: number
  stroke?: number
  color?: string
  trackColor?: string
}) {
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  const p = Math.min(1, Math.max(0, progress))
  return (
    <div className="ring-wrap" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <defs>
          <linearGradient id="gradApi" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#FFC542" />
            <stop offset="55%" stopColor="#FF6B1A" />
            <stop offset="100%" stopColor="#E24E06" />
          </linearGradient>
          <linearGradient id="gradHijau" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#4ADE80" />
            <stop offset="100%" stopColor="#16A34A" />
          </linearGradient>
        </defs>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke={trackColor ?? 'rgba(255,255,255,0.07)'}
          strokeWidth={stroke}
          fill="none"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke={color}
          strokeWidth={stroke}
          fill="none"
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c * (1 - p)}
          style={{ transition: 'stroke-dashoffset 0.35s linear' }}
        />
      </svg>
      <div className="ring-center">{children}</div>
    </div>
  )
}

/* ------------------------------- Confetti ------------------------------- */
export function Confetti({ fire }: { fire: number }) {
  const pieces = useMemo(() => {
    if (!fire) return []
    const colors = ['#FF6B1A', '#FFC542', '#22C55E', '#3B82F6', '#A855F7', '#22D3EE']
    return Array.from({ length: 44 }, (_, i) => ({
      id: `${fire}-${i}`,
      left: Math.random() * 100,
      delay: Math.random() * 0.5,
      dur: 1.6 + Math.random() * 1.4,
      color: colors[i % colors.length],
      w: 5 + Math.random() * 6,
      h: 9 + Math.random() * 8,
      rot: Math.random() * 360,
    }))
  }, [fire])

  if (!fire || !pieces.length) return null

  return (
    <div className="confetti-wrap" key={fire}>
      {pieces.map((p) => (
        <span
          key={p.id}
          className="confetti"
          style={{
            left: `${p.left}%`,
            width: p.w,
            height: p.h,
            background: p.color,
            animationDelay: `${p.delay}s`,
            animationDuration: `${p.dur}s`,
            transform: `rotate(${p.rot}deg)`,
          }}
        />
      ))}
    </div>
  )
}

/* -------------------------------- Switch -------------------------------- */
export function Switch({ on, onChange }: { on: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      className={`switch${on ? ' on' : ''}`}
      role="switch"
      aria-checked={on}
      onClick={() => onChange(!on)}
    >
      <i />
    </button>
  )
}

/* ------------------------------- Segmented ------------------------------- */
export function Segmented<T extends string | number>({
  value,
  options,
  onChange,
}: {
  value: T
  options: Array<{ value: T; label: string }>
  onChange: (v: T) => void
}) {
  return (
    <div className="segmented">
      {options.map((o) => (
        <button
          key={String(o.value)}
          className={o.value === value ? 'on' : ''}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}

/* --------------------------------- Stepper -------------------------------- */
export function Stepper({
  value,
  onChange,
  min = 0,
  max = 999,
  step = 1,
  suffix,
}: {
  value: number
  onChange: (v: number) => void
  min?: number
  max?: number
  step?: number
  suffix?: string
}) {
  return (
    <div className="stepper">
      <button onClick={() => onChange(Math.max(min, value - step))} aria-label="Kurangi">
        −
      </button>
      <b>
        {value}
        {suffix ? <span style={{ fontSize: 11, color: 'var(--dim)' }}>{suffix}</span> : null}
      </b>
      <button onClick={() => onChange(Math.min(max, value + step))} aria-label="Tambah">
        +
      </button>
    </div>
  )
}

/* ---------------------------------- Ringkasan modal ---------------------------------- */
export function useNow(intervalMs = 30000) {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), intervalMs)
    return () => window.clearInterval(id)
  }, [intervalMs])
  return now
}
