<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import Modal from '@/components/Modal.vue'
import { tournamentsApi } from '@/api'
import { PLATFORMS, TOURNAMENT_FORMATS, TOURNAMENT_STATUSES } from '@/lib/constants'
import { formatDate } from '@/lib/format'

const router = useRouter()

const tournaments = ref([])
const loading = ref(false)
const error = ref('')

const showCreate = ref(false)
const creating = ref(false)
const pendingDelete = ref(null)
const deleting = ref(false)

function toLocalInput(date) {
  const pad = (value) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function inDays(days) {
  const date = new Date(Date.now() + days * 24 * 60 * 60 * 1000)
  date.setMinutes(0, 0, 0)
  return toLocalInput(date)
}

const form = reactive({
  title: '',
  description: '',
  date: inDays(7),
  registrationEnd: inDays(6),
  playerLimit: '',
  platform: 'all',
  bo: 3,
  finalBo: 5,
})

const formErrors = reactive({})

onMounted(load)

async function load() {
  loading.value = true
  error.value = ''
  try {
    tournaments.value = await tournamentsApi.getAll()
  } catch {
    error.value = 'Не удалось загрузить турниры.'
  } finally {
    loading.value = false
  }
}

const statusOf = (tournament) =>
  TOURNAMENT_STATUSES[tournament.status] || TOURNAMENT_STATUSES.draft

const totalPlayers = computed(() =>
  tournaments.value.reduce((sum, tournament) => sum + (tournament.players?.length || 0), 0),
)
const liveCount = computed(
  () => tournaments.value.filter((tournament) => tournament.status === 'live').length,
)
const finishedCount = computed(
  () => tournaments.value.filter((tournament) => tournament.status === 'finished').length,
)

function openCreate() {
  Object.assign(form, {
    title: '',
    description: '',
    date: inDays(7),
    registrationEnd: inDays(6),
    playerLimit: '',
    platform: 'all',
    bo: 3,
    finalBo: 5,
  })
  Object.keys(formErrors).forEach((key) => delete formErrors[key])
  showCreate.value = true
}

function syncFinalBo() {
  if (form.finalBo < form.bo) form.finalBo = form.bo
}

async function createTournament() {
  Object.keys(formErrors).forEach((key) => delete formErrors[key])

  if (!form.title.trim()) formErrors.title = 'Введите название турнира'
  if (!form.date) formErrors.date = 'Укажите дату и время'
  if (form.bo === 5 && form.finalBo < 5) formErrors.finalBo = 'Гранд-финал не может быть короче матчей'
  if (form.registrationEnd && form.date && new Date(form.registrationEnd) > new Date(form.date)) {
    formErrors.registrationEnd = 'Регистрация должна закрыться до старта'
  }
  if (form.playerLimit !== '') {
    const limit = Number(form.playerLimit)
    if (!Number.isInteger(limit) || limit < 2 || limit > 64) {
      formErrors.playerLimit = 'Лимит от 2 до 64 игроков'
    }
  }

  if (Object.keys(formErrors).length) return

  creating.value = true
  error.value = ''
  try {
    const created = await tournamentsApi.create({
      title: form.title.trim(),
      description: form.description.trim(),
      date: new Date(form.date).toISOString(),
      registrationEnd: form.registrationEnd
        ? new Date(form.registrationEnd).toISOString()
        : null,
      playerLimit: form.playerLimit === '' ? null : Number(form.playerLimit),
      platform: form.platform,
      format: 'single_elimination',
      bo: form.bo,
      finalBo: form.finalBo,
      status: 'draft',
    })
    showCreate.value = false
    router.push(`/admin/tournaments/${created.id}`)
  } catch {
    error.value = 'Не удалось создать турнир.'
  } finally {
    creating.value = false
  }
}

async function confirmDelete() {
  if (!pendingDelete.value) return
  deleting.value = true
  error.value = ''
  try {
    await tournamentsApi.remove(pendingDelete.value.id)
    tournaments.value = tournaments.value.filter((item) => item.id !== pendingDelete.value.id)
    pendingDelete.value = null
  } catch {
    error.value = 'Не удалось удалить турнир.'
  } finally {
    deleting.value = false
  }
}
</script>

<template>
  <div class="admin-page">
    <header class="page-head">
      <div>
        <span class="eyebrow">Организация</span>
        <h1>Турниры</h1>
        <p>Создайте ивент, проведите жеребьёвку и ведите матчи до чемпиона.</p>
      </div>
      <button type="button" class="btn btn-primary btn-sm" @click="openCreate">
        + Новый турнир
      </button>
    </header>

    <div class="stats-row">
      <div class="stat-card">
        <span class="stat-label">Всего турниров</span>
        <span class="stat-value">{{ tournaments.length }}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">В игре</span>
        <span class="stat-value">{{ liveCount }}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">Завершено</span>
        <span class="stat-value">{{ finishedCount }}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">Бойцов в сетках</span>
        <span class="stat-value">{{ totalPlayers }}</span>
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div class="panel table-panel">
      <div v-if="loading && tournaments.length === 0" class="empty-state">
        <span class="spinner spinner-lg" />
        <p>Загружаем турниры…</p>
      </div>

      <div v-else-if="tournaments.length === 0" class="empty-state">
        <strong>Турниров пока нет</strong>
        <p>Создайте первый ивент — сетка появится после жеребьёвки.</p>
        <button type="button" class="btn btn-primary btn-sm" @click="openCreate">
          + Новый турнир
        </button>
      </div>

      <div v-else class="table-wrap">
        <table class="table-mk">
          <thead>
            <tr>
              <th>Турнир</th>
              <th>Дата</th>
              <th>Платформа</th>
              <th>Состав</th>
              <th>Формат</th>
              <th>Заявки</th>
              <th>Статус</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="tournament in tournaments" :key="tournament.id">
              <td>
                <div class="tournament-cell">
                  <strong>{{ tournament.title }}</strong>
                  <span v-if="tournament.champion">
                    Чемпион: {{ tournament.champion.nickname }}
                    <template v-if="tournament.champion.fullName">
                      · {{ tournament.champion.fullName }}
                    </template>
                  </span>
                </div>
              </td>
              <td class="cell-date">{{ formatDate(tournament.date) }}</td>
              <td>
                {{ tournament.platform === 'all' || !tournament.platform
                  ? 'Все'
                  : PLATFORMS.find((p) => p.value === tournament.platform)?.label || '—' }}
              </td>
              <td>{{ tournament.players?.length || 0 }}</td>
              <td>Bo{{ tournament.bo || 3 }} / Bo{{ tournament.finalBo || 5 }}</td>
              <td>
                <div class="applications-cell">
                  <span>
                    {{ tournament.registrationEnd ? formatDate(tournament.registrationEnd, false) : 'без срока' }}
                  </span>
                  <small v-if="tournament.playerLimit">лимит {{ tournament.playerLimit }}</small>
                </div>
              </td>
              <td>
                <span class="badge" :class="statusOf(tournament).badge">
                  {{ statusOf(tournament).label }}
                </span>
              </td>
              <td>
                <div class="row-actions">
                  <RouterLink
                    :to="`/admin/tournaments/${tournament.id}`"
                    class="btn btn-ghost btn-sm"
                  >
                    Открыть
                  </RouterLink>
                  <button type="button" class="danger-link" @click="pendingDelete = tournament">
                    Удалить
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <Modal v-model="showCreate" title="Новый турнир" wide>
      <div class="field">
        <label class="label" for="title">Название <span class="required">*</span></label>
        <input
          id="title"
          v-model="form.title"
          class="input"
          :class="{ 'is-error': formErrors.title }"
          type="text"
          placeholder="MK11 Arena Cup #1"
          @input="delete formErrors.title"
        />
        <p v-if="formErrors.title" class="field-error">{{ formErrors.title }}</p>
      </div>

      <div class="row">
        <div class="field">
          <label class="label" for="date">Дата и время <span class="required">*</span></label>
          <input
            id="date"
            v-model="form.date"
            class="input"
            :class="{ 'is-error': formErrors.date }"
            type="datetime-local"
            @input="delete formErrors.date"
          />
          <p v-if="formErrors.date" class="field-error">{{ formErrors.date }}</p>
        </div>

        <div class="field">
          <label class="label" for="platform">Платформа</label>
          <div class="select-wrap">
            <select id="platform" v-model="form.platform" class="select">
              <option value="all">Все платформы</option>
              <option v-for="platform in PLATFORMS" :key="platform.value" :value="platform.value">
                {{ platform.label }}
              </option>
            </select>
          </div>
        </div>
      </div>

      <div class="row">
        <div class="field">
          <label class="label" for="registrationEnd">Регистрация до</label>
          <input
            id="registrationEnd"
            v-model="form.registrationEnd"
            class="input"
            :class="{ 'is-error': formErrors.registrationEnd }"
            type="datetime-local"
            @input="delete formErrors.registrationEnd"
          />
          <p v-if="formErrors.registrationEnd" class="field-error">{{ formErrors.registrationEnd }}</p>
          <p v-else class="hint">Можно оставить пустым — без срока.</p>
        </div>

        <div class="field">
          <label class="label" for="playerLimit">Лимит игроков</label>
          <input
            id="playerLimit"
            v-model="form.playerLimit"
            class="input"
            :class="{ 'is-error': formErrors.playerLimit }"
            type="number"
            min="2"
            max="64"
            placeholder="Без лимита"
            @input="delete formErrors.playerLimit"
          />
          <p v-if="formErrors.playerLimit" class="field-error">{{ formErrors.playerLimit }}</p>
          <p v-else class="hint">От 2 до 64. Пустое поле — без ограничения.</p>
        </div>
      </div>

      <div class="row">
        <div class="field">
          <label class="label" for="bo">Матчи</label>
          <div class="select-wrap">
            <select id="bo" v-model.number="form.bo" class="select" @change="syncFinalBo">
              <option :value="3">Bo3 — до 2 побед</option>
              <option :value="5">Bo5 — до 3 побед</option>
            </select>
          </div>
        </div>

        <div class="field">
          <label class="label" for="finalBo">Гранд-финал</label>
          <div class="select-wrap">
            <select
              id="finalBo"
              v-model.number="form.finalBo"
              class="select"
              :class="{ 'is-error': formErrors.finalBo }"
            >
              <option :value="3">Bo3</option>
              <option :value="5">Bo5</option>
            </select>
          </div>
          <p v-if="formErrors.finalBo" class="field-error">{{ formErrors.finalBo }}</p>
        </div>
      </div>

      <div class="field">
        <label class="label" for="description">Описание и правила</label>
        <textarea
          id="description"
          v-model="form.description"
          class="textarea"
          placeholder="Онлайн-турнир, чек-ин за 15 минут до старта…"
        />
      </div>

      <p class="form-note">
        Сетка: {{ TOURNAMENT_FORMATS.single_elimination.label }} —
        {{ TOURNAMENT_FORMATS.single_elimination.hint }}
        Другие форматы (double elimination, round robin) появятся позже.
      </p>

      <template #footer>
        <button type="button" class="btn btn-ghost btn-sm" @click="showCreate = false">
          Отмена
        </button>
        <button type="button" class="btn btn-primary btn-sm" :disabled="creating" @click="createTournament">
          {{ creating ? 'Создаём…' : 'Создать турнир' }}
        </button>
      </template>
    </Modal>

    <Modal
      :model-value="!!pendingDelete"
      title="Удалить турнир?"
      @update:model-value="pendingDelete = null"
    >
      <p class="confirm-text">
        Турнир <strong>{{ pendingDelete?.title }}</strong> и его сетка будут удалены без
        возможности восстановления.
      </p>
      <template #footer>
        <button type="button" class="btn btn-ghost btn-sm" @click="pendingDelete = null">
          Отмена
        </button>
        <button type="button" class="btn btn-blood btn-sm" :disabled="deleting" @click="confirmDelete">
          {{ deleting ? 'Удаляем…' : 'Удалить' }}
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

.page-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
}

.page-head h1 {
  margin: 6px 0 6px;
  font-size: clamp(1.6rem, 3vw, 2.1rem);
}

.page-head p {
  color: var(--dim);
  font-size: 13px;
}

.stats-row {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.stat-card {
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 14px 16px;
  border: 1px solid var(--line);
  background: var(--panel);
}

.stat-label {
  color: var(--mute);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.stat-value {
  font-family: var(--font-display);
  font-size: 1.6rem;
  font-weight: 600;
  line-height: 1;
}

.storage-note {
  border-color: var(--gold);
  background: var(--gold-soft);
  color: var(--dim);
  font-size: 12.5px;
  line-height: 1.7;
}

.storage-note code {
  padding: 1px 5px;
  background: var(--panel-2);
  color: var(--gold);
  font-size: 12px;
}

.table-panel {
  overflow: hidden;
}

.tournament-cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.tournament-cell strong {
  color: var(--text);
  font-size: 13.5px;
  font-weight: 600;
}

.tournament-cell span {
  color: var(--gold);
  font-size: 11px;
}

.cell-date {
  color: var(--mute);
  font-size: 11.5px;
  white-space: nowrap;
}

.applications-cell {
  display: flex;
  flex-direction: column;
  gap: 1px;
  font-size: 12px;
  white-space: nowrap;
}

.applications-cell small {
  color: var(--mute);
  font-size: 10.5px;
}

.form-note {
  margin-top: 18px;
  padding: 12px 14px;
  border: 1px solid var(--line);
  background: var(--panel-2);
  color: var(--mute);
  font-size: 11.5px;
  line-height: 1.65;
}

.row-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: flex-end;
}

.danger-link {
  padding: 6px 8px;
  border: 0;
  background: transparent;
  color: var(--mute);
  font-size: 11px;
  cursor: pointer;
  transition: color 0.18s ease;
}

.danger-link:hover {
  color: var(--blood-2);
}

.row {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-top: 18px;
}

.row .field + .field {
  margin-top: 0;
}

.modal-body .field + .field,
.modal-body .row + .field {
  margin-top: 18px;
}

.confirm-text {
  color: var(--dim);
  font-size: 13.5px;
  line-height: 1.7;
}

.confirm-text strong {
  color: var(--text);
}

@media (max-width: 1100px) {
  .stats-row {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .page-head {
    flex-direction: column;
    align-items: flex-start;
  }

  .row {
    grid-template-columns: minmax(0, 1fr);
  }

  .row .field + .field {
    margin-top: 18px;
  }
}
</style>
