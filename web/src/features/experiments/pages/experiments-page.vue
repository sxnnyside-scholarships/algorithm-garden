<script setup lang="ts">
import { onMounted } from 'vue';
import GardenLayout from '@/app/layouts/garden-layout.vue';
import { useAuthStore } from '@/features/auth/stores/auth-store';
import { useLocale } from '@/shared/i18n/use-locale';
import FloralFiligree from '@/shared/ui/floral-filigree.vue';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import { useExperimentsStore } from '../stores/experiments-store';

const authStore = useAuthStore();
const experimentsStore = useExperimentsStore();
const { locale, t } = useLocale();

onMounted(() => {
  if (authStore.isAuthenticated) {
    void experimentsStore.fetchAll();
  }
});

async function removeExperiment(id: string): Promise<void> {
  await experimentsStore.deleteById(id);
}

function formatUpdatedAt(isoOrTimestamp: string): string {
  const parsed = new Date(isoOrTimestamp);
  if (Number.isNaN(parsed.getTime())) {
    return isoOrTimestamp;
  }
  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(parsed);
}
</script>

<template>
  <GardenLayout>
    <div class="experiments-wrap">
      <header class="experiments-header garden-card garden-card--bloomcore petal-card">
        <FloralFiligree position="top-right" variant="blossom" />
        <FloralFiligree position="bottom-left" variant="vine" />
        <div class="experiments-header__copy">
          <h1>{{ t.experiments.title }}</h1>
          <p>{{ t.experiments.subtitle }}</p>
        </div>
        <RouterLink to="/catalog" class="garden-btn garden-btn--primary">
          <MingcuteIcon name="add-line" :size="16" />
          <span>{{ t.experiments.newFromCatalog }}</span>
        </RouterLink>
      </header>

      <div v-if="experimentsStore.error" class="garden-card exp-error" role="alert">
        <MingcuteIcon name="alert-line" :size="18" />
        <span>{{ experimentsStore.error }}</span>
      </div>

      <div v-if="!authStore.isAuthenticated" class="garden-card empty-box">
        <MingcuteIcon name="lock-line" :size="28" />
        <h3>{{ t.experiments.authTitle }}</h3>
        <p>{{ t.experiments.authCopy }}</p>
        <RouterLink to="/login" class="garden-btn garden-btn--primary">
          {{ t.experiments.goToLogin }}
        </RouterLink>
      </div>

      <div v-else-if="experimentsStore.loading" class="empty-box">{{ t.experiments.loading }}</div>

      <div v-else-if="experimentsStore.items.length === 0 && !experimentsStore.error" class="garden-card empty-box">
        <MingcuteIcon name="lotus-line" :size="30" />
        <h3>{{ t.experiments.emptyTitle }}</h3>
        <p>{{ t.experiments.emptyCopy }}</p>
        <RouterLink to="/catalog" class="garden-btn garden-btn--primary">
          {{ t.experiments.exploreGardens }}
        </RouterLink>
      </div>

      <div v-else-if="experimentsStore.items.length > 0" class="exp-grid">
        <article
          v-for="exp in experimentsStore.items"
          :key="exp.id"
          class="garden-card garden-card--interactive exp-card"
        >
          <div class="exp-card__head">
            <span class="garden-badge">
              <MingcuteIcon name="flower-line" :size="12" />
              {{ exp.algorithm_slug }}
            </span>
            <button
              type="button"
              class="garden-btn garden-btn--ghost"
              :title="t.experiments.deleteTitle"
              :aria-label="`${t.experiments.deleteTitle}: ${exp.title}`"
              @click="removeExperiment(exp.id)"
            >
              <MingcuteIcon name="delete-2-line" :size="16" />
            </button>
          </div>
          <h3>{{ exp.title }}</h3>
          <small class="mono">
            {{ t.experiments.updatedAt }}:
            <time :datetime="exp.updated_at">{{ formatUpdatedAt(exp.updated_at) }}</time>
          </small>
          <RouterLink
            :to="{ path: `/workspace/${exp.algorithm_slug}`, query: { experiment: exp.id } }"
            class="garden-btn garden-btn--primary"
          >
            <MingcuteIcon name="folder-open-line" :size="15" />
            <span>{{ t.experiments.openWorkspace }}</span>
          </RouterLink>
        </article>
      </div>
    </div>
  </GardenLayout>
</template>

<style scoped>
.experiments-wrap {
  max-width: 1120px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.experiments-header {
  padding: 1.35rem 1.5rem;
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
}

.experiments-header__copy {
  position: relative;
  z-index: 1;
}

.experiments-header p {
  margin: 0.25rem 0 0;
  color: var(--text-secondary);
}

.exp-error {
  padding: 0.9rem 1.15rem;
  display: flex;
  align-items: center;
  gap: 0.65rem;
  color: var(--status-danger);
  border-color: color-mix(in srgb, var(--status-danger) 42%, var(--border-subtle));
  background: color-mix(in srgb, var(--status-danger) 10%, var(--bg-surface));
  font-weight: 500;
}

.empty-box {
  padding: 2.5rem 1.5rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 0.65rem;
  color: var(--text-secondary);
}

.exp-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.exp-card {
  padding: 1.15rem;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.exp-card__head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.exp-card small {
  font-size: 0.74rem;
  color: var(--text-muted);
}
</style>
