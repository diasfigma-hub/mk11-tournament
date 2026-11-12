<script setup>
import { computed, onMounted, ref } from 'vue'
import SiteHeader from '@/components/SiteHeader.vue'
import SiteFooter from '@/components/SiteFooter.vue'
import TournamentCard from '@/components/TournamentCard.vue'
import { tournamentsApi } from '@/api'
import { TOURNAMENT_STATUSES } from '@/lib/constants'

const tournaments = ref([])
const loading = ref(true)
const error = ref('')
const filter = ref('all')

const filters = [
  { value: 'all', label: 'Все' },
  { value: 'draft', label: TOURNAMENT_STATUSES.draft.label },
  { value: 'live', label: TOURNAMENT_STATUSES.live.label },
  { value: 'finished', label: TOURNAMENT_STATUSES.finished.label },
]

onMounted(load)

async function load() {
  loading.value = true
  error.value = ''
  try {
    tournaments.value = await tournamentsApi.getAll()
  } catch {
    error.value = 'Не удалось загрузить список турниров. Попробуйте обновить страницу.'
  } finally {
    loading.value = false
  }
}

const counts = computed(() => {
  const result = { all: tournaments.value.length, draft: 0, live: 0, finished: 0 }
  tournaments.value.forEach((tournament) => {
    if (result[tournament.status] !== undefined) result[tournament.status] += 1
  })
  return result
})

const filtered = computed(() =>
  filter.value === 'all'
    ? tournaments.value
    : tournaments.value.filter((tournament) => tournament.status === filter.value),
)
</script>

<template>
  <div class="page">
    <SiteHeader />

    <main class="container">
      <header class="page-head">
        <div>
          <span class="eyebrow">Расписание арены</span>
          <h1>Турниры MK11</h1>
          <p>
            Открытые сетки и завершённые ивенты. Открой турнир, чтобы посмотреть пары,
            результаты и таблицу мест.
          </p>
        </div>
        <RouterLink to="/register" class="btn btn-primary">Стать участником</RouterLink>
      </header>

      <div class="filter-bar">
        <button
          v-for="item in filters"
          :key="item.value"
          type="button"
          class="filter-btn"
          :class="{ 'is-active': filter === item.value }"
          @click="filter = item.value"
        >
          {{ item.label }}
          <span class="filter-count">{{ counts[item.value] }}</span>
        </button>
        <button type="button" class="btn btn-quiet btn-sm refresh" :disabled="loading" @click="load">
          Обновить
        </button>
      </div>

      <div v-if="loading" class="state">
        <span class="spinner spinner-lg" />
        <p class="text-mute">Загружаем сетки…</p>
      </div>

      <div v-else-if="error" class="alert alert-error">{{ error }}</div>

      <div v-else-if="filtered.length" class="grid">
        <TournamentCard
          v-for="tournament in filtered"
          :key="tournament.id"
          :tournament="tournament"
        />
      </div>

      <div v-else class="panel empty-state">
        <strong>Здесь пока пусто</strong>
        <p>Турниров в этом статусе нет. Загляни позже или подай заявку в лобби.</p>
        <RouterLink to="/register" class="btn btn-ghost btn-sm">Регистрация бойца</RouterLink>
      </div>
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
  padding-top: clamp(32px, 5vw, 56px);
}

.page-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 24px;
  margin-bottom: 26px;
}

.page-head h1 {
  margin: 8px 0 10px;
  font-size: clamp(2rem, 4.4vw, 3rem);
}

.page-head p {
  max-width: 520px;
  color: var(--dim);
  font-size: 14px;
  line-height: 1.7;
}

.filter-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-bottom: 22px;
  padding-bottom: 18px;
  border-bottom: 1px solid var(--line);
}

.filter-btn {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 8px 12px;
  border: 1px solid var(--line);
  border-radius: 2px;
  background: transparent;
  color: var(--dim);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  cursor: pointer;
  transition: border-color 0.18s ease, color 0.18s ease, background-color 0.18s ease;
}

.filter-btn:hover {
  border-color: var(--line-2);
  color: var(--text);
}

.filter-btn.is-active {
  border-color: var(--gold);
  background: var(--gold-soft);
  color: var(--gold);
}

.filter-count {
  color: var(--mute);
  font-size: 10px;
}

.filter-btn.is-active .filter-count {
  color: var(--gold);
}

.refresh {
  margin-left: auto;
}

.grid {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 72px 20px;
}

@media (max-width: 960px) {
  .grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 700px) {
  .page-head {
    flex-direction: column;
    align-items: flex-start;
  }

  .grid {
    grid-template-columns: minmax(0, 1fr);
  }

  .refresh {
    margin-left: 0;
  }
}
</style>
