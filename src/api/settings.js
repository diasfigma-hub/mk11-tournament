import { getSupabase } from '@/lib/supabase'

const TABLE = 'settings'
const PUBLIC_VIEW = 'public_settings'

function toError(error, fallback) {
  const result = new Error(fallback)
  if (error?.code) result.code = error.code
  return result
}

export const settingsApi = {
  async getRegistrationClosed() {
    const { data, error } = await getSupabase()
      .from(PUBLIC_VIEW)
      .select('registration_closed')
      .maybeSingle()

    if (error) throw toError(error, 'Не удалось проверить статус регистрации.')
    return Boolean(data?.registration_closed)
  },

  async setRegistrationClosed(closed) {
    const { error } = await getSupabase()
      .from(TABLE)
      .update({ registration_closed: closed, updated_at: new Date().toISOString() })
      .eq('id', 1)

    if (error) throw toError(error, 'Не удалось изменить статус регистрации.')
  },
}
