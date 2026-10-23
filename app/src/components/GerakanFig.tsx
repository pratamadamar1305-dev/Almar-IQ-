import { useMemo } from 'react'
import { figMarkup, hasPose } from '../lib/fig'

interface Props {
  id: string
  /** animasikan fase awal -> akhir */
  animate?: boolean
  /** lebar dalam px; tinggi ikut rasio 120:130 */
  size?: number
  className?: string
  /** teks aksesibilitas; kosongkan kalau murni dekoratif */
  label?: string
}

/**
 * Ilustrasi stick-man satu gerakan. SVG-nya digenerate dari poses.json,
 * jadi tajam di semua ukuran dan ikut tema terang/gelap.
 */
export function GerakanFig({ id, animate = false, size = 120, className, label }: Props) {
  const html = useMemo(() => figMarkup(id, { animate }), [id, animate])

  if (!html) return null

  const h = Math.round((size * 130) / 120)
  return (
    <svg
      viewBox="0 0 120 130"
      width={size}
      height={h}
      className={`gfig${className ? ` ${className}` : ''}`}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      focusable="false"
      dangerouslySetInnerHTML={{ __html: html }}
    />
  )
}

/** Panel besar untuk layar Detail / Player. */
export function GerakanFigPanel({
  id,
  animate = true,
  label,
}: {
  id: string
  animate?: boolean
  label?: string
}) {
  if (!hasPose(id)) return null
  return (
    <div className="gfig-panel">
      <div className="gfig-grid" aria-hidden="true" />
      <GerakanFig id={id} animate={animate} size={168} label={label} />
      <div className="gfig-hint">
        <span className="gfig-dot" />
        gerak: awal ke akhir
      </div>
    </div>
  )
}
