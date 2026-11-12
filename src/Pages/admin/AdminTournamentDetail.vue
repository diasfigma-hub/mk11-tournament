<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import BracketView from '@/components/BracketView.vue'
import Modal from '@/components/Modal.vue'
import { participantsApi, tournamentsApi } from '@/api'
import {
  applyScore as applyMatchScore,
  applyThirdPlaceScore,
  buildThirdPlace,
  championOf,
  countMatches,
  createRounds,
  nextPow2,
  resetResult,
  resetThirdPlace,
  scoreOptions,
} from '@/lib/bracket'
import { TOURNAMENT_FORMATS, TOURNAMENT_STATUSES, isAllowedCharacter } from '@/lib/constants'
import { formatDate, isFighter, platformLabel, pluralizeFighters } from '@/lib/format'

const route = useRoute()
const router = useRouter()

const tournament = ref(null)
const participants = ref([])
const loading = ref(true)
const notFound = ref(false)
const error = ref('')
const busy = ref(false)

const selected = ref([])
const search = ref('')

const scoreTarget = ref(null)
const showReset = ref(false)

onMounted(load)

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [event, roster] = await Promise.allSettled([
      tournamentsApi.getById(route.params.id),
      participantsApi.getAll(),
    ])

    if (event.status === 'fulfilled') tournament.value = event.value
    if (roster.status === 'fulfilled') participants.value = roster.value

    if (!tournament.value) {
      notFound.value = true
      return
    }

    if (tournament.value.players?.length && !tournament.value.rounds?.length) {
      selected.value = tournament.value.players.map((player) => player.id)
    }
  } catch {
    notFound.value = true
  } finally {
    loading.value = false
  }
}

const eligible = computed(() =>
  participants.value.filter(
    (participant) => isFighter(participant) && participant.status !== 'disqualified',
  ),
)

const filteredFighters = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return eligible.value
  return eligible.value.filter((fighter) =>
    [fighter.nickname, fighter.fullName, fighter.mainCharacter]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query)),
  )
})

const rounds = computed(() => tournament.value?.rounds || [])
const champion = computed(
  () => tournament.value?.champion || championOf(rounds.value),
)
const thirdPlace = computed(
  () =>
    tournament.value?.thirdPlace ||
    buildThirdPlace(rounds.value, null, tournament.value?.bo || 3),
)
const matches = computed(() => countMatches(rounds.value))
const status = computed(
  () => TOURNAMENT_STATUSES[tournament.value?.status] || TOURNAMENT_STATUSES.draft,
)

const bracketSize = computed(() => (selected.value.length >= 2 ? nextPow2(selected.value.length) : 0))
const byeCount = computed(() => Math.max(0, bracketSize.value - selected.value.length))

const playerLimit = computed(() => Number(tournament.value?.playerLimit) || 0)
const atLimit = computed(
  () => playerLimit.value > 0 && selected.value.length >= playerLimit.value,
)
const formatLabel = computed(
  () =>
    TOURNAMENT_FORMATS[tournament.value?.format]?.label ||
    TOURNAMENT_FORMATS.single_elimination.label,
)
const playersLabel = computed(() => pluralizeFighters(tournament.value?.players?.length || 0))

function isDisabled(id) {
  return atLimit.value && !selected.value.includes(id)
}

function toggleAll() {
  const ids = filteredFighters.value.map((fighter) => fighter.id)
  selected.value = playerLimit.value > 0 ? ids.slice(0, playerLimit.value) : ids
}

function clearSelection() {
  selected.value = []
}

function shuffle(list) {
  const result = [...list]
  for (let i = result.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[result[i], result[j]] = [result[j], result[i]]
  }
  return result
}

function toPlayer(fighter) {
  return {
    id: fighter.id,
    nickname: fighter.nickname,
    fullName: fighter.fullName || '',
    mainCharacter: isAllowedCharacter(fighter.mainCharacter) ? fighter.mainCharacter : '',
  }
}

async function persist(patch) {
  const updated = await tournamentsApi.update(tournament.value.id, patch)
  tournament.value = { ...tournament.value, ...patch, ...(updated || {}) }
}

async function drawBracket() {
  if (selected.value.length < 2) return
  busy.value = true
  error.value = ''
  try {
    const chosen = eligible.value.filter((fighter) => selected.value.includes(fighter.id))
    const players = shuffle(chosen).map(toPlayer)
    const newRounds = createRounds(players, {
      bo: tournament.value.bo || 3,
      finalBo: tournament.value.finalBo || 5,
    })
    await persist({
      players,
      rounds: newRounds,
      thirdPlace: buildThirdPlace(newRounds, null, tournament.value.bo || 3),
      status: 'live',
      champion: null,
    })
  } catch {
    error.value = 'Не удалось сформировать сетку. Попробуйте ещё раз.'
  } finally {
    busy.value = false
  }
}

function openScore(match, roundIndex, matchIndex) {
  if (!match?.p1 || !match?.p2) return
  scoreTarget.value = { match, roundIndex, matchIndex, options: scoreOptions(match.bo) }
}

function openThirdPlaceScore() {
  const third = thirdPlace.value
  if (!third?.p1 || !third?.p2) return
  scoreTarget.value = { match: third, third: true, options: scoreOptions(third.bo) }
}

async function applyScore(score1, score2) {
  if (!scoreTarget.value) return
  const { roundIndex, matchIndex } = scoreTarget.value
  busy.value = true
  try {
    if (scoreTarget.value.third) {
      const updatedThird = applyThirdPlaceScore(thirdPlace.value, score1, score2)
      await persist({ thirdPlace: updatedThird })
      scoreTarget.value = null
      return
    }

    const updatedRounds = applyMatchScore(rounds.value, roundIndex, matchIndex, score1, score2)
    const nextChampion = championOf(updatedRounds)
    await persist({
      rounds: updatedRounds,
      thirdPlace: buildThirdPlace(
        updatedRounds,
        thirdPlace.value,
        tournament.value.bo || 3,
      ),
      champion: nextChampion,
      status: nextChampion ? 'finished' : 'live',
    })
    scoreTarget.value = null
  } catch {
    error.value = 'Не удалось сохранить результат матча.'
  } finally {
    busy.value = false
  }
}

async function resetMatch() {
  if (!scoreTarget.value) return
  const { roundIndex, matchIndex } = scoreTarget.value
  busy.value = true
  try {
    if (scoreTarget.value.third) {
      const updatedThird = resetThirdPlace(thirdPlace.value)
      await persist({ thirdPlace: updatedThird })
      scoreTarget.value = null
      return
    }

    const updatedRounds = resetResult(rounds.value, roundIndex, matchIndex)
    const nextChampion = championOf(updatedRounds)
    await persist({
      rounds: updatedRounds,
      thirdPlace: buildThirdPlace(
        updatedRounds,
        thirdPlace.value,
        tournament.value.bo || 3,
      ),
      champion: nextChampion,
      status: nextChampion ? 'finished' : 'live',
    })
    scoreTarget.value = null
  } catch {
    error.value = 'Не удалось отменить результат.'
  } finally {
    busy.value = false
  }
}

async function resetBracket() {
  busy.value = true
  try {
    await persist({ rounds: [], thirdPlace: null, champion: null, status: 'draft' })
    selected.value = (tournament.value.players || []).map((player) => player.id)
    showReset.value = false
  } catch {
    error.value = 'Не удалось сбросить сетку.'
  } finally {
    busy.value = false
  }
}

function openPublicPage() {
  router.push(`/tournaments/${tournament.value.id}`)
}
</script>

<template>
  <div class="admin-page">
    <RouterLink to="/admin/tournaments" class="back-link">← Все турниры</RouterLink>

    <div v-if="loading" class="panel empty-state">
      <span class="spinner spinner-lg" />
      <p>Открываем турнир…</p>
    </div>

    <div v-else-if="notFound || !tournament" class="panel empty-state">
      <strong>Турнир не найден</strong>
      <p>Возможно, он был удалён.</p>
      <RouterLink to="/admin/tournaments" class="btn btn-ghost btn-sm">К списку турниров</RouterLink>
    </div>

    <template v-else>
      <header class="event-head">
        <div class="event-copy">
          <div class="event-badges">
            <span class="badge" :class="status.badge">{{ status.label }}</span>
            <span class="badge">{{ playersLabel }}</span>
            <span class="badge">Bo{{ tournament.bo || 3 }} / финал Bo{{ tournament.finalBo || 5 }}</span>
          </div>
          <h1>{{ tournament.title }}</h1>
          <p class="event-meta">
            {{ formatDate(tournament.date) }} ·
            {{ tournament.platform === 'all' || !tournament.platform
              ? 'Все платформы'
              : platformLabel(tournament.platform) }}
            · матчи {{ matches.played }} / {{ matches.total || '—' }}
          </p>
          <p class="event-meta">
            {{ formatLabel }} · заявки:
            {{ tournament.registrationEnd ? `до ${formatDate(tournament.registrationEnd)}` : 'без срока' }}
            <template v-if="playerLimit"> · лимит {{ playerLimit }}</template>
          </p>
        </div>

        <div class="event-actions">
          <button type="button" class="btn btn-ghost btn-sm" @click="openPublicPage">
            Публичная страница
          </button>
          <button
            v-if="rounds.length"
            type="button"
            class="btn btn-blood btn-sm"
            :disabled="busy"
            @click="showReset = true"
          >
            Сбросить сетку
          </button>
        </div>
      </header>

      <div v-if="error" class="alert alert-error">{{ error }}</div>

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

      <!-- Жеребьёвка -->
      <section v-if="!rounds.length" class="panel draw-panel">
        <div class="panel-head">
          <div>
            <h2>Жеребьёвка</h2>
            <p class="panel-sub">Отметьте состав — пары определит случайная жеребьёвка.</p>
          </div>
          <span class="badge badge-gold">
            {{ selected.length }} / {{ bracketSize || '—' }}
          </span>
        </div>

        <div class="draw-body">
          <div class="draw-toolbar">
            <input
              v-model="search"
              class="input search"
              type="search"
              placeholder="Найти бойца…"
            />
            <button type="button" class="btn btn-ghost btn-sm" @click="toggleAll">
              Выбрать всех
            </button>
            <button type="button" class="btn btn-quiet btn-sm" @click="clearSelection">
              Очистить
            </button>
          </div>

          <div v-if="filteredFighters.length === 0" class="empty-state small">
            <strong>Нет доступных бойцов</strong>
            <p>Отправьте бойцов на регистрацию или снимите фильтр поиска.</p>
            <RouterLink to="/register" class="btn btn-ghost btn-sm">Форма регистрации</RouterLink>
          </div>

          <ul v-else class="fighter-picker">
            <li v-for="fighter in filteredFighters" :key="fighter.id">
              <label>
                <input
                  v-model="selected"
                  type="checkbox"
                  :value="fighter.id"
                  :disabled="isDisabled(fighter.id)"
                />
                <span class="pick-person">
                  <span class="pick-name">{{ fighter.nickname }}</span>
                  <span v-if="fighter.fullName" class="pick-fullname">{{ fighter.fullName }}</span>
                </span>
                <span class="pick-char">{{ fighter.mainCharacter || '—' }}</span>
              </label>
            </li>
          </ul>
        </div>

        <div class="draw-foot">
          <p class="draw-hint">
            <template v-if="selected.length < 2">
              Выберите минимум двух бойцов.
            </template>
            <template v-else-if="playerLimit && selected.length > playerLimit">
              Выбрано больше лимита ({{ playerLimit }}) — снимите лишних.
            </template>
            <template v-else>
              Сетка на {{ bracketSize }} слотов<template v-if="byeCount">,
                без игры пройдут {{ pluralizeFighters(byeCount) }}</template>.
              <template v-if="playerLimit">
                Состав: {{ selected.length }} / {{ playerLimit }}.
              </template>
            </template>
          </p>
          <button
            type="button"
            class="btn btn-primary"
            :disabled="selected.length < 2 || busy || (playerLimit > 0 && selected.length > playerLimit)"
            @click="drawBracket"
          >
            {{ busy ? 'Формируем…' : 'Провести жеребьёвку' }}
          </button>
        </div>
      </section>

      <!-- Сетка -->
      <section v-else class="panel bracket-panel">
        <div class="panel-head">
          <div>
            <h2>Сетка турнира</h2>
            <p class="panel-sub">Нажмите на пару, чтобы внести счёт или исправить результат.</p>
          </div>
          <span class="badge">{{ matches.played }} / {{ matches.total }} матчей</span>
        </div>
        <BracketView
          :rounds="rounds"
          :third-place="thirdPlace"
          editable
          @score="openScore"
          @score-third="openThirdPlaceScore"
        />
      </section>

      <div v-if="tournament.description" class="panel description-panel">
        <h3>Описание турнира</h3>
        <p>{{ tournament.description }}</p>
      </div>
    </template>

    <Modal
      :model-value="!!scoreTarget"
      :title="scoreTarget ? `${scoreTarget.match.p1.nickname} — ${scoreTarget.match.p2.nickname}` : 'Матч'"
      @update:model-value="scoreTarget = null"
    >
      <template v-if="scoreTarget">
        <p class="score-hint">
          Формат матча: до {{ Math.ceil((scoreTarget.match.bo || 3) / 2) }} побед
          (Bo{{ scoreTarget.match.bo || 3 }}).
          <template v-if="scoreTarget.match.winnerId && !scoreTarget.third">
            Изменение счёта сбросит результаты следующих раундов.
          </template>
        </p>

        <p
          v-if="scoreTarget.match.p1.fullName || scoreTarget.match.p2.fullName"
          class="panel-sub score-fullnames"
        >
          {{ scoreTarget.match.p1.fullName || scoreTarget.match.p1.nickname }}
          —
          {{ scoreTarget.match.p2.fullName || scoreTarget.match.p2.nickname }}
        </p>

        <div class="score-grid">
          <button
            v-for="option in scoreTarget.options"
            :key="option.join('-')"
            type="button"
            class="score-option"
            :disabled="busy"
            @click="applyScore(option[0], option[1])"
          >
            <span class="score-side">{{ scoreTarget.match.p1.nickname }}</span>
            <span class="score-value">{{ option[0] }} : {{ option[1] }}</span>
            <span class="score-side right">{{ scoreTarget.match.p2.nickname }}</span>
          </button>
        </div>

        <button
          v-if="scoreTarget.match.winnerId"
          type="button"
          class="btn btn-blood btn-sm btn-block reset-match"
          :disabled="busy"
          @click="resetMatch"
        >
          Отменить результат матча
        </button>
      </template>
    </Modal>

    <Modal v-model="showReset" title="Сбросить сетку?">
      <p class="confirm-text">
        Все матчи и результаты будут удалены, сетку можно будет провести заново.
        Состав турнира сохранится.
      </p>
      <template #footer>
        <button type="button" class="btn btn-ghost btn-sm" @click="showReset = false">Отмена</button>
        <button type="button" class="btn btn-blood btn-sm" :disabled="busy" @click="resetBracket">
          Сбросить
        </button>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
.admin-page {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.back-link {
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

.event-head {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
}

.event-copy {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.event-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.event-copy h1 {
  font-size: clamp(1.6rem, 3.2vw, 2.2rem);
}

.event-meta {
  color: var(--dim);
  font-size: 12.5px;
}

.event-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.storage-note {
  border-color: var(--gold);
  background: var(--gold-soft);
  color: var(--dim);
  font-size: 12.5px;
}

.champion-banner {
  display: flex;
  align-items: center;
  gap: 14px;
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
  color: var(--mute);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
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

.panel-sub {
  margin-top: 4px;
  color: var(--mute);
  font-size: 12px;
}

/* ── Draw ── */

.draw-panel {
  overflow: hidden;
}

.draw-body {
  padding: 16px 22px 0;
}

.draw-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}

.search {
  flex: 1;
  min-width: 200px;
}

.fighter-picker {
  max-height: 340px;
  margin: 14px 0 0;
  padding: 0;
  overflow-y: auto;
  border-top: 1px solid var(--line);
  list-style: none;
}

.fighter-picker li {
  border-bottom: 1px solid var(--line);
}

.fighter-picker label {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 4px;
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.fighter-picker label:hover {
  background: var(--panel-2);
}

.fighter-picker input {
  width: 15px;
  height: 15px;
  accent-color: var(--gold);
  flex-shrink: 0;
}

.pick-person {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}

.pick-name {
  overflow: hidden;
  color: var(--text);
  font-size: 13.5px;
  font-weight: 500;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pick-fullname {
  overflow: hidden;
  color: var(--mute);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pick-char {
  color: var(--dim);
  font-size: 12px;
}

.pick-platform {
  width: 150px;
  color: var(--mute);
  font-size: 11px;
  text-align: right;
}

.draw-foot {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 16px 22px 20px;
  border-top: 1px solid var(--line);
  background: var(--panel-2);
}

.draw-hint {
  color: var(--dim);
  font-size: 12.5px;
}

/* ── Bracket ── */

.bracket-panel {
  padding: 20px 22px 26px;
}

.bracket-panel .panel-head {
  padding: 0 0 16px;
  border-bottom: 0;
}

.description-panel {
  padding: 18px 22px;
}

.description-panel h3 {
  margin-bottom: 8px;
  font-size: 13px;
  letter-spacing: 0.1em;
}

.description-panel p {
  color: var(--dim);
  font-size: 13px;
  line-height: 1.7;
  white-space: pre-line;
}

/* ── Score modal ── */

.score-hint {
  color: var(--dim);
  font-size: 12.5px;
  line-height: 1.7;
}

.score-grid {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 16px;
}

.score-option {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 62px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border: 1px solid var(--line);
  border-radius: 2px;
  background: var(--panel-2);
  color: var(--text);
  font-family: var(--font-body);
  font-size: 12.5px;
  cursor: pointer;
  transition: border-color 0.18s ease, background-color 0.18s ease;
}

.score-option:hover:not(:disabled) {
  border-color: var(--gold);
  background: var(--gold-soft);
}

.score-option:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.score-side {
  overflow: hidden;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.score-side.right {
  text-align: right;
}

.score-value {
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-align: center;
}

.reset-match {
  margin-top: 16px;
}

.confirm-text {
  color: var(--dim);
  font-size: 13.5px;
  line-height: 1.7;
}

.empty-state.small {
  padding: 34px 20px;
  font-size: 13px;
}

@media (max-width: 720px) {
  .pick-platform {
    display: none;
  }

  .draw-body {
    padding-inline: 16px;
  }

  .draw-foot {
    padding-inline: 16px;
  }

  .bracket-panel {
    padding: 16px;
  }
}
</style>
