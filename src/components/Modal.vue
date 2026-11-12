<script setup>
import { onBeforeUnmount, onMounted } from 'vue'

defineProps({
  modelValue: { type: Boolean, default: false },
  title: { type: String, default: '' },
  wide: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue'])

function close() {
  emit('update:modelValue', false)
}

function onKey(event) {
  if (event.key === 'Escape') close()
}

onMounted(() => document.addEventListener('keydown', onKey))
onBeforeUnmount(() => document.removeEventListener('keydown', onKey))
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue" class="modal-backdrop" @click.self="close">
      <div class="modal" :class="{ 'modal-wide': wide }" role="dialog" aria-modal="true">
        <div class="modal-head">
          <h3>{{ title }}</h3>
          <button type="button" class="modal-close" aria-label="Закрыть" @click="close">✕</button>
        </div>
        <div class="modal-body">
          <slot />
        </div>
        <div v-if="$slots.footer" class="modal-foot">
          <slot name="footer" />
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.modal-close {
  width: 30px;
  height: 30px;
  border: 1px solid var(--line-2);
  border-radius: 2px;
  background: transparent;
  color: var(--mute);
  font-size: 12px;
  cursor: pointer;
  transition: color 0.18s ease, border-color 0.18s ease;
}

.modal-close:hover {
  border-color: var(--blood);
  color: var(--blood-2);
}
</style>
