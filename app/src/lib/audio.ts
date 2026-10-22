let ctx: AudioContext | null = null

function getCtx(): AudioContext | null {
  if (typeof window === 'undefined') return null
  try {
    if (!ctx) {
      const AC =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext?: typeof AudioContext })
          .webkitAudioContext
      if (!AC) return null
      ctx = new AC()
    }
    if (ctx.state === 'suspended') void ctx.resume()
    return ctx
  } catch {
    return null
  }
}

export function unlockAudio() {
  getCtx()
}

interface ToneOpts {
  freq?: number
  dur?: number
  vol?: number
  type?: OscillatorType
  delay?: number
}

export function tone({
  freq = 880,
  dur = 0.12,
  vol = 0.16,
  type = 'sine',
  delay = 0,
}: ToneOpts = {}) {
  const ac = getCtx()
  if (!ac) return
  const t0 = ac.currentTime + delay
  const osc = ac.createOscillator()
  const gain = ac.createGain()
  osc.type = type
  osc.frequency.setValueAtTime(freq, t0)
  gain.gain.setValueAtTime(0.0001, t0)
  gain.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol), t0 + 0.012)
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur)
  osc.connect(gain)
  gain.connect(ac.destination)
  osc.start(t0)
  osc.stop(t0 + dur + 0.03)
}

export const sfx = {
  tick() {
    tone({ freq: 660, dur: 0.07, vol: 0.1, type: 'triangle' })
  },
  blip() {
    tone({ freq: 1040, dur: 0.09, vol: 0.14, type: 'sine' })
  },
  setDone() {
    tone({ freq: 720, dur: 0.1, vol: 0.16 })
    tone({ freq: 1080, dur: 0.14, vol: 0.14, delay: 0.09 })
  },
  restEnd() {
    tone({ freq: 520, dur: 0.1, vol: 0.14, type: 'triangle' })
    tone({ freq: 780, dur: 0.14, vol: 0.14, delay: 0.1, type: 'triangle' })
  },
  gong() {
    const ac = getCtx()
    if (!ac) return
    const t0 = ac.currentTime
    ;[110, 165, 220, 330, 495].forEach((f, i) => {
      const osc = ac.createOscillator()
      const gain = ac.createGain()
      osc.type = i % 2 === 0 ? 'sine' : 'triangle'
      osc.frequency.setValueAtTime(f, t0)
      osc.frequency.exponentialRampToValueAtTime(f * 0.92, t0 + 1.1)
      gain.gain.setValueAtTime(0.0001, t0)
      gain.gain.exponentialRampToValueAtTime(0.16 / (i + 1), t0 + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.0001, t0 + 1.8)
      osc.connect(gain)
      gain.connect(ac.destination)
      osc.start(t0)
      osc.stop(t0 + 1.9)
    })
  },
  complete() {
    ;[523, 659, 784, 1047].forEach((f, i) =>
      tone({ freq: f, dur: 0.22, vol: 0.14, delay: i * 0.11, type: 'triangle' })
    )
  },
  levelUp() {
    ;[659, 880, 1175, 1568].forEach((f, i) =>
      tone({ freq: f, dur: 0.24, vol: 0.13, delay: i * 0.09 })
    )
  },
}

export function getar(pattern: number | number[]) {
  try {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      navigator.vibrate(pattern)
    }
  } catch {
    /* diamkan */
  }
}

export async function mintaWakeLock(): Promise<{ release: () => Promise<void> } | null> {
  try {
    const nav = navigator as Navigator & {
      wakeLock?: { request: (t: 'screen') => Promise<{ release: () => Promise<void> }> }
    }
    if (!nav.wakeLock) return null
    const lock = await nav.wakeLock.request('screen')
    return lock
  } catch {
    return null
  }
}
