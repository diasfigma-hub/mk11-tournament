<script setup>
import { computed } from 'vue'
import { TOURNAMENT_STATUSES } from '@/lib/constants'
import { formatDate, platformLabel, pluralizeFighters } from '@/lib/format'

const props = defineProps({
  tournament: { type: Object, required: true },
})

const status = computed(() => TOURNAMENT_STATUSES[props.tournament.status] || TOURNAMENT_STATUSES.draft)
const players = computed(() => props.tournament.players?.length || 0)
const playersLabel = computed(() => pluralizeFighters(players.value))
const playerLimit = computed(() => Number(props.tournament.playerLimit) || 0)
const platform = computed(() =>
  props.tournament.platform === 'all' || !props.tournament.platform
    ? 'Все платформы'
    : platformLabel(props.tournament.platform),
)
const format = computed(() => `Bo${props.tournament.bo || 3} · финал Bo${props.tournament.finalBo || 5}`)
</script>

<template>
  <RouterLink :to="`/tournaments/${tournament.id}`" class="tournament-card">
    <div class="card-top">
      <span class="badge" :class="status.badge">{{ status.label }}</span>
      <span class="card-date">{{ formatDate(tournament.date) }}</span>
    </div>

    <h3>{{ tournament.title }}</h3>
    <p v-if="tournament.description" class="card-desc">{{ tournament.description }}</p>

    <div class="card-meta">
      <span class="tag">{{ platform }}</span>
      <span class="tag">{{ playersLabel }}</span>
      <span class="tag">{{ format }}</span>
      <span v-if="playerLimit" class="tag">лимит {{ playerLimit }}</span>
    </div>

    <div v-if="tournament.champion" class="card-champion">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M8 3h8l-1 6a3 3 0 0 1-6 0z" />
        <path d="M8 5H4v2a4 4 0 0 0 4 4M16 5h4v2a4 4 0 0 1-4 4M12 15v4M8 21h8" />
      </svg>
      <span class="champion-text">
        <span>Чемпион: {{ tournament.champion.nickname }}</span>
        <small v-if="tournament.champion.fullName">{{ tournament.champion.fullName }}</small>
      </span>
    </div>

    <span class="card-link">Открыть сетку →</span>
  </RouterLink>
</template>

<style scoped>
.tournament-card {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 20px;
  border: 1px solid var(--line);
  border-radius: 2px;
  background: var(--panel);
  transition: border-color 0.18s ease, transform 0.18s ease, background-color 0.18s ease;
}

.tournament-card:hover {
  border-color: var(--gold);
  background: var(--panel-2);
  transform: translateY(-2px);
}

.card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.card-date {
  color: var(--mute);
  font-size: 11px;
  letter-spacing: 0.04em;
  white-space: nowrap;
}

h3 {
  font-size: 19px;
  letter-spacing: 0.04em;
}

.card-desc {
  display: -webkit-box;
  overflow: hidden;
  color: var(--dim);
  font-size: 13px;
  line-height: 1.6;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.card-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: auto;
}

.card-champion {
  display: flex;
  align-items: center;
  gap: 7px;
  padding-top: 10px;
  border-top: 1px solid var(--line);
  color: var(--gold);
  font-size: 12px;
  font-weight: 600;
}

.champion-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.champion-text small {
  color: var(--mute);
  font-size: 11px;
  font-weight: 500;
}

.card-link {
  color: var(--gold);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}
</style>
