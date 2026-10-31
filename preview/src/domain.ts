import { CalculationParameters, Coordinates, Madhab, PrayerTimes, HighLatitudeRule } from 'adhan';

export const PRAYERS = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'] as const;
export type Prayer = typeof PRAYERS[number];
export type Mode = 'Pengingat' | 'Tegas';
export type Rule = { enabled: boolean; duration: number; mode: Mode; offset: number; reminder: number };
export type Settings = { city: string; lat: number; lng: number; zone: string; hanafi: boolean; enabled: boolean; selected: string[]; whitelist: string[]; rules: Record<Prayer, Rule>; theme: 'light' | 'dark'; notifications: boolean };
export type Window = { id: string; prayer: Prayer; start: Date; end: Date; rule: Rule };
export type DemoSession = { prayer: Prayer; start: number; end: number; mode: Mode; snoozedUntil?: number; snoozeUsed?: boolean };
export const CITIES = [
  { name: 'Jakarta', lat: -6.2115, lng: 106.8452, zone: 'Asia/Jakarta' },
  { name: 'Bandung', lat: -6.9175, lng: 107.6191, zone: 'Asia/Jakarta' },
  { name: 'Yogyakarta', lat: -7.7956, lng: 110.3695, zone: 'Asia/Jakarta' },
  { name: 'Surabaya', lat: -7.2575, lng: 112.7521, zone: 'Asia/Jakarta' },
  { name: 'Medan', lat: 3.5952, lng: 98.6722, zone: 'Asia/Jakarta' },
  { name: 'Makassar', lat: -5.1477, lng: 119.4327, zone: 'Asia/Makassar' },
  { name: 'Denpasar', lat: -8.6705, lng: 115.2126, zone: 'Asia/Makassar' },
  { name: 'Jayapura', lat: -2.5337, lng: 140.7181, zone: 'Asia/Jayapura' },
];
export const DEFAULT_SETTINGS: Settings = {
  city: 'Jakarta', lat: -6.2115, lng: 106.8452, zone: 'Asia/Jakarta', hanafi: false, enabled: true,
  selected: ['tiktok', 'instagram', 'youtube'], whitelist: ['whatsapp'], theme: 'light', notifications: true,
  rules: Object.fromEntries(PRAYERS.map(p => [p, { enabled: true, duration: 20, mode: 'Pengingat', offset: 0, reminder: 5 }])) as Record<Prayer, Rule>,
};
export const APP_CATALOG = [
  { id: 'tiktok', name: 'TikTok', category: 'Hiburan', initial: '♪', color: '#171717' },
  { id: 'instagram', name: 'Instagram', category: 'Sosial', initial: '◎', color: '#c44779' },
  { id: 'youtube', name: 'YouTube', category: 'Video', initial: '▶', color: '#df4343' },
  { id: 'mobilelegends', name: 'Mobile Legends', category: 'Game', initial: 'M', color: '#967338' },
  { id: 'freefire', name: 'Free Fire', category: 'Game', initial: 'F', color: '#db8a32' },
  { id: 'chrome', name: 'Chrome', category: 'Browser', initial: '◉', color: '#4386dc' },
  { id: 'whatsapp', name: 'WhatsApp', category: 'Komunikasi', initial: '✆', color: '#329669' },
  { id: 'telegram', name: 'Telegram', category: 'Komunikasi', initial: '➤', color: '#3997c9' },
  { id: 'spotify', name: 'Spotify', category: 'Musik', initial: '≋', color: '#258956' },
  { id: 'netflix', name: 'Netflix', category: 'Video', initial: 'N', color: '#b9363d' },
];
export function dateInZone(now: Date, zone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(now);
  const get = (t: string) => parts.find(p => p.type === t)?.value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}
export function validateSettings(s: Settings) {
  if (!Number.isFinite(s.lat) || s.lat < -90 || s.lat > 90 || !Number.isFinite(s.lng) || s.lng < -180 || s.lng > 180) throw Error('Koordinat tidak valid.');
  for (const r of Object.values(s.rules)) if (r.duration < 1 || r.duration > 120 || Math.abs(r.offset) > 30) throw Error('Durasi atau koreksi tidak valid.');
}
export function windowsFor(now: Date, settings: Settings): Window[] {
  validateSettings(settings);
  const [y, m, d] = dateInZone(now, settings.zone).split('-').map(Number);
  const params = new CalculationParameters('Other', 20, 18);
  params.madhab = settings.hanafi ? Madhab.Hanafi : Madhab.Shafi;
  params.highLatitudeRule = HighLatitudeRule.TwilightAngle;
  const times = new PrayerTimes(new Coordinates(settings.lat, settings.lng), new Date(y, m - 1, d, 12), params);
  const starts = [times.fajr, times.dhuhr, times.asr, times.maghrib, times.isha];
  return PRAYERS.flatMap((prayer, i) => {
    const rule = settings.rules[prayer];
    if (!rule.enabled || !starts[i] || !Number.isFinite(starts[i].getTime())) return [];
    const start = new Date(starts[i].getTime() + rule.offset * 60000);
    return [{ id: `${dateInZone(now, settings.zone)}:${prayer}`, prayer, start, end: new Date(start.getTime() + rule.duration * 60000), rule }];
  });
}
export function formatTime(date: Date, zone: string) { return new Intl.DateTimeFormat('id-ID', { timeZone: zone, hour: '2-digit', minute: '2-digit', hour12: false }).format(date).replace('.', ':'); }
export function countdown(end: number, now: number) { const sec = Math.max(0, Math.ceil((end - now) / 1000)); return `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`; }
export function nextWindow(windows: Window[], now: number) { return windows.find(w => w.end.getTime() > now); }
export function activeWindow(windows: Window[], now: number) { return windows.find(w => w.start.getTime() <= now && now < w.end.getTime()); }
export function demoDecision(session: DemoSession | null, appId: string, s: Settings, now: number): 'allow' | 'remind' | 'block' {
  if (!session || !s.enabled || now < session.start || now >= session.end || (session.snoozedUntil ?? 0) > now) return 'allow';
  if (s.whitelist.includes(appId) || !s.selected.includes(appId)) return 'allow';
  return session.mode === 'Tegas' ? 'block' : 'remind';
}
export function snoozeDemo(session: DemoSession, now: number): DemoSession {
  if (session.mode !== 'Pengingat' || session.snoozeUsed || now >= session.end) return session;
  return { ...session, snoozeUsed: true, snoozedUntil: Math.min(session.end, now + 300000) };
}
export function loadSettings(): Settings {
  try {
    const raw = JSON.parse(localStorage.getItem('jedasholat-preview-v1') || 'null');
    if (!raw) return structuredClone(DEFAULT_SETTINGS);
    const merged = { ...DEFAULT_SETTINGS, ...raw, rules: { ...DEFAULT_SETTINGS.rules, ...raw.rules } };
    validateSettings(merged); return merged;
  } catch { return structuredClone(DEFAULT_SETTINGS); }
}
