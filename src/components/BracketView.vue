<script setup>
import { isPlayable, roundLabel } from '@/lib/bracket'

const props = defineProps({
  rounds: { type: Array, required: true },
  thirdPlace: { type: Object, default: null },
  editable: { type: Boolean, default: false },
})

defineEmits(['score', 'score-third'])

function canOpen(match) {
  if (!props.editable) return false
  return isPlayable(match) || (Boolean(match?.winnerId) && !match.bye)
}

function statusLabel(match) {
  if (match?.bye) return 'без игры'
  if (match?.winnerId) return props.editable ? 'завершён · изменить счёт' : 'завершён'
  if (match?.p1 && match?.p2) return props.editable ? 'внести счёт' : 'готов к игре'
  if (match?.p1 || match?.p2) return 'ожидает соперника'
  return 'не заполнен'
}

function name(player, match) {
  if (player) return player.nickname || player.fullName || 'Боец'
  return match?.bye ? 'Проход' : 'Ожидание'
}

function fullName(player) {
  return player?.fullName || ''
}

function score(match, side) {
  if (!match?.winnerId) return ''
  if (match.bye) return '—'
  return side === 'p1' ? match.score1 : match.score2
}

function sideClass(match, player) {
  if (!match?.winnerId || !player) return ''
  return match.winnerId === player.id ? 'is-winner' : 'is-loser'
}

function sideTitle(player) {
  if (!player) return ''
  return [player.mainCharacter, player.fullName].filter(Boolean).join(' · ')
}
</script>

<template>
  <div class="bracket-wrap">
    <div class="bracket">
      <section
        v-for="(round, roundIndex) in rounds"
        :key="roundIndex"
        class="round"
        :class="{ 'is-final': roundIndex === rounds.length - 1 }"
      >
        <header class="round-head">
          <span>{{ roundLabel(rounds, roundIndex) }}</span>
          <span class="round-bo">Bo{{ round.matches[0]?.bo || 3 }}</span>
        </header>

        <div class="round-matches">
          <button
            v-for="(match, matchIndex) in round.matches"
            :key="matchIndex"
            type="button"
            class="match"
            :class="{
              'is-done': !!match.winnerId,
              'is-ready': isPlayable(match),
              'is-idle': !match.p1 && !match.p2,
            }"
            :disabled="!canOpen(match)"
            :title="canOpen(match) ? (match.winnerId ? 'Изменить счёт' : 'Внести счёт') : undefined"
            @click="canOpen(match) && $emit('score', match, roundIndex, matchIndex)"
          >
            <span class="match-side" :class="sideClass(match, match.p1)" :title="sideTitle(match.p1)">
              <span class="side-name">
                <span class="side-nick">{{ name(match.p1, match) }}</span>
                <span v-if="fullName(match.p1)" class="side-fullname">{{ fullName(match.p1) }}</span>
              </span>
              <span class="side-score">{{ score(match, 'p1') }}</span>
            </span>
            <span class="match-side" :class="sideClass(match, match.p2)" :title="sideTitle(match.p2)">
              <span class="side-name">
                <span class="side-nick">{{ name(match.p2, match) }}</span>
                <span v-if="fullName(match.p2)" class="side-fullname">{{ fullName(match.p2) }}</span>
              </span>
              <span class="side-score">{{ score(match, 'p2') }}</span>
            </span>
            <span
              class="match-state"
              :class="{
                'is-ready': !match.winnerId && canOpen(match),
                'is-done': Boolean(match.winnerId) && !match.bye,
              }"
            >
              {{ statusLabel(match) }}
            </span>
          </button>
        </div>
      </section>
    </div>

    <section v-if="thirdPlace" class="third-place">
      <header class="round-head third-head">
        <span>Матч за 3-е место</span>
        <span class="round-bo">Bo{{ thirdPlace.bo || 3 }}</span>
      </header>

      <button
        type="button"
        class="match third-match"
        :class="{
          'is-done': !!thirdPlace.winnerId,
          'is-ready': isPlayable(thirdPlace),
          'is-idle': !thirdPlace.p1 && !thirdPlace.p2,
        }"
        :disabled="!canOpen(thirdPlace)"
        :title="canOpen(thirdPlace) ? (thirdPlace.winnerId ? 'Изменить счёт' : 'Внести счёт') : undefined"
        @click="canOpen(thirdPlace) && $emit('score-third')"
      >
        <span class="match-side" :class="sideClass(thirdPlace, thirdPlace.p1)" :title="sideTitle(thirdPlace.p1)">
          <span class="side-name">
            <span class="side-nick">{{ name(thirdPlace.p1, thirdPlace) }}</span>
            <span v-if="fullName(thirdPlace.p1)" class="side-fullname">{{ fullName(thirdPlace.p1) }}</span>
          </span>
          <span class="side-score">{{ score(thirdPlace, 'p1') }}</span>
        </span>
        <span class="match-side" :class="sideClass(thirdPlace, thirdPlace.p2)" :title="sideTitle(thirdPlace.p2)">
          <span class="side-name">
            <span class="side-nick">{{ name(thirdPlace.p2, thirdPlace) }}</span>
            <span v-if="fullName(thirdPlace.p2)" class="side-fullname">{{ fullName(thirdPlace.p2) }}</span>
          </span>
          <span class="side-score">{{ score(thirdPlace, 'p2') }}</span>
        </span>
        <span
          class="match-state"
          :class="{
            'is-ready': !thirdPlace.winnerId && canOpen(thirdPlace),
            'is-done': Boolean(thirdPlace.winnerId),
          }"
        >
          {{ statusLabel(thirdPlace) }}
        </span>
      </button>
    </section>
  </div>
</template>

<style scoped>
.bracket {
  display: flex;
  gap: 16px;
  overflow-x: auto;
  padding-bottom: 10px;
}

.round {
  display: flex;
  flex-direction: column;
  flex: 1 0 228px;
  min-width: 228px;
}

.round-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 14px;
  padding-bottom: 9px;
  border-bottom: 1px solid var(--line);
  color: var(--mute);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

.round.is-final .round-head {
  border-bottom-color: var(--gold);
  color: var(--gold);
}

.round-bo {
  color: var(--mute);
  letter-spacing: 0.08em;
}

.round-matches {
  display: flex;
  flex: 1;
  flex-direction: column;
  justify-content: space-around;
  gap: 12px;
}

.match {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 2px;
  width: 100%;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-left: 2px solid var(--line-2);
  border-radius: 2px;
  background: var(--panel);
  color: var(--text);
  text-align: left;
  cursor: default;
  transition: border-color 0.18s ease, background-color 0.18s ease;
}

.match.is-ready {
  border-left-color: var(--gold);
  cursor: pointer;
}

.match.is-ready:hover {
  border-color: var(--gold);
  background: var(--panel-2);
}

.match.is-done {
  border-left-color: var(--win);
}

.match.is-idle {
  opacity: 0.55;
}

.match-side {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
  padding: 3px 0;
  font-size: 13px;
  line-height: 1.4;
}

.side-name {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}

.side-nick {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.side-fullname {
  overflow: hidden;
  color: var(--mute);
  font-size: 10px;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.side-score {
  flex-shrink: 0;
  font-family: var(--font-display);
  font-size: 15px;
  font-weight: 600;
  color: var(--mute);
}

.match-side.is-winner .side-nick {
  color: var(--text);
  font-weight: 600;
}

.match-side.is-winner .side-score {
  color: var(--gold);
}

.match-side.is-loser .side-nick,
.match-side.is-loser .side-score,
.match-side.is-loser .side-fullname {
  color: var(--mute);
}

.match-state {
  margin-top: 4px;
  color: var(--mute);
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.match-state.is-ready {
  color: var(--gold);
}

.match-state.is-done {
  color: var(--win);
}

.third-place {
  max-width: 300px;
  margin-top: 20px;
}

.third-head {
  border-bottom-color: var(--line-2);
  color: var(--gold);
}

@media (max-width: 640px) {
  .round {
    flex-basis: 190px;
    min-width: 190px;
  }

  .match-side {
    font-size: 12px;
  }

  .third-place {
    max-width: none;
  }
}
</style>
