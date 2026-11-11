<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';
import { useLocale } from '@/shared/i18n/use-locale';
import type { CellularFrame } from '../../types/execution';

const props = defineProps<{
  frame: CellularFrame;
  editable: boolean;
}>();

const emit = defineEmits<{
  toggleCell: [row: number, col: number];
}>();

const { t } = useLocale();
const painting = ref(false);

function stopPainting(): void {
  painting.value = false;
}

onMounted(() => {
  window.addEventListener('pointerup', stopPainting);
});

onUnmounted(() => {
  window.removeEventListener('pointerup', stopPainting);
});

function handlePointerDown(r: number, c: number): void {
  if (!props.editable) {
    return;
  }
  painting.value = true;
  emit('toggleCell', r, c);
}

function handlePointerEnter(r: number, c: number): void {
  if (props.editable && painting.value) {
    emit('toggleCell', r, c);
  }
}

function handleKeyActivate(r: number, c: number): void {
  if (!props.editable) {
    return;
  }
  emit('toggleCell', r, c);
}

function cellStateLabel(state: number): string {
  if (state === 1) {
    return t.value.stage.legendAlive;
  }
  if (state === 2) {
    return t.value.stage.legendRefractory;
  }
  return t.value.stage.legendDead;
}

function cellAriaLabel(r: number, c: number, state: number): string {
  return `${t.value.stage.cellRowLabel} ${r}, ${t.value.stage.cellColLabel} ${c}: ${cellStateLabel(state)}`;
}

function cellClass(state: number): string {
  if (state === 1) {
    return 'ca-cell--alive';
  }
  if (state === 2) {
    return 'ca-cell--dying';
  }
  return 'ca-cell--dead';
}
</script>

<template>
  <div class="cellular-stage" @pointerup="stopPainting" @pointerleave="stopPainting">
    <div class="cellular-meta mono">
      <span class="stage-meta-pill">B{{ frame.born.join('') }}/S{{ frame.survive.join('') }}</span>
      <span class="stage-meta-pill">{{ t.stage.cellularGen }} {{ frame.generation }}</span>
      <span class="stage-meta-pill">{{ t.stage.cellularAlive }}: {{ frame.aliveCount }}</span>
      <span v-if="frame.generation > 0" class="stage-meta-pill">
        +{{ frame.bornCount }} / -{{ frame.diedCount }}
      </span>
    </div>

    <div
      class="ca-grid"
      :class="{ 'is-editable': editable }"
      role="grid"
      :aria-label="t.stage.cellularGridAria"
      :style="{
        gridTemplateColumns: `repeat(${frame.cols}, minmax(12px, 1fr))`,
      }"
    >
      <template v-for="(row, rIdx) in frame.cells" :key="rIdx">
        <button
          v-for="(state, cIdx) in row"
          :key="`${rIdx}-${cIdx}`"
          type="button"
          class="ca-cell"
          :class="cellClass(state)"
          :title="`(${rIdx + 1}, ${cIdx + 1}) = ${state}`"
          :aria-label="cellAriaLabel(rIdx + 1, cIdx + 1, state)"
          @pointerdown.prevent="handlePointerDown(rIdx + 1, cIdx + 1)"
          @pointerenter="handlePointerEnter(rIdx + 1, cIdx + 1)"
          @keydown.enter.space.prevent="handleKeyActivate(rIdx + 1, cIdx + 1)"
        />
      </template>
    </div>

    <div class="stage-legend">
      <span><i class="stage-swatch ca-cell--alive" /> {{ t.stage.legendAlive }}</span>
      <span><i class="stage-swatch ca-cell--dying" /> {{ t.stage.legendRefractory }}</span>
      <span><i class="stage-swatch ca-cell--dead" /> {{ t.stage.legendDead }}</span>
    </div>
  </div>
</template>

<style scoped>
.cellular-stage {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.cellular-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  font-size: 0.74rem;
}

.ca-grid {
  display: grid;
  gap: 3px;
  padding: 0.6rem;
  border-radius: var(--radius-md);
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
  user-select: none;
}

.ca-cell {
  aspect-ratio: 1;
  border: 1px solid var(--border-subtle);
  border-radius: 4px;
  padding: 0;
  cursor: default;
  transition: transform 0.12s ease, background-color 0.14s ease;
}

.ca-grid.is-editable .ca-cell {
  cursor: pointer;
}

.ca-grid.is-editable .ca-cell:hover {
  transform: scale(1.08);
}

.ca-cell--dead {
  background: var(--bg-surface);
}

.ca-cell--alive {
  background: var(--accent-primary);
  border-color: var(--accent-primary);
  box-shadow: 0 0 8px color-mix(in srgb, var(--accent-primary) 45%, transparent);
}

.ca-cell--dying {
  background: var(--accent-orchid);
  border-color: var(--accent-orchid);
  opacity: 0.85;
}
</style>

