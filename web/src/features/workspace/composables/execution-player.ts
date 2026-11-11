import { computed, getCurrentInstance, onUnmounted, ref } from 'vue';
import type {
  CellularFrame,
  EvolutionFrame,
  EvolutionHistoryPoint,
  ExecutionResult,
  FractalFrame,
  GraphFrame,
  GraphNodeSpec,
  PathfindingFrame,
  SortingFrame,
  TraceEvent,
} from '../types/execution';

export function computeSortingFrame(execution: ExecutionResult, stepCount: number): SortingFrame {
  const rawValues = (execution.initial_state?.values as number[] | undefined) ?? [];
  const values = [...rawValues];
  const sortedSet = new Set<number>();
  let activeCompare: [number, number] | null = null;
  let activeSwap: [number, number] | null = null;
  let activeWrite: number | null = null;
  let activeRead: number | null = null;
  let activePivot: number | null = null;
  let activeRange: [number, number] | null = null;
  let currentEvent: TraceEvent | null = null;

  const counters = { comparisons: 0, swaps: 0, reads: 0, writes: 0 };
  const limit = Math.max(0, Math.min(stepCount, execution.events.length));

  for (let i = 0; i < limit; i++) {
    const ev = execution.events[i];
    if (!ev) {
      continue;
    }
    currentEvent = ev;
    activeCompare = null;
    activeSwap = null;
    activeWrite = null;
    activeRead = null;

    switch (ev.type) {
      case 'compare':
        counters.comparisons += 1;
        counters.reads += 2;
        if (ev.indices) {
          activeCompare = ev.indices;
        }
        break;
      case 'swap':
        counters.swaps += 1;
        counters.reads += 2;
        counters.writes += 2;
        if (ev.indices) {
          const [a, b] = ev.indices;
          const idxA = a - 1;
          const idxB = b - 1;
          const valA = values[idxA];
          const valB = values[idxB];
          if (valA !== undefined && valB !== undefined) {
            values[idxA] = valB;
            values[idxB] = valA;
          }
          activeSwap = ev.indices;
        }
        break;
      case 'write':
        counters.writes += 1;
        if (ev.index !== undefined && ev.value !== undefined) {
          values[ev.index - 1] = ev.value;
          activeWrite = ev.index;
        }
        break;
      case 'read':
        counters.reads += 1;
        if (ev.index !== undefined) {
          activeRead = ev.index;
        }
        break;
      case 'mark_pivot':
        activePivot = ev.index ?? null;
        break;
      case 'mark_range':
        activeRange = ev.range ?? null;
        break;
      case 'mark_sorted':
        if (ev.index !== undefined) {
          sortedSet.add(ev.index);
        }
        break;
      default:
        break;
    }
  }

  return {
    values,
    activeCompare,
    activeSwap,
    activeWrite,
    activeRead,
    activePivot,
    activeRange,
    sortedIndices: Array.from(sortedSet),
    counters,
    currentEvent,
  };
}

export function computePathfindingFrame(
  execution: ExecutionResult,
  stepCount: number,
): PathfindingFrame {
  const init = execution.initial_state ?? {};
  const rows = Number(init.rows ?? 12);
  const cols = Number(init.cols ?? 18);
  const start = (init.start as [number, number] | undefined) ?? [1, 1];
  const goal = (init.goal as [number, number] | undefined) ?? [rows, cols];
  const walls = (init.walls as [number, number][] | undefined) ?? [];
  const weights = (init.weights as [number, number, number][] | undefined) ?? [];

  const frontierMap = new Map<string, [number, number]>();
  const visitedMap = new Map<string, [number, number]>();
  const cellCosts: Record<string, number> = {};
  let activeCell: [number, number] | null = null;
  let activeEdge: { from: [number, number]; to: [number, number]; cost: number } | null = null;
  let path: [number, number][] = [];
  let totalCost: number | null = null;
  let currentEvent: TraceEvent | null = null;
  const counters = { visited: 0, frontier: 0, relaxed: 0 };

  const keyOf = (pos: [number, number]): string => `${pos[0]}:${pos[1]}`;
  const limit = Math.max(0, Math.min(stepCount, execution.events.length));

  for (let i = 0; i < limit; i++) {
    const ev = execution.events[i];
    if (!ev) {
      continue;
    }
    currentEvent = ev;
    activeEdge = null;

    switch (ev.type) {
      case 'frontier':
        counters.frontier += 1;
        if (ev.pos) {
          const k = keyOf(ev.pos);
          if (!visitedMap.has(k)) {
            frontierMap.set(k, ev.pos);
          }
          if (ev.cost !== undefined) {
            cellCosts[k] = ev.cost;
          }
          activeCell = ev.pos;
        }
        break;
      case 'visit':
        counters.visited += 1;
        if (ev.pos) {
          const k = keyOf(ev.pos);
          frontierMap.delete(k);
          visitedMap.set(k, ev.pos);
          if (ev.cost !== undefined) {
            cellCosts[k] = ev.cost;
          }
          activeCell = ev.pos;
        }
        break;
      case 'relax_edge':
        counters.relaxed += 1;
        if (Array.isArray(ev.from) && Array.isArray(ev.to)) {
          activeEdge = { from: ev.from, to: ev.to, cost: ev.cost ?? 0 };
        }
        break;
      case 'path_found':
        path = Array.isArray(ev.path) ? (ev.path as [number, number][]) : [];
        totalCost = ev.total_cost ?? null;
        break;
      default:
        break;
    }
  }

  return {
    rows,
    cols,
    start,
    goal,
    walls,
    weights,
    frontier: Array.from(frontierMap.values()),
    visited: Array.from(visitedMap.values()),
    cellCosts,
    activeCell,
    activeEdge,
    path,
    totalCost,
    counters,
    currentEvent,
  };
}

export function computeCellularFrame(execution: ExecutionResult, stepCount: number): CellularFrame {
  const init = execution.initial_state ?? {};
  const rows = Number(init.rows ?? 14);
  const cols = Number(init.cols ?? 18);
  const rawCells = (init.cells as number[][] | undefined) ?? [];
  let cells = rawCells.map((row) => [...row]);
  const born = Array.isArray(init.born) ? init.born.map(Number) : [3];
  const survive = Array.isArray(init.survive) ? init.survive.map(Number) : [2, 3];

  let generation = 0;
  let aliveCount = cells.reduce(
    (sum, row) => sum + row.reduce((acc, cell) => acc + (cell === 1 ? 1 : 0), 0),
    0,
  );
  let bornCount = 0;
  let diedCount = 0;
  let currentEvent: TraceEvent | null = null;

  const limit = Math.max(0, Math.min(stepCount, execution.events.length));
  for (let i = 0; i < limit; i++) {
    const ev = execution.events[i];
    if (!ev) {
      continue;
    }
    currentEvent = ev;
    if (ev.type === 'generation' && Array.isArray(ev.cells)) {
      cells = ev.cells.map((row) => [...row]);
      generation = Number(ev.gen ?? generation + 1);
      aliveCount = Number(ev.alive_count ?? aliveCount);
      bornCount = Number(ev.born_count ?? 0);
      diedCount = Number(ev.died_count ?? 0);
    }
  }

  return {
    rows,
    cols,
    cells,
    born,
    survive,
    generation,
    aliveCount,
    bornCount,
    diedCount,
    currentEvent,
  };
}

export function computeGraphFrame(execution: ExecutionResult, stepCount: number): GraphFrame {
  const init = execution.initial_state ?? {};
  const nodes = ((init.nodes as GraphNodeSpec[] | undefined) ?? []).map((n) => ({ ...n }));
  const edges = ((init.edges as [number, number, number][] | undefined) ?? []).map(
    (e) => [Number(e[0]), Number(e[1]), Number(e[2] ?? 1)] as [number, number, number],
  );
  const directed = Boolean(init.directed ?? false);
  const startNode = Number(init.start_node ?? 1);
  const targetNode = Number(init.target_node ?? Math.max(1, nodes.length));

  const visitedSet = new Set<number>();
  const frontierSet = new Set<number>();
  const mstEdges: [number, number, number][] = [];
  const components: Record<number, number> = {};
  let path: number[] = [];
  let activeNode: number | null = null;
  let activeEdge: { from: number; to: number; accepted: boolean; weight: number } | null = null;
  let inspected = 0;
  let mstWeight = 0;
  let currentEvent: TraceEvent | null = null;

  const limit = Math.max(0, Math.min(stepCount, execution.events.length));
  for (let i = 0; i < limit; i++) {
    const ev = execution.events[i];
    if (!ev) {
      continue;
    }
    currentEvent = ev;
    activeEdge = null;
    if (ev.type === 'graph_frontier' && ev.node !== undefined) {
      if (!visitedSet.has(ev.node)) {
        frontierSet.add(ev.node);
      }
      activeNode = ev.node;
    } else if (ev.type === 'graph_visit' && ev.node !== undefined) {
      visitedSet.add(ev.node);
      frontierSet.delete(ev.node);
      activeNode = ev.node;
    } else if (ev.type === 'graph_edge' && ev.from_node !== undefined && ev.to_node !== undefined) {
      inspected += 1;
      activeEdge = {
        from: ev.from_node,
        to: ev.to_node,
        accepted: Boolean(ev.accepted),
        weight: Number(ev.weight ?? 1),
      };
    } else if (
      ev.type === 'graph_mst_edge' &&
      ev.from_node !== undefined &&
      ev.to_node !== undefined
    ) {
      const w = Number(ev.weight ?? 1);
      mstEdges.push([ev.from_node, ev.to_node, w]);
      mstWeight += w;
      activeEdge = { from: ev.from_node, to: ev.to_node, accepted: true, weight: w };
    } else if (
      ev.type === 'graph_component' &&
      ev.node !== undefined &&
      ev.component !== undefined
    ) {
      components[ev.node] = ev.component;
      activeNode = ev.node;
    } else if (ev.type === 'graph_path' && Array.isArray(ev.path)) {
      path = (ev.path as number[]).map(Number);
    }
  }

  return {
    nodes,
    edges,
    directed,
    startNode,
    targetNode,
    visitedNodes: [...visitedSet],
    frontierNodes: [...frontierSet],
    activeNode,
    activeEdge,
    mstEdges,
    components,
    path,
    counters: {
      visited: visitedSet.size,
      frontier: frontierSet.size,
      inspected,
      mstWeight: Number(mstWeight.toFixed(2)),
    },
    currentEvent,
  };
}

export function computeFractalFrame(execution: ExecutionResult, stepCount: number): FractalFrame {
  const init = execution.initial_state ?? {};
  const width = Number(init.width ?? 64);
  const height = Number(init.height ?? 48);
  const mode = String(init.mode ?? 'raster') === 'vector' ? 'vector' : 'raster';
  const rows: number[][] = Array.from({ length: height }, () => Array<number>(width).fill(0));
  const segments: number[][] = [];
  let computedRows = 0;
  let currentDepth = 0;
  let currentEvent: TraceEvent | null = null;
  let detectedMode: 'raster' | 'vector' = mode;

  const limit = Math.max(0, Math.min(stepCount, execution.events.length));
  for (let i = 0; i < limit; i++) {
    const ev = execution.events[i];
    if (!ev) {
      continue;
    }
    currentEvent = ev;
    if (ev.type === 'fractal_row' && ev.row !== undefined && Array.isArray(ev.values)) {
      detectedMode = 'raster';
      const idx = ev.row - 1;
      if (idx >= 0 && idx < height) {
        rows[idx] = (ev.values as number[]).map(Number);
        computedRows += 1;
      }
    } else if (ev.type === 'fractal_segments' && Array.isArray(ev.segments)) {
      detectedMode = 'vector';
      const depth = Number(ev.depth ?? 1);
      currentDepth = Math.max(currentDepth, depth);
      for (const seg of ev.segments) {
        segments.push([
          Number(seg[0] ?? 0),
          Number(seg[1] ?? 0),
          Number(seg[2] ?? 0),
          Number(seg[3] ?? 0),
          Number(seg[4] ?? depth),
        ]);
      }
    }
  }

  return {
    mode: detectedMode,
    width,
    height,
    xMin: Number(init.x_min ?? -2.1),
    xMax: Number(init.x_max ?? 0.8),
    yMin: Number(init.y_min ?? -1.2),
    yMax: Number(init.y_max ?? 1.2),
    maxIter: Number(init.max_iter ?? 40),
    rows,
    computedRows,
    segments,
    currentDepth,
    currentEvent,
  };
}

export function computeEvolutionFrame(
  execution: ExecutionResult,
  stepCount: number,
): EvolutionFrame {
  const init = execution.initial_state ?? {};
  const populationSize = Number(init.population_size ?? 18);
  const chromosomeLength = Number(init.chromosome_length ?? 16);
  const targetGene = Array.isArray(init.target_gene) ? init.target_gene.map(Number) : [];

  let generation = 0;
  let bestFitness = 0;
  let avgFitness = 0;
  let diversity = 0;
  let bestGenome: number[] = [];
  let topGenomes: number[][] = [];
  let topFitnesses: number[] = [];
  const history: EvolutionHistoryPoint[] = [];
  let mutations = 0;
  let crossovers = 0;
  let currentEvent: TraceEvent | null = null;

  const limit = Math.max(0, Math.min(stepCount, execution.events.length));
  for (let i = 0; i < limit; i++) {
    const ev = execution.events[i];
    if (!ev) {
      continue;
    }
    currentEvent = ev;
    if (ev.type === 'evolution_gen') {
      generation = Number(ev.gen ?? generation + 1);
      bestFitness = Number(ev.best_fitness ?? 0);
      avgFitness = Number(ev.avg_fitness ?? 0);
      diversity = Number(ev.diversity ?? 0);
      bestGenome = Array.isArray(ev.best_genome) ? ev.best_genome.map(Number) : [];
      topGenomes = Array.isArray(ev.top_genomes) ? ev.top_genomes.map((g) => [...g]) : [];
      topFitnesses = Array.isArray(ev.top_fitnesses) ? ev.top_fitnesses.map(Number) : [];
      mutations += Number(ev.mutations ?? 0);
      crossovers += Number(ev.crossovers ?? 0);
      history.push({ gen: generation, best: bestFitness, avg: avgFitness, diversity });
    }
  }

  return {
    generation,
    populationSize,
    chromosomeLength,
    targetGene,
    bestFitness,
    avgFitness,
    diversity,
    bestGenome,
    topGenomes,
    topFitnesses,
    history,
    counters: { mutations, crossovers },
    currentEvent,
  };
}

export function useExecutionPlayer() {
  const execution = ref<ExecutionResult | null>(null);
  const currentStep = ref(0);
  const status = ref<'idle' | 'playing' | 'paused' | 'completed'>('idle');
  const speedMultiplier = ref(1);

  let rafId: number | null = null;
  let lastTickMs = 0;
  let accumulatorMs = 0;

  const totalSteps = computed(() => execution.value?.events.length ?? 0);

  const sortingFrame = computed<SortingFrame | null>(() => {
    if (execution.value?.garden !== 'sorting' || !execution.value.initial_state) {
      return null;
    }
    return computeSortingFrame(execution.value, currentStep.value);
  });

  const pathfindingFrame = computed<PathfindingFrame | null>(() => {
    if (execution.value?.garden !== 'pathfinding' || !execution.value.initial_state) {
      return null;
    }
    return computePathfindingFrame(execution.value, currentStep.value);
  });

  const cellularFrame = computed<CellularFrame | null>(() => {
    if (execution.value?.garden !== 'cellular' || !execution.value.initial_state) {
      return null;
    }
    return computeCellularFrame(execution.value, currentStep.value);
  });

  const graphFrame = computed<GraphFrame | null>(() => {
    if (execution.value?.garden !== 'graph' || !execution.value.initial_state) {
      return null;
    }
    return computeGraphFrame(execution.value, currentStep.value);
  });

  const fractalFrame = computed<FractalFrame | null>(() => {
    if (execution.value?.garden !== 'fractal' || !execution.value.initial_state) {
      return null;
    }
    return computeFractalFrame(execution.value, currentStep.value);
  });

  const evolutionFrame = computed<EvolutionFrame | null>(() => {
    if (execution.value?.garden !== 'evolution' || !execution.value.initial_state) {
      return null;
    }
    return computeEvolutionFrame(execution.value, currentStep.value);
  });

  function stopLoop(): void {
    if (rafId !== null && typeof cancelAnimationFrame !== 'undefined') {
      cancelAnimationFrame(rafId);
    }
    rafId = null;
  }

  function stepIntervalMs(): number {
    const garden = execution.value?.garden;
    const base =
      garden === 'sorting'
        ? 75
        : garden === 'pathfinding'
          ? 40
          : garden === 'fractal'
            ? 24
            : garden === 'graph'
              ? 160
              : 140;

    // Dense sorting/pathfinding traces can emit thousands of fine-grained events;
    // cap nominal 1x duration so large inputs finish in a crisp ~12s instead of minutes.
    const steps = totalSteps.value;
    const targetDurationMs =
      garden === 'sorting' || garden === 'pathfinding' ? 12_000 : Number.POSITIVE_INFINITY;
    const adaptiveBase =
      steps > 0 && Number.isFinite(targetDurationMs)
        ? Math.min(base, targetDurationMs / steps)
        : base;

    return Math.max(1.5, adaptiveBase / speedMultiplier.value);
  }

  function tick(nowMs: number): void {
    if (status.value !== 'playing') {
      return;
    }
    if (lastTickMs === 0) {
      lastTickMs = nowMs;
    }
    accumulatorMs += nowMs - lastTickMs;
    lastTickMs = nowMs;

    const interval = stepIntervalMs();
    const advance = Math.floor(accumulatorMs / interval);
    if (advance > 0 && currentStep.value < totalSteps.value) {
      const nextStep = Math.min(totalSteps.value, currentStep.value + advance);
      const consumed = nextStep - currentStep.value;
      currentStep.value = nextStep;
      accumulatorMs -= consumed * interval;
    }

    if (currentStep.value >= totalSteps.value) {
      status.value = 'completed';
      stopLoop();
      return;
    }

    if (typeof requestAnimationFrame !== 'undefined') {
      rafId = requestAnimationFrame(tick);
    }
  }

  function clear(): void {
    stopLoop();
    execution.value = null;
    currentStep.value = 0;
    status.value = 'idle';
  }

  function load(next: ExecutionResult, autoPlay = true): void {
    stopLoop();
    execution.value = next;
    currentStep.value = 0;
    accumulatorMs = 0;
    lastTickMs = 0;

    if (next.status === 'failed' || next.events.length === 0) {
      status.value = next.status === 'completed' ? 'completed' : 'idle';
      return;
    }

    if (autoPlay) {
      play();
    } else {
      status.value = 'paused';
    }
  }

  function play(): void {
    if (!execution.value || totalSteps.value === 0) {
      return;
    }
    if (currentStep.value >= totalSteps.value) {
      currentStep.value = 0;
    }
    stopLoop();
    status.value = 'playing';
    lastTickMs = 0;
    accumulatorMs = 0;
    if (typeof requestAnimationFrame !== 'undefined') {
      rafId = requestAnimationFrame(tick);
    }
  }

  function pause(): void {
    if (status.value === 'playing') {
      stopLoop();
      status.value = 'paused';
    }
  }

  function resume(): void {
    if (status.value === 'paused') {
      play();
    }
  }

  function stepForward(): void {
    pause();
    if (currentStep.value < totalSteps.value) {
      currentStep.value += 1;
      if (currentStep.value >= totalSteps.value) {
        status.value = 'completed';
      }
    }
  }

  function stepBackward(): void {
    pause();
    if (currentStep.value > 0) {
      currentStep.value -= 1;
      status.value = 'paused';
    }
  }

  function seek(step: number): void {
    pause();
    currentStep.value = Math.max(0, Math.min(step, totalSteps.value));
    status.value = currentStep.value >= totalSteps.value ? 'completed' : 'paused';
  }

  function reset(): void {
    stopLoop();
    currentStep.value = 0;
    status.value = totalSteps.value > 0 ? 'paused' : 'idle';
  }

  function setSpeed(mult: number): void {
    speedMultiplier.value = Math.max(0.25, Math.min(8, mult));
  }

  if (getCurrentInstance()) {
    onUnmounted(stopLoop);
  }

  return {
    execution,
    currentStep,
    totalSteps,
    status,
    speedMultiplier,
    sortingFrame,
    pathfindingFrame,
    cellularFrame,
    graphFrame,
    fractalFrame,
    evolutionFrame,
    load,
    clear,
    play,
    pause,
    resume,
    stepForward,
    stepBackward,
    seek,
    reset,
    setSpeed,
  };
}
