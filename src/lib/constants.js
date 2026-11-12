export const GAME = {
  title: 'Mortal Kombat 11',
  short: 'MK11',
}

export const PLATFORMS = [
  { value: 'PS5', label: 'PlayStation 5' },
  { value: 'PS4', label: 'PlayStation 4' },
  { value: 'XBOX', label: 'Xbox One / Series X|S' },
  { value: 'PC', label: 'PC (Steam)' },
  { value: 'SWITCH', label: 'Nintendo Switch' },
]

export const LEVELS = [
  { value: 'rookie', label: 'Новичок' },
  { value: 'amateur', label: 'Любитель' },
  { value: 'pro', label: 'Профи' },
]

export const REGIONS = [
  'Акмолинская область',
  'Актюбинская область',
  'Алматинская область',
  'Атырауская область',
  'Восточно-Казахстанская область',
  'Жамбылская область',
  'Западно-Казахстанская область',
  'Карагандинская область',
  'Костанайская область',
  'Кызылординская область',
  'Мангистауская область',
  'Павлодарская область',
  'Северо-Казахстанская область',
  'Туркестанская область',
  'Астана (город)',
  'Алматы (город)',
  'Шымкент (город)',
  'Другая страна',
]

// Только базовая версия MK11: 24 персонажа. DLC (Kombat Pack 1/2, Aftermath)
// в турнире недоступны. Frost остаётся в списке, как и остальные.
export const ROSTER = [
  'Baraka',
  'Cassie Cage',
  'Cetrion',
  "D'Vorah",
  'Erron Black',
  'Frost',
  'Geras',
  'Jacqui Briggs',
  'Jade',
  'Jax Briggs',
  'Johnny Cage',
  'Kabal',
  'Kano',
  'Kitana',
  'Kollector',
  'Kotal Kahn',
  'Kung Lao',
  'Liu Kang',
  'Noob Saibot',
  'Raiden',
  'Scorpion',
  'Skarlet',
  'Sonya Blade',
  'Sub-Zero',
]

export function isAllowedCharacter(value) {
  return ROSTER.includes(value)
}

export const PLAYER_STATUSES = {
  accepted: { label: 'Допущен', badge: 'badge-win' },
  pending: { label: 'На проверке', badge: 'badge-gold' },
  disqualified: { label: 'Снят', badge: 'badge-blood' },
}

export const TOURNAMENT_STATUSES = {
  draft: { label: 'Набор участников', badge: 'badge-gold' },
  live: { label: 'В игре', badge: 'badge-blood' },
  finished: { label: 'Завершён', badge: 'badge-win' },
}

export const TOURNAMENT_FORMATS = {
  single_elimination: {
    label: 'Single elimination',
    hint: 'Олимпийская система: одно поражение — вылет из турнира.',
  },
}

export const FORMATS = [
  { bo: 3, finalBo: 5, label: 'Bo3, финал Bo5' },
  { bo: 3, finalBo: 3, label: 'Bo3, финал Bo3' },
  { bo: 5, finalBo: 5, label: 'Bo5, финал Bo5' },
]
