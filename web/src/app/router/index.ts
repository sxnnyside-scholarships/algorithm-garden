import { createRouter, createWebHistory } from 'vue-router';

export type PageTitleKey = 'login' | 'catalog' | 'experiments' | 'workspace';

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/login' },
    {
      path: '/login',
      name: 'login',
      meta: { titleKey: 'login' satisfies PageTitleKey },
      component: () => import('@/features/auth/pages/login-page.vue'),
    },
    {
      path: '/catalog',
      name: 'catalog',
      meta: { titleKey: 'catalog' satisfies PageTitleKey },
      component: () => import('@/features/catalog/pages/catalog-page.vue'),
    },
    {
      path: '/experiments',
      name: 'experiments',
      meta: { titleKey: 'experiments' satisfies PageTitleKey },
      component: () => import('@/features/experiments/pages/experiments-page.vue'),
    },
    {
      path: '/workspace/:slug',
      name: 'workspace',
      meta: { titleKey: 'workspace' satisfies PageTitleKey },
      component: () => import('@/features/workspace/pages/workspace-page.vue'),
    },
    { path: '/:pathMatch(.*)*', redirect: '/catalog' },
  ],
});
