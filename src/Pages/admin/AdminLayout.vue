<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import ThemeToggle from '@/components/ThemeToggle.vue'
import { authApi } from '@/api'
import { initials } from '@/lib/format'

const router = useRouter()
const adminEmail = ref('Администратор')

onMounted(async () => {
  const session = await authApi.getSession()
  adminEmail.value = session?.user?.email || 'Администратор'
})

const adminLogin = computed(() => adminEmail.value)

async function logout() {
  try {
    await authApi.logout()
  } catch {
    // даже при ошибке сети возвращаем на экран входа
  } finally {
    router.push('/admin/login')
  }
}
</script>

<template>
  <div class="admin-shell">
    <aside class="sidebar">
      <div class="sidebar-top">
        <RouterLink to="/admin/participants" class="brand">
          <span class="brand-mark">11</span>
          <span class="brand-copy">
            <strong>MK Arena</strong>
            <small>Админ-панель</small>
          </span>
        </RouterLink>
        <ThemeToggle />
      </div>

      <nav class="nav" aria-label="Админ-навигация">
        <RouterLink to="/admin/participants" class="nav-item">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M17 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
            <circle cx="9.5" cy="7" r="4" />
            <path d="M21 21v-2a4 4 0 0 0-3-3.87M16.5 3.2a4 4 0 0 1 0 7.6" />
          </svg>
          Бойцы
        </RouterLink>

        <RouterLink to="/admin/tournaments" class="nav-item">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M8 3h8l-1 6a3 3 0 0 1-6 0z" />
            <path d="M8 5H4v2a4 4 0 0 0 4 4M16 5h4v2a4 4 0 0 1-4 4M12 15v4M8 21h8" />
          </svg>
          Турниры
        </RouterLink>
      </nav>

      <div class="sidebar-foot">
        <div class="admin-info">
          <span class="avatar">{{ initials(adminLogin) }}</span>
          <span class="admin-copy">
            <strong>{{ adminLogin }}</strong>
            <small>Администратор</small>
          </span>
        </div>

        <div class="foot-actions">
          <RouterLink to="/" class="site-link">На сайт →</RouterLink>
          <button type="button" class="logout" title="Выйти" @click="logout">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
            Выйти
          </button>
        </div>
      </div>
    </aside>

    <div class="admin-main">
      <RouterView />
    </div>
  </div>
</template>

<style scoped>
.admin-shell {
  display: flex;
  min-height: 100vh;
}

.sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  width: 232px;
  height: 100vh;
  flex-shrink: 0;
  border-right: 1px solid var(--line);
  background: var(--bg-soft);
}

.sidebar-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 20px 16px;
  border-bottom: 1px solid var(--line);
}

.brand {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
}

.brand-mark {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  flex-shrink: 0;
  border: 1px solid var(--gold);
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 14px;
  font-weight: 700;
}

.brand-copy {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
  min-width: 0;
}

.brand-copy strong {
  font-family: var(--font-display);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  white-space: nowrap;
}

.brand-copy small {
  color: var(--mute);
  font-size: 9px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

.nav {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 3px;
  padding: 14px 10px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 11px;
  border-left: 2px solid transparent;
  border-radius: 2px;
  color: var(--dim);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  transition: color 0.18s ease, background-color 0.18s ease, border-color 0.18s ease;
}

.nav-item:hover {
  background: var(--panel-2);
  color: var(--text);
}

.nav-item.router-link-active {
  border-left-color: var(--gold);
  background: var(--panel);
  color: var(--gold);
}

.sidebar-foot {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
  border-top: 1px solid var(--line);
}

.admin-info {
  display: flex;
  align-items: center;
  gap: 9px;
  min-width: 0;
}

.avatar {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  flex-shrink: 0;
  border: 1px solid var(--line-2);
  border-radius: 50%;
  color: var(--gold);
  font-size: 11px;
  font-weight: 600;
}

.admin-copy {
  display: flex;
  flex-direction: column;
  line-height: 1.25;
  min-width: 0;
}

.admin-copy strong {
  overflow: hidden;
  font-size: 12.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-copy small {
  color: var(--mute);
  font-size: 10px;
}

.foot-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.site-link {
  color: var(--mute);
  font-size: 10px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  transition: color 0.18s ease;
}

.site-link:hover {
  color: var(--gold);
}

.logout {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px;
  border: 0;
  background: transparent;
  color: var(--mute);
  font-size: 10px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  cursor: pointer;
  transition: color 0.18s ease;
}

.logout:hover {
  color: var(--blood-2);
}

.admin-main {
  flex: 1;
  min-width: 0;
  padding: clamp(20px, 3vw, 34px);
}

@media (max-width: 900px) {
  .admin-shell {
    flex-direction: column;
  }

  .sidebar {
    position: static;
    width: auto;
    height: auto;
    border-right: 0;
    border-bottom: 1px solid var(--line);
  }

  .sidebar-top {
    padding: 12px 16px;
  }

  .nav {
    flex-direction: row;
    padding: 8px 12px;
  }

  .nav-item {
    flex: 1;
    justify-content: center;
    border-left: 0;
    border-bottom: 2px solid transparent;
  }

  .nav-item.router-link-active {
    border-bottom-color: var(--gold);
  }

  .sidebar-foot {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    padding: 10px 16px;
  }

  .foot-actions {
    gap: 14px;
  }
}
</style>
