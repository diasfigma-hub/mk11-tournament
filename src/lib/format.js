import { LEVELS, PLATFORMS } from './constants'

export function platformLabel(value) {
  return PLATFORMS.find((p) => p.value === value)?.label || '—'
}

export function levelLabel(value) {
  return LEVELS.find((l) => l.value === value)?.label || '—'
}

export function formatDate(value, withTime = true) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat(
    'ru-RU',
    withTime
      ? { day: '2-digit', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' }
      : { day: '2-digit', month: 'short', year: 'numeric' },
  ).format(date)
}

export function formatShortDate(value) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('ru-RU', { day: '2-digit', month: '2-digit', year: '2-digit' })
    .format(date)
    .replace(/\s/g, '')
}

export function playerName(player) {
  if (!player) return '—'
  return player.nickname || player.fullName || 'Боец'
}

export function initials(name) {
  return (name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || '')
    .join('')
}

export function isFighter(participant) {
  return Boolean(participant?.nickname)
}

export function pluralizeFighters(count) {
  const value = Math.abs(Number(count) || 0)
  const mod10 = value % 10
  const mod100 = value % 100
  if (mod10 === 1 && mod100 !== 11) return `${value} боец`
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return `${value} бойца`
  return `${value} бойцов`
}
