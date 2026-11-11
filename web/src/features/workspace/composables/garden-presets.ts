import type {
  CellularFrame,
  EvolutionFrame,
  FractalFrame,
  GraphFrame,
  GraphNodeSpec,
} from '../types/execution';

export type SortingDistribution = 'random' | 'reversed' | 'nearly_sorted' | 'few_unique';
export type PathfindingPresetKey = 'open' | 'u_trap' | 'weighted_swamp' | 'spiral' | 'seeded_maze';
export type CellularPresetKey = 'glider' | 'blinker' | 'r_pentomino' | 'brians_glider' | 'random';
export type GraphPresetKey = 'botanical_web' | 'two_islands' | 'weighted_canopy';

export interface GridSpec {
  rows: number;
  cols: number;
  start: [number, number];
  goal: [number, number];
  walls: [number, number][];
  weights: [number, number, number][];
}

function mulberry32(seed: number): () => number {
  let state = (seed >>> 0) + 0x6d2b79f5;
  return () => {
    state = Math.imul(state ^ (state >>> 15), state | 1);
    state ^= state + Math.imul(state ^ (state >>> 7), state | 61);
    return ((state ^ (state >>> 14)) >>> 0) / 4294967296;
  };
}

export function buildSortingPreviewValues(params: Record<string, unknown>): number[] {
  const custom = params.values;
  if (Array.isArray(custom) && custom.length > 0) {
    return custom.map((v) => Number(v)).filter((n) => Number.isFinite(n));
  }

  const size = Math.max(2, Math.min(80, Number(params.size ?? 18)));
  const dist = String(params.distribution ?? 'random') as SortingDistribution;
  const seed = Number(params.seed ?? 42);
  const rand = mulberry32(seed);

  if (dist === 'reversed') {
    return Array.from({ length: size }, (_, i) => (size - i) * 4);
  }
  if (dist === 'nearly_sorted') {
    const arr = Array.from({ length: size }, (_, i) => (i + 1) * 4);
    const swaps = Math.max(1, Math.floor(size / 8));
    for (let s = 0; s < swaps; s++) {
      const i = Math.floor(rand() * size);
      const j = Math.floor(rand() * size);
      const tmp = arr[i] ?? 0;
      arr[i] = arr[j] ?? 0;
      arr[j] = tmp;
    }
    return arr;
  }
  if (dist === 'few_unique') {
    const palette = [15, 35, 55, 75, 95];
    return Array.from({ length: size }, () => palette[Math.floor(rand() * palette.length)] ?? 55);
  }
  return Array.from({ length: size }, () => 5 + Math.floor(rand() * 96));
}

export function buildMountainPreset(size: number): number[] {
  const clamped = Math.max(4, Math.min(50, size));
  const mid = Math.floor(clamped / 2);
  return Array.from({ length: clamped }, (_, i) => {
    const dist = Math.abs(i - mid);
    return Math.max(8, (mid - dist + 1) * 8);
  });
}

export function buildSawtoothPreset(size: number): number[] {
  const clamped = Math.max(4, Math.min(50, size));
  return Array.from({ length: clamped }, (_, i) => ((i % 5) + 1) * 18);
}

export function normalizeGridSpec(params: Record<string, unknown>): GridSpec {
  const rows = Math.max(4, Math.min(30, Number(params.rows ?? 12)));
  const cols = Math.max(4, Math.min(36, Number(params.cols ?? 18)));

  const clampCoord = (raw: unknown, fallback: [number, number]): [number, number] => {
    if (!Array.isArray(raw) || raw.length < 2) {
      return fallback;
    }
    const r = Math.max(1, Math.min(rows, Math.round(Number(raw[0]))));
    const c = Math.max(1, Math.min(cols, Math.round(Number(raw[1]))));
    return [r, c];
  };

  let start = clampCoord(params.start, [Math.max(1, Math.floor(rows / 2)), 2]);
  let goal = clampCoord(params.goal, [Math.max(1, Math.floor(rows / 2)), Math.max(2, cols - 1)]);
  if (start[0] === goal[0] && start[1] === goal[1]) {
    start = [1, 1];
    goal = [rows, cols];
  }

  const startKey = `${start[0]}:${start[1]}`;
  const goalKey = `${goal[0]}:${goal[1]}`;

  const rawWalls = Array.isArray(params.walls) ? params.walls : [];
  const wallSet = new Set<string>();
  const walls: [number, number][] = [];
  for (const w of rawWalls) {
    if (!Array.isArray(w) || w.length < 2) {
      continue;
    }
    const r = Math.round(Number(w[0]));
    const c = Math.round(Number(w[1]));
    if (r < 1 || r > rows || c < 1 || c > cols) {
      continue;
    }
    const key = `${r}:${c}`;
    if (key === startKey || key === goalKey || wallSet.has(key)) {
      continue;
    }
    wallSet.add(key);
    walls.push([r, c]);
  }

  const rawWeights = Array.isArray(params.weights) ? params.weights : [];
  const weightSet = new Set<string>();
  const weights: [number, number, number][] = [];
  for (const item of rawWeights) {
    if (!Array.isArray(item) || item.length < 3) {
      continue;
    }
    const r = Math.round(Number(item[0]));
    const c = Math.round(Number(item[1]));
    const cost = Number(item[2]);
    const key = `${r}:${c}`;
    if (
      r < 1 ||
      r > rows ||
      c < 1 ||
      c > cols ||
      cost <= 0 ||
      key === startKey ||
      key === goalKey ||
      wallSet.has(key) ||
      weightSet.has(key)
    ) {
      continue;
    }
    weightSet.add(key);
    weights.push([r, c, cost]);
  }

  return { rows, cols, start, goal, walls, weights };
}

export function buildGridPreset(
  preset: PathfindingPresetKey,
  rows: number,
  cols: number,
  seed: number,
): GridSpec {
  const safeRows = Math.max(6, Math.min(24, rows));
  const safeCols = Math.max(6, Math.min(30, cols));
  const midRow = Math.max(2, Math.floor(safeRows / 2));
  const start: [number, number] = [midRow, 2];
  const goal: [number, number] = [midRow, safeCols - 1];
  const walls: [number, number][] = [];
  const weights: [number, number, number][] = [];

  if (preset === 'open') {
    return { rows: safeRows, cols: safeCols, start, goal, walls, weights };
  }

  if (preset === 'u_trap') {
    const colWall = Math.floor(safeCols * 0.58);
    const top = Math.max(2, midRow - Math.floor(safeRows / 3));
    const bot = Math.min(safeRows - 1, midRow + Math.floor(safeRows / 3));
    for (let r = top; r <= bot; r++) {
      walls.push([r, colWall]);
    }
    for (let c = Math.max(3, colWall - 3); c < colWall; c++) {
      walls.push([top, c]);
      walls.push([bot, c]);
    }
    return normalizeGridSpec({ rows: safeRows, cols: safeCols, start, goal, walls, weights });
  }

  if (preset === 'weighted_swamp') {
    const midCol = Math.floor(safeCols / 2);
    for (let r = 2; r <= safeRows - 1; r++) {
      for (let c = midCol - 1; c <= midCol + 1; c++) {
        weights.push([r, c, 5.0]);
      }
    }
    walls.push(
      [2, midCol - 3],
      [3, midCol - 3],
      [safeRows - 1, midCol + 3],
      [safeRows - 2, midCol + 3],
    );
    return normalizeGridSpec({ rows: safeRows, cols: safeCols, start, goal, walls, weights });
  }

  if (preset === 'spiral') {
    let top = 2;
    let bottom = safeRows - 1;
    let left = 4;
    let right = safeCols - 3;
    while (top <= bottom && left <= right) {
      for (let c = left; c <= right; c++) {
        walls.push([top, c]);
      }
      top += 2;
      for (let r = top - 1; r <= bottom; r++) {
        walls.push([r, right]);
      }
      right -= 2;
      if (top <= bottom) {
        for (let c = right + 1; c >= left + 1; c--) {
          walls.push([bottom, c]);
        }
        bottom -= 2;
      }
      if (left <= right) {
        for (let r = bottom + 1; r >= top; r--) {
          walls.push([r, left]);
        }
        left += 2;
      }
    }
    return normalizeGridSpec({
      rows: safeRows,
      cols: safeCols,
      start: [1, 1],
      goal: [Math.ceil(safeRows / 2), Math.ceil(safeCols / 2)],
      walls,
      weights,
    });
  }

  // seeded_maze: deterministic vertical ribs with staggered openings + occasional swamp weights
  const rand = mulberry32(seed);
  for (let c = 3; c <= safeCols - 2; c += 2) {
    const gap1 = 1 + Math.floor(rand() * safeRows);
    const gap2 = 1 + Math.floor(rand() * safeRows);
    for (let r = 1; r <= safeRows; r++) {
      if (r === gap1 || r === gap2) {
        if (rand() < 0.35) {
          weights.push([r, c, 5.0]);
        }
      } else {
        walls.push([r, c]);
      }
    }
  }
  return normalizeGridSpec({
    rows: safeRows,
    cols: safeCols,
    start: [1, 1],
    goal: [safeRows, safeCols],
    walls,
    weights,
  });
}

export function buildCellularPresetCells(
  preset: CellularPresetKey,
  rows: number,
  cols: number,
  seed = 42,
): number[][] {
  const safeRows = Math.max(2, Math.min(48, Math.round(rows)));
  const safeCols = Math.max(2, Math.min(48, Math.round(cols)));
  const mat = Array.from({ length: safeRows }, () => Array<number>(safeCols).fill(0));
  const mr = Math.max(1, Math.floor(safeRows / 2) - 1);
  const mc = Math.max(1, Math.floor(safeCols / 2) - 1);

  const put = (rIdx: number, cIdx: number, val = 1) => {
    const rr = Math.max(0, Math.min(safeRows - 1, rIdx));
    const cc = Math.max(0, Math.min(safeCols - 1, cIdx));
    const row = mat[rr];
    if (row) {
      row[cc] = val;
    }
  };

  if (preset === 'blinker') {
    for (const dc of [-1, 0, 1]) {
      put(mr, mc + dc, 1);
    }
  } else if (preset === 'r_pentomino') {
    for (const [dr, dc] of [
      [0, 0],
      [0, 1],
      [-1, 0],
      [1, 0],
      [-1, -1],
    ] as const) {
      put(mr + dr, mc + dc, 1);
    }
  } else if (preset === 'brians_glider') {
    for (const [dr, dc] of [
      [0, 0],
      [0, 1],
      [1, -1],
      [1, 2],
    ] as const) {
      put(mr + dr, mc + dc, 1);
    }
    for (const [dr, dc] of [
      [-1, 0],
      [-1, 1],
    ] as const) {
      put(mr + dr, mc + dc, 2);
    }
  } else if (preset === 'random') {
    const rand = mulberry32(seed);
    for (let r = 0; r < safeRows; r++) {
      for (let c = 0; c < safeCols; c++) {
        put(r, c, rand() < 0.32 ? 1 : 0);
      }
    }
  } else {
    const r0 = Math.max(0, Math.min(safeRows - 4, 1));
    const c0 = Math.max(0, Math.min(safeCols - 4, 1));
    for (const [dr, dc] of [
      [0, 1],
      [1, 2],
      [2, 0],
      [2, 1],
      [2, 2],
    ] as const) {
      if (r0 + dr < safeRows && c0 + dc < safeCols) {
        put(r0 + dr, c0 + dc, 1);
      }
    }
  }

  return mat;
}

export function buildCellularPreview(params: Record<string, unknown>): CellularFrame {
  const rows = Math.max(2, Math.min(48, Math.round(Number(params.rows ?? 14))));
  const cols = Math.max(2, Math.min(48, Math.round(Number(params.cols ?? 18))));
  const born = Array.isArray(params.born) ? params.born.map((n) => Number(n)) : [3];
  const survive = Array.isArray(params.survive) ? params.survive.map((n) => Number(n)) : [2, 3];
  let cells: number[][];

  if (
    Array.isArray(params.cells) &&
    params.cells.length === rows &&
    params.cells.every((r) => Array.isArray(r) && r.length === cols)
  ) {
    cells = params.cells.map((row) => (row as unknown[]).map((v) => Number(v) || 0));
  } else if (Array.isArray(params.live_cells)) {
    cells = Array.from({ length: rows }, () => Array<number>(cols).fill(0));
    for (const item of params.live_cells) {
      if (!Array.isArray(item) || item.length < 2) {
        continue;
      }
      const r = Math.round(Number(item[0])) - 1;
      const c = Math.round(Number(item[1])) - 1;
      const st = item.length >= 3 ? Number(item[2]) || 1 : 1;
      if (r >= 0 && r < rows && c >= 0 && c < cols && cells[r]) {
        cells[r][c] = st;
      }
    }
  } else {
    const preset = String(params.preset ?? 'glider') as CellularPresetKey;
    cells = buildCellularPresetCells(preset, rows, cols);
  }

  const aliveCount = cells.reduce(
    (sum, row) => sum + row.reduce((acc, cell) => acc + (cell === 1 ? 1 : 0), 0),
    0,
  );

  return {
    rows,
    cols,
    cells,
    born,
    survive,
    generation: 0,
    aliveCount,
    bornCount: 0,
    diedCount: 0,
    currentEvent: null,
  };
}

export function buildGraphPreset(preset: GraphPresetKey): {
  nodes: GraphNodeSpec[];
  edges: [number, number, number][];
  startNode: number;
  targetNode: number;
} {
  if (preset === 'two_islands') {
    return {
      nodes: [
        { id: 1, label: 'A', x: 18, y: 28 },
        { id: 2, label: 'B', x: 36, y: 22 },
        { id: 3, label: 'C', x: 34, y: 52 },
        { id: 4, label: 'D', x: 16, y: 66 },
        { id: 5, label: 'E', x: 66, y: 26 },
        { id: 6, label: 'F', x: 84, y: 42 },
        { id: 7, label: 'G', x: 70, y: 72 },
        { id: 8, label: 'H', x: 48, y: 82 },
      ],
      edges: [
        [1, 2, 1],
        [2, 3, 2],
        [3, 4, 1],
        [1, 3, 3],
        [5, 6, 1],
        [6, 7, 2],
        [5, 7, 4],
      ],
      startNode: 1,
      targetNode: 7,
    };
  }

  if (preset === 'weighted_canopy') {
    return {
      nodes: [
        { id: 1, label: 'Root', x: 14, y: 50 },
        { id: 2, label: 'Fern', x: 35, y: 20 },
        { id: 3, label: 'Moss', x: 35, y: 80 },
        { id: 4, label: 'Lotus', x: 60, y: 22 },
        { id: 5, label: 'Iris', x: 58, y: 78 },
        { id: 6, label: 'Crown', x: 86, y: 50 },
      ],
      edges: [
        [1, 2, 4],
        [1, 3, 2],
        [2, 3, 1],
        [2, 4, 5],
        [3, 4, 8],
        [3, 5, 6],
        [4, 5, 2],
        [4, 6, 3],
        [5, 6, 7],
      ],
      startNode: 1,
      targetNode: 6,
    };
  }

  return {
    nodes: [
      { id: 1, label: '1', x: 16, y: 50 },
      { id: 2, label: '2', x: 36, y: 20 },
      { id: 3, label: '3', x: 36, y: 80 },
      { id: 4, label: '4', x: 60, y: 24 },
      { id: 5, label: '5', x: 60, y: 76 },
      { id: 6, label: '6', x: 84, y: 50 },
      { id: 7, label: '7', x: 48, y: 50 },
    ],
    edges: [
      [1, 2, 2],
      [1, 3, 3],
      [2, 4, 4],
      [2, 7, 1],
      [3, 5, 2],
      [3, 7, 3],
      [7, 4, 2],
      [7, 5, 1],
      [4, 6, 3],
      [5, 6, 2],
    ],
    startNode: 1,
    targetNode: 6,
  };
}

export function buildGraphPreview(params: Record<string, unknown>): GraphFrame {
  const directed = Boolean(params.directed ?? false);
  const preset = String(params.preset ?? 'botanical_web') as GraphPresetKey;
  const fallback = buildGraphPreset(preset);

  let nodes = fallback.nodes;
  let edges = fallback.edges;
  if (Array.isArray(params.nodes) && params.nodes.length > 0) {
    nodes = params.nodes.map((raw, idx) => {
      const nd = raw as Record<string, unknown>;
      const id = Number(nd.id ?? idx + 1);
      return {
        id,
        label: String(nd.label ?? id),
        x: Number(nd.x ?? 50),
        y: Number(nd.y ?? 50),
      };
    });
    edges = Array.isArray(params.edges)
      ? params.edges
          .filter((e): e is unknown[] => Array.isArray(e) && e.length >= 2)
          .map((e) => [Number(e[0]), Number(e[1]), Number(e[2] ?? 1)] as [number, number, number])
      : [];
  }

  const maxId = Math.max(1, nodes.length);
  const startNode = Math.max(1, Math.min(maxId, Number(params.start_node ?? fallback.startNode)));
  const targetNode = Math.max(
    1,
    Math.min(maxId, Number(params.target_node ?? fallback.targetNode)),
  );

  return {
    nodes,
    edges,
    directed,
    startNode,
    targetNode,
    visitedNodes: [],
    frontierNodes: [],
    activeNode: null,
    activeEdge: null,
    mstEdges: [],
    components: {},
    path: [],
    counters: { visited: 0, frontier: 0, inspected: 0, mstWeight: 0 },
    currentEvent: null,
  };
}

export function buildFractalPreview(
  params: Record<string, unknown>,
  algorithmSlug = '',
): FractalFrame {
  const width = Math.max(16, Math.min(160, Number(params.width ?? 64)));
  const height = Math.max(12, Math.min(120, Number(params.height ?? 48)));
  const mode = algorithmSlug === 'recursive-tree' ? 'vector' : 'raster';
  return {
    mode,
    width,
    height,
    xMin: Number(params.x_min ?? -2.1),
    xMax: Number(params.x_max ?? 0.8),
    yMin: Number(params.y_min ?? -1.2),
    yMax: Number(params.y_max ?? 1.2),
    maxIter: Math.max(5, Math.min(200, Number(params.max_iter ?? 40))),
    rows: [],
    computedRows: 0,
    segments: [],
    currentDepth: 0,
    currentEvent: null,
  };
}

export function buildEvolutionPreview(params: Record<string, unknown>): EvolutionFrame {
  const popSize = Math.max(4, Math.min(60, Number(params.population_size ?? 18)));
  const chromLen = Math.max(4, Math.min(32, Number(params.chromosome_length ?? 16)));
  const rawTarget = params.target_gene;
  const targetGene =
    Array.isArray(rawTarget) && rawTarget.length === chromLen
      ? rawTarget.map((x) => (Number(x) !== 0 ? 1 : 0))
      : Array.from({ length: chromLen }, (_, i) => (i + 1) % 2);

  return {
    generation: 0,
    populationSize: popSize,
    chromosomeLength: chromLen,
    targetGene,
    bestFitness: 0,
    avgFitness: 0,
    diversity: 0,
    bestGenome: [],
    topGenomes: [],
    topFitnesses: [],
    history: [],
    counters: { mutations: 0, crossovers: 0 },
    currentEvent: null,
  };
}
