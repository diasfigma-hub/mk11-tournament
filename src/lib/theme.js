import { ref, onMounted } from 'vue'

const THEME_KEY = 'mk11.theme'
const isDark = ref(true)
let initialized = false

function applyTheme(dark) {
  document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light')
}

export function initTheme() {
  if (initialized) return
  initialized = true
  const saved = localStorage.getItem(THEME_KEY)
  isDark.value = saved !== 'light'
  applyTheme(isDark.value)
}

export function useTheme() {
  onMounted(initTheme)

  function toggleTheme() {
    isDark.value = !isDark.value
    localStorage.setItem(THEME_KEY, isDark.value ? 'dark' : 'light')
    applyTheme(isDark.value)
  }

  return { isDark, toggleTheme }
}
