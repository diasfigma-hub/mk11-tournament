<script setup>
import { computed, onMounted, ref } from 'vue'
import SiteHeader from '@/components/SiteHeader.vue'
import SiteFooter from '@/components/SiteFooter.vue'
import TournamentCard from '@/components/TournamentCard.vue'
import { participantsApi, tournamentsApi } from '@/api'
import { countMatches } from '@/lib/bracket'
import { ROSTER } from '@/lib/constants'

const fightersCount = ref(0)
const tournaments = ref([])
const loading = ref(true)
const statsError = ref('')

onMounted(async () => {
  const [players, events] = await Promise.allSettled([
    participantsApi.count(),
    tournamentsApi.getPublicAll(),
  ])
  if (players.status === 'fulfilled') fightersCount.value = players.value
  if (events.status === 'fulfilled') tournaments.value = events.value
  const failure =
    players.status === 'rejected'
      ? players.reason
      : events.status === 'rejected'
        ? events.reason
        : null
  if (failure) {
    statsError.value =
      failure?.message || 'Часть данных не загрузилась — статистика может быть неполной.'
  }
  loading.value = false
})

const matchesPlayed = computed(() =>
  tournaments.value.reduce((sum, tournament) => sum + countMatches(tournament.rounds).played, 0),
)

const upcoming = computed(() =>
  tournaments.value.filter((tournament) => tournament.status !== 'finished').slice(0, 3),
)

const stats = computed(() => [
  { value: loading.value ? '—' : fightersCount.value, label: 'бойцов в лобби' },
  { value: loading.value ? '—' : tournaments.value.length, label: 'турниров создано' },
  { value: loading.value ? '—' : matchesPlayed.value, label: 'матчей сыграно' },
  { value: ROSTER.length, label: 'персонажей в ростере' },
])

const steps = [
  {
    number: '01',
    title: 'Регистрация',
    text: 'Боец указывает ник, ФИО, основного персонажа и контакт. Заявка сразу попадает в общее лобби.',
  },
  {
    number: '02',
    title: 'Жеребьёвка',
    text: 'Администратор собирает состав турнира — платформа сама строит сетку на 4, 8, 16 или 32 бойца.',
  },
  {
    number: '03',
    title: 'Матчи',
    text: 'Судья вносит счёт Bo3 или Bo5. Победитель уходит в следующий раунд, таблица мест пересчитывается.',
  },
]

const rules = [
  'Олимпийская система: одно поражение — вылет из турнира.',
  'Матчи до двух побед (Bo3), гранд-финал — до трёх (Bo5).',
  'Только турнирные вариации персонажей, гостевые запрещены.',
  'Арена: проигравший боец выбирает Stage Select.',
  'Неявка более 10 минут — техническое поражение.',
  'Читы, модификации и намеренные паузы — дисквалификация.',
  'Спорные ситуации решает судья турнира по записи матча.',
]
</script>

<template>
  <div class="page">
    <SiteHeader />

    <main>
      <section class="hero">
        <div class="container hero-inner">
          <div class="hero-copy">
            <span class="eyebrow">Турнирная платформа · Mortal Kombat 11</span>
            <h1>
              Турнирная<br />
              <span class="accent">арена</span>
              <span class="outline">11</span>
            </h1>
            <p class="hero-lead">
              Собираем бойцов в одном лобби, проводим жеребьёвку и ведём сетку от первой пары
              до гранд-финала. Счёт внесён — победитель уже в следующем раунде.
            </p>

            <div class="hero-actions">
              <RouterLink to="/register" class="btn btn-primary">Стать участником</RouterLink>
              <RouterLink to="/tournaments" class="btn btn-ghost">Смотреть турниры</RouterLink>
            </div>

            <ul class="hero-facts">
              <li><strong>Bo3</strong> основной матч</li>
              <li><strong>Bo5</strong> гранд-финал</li>
              <li><strong>Single Elimination</strong> формат</li>
            </ul>
          </div>

          <aside class="rules-card">
            <div class="rules-top">
              <span class="rules-mark">11</span>
              <div class="rules-title">
                <strong>Mortal Kombat 11</strong>
                <span>Tournament platform</span>
              </div>
            </div>

            <dl class="rules-list">
              <div>
                <dt>Формат</dt>
                <dd>Single elimination</dd>
              </div>
              <div>
                <dt>Матчи</dt>
                <dd>Bo3 · финал Bo5</dd>
              </div>
              <div>
                <dt>Платформы</dt>
                <dd>PS5 / PS4 · Xbox · PC · Switch</dd>
              </div>
              <div>
                <dt>Вариации</dt>
                <dd>Турнирные</dd>
              </div>
            </dl>

            <p class="rules-note">
              Сетка обновляется автоматически после каждого результата — без ручных таблиц.
            </p>
          </aside>
        </div>
      </section>

      <section class="container stats-ribbon">
        <div v-for="stat in stats" :key="stat.label" class="stat">
          <span class="stat-value">{{ stat.value }}</span>
          <span class="stat-label">{{ stat.label }}</span>
        </div>
      </section>

      <p v-if="statsError" class="container stats-error">{{ statsError }}</p>

      <section class="container section">
        <div class="section-head">
          <div>
            <span class="eyebrow">Расписание</span>
            <h2>Ближайшие турниры</h2>
          </div>
          <RouterLink to="/tournaments" class="section-link">Все турниры →</RouterLink>
        </div>

        <div v-if="upcoming.length" class="tournament-grid">
          <TournamentCard
            v-for="tournament in upcoming"
            :key="tournament.id"
            :tournament="tournament"
          />
        </div>

        <div v-else class="panel empty-state">
          <strong>Турниры пока не объявлены</strong>
          <p>Зарегистрируйся в лобби — администратор соберёт состав и запустит сетку.</p>
          <RouterLink to="/register" class="btn btn-primary btn-sm">Подать заявку</RouterLink>
        </div>
      </section>

      <section class="container section">
        <div class="section-head">
          <div>
            <span class="eyebrow">Процесс</span>
            <h2>Как проходит турнир</h2>
          </div>
        </div>

        <div class="steps">
          <article v-for="step in steps" :key="step.number" class="step">
            <span class="step-number">{{ step.number }}</span>
            <h3>{{ step.title }}</h3>
            <p>{{ step.text }}</p>
          </article>
        </div>
      </section>

      <section class="container section">
        <div class="rules-grid">
          <div class="rules-intro">
            <span class="eyebrow">Регламент</span>
            <h2>Правила арены</h2>
            <p>
              Единый регламент для всех турниров платформы. Организатор может добавить
              уточнения в описании конкретного ивента.
            </p>
            <RouterLink to="/register" class="btn btn-ghost btn-sm">Принять правила</RouterLink>
          </div>

          <ul class="rules-list-text">
            <li v-for="rule in rules" :key="rule">{{ rule }}</li>
          </ul>
        </div>
      </section>
    </main>

    <SiteFooter />
  </div>
</template>

<style scoped>
.page {
  display: flex;
  min-height: 100vh;
  flex-direction: column;
}

main {
  flex: 1;
}

/* ── Hero ── */

.hero {
  position: relative;
  padding: clamp(48px, 8vw, 96px) 0 clamp(40px, 6vw, 72px);
  border-bottom: 1px solid var(--line);
  overflow: hidden;
}

.hero::after {
  content: '11';
  position: absolute;
  right: -2%;
  bottom: -22%;
  color: var(--panel-2);
  font-family: var(--font-display);
  font-size: clamp(180px, 30vw, 420px);
  font-weight: 700;
  line-height: 0.8;
  pointer-events: none;
  user-select: none;
}

.hero-inner {
  position: relative;
  z-index: 1;
  display: grid;
  gap: clamp(28px, 5vw, 64px);
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.85fr);
  align-items: center;
}

.hero-copy {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 18px;
}

h1 {
  font-size: clamp(2.9rem, 6.4vw, 5.2rem);
  font-weight: 600;
  line-height: 0.92;
  letter-spacing: 0.005em;
}

.accent {
  color: var(--gold);
}

.outline {
  margin-left: 10px;
  color: transparent;
  -webkit-text-stroke: 1.5px var(--gold);
}

.hero-lead {
  max-width: 520px;
  color: var(--dim);
  font-size: 15px;
  line-height: 1.75;
}

.hero-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-top: 6px;
}

.hero-facts {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 26px;
  margin: 10px 0 0;
  padding: 0;
  list-style: none;
  color: var(--mute);
  font-size: 12px;
}

.hero-facts strong {
  margin-right: 5px;
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 13px;
  letter-spacing: 0.06em;
}

/* ── Rules card ── */

.rules-card {
  border: 1px solid var(--line-2);
  background: linear-gradient(160deg, var(--panel-2), var(--panel) 55%);
  box-shadow: var(--shadow);
}

.rules-top {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 22px;
  border-bottom: 1px solid var(--line);
}

.rules-mark {
  display: grid;
  place-items: center;
  width: 52px;
  height: 52px;
  border: 1px solid var(--gold);
  background: var(--gold-soft);
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 24px;
  font-weight: 700;
  flex-shrink: 0;
}

.rules-title {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
}

.rules-title strong {
  font-family: var(--font-display);
  font-size: 17px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.rules-title span {
  color: var(--mute);
  font-size: 10px;
  letter-spacing: 0.2em;
  text-transform: uppercase;
}

.rules-list {
  margin: 0;
  padding: 8px 22px;
}

.rules-list > div {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 16px;
  padding: 12px 0;
  border-bottom: 1px dashed var(--line);
}

.rules-list > div:last-child {
  border-bottom: 0;
}

.rules-list dt {
  color: var(--mute);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  white-space: nowrap;
}

.rules-list dd {
  margin: 0;
  color: var(--text);
  font-size: 13px;
  text-align: right;
}

.rules-note {
  padding: 16px 22px 20px;
  border-top: 1px solid var(--line);
  color: var(--mute);
  font-size: 12px;
  line-height: 1.6;
}

/* ── Stats ── */

.stats-ribbon {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  border: 1px solid var(--line);
  border-top: 0;
  background: var(--panel);
}

.stat {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 22px 24px;
  border-right: 1px solid var(--line);
}

.stat:last-child {
  border-right: 0;
}

.stat-value {
  font-family: var(--font-display);
  font-size: clamp(1.7rem, 3vw, 2.3rem);
  font-weight: 600;
  line-height: 1;
}

.stat-label {
  color: var(--mute);
  font-size: 11px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.stats-error {
  margin-top: 10px;
  color: var(--mute);
  font-size: 12px;
}

/* ── Sections ── */

.section {
  margin-top: clamp(48px, 7vw, 84px);
}

.section-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  margin-bottom: 22px;
}

.section-head h2 {
  margin-top: 8px;
  font-size: clamp(1.5rem, 3vw, 2rem);
}

.section-link {
  color: var(--gold);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  white-space: nowrap;
}

.section-link:hover {
  text-decoration: underline;
}

.tournament-grid {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

/* ── Steps ── */

.steps {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.step {
  padding: 24px;
  border: 1px solid var(--line);
  background: var(--panel);
}

.step-number {
  display: block;
  margin-bottom: 14px;
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.18em;
}

.step h3 {
  margin-bottom: 8px;
  font-size: 18px;
  letter-spacing: 0.04em;
}

.step p {
  color: var(--dim);
  font-size: 13px;
  line-height: 1.7;
}

/* ── Rules section ── */

.rules-grid {
  display: grid;
  gap: clamp(24px, 4vw, 56px);
  grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr);
  padding: clamp(24px, 4vw, 40px);
  border: 1px solid var(--line);
  background: var(--panel);
}

.rules-intro {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 14px;
}

.rules-intro h2 {
  font-size: clamp(1.5rem, 3vw, 2rem);
}

.rules-intro p {
  color: var(--dim);
  font-size: 13px;
  line-height: 1.75;
}

.rules-list-text {
  display: grid;
  gap: 10px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.rules-list-text li {
  position: relative;
  padding-left: 20px;
  color: var(--dim);
  font-size: 13px;
  line-height: 1.6;
}

.rules-list-text li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.65em;
  width: 7px;
  height: 7px;
  border: 1px solid var(--gold);
  transform: rotate(45deg);
}

@media (max-width: 960px) {
  .hero-inner {
    grid-template-columns: minmax(0, 1fr);
  }

  .rules-card {
    max-width: 520px;
  }

  .tournament-grid,
  .steps {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .rules-grid {
    grid-template-columns: minmax(0, 1fr);
  }
}

@media (max-width: 640px) {
  .stats-ribbon {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .stat {
    border-bottom: 1px solid var(--line);
  }

  .stat:nth-child(2n) {
    border-right: 0;
  }

  .stat:nth-last-child(-n + 2) {
    border-bottom: 0;
  }

  .tournament-grid,
  .steps {
    grid-template-columns: minmax(0, 1fr);
  }

  .section-head {
    align-items: flex-start;
    flex-direction: column;
    gap: 10px;
  }
}
</style>
