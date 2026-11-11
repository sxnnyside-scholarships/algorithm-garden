<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { GardenSlug } from '@/features/catalog/types/catalog';
import { useLocale } from '@/shared/i18n/use-locale';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import {
  buildGraphPreset,
  buildGridPreset,
  buildMountainPreset,
  buildSawtoothPreset,
  type CellularPresetKey,
  type GraphPresetKey,
  normalizeGridSpec,
  type PathfindingPresetKey,
} from '../composables/garden-presets';

export type GridBrush = 'wall' | 'weight' | 'start' | 'goal' | 'erase';

const props = defineProps<{
  garden: GardenSlug;
  algorithmSlug: string;
  params: Record<string, unknown>;
  activeBrush: GridBrush;
  graphNodeCount: number;
}>();

const emit = defineEmits<{
  updateParams: [nextParams: Record<string, unknown>];
  updateBrush: [brush: GridBrush];
  resetFractalZoom: [];
}>();

const { t } = useLocale();
const customArrayDraft = ref('');
const mazeSeed = ref(17);

watch(
  () => props.algorithmSlug,
  () => {
    customArrayDraft.value = '';
  },
);

function updateParam(patch: Record<string, unknown>): void {
  emit('updateParams', { ...props.params, ...patch });
}

function updateSortingParam(patch: Record<string, unknown>): void {
  const { values: _ignored, ...rest } = props.params;
  emit('updateParams', { ...rest, ...patch });
}

const sortingSize = computed({
  get: () => Number(props.params.size ?? 18),
  set: (v: number) => updateSortingParam({ size: v }),
});
const sortingDistribution = computed({
  get: () => String(props.params.distribution ?? 'random'),
  set: (v: string) => updateSortingParam({ distribution: v }),
});
const sortingSeed = computed({
  get: () => Number(props.params.seed ?? 42),
  set: (v: number) => updateSortingParam({ seed: v }),
});

const gridSpec = computed(() => normalizeGridSpec(props.params));

function applySortingPreset(preset: 'mountain' | 'sawtooth'): void {
  const vals =
    preset === 'mountain'
      ? buildMountainPreset(sortingSize.value)
      : buildSawtoothPreset(sortingSize.value);
  customArrayDraft.value = vals.join(', ');
  emit('updateParams', { ...props.params, values: vals });
}

function applyCustomArray(): void {
  const parsed = customArrayDraft.value
    .split(/[,\s]+/)
    .map((s) => Number(s.trim()))
    .filter((n) => Number.isFinite(n));
  if (parsed.length < 2) {
    return;
  }
  emit('updateParams', { ...props.params, values: parsed.slice(0, 60) });
}

function clearCustomArray(): void {
  const next = { ...props.params };
  delete next.values;
  customArrayDraft.value = '';
  emit('updateParams', next);
}

function applyPathfindingPreset(preset: PathfindingPresetKey): void {
  const g = gridSpec.value;
  const spec = buildGridPreset(preset, g.rows, g.cols, mazeSeed.value);
  emit('updateParams', {
    rows: spec.rows,
    cols: spec.cols,
    start: spec.start,
    goal: spec.goal,
    walls: spec.walls,
    weights: spec.weights,
  });
}

function resizeGrid(rows: number, cols: number): void {
  const g = gridSpec.value;
  const clamped = normalizeGridSpec({ ...g, rows, cols });
  emit('updateParams', clamped as unknown as Record<string, unknown>);
}

function applyCellularPreset(preset: CellularPresetKey): void {
  const { cells: _c, live_cells: _lc, ...rest } = props.params;
  emit('updateParams', { ...rest, preset });
}

function clearCellularGrid(): void {
  const rows = Number(props.params.rows ?? 14);
  const cols = Number(props.params.cols ?? 18);
  const empty = Array.from({ length: rows }, () => Array<number>(cols).fill(0));
  const { preset: _p, live_cells: _lc, ...rest } = props.params;
  emit('updateParams', { ...rest, cells: empty });
}

function hasRuleDigit(key: 'born' | 'survive', digit: number): boolean {
  const arr = props.params[key];
  return Array.isArray(arr) && arr.map(Number).includes(digit);
}

function toggleRuleDigit(key: 'born' | 'survive', digit: number): void {
  const arr = Array.isArray(props.params[key]) ? props.params[key].map(Number) : [];
  const next = arr.includes(digit)
    ? arr.filter((d) => d !== digit)
    : [...arr, digit].sort((a, b) => a - b);
  updateParam({ [key]: next });
}

function applyGraphPreset(preset: GraphPresetKey): void {
  const { nodes: _n, edges: _e, ...rest } = props.params;
  const spec = buildGraphPreset(preset);
  emit('updateParams', {
    ...rest,
    preset,
    start_node: spec.startNode,
    target_node: spec.targetNode,
  });
}
</script>

<template>
  <div v-if="garden === 'sorting'" class="guide-block">
    <h3>
      <MingcuteIcon name="edit-2-line" :size="16" />
      <span>{{ t.workspace.sortingParamsTitle }}</span>
    </h3>
    <div class="param-grid">
      <label class="param-field">
        <span>{{ t.workspace.sizeLabel }} ({{ sortingSize }})</span>
        <input v-model.number="sortingSize" type="range" min="4" max="50" />
      </label>
      <label class="param-field">
        <span>{{ t.workspace.distributionLabel }}</span>
        <select v-model="sortingDistribution" class="garden-input">
          <option value="random">{{ t.workspace.distRandom }}</option>
          <option value="reversed">{{ t.workspace.distReversed }}</option>
          <option value="nearly_sorted">{{ t.workspace.distNearlySorted }}</option>
          <option value="few_unique">{{ t.workspace.distFewUnique }}</option>
        </select>
      </label>
      <label class="param-field">
        <span>{{ t.workspace.seedLabel }}</span>
        <input v-model.number="sortingSeed" type="number" min="1" max="9999" class="garden-input" />
      </label>

      <div class="param-field">
        <span>{{ t.workspace.sortingPresetsLabel }}</span>
        <div class="chip-row">
          <button type="button" class="mini-chip" @click="applySortingPreset('mountain')">
            <MingcuteIcon name="mountain-2-line" :size="13" />
            <span>{{ t.workspace.presetMountain }}</span>
          </button>
          <button type="button" class="mini-chip" @click="applySortingPreset('sawtooth')">
            <MingcuteIcon name="chart-bar-line" :size="13" />
            <span>{{ t.workspace.presetSawtooth }}</span>
          </button>
        </div>
      </div>

      <div class="param-field">
        <span>{{ t.workspace.customArrayLabel }}</span>
        <div class="custom-array-row">
          <input
            v-model="customArrayDraft"
            type="text"
            :placeholder="t.workspace.customArrayPlaceholder"
            :aria-label="t.workspace.customArrayLabel"
            class="garden-input"
          />
          <button type="button" class="mini-chip" @click="applyCustomArray">
            {{ t.workspace.applyCustomArray }}
          </button>
          <button
            v-if="Array.isArray(params.values)"
            type="button"
            class="mini-chip"
            @click="clearCustomArray"
          >
            {{ t.workspace.clearCustomArray }}
          </button>
        </div>
      </div>
    </div>
  </div>

  <div v-else-if="garden === 'pathfinding'" class="guide-block">
    <h3>
      <MingcuteIcon name="route-line" :size="16" />
      <span>{{ t.workspace.pathfindingParamsTitle }}</span>
    </h3>

    <div class="param-grid">
      <div class="param-field">
        <span>{{ t.workspace.brushLabel }}</span>
        <div class="chip-row">
          <button
            type="button"
            class="mini-chip"
            :class="{ 'is-active': activeBrush === 'wall' }"
            :aria-pressed="activeBrush === 'wall'"
            @click="emit('updateBrush', 'wall')"
          >
            <MingcuteIcon name="bricks-line" :size="13" />
            <span>{{ t.workspace.brushWall }}</span>
          </button>
          <button
            type="button"
            class="mini-chip"
            :class="{ 'is-active': activeBrush === 'weight' }"
            :aria-pressed="activeBrush === 'weight'"
            @click="emit('updateBrush', 'weight')"
          >
            <MingcuteIcon name="mountain-2-line" :size="13" />
            <span>{{ t.workspace.brushWeight }}</span>
          </button>
          <button
            type="button"
            class="mini-chip"
            :class="{ 'is-active': activeBrush === 'start' }"
            :aria-pressed="activeBrush === 'start'"
            @click="emit('updateBrush', 'start')"
          >
            <MingcuteIcon name="map-pin-line" :size="13" />
            <span>{{ t.workspace.brushStart }}</span>
          </button>
          <button
            type="button"
            class="mini-chip"
            :class="{ 'is-active': activeBrush === 'goal' }"
            :aria-pressed="activeBrush === 'goal'"
            @click="emit('updateBrush', 'goal')"
          >
            <MingcuteIcon name="flag-2-line" :size="13" />
            <span>{{ t.workspace.brushGoal }}</span>
          </button>
          <button
            type="button"
            class="mini-chip"
            :class="{ 'is-active': activeBrush === 'erase' }"
            :aria-pressed="activeBrush === 'erase'"
            @click="emit('updateBrush', 'erase')"
          >
            <MingcuteIcon name="eraser-line" :size="13" />
            <span>{{ t.workspace.brushErase }}</span>
          </button>
        </div>
      </div>

      <div class="param-field">
        <span>{{ t.workspace.gridSizeLabel }}</span>
        <div class="chip-row">
          <button
            type="button"
            class="mini-chip mono"
            :class="{ 'is-active': gridSpec.rows === 10 && gridSpec.cols === 14 }"
            :aria-pressed="gridSpec.rows === 10 && gridSpec.cols === 14"
            @click="resizeGrid(10, 14)"
          >
            10×14
          </button>
          <button
            type="button"
            class="mini-chip mono"
            :class="{ 'is-active': gridSpec.rows === 12 && gridSpec.cols === 18 }"
            :aria-pressed="gridSpec.rows === 12 && gridSpec.cols === 18"
            @click="resizeGrid(12, 18)"
          >
            12×18
          </button>
          <button
            type="button"
            class="mini-chip mono"
            :class="{ 'is-active': gridSpec.rows === 15 && gridSpec.cols === 22 }"
            :aria-pressed="gridSpec.rows === 15 && gridSpec.cols === 22"
            @click="resizeGrid(15, 22)"
          >
            15×22
          </button>
        </div>
      </div>

      <div class="param-field">
        <span>{{ t.workspace.gridPresetLabel }}</span>
        <div class="chip-row">
          <button type="button" class="mini-chip" @click="applyPathfindingPreset('open')">
            {{ t.workspace.presetOpen }}
          </button>
          <button type="button" class="mini-chip" @click="applyPathfindingPreset('u_trap')">
            {{ t.workspace.presetUTrap }}
          </button>
          <button type="button" class="mini-chip" @click="applyPathfindingPreset('weighted_swamp')">
            {{ t.workspace.presetSwamp }}
          </button>
          <button type="button" class="mini-chip" @click="applyPathfindingPreset('spiral')">
            {{ t.workspace.presetSpiral }}
          </button>
          <button type="button" class="mini-chip" @click="applyPathfindingPreset('seeded_maze')">
            <MingcuteIcon name="magic-2-line" :size="13" />
            <span>{{ t.workspace.presetMaze }}</span>
          </button>
        </div>
      </div>

      <label class="param-field">
        <span>{{ t.workspace.gridSeedLabel }}</span>
        <input v-model.number="mazeSeed" type="number" min="1" max="9999" class="garden-input" />
      </label>
    </div>
  </div>

  <div v-else-if="garden === 'cellular'" class="guide-block">
    <h3>
      <MingcuteIcon name="dot-grid-line" :size="16" />
      <span>{{ t.workspace.cellularParamsTitle }}</span>
    </h3>
    <div class="param-grid">
      <div class="param-field">
        <span>{{ t.workspace.cellularPresetLabel }}</span>
        <div class="chip-row">
          <button type="button" class="mini-chip" @click="applyCellularPreset('glider')">
            {{ t.workspace.cellularPresetGlider }}
          </button>
          <button type="button" class="mini-chip" @click="applyCellularPreset('blinker')">
            {{ t.workspace.cellularPresetBlinker }}
          </button>
          <button type="button" class="mini-chip" @click="applyCellularPreset('r_pentomino')">
            {{ t.workspace.cellularPresetRPentomino }}
          </button>
          <button type="button" class="mini-chip" @click="applyCellularPreset('brians_glider')">
            {{ t.workspace.cellularPresetBriansGlider }}
          </button>
          <button type="button" class="mini-chip" @click="applyCellularPreset('random')">
            {{ t.workspace.cellularPresetRandom }}
          </button>
          <button type="button" class="mini-chip" @click="clearCellularGrid">
            {{ t.workspace.cellularClearBtn }}
          </button>
        </div>
      </div>

      <label class="param-field">
        <span>{{ t.workspace.cellularGenerationsLabel }} ({{ Number(params.generations ?? 16) }})</span>
        <input
          type="range"
          min="4"
          max="40"
          :value="Number(params.generations ?? 16)"
          @input="updateParam({ generations: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>

      <div class="param-field">
        <span>{{ t.workspace.cellularBornLabel }}</span>
        <div class="chip-row">
          <button
            v-for="d in [0, 1, 2, 3, 4, 5, 6, 7, 8]"
            :key="`b-${d}`"
            type="button"
            class="mini-chip mono"
            :class="{ 'is-active': hasRuleDigit('born', d) }"
            :aria-pressed="hasRuleDigit('born', d)"
            @click="toggleRuleDigit('born', d)"
          >
            {{ d }}
          </button>
        </div>
      </div>

      <div class="param-field">
        <span>{{ t.workspace.cellularSurviveLabel }}</span>
        <div class="chip-row">
          <button
            v-for="d in [0, 1, 2, 3, 4, 5, 6, 7, 8]"
            :key="`s-${d}`"
            type="button"
            class="mini-chip mono"
            :class="{ 'is-active': hasRuleDigit('survive', d) }"
            :aria-pressed="hasRuleDigit('survive', d)"
            @click="toggleRuleDigit('survive', d)"
          >
            {{ d }}
          </button>
        </div>
      </div>
    </div>
  </div>

  <div v-else-if="garden === 'graph'" class="guide-block">
    <h3>
      <MingcuteIcon name="chart-network-line" :size="16" />
      <span>{{ t.workspace.graphParamsTitle }}</span>
    </h3>
    <div class="param-grid">
      <div class="param-field">
        <span>{{ t.workspace.graphPresetLabel }}</span>
        <div class="chip-row">
          <button type="button" class="mini-chip" @click="applyGraphPreset('botanical_web')">
            {{ t.workspace.graphPresetWeb }}
          </button>
          <button type="button" class="mini-chip" @click="applyGraphPreset('two_islands')">
            {{ t.workspace.graphPresetIslands }}
          </button>
          <button type="button" class="mini-chip" @click="applyGraphPreset('weighted_canopy')">
            {{ t.workspace.graphPresetCanopy }}
          </button>
        </div>
      </div>

      <label class="param-field">
        <span>{{ t.workspace.graphStartLabel }}</span>
        <input
          type="number"
          min="1"
          :max="graphNodeCount"
          :value="Number(params.start_node ?? 1)"
          class="garden-input"
          @input="updateParam({ start_node: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>

      <label class="param-field">
        <span>{{ t.workspace.graphTargetLabel }}</span>
        <input
          type="number"
          min="1"
          :max="graphNodeCount"
          :value="Number(params.target_node ?? 6)"
          class="garden-input"
          @input="updateParam({ target_node: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>
    </div>
  </div>

  <div v-else-if="garden === 'fractal'" class="guide-block">
    <h3>
      <MingcuteIcon name="flower-5-line" :size="16" />
      <span>{{ t.workspace.fractalParamsTitle }}</span>
    </h3>
    <div class="param-grid">
      <label v-if="algorithmSlug !== 'recursive-tree'" class="param-field">
        <span>{{ t.workspace.fractalIterLabel }} ({{ Number(params.max_iter ?? 40) }})</span>
        <input
          type="range"
          min="15"
          max="100"
          :value="Number(params.max_iter ?? 40)"
          @input="updateParam({ max_iter: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>

      <label v-else class="param-field">
        <span>{{ t.workspace.fractalDepthLabel }} ({{ Number(params.depth ?? 6) }})</span>
        <input
          type="range"
          min="2"
          max="8"
          :value="Number(params.depth ?? 6)"
          @input="updateParam({ depth: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>

      <template v-if="algorithmSlug === 'julia-set'">
        <label class="param-field">
          <span>{{ t.workspace.fractalJuliaReLabel }}</span>
          <input
            type="number"
            step="0.02"
            min="-1.5"
            max="1.5"
            :value="Number(params.julia_re ?? -0.7)"
            class="garden-input"
            @input="updateParam({ julia_re: Number(($event.target as HTMLInputElement).value) })"
          />
        </label>
        <label class="param-field">
          <span>{{ t.workspace.fractalJuliaImLabel }}</span>
          <input
            type="number"
            step="0.02"
            min="-1.5"
            max="1.5"
            :value="Number(params.julia_im ?? 0.27015)"
            class="garden-input"
            @input="updateParam({ julia_im: Number(($event.target as HTMLInputElement).value) })"
          />
        </label>
      </template>

      <div v-if="algorithmSlug !== 'recursive-tree'" class="chip-row">
        <button type="button" class="mini-chip" @click="emit('resetFractalZoom')">
          {{ t.workspace.fractalResetViewBtn }}
        </button>
      </div>
    </div>
  </div>

  <div v-else-if="garden === 'evolution'" class="guide-block">
    <h3>
      <MingcuteIcon name="dna-line" :size="16" />
      <span>{{ t.workspace.evolutionParamsTitle }}</span>
    </h3>
    <div class="param-grid">
      <label class="param-field">
        <span>{{ t.workspace.evoPopLabel }} ({{ Number(params.population_size ?? 18) }})</span>
        <input
          type="range"
          min="8"
          max="40"
          :value="Number(params.population_size ?? 18)"
          @input="updateParam({ population_size: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>
      <label class="param-field">
        <span>{{ t.workspace.evoGensLabel }} ({{ Number(params.generations ?? 20) }})</span>
        <input
          type="range"
          min="8"
          max="45"
          :value="Number(params.generations ?? 20)"
          @input="updateParam({ generations: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>
      <label class="param-field">
        <span>{{ t.workspace.evoMutLabel }}</span>
        <input
          type="number"
          step="0.01"
          min="0.01"
          max="0.5"
          :value="Number(params.mutation_rate ?? 0.06)"
          class="garden-input"
          @input="updateParam({ mutation_rate: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>
      <label class="param-field">
        <span>{{ t.workspace.evoSeedLabel }}</span>
        <input
          type="number"
          min="1"
          max="9999"
          :value="Number(params.seed ?? 42)"
          class="garden-input"
          @input="updateParam({ seed: Number(($event.target as HTMLInputElement).value) })"
        />
      </label>
    </div>
  </div>
</template>

<style scoped>
.guide-block {
  border-top: 1px solid var(--border-subtle);
  padding-top: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.guide-block h3 {
  display: inline-flex;
  align-items: center;
  gap: 0.38rem;
  font-size: 0.94rem;
}

.param-grid {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.param-field {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.chip-row,
.custom-array-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  align-items: center;
}

.custom-array-row .garden-input {
  flex: 1;
  min-width: 130px;
  padding: 0.38rem 0.65rem;
  font-size: 0.8rem;
}

.mini-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.28rem;
  padding: 0.3rem 0.6rem;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-subtle);
  background: var(--bg-elevated);
  color: var(--text-primary);
  font-size: 0.74rem;
  font-weight: 600;
  cursor: pointer;
  transition:
    border-color var(--transition-fast),
    background var(--transition-fast);
}

.mini-chip:hover {
  border-color: var(--accent-primary);
}

.mini-chip.is-active {
  background: var(--accent-primary-soft);
  border-color: var(--accent-primary);
  color: var(--accent-primary);
}
</style>

