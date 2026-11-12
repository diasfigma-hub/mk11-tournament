<script setup>
const year = new Date().getFullYear()
</script>

<template>
  <footer class="site-footer">
    <div class="container footer-inner">
      <div class="footer-brand">
        <span class="brand-mark">11</span>
        <div>
          <strong>MK Arena</strong>
          <p>Турниры по Mortal Kombat 11 — от заявки до гранд-финала.</p>
        </div>
      </div>
      <div class="footer-links">
        <RouterLink to="/register">Регистрация бойца</RouterLink>
        <RouterLink to="/tournaments">Турниры</RouterLink>
        <RouterLink to="/admin/login">Администратору</RouterLink>
      </div>
      <p class="footer-note">
        Фанатский проект. Mortal Kombat 11 — торговая марка NetherRealm Studios и WB Games.
        © {{ year }}
      </p>
    </div>
  </footer>
</template>

<style scoped>
.site-footer {
  margin-top: 72px;
  border-top: 1px solid var(--line);
  background: var(--bg-soft);
}

.footer-inner {
  display: flex;
  flex-wrap: wrap;
  gap: 28px;
  align-items: flex-start;
  justify-content: space-between;
  padding-block: 36px 28px;
}

.footer-brand {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  max-width: 340px;
}

.brand-mark {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border: 1px solid var(--gold);
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 15px;
  font-weight: 700;
  flex-shrink: 0;
}

.footer-brand strong {
  display: block;
  font-family: var(--font-display);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.footer-brand p {
  margin-top: 4px;
  color: var(--mute);
  font-size: 12px;
  line-height: 1.6;
}

.footer-links {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.footer-links a {
  color: var(--dim);
  font-size: 12px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  transition: color 0.18s ease;
}

.footer-links a:hover {
  color: var(--gold);
}

.footer-note {
  flex-basis: 100%;
  padding-top: 20px;
  border-top: 1px solid var(--line);
  color: var(--mute);
  font-size: 11px;
}

@media (max-width: 640px) {
  .site-footer {
    margin-top: 48px;
  }
}
</style>
