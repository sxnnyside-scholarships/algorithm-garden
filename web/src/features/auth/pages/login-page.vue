<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import heroDark from '@/assets/login-hero-dark.webp';
import heroLight from '@/assets/login-hero-light.webp';
import { ApiClientError } from '@/shared/api/http-client';
import { useLocale } from '@/shared/i18n/use-locale';
import { useTheme } from '@/shared/theme/use-theme';
import FloralFiligree from '@/shared/ui/floral-filigree.vue';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import SxnnysideBadge from '@/shared/ui/sxnnyside-badge.vue';
import { useAuthStore } from '../stores/auth-store';

const router = useRouter();
const authStore = useAuthStore();
const { theme, toggleTheme } = useTheme();
const { t, toggleLocale } = useLocale();

const mode = ref<'login' | 'register'>('login');
const email = ref('');
const username = ref('');
const password = ref('');
const showPassword = ref(false);
const loading = ref(false);
const errorMessage = ref<string | null>(null);

const heroImage = computed(() => (theme.value === 'dark' ? heroDark : heroLight));

async function handleSubmit(): Promise<void> {
  errorMessage.value = null;
  loading.value = true;
  try {
    if (mode.value === 'login') {
      await authStore.login(email.value.trim(), password.value);
    } else {
      await authStore.register(email.value.trim(), username.value.trim(), password.value);
    }
    await router.push('/catalog');
  } catch (err) {
    if (err instanceof ApiClientError) {
      const detailValues = err.details
        ? Object.entries(err.details).map(([k, v]) => `${k}: ${v}`)
        : [];
      errorMessage.value =
        detailValues.length > 0 ? `${err.message} (${detailValues.join(', ')})` : err.message;
    } else {
      errorMessage.value = t.value.login.connectionError;
    }
  } finally {
    loading.value = false;
  }
}

function exploreAsGuest(): void {
  void router.push('/catalog');
}
</script>

<template>
  <main class="login-shell">
    <!-- 80% Weirdcore Solarpunk Julia Garden Hero -->
    <section class="login-hero" :aria-label="t.login.heroAria">
      <img
        :src="heroImage"
        :alt="t.login.heroAlt"
        class="login-hero__image"
        decoding="async"
        fetchpriority="high"
      />
      <div class="login-hero__scrim" />

      <div class="login-hero__overlay">
        <header class="login-hero__top">
          <div class="login-brand">
            <span class="login-brand__orb">
              <MingcuteIcon name="lotus-fill" :size="20" />
            </span>
            <div>
              <span class="login-brand__name">{{ t.common.brandName }}</span>
              <span class="login-brand__tag mono">{{ t.common.juliaTag }}</span>
            </div>
          </div>

          <div class="login-math-pills" aria-hidden="true">
            <span class="math-pill mono">zₙ₊₁ = zₙ² + c</span>
            <span class="math-pill mono">sort_algorithm!(arr)</span>
            <span class="math-pill mono">find_path(grid)</span>
          </div>
        </header>

        <div class="login-hero__bottom">
          <div class="login-hero__copy">
            <span class="garden-badge">
              <MingcuteIcon name="sparkles-line" :size="14" />
              {{ t.login.heroBadge }}
            </span>
            <h1>{{ t.login.heroHeadline }}</h1>
            <p>{{ t.login.heroCopy }}</p>
          </div>

        </div>
      </div>
    </section>

    <!-- 20% Botanical Auth Form Panel -->
    <section class="login-panel" :aria-label="t.login.panelAria">
      <FloralFiligree position="top-right" variant="blossom" />
      <FloralFiligree position="bottom-left" variant="vine" />

      <div class="login-panel__header">
        <button
          type="button"
          class="garden-btn garden-btn--ghost locale-toggle"
          :title="t.common.localeSwitchTitle"
          :aria-label="t.common.localeSwitchTitle"
          @click="toggleLocale"
        >
          <MingcuteIcon name="translate-2-line" :size="16" />
          <span class="mono">{{ t.common.localeCode }}</span>
        </button>

        <button
          type="button"
          class="garden-btn garden-btn--ghost theme-toggle"
          :title="theme === 'dark' ? t.common.lightModeTitle : t.common.darkModeTitle"
          :aria-label="theme === 'dark' ? t.common.lightModeTitle : t.common.darkModeTitle"
          @click="toggleTheme"
        >
          <MingcuteIcon :name="theme === 'dark' ? 'sun-line' : 'moon-line'" :size="17" />
          <span>{{ theme === 'dark' ? t.common.lightLabel : t.common.darkLabel }}</span>
        </button>
      </div>

      <div class="login-panel__body">
        <div class="login-panel__intro">
          <span class="floral-emblem" aria-hidden="true">
            <MingcuteIcon name="rose-line" :size="16" />
          </span>
          <h2>{{ mode === 'login' ? t.login.panelTitleLogin : t.login.panelTitleRegister }}</h2>
          <p>
            {{
              mode === 'login' ? t.login.panelSubtitleLogin : t.login.panelSubtitleRegister
            }}
          </p>
        </div>

        <div class="mode-tabs" role="tablist" :aria-label="t.login.authModeAria">
          <button
            type="button"
            role="tab"
            :aria-selected="mode === 'login'"
            class="mode-tab"
            :class="{ 'is-active': mode === 'login' }"
            @click="
              mode = 'login';
              errorMessage = null;
            "
          >
            {{ t.login.tabLogin }}
          </button>
          <button
            type="button"
            role="tab"
            :aria-selected="mode === 'register'"
            class="mode-tab"
            :class="{ 'is-active': mode === 'register' }"
            @click="
              mode = 'register';
              errorMessage = null;
            "
          >
            {{ t.login.tabRegister }}
          </button>
        </div>

        <div v-if="errorMessage" class="form-alert" role="alert">
          <MingcuteIcon name="alert-line" :size="16" />
          <span>{{ errorMessage }}</span>
        </div>

        <form class="login-form" @submit.prevent="handleSubmit">
          <label class="field">
            <span>{{ t.login.emailLabel }}</span>
            <input
              v-model="email"
              type="email"
              required
              autocomplete="email"
              :placeholder="t.login.emailPlaceholder"
              class="garden-input"
            />
          </label>

          <label v-if="mode === 'register'" class="field">
            <span>{{ t.login.usernameLabel }}</span>
            <input
              v-model="username"
              type="text"
              required
              minlength="3"
              maxlength="32"
              autocomplete="username"
              :placeholder="t.login.usernamePlaceholder"
              class="garden-input"
            />
          </label>

          <label class="field">
            <span>{{ t.login.passwordLabel }}</span>
            <div class="password-wrap">
              <input
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                required
                minlength="8"
                :autocomplete="mode === 'login' ? 'current-password' : 'new-password'"
                :placeholder="t.login.passwordPlaceholder"
                class="garden-input"
              />
              <button
                type="button"
                class="password-eye"
                :aria-label="showPassword ? t.login.hidePassword : t.login.showPassword"
                :aria-pressed="showPassword"
                @click="showPassword = !showPassword"
              >
                <MingcuteIcon :name="showPassword ? 'eye-close-line' : 'eye-line'" :size="16" />
              </button>
            </div>
          </label>

          <button
            type="submit"
            class="garden-btn garden-btn--primary submit-btn"
            :disabled="loading"
          >
            <MingcuteIcon :name="mode === 'login' ? 'leaf-fill' : 'sparkles-line'" :size="16" />
            <span>{{
              loading
                ? t.login.submitting
                : mode === 'login'
                  ? t.login.submitLogin
                  : t.login.submitRegister
            }}</span>
          </button>
        </form>

        <div class="login-divider">
          <span>{{ t.login.divider }}</span>
        </div>

        <button type="button" class="garden-btn guest-btn" @click="exploreAsGuest">
          <MingcuteIcon name="compass-line" :size="16" />
          <span>{{ t.login.exploreGuest }}</span>
        </button>
      </div>

      <footer class="login-panel__footer">
        <SxnnysideBadge compact />
      </footer>
    </section>
  </main>
</template>

<style scoped>
.login-shell {
  min-height: 100vh;
  display: grid;
  grid-template-columns: 1fr;
  background: var(--bg-canvas);
}

@media (min-width: 1024px) {
  .login-shell {
    grid-template-columns: 4fr 1fr;
  }
}

.login-hero {
  position: relative;
  min-height: 44vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

@media (min-width: 1024px) {
  .login-hero {
    min-height: 100vh;
  }
}

.login-hero__image {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: opacity var(--transition-smooth);
}

.login-hero__scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    180deg,
    rgba(10, 22, 17, 0.36) 0%,
    rgba(10, 22, 17, 0.14) 45%,
    rgba(10, 22, 17, 0.72) 100%
  );
}

.login-hero__overlay {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
  padding: 2rem 2.5rem;
  color: #f6faf6;
}

.login-hero__top {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.login-brand {
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.55rem 0.95rem;
  border-radius: var(--radius-pill);
  background: rgba(11, 24, 19, 0.54);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.login-brand__orb {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: linear-gradient(135deg, #39d399, #ff8270, #b794f4);
  color: #0b1411;
}

.login-brand__name {
  display: block;
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 1rem;
  line-height: 1.1;
}

.login-brand__tag {
  display: block;
  font-size: 0.7rem;
  opacity: 0.82;
}

.login-math-pills {
  display: none;
  gap: 0.5rem;
}

@media (min-width: 768px) {
  .login-math-pills {
    display: flex;
  }
}

.math-pill {
  font-size: 0.75rem;
  padding: 0.35rem 0.75rem;
  border-radius: var(--radius-pill);
  background: rgba(11, 24, 19, 0.48);
  border: 1px solid rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  color: #e6f7ee;
}

.login-hero__bottom {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1rem;
}

.login-hero__copy {
  max-width: 640px;
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  padding: 1.5rem 1.75rem;
  border-radius: var(--radius-lg);
  background: rgba(11, 24, 19, 0.5);
  border: 1px solid rgba(255, 255, 255, 0.16);
  backdrop-filter: blur(14px);
}

.login-hero__copy h1 {
  font-size: clamp(1.65rem, 3vw, 2.55rem);
  line-height: 1.15;
  color: #ffffff;
}

.login-hero__copy p {
  margin: 0;
  font-size: 0.98rem;
  color: rgba(235, 248, 240, 0.88);
}

.login-panel {
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 1.15rem 1.25rem 1.25rem;
  background:
    radial-gradient(circle at 95% 5%, var(--accent-bloom-soft), transparent 42%),
    var(--bg-surface);
  border-left: 1px solid var(--border-subtle);
}

.login-panel__header {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: flex-end;
  gap: 0.35rem;
}

.locale-toggle,
.theme-toggle {
  padding: 0.4rem 0.65rem;
  font-size: 0.78rem;
}

.login-panel__body {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  gap: 0.95rem;
  margin: auto 0;
  padding: 1rem 0;
}

.floral-emblem {
  display: inline-grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: var(--accent-bloom-soft);
  color: var(--accent-bloom);
  margin-bottom: 0.35rem;
}

.login-panel__intro h2 {
  font-size: 1.42rem;
}

.login-panel__intro p {
  margin: 0.25rem 0 0;
  font-size: 0.82rem;
  color: var(--text-secondary);
}

.mode-tabs {
  display: grid;
  grid-template-columns: 1fr 1fr;
  padding: 0.22rem;
  border-radius: var(--radius-pill);
  background: var(--bg-muted);
}

.mode-tab {
  border: 0;
  background: transparent;
  color: var(--text-secondary);
  padding: 0.42rem 0.5rem;
  border-radius: var(--radius-pill);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition:
    background var(--transition-fast),
    color var(--transition-fast);
}

.mode-tab.is-active {
  background: var(--bg-elevated);
  color: var(--text-primary);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.form-alert {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  padding: 0.65rem 0.75rem;
  border-radius: var(--radius-md);
  background: var(--status-danger-soft);
  color: var(--status-danger);
  font-size: 0.8rem;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.password-wrap {
  position: relative;
}

.password-wrap .garden-input {
  padding-right: 2.35rem;
}

.password-eye {
  position: absolute;
  right: 0.5rem;
  top: 50%;
  transform: translateY(-50%);
  border: 0;
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
  display: grid;
  place-items: center;
  padding: 0.25rem;
}

.submit-btn,
.guest-btn {
  width: 100%;
  padding: 0.65rem 1rem;
}

.login-divider {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  color: var(--text-muted);
  font-size: 0.75rem;
}

.login-divider::before,
.login-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--border-subtle);
}

.login-panel__footer {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: center;
  padding-top: 0.5rem;
}
</style>
