<script setup lang="ts">
import { computed, ref } from 'vue';
import { useLocale } from '@/shared/i18n/use-locale';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import type {
  CellularFrame,
  EvolutionFrame,
  ExecutionResult,
  ExerciseTestResult,
  FractalFrame,
  GraphFrame,
  PathfindingFrame,
  SortingFrame,
  TraceEvent,
} from '../types/execution';

const props = defineProps<{
  execution: ExecutionResult | null;
  currentStep: number;
  totalSteps: number;
  sortingFrame: SortingFrame | null;
  pathfindingFrame: PathfindingFrame | null;
  cellularFrame?: CellularFrame | null;
  graphFrame?: GraphFrame | null;
  fractalFrame?: FractalFrame | null;
  evolutionFrame?: EvolutionFrame | null;
  exerciseResults: ExerciseTestResult[] | null;
  exercisePassed: boolean | null;
}>();

const { t } = useLocale();
const activeTab = ref<'overview' | 'events' | 'tests'>('overview');

const visibleEvents = computed<TraceEvent[]>(() => {
  const events = props.execution?.events ?? [];
  if (events.length === 0) {
    return [];
  }
  const start = Math.max(0, props.currentStep - 12);
  const end = Math.min(events.length, start + 24);
  return events.slice(start, end);
});

const currentEventLabel = computed(() => {
  const ev =
    props.sortingFrame?.currentEvent ??
    props.pathfindingFrame?.currentEvent ??
    props.cellularFrame?.currentEvent ??
    props.graphFrame?.currentEvent ??
    props.fractalFrame?.currentEvent ??
    props.evolutionFrame?.currentEvent;
  if (!ev) {
    return t.value.inspector.readyToRun;
  }
  return `#${ev.seq} · ${ev.type}`;
});

function formatEventDetails(ev: TraceEvent): string {
  const i = t.value.inspector;
  if (ev.gen !== undefined && ev.alive_count !== undefined) {
    return `${i.detailGen}=${ev.gen} ${i.detailAlive}=${ev.alive_count} (+${ev.born_count ?? 0}/-${ev.died_count ?? 0})`;
  }
  if (ev.gen !== undefined && ev.best_fitness !== undefined) {
    return `${i.detailGen}=${ev.gen} ${i.detailBest}=${Math.round(ev.best_fitness * 100)}% ${i.detailAvg}=${Math.round((ev.avg_fitness ?? 0) * 100)}%`;
  }
  if (ev.from_node !== undefined && ev.to_node !== undefined) {
    return `${ev.from_node} -> ${ev.to_node} (w=${ev.weight ?? 1})`;
  }
  if (ev.node !== undefined && ev.component !== undefined) {
    return `${i.detailNode}=${ev.node} ${i.detailComp}=${ev.component}`;
  }
  if (ev.node !== undefined) {
    return `${i.detailNode}=${ev.node}`;
  }
  if (ev.row !== undefined) {
    return `${i.detailRow}=${ev.row}`;
  }
  if (ev.depth !== undefined && ev.segments) {
    return `${i.detailDepth}=${ev.depth} ${i.detailSegs}=${ev.segments.length}`;
  }
  if (ev.indices) {
    return `${i.detailIndices}=[${ev.indices.join(', ')}]${ev.values ? ` ${i.detailValues}=[${ev.values.join(', ')}]` : ''}`;
  }
  if (ev.range) {
    return `${i.detailRange}=[${ev.range.join(', ')}]`;
  }
  if (ev.pos) {
    return `${i.detailPos}=(${ev.pos.join(', ')})${ev.cost !== undefined ? ` ${i.detailCost}=${ev.cost}` : ''}`;
  }
  if (ev.from && ev.to) {
    return `(${Array.isArray(ev.from) ? ev.from.join(',') : ev.from}) -> (${ev.to.join(',')}) ${i.detailCost}=${ev.cost ?? 0}`;
  }
  if (ev.index !== undefined) {
    return `${i.detailIndex}=${ev.index}${ev.value !== undefined ? ` ${i.detailValue}=${ev.value}` : ''}`;
  }
  if (ev.path) {
    return `${i.detailLength}=${ev.path.length}${ev.total_cost !== undefined ? ` ${i.detailCost}=${ev.total_cost}` : ''}`;
  }
  return '';
}
</script>

<template>
  <aside class="inspector garden-card" :aria-label="t.inspector.ariaLabel">
    <div class="inspector__tabs" role="tablist" :aria-label="t.inspector.tabsAria">
      <button
        id="inspector-tab-overview"
        type="button"
        role="tab"
        :aria-selected="activeTab === 'overview'"
        aria-controls="inspector-panel-overview"
        class="inspector__tab"
        :class="{ 'is-active': activeTab === 'overview' }"
        @click="activeTab = 'overview'"
      >
        <MingcuteIcon name="dashboard-3-line" :size="15" />
        <span>{{ t.inspector.tabOverview }}</span>
      </button>
      <button
        id="inspector-tab-events"
        type="button"
        role="tab"
        :aria-selected="activeTab === 'events'"
        aria-controls="inspector-panel-events"
        class="inspector__tab"
        :class="{ 'is-active': activeTab === 'events' }"
        @click="activeTab = 'events'"
      >
        <MingcuteIcon name="terminal-box-line" :size="15" />
        <span>{{ t.inspector.tabEvents }} ({{ totalSteps }})</span>
      </button>
      <button
        v-if="exerciseResults !== null"
        id="inspector-tab-tests"
        type="button"
        role="tab"
        :aria-selected="activeTab === 'tests'"
        aria-controls="inspector-panel-tests"
        class="inspector__tab"
        :class="{ 'is-active': activeTab === 'tests' }"
        @click="activeTab = 'tests'"
      >
        <MingcuteIcon name="check-circle-line" :size="15" />
        <span>{{ t.inspector.tabTests }} ({{ exerciseResults.length }})</span>
      </button>
    </div>

    <div v-if="execution?.error" class="inspector__error" role="alert">
      <div class="inspector__error-head">
        <MingcuteIcon name="bug-line" :size="16" />
        <strong>
          {{
            t.inspector.errors[execution.error.category] ?? t.inspector.errors.fallback
          }}
        </strong>
        <span v-if="execution.error.line" class="mono">
          {{ t.inspector.lineLabel }} {{ execution.error.line }}
        </span>
      </div>
      <p class="mono">{{ execution.error.message }}</p>
      <small v-if="execution.error.hint">{{ execution.error.hint }}</small>
    </div>

    <div
      v-if="activeTab === 'overview'"
      id="inspector-panel-overview"
      role="tabpanel"
      aria-labelledby="inspector-tab-overview"
      class="inspector__body"
    >
      <div class="stat-grid">
        <div class="stat-pill">
          <span>{{ t.inspector.stepLabel }}</span>
          <strong class="mono">{{ currentStep }} / {{ totalSteps }}</strong>
        </div>
        <div class="stat-pill">
          <span>{{ t.inspector.operationLabel }}</span>
          <strong class="mono">{{ currentEventLabel }}</strong>
        </div>
        <template v-if="sortingFrame">
          <div class="stat-pill">
            <span>{{ t.inspector.comparisonsLabel }}</span>
            <strong class="mono">{{ sortingFrame.counters.comparisons }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.swapsLabel }}</span>
            <strong class="mono">{{ sortingFrame.counters.swaps }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.readsWritesLabel }}</span>
            <strong class="mono">
              {{ sortingFrame.counters.reads }} / {{ sortingFrame.counters.writes }}
            </strong>
          </div>
        </template>
        <template v-if="pathfindingFrame">
          <div class="stat-pill">
            <span>{{ t.inspector.visitedLabel }}</span>
            <strong class="mono">{{ pathfindingFrame.counters.visited }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.frontierLabel }}</span>
            <strong class="mono">{{ pathfindingFrame.counters.frontier }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.pathCostLabel }}</span>
            <strong class="mono">
              {{ pathfindingFrame.totalCost !== null ? pathfindingFrame.totalCost : '—' }}
            </strong>
          </div>
        </template>
        <template v-if="cellularFrame">
          <div class="stat-pill">
            <span>{{ t.inspector.cellularGenLabel }}</span>
            <strong class="mono">{{ cellularFrame.generation }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.cellularAliveLabel }}</span>
            <strong class="mono">{{ cellularFrame.aliveCount }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.cellularDeltaLabel }}</span>
            <strong class="mono">
              +{{ cellularFrame.bornCount }} / -{{ cellularFrame.diedCount }}
            </strong>
          </div>
        </template>
        <template v-if="graphFrame">
          <div class="stat-pill">
            <span>{{ t.inspector.visitedLabel }}</span>
            <strong class="mono">{{ graphFrame.counters.visited }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.graphEdgesLabel }}</span>
            <strong class="mono">{{ graphFrame.counters.inspected }}</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.graphMstLabel }}</span>
            <strong class="mono">
              {{
                graphFrame.mstEdges.length > 0
                  ? graphFrame.counters.mstWeight
                  : graphFrame.path.length > 0
                    ? `${graphFrame.path.length} ${t.inspector.nodesUnit}`
                    : '—'
              }}
            </strong>
          </div>
        </template>
        <template v-if="fractalFrame">
          <div class="stat-pill">
            <span>{{ t.inspector.fractalProgressLabel }}</span>
            <strong class="mono">
              {{
                fractalFrame.mode === 'vector'
                  ? `d=${fractalFrame.currentDepth}`
                  : `${fractalFrame.computedRows}/${fractalFrame.height}`
              }}
            </strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.fractalItemsLabel }}</span>
            <strong class="mono">
              {{
                fractalFrame.mode === 'vector'
                  ? fractalFrame.segments.length
                  : fractalFrame.computedRows * fractalFrame.width
              }}
            </strong>
          </div>
        </template>
        <template v-if="evolutionFrame">
          <div class="stat-pill">
            <span>{{ t.inspector.evoBestLabel }}</span>
            <strong class="mono">{{ Math.round(evolutionFrame.bestFitness * 100) }}%</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.evoAvgLabel }}</span>
            <strong class="mono">{{ Math.round(evolutionFrame.avgFitness * 100) }}%</strong>
          </div>
          <div class="stat-pill">
            <span>{{ t.inspector.evoOpsLabel }}</span>
            <strong class="mono">
              {{ evolutionFrame.counters.crossovers }} / {{ evolutionFrame.counters.mutations }}
            </strong>
          </div>
        </template>
        <div v-if="execution?.metrics" class="stat-pill">
          <span>{{ t.inspector.juliaTimeLabel }}</span>
          <strong class="mono">{{ execution.metrics.elapsed_ms }} ms</strong>
        </div>
      </div>
    </div>

    <div
      v-else-if="activeTab === 'events'"
      id="inspector-panel-events"
      role="tabpanel"
      aria-labelledby="inspector-tab-events"
      class="inspector__body"
    >
      <div v-if="visibleEvents.length === 0" class="inspector__empty">
        {{ t.inspector.emptyEvents }}
      </div>
      <ul v-else class="event-list">
        <li
          v-for="ev in visibleEvents"
          :key="ev.seq"
          class="event-row mono"
          :class="{ 'is-current': ev.seq === currentStep }"
        >
          <span class="event-seq">#{{ ev.seq }}</span>
          <span class="event-type">{{ ev.type }}</span>
          <span class="event-detail">{{ formatEventDetails(ev) }}</span>
        </li>
      </ul>
    </div>

    <div
      v-else-if="activeTab === 'tests' && exerciseResults"
      id="inspector-panel-tests"
      role="tabpanel"
      aria-labelledby="inspector-tab-tests"
      class="inspector__body"
    >
      <div class="test-summary" :class="exercisePassed ? 'is-pass' : 'is-fail'">
        <MingcuteIcon :name="exercisePassed ? 'check-circle-line' : 'alert-line'" :size="16" />
        <span>
          {{ exercisePassed ? t.inspector.testsPassed : t.inspector.testsFailed }}
        </span>
      </div>
      <ul class="test-list">
        <li v-for="tc in exerciseResults" :key="tc.name" class="test-row">
          <MingcuteIcon
            :name="tc.passed ? 'check-circle-line' : 'close-line'"
            :size="16"
            :class="tc.passed ? 'text-pass' : 'text-fail'"
          />
          <div>
            <strong class="mono">{{ tc.name }}</strong>
            <p>{{ tc.message }}</p>
          </div>
        </li>
      </ul>
    </div>
  </aside>
</template>

<style scoped>
.inspector {
  display: flex;
  flex-direction: column;
  padding: 0.85rem;
  gap: 0.75rem;
}

.inspector__tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  border-bottom: 1px solid var(--border-subtle);
  padding-bottom: 0.55rem;
}

.inspector__tab {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  border: 0;
  background: transparent;
  color: var(--text-secondary);
  padding: 0.35rem 0.7rem;
  border-radius: var(--radius-pill);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
}

.inspector__tab.is-active {
  background: var(--accent-primary-soft);
  color: var(--accent-primary);
}

.inspector__error {
  padding: 0.75rem;
  border-radius: var(--radius-md);
  background: var(--status-danger-soft);
  color: var(--status-danger);
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.inspector__error-head {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.85rem;
}

.inspector__error p {
  margin: 0;
  font-size: 0.78rem;
  white-space: pre-wrap;
}

.inspector__error small {
  font-size: 0.76rem;
  opacity: 0.9;
}

.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
  gap: 0.5rem;
}

.stat-pill {
  padding: 0.5rem 0.65rem;
  border-radius: var(--radius-md);
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.stat-pill span {
  font-size: 0.72rem;
  color: var(--text-muted);
}

.stat-pill strong {
  font-size: 0.88rem;
}

.event-list,
.test-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  max-height: 220px;
  overflow-y: auto;
}

.event-row {
  display: grid;
  grid-template-columns: 52px 100px 1fr;
  gap: 0.5rem;
  font-size: 0.74rem;
  padding: 0.3rem 0.5rem;
  border-radius: var(--radius-sm);
  background: var(--bg-elevated);
}

.event-row.is-current {
  background: var(--accent-primary-soft);
  color: var(--accent-primary);
  font-weight: 600;
}

.event-seq {
  color: var(--text-muted);
}

.event-type {
  color: var(--accent-bloom);
}

.event-detail {
  color: var(--text-secondary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.test-summary {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.55rem 0.75rem;
  border-radius: var(--radius-md);
  font-size: 0.84rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.test-summary.is-pass {
  background: var(--accent-primary-soft);
  color: var(--status-success);
}

.test-summary.is-fail {
  background: var(--status-danger-soft);
  color: var(--status-danger);
}

.test-row {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  padding: 0.45rem 0.6rem;
  border-radius: var(--radius-sm);
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
}

.test-row p {
  margin: 0.15rem 0 0;
  font-size: 0.78rem;
  color: var(--text-secondary);
}

.text-pass {
  color: var(--status-success);
}

.text-fail {
  color: var(--status-danger);
}

.inspector__empty {
  font-size: 0.84rem;
  color: var(--text-muted);
  padding: 0.75rem 0;
}
</style>
