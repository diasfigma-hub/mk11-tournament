import { getSupabase } from '@/lib/supabase'

const TABLE = 'tournaments'
const PUBLIC_VIEW = 'public_tournaments'

function toTournament(row) {
  if (!row) return null
  return {
    id: row.id,
    title: row.title,
    description: row.description || '',
    date: row.date,
    registrationEnd: row.registration_end,
    playerLimit: row.player_limit,
    platform: row.platform,
    bo: row.bo,
    finalBo: row.final_bo,
    format: row.format,
    status: row.status,
    players: row.players || [],
    rounds: row.rounds || [],
    thirdPlace: row.third_place,
    champion: row.champion,
    registrationClosed: row.registration_closed,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

const FIELD_MAP = {
  registrationEnd: 'registration_end',
  playerLimit: 'player_limit',
  finalBo: 'final_bo',
  thirdPlace: 'third_place',
  registrationClosed: 'registration_closed',
  createdAt: 'created_at',
  updatedAt: 'updated_at',
}

function toRow(patch) {
  const row = {}
  Object.entries(patch).forEach(([key, value]) => {
    if (value === undefined) return
    row[FIELD_MAP[key] || key] = value
  })
  return row
}

function toError(error, fallback) {
  const result = new Error(fallback)
  if (error?.code) result.code = error.code
  return result
}

function sortByDate(list) {
  return [...list].sort((a, b) => {
    const left = new Date(a.date || a.createdAt || 0).getTime()
    const right = new Date(b.date || b.createdAt || 0).getTime()
    return right - left
  })
}

export const tournamentsApi = {
  async getAll() {
    const { data, error } = await getSupabase().from(TABLE).select('*')
    if (error) throw toError(error, 'Не удалось загрузить список турниров.')
    return sortByDate((data || []).map(toTournament))
  },

  async getById(id) {
    const { data, error } = await getSupabase().from(TABLE).select('*').eq('id', id).maybeSingle()
    if (error) throw toError(error, 'Не удалось загрузить турнир.')
    return toTournament(data)
  },

  // Публичные страницы читают безопасную проекцию без ФИО и служебных полей.
  async getPublicAll() {
    const { data, error } = await getSupabase().from(PUBLIC_VIEW).select('*')
    if (error) throw toError(error, 'Не удалось загрузить список турниров.')
    return sortByDate((data || []).map(toTournament))
  },

  async getPublicById(id) {
    const { data, error } = await getSupabase()
      .from(PUBLIC_VIEW)
      .select('*')
      .eq('id', id)
      .maybeSingle()
    if (error) throw toError(error, 'Не удалось загрузить турнир.')
    return toTournament(data)
  },

  async create(payload) {
    const body = {
      ...toRow(payload),
      status: payload.status || 'draft',
      rounds: payload.rounds || [],
      players: payload.players || [],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }

    const { data, error } = await getSupabase().from(TABLE).insert(body).select().single()
    if (error) throw toError(error, 'Не удалось создать турнир.')
    return toTournament(data)
  },

  async update(id, patch) {
    const body = {
      ...toRow(patch),
      updated_at: new Date().toISOString(),
    }

    const { data, error } = await getSupabase()
      .from(TABLE)
      .update(body)
      .eq('id', id)
      .select()
      .single()

    if (error) throw toError(error, 'Не удалось сохранить турнир.')
    return toTournament(data)
  },

  async remove(id) {
    const { error } = await getSupabase().from(TABLE).delete().eq('id', id)
    if (error) throw toError(error, 'Не удалось удалить турнир.')
  },
}
