<script setup lang="ts">
import { computed, onMounted, ref, toRaw, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import GardenLayout from '@/app/layouts/garden-layout.vue';
import { useAuthStore } from '@/features/auth/stores/auth-store';
import { useCatalogStore } from '@/features/catalog/stores/catalog-store';
import type { ExerciseSummary, GardenSlug } from '@/features/catalog/types/catalog';
import { experimentsApi } from '@/features/experiments/api/experiments-api';
import { useExperimentsStore } from '@/features/experiments/stores/experiments-store';
import { ApiClientError } from '@/shared/api/http-client';
import { localizeAlgorithm, localizeExercise } from '@/shared/i18n/catalog-i18n';
import { useLocale } from '@/shared/i18n/use-locale';
import { useTheme } from '@/shared/theme/use-theme';
import FloralFiligree from '@/shared/ui/floral-filigree.vue';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import { executionsApi } from '../api/executions-api';
import ExecutionInspector from '../components/execution-inspector.vue';
import JuliaEditor from '../components/julia-editor.vue';
import PlaybackControls from '../components/playback-controls.vue';
import TraceStage from '../components/trace-stage.vue';
import WorkspaceParamsPanel, { type GridBrush } from '../components/workspace-params-panel.vue';
import { useExecutionPlayer } from '../composables/execution-player';
import {
  buildCellularPreview,
  buildEvolutionPreview,
  buildFractalPreview,
  buildGraphPreview,
  buildSortingPreviewValues,
  normalizeGridSpec,
} from '../composables/garden-presets';
import type {
  CellularFrame,
  EvolutionFrame,
  ExerciseTestResult,
  FractalFrame,
  GraphFrame,
  PathfindingFrame,
  SortingFrame,
} from '../types/execution';

const GARDEN_BADGE_ICON: Record<GardenSlug, string> = {
  sorting: 'cherry-line',
  pathfinding: 'rose-line',
  cellular: 'flower-2-line',
  graph: 'chart-network-line',
  fractal: 'flower-5-line',
  evolution: 'dna-line',
};

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const catalogStore = useCatalogStore();
const experimentsStore = useExperimentsStore();
const { theme } = useTheme();
const { locale, t } = useLocale();
const player = useExecutionPlayer();

const code = ref('');
const params = ref<Record<string, unknown>>({});
const running = ref(false);
const saving = ref(false);
const saveFeedback = ref<string | null>(null);
const apiError = ref<string | null>(null);

const selectedExercise = ref<ExerciseSummary | null>(null);
const exerciseResults = ref<ExerciseTestResult[] | null>(null);
const exercisePassed = ref<boolean | null>(null);
const activeExperimentId = ref<string | null>(null);
const experimentTitle = ref('');
const activeBrush = ref<GridBrush>('wall');

const algorithmSlug = computed(() => String(route.params.slug ?? 'bubble-sort'));
const localizedAlgo = computed(() =>
  catalogStore.activeAlgorithm
    ? localizeAlgorithm(catalogStore.activeAlgorithm, locale.value)
    : null,
);
const localizedExercises = computed(() =>
  catalogStore.activeExercises.map((ex) => localizeExercise(ex, locale.value)),
);

const gridSpec = computed(() => normalizeGridSpec(params.value));

const previewSortingFrame = computed<SortingFrame | null>(() => {
  if (catalogStore.activeAlgorithm?.garden !== 'sorting') {
    return null;
  }
  return {
    values: buildSortingPreviewValues(params.value),
    activeCompare: null,
    activeSwap: null,
    activeWrite: null,
    activeRead: null,
    activePivot: null,
    activeRange: null,
    sortedIndices: [],
    counters: { comparisons: 0, swaps: 0, reads: 0, writes: 0 },
    currentEvent: null,
  };
});

const previewPathfindingFrame = computed<PathfindingFrame | null>(() => {
  if (catalogStore.activeAlgorithm?.garden !== 'pathfinding') {
    return null;
  }
  const g = gridSpec.value;
  return {
    rows: g.rows,
    cols: g.cols,
    start: g.start,
    goal: g.goal,
    walls: g.walls,
    weights: g.weights,
    frontier: [],
    visited: [],
    cellCosts: {},
    activeCell: null,
    activeEdge: null,
    path: [],
    totalCost: null,
    counters: { visited: 0, frontier: 0, relaxed: 0 },
    currentEvent: null,
  };
});

const previewCellularFrame = computed<CellularFrame | null>(() =>
  catalogStore.activeAlgorithm?.garden === 'cellular' ? buildCellularPreview(params.value) : null,
);

const previewGraphFrame = computed<GraphFrame | null>(() =>
  catalogStore.activeAlgorithm?.garden === 'graph' ? buildGraphPreview(params.value) : null,
);

const previewFractalFrame = computed<FractalFrame | null>(() =>
  catalogStore.activeAlgorithm?.garden === 'fractal'
    ? buildFractalPreview(params.value, catalogStore.activeAlgorithm.slug)
    : null,
);

const previewEvolutionFrame = computed<EvolutionFrame | null>(() =>
  catalogStore.activeAlgorithm?.garden === 'evolution' ? buildEvolutionPreview(params.value) : null,
);

const effectiveSortingFrame = computed(
  () => player.sortingFrame.value ?? previewSortingFrame.value,
);
const effectivePathfindingFrame = computed(
  () => player.pathfindingFrame.value ?? previewPathfindingFrame.value,
);
const effectiveCellularFrame = computed(
  () => player.cellularFrame.value ?? previewCellularFrame.value,
);
const effectiveGraphFrame = computed(() => player.graphFrame.value ?? previewGraphFrame.value);
const effectiveFractalFrame = computed(
  () => player.fractalFrame.value ?? previewFractalFrame.value,
);
const effectiveEvolutionFrame = computed(
  () => player.evolutionFrame.value ?? previewEvolutionFrame.value,
);
const isShowingPreview = computed(() => player.execution.value === null);

function cloneParams(source: Record<string, unknown>): Record<string, unknown> {
  return structuredClone(toRaw(source));
}

function handleParamsUpdate(nextParams: Record<string, unknown>): void {
  params.value = nextParams;
  player.clear();
}

function handleToggleCellularCell(row: number, col: number): void {
  const current = buildCellularPreview(params.value);
  const cloned = current.cells.map((r) => [...r]);
  const targetRow = cloned[row - 1];
  if (targetRow) {
    targetRow[col - 1] = targetRow[col - 1] === 1 ? 0 : 1;
  }
  const { preset: _p, live_cells: _lc, ...rest } = params.value;
  params.value = { ...rest, cells: cloned };
  player.clear();
}

function scaleFractalView(halfSpanFactor: number, centerRe?: number, centerIm?: number): void {
  const xMin = Number(params.value.x_min ?? -2.1);
  const xMax = Number(params.value.x_max ?? 0.8);
  const yMin = Number(params.value.y_min ?? -1.2);
  const yMax = Number(params.value.y_max ?? 1.2);
  const re = centerRe ?? (xMin + xMax) / 2;
  const im = centerIm ?? (yMin + yMax) / 2;
  const halfW = (xMax - xMin) * halfSpanFactor;
  const halfH = (yMax - yMin) * halfSpanFactor;
  params.value = {
    ...params.value,
    x_min: Number((re - halfW).toFixed(6)),
    x_max: Number((re + halfW).toFixed(6)),
    y_min: Number((im - halfH).toFixed(6)),
    y_max: Number((im + halfH).toFixed(6)),
  };
  void runCode();
}

function handleZoomFractalAt(re: number, im: number): void {
  scaleFractalView(0.25, re, im);
}

function handleZoomFractalOut(): void {
  scaleFractalView(1.0);
}

function handleResetFractalZoom(): void {
  const def = catalogStore.activeAlgorithm?.default_params ?? {};
  params.value = {
    ...params.value,
    x_min: def.x_min ?? -2.1,
    x_max: def.x_max ?? 0.8,
    y_min: def.y_min ?? -1.2,
    y_max: def.y_max ?? 1.2,
  };
  player.clear();
}

function handleEditGridCell(row: number, col: number): void {
  const g = gridSpec.value;
  const isStart = g.start[0] === row && g.start[1] === col;
  const isGoal = g.goal[0] === row && g.goal[1] === col;
  let walls = [...g.walls];
  let weights = [...g.weights];
  let start: [number, number] = g.start;
  let goal: [number, number] = g.goal;

  const stripCell = (r: number, c: number) => {
    walls = walls.filter(([wr, wc]) => wr !== r || wc !== c);
    weights = weights.filter(([wr, wc]) => wr !== r || wc !== c);
  };

  if (activeBrush.value === 'start' && !isGoal) {
    stripCell(row, col);
    start = [row, col];
  } else if (activeBrush.value === 'goal' && !isStart) {
    stripCell(row, col);
    goal = [row, col];
  } else if (activeBrush.value === 'wall' && !isStart && !isGoal) {
    const exists = walls.some(([wr, wc]) => wr === row && wc === col);
    stripCell(row, col);
    if (!exists) {
      walls.push([row, col]);
    }
  } else if (activeBrush.value === 'weight' && !isStart && !isGoal) {
    const exists = weights.some(([wr, wc]) => wr === row && wc === col);
    stripCell(row, col);
    if (!exists) {
      weights.push([row, col, 5.0]);
    }
  } else if (activeBrush.value === 'erase' && !isStart && !isGoal) {
    stripCell(row, col);
  }

  params.value = normalizeGridSpec({
    rows: g.rows,
    cols: g.cols,
    start,
    goal,
    walls,
    weights,
  }) as unknown as Record<string, unknown>;
  player.clear();
}

async function loadAlgorithmView(): Promise<void> {
  const requestedSlug = algorithmSlug.value;
  apiError.value = null;
  saveFeedback.value = null;
  selectedExercise.value = null;
  exerciseResults.value = null;
  exercisePassed.value = null;
  activeExperimentId.value = null;
  player.clear();

  const loaded = await catalogStore.fetchAlgorithm(requestedSlug);
  const algo = catalogStore.activeAlgorithm;
  if (!loaded || !algo || requestedSlug !== algorithmSlug.value) {
    return;
  }

  code.value = algo.reference_code;
  params.value = cloneParams(algo.default_params);
  experimentTitle.value = `${algo.name} — ${t.value.workspace.defaultExperimentSuffix}`;

  const expQuery = route.query.experiment;
  if (typeof expQuery === 'string' && authStore.isAuthenticated) {
    try {
      const { experiment } = await experimentsApi.get(expQuery);
      if (requestedSlug !== algorithmSlug.value) {
        return;
      }
      activeExperimentId.value = experiment.id;
      experimentTitle.value = experiment.title;
      code.value = experiment.code;
      params.value = cloneParams(experiment.params);
    } catch {
      // Fall back to reference code when experiment cannot be loaded.
    }
  }
}

onMounted(() => {
  void loadAlgorithmView();
});

watch(algorithmSlug, () => {
  void loadAlgorithmView();
});

function restoreReference(): void {
  const algo = catalogStore.activeAlgorithm;
  if (!algo) {
    return;
  }
  selectedExercise.value = null;
  exerciseResults.value = null;
  exercisePassed.value = null;
  code.value = algo.reference_code;
  params.value = cloneParams(algo.default_params);
  player.clear();
}

function selectExercise(ex: ExerciseSummary): void {
  selectedExercise.value = ex;
  exerciseResults.value = null;
  exercisePassed.value = null;
  code.value = ex.starter_code;
  player.clear();
}

async function runCode(): Promise<void> {
  if (!catalogStore.activeAlgorithm) {
    return;
  }
  running.value = true;
  apiError.value = null;
  exerciseResults.value = null;
  exercisePassed.value = null;
  try {
    const res = await executionsApi.run({
      algorithm_slug: catalogStore.activeAlgorithm.slug,
      code: code.value,
      params: params.value,
    });
    player.load(res.execution, true);
  } catch (err) {
    apiError.value = err instanceof ApiClientError ? err.message : t.value.workspace.runError;
  } finally {
    running.value = false;
  }
}

async function verifyCurrentExercise(): Promise<void> {
  if (!selectedExercise.value) {
    return;
  }
  if (!authStore.isAuthenticated) {
    await router.push('/login');
    return;
  }
  running.value = true;
  apiError.value = null;
  try {
    const res = await executionsApi.verifyExercise(selectedExercise.value.id, {
      code: code.value,
    });
    exercisePassed.value = res.passed;
    exerciseResults.value = res.results;
    player.load(res.execution, true);
  } catch (err) {
    apiError.value = err instanceof ApiClientError ? err.message : t.value.workspace.verifyError;
  } finally {
    running.value = false;
  }
}

async function saveExperiment(): Promise<void> {
  if (!catalogStore.activeAlgorithm) {
    return;
  }
  if (!authStore.isAuthenticated) {
    await router.push('/login');
    return;
  }
  saving.value = true;
  saveFeedback.value = null;
  apiError.value = null;
  try {
    if (activeExperimentId.value) {
      await experimentsStore.updateExisting(activeExperimentId.value, {
        title: experimentTitle.value.trim() || catalogStore.activeAlgorithm.name,
        code: code.value,
        params: params.value,
      });
      saveFeedback.value = t.value.workspace.savedUpdated;
    } else {
      const created = await experimentsStore.saveNew({
        algorithm_slug: catalogStore.activeAlgorithm.slug,
        title: experimentTitle.value.trim() || catalogStore.activeAlgorithm.name,
        code: code.value,
        params: params.value,
      });
      activeExperimentId.value = created.id;
      saveFeedback.value = t.value.workspace.savedCreated;
    }
  } catch (err) {
    apiError.value = err instanceof ApiClientError ? err.message : t.value.workspace.saveError;
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <GardenLayout>
    <div v-if="catalogStore.loading && !localizedAlgo" class="loading-box">
      {{ t.workspace.loading }}
    </div>

    <div v-else-if="catalogStore.error && !localizedAlgo" class="feedback-bar is-error" role="alert">
      {{ catalogStore.error }}
    </div>

    <div v-else-if="localizedAlgo" class="workspace-grid">
      <!-- Area 1: Educational Content, Parameters & Exercises -->
      <section class="guide-pane garden-card garden-card--bloomcore petal-card">
        <FloralFiligree position="top-right" variant="blossom" />
        <FloralFiligree position="bottom-left" variant="vine" />
        <div class="guide-pane__head">
          <RouterLink to="/catalog" class="back-link">
            <MingcuteIcon name="arrow-left-line" :size="15" />
            <span>{{ t.workspace.backToCatalog }}</span>
          </RouterLink>
          <span class="garden-badge">
            <MingcuteIcon :name="GARDEN_BADGE_ICON[localizedAlgo.garden]" :size="12" />
            {{ t.catalog.gardens[localizedAlgo.garden] }}
          </span>
        </div>

        <h1>{{ localizedAlgo.name }}</h1>
        <p class="concept">{{ localizedAlgo.concept }}</p>
        <p class="explanation">{{ localizedAlgo.explanation }}</p>

        <div class="guide-block">
          <h3>
            <MingcuteIcon name="eye-line" :size="16" />
            <span>{{ t.workspace.whatToWatch }}</span>
          </h3>
          <p>{{ localizedAlgo.visualization_guide }}</p>
        </div>

        <WorkspaceParamsPanel
          :garden="localizedAlgo.garden"
          :algorithm-slug="localizedAlgo.slug"
          :params="params"
          :active-brush="activeBrush"
          :graph-node-count="effectiveGraphFrame?.nodes.length ?? 8"
          @update-params="handleParamsUpdate"
          @update-brush="(b) => (activeBrush = b)"
          @reset-fractal-zoom="handleResetFractalZoom"
        />

        <div v-if="localizedExercises.length > 0" class="guide-block">
          <h3>
            <MingcuteIcon name="book-2-line" :size="16" />
            <span>{{ t.workspace.guidedExercisesTitle }}</span>
          </h3>
          <div class="exercise-list">
            <button
              v-for="ex in localizedExercises"
              :key="ex.id"
              type="button"
              class="exercise-chip"
              :class="{ 'is-active': selectedExercise?.id === ex.id }"
              :aria-pressed="selectedExercise?.id === ex.id"
              @click="selectExercise(ex)"
            >
              <strong>{{ ex.title }}</strong>
              <small>{{ ex.instructions }}</small>
            </button>
          </div>
        </div>
      </section>

      <!-- Area 2: Julia Code Editor -->
      <section class="editor-pane garden-card">
        <div class="pane-toolbar">
          <div class="pane-toolbar__title">
            <MingcuteIcon name="code-line" :size="17" />
            <span>{{ t.workspace.juliaTitle }}</span>
            <span v-if="selectedExercise" class="garden-badge garden-badge--bloom">
              {{ t.workspace.activeExerciseBadge }}
            </span>
          </div>

          <div class="pane-toolbar__actions">
            <button type="button" class="garden-btn" @click="restoreReference">
              <MingcuteIcon name="refresh-2-line" :size="15" />
              <span>{{ t.workspace.restoreBtn }}</span>
            </button>
            <button type="button" class="garden-btn" :disabled="saving" @click="saveExperiment">
              <MingcuteIcon name="save-2-line" :size="15" />
              <span>{{ saving ? t.workspace.savingBtn : t.workspace.saveBtn }}</span>
            </button>
            <button
              v-if="selectedExercise"
              type="button"
              class="garden-btn garden-btn--bloom"
              :disabled="running"
              @click="verifyCurrentExercise"
            >
              <MingcuteIcon name="check-circle-line" :size="15" />
              <span>{{ running ? t.workspace.verifyingBtn : t.workspace.verifyBtn }}</span>
            </button>
            <button
              type="button"
              class="garden-btn garden-btn--primary"
              :disabled="running"
              @click="runCode"
            >
              <MingcuteIcon name="play-fill" :size="15" />
              <span>{{ running ? t.workspace.runningBtn : t.workspace.runBtn }}</span>
            </button>
          </div>
        </div>

        <div v-if="saveFeedback" class="feedback-bar" role="status">{{ saveFeedback }}</div>
        <div v-if="apiError" class="feedback-bar is-error" role="alert">{{ apiError }}</div>

        <div class="editor-body">
          <JuliaEditor
            v-model="code"
            :theme="theme"
            :error="player.execution.value?.error ?? null"
          />
        </div>
      </section>

      <!-- Area 3: Visualization + Execution Controls + Inspector -->
      <section class="visual-pane">
        <TraceStage
          :garden="localizedAlgo.garden"
          :sorting-frame="effectiveSortingFrame"
          :pathfinding-frame="effectivePathfindingFrame"
          :cellular-frame="effectiveCellularFrame"
          :graph-frame="effectiveGraphFrame"
          :fractal-frame="effectiveFractalFrame"
          :evolution-frame="effectiveEvolutionFrame"
          :is-preview="isShowingPreview"
          :editable-grid="localizedAlgo.garden === 'pathfinding' || localizedAlgo.garden === 'cellular'"
          @edit-cell="handleEditGridCell"
          @toggle-cellular-cell="handleToggleCellularCell"
          @zoom-fractal-at="handleZoomFractalAt"
          @zoom-fractal-out="handleZoomFractalOut"
          @reset-fractal-zoom="handleResetFractalZoom"
        />

        <PlaybackControls
          :status="player.status.value"
          :current-step="player.currentStep.value"
          :total-steps="player.totalSteps.value"
          :speed-multiplier="player.speedMultiplier.value"
          @step-backward="player.stepBackward"
          @play="player.play"
          @pause="player.pause"
          @resume="player.resume"
          @step-forward="player.stepForward"
          @reset="player.reset"
          @seek="player.seek"
          @set-speed="player.setSpeed"
        />

        <ExecutionInspector
          :execution="player.execution.value"
          :current-step="player.currentStep.value"
          :total-steps="player.totalSteps.value"
          :sorting-frame="player.sortingFrame.value"
          :pathfinding-frame="player.pathfindingFrame.value"
          :cellular-frame="player.cellularFrame.value"
          :graph-frame="player.graphFrame.value"
          :fractal-frame="player.fractalFrame.value"
          :evolution-frame="player.evolutionFrame.value"
          :exercise-results="exerciseResults"
          :exercise-passed="exercisePassed"
        />
      </section>
    </div>
  </GardenLayout>
</template>

<style scoped>
.loading-box {
  padding: 3rem;
  text-align: center;
  color: var(--text-secondary);
}

.workspace-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
  align-items: start;
}

@media (min-width: 1200px) {
  .workspace-grid {
    grid-template-columns: 325px minmax(380px, 1.05fr) minmax(380px, 1.1fr);
  }
}

.guide-pane,
.editor-pane {
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
}

.guide-pane__head,
.guide-pane h1,
.concept,
.explanation,
.guide-block {
  position: relative;
  z-index: 1;
}

.guide-pane__head {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.back-link {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.concept {
  margin: 0;
  font-size: 0.84rem;
  font-weight: 600;
  color: var(--accent-primary);
}

.explanation {
  margin: 0;
  font-size: 0.85rem;
  color: var(--text-secondary);
  white-space: pre-line;
}

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

.guide-block p {
  margin: 0;
  font-size: 0.82rem;
  color: var(--text-secondary);
}

.exercise-list {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.exercise-chip {
  text-align: left;
  padding: 0.6rem 0.75rem;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-subtle);
  background: var(--bg-elevated);
  color: var(--text-primary);
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  cursor: pointer;
}

.exercise-chip.is-active {
  border-color: var(--accent-bloom);
  background: var(--accent-bloom-soft);
}

.exercise-chip strong {
  font-size: 0.82rem;
}

.exercise-chip small {
  font-size: 0.76rem;
  color: var(--text-secondary);
}

.pane-toolbar {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
}

.pane-toolbar__title {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-weight: 600;
  font-size: 0.9rem;
}

.pane-toolbar__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.editor-body {
  height: 520px;
}

.feedback-bar {
  padding: 0.45rem 0.75rem;
  border-radius: var(--radius-sm);
  font-size: 0.8rem;
  background: var(--accent-primary-soft);
  color: var(--accent-primary);
}

.feedback-bar.is-error {
  background: var(--status-danger-soft);
  color: var(--status-danger);
}

.visual-pane {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
}
</style>
