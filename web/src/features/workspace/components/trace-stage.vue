<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useLocale } from '@/shared/i18n/use-locale';
import FloralFiligree from '@/shared/ui/floral-filigree.vue';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import type {
  CellularFrame,
  EvolutionFrame,
  FractalFrame,
  GraphFrame,
  PathfindingFrame,
  SortingFrame,
} from '../types/execution';
import CellularStage from './stages/cellular-stage.vue';
import EvolutionStage from './stages/evolution-stage.vue';
import FractalStage from './stages/fractal-stage.vue';
import GraphStage from './stages/graph-stage.vue';

const props = defineProps<{
  garden: string;
  sortingFrame: SortingFrame | null;
  pathfindingFrame: PathfindingFrame | null;
  cellularFrame?: CellularFrame | null;
  graphFrame?: GraphFrame | null;
  fractalFrame?: FractalFrame | null;
  evolutionFrame?: EvolutionFrame | null;
  isPreview: boolean;
  editableGrid: boolean;
}>();

const emit = defineEmits<{
  editCell: [row: number, col: number];
  toggleCellularCell: [row: number, col: number];
  zoomFractalAt: [re: number, im: number];
  zoomFractalOut: [];
  resetFractalZoom: [];
}>();

const { t } = useLocale();
const isPointerDown = ref(false);

function handlePointerUp(): void {
  isPointerDown.value = false;
}

onMounted(() => {
  window.addEventListener('pointerup', handlePointerUp);
});
onUnmounted(() => {
  window.removeEventListener('pointerup', handlePointerUp);
});

function onCellPointerDown(r: number, c: number): void {
  if (!props.editableGrid) {
    return;
  }
  isPointerDown.value = true;
  emit('editCell', r, c);
}

function onCellPointerEnter(r: number, c: number): void {
  if (!props.editableGrid || !isPointerDown.value) {
    return;
  }
  emit('editCell', r, c);
}

function onCellKeyboardActivate(r: number, c: number): void {
  if (!props.editableGrid) {
    return;
  }
  emit('editCell', r, c);
}

const maxBar = computed(() => {
  const vals = props.sortingFrame?.values ?? [];
  return Math.max(1, ...vals.map((v) => Math.abs(v)));
});

function barTone(idx1: number): string {
  const f = props.sortingFrame;
  if (!f) {
    return 'bar--idle';
  }
  if (f.activeSwap && (f.activeSwap[0] === idx1 || f.activeSwap[1] === idx1)) {
    return 'bar--swap';
  }
  if (f.activeCompare && (f.activeCompare[0] === idx1 || f.activeCompare[1] === idx1)) {
    return 'bar--compare';
  }
  if (f.activeWrite === idx1) {
    return 'bar--write';
  }
  if (f.activePivot === idx1) {
    return 'bar--pivot';
  }
  if (f.sortedIndices.includes(idx1)) {
    return 'bar--sorted';
  }
  if (f.activeRead === idx1) {
    return 'bar--read';
  }
  if (f.activeRange && idx1 >= f.activeRange[0] && idx1 <= f.activeRange[1]) {
    return 'bar--range';
  }
  return 'bar--idle';
}

const wallSet = computed(
  () => new Set((props.pathfindingFrame?.walls ?? []).map(([r, c]) => `${r}:${c}`)),
);
const frontierSet = computed(
  () => new Set((props.pathfindingFrame?.frontier ?? []).map(([r, c]) => `${r}:${c}`)),
);
const visitedSet = computed(
  () => new Set((props.pathfindingFrame?.visited ?? []).map(([r, c]) => `${r}:${c}`)),
);
const pathSet = computed(
  () => new Set((props.pathfindingFrame?.path ?? []).map(([r, c]) => `${r}:${c}`)),
);
const weightMap = computed(() => {
  const map = new Map<string, number>();
  for (const [r, c, w] of props.pathfindingFrame?.weights ?? []) {
    map.set(`${r}:${c}`, w);
  }
  return map;
});

function cellClass(r: number, c: number): string {
  const f = props.pathfindingFrame;
  if (!f) {
    return 'cell--empty';
  }
  if (f.start[0] === r && f.start[1] === c) {
    return 'cell--start';
  }
  if (f.goal[0] === r && f.goal[1] === c) {
    return 'cell--goal';
  }
  const key = `${r}:${c}`;
  if (wallSet.value.has(key)) {
    return 'cell--wall';
  }
  if (pathSet.value.has(key)) {
    return 'cell--path';
  }
  if (f.activeCell && f.activeCell[0] === r && f.activeCell[1] === c) {
    return 'cell--active';
  }
  if (visitedSet.value.has(key)) {
    return 'cell--visited';
  }
  if (frontierSet.value.has(key)) {
    return 'cell--frontier';
  }
  if (weightMap.value.has(key)) {
    return 'cell--weighted';
  }
  return 'cell--empty';
}

function cellLabel(r: number, c: number): string {
  const f = props.pathfindingFrame;
  if (!f) {
    return '';
  }
  const key = `${r}:${c}`;
  if (f.start[0] === r && f.start[1] === c) {
    return 'S';
  }
  if (f.goal[0] === r && f.goal[1] === c) {
    return 'G';
  }
  const weight = weightMap.value.get(key);
  if (weight !== undefined && !wallSet.value.has(key)) {
    return `×${Math.round(weight)}`;
  }
  const cost = f.cellCosts[key];
  if (cost !== undefined && f.rows <= 14 && f.cols <= 18) {
    return String(Math.round(cost));
  }
  return '';
}

function cellTitle(r: number, c: number): string {
  const key = `${r}:${c}`;
  const parts = [`(${r}, ${c})`];
  const weight = weightMap.value.get(key);
  if (weight !== undefined) {
    parts.push(`${t.value.stage.weightShort}=${weight}`);
  }
  const cost = props.pathfindingFrame?.cellCosts[key];
  if (cost !== undefined) {
    parts.push(`g=${cost}`);
  }
  return parts.join(' · ');
}

function cellAriaLabel(r: number, c: number): string {
  const st = t.value.stage;
  const f = props.pathfindingFrame;
  const base = `${st.cellRowLabel} ${r}, ${st.cellColLabel} ${c}`;
  if (!f) {
    return base;
  }
  const key = `${r}:${c}`;
  if (f.start[0] === r && f.start[1] === c) {
    return `${base} (${st.legendStart})`;
  }
  if (f.goal[0] === r && f.goal[1] === c) {
    return `${base} (${st.legendGoal})`;
  }
  if (wallSet.value.has(key)) {
    return `${base} (${st.legendWall})`;
  }
  const weight = weightMap.value.get(key);
  if (weight !== undefined) {
    return `${base} (${st.weightShort} ${weight})`;
  }
  return base;
}
</script>

<template>
  <div class="trace-stage garden-card garden-card--bloomcore petal-card">
    <FloralFiligree position="bottom-left" variant="blossom" />
    <div class="stage-head">
      <span class="garden-badge" :class="isPreview ? 'garden-badge--sun' : ''">
        <MingcuteIcon :name="isPreview ? 'flower-line' : 'lotus-fill'" :size="13" />
        {{ isPreview ? t.stage.previewBadge : t.stage.liveBadge }}
      </span>
      <small v-if="garden === 'pathfinding' && editableGrid" class="stage-head__hint">
        {{ t.stage.pathfindingEditHint }}
      </small>
      <small v-else-if="garden === 'sorting'" class="stage-head__hint">
        {{ t.stage.sortingHint }}
      </small>
      <small v-else-if="garden === 'cellular'" class="stage-head__hint">
        {{ t.stage.cellularHint }}
      </small>
      <small v-else-if="garden === 'graph'" class="stage-head__hint">
        {{ t.stage.graphHint }}
      </small>
      <small v-else-if="garden === 'fractal'" class="stage-head__hint">
        {{ t.stage.fractalHint }}
      </small>
      <small v-else-if="garden === 'evolution'" class="stage-head__hint">
        {{ t.stage.evolutionHint }}
      </small>
    </div>

    <div v-if="garden === 'sorting' && sortingFrame" class="sorting-stage">
      <div class="sorting-bars" role="img" :aria-label="t.stage.sortingChartAria">
        <div v-for="(val, i) in sortingFrame.values" :key="i" class="sorting-bar-wrap">
          <div
            class="sorting-bar"
            :class="barTone(i + 1)"
            :style="{ height: `${Math.max(8, (Math.abs(val) / maxBar) * 100)}%` }"
            :title="`[${i + 1}] = ${val}`"
          />
          <span v-if="sortingFrame.values.length <= 26" class="sorting-label mono">{{ val }}</span>
        </div>
      </div>

      <div class="stage-legend stage-legend--centered">
        <span><i class="stage-swatch bar--compare" /> {{ t.stage.legendCompare }}</span>
        <span><i class="stage-swatch bar--swap" /> {{ t.stage.legendSwap }}</span>
        <span><i class="stage-swatch bar--pivot" /> {{ t.stage.legendPivot }}</span>
        <span><i class="stage-swatch bar--sorted" /> {{ t.stage.legendSorted }}</span>
      </div>
    </div>

    <div v-else-if="garden === 'pathfinding' && pathfindingFrame" class="pathfinding-stage">
      <div
        class="pf-grid"
        :class="{ 'is-editable': editableGrid }"
        role="grid"
        :aria-label="t.stage.pathfindingGridAria"
        :style="{
          gridTemplateColumns: `repeat(${pathfindingFrame.cols}, minmax(14px, 1fr))`,
        }"
      >
        <template v-for="r in pathfindingFrame.rows" :key="r">
          <button
            v-for="c in pathfindingFrame.cols"
            :key="`${r}-${c}`"
            type="button"
            class="pf-cell mono"
            :class="cellClass(r, c)"
            :title="cellTitle(r, c)"
            :aria-label="cellAriaLabel(r, c)"
            @pointerdown.prevent="onCellPointerDown(r, c)"
            @pointerenter="onCellPointerEnter(r, c)"
            @keydown.enter.space.prevent="onCellKeyboardActivate(r, c)"
          >
            {{ cellLabel(r, c) }}
          </button>
        </template>
      </div>

      <div class="stage-legend stage-legend--centered">
        <span><i class="stage-swatch cell--start" /> {{ t.stage.legendStart }}</span>
        <span><i class="stage-swatch cell--goal" /> {{ t.stage.legendGoal }}</span>
        <span><i class="stage-swatch cell--wall" /> {{ t.stage.legendWall }}</span>
        <span><i class="stage-swatch cell--weighted" /> {{ t.stage.legendWeight }}</span>
        <span><i class="stage-swatch cell--frontier" /> {{ t.stage.legendFrontier }}</span>
        <span><i class="stage-swatch cell--visited" /> {{ t.stage.legendVisited }}</span>
        <span><i class="stage-swatch cell--path" /> {{ t.stage.legendPath }}</span>
      </div>
    </div>

    <CellularStage
      v-else-if="garden === 'cellular' && cellularFrame"
      :frame="cellularFrame"
      :editable="editableGrid"
      @toggle-cell="(r, c) => emit('toggleCellularCell', r, c)"
    />

    <GraphStage
      v-else-if="garden === 'graph' && graphFrame"
      :frame="graphFrame"
    />

    <FractalStage
      v-else-if="garden === 'fractal' && fractalFrame"
      :frame="fractalFrame"
      :is-preview="isPreview"
      @zoom-at="(re, im) => emit('zoomFractalAt', re, im)"
      @zoom-out="emit('zoomFractalOut')"
      @reset-zoom="emit('resetFractalZoom')"
    />

    <EvolutionStage
      v-else-if="garden === 'evolution' && evolutionFrame"
      :frame="evolutionFrame"
      :is-preview="isPreview"
    />

    <div v-else class="stage-empty">
      <p>{{ t.stage.emptyPrompt }}</p>
    </div>
  </div>
</template>

<style scoped>
.trace-stage {
  padding: 0.95rem 1rem 1rem;
  min-height: 315px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 0.65rem;
}

.stage-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.4rem;
}

.stage-head__hint {
  font-size: 0.74rem;
  color: var(--text-muted);
}

.sorting-stage,
.pathfinding-stage {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.sorting-bars {
  height: 220px;
  display: flex;
  align-items: flex-end;
  gap: 4px;
  padding: 0.5rem 0.25rem 0;
}

.sorting-bar-wrap {
  flex: 1;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  align-items: center;
  gap: 0.2rem;
}

.sorting-bar {
  width: 100%;
  border-radius: 6px 6px 2px 2px;
  transition:
    height 110ms ease,
    background-color 110ms ease;
}

.sorting-label {
  font-size: 0.65rem;
  color: var(--text-muted);
}

.bar--idle {
  background: var(--bg-muted);
  border: 1px solid var(--border-subtle);
}

.bar--read {
  background: color-mix(in srgb, var(--accent-primary) 26%, var(--bg-muted));
}

.bar--range {
  background: color-mix(in srgb, var(--accent-primary) 42%, var(--bg-muted));
}

.bar--compare {
  background: var(--accent-sun);
}

.bar--swap {
  background: var(--accent-bloom);
}

.bar--write {
  background: var(--accent-orchid);
}

.bar--pivot {
  background: var(--accent-orchid);
}

.bar--sorted {
  background: var(--accent-primary);
}

.pf-grid {
  display: grid;
  gap: 2px;
  margin: 0 auto;
  width: 100%;
  user-select: none;
  touch-action: none;
}

.pf-cell {
  display: grid;
  place-items: center;
  padding: 0;
  font-size: 0.58rem;
  font-weight: 700;
  color: var(--text-primary);
  border-radius: 4px;
  aspect-ratio: 1;
  border: 1px solid var(--border-subtle);
  cursor: default;
  transition:
    background-color 90ms ease,
    transform 90ms ease;
}

.pf-grid.is-editable .pf-cell {
  cursor: crosshair;
}

.pf-grid.is-editable .pf-cell:hover {
  transform: scale(1.06);
  z-index: 1;
}

.cell--empty {
  background: var(--bg-elevated);
}

.cell--wall {
  background: var(--text-primary);
  border-color: var(--text-primary);
  opacity: 0.8;
}

.cell--weighted {
  background: var(--accent-sun-soft);
  border-color: var(--accent-sun);
  color: var(--accent-sun);
}

.cell--frontier {
  background: var(--accent-orchid-soft);
  border-color: var(--accent-orchid);
}

.cell--visited {
  background: var(--accent-primary-soft);
  border-color: color-mix(in srgb, var(--accent-primary) 55%, transparent);
}

.cell--active {
  background: var(--accent-sun);
  color: var(--text-on-warm-accent);
}

.cell--path {
  background: var(--accent-primary);
  border-color: var(--accent-primary);
  color: var(--text-on-primary-btn);
}

.cell--start {
  background: var(--accent-sun);
  border-color: var(--accent-sun);
  color: var(--text-on-warm-accent);
}

.cell--goal {
  background: var(--accent-bloom);
  border-color: var(--accent-bloom);
  color: var(--text-on-accent);
}

.stage-legend--centered {
  justify-content: center;
}

.stage-empty {
  text-align: center;
  color: var(--text-muted);
  font-size: 0.9rem;
}
</style>
