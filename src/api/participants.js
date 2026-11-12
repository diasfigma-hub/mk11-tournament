import { getSupabase } from '@/lib/supabase'

const TABLE = 'participants'

function toParticipant(row) {
  if (!row) return null
  return {
    id: row.id,
    nickname: row.nickname,
    fullName: row.full_name || '',
    mainCharacter: row.main_character,
    contact: row.contact || '',
    status: row.status,
    createdAt: row.created_at,
  }
}

function toError(error, fallback) {
  let message = fallback
  if (error?.code === '23505') message = 'Боец с таким ником уже зарегистрирован.'
  else if (error?.code === '23514')
    message = 'Проверьте данные: ник, ФИО и персонаж должны соответствовать требованиям.'
  else if (error?.code === '42501') message = 'Недостаточно прав для этого действия.'

  const result = new Error(message)
  if (error?.code) result.code = error.code
  return result
}

export const participantsApi = {
  // Полный список доступен только администратору (RLS).
  async getAll() {
    const { data, error } = await getSupabase()
      .from(TABLE)
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw toError(error, 'Не удалось загрузить список бойцов.')
    return (data || []).map(toParticipant)
  },

  // Публичная статистика: RPC считает записи, не раскрывая контакты.
  async count() {
    const { data, error } = await getSupabase().rpc('participant_count')
    if (error) throw toError(error, 'Не удалось получить число участников.')
    return Number(data) || 0
  },

  async register(fighter) {
    const { error } = await getSupabase().from(TABLE).insert({
      nickname: fighter.nickname,
      full_name: fighter.fullName,
      main_character: fighter.mainCharacter,
      contact: fighter.contact || null,
    })

    if (error) throw toError(error, 'Не удалось отправить заявку. Проверьте соединение и попробуйте снова.')
    return true
  },

  async update(id, patch) {
    const row = {}

    if ('nickname' in patch) row.nickname = patch.nickname
    if ('fullName' in patch) row.full_name = patch.fullName
    if ('mainCharacter' in patch) row.main_character = patch.mainCharacter
    if ('contact' in patch) row.contact = patch.contact || null
    if ('status' in patch) row.status = patch.status

    const { data, error } = await getSupabase()
      .from(TABLE)
      .update(row)
      .eq('id', id)
      .select()
      .single()

    if (error) throw toError(error, 'Не удалось сохранить изменения.')
    return toParticipant(data)
  },

  async remove(id) {
    const { error } = await getSupabase().from(TABLE).delete().eq('id', id)
    if (error) throw toError(error, 'Не удалось удалить запись.')
  },

  subscribe(onChange) {
    const supabase = getSupabase()
    return supabase
      .channel('participants-admin')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: TABLE },
        onChange,
      )
      .subscribe()
  },

  unsubscribe(channel) {
    if (channel) getSupabase().removeChannel(channel)
  },
}
