import type { CSSProperties, ReactNode } from 'react'

interface P {
  size?: number
  strokeWidth?: number
  className?: string
  style?: CSSProperties
}

function S({
  size = 22,
  strokeWidth = 2,
  className,
  style,
  children,
}: P & { children: ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      style={style}
      aria-hidden="true"
    >
      {children}
    </svg>
  )
}

export const IcHome = (p: P) => (
  <S {...p}>
    <path d="M3 10.5 12 3l9 7.5" />
    <path d="M5 9.5V21h14V9.5" />
    <path d="M9.5 21v-6h5v6" />
  </S>
)

export const IcTimer = (p: P) => (
  <S {...p}>
    <circle cx="12" cy="13.5" r="8" />
    <path d="M12 9.5v4l2.5 1.5" />
    <path d="M9 3h6" />
  </S>
)

export const IcChart = (p: P) => (
  <S {...p}>
    <path d="M4 20V10" />
    <path d="M10 20V4" />
    <path d="M16 20v-7" />
    <path d="M22 20V7" />
  </S>
)

export const IcGear = (p: P) => (
  <S {...p}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1A1.6 1.6 0 0 0 9 19.4a1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.6 1.6 0 0 0 4.6 9a1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z" />
  </S>
)

export const IcChevron = (p: P) => (
  <S {...p}>
    <path d="m6 9 6 6 6-6" />
  </S>
)

export const IcBack = (p: P) => (
  <S {...p}>
    <path d="M15 18l-6-6 6-6" />
  </S>
)

export const IcX = (p: P) => (
  <S {...p}>
    <path d="M18 6 6 18M6 6l12 12" />
  </S>
)

export const IcPlay = (p: P) => (
  <S {...p}>
    <path d="M7 4.5v15l13-7.5z" fill="currentColor" stroke="none" />
  </S>
)

export const IcPause = (p: P) => (
  <S {...p}>
    <rect x="6" y="4.5" width="4" height="15" rx="1.4" fill="currentColor" stroke="none" />
    <rect x="14" y="4.5" width="4" height="15" rx="1.4" fill="currentColor" stroke="none" />
  </S>
)

export const IcCheck = (p: P) => (
  <S {...p}>
    <path d="M20 6 9 17l-5-5" />
  </S>
)

export const IcSkip = (p: P) => (
  <S {...p}>
    <path d="M5 5v14l10-7z" fill="currentColor" stroke="none" />
    <path d="M19 5v14" />
  </S>
)

export const IcRefresh = (p: P) => (
  <S {...p}>
    <path d="M20 11a8 8 0 1 0-2.3 6.3" />
    <path d="M20 4v7h-7" />
  </S>
)

export const IcShield = (p: P) => (
  <S {...p}>
    <path d="M12 3l8 3v6c0 4.5-3.3 8.2-8 9-4.7-.8-8-4.5-8-9V6z" />
    <path d="m9 12 2 2 4-4" />
  </S>
)

export const IcTrophy = (p: P) => (
  <S {...p}>
    <path d="M7 4h10v5a5 5 0 0 1-10 0z" />
    <path d="M7 6H4v2a3 3 0 0 0 3 3" />
    <path d="M17 6h3v2a3 3 0 0 1-3 3" />
    <path d="M9 20h6M12 14v6" />
  </S>
)

export const IcFlame = (p: P) => (
  <S {...p}>
    <path d="M12 2s5 3.5 5 8a5 5 0 0 1-10 0c0-1.5.6-2.6 1.2-3.4C9 8 12 9 12 9s-.5-4 0-7z" />
  </S>
)

export const IcTarget = (p: P) => (
  <S {...p}>
    <circle cx="12" cy="12" r="8" />
    <circle cx="12" cy="12" r="3.5" />
  </S>
)

export const IcSun = (p: P) => (
  <S {...p}>
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4" />
  </S>
)

export const IcMoon = (p: P) => (
  <S {...p}>
    <path d="M21 12.8A8.5 8.5 0 1 1 11.2 3a6.6 6.6 0 0 0 9.8 9.8z" />
  </S>
)

export const IcSnow = (p: P) => (
  <S {...p}>
    <path d="M12 2v20M4.5 6.5l15 11M19.5 6.5l-15 11" />
  </S>
)

export const IcTrash = (p: P) => (
  <S {...p}>
    <path d="M4 7h16M9 7V4.5h6V7M6 7l1 13h10l1-13" />
    <path d="M10 11v6M14 11v6" />
  </S>
)

export const IcStar = (p: P) => (
  <S {...p}>
    <path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z" />
  </S>
)

export const IcInfo = (p: P) => (
  <S {...p}>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 11v5M12 8h.01" />
  </S>
)
