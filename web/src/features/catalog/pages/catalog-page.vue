<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import GardenLayout from '@/app/layouts/garden-layout.vue';
import { localizeAlgorithm, localizeGarden } from '@/shared/i18n/catalog-i18n';
import { useLocale } from '@/shared/i18n/use-locale';
import FloralFiligree from '@/shared/ui/floral-filigree.vue';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import { useCatalogStore } from '../stores/catalog-store';
import type { GardenSlug } from '../types/catalog';

const catalogStore = useCatalogStore();
const { locale, t } = useLocale();
const selectedGarden = ref<'all' | GardenSlug>('all');

const GARDEN_ICON: Record<GardenSlug, string> = {
  sorting: 'chart-bar-line',
  pathfinding: 'route-line',
  cellular: 'dot-grid-line',
  graph: 'chart-network-line',
  fractal: 'flower-5-line',
  evolution: 'dna-line',
};

const GARDEN_CARD_ICON: Record<GardenSlug, string> = {
  sorting: 'cherry-line',
  pathfinding: 'rose-line',
  cellular: 'flower-2-line',
  graph: 'chart-network-line',
  fractal: 'flower-5-line',
  evolution: 'dna-line',
};

const GARDEN_BADGE: Record<GardenSlug, string> = {
  sorting: 'garden-badge--bloom',
  pathfinding: 'garden-badge--orchid',
  cellular: '',
  graph: 'garden-badge--sun',
  fractal: 'garden-badge--orchid',
  evolution: 'garden-badge--bloom',
};

onMounted(() => {
  void catalogStore.fetchCatalog();
});

const localizedGardens = computed(() =>
  catalogStore.gardens.map((g) => localizeGarden(g, locale.value)),
);

const filteredAlgorithms = computed(() => {
  const list =
    selectedGarden.value === 'all'
      ? catalogStore.algorithms
      : catalogStore.algorithms.filter((a) => a.garden === selectedGarden.value);
  return list.map((a) => localizeAlgorithm(a, locale.value));
});
</script>

<template>
  <GardenLayout>
    <div class="catalog-wrap">
      <section class="catalog-hero garden-card garden-card--bloomcore petal-card">
        <FloralFiligree position="top-right" variant="blossom" />
        <FloralFiligree position="bottom-left" variant="vine" />
        <div class="catalog-hero__intro">
          <span class="garden-badge">
            <MingcuteIcon name="lotus-line" :size="14" />
            {{ t.catalog.heroBadge }}
          </span>
          <h1>{{ t.catalog.heroTitle }}</h1>
          <p>{{ t.catalog.heroCopy }}</p>
        </div>

        <div class="garden-cards">
          <button
            v-for="garden in localizedGardens"
            :key="garden.slug"
            type="button"
            class="garden-filter-card"
            :class="{ 'is-selected': selectedGarden === garden.slug }"
            :aria-pressed="selectedGarden === garden.slug"
            @click="selectedGarden = selectedGarden === garden.slug ? 'all' : garden.slug"
          >
            <div class="garden-filter-card__top">
              <MingcuteIcon :name="GARDEN_ICON[garden.slug]" :size="20" />
              <span class="garden-badge garden-badge--sun">
                {{ garden.algorithms_count }} {{ t.catalog.algorithmsUnit }}
              </span>
            </div>
            <strong>{{ garden.name }}</strong>
            <small>{{ garden.description }}</small>
          </button>
        </div>
      </section>

      <div v-if="catalogStore.loading" class="status-msg" role="status">{{ t.catalog.loading }}</div>
      <div v-else-if="catalogStore.error" class="status-msg is-error" role="alert">
        {{ catalogStore.error }}
      </div>

      <template v-else>
        <div v-if="selectedGarden !== 'all'" class="catalog-filter-status">
          <button type="button" class="garden-btn garden-btn--ghost" @click="selectedGarden = 'all'">
            <MingcuteIcon name="close-line" :size="15" />
            <span>{{ t.catalog.allGardens }}</span>
          </button>
        </div>

        <section class="algo-grid">
          <RouterLink
            v-for="algo in filteredAlgorithms"
            :key="algo.slug"
            :to="`/workspace/${algo.slug}`"
            class="algo-card garden-card garden-card--interactive"
          >
            <div class="algo-card__head">
              <span class="garden-badge" :class="GARDEN_BADGE[algo.garden]">
                <MingcuteIcon :name="GARDEN_CARD_ICON[algo.garden]" :size="13" />
                {{ t.catalog.gardens[algo.garden] }}
              </span>
              <span class="difficulty mono">
                {{ t.catalog.difficulty[algo.difficulty] ?? algo.difficulty }}
              </span>
            </div>

            <h3>{{ algo.name }}</h3>
            <p>{{ algo.summary }}</p>

            <span class="algo-card__cta">
              {{ t.catalog.openWorkspace }}
              <MingcuteIcon name="arrow-right-line" :size="16" />
            </span>
          </RouterLink>
        </section>
      </template>
    </div>
  </GardenLayout>
</template>

<style scoped>
.catalog-wrap {
  max-width: 1280px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.catalog-hero {
  padding: 1.65rem;
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.25rem;
}

@media (min-width: 960px) {
  .catalog-hero {
    grid-template-columns: 1.1fr 1.4fr;
    align-items: center;
  }
}

.catalog-hero__intro,
.garden-cards {
  position: relative;
  z-index: 1;
}

.catalog-hero h1 {
  margin-top: 0.6rem;
  font-size: clamp(1.6rem, 2.5vw, 2.2rem);
}

.catalog-hero p {
  margin: 0.5rem 0 0;
  color: var(--text-secondary);
}

.garden-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 0.85rem;
}

.garden-filter-card {
  text-align: left;
  padding: 1rem;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-subtle);
  background: var(--bg-elevated);
  color: var(--text-primary);
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  cursor: pointer;
  transition:
    border-color var(--transition-fast),
    transform var(--transition-fast),
    box-shadow var(--transition-fast);
}

.garden-filter-card:hover {
  transform: translateY(-2px);
  border-color: var(--accent-primary);
}

.garden-filter-card.is-selected {
  border-color: var(--accent-primary);
  box-shadow: 0 0 0 2px var(--accent-primary-soft);
}

.garden-filter-card__top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  color: var(--accent-primary);
}

.garden-filter-card small {
  color: var(--text-secondary);
  line-height: 1.4;
}

.algo-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(275px, 1fr));
  gap: 1rem;
}

.catalog-filter-status {
  display: flex;
  justify-content: flex-start;
}

.algo-card {
  position: relative;
  overflow: hidden;
  padding: 1.2rem;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.algo-card::after {
  content: '';
  position: absolute;
  inset: auto -22px -22px auto;
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: radial-gradient(circle, var(--accent-primary-soft), transparent 70%);
  pointer-events: none;
}

.algo-card__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.difficulty {
  font-size: 0.74rem;
  color: var(--text-muted);
}

.algo-card h3 {
  font-size: 1.18rem;
}

.algo-card p {
  margin: 0;
  font-size: 0.86rem;
  color: var(--text-secondary);
  flex: 1;
}

.algo-card__cta {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.84rem;
  font-weight: 600;
  color: var(--accent-primary);
}

.status-msg {
  padding: 2rem;
  text-align: center;
  color: var(--text-secondary);
}

.status-msg.is-error {
  color: var(--status-danger);
}
</style>
