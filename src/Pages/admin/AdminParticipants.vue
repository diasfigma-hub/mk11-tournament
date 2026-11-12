<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import Modal from '@/components/Modal.vue'
import { participantsApi, settingsApi } from '@/api'
import { PLAYER_STATUSES, ROSTER, isAllowedCharacter } from '@/lib/constants'
import { formatShortDate, isFighter } from '@/lib/format'

const participants = ref([])
const loading = ref(false)
const error = ref('')
const notice = ref('')

const search = ref('')
const showArchive = ref(false)
const page = ref(1)
const perPage = 12
const sortBy = ref('createdAt')
const sortDir = ref('desc')

const pendingDelete = ref(null)
const deleting = ref(false)
const busyId = ref(null)
const savingCharId = ref(null)
const roster = ROSTER

const registrationClosed = ref(false)
const savingSettings = ref(false)

const editing = ref(null)
const editForm = reactive({ nickname: '', fullName: '', mainCharacter: '', contact: '' })
const editError = ref('')
const savingEdit = ref(false)

let channel = null

const fighters = computed(() => participants.value.filter(isFighter))

const visible = computed(() => {
  let list = showArchive.value ? participants.value : fighters.value

  const query = search.value.trim().toLowerCase()
  if (query) {
    list = list.filter((item) =>
      [item.nickname, item.fullName, item.contact]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(query)),
    )
  }

  const direction = sortDir.value === 'asc' ? 1 : -1
  return [...list].sort((a, b) => {
    if (sortBy.value === 'nickname') {
      const left = String(a.nickname || a.fullName || '').toLowerCase()
      const right = String(b.nickname || b.fullName || '').toLowerCase()
      return left.localeCompare(right, 'ru') * direction
    }
    return (new Date(a.createdAt || 0) - new Date(b.createdAt || 0)) * direction
  })
})

const totalPages = computed(() => Math.max(1, Math.ceil(visible.value.length / perPage)))
const paginated = computed(() =>
  visible.value.slice((page.value - 1) * perPage, page.value * perPage),
)

const stats = computed(() => [
  { label: 'Бойцов в лобби', value: fighters.value.length },
  {
    label: 'Допущено',
    value: fighters.value.filter((item) => item.status !== 'disqualified').length,
  },
  {
    label: 'Персонажей',
    value: new Set(fighters.value.map((item) => item.mainCharacter).filter(Boolean)).size,
  },
  {
    label: 'Снято',
    value: fighters.value.filter((item) => item.status === 'disqualified').length,
  },
])

onMounted(async () => {
  await Promise.all([load(), loadSettings()])
  try {
    channel = participantsApi.subscribe(() => load())
  } catch {
    // Realtime не критичен: остаётся кнопка «Обновить».
  }
})

onUnmounted(() => participantsApi.unsubscribe(channel))

async function load() {
  loading.value = true
  error.value = ''
  try {
    participants.value = await participantsApi.getAll()
  } catch (e) {
    error.value = e?.message || 'Не удалось загрузить список бойцов. Проверьте соединение.'
  } finally {
    loading.value = false
  }
}

async function loadSettings() {
  try {
    registrationClosed.value = await settingsApi.getRegistrationClosed()
  } catch {
    // статус регистрации не мешает работе лобби
  }
}

async function toggleRegistration() {
  const next = !registrationClosed.value
  savingSettings.value = true
  error.value = ''
  try {
    await settingsApi.setRegistrationClosed(next)
    registrationClosed.value = next
    notice.value = next ? 'Регистрация в лобби закрыта' : 'Регистрация в лобби открыта'
  } catch (e) {
    error.value = e?.message || 'Не удалось изменить статус регистрации.'
  } finally {
    savingSettings.value = false
  }
}

function openEdit(record) {
  editing.value = record
  editError.value = ''
  Object.assign(editForm, {
    nickname: record.nickname || '',
    fullName: record.fullName || '',
    mainCharacter: isAllowedCharacter(record.mainCharacter) ? record.mainCharacter : '',
    contact: record.contact || '',
  })
}

async function saveEdit() {
  if (!editing.value) return
  editError.value = ''

  const nickname = editForm.nickname.trim()
  const fullName = editForm.fullName.trim()
  const contact = editForm.contact.trim()

  if (nickname.length < 2 || nickname.length > 20) {
    editError.value = 'Ник должен быть от 2 до 20 символов'
    return
  }
  if (!fullName) {
    editError.value = 'Укажите ФИО'
    return
  }
  if (!isAllowedCharacter(editForm.mainCharacter)) {
    editError.value = 'Выберите персонажа из базового состава'
    return
  }
  if (contact.length > 120) {
    editError.value = 'Контакт слишком длинный'
    return
  }

  savingEdit.value = true
  try {
    const updated = await participantsApi.update(editing.value.id, {
      nickname,
      fullName,
      mainCharacter: editForm.mainCharacter,
      contact,
    })
    Object.assign(editing.value, updated)
    notice.value = 'Данные бойца обновлены'
    editing.value = null
  } catch (e) {
    editError.value = e?.message || 'Не удалось сохранить изменения.'
  } finally {
    savingEdit.value = false
  }
}

function statusMeta(record) {
  if (!record.status) return null
  return PLAYER_STATUSES[record.status] || null
}

function needsCharacter(record) {
  return Boolean(record.mainCharacter) && !isAllowedCharacter(record.mainCharacter)
}

async function updateCharacter(record, value) {
  if (!isAllowedCharacter(value)) return
  savingCharId.value = record.id
  error.value = ''
  try {
    await participantsApi.update(record.id, { mainCharacter: value })
    record.mainCharacter = value
    notice.value = 'Персонаж обновлён'
  } catch {
    error.value = 'Не удалось изменить персонажа.'
  } finally {
    savingCharId.value = null
  }
}

async function toggleStatus(record) {
  if (!record.status) return
  const nextStatus = record.status === 'disqualified' ? 'accepted' : 'disqualified'
  busyId.value = record.id
  error.value = ''
  try {
    await participantsApi.update(record.id, { status: nextStatus })
    record.status = nextStatus
  } catch {
    error.value = 'Не удалось изменить статус бойца.'
  } finally {
    busyId.value = null
  }
}

function askDelete(record) {
  pendingDelete.value = record
}

async function confirmDelete() {
  if (!pendingDelete.value) return
  deleting.value = true
  error.value = ''
  try {
    await participantsApi.remove(pendingDelete.value.id)
    participants.value = participants.value.filter((item) => item.id !== pendingDelete.value.id)
    notice.value = 'Запись удалена'
    pendingDelete.value = null
  } catch {
    error.value = 'Не удалось удалить запись.'
  } finally {
    deleting.value = false
  }
}

function resetPage() {
  page.value = 1
}

function setSort(field) {
  if (sortBy.value === field) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = field
    sortDir.value = field === 'createdAt' ? 'desc' : 'asc'
  }
  resetPage()
}

function displayName(record) {
  return record.nickname || record.fullName || 'Без имени'
}
</script>

<template>
  <div class="admin-page">
    <header class="page-head">
      <div>
        <span class="eyebrow">Лобби</span>
        <h1>Бойцы</h1>
        <p>Заявки с формы регистрации. Отсюда видно, кого можно ставить в сетку.</p>
      </div>
      <div class="head-actions">
        <button
          type="button"
          class="btn btn-quiet btn-sm"
          :disabled="savingSettings"
          @click="toggleRegistration"
        >
          {{ registrationClosed ? 'Открыть регистрацию' : 'Закрыть регистрацию' }}
        </button>
        <button type="button" class="btn btn-ghost btn-sm" :disabled="loading" @click="load">
          {{ loading ? 'Обновление…' : 'Обновить' }}
        </button>
      </div>
    </header>

    <div class="stats-row">
      <div v-for="stat in stats" :key="stat.label" class="stat-card">
        <span class="stat-label">{{ stat.label }}</span>
        <span class="stat-value">{{ stat.value }}</span>
      </div>
    </div>

    <div class="filters">
      <input
        v-model="search"
        class="input search"
        type="search"
        placeholder="Поиск по нику, имени, контакту…"
        @input="resetPage"
      />
      <label class="archive-toggle">
        <input v-model="showArchive" type="checkbox" @change="resetPage" />
        Показывать старые заявки
      </label>
    </div>

    <div v-if="notice" class="alert alert-success notice">{{ notice }}</div>
    <div v-if="error" class="alert alert-error notice">{{ error }}</div>

    <div class="panel table-panel">
      <div v-if="loading && participants.length === 0" class="empty-state">
        <span class="spinner spinner-lg" />
        <p>Загружаем лобби…</p>
      </div>

      <div v-else-if="visible.length === 0" class="empty-state">
        <strong>Никого не нашли</strong>
        <p>Измените фильтр или отправьте бойца на регистрацию.</p>
      </div>

      <div v-else class="table-wrap">
        <table class="table-mk">
          <thead>
            <tr>
              <th>#</th>
              <th>
                <button type="button" class="sort-btn" @click="setSort('nickname')">
                  Боец
                  <span>{{ sortBy === 'nickname' ? (sortDir === 'asc' ? '↑' : '↓') : '↕' }}</span>
                </button>
              </th>
              <th>Персонаж</th>
              <th>Статус</th>
              <th>
                <button type="button" class="sort-btn" @click="setSort('createdAt')">
                  Заявка
                  <span>{{ sortBy === 'createdAt' ? (sortDir === 'asc' ? '↑' : '↓') : '↕' }}</span>
                </button>
              </th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(record, index) in paginated" :key="record.id">
              <td class="cell-index">{{ (page - 1) * perPage + index + 1 }}</td>
              <td>
                <div class="fighter-cell">
                  <strong>{{ displayName(record) }}</strong>
                  <span v-if="record.nickname && record.fullName">{{ record.fullName }}</span>
                  <span v-if="!isFighter(record)" class="badge">архив</span>
                </div>
              </td>
              <td>
                <select
                  v-if="needsCharacter(record)"
                  class="select char-select"
                  :value="record.mainCharacter"
                  :disabled="savingCharId === record.id"
                  title="Этот персонаж недоступен в турнире — выберите из базового состава"
                  @change="updateCharacter(record, $event.target.value)"
                >
                  <option :value="record.mainCharacter" disabled>
                    {{ record.mainCharacter }} — DLC, выберите заново
                  </option>
                  <option v-for="character in roster" :key="character" :value="character">
                    {{ character }}
                  </option>
                </select>
                <span v-else>{{ record.mainCharacter || '—' }}</span>
              </td>
              <td>
                <span v-if="statusMeta(record)" class="badge" :class="statusMeta(record).badge">
                  {{ statusMeta(record).label }}
                </span>
                <span v-else class="text-mute">—</span>
              </td>
              <td class="cell-date">{{ formatShortDate(record.createdAt) }}</td>
              <td>
                <div class="row-actions">
                  <button type="button" class="btn btn-quiet btn-sm" @click="openEdit(record)">
                    Изменить
                  </button>
                  <button
                    v-if="record.status"
                    type="button"
                    class="btn btn-quiet btn-sm"
                    :disabled="busyId === record.id"
                    @click="toggleStatus(record)"
                  >
                    {{ record.status === 'disqualified' ? 'Допустить' : 'Снять' }}
                  </button>
                  <button type="button" class="danger-link" @click="askDelete(record)">Удалить</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="totalPages > 1" class="pagination">
      <button type="button" class="btn btn-ghost btn-sm" :disabled="page === 1" @click="page--">
        ← Назад
      </button>
      <span class="page-info">{{ page }} / {{ totalPages }}</span>
      <button
        type="button"
        class="btn btn-ghost btn-sm"
        :disabled="page === totalPages"
        @click="page++"
      >
        Вперёд →
      </button>
    </div>

    <Modal
      :model-value="!!pendingDelete"
      title="Удалить запись?"
      @update:model-value="pendingDelete = null"
    >
      <p class="confirm-text">
        Боец <strong>{{ pendingDelete ? displayName(pendingDelete) : '' }}</strong> будет удалён
        из лобби. Если он уже в сетке турнира, в сетке останется его последняя запись.
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

    <Modal
      :model-value="!!editing"
      title="Редактировать бойца"
      @update:model-value="editing = null"
    >
      <div class="field">
        <label class="label" for="edit-nickname">Игровой ник</label>
        <input
          id="edit-nickname"
          v-model="editForm.nickname"
          class="input"
          type="text"
          maxlength="20"
          autocomplete="off"
        />
      </div>

      <div class="field">
        <label class="label" for="edit-fullname">ФИО</label>
        <input
          id="edit-fullname"
          v-model="editForm.fullName"
          class="input"
          type="text"
          autocomplete="name"
        />
      </div>

      <div class="field">
        <label class="label" for="edit-character">Основной персонаж</label>
        <div class="select-wrap">
          <select id="edit-character" v-model="editForm.mainCharacter" class="select">
            <option value="" disabled>Выберите бойца</option>
            <option v-for="character in roster" :key="character" :value="character">
              {{ character }}
            </option>
          </select>
        </div>
      </div>

      <div class="field">
        <label class="label" for="edit-contact">Контакт</label>
        <input
          id="edit-contact"
          v-model="editForm.contact"
          class="input"
          type="text"
          placeholder="Необязательно"
          autocomplete="off"
        />
      </div>

      <p v-if="editError" class="field-error">{{ editError }}</p>

      <template #footer>
        <button type="button" class="btn btn-ghost btn-sm" @click="editing = null">
          Отмена
        </button>
        <button type="button" class="btn btn-primary btn-sm" :disabled="savingEdit" @click="saveEdit">
          {{ savingEdit ? 'Сохраняем…' : 'Сохранить' }}
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

.head-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.modal-body .field + .field {
  margin-top: 16px;
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

.filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}

.search {
  flex: 1;
  min-width: 220px;
}

.filters .select-wrap {
  min-width: 180px;
}

.archive-toggle {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--dim);
  font-size: 12px;
  cursor: pointer;
  white-space: nowrap;
}

.archive-toggle input {
  width: 15px;
  height: 15px;
  accent-color: var(--gold);
}

.notice {
  font-size: 12.5px;
}

.table-panel {
  overflow: hidden;
}

.cell-index {
  width: 44px;
  color: var(--mute);
  font-family: var(--font-display);
  font-size: 11px;
  letter-spacing: 0.08em;
}

.fighter-cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.fighter-cell strong {
  color: var(--text);
  font-size: 13.5px;
  font-weight: 600;
}

.fighter-cell span {
  color: var(--mute);
  font-size: 11px;
}

.char-select {
  max-width: 210px;
  padding: 6px 8px;
  font-size: 12px;
}

.cell-date {
  color: var(--mute);
  font-size: 11.5px;
  white-space: nowrap;
}

.sort-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  letter-spacing: inherit;
  text-transform: inherit;
  cursor: pointer;
  transition: color 0.18s ease;
}

.sort-btn:hover {
  color: var(--gold);
}

.sort-btn span {
  color: var(--gold);
  font-size: 9px;
}

.row-actions {
  display: flex;
  align-items: center;
  gap: 6px;
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

.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
}

.page-info {
  color: var(--dim);
  font-size: 12px;
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
}
</style>
