<script setup>
import ThemeToggle from './ThemeToggle.vue'
</script>

<template>
  <header class="site-header">
    <div class="container header-inner">
      <RouterLink to="/" class="brand">
        <span class="brand-mark">11</span>
        <span class="brand-text">
          <strong>MK Arena</strong>
          <small>Mortal Kombat 11</small>
        </span>
      </RouterLink>

      <nav class="nav" aria-label="Основная навигация">
        <RouterLink to="/" exact-active-class="is-active">Главная</RouterLink>
        <RouterLink to="/tournaments" active-class="is-active">Турниры</RouterLink>
        <RouterLink to="/register" active-class="is-active">Регистрация</RouterLink>
      </nav>

      <div class="header-actions">
        <ThemeToggle />
        <RouterLink to="/admin/login" class="btn btn-ghost btn-sm">Вход</RouterLink>
      </div>
    </div>
  </header>
</template>

<style scoped>
.site-header {
  position: sticky;
  top: 0;
  z-index: 40;
  border-bottom: 1px solid var(--line);
  background: color-mix(in srgb, var(--bg) 86%, transparent);
  backdrop-filter: blur(14px);
}

.header-inner {
  display: flex;
  align-items: center;
  gap: 28px;
  min-height: 68px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 11px;
  flex-shrink: 0;
}

.brand-mark {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border: 1px solid var(--gold);
  background: linear-gradient(140deg, var(--gold-soft), transparent 70%);
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.brand-text {
  display: flex;
  flex-direction: column;
  line-height: 1.15;
}

.brand-text strong {
  font-family: var(--font-display);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.brand-text small {
  color: var(--mute);
  font-size: 10px;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.nav {
  display: flex;
  align-items: center;
  gap: 4px;
  flex: 1;
}

.nav a {
  padding: 8px 12px;
  border-radius: 2px;
  color: var(--dim);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  transition: color 0.18s ease, background-color 0.18s ease;
}

.nav a:hover {
  color: var(--text);
  background: var(--panel-2);
}

.nav a.is-active {
  color: var(--gold);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
}

@media (max-width: 760px) {
  .header-inner {
    flex-wrap: wrap;
    gap: 0;
    padding-block: 10px;
  }

  .brand {
    order: 1;
  }

  .header-actions {
    order: 2;
    margin-left: auto;
  }

  .brand-text small {
    display: none;
  }

  .nav {
    order: 3;
    flex-basis: 100%;
    margin-top: 10px;
    padding-top: 6px;
    border-top: 1px solid var(--line);
    overflow-x: auto;
  }

  .nav a {
    padding: 8px 10px;
    font-size: 11px;
    letter-spacing: 0.06em;
  }
}
</style>
