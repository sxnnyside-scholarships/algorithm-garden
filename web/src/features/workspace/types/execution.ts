import type { GardenSlug } from '@/features/catalog/types/catalog';

export interface TraceEvent {
  seq: number;
  type:
    | 'compare'
    | 'swap'
    | 'write'
    | 'read'
    | 'mark_pivot'
    | 'mark_range'
    | 'mark_sorted'
    | 'frontier'
    | 'visit'
    | 'relax_edge'
    | 'path_found'
    | 'generation'
    | 'graph_frontier'
    | 'graph_visit'
    | 'graph_edge'
    | 'graph_component'
    | 'graph_mst_edge'
    | 'graph_path'
    | 'fractal_row'
    | 'fractal_segments'
    | 'evolution_gen';
  indices?: [number, number];
  values?: [number, number] | number[];
  index?: number;
  value?: number;
  range?: [number, number];
  pos?: [number, number];
  from?: [number, number] | number;
  to?: [number, number];
  cost?: number;
  path?: [number, number][] | number[];
  total_cost?: number;
  gen?: number;
  cells?: number[][];
  alive_count?: number;
  born_count?: number;
  died_count?: number;
  node?: number;
  component?: number;
  from_node?: number;
  to_node?: number;
  weight?: number;
  accepted?: boolean;
  row?: number;
  max_iter?: number;
  depth?: number;
  segments?: number[][];
  best_fitness?: number;
  avg_fitness?: number;
  diversity?: number;
  best_genome?: number[];
  top_genomes?: number[][];
  top_fitnesses?: number[];
  mutations?: number;
  crossovers?: number;
}

export interface ExecutionError {
  category: 'syntax' | 'runtime' | 'timeout' | 'resource_limit' | 'contract_violation';
  message: string;
  line: number | null;
  hint: string;
}

export interface ExerciseTestResult {
  name: string;
  passed: boolean;
  message: string;
}

export interface ExecutionMetrics {
  comparisons: number;
  swaps: number;
  reads: number;
  writes: number;
  nodes_visited: number;
  frontier_enqueued: number;
  edges_relaxed: number;
  generations_simulated?: number;
  pixels_computed?: number;
  segments_drawn?: number;
  evaluations?: number;
  mutations?: number;
  crossovers?: number;
  total_events: number;
  elapsed_ms: number;
}

export interface ExecutionResult {
  status: 'completed' | 'failed';
  garden: GardenSlug | string;
  algorithm: string;
  initial_state: Record<string, unknown> | null;
  events: TraceEvent[];
  final_state: Record<string, unknown> | null;
  metrics: ExecutionMetrics | null;
  tests: ExerciseTestResult[] | null;
  error: ExecutionError | null;
}

export interface SortingFrame {
  values: number[];
  activeCompare: [number, number] | null;
  activeSwap: [number, number] | null;
  activeWrite: number | null;
  activeRead: number | null;
  activePivot: number | null;
  activeRange: [number, number] | null;
  sortedIndices: number[];
  counters: {
    comparisons: number;
    swaps: number;
    reads: number;
    writes: number;
  };
  currentEvent: TraceEvent | null;
}

export interface PathfindingFrame {
  rows: number;
  cols: number;
  start: [number, number];
  goal: [number, number];
  walls: [number, number][];
  weights: [number, number, number][];
  frontier: [number, number][];
  visited: [number, number][];
  cellCosts: Record<string, number>;
  activeCell: [number, number] | null;
  activeEdge: { from: [number, number]; to: [number, number]; cost: number } | null;
  path: [number, number][];
  totalCost: number | null;
  counters: {
    visited: number;
    frontier: number;
    relaxed: number;
  };
  currentEvent: TraceEvent | null;
}

export interface CellularFrame {
  rows: number;
  cols: number;
  cells: number[][];
  born: number[];
  survive: number[];
  generation: number;
  aliveCount: number;
  bornCount: number;
  diedCount: number;
  currentEvent: TraceEvent | null;
}

export interface GraphNodeSpec {
  id: number;
  label: string;
  x: number;
  y: number;
}

export interface GraphFrame {
  nodes: GraphNodeSpec[];
  edges: [number, number, number][];
  directed: boolean;
  startNode: number;
  targetNode: number;
  visitedNodes: number[];
  frontierNodes: number[];
  activeNode: number | null;
  activeEdge: { from: number; to: number; accepted: boolean; weight: number } | null;
  mstEdges: [number, number, number][];
  components: Record<number, number>;
  path: number[];
  counters: {
    visited: number;
    frontier: number;
    inspected: number;
    mstWeight: number;
  };
  currentEvent: TraceEvent | null;
}

export interface FractalFrame {
  mode: 'raster' | 'vector';
  width: number;
  height: number;
  xMin: number;
  xMax: number;
  yMin: number;
  yMax: number;
  maxIter: number;
  rows: number[][];
  computedRows: number;
  segments: number[][];
  currentDepth: number;
  currentEvent: TraceEvent | null;
}

export interface EvolutionHistoryPoint {
  gen: number;
  best: number;
  avg: number;
  diversity: number;
}

export interface EvolutionFrame {
  generation: number;
  populationSize: number;
  chromosomeLength: number;
  targetGene: number[];
  bestFitness: number;
  avgFitness: number;
  diversity: number;
  bestGenome: number[];
  topGenomes: number[][];
  topFitnesses: number[];
  history: EvolutionHistoryPoint[];
  counters: {
    mutations: number;
    crossovers: number;
  };
  currentEvent: TraceEvent | null;
}
