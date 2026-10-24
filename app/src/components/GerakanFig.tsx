import { useMemo } from 'react'
import { figFrameMarkup, figMarkup, hasPose } from '../lib/fig'

interface Props {
  id: string
  /** animasikan fase awal -> akhir */
  animate?: boolean
  phase?: 'a' | 'b'
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
export function GerakanFig({ id, animate = false, phase, size = 120, className, label }: Props) {
  const html = useMemo(
    () => phase ? figFrameMarkup(id, phase) : figMarkup(id, { animate }),
    [id, animate, phase],
  )

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
  label,
}: {
  id: string
  label?: string
}) {
  if (!hasPose(id)) return null
  return (
    <div className="gfig-panel">
      <div className="gfig-grid" aria-hidden="true" />
      <div className="gfig-steps" role="img" aria-label={label ?? 'Posisi awal lalu posisi akhir'}>
        <div className="gfig-step">
          <span className="gfig-step-label"><b>1</b> MULAI</span>
          <GerakanFig id={id} phase="a" size={106} />
        </div>
        <span className="gfig-step-arrow" aria-hidden="true">→</span>
        <div className="gfig-step">
          <span className="gfig-step-label"><b>2</b> AKHIR</span>
          <GerakanFig id={id} phase="b" size={106} />
        </div>
      </div>
      <div className="gfig-hint">
        <span className="gfig-dot" />
        mulai 1 → gerak ke 2 → kembali perlahan
      </div>
    </div>
  )
}
