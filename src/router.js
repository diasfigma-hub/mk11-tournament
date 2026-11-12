import { createRouter, createWebHistory } from 'vue-router'
import { authApi } from '@/api'
import HomeView from './Pages/HomeView.vue'
import Register from './Pages/Register.vue'
import Tournaments from './Pages/Tournaments.vue'
import TournamentDetail from './Pages/TournamentDetail.vue'
import AdminLogin from './Pages/AdminLogin.vue'
import AdminLayout from './Pages/admin/AdminLayout.vue'
import AdminParticipants from './Pages/admin/AdminParticipants.vue'
import AdminTournaments from './Pages/admin/AdminTournaments.vue'
import AdminTournamentDetail from './Pages/admin/AdminTournamentDetail.vue'

const routes = [
  {
    path: '/',
    name: 'home',
    component: HomeView,
    meta: { title: 'Турниры по Mortal Kombat 11' },
  },
  {
    path: '/register',
    name: 'register',
    component: Register,
    meta: { title: 'Регистрация бойца' },
  },
  {
    path: '/tournaments',
    name: 'tournaments',
    component: Tournaments,
    meta: { title: 'Турниры' },
  },
  {
    path: '/tournaments/:id',
    name: 'tournament',
    component: TournamentDetail,
    meta: { title: 'Турнир' },
  },
  {
    path: '/admin/login',
    name: 'admin-login',
    component: AdminLogin,
    meta: { title: 'Вход организатора' },
  },
  {
    path: '/admin',
    component: AdminLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: { name: 'admin-participants' },
      },
      {
        path: 'participants',
        name: 'admin-participants',
        component: AdminParticipants,
        meta: { title: 'Бойцы' },
      },
      {
        path: 'tournaments',
        name: 'admin-tournaments',
        component: AdminTournaments,
        meta: { title: 'Турниры' },
      },
      {
        path: 'tournaments/:id',
        name: 'admin-tournament',
        component: AdminTournamentDetail,
        meta: { title: 'Турнир' },
      },
    ],
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/',
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior() {
    return { top: 0 }
  },
})

// Гард: защита маршрутов администратора сессией Supabase Auth.
router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return
  const session = await authApi.getSession()
  if (!session) return { name: 'admin-login' }

  const admin = await authApi.isAdmin()
  if (!admin) {
    await authApi.logout().catch(() => {})
    return { name: 'admin-login' }
  }
})

router.afterEach((to) => {
  document.title = to.meta.title
    ? `${to.meta.title} — MK Arena`
    : 'MK Arena — турниры по Mortal Kombat 11'
})

export default router
