<script setup>
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import ThemeToggle from '@/components/ThemeToggle.vue'
import { authApi } from '@/api'
import { isSupabaseConfigured } from '@/lib/supabase'

const router = useRouter()
const form = reactive({ email: '', password: '' })
const showPassword = ref(false)
const loading = ref(false)
const errorMsg = ref('')

onMounted(async () => {
  const session = await authApi.getSession()
  if (!session) return
  if (await authApi.isAdmin()) router.replace('/admin/participants')
  else await authApi.logout().catch(() => {})
})

async function handleLogin() {
  errorMsg.value = ''
  if (!form.email.trim() || !form.password) {
    errorMsg.value = 'Введите email и пароль'
    return
  }

  loading.value = true
  try {
    await authApi.login(form.email, form.password)
    if (!(await authApi.isAdmin())) {
      await authApi.logout().catch(() => {})
      errorMsg.value = 'У этого аккаунта нет прав организатора. Добавьте его в admin_users.'
      return
    }
    router.push('/admin/participants')
  } catch (error) {
    errorMsg.value = error?.message || 'Не удалось выполнить вход'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="top-actions">
      <ThemeToggle />
    </div>

    <div class="login-shell">
      <RouterLink to="/" class="brand">
        <span class="brand-mark">11</span>
        <span>
          <strong>MK Arena</strong>
          <small>Mortal Kombat 11</small>
        </span>
      </RouterLink>

      <div class="panel login-card">
        <div class="card-head">
          <span class="eyebrow">Судейская зона</span>
          <h1>Вход организатора</h1>
          <p>Доступ к лобби бойцов, сеткам и результатам матчей.</p>
        </div>

        <form class="login-form" @submit.prevent="handleLogin">
          <div class="field">
            <label class="label" for="email">Email администратора</label>
            <input
              id="email"
              v-model="form.email"
              class="input"
              type="email"
              placeholder="you@example.com"
              autocomplete="email"
            />
          </div>

          <div class="field">
            <label class="label" for="password">Пароль</label>
            <div class="password-wrap">
              <input
                id="password"
                v-model="form.password"
                class="input"
                :type="showPassword ? 'text' : 'password'"
                placeholder="••••••••"
                autocomplete="current-password"
              />
              <button
                type="button"
                class="password-toggle"
                :aria-label="showPassword ? 'Скрыть пароль' : 'Показать пароль'"
                @click="showPassword = !showPassword"
              >
                {{ showPassword ? 'Скрыть' : 'Показать' }}
              </button>
            </div>
          </div>

          <div v-if="errorMsg" class="alert alert-error">{{ errorMsg }}</div>

          <button type="submit" class="btn btn-primary btn-block" :disabled="loading">
            <span v-if="loading" class="spinner" />
            <span v-else>Войти в панель</span>
          </button>
        </form>

        <div v-if="!isSupabaseConfigured" class="alert alert-error">
          Supabase не подключён. Добавьте VITE_SUPABASE_URL и VITE_SUPABASE_ANON_KEY
          в переменные окружения (локально — в .env, на Vercel — в Project Settings).
        </div>

        <p class="security-note">
          Вход через Supabase Auth. Учётная запись администратора создаётся в панели
          Supabase; самостоятельная регистрация посетителей отключена.
        </p>

        <RouterLink to="/" class="back-home">← Вернуться на сайт</RouterLink>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  display: grid;
  place-items: center;
  min-height: 100vh;
  padding: 24px;
}

.top-actions {
  position: fixed;
  top: 20px;
  right: 20px;
  z-index: 10;
}

.login-shell {
  width: 100%;
  max-width: 420px;
}

.brand {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 11px;
  margin-bottom: 22px;
}

.brand-mark {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border: 1px solid var(--gold);
  background: var(--gold-soft);
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
}

.brand > span:last-child {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
}

.brand strong {
  font-family: var(--font-display);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.brand small {
  color: var(--mute);
  font-size: 10px;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.login-card {
  padding: 28px;
}

.card-head {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-bottom: 22px;
  border-bottom: 1px solid var(--line);
}

.card-head h1 {
  font-size: 1.7rem;
}

.card-head p {
  color: var(--dim);
  font-size: 13px;
  line-height: 1.6;
}

.login-form {
  padding-top: 22px;
}

.password-wrap {
  position: relative;
}

.password-wrap .input {
  padding-right: 86px;
}

.password-toggle {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  padding: 6px 8px;
  border: 0;
  background: transparent;
  color: var(--mute);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  cursor: pointer;
}

.password-toggle:hover {
  color: var(--gold);
}

.login-form .alert {
  margin-top: 18px;
}

.login-form .btn {
  margin-top: 22px;
}

.security-note {
  margin-top: 18px;
  padding-top: 14px;
  border-top: 1px solid var(--line);
  color: var(--mute);
  font-size: 11px;
  line-height: 1.6;
}

.back-home {
  display: block;
  margin-top: 16px;
  color: var(--mute);
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  text-align: center;
  transition: color 0.18s ease;
}

.back-home:hover {
  color: var(--gold);
}
</style>
