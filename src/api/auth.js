import { getSupabase } from '@/lib/supabase'

function loginError(error) {
  if (error?.message === 'Invalid login credentials') {
    return new Error('Неверный email или пароль')
  }
  if (error?.message?.includes('Email not confirmed')) {
    return new Error('Email администратора не подтверждён. Подтвердите его в Supabase.')
  }
  return new Error('Не удалось выполнить вход. Проверьте соединение и настройки Supabase.')
}

export const authApi = {
  async login(email, password) {
    const { data, error } = await getSupabase().auth.signInWithPassword({
      email: String(email).trim(),
      password,
    })

    if (error) throw loginError(error)
    return data.user
  },

  async logout() {
    const { error } = await getSupabase().auth.signOut()
    if (error) throw new Error('Не удалось выйти из панели.')
  },

  async getSession() {
    try {
      const { data } = await getSupabase().auth.getSession()
      return data.session
    } catch {
      return null
    }
  },

  // Проверка записи в public.admin_users через защищённую RPC-функцию.
  async isAdmin() {
    try {
      const { data, error } = await getSupabase().rpc('is_admin')
      if (error) return false
      return Boolean(data)
    } catch {
      return false
    }
  },
}
