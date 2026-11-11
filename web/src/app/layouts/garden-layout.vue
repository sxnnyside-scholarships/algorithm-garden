<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/features/auth/stores/auth-store';
import { useLocale } from '@/shared/i18n/use-locale';
import { useTheme } from '@/shared/theme/use-theme';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import SxnnysideBadge from '@/shared/ui/sxnnyside-badge.vue';

const router = useRouter();
const authStore = useAuthStore();
const { theme, toggleTheme } = useTheme();
const { t, toggleLocale } = useLocale();

async function handleLogout(): Promise<void> {
  await authStore.logout();
  await router.push('/login');
}
</script>

<template>
  <div class="shell">
    <div class="floral-rim" aria-hidden="true" />
    <header class="topbar">
      <div class="topbar__left">
        <RouterLink to="/catalog" class="brand">
          <span class="brand__dot">
            <MingcuteIcon name="lotus-fill" :size="18" />
          </span>
          <span class="brand__text">{{ t.common.brandName }}</span>
        </RouterLink>

        <nav class="nav-links" :aria-label="t.common.gardensNav">
          <RouterLink to="/catalog" class="nav-link" active-class="is-active">
            <MingcuteIcon name="compass-line" :size="16" />
            <span>{{ t.common.gardensNav }}</span>
          </RouterLink>
          <RouterLink to="/experiments" class="nav-link" active-class="is-active">
            <MingcuteIcon name="flask-line" :size="16" />
            <span>{{ t.common.experimentsNav }}</span>
          </RouterLink>
        </nav>
      </div>

      <div class="topbar__right">
        <button
          type="button"
          class="garden-btn garden-btn--ghost locale-btn"
          :title="t.common.localeSwitchTitle"
          :aria-label="t.common.localeSwitchTitle"
          @click="toggleLocale"
        >
          <MingcuteIcon name="translate-2-line" :size="16" />
          <span class="mono">{{ t.common.localeCode }}</span>
        </button>

        <button
          type="button"
          class="garden-btn garden-btn--ghost"
          :title="theme === 'dark' ? t.common.lightModeTitle : t.common.darkModeTitle"
          :aria-label="theme === 'dark' ? t.common.lightModeTitle : t.common.darkModeTitle"
          @click="toggleTheme"
        >
          <MingcuteIcon :name="theme === 'dark' ? 'sun-line' : 'moon-line'" :size="17" />
        </button>

        <template v-if="authStore.isAuthenticated && authStore.user">
          <span class="user-pill">
            <MingcuteIcon name="user-3-line" :size="15" />
            <span>{{ authStore.user.username }}</span>
          </span>
          <button type="button" class="garden-btn" @click="handleLogout">
            <MingcuteIcon name="exit-line" :size="15" />
            <span>{{ t.common.logout }}</span>
          </button>
        </template>
        <RouterLink v-else to="/login" class="garden-btn garden-btn--primary">
          <MingcuteIcon name="leaf-fill" :size="15" />
          <span>{{ t.common.login }}</span>
        </RouterLink>
      </div>
    </header>

    <main class="shell__main">
      <slot />
    </main>

    <footer class="garden-footer">
      <div class="floral-divider" aria-hidden="true">
        <MingcuteIcon name="leaf-line" :size="13" />
        <MingcuteIcon name="lotus-fill" :size="15" />
        <MingcuteIcon name="rose-line" :size="13" />
      </div>
      <div class="garden-footer__row">
        <span class="garden-footer__meta mono">
          <MingcuteIcon name="flower-line" :size="14" />
          {{ t.common.juliaTag }}
        </span>
        <SxnnysideBadge />
      </div>
    </footer>
  </div>
</template>

<style scoped>
.shell {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background:
    radial-gradient(circle at 8% 0%, var(--accent-primary-soft), transparent 28%),
    radial-gradient(circle at 92% 100%, var(--accent-bloom-soft), transparent 30%),
    var(--bg-canvas);
}

.floral-rim {
  height: 3px;
  background: linear-gradient(
    90deg,
    var(--accent-primary),
    var(--accent-sun),
    var(--accent-bloom),
    var(--accent-orchid),
    var(--accent-primary)
  );
}

.topbar {
  position: sticky;
  top: 0;
  z-index: 20;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.7rem 1.4rem;
  background: var(--bg-glass);
  backdrop-filter: blur(14px);
  border-bottom: 1px solid var(--border-subtle);
}

.topbar__left,
.topbar__right {
  display: flex;
  align-items: center;
  gap: 0.65rem;
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: 0.55rem;
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 1.08rem;
}

.brand__dot {
  display: grid;
  place-items: center;
  width: 31px;
  height: 31px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--accent-primary), var(--accent-bloom));
  color: #ffffff;
  box-shadow: 0 3px 12px color-mix(in srgb, var(--accent-bloom) 28%, transparent);
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  margin-left: 0.5rem;
}

.nav-link {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.8rem;
  border-radius: var(--radius-pill);
  font-size: 0.86rem;
  font-weight: 600;
  color: var(--text-secondary);
  transition:
    background var(--transition-fast),
    color var(--transition-fast);
}

.nav-link:hover {
  background: var(--bg-muted);
  color: var(--text-primary);
}

.nav-link.is-active {
  background: var(--accent-primary-soft);
  color: var(--accent-primary);
}

.locale-btn {
  font-size: 0.78rem;
  padding: 0.42rem 0.7rem;
}

.user-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.38rem 0.75rem;
  border-radius: var(--radius-pill);
  background: var(--bg-muted);
  font-size: 0.82rem;
  font-weight: 600;
}

.shell__main {
  flex: 1;
  padding: 1.25rem 1.4rem 1.5rem;
}

.garden-footer {
  padding: 0.5rem 1.4rem 1.35rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.garden-footer__row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.garden-footer__meta {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.75rem;
  color: var(--text-muted);
}
</style>
