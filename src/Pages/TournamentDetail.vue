<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import SiteHeader from '@/components/SiteHeader.vue'
import SiteFooter from '@/components/SiteFooter.vue'
import BracketView from '@/components/BracketView.vue'
import { settingsApi, tournamentsApi } from '@/api'
import { buildThirdPlace, championOf, computeStandings, countMatches } from '@/lib/bracket'
import { TOURNAMENT_FORMATS, TOURNAMENT_STATUSES } from '@/lib/constants'
import { formatDate, platformLabel, pluralizeFighters } from '@/lib/format'

const route = useRoute()
const tournament = ref(null)
const loading = ref(true)
const notFound = ref(false)
const registrationClosed = ref(false)

onMounted(async () => {
  const [event, closed] = await Promise.allSettled([
    tournamentsApi.getById(route.params.id),
    settingsApi.getRegistrationClosed(),
  ])

  if (event.status === 'fulfilled') {
    tournament.value = event.value
    notFound.value = !event.value
  } else {
    notFound.value = true
  }
  if (closed.status === 'fulfilled') registrationClosed.value = closed.value
  loading.value = false
})

const rounds = computed(() => tournament.value?.rounds || [])
const players = computed(() => tournament.value?.players || [])
const champion = computed(() => tournament.value?.champion || championOf(rounds.value))
const thirdPlace = computed(
  () =>
    tournament.value?.thirdPlace ||
    buildThirdPlace(rounds.value, null, tournament.value?.bo || 3),
)
const standings = computed(() => computeStandings(rounds.value, thirdPlace.value))
const matches = computed(() => countMatches(rounds.value))

const status = computed(
  () => TOURNAMENT_STATUSES[tournament.value?.status] || TOURNAMENT_STATUSES.draft,
)

const platform = computed(() =>
  tournament.value?.platform === 'all' || !tournament.value?.platform
    ? 'Все платформы'
    : platformLabel(tournament.value.platform),
)

const format = computed(
  () => `Bo${tournament.value?.bo || 3} · гранд-финал Bo${tournament.value?.finalBo || 5}`,
)

const formatLabel = computed(
  () =>
    TOURNAMENT_FORMATS[tournament.value?.format]?.label ||
    TOURNAMENT_FORMATS.single_elimination.label,
)

const playersLabel = computed(() => pluralizeFighters(players.value.length))

const registration = computed(() => {
  const event = tournament.value
  const limit = Number(event?.playerLimit) || 0
  const count = players.value.length
  const deadline = event?.registrationEnd ? new Date(event.registrationEnd) : null
  const deadlinePassed = deadline ? Date.now() > deadline.getTime() : false
  const full = limit > 0 && count >= limit
  const closed = registrationClosed.value || event?.status === 'finished' || deadlinePassed || full

  return {
    deadline,
    limit,
    full,
    deadlinePassed,
    open: !closed,
    label: closed ? 'Регистрация закрыта' : 'Регистрация открыта',
  }
})
</script>

<template>
  <div class="page">
    <SiteHeader />

    <main class="container">
      <div v-if="loading" class="state">
        <span class="spinner spinner-lg" />
        <p class="text-mute">Открываем сетку…</p>
      </div>

      <div v-else-if="notFound || !tournament" class="panel empty-state">
        <strong>Турнир не найден</strong>
        <p>Возможно, организатор удалил его или ссылка устарела.</p>
        <RouterLink to="/tournaments" class="btn btn-ghost btn-sm">Все турниры</RouterLink>
      </div>

      <template v-else>
        <header class="tournament-head">
          <RouterLink to="/tournaments" class="back-link">← Все турниры</RouterLink>

          <div class="head-row">
            <div class="head-copy">
              <div class="head-badges">
                <span class="badge" :class="status.badge">{{ status.label }}</span>
                <span class="badge">{{ formatLabel }}</span>
              </div>
              <h1>{{ tournament.title }}</h1>
              <p v-if="tournament.description" class="description">{{ tournament.description }}</p>
              <p class="reg-line" :class="{ 'is-closed': !registration.open }">
                <span class="reg-dot" />
                {{ registration.label }}
                <template v-if="registration.limit">
                  · {{ players.length }} / {{ registration.limit }}
                </template>
                <template v-if="registration.full"> · мест нет</template>
                <template v-else-if="registration.deadlinePassed"> · срок истёк</template>
              </p>
            </div>

            <div class="head-meta">
              <div>
                <span>Дата</span>
                <strong>{{ formatDate(tournament.date) }}</strong>
              </div>
              <div>
                <span>Платформа</span>
                <strong>{{ platform }}</strong>
              </div>
              <div>
                <span>Формат</span>
                <strong>{{ format }}</strong>
              </div>
              <div>
                <span>Сетка</span>
                <strong>{{ formatLabel }}</strong>
              </div>
              <div>
                <span>Заявки</span>
                <strong>
                  {{ registration.deadline ? `до ${formatDate(registration.deadline)}` : 'без срока' }}
                </strong>
              </div>
              <div>
                <span>Матчи</span>
                <strong>{{ rounds.length ? `${matches.played} / ${matches.total}` : '—' }}</strong>
              </div>
            </div>
          </div>
        </header>

        <div v-if="champion" class="champion-banner">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7">
            <path d="M8 3h8l-1 6a3 3 0 0 1-6 0z" />
            <path d="M8 5H4v2a4 4 0 0 0 4 4M16 5h4v2a4 4 0 0 1-4 4M12 15v4M8 21h8" />
          </svg>
          <div>
            <span>Чемпион турнира</span>
            <strong>{{ champion.nickname }}</strong>
            <span v-if="champion.fullName" class="champion-fullname">{{ champion.fullName }}</span>
          </div>
        </div>

        <section class="panel bracket-panel">
          <div class="panel-head">
            <h2>Турнирная сетка</h2>
            <span class="badge">{{ playersLabel }}</span>
          </div>
          <BracketView
            v-if="rounds.length"
            :rounds="rounds"
            :third-place="thirdPlace"
          />
          <div v-else class="empty-state">
            <strong>Сетка ещё не сформирована</strong>
            <p>Организатор проведёт жеребьёвку после закрытия заявок.</p>
          </div>
        </section>

        <div class="lower-grid">
          <section class="panel">
            <div class="panel-head">
              <h2>Таблица мест</h2>
            </div>
            <div v-if="standings.length" class="table-wrap">
              <table class="table-mk">
                <thead>
                  <tr>
                    <th>Место</th>
                    <th>Боец</th>
                    <th>Персонаж</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="row in standings" :key="`${row.place}-${row.player.id}`">
                    <td class="cell-strong place">{{ row.place }}</td>
                    <td class="cell-strong">
                      <span class="player-cell">
                        <span class="player-nick">{{ row.player.nickname }}</span>
                        <span v-if="row.player.fullName" class="player-fullname">{{ row.player.fullName }}</span>
                      </span>
                    </td>
                    <td>{{ row.player.mainCharacter || '—' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-else class="empty-state small">
              <p>Результатов пока нет.</p>
            </div>
          </section>

          <section class="panel">
            <div class="panel-head">
              <h2>Состав турнира</h2>
              <span class="badge">{{ players.length }}</span>
            </div>
            <ul v-if="players.length" class="roster">
              <li v-for="(player, index) in players" :key="player.id">
                <span class="roster-index">{{ String(index + 1).padStart(2, '0') }}</span>
                <span class="roster-person">
                  <span class="roster-name">{{ player.nickname }}</span>
                  <span v-if="player.fullName" class="roster-fullname">{{ player.fullName }}</span>
                </span>
                <span class="tag">{{ player.mainCharacter || '—' }}</span>
              </li>
            </ul>
            <div v-else class="empty-state small">
              <p>Состав пока не объявлен.</p>
            </div>
          </section>
        </div>
      </template>
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
  padding-top: clamp(28px, 4vw, 44px);
}

.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 90px 20px;
}

.back-link {
  display: inline-block;
  margin-bottom: 18px;
  color: var(--mute);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  transition: color 0.18s ease;
}

.back-link:hover {
  color: var(--gold);
}

.tournament-head {
  padding-bottom: 26px;
  border-bottom: 1px solid var(--line);
}

.head-row {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 28px;
}

.head-copy {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 12px;
  min-width: 260px;
}

h1 {
  font-size: clamp(1.9rem, 4.2vw, 2.9rem);
}

.head-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.description {
  max-width: 560px;
  color: var(--dim);
  font-size: 14px;
  line-height: 1.7;
}

.reg-line {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: var(--win);
  font-size: 12px;
  font-weight: 500;
}

.reg-line.is-closed {
  color: var(--mute);
}

.reg-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}

.head-meta {
  display: grid;
  gap: 14px 28px;
  grid-template-columns: repeat(2, minmax(0, auto));
}

.head-meta > div {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.head-meta span {
  color: var(--mute);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

.head-meta strong {
  font-size: 13.5px;
  font-weight: 500;
}

.champion-banner {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-top: 20px;
  padding: 16px 20px;
  border: 1px solid var(--gold);
  background: linear-gradient(100deg, var(--gold-soft), transparent 65%);
  color: var(--gold);
}

.champion-banner div {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
}

.champion-banner span {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--mute);
}

.champion-banner strong {
  font-family: var(--font-display);
  font-size: 20px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.champion-banner .champion-fullname {
  color: var(--dim);
  font-size: 12.5px;
  font-weight: 500;
  letter-spacing: 0;
  text-transform: none;
}

.bracket-panel {
  margin-top: 26px;
  padding: 20px 22px 24px;
}

.bracket-panel .panel-head {
  padding: 0 0 16px;
  border-bottom: 0;
}

.lower-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 16px;
}

.lower-grid .panel {
  overflow: hidden;
}

.place {
  color: var(--gold);
  font-family: var(--font-display);
  letter-spacing: 0.04em;
}

.roster {
  margin: 0;
  padding: 8px 22px 14px;
  list-style: none;
}

.roster li {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 0;
  border-bottom: 1px dashed var(--line);
}

.roster li:last-child {
  border-bottom: 0;
}

.roster-index {
  color: var(--mute);
  font-family: var(--font-display);
  font-size: 11px;
  letter-spacing: 0.1em;
  width: 20px;
  flex-shrink: 0;
}

.roster-person {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}

.roster-name {
  overflow: hidden;
  color: var(--text);
  font-size: 13.5px;
  font-weight: 500;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.roster-fullname {
  overflow: hidden;
  color: var(--mute);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.player-cell {
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.player-nick {
  font-weight: 600;
}

.player-fullname {
  color: var(--mute);
  font-size: 11px;
  font-weight: 500;
}

.empty-state.small {
  padding: 34px 20px;
  font-size: 13px;
}

@media (max-width: 860px) {
  .lower-grid {
    grid-template-columns: minmax(0, 1fr);
  }

  .head-meta {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    width: 100%;
  }
}
</style>
