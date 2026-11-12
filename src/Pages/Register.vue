<script setup>
import { onMounted, reactive, ref } from 'vue'
import SiteHeader from '@/components/SiteHeader.vue'
import SiteFooter from '@/components/SiteFooter.vue'
import { participantsApi, settingsApi } from '@/api'
import { ROSTER, isAllowedCharacter } from '@/lib/constants'

const form = reactive({
  nickname: '',
  fullName: '',
  mainCharacter: '',
  contact: '',
  acceptedRules: false,
})

const errors = reactive({})
const loading = ref(false)
const fightersCount = ref(0)
const registered = ref('')
const submitError = ref('')
const registrationClosed = ref(false)
const checkingRegistration = ref(true)

onMounted(async () => {
  const [count, closed] = await Promise.allSettled([
    participantsApi.count(),
    settingsApi.getRegistrationClosed(),
  ])
  if (count.status === 'fulfilled') fightersCount.value = count.value
  if (closed.status === 'fulfilled') registrationClosed.value = closed.value
  checkingRegistration.value = false
})

const roster = ROSTER

function clearError(field) {
  if (errors[field]) delete errors[field]
}

function validate() {
  Object.keys(errors).forEach((key) => delete errors[key])

  const nickname = form.nickname.trim()
  if (!nickname) errors.nickname = 'Придумайте игровой ник'
  else if (nickname.length < 2 || nickname.length > 20) errors.nickname = 'Ник от 2 до 20 символов'
  else if (!/^[\w\u0400-\u04FF .-]+$/.test(nickname)) errors.nickname = 'Только буквы, цифры, пробел, точка, дефис'

  const fullName = form.fullName.trim()
  if (!fullName) errors.fullName = 'Укажите ФИО'
  else if (fullName.length < 2) errors.fullName = 'ФИО слишком короткое'

  if (!form.mainCharacter) errors.mainCharacter = 'Выберите основного персонажа'
  else if (!isAllowedCharacter(form.mainCharacter))
    errors.mainCharacter = 'Этот персонаж недоступен. Выберите бойца из базового состава.'

  const contact = form.contact.trim()
  if (contact && contact.length < 3) errors.contact = 'Контакт слишком короткий'

  if (!form.acceptedRules) errors.acceptedRules = 'Нужно принять регламент'

  return Object.keys(errors).length === 0
}

async function handleSubmit() {
  submitError.value = ''
  if (!validate()) return

  loading.value = true
  try {
    await participantsApi.register({
      nickname: form.nickname.trim(),
      fullName: form.fullName.trim(),
      mainCharacter: form.mainCharacter,
      contact: form.contact.trim(),
    })
    registered.value = form.nickname.trim()
    resetForm()
    fightersCount.value += 1
  } catch (e) {
    if (e?.code === '23505') {
      errors.nickname = 'Этот ник уже зарегистрирован'
    } else if (e?.code === '42501') {
      submitError.value = 'Регистрация сейчас закрыта. Попробуйте позже.'
    } else {
      submitError.value =
        e?.message || 'Не удалось отправить заявку. Проверьте соединение и попробуйте снова.'
    }
  } finally {
    loading.value = false
  }
}

function resetForm() {
  Object.assign(form, {
    nickname: '',
    fullName: '',
    mainCharacter: '',
    contact: '',
    acceptedRules: false,
  })
  Object.keys(errors).forEach((key) => delete errors[key])
}
</script>

<template>
  <div class="page">
    <SiteHeader />

    <main class="container register-layout">
      <section class="intro">
        <span class="eyebrow">Заявка бойца</span>
        <h1>Выход на арену</h1>
        <p>
          Заполните профиль — организатор увидит его в общем лобби и включит в состав
          ближайшего турнира. Ник будет отображаться в сетке.
        </p>

        <ul class="intro-list">
          <li>
            <strong>{{ fightersCount }}</strong>
            <span>бойцов уже в лобби</span>
          </li>
          <li>
            <strong>{{ roster.length }}</strong>
            <span>персонажей на выбор</span>
          </li>
          <li>
            <strong>Bo3</strong>
            <span>формат матчей</span>
          </li>
        </ul>

        <div class="intro-note">
          <span class="note-mark">!</span>
          <p>
            Заявка активируется сразу. Организатор может снять бойца с турнира
            за нарушение регламента.
          </p>
        </div>
      </section>

      <section class="form-column">
        <div v-if="checkingRegistration" class="panel empty-state">
          <span class="spinner" />
          <p>Проверяем регистрацию…</p>
        </div>

        <div v-else-if="registrationClosed" class="panel success-card">
          <span class="success-mark">!</span>
          <h2>Регистрация закрыта</h2>
          <p>
            Организатор остановил приём заявок в лобби. Следите за объявлениями
            о следующем турнире.
          </p>
        </div>

        <div v-else-if="registered" class="panel success-card">
          <span class="success-mark">✓</span>
          <h2>Боец зарегистрирован</h2>
          <p>
            <strong>{{ registered }}</strong> добавлен в лобби. Следите за расписанием —
            администратор объявит состав турнира.
          </p>
          <div class="success-actions">
            <RouterLink to="/tournaments" class="btn btn-primary btn-sm">Смотреть турниры</RouterLink>
            <button type="button" class="btn btn-ghost btn-sm" @click="registered = ''">
              Добавить ещё бойца
            </button>
          </div>
        </div>

        <form v-else class="panel form-panel" novalidate @submit.prevent="handleSubmit">
          <div class="panel-head">
            <h2>Профиль бойца</h2>
            <span class="badge badge-gold">Mortal Kombat 11</span>
          </div>

          <div class="panel-body">
            <div class="field">
              <label class="label" for="nickname">Игровой ник <span class="required">*</span></label>
              <input
                id="nickname"
                v-model="form.nickname"
                class="input"
                :class="{ 'is-error': errors.nickname }"
                type="text"
                maxlength="20"
                placeholder="Scorpion_Main"
                autocomplete="off"
                @input="clearError('nickname')"
              />
              <p v-if="errors.nickname" class="field-error">{{ errors.nickname }}</p>
              <p v-else class="hint">Латиница или кириллица, до 20 символов.</p>
            </div>

            <div class="field">
              <label class="label" for="fullName">ФИО <span class="required">*</span></label>
              <input
                id="fullName"
                v-model="form.fullName"
                class="input"
                :class="{ 'is-error': errors.fullName }"
                type="text"
                placeholder="Иванов Иван"
                autocomplete="name"
                @input="clearError('fullName')"
              />
              <p v-if="errors.fullName" class="field-error">{{ errors.fullName }}</p>
            </div>

            <div class="field">
              <label class="label" for="mainCharacter">Основной персонаж <span class="required">*</span></label>
              <div class="select-wrap">
                <select
                  id="mainCharacter"
                  v-model="form.mainCharacter"
                  class="select"
                  :class="{ 'is-error': errors.mainCharacter }"
                  @change="clearError('mainCharacter')"
                >
                  <option value="" disabled>Выберите бойца</option>
                  <option v-for="character in roster" :key="character" :value="character">
                    {{ character }}
                  </option>
                </select>
              </div>
              <p v-if="errors.mainCharacter" class="field-error">{{ errors.mainCharacter }}</p>
            </div>

            <div class="field">
              <label class="label" for="contact">Контакт</label>
              <input
                id="contact"
                v-model="form.contact"
                class="input"
                :class="{ 'is-error': errors.contact }"
                type="text"
                placeholder="@telegram или Discord: nickname"
                autocomplete="off"
                @input="clearError('contact')"
              />
              <p v-if="errors.contact" class="field-error">{{ errors.contact }}</p>
              <p v-else class="hint">Необязательно. Судья свяжется с вами для подтверждения матча.</p>
            </div>

            <label class="checkbox-field">
              <input
                v-model="form.acceptedRules"
                type="checkbox"
                @change="clearError('acceptedRules')"
              />
              <span>
                Принимаю регламент турнира: Bo3, турнирные вариации, уважение к сопернику.
              </span>
            </label>
            <p v-if="errors.acceptedRules" class="field-error">{{ errors.acceptedRules }}</p>

            <div v-if="submitError" class="alert alert-error">{{ submitError }}</div>

            <button type="submit" class="btn btn-primary btn-block" :disabled="loading">
              <span v-if="loading" class="spinner" />
              <span v-else>Отправить заявку</span>
            </button>
          </div>
        </form>
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

.register-layout {
  display: grid;
  gap: clamp(28px, 5vw, 64px);
  grid-template-columns: minmax(0, 0.85fr) minmax(0, 1.15fr);
  align-items: start;
  padding-top: clamp(36px, 6vw, 64px);
  padding-bottom: 48px;
}

/* ── Intro ── */

.intro {
  position: sticky;
  top: 100px;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 16px;
}

.intro h1 {
  font-size: clamp(2.2rem, 4.4vw, 3.2rem);
}

.intro > p {
  max-width: 380px;
  color: var(--dim);
  font-size: 14px;
  line-height: 1.75;
}

.intro-list {
  display: flex;
  flex-wrap: wrap;
  gap: 26px;
  margin: 10px 0 0;
  padding: 18px 0;
  border-top: 1px solid var(--line);
  border-bottom: 1px solid var(--line);
  list-style: none;
}

.intro-list li {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.intro-list strong {
  font-family: var(--font-display);
  font-size: 1.6rem;
  font-weight: 600;
  line-height: 1;
  color: var(--gold);
}

.intro-list span {
  color: var(--mute);
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.intro-note {
  display: flex;
  gap: 11px;
  padding: 14px 16px;
  border: 1px solid var(--line);
  border-left: 2px solid var(--gold);
  background: var(--panel);
}

.note-mark {
  color: var(--gold);
  font-family: var(--font-display);
  font-size: 15px;
  font-weight: 700;
  line-height: 1.4;
}

.intro-note p {
  color: var(--mute);
  font-size: 12px;
  line-height: 1.6;
}

/* ── Form ── */

.form-panel {
  overflow: hidden;
}

.checkbox-field {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-top: 22px;
  color: var(--dim);
  font-size: 12.5px;
  line-height: 1.6;
  cursor: pointer;
}

.checkbox-field input {
  width: 16px;
  height: 16px;
  margin-top: 2px;
  accent-color: var(--gold);
  flex-shrink: 0;
}

.form-panel .btn[type='submit'] {
  margin-top: 20px;
}

.form-panel .alert {
  margin-top: 18px;
}

/* ── Success ── */

.success-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 12px;
  padding: clamp(28px, 5vw, 44px);
  border-color: var(--win);
  background: linear-gradient(160deg, var(--win-soft), var(--panel) 60%);
}

.success-mark {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border: 1px solid var(--win);
  border-radius: 50%;
  color: var(--win);
  font-size: 20px;
}

.success-card h2 {
  font-size: 1.5rem;
}

.success-card p {
  color: var(--dim);
  font-size: 14px;
  line-height: 1.7;
}

.success-card strong {
  color: var(--gold);
}

.success-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 8px;
}

@media (max-width: 900px) {
  .register-layout {
    grid-template-columns: minmax(0, 1fr);
  }

  .intro {
    position: static;
  }
}

@media (max-width: 560px) {
  .register-layout {
    padding-bottom: 32px;
  }
}
</style>
