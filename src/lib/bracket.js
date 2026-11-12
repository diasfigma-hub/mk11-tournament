/**
 * Логика одиночной сетки (single elimination): жеребьёвка, баи,
 * продвижение победителей, отмена результатов и итоговые места.
 * Все функции возвращают новые объекты, исходная сетка не мутируется.
 */

export function nextPow2(n) {
  let size = 2
  while (size < Math.max(2, n)) size *= 2
  return size
}

// Классическая расстановка посева: 1-8, 4-5, 2-7, 3-6 и т.д.
function seedOrder(size) {
  const depth = Math.log2(size)
  let order = [1, 2]
  for (let round = 1; round < depth; round++) {
    const sum = 2 ** (round + 1) + 1
    const next = []
    for (const seed of order) next.push(seed, sum - seed)
    order = next
  }
  return order
}

export function emptyMatch() {
  return { p1: null, p2: null, score1: null, score2: null, winnerId: null, bye: false }
}

export function roundLabel(rounds, index) {
  const remaining = rounds.length - index
  if (remaining === 1) return 'Гранд-финал'
  if (remaining === 2) return 'Полуфинал'
  if (remaining === 3) return 'Четвертьфинал'
  return `1/${2 ** (remaining - 1)} финала`
}

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

function propagate(rounds, roundIndex, matchIndex, winner) {
  const next = rounds[roundIndex + 1]
  if (!next || !winner) return
  const target = next.matches[Math.floor(matchIndex / 2)]
  if (!target) return
  if (matchIndex % 2 === 0) target.p1 = winner
  else target.p2 = winner
}

function clearDownstream(rounds, roundIndex, matchIndex) {
  const next = rounds[roundIndex + 1]
  if (!next) return
  const targetIndex = Math.floor(matchIndex / 2)
  const target = next.matches[targetIndex]
  if (!target) return
  if (!target.winnerId && target.score1 == null) return
  target.winnerId = null
  target.score1 = null
  target.score2 = null
  target.bye = false
  clearDownstream(rounds, roundIndex + 1, targetIndex)
}

// Пустые слоты первого раунда — это баи: боец проходит дальше без игры.
function resolveFirstRoundByes(rounds) {
  const first = rounds[0]
  if (!first) return
  first.matches.forEach((match, index) => {
    const only = match.p1 || match.p2
    const hasBoth = Boolean(match.p1 && match.p2)
    if (only && !hasBoth) {
      match.winnerId = only.id
      match.bye = true
      propagate(rounds, 0, index, only)
    }
  })
}

export function createRounds(players, { bo = 3, finalBo = 5 } = {}) {
  const list = (players || []).filter(Boolean)
  const size = nextPow2(list.length)
  const order = seedOrder(size)
  const slots = order.map((seed) => list[seed - 1] || null)

  const rounds = []
  let matchCount = size / 2
  while (matchCount >= 1) {
    rounds.push({ matches: Array.from({ length: matchCount }, () => emptyMatch()) })
    matchCount /= 2
  }

  slots.forEach((player, slot) => {
    const match = rounds[0].matches[Math.floor(slot / 2)]
    if (!match) return
    if (slot % 2 === 0) match.p1 = player
    else match.p2 = player
  })

  rounds.forEach((round, index) => {
    round.matches.forEach((match) => {
      match.bo = index === rounds.length - 1 ? finalBo : bo
    })
  })

  resolveFirstRoundByes(rounds)
  return rounds
}

export function applyScore(rounds, roundIndex, matchIndex, score1, score2) {
  const copy = clone(rounds)
  const match = copy[roundIndex]?.matches?.[matchIndex]
  if (!match?.p1 || !match?.p2) return copy

  const first = Number(score1)
  const second = Number(score2)
  const winner = first > second ? match.p1 : match.p2

  match.score1 = first
  match.score2 = second
  match.winnerId = winner.id
  match.bye = false

  // Новый результат отменяет всё, что было сыграно дальше по сетке.
  clearDownstream(copy, roundIndex, matchIndex)
  propagate(copy, roundIndex, matchIndex, winner)
  return copy
}

export function resetResult(rounds, roundIndex, matchIndex) {
  const copy = clone(rounds)
  const match = copy[roundIndex]?.matches?.[matchIndex]
  if (!match) return copy

  match.winnerId = null
  match.score1 = null
  match.score2 = null
  match.bye = false

  const next = copy[roundIndex + 1]
  if (next) {
    const target = next.matches[Math.floor(matchIndex / 2)]
    if (target) {
      if (matchIndex % 2 === 0) target.p1 = null
      else target.p2 = null
      target.winnerId = null
      target.score1 = null
      target.score2 = null
      target.bye = false
      clearDownstream(copy, roundIndex + 1, Math.floor(matchIndex / 2))
    }
  }

  return copy
}

export function championOf(rounds) {
  if (!rounds?.length) return null
  const final = rounds[rounds.length - 1].matches[0]
  if (!final?.winnerId) return null
  return [final.p1, final.p2].find((player) => player && player.id === final.winnerId) || null
}

export function isPlayable(match) {
  return Boolean(match?.p1 && match?.p2 && !match.winnerId)
}

export function computeStandings(rounds, thirdPlace = null) {
  if (!rounds?.length) return []

  const total = rounds.length
  const eliminated = new Map()
  let champion = null

  rounds.forEach((round, roundIndex) => {
    round.matches.forEach((match) => {
      if (!match.winnerId) return
      const winner = [match.p1, match.p2].find((player) => player && player.id === match.winnerId)
      const loser = [match.p1, match.p2].find((player) => player && player.id !== match.winnerId)
      if (loser) eliminated.set(loser.id, { player: loser, round: roundIndex })
      if (roundIndex === total - 1 && winner) champion = winner
    })
  })

  const rows = []
  if (champion) rows.push({ place: '1', player: champion })

  const groups = new Map()
  eliminated.forEach(({ player, round }) => {
    const level = total - 1 - round
    const from = 2 ** level + 1
    const to = 2 ** (level + 1)
    const place = from === to ? String(from) : `${from}–${to}`
    if (!groups.has(place)) groups.set(place, { place, from, players: [] })
    groups.get(place).players.push(player)
  })

  const sorted = [...groups.values()].sort((a, b) => a.from - b.from)
  sorted.forEach((group) => {
    group.players.forEach((player) => rows.push({ place: group.place, player }))
  })

  if (thirdPlace?.winnerId) {
    const thirdLoser = [thirdPlace.p1, thirdPlace.p2].find(
      (player) => player && player.id !== thirdPlace.winnerId,
    )
    rows.forEach((row) => {
      if (row.player.id === thirdPlace.winnerId) row.place = '3'
      else if (thirdLoser && row.player.id === thirdLoser.id) row.place = '4'
    })
    rows.sort((a, b) => parseInt(a.place, 10) - parseInt(b.place, 10))
  }

  return rows
}

export function maxScoreFor(bo) {
  return Math.ceil((bo || 3) / 2)
}

export function scoreOptions(bo) {
  const win = maxScoreFor(bo)
  const wins = []
  const losses = []
  for (let lose = 0; lose < win; lose++) {
    wins.push([win, lose])
    losses.push([lose, win])
  }
  return [...wins, ...losses]
}

export function countMatches(rounds) {
  if (!rounds?.length) return { total: 0, played: 0 }
  let total = 0
  let played = 0
  rounds.forEach((round) => {
    round.matches.forEach((match) => {
      if (!match.p1 && !match.p2) return
      total += 1
      if (match.winnerId) played += 1
    })
  })
  return { total, played }
}

export function buildThirdPlace(rounds, current = null, bo = 3) {
  if (!rounds || rounds.length < 2) return null

  const semis = rounds[rounds.length - 2]
  if (!semis?.matches?.length) return null
  if (semis.matches.some((match) => match.bye)) return null

  const losers = []
  semis.matches.forEach((match) => {
    if (!match.winnerId) return
    const loser = [match.p1, match.p2].find((player) => player && player.id !== match.winnerId)
    if (loser) losers.push(loser)
  })

  const p1 = losers[0] || null
  const p2 = losers[1] || null
  const same = Boolean(current) && current.p1?.id === p1?.id && current.p2?.id === p2?.id
  const matchBo = current?.bo || bo

  if (same) return { ...current, p1, p2, bo: matchBo }
  return { p1, p2, score1: null, score2: null, winnerId: null, bo: matchBo }
}

export function applyThirdPlaceScore(thirdPlace, score1, score2) {
  if (!thirdPlace?.p1 || !thirdPlace?.p2) return thirdPlace
  const copy = clone(thirdPlace)
  copy.score1 = Number(score1)
  copy.score2 = Number(score2)
  copy.winnerId = copy.score1 > copy.score2 ? copy.p1.id : copy.p2.id
  return copy
}

export function resetThirdPlace(thirdPlace) {
  if (!thirdPlace) return thirdPlace
  const copy = clone(thirdPlace)
  copy.score1 = null
  copy.score2 = null
  copy.winnerId = null
  return copy
}
