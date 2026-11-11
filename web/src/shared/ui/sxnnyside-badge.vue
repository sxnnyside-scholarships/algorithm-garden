<script setup lang="ts">
import { useLocale } from '@/shared/i18n/use-locale';
import MingcuteIcon from './mingcute-icon.vue';

withDefaults(
  defineProps<{
    compact?: boolean;
  }>(),
  {
    compact: false,
  },
);

const { t, sxnnysideUrl } = useLocale();
</script>

<template>
  <a
    :href="sxnnysideUrl"
    target="_blank"
    rel="noopener noreferrer"
    class="sxnnyside-credit"
    :class="{ 'is-compact': compact }"
  >
    <span class="sxnnyside-credit__lotus">
      <MingcuteIcon name="lotus-fill" :size="compact ? 14 : 15" />
    </span>
    <span class="sxnnyside-credit__text">{{ t.common.sxnnysideCredit }}</span>
    <MingcuteIcon name="external-link-line" :size="compact ? 12 : 13" />
  </a>
</template>

<style scoped>
.sxnnyside-credit {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.36rem 0.78rem;
  border-radius: var(--radius-pill);
  border: 1px solid color-mix(in srgb, var(--accent-bloom) 28%, var(--border-subtle));
  background: linear-gradient(
    135deg,
    color-mix(in srgb, var(--accent-primary-soft) 72%, var(--bg-surface)),
    color-mix(in srgb, var(--accent-bloom-soft) 72%, var(--bg-surface))
  );
  color: var(--text-primary);
  font-size: 0.78rem;
  font-weight: 600;
  transition:
    transform var(--transition-fast),
    border-color var(--transition-fast),
    box-shadow var(--transition-fast);
}

.sxnnyside-credit:hover {
  transform: translateY(-1px);
  border-color: var(--accent-primary);
  box-shadow: var(--shadow-glow);
}

.sxnnyside-credit.is-compact {
  padding: 0.28rem 0.65rem;
  font-size: 0.72rem;
}

.sxnnyside-credit__lotus {
  display: inline-flex;
  color: var(--accent-bloom);
}
</style>

