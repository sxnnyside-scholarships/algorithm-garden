import type {
  AlgorithmDetail,
  AlgorithmSummary,
  ExerciseSummary,
  GardenSummary,
} from '@/features/catalog/types/catalog';
import type { Locale } from './messages';

interface GardenCopy {
  name: string;
  description: string;
}

interface AlgorithmCopy {
  summary: string;
  concept: string;
  explanation: string;
  visualization_guide: string;
}

interface ExerciseCopy {
  title: string;
  instructions: string;
}

const GARDEN_EN: Record<string, GardenCopy> = {
  sorting: {
    name: 'Sorting Garden',
    description:
      'Compare quadratic and divide-and-conquer sorting strategies through comparisons, swaps, pivots, and partitions.',
  },
  pathfinding: {
    name: 'Pathfinding Garden',
    description:
      'Explore 2D grids with walls and weighted terrain to contrast BFS, DFS, Dijkstra, and A*.',
  },
  cellular: {
    name: 'Cellular Garden',
    description:
      'Explore discrete 2D cellular automata with editable B/S rules, initial patterns, and generation-by-generation evolution.',
  },
  graph: {
    name: 'Graph Garden',
    description:
      'Trace BFS/DFS graph traversals, connected components, and Kruskal minimum spanning trees on weighted networks.',
  },
  fractal: {
    name: 'Fractal Garden',
    description:
      'Experiment with complex-plane escape fractals (Mandelbrot and Julia sets) and recursive botanical geometry with live zoom.',
  },
  evolution: {
    name: 'Evolution Garden',
    description:
      'Inspect tournament selection, single-point crossover, mutation, and fitness convergence in genetic algorithms.',
  },
};

const ALGO_EN: Record<string, AlgorithmCopy> = {
  'bubble-sort': {
    summary: 'Repeatedly compares adjacent pairs and bubbles the largest value to the end.',
    concept: 'Adjacent comparisons, swaps, and early termination on sorted input',
    explanation:
      'Bubble Sort sweeps left to right across the array, swapping inverted neighbors until the largest unsorted value settles at the end of the pass.',
    visualization_guide:
      'Yellow highlights mark active comparisons, coral marks swaps, and emerald bars indicate elements locked in final position.',
  },
  'selection-sort': {
    summary: 'Finds the minimum of the unsorted suffix and swaps it into position.',
    concept: 'Quadratic scan with minimal swaps O(n)',
    explanation:
      'Selection Sort scans the unsorted portion of the array to locate its smallest element and performs at most one swap per pass.',
    visualization_guide:
      'Observe how comparisons are frequent while swaps stay constant per iteration.',
  },
  'insertion-sort': {
    summary: 'Builds a sorted prefix one element at a time via backward shifts.',
    concept: 'Adaptive performance on nearly sorted data',
    explanation:
      'Each new item slides leftward while it remains smaller than elements in the already-sorted prefix.',
    visualization_guide:
      'On nearly sorted presets, watch how total comparisons drop sharply compared to reversed arrays.',
  },
  'merge-sort': {
    summary: 'Splits the array into halves recursively and merges sorted subarrays.',
    concept: 'Divide and conquer with O(n log n) guaranteed runtime',
    explanation:
      'Merge Sort divides the input recursively into halves of size 1, then merges pairs of sorted ranges in ascending order.',
    visualization_guide:
      'Highlighted range brackets show each subarray being merged and in-place writes rebuild the sorted array.',
  },
  'quick-sort': {
    summary: 'Partitions the array around a pivot to sort subranges recursively.',
    concept: 'Lomuto partitioning, pivot selection, and recursion',
    explanation:
      'Partitioning moves elements less than or equal to the pivot to the left, locking the pivot in its final position before recursing.',
    visualization_guide:
      'Violet marks the chosen pivot; watch elements split left and right inside the active range.',
  },
  'heap-sort': {
    summary: 'Builds a binary max-heap in-place and extracts maximums iteratively.',
    concept: 'Heapify invariant and root-to-end extraction',
    explanation:
      'First heapifies the array bottom-up into a max-heap, then swaps the root into the suffix and restores the invariant with sift-down.',
    visualization_guide:
      'Large swaps move the root maximum toward the sorted emerald suffix on the right.',
  },
  bfs: {
    summary:
      'Explores the grid in level-order rings, guaranteeing fewest steps on unweighted maps.',
    concept: 'FIFO queue and shortest path by step count',
    explanation:
      'Breadth-First Search visits all cells at distance k before moving to k + 1, guaranteeing the shortest unweighted route.',
    visualization_guide:
      'The frontier expands concentrically around the start cell; note that BFS ignores weighted terrain.',
  },
  dfs: {
    summary: 'Follows one branch as deep as possible before backtracking.',
    concept: 'LIFO stack exploration and backtracking',
    explanation:
      'Depth-First Search pushes neighbors onto a stack, diving deep into corridors rather than guaranteeing shortest paths.',
    visualization_guide:
      'Notice the winding path shape and how total path length compares against BFS or A*.',
  },
  dijkstra: {
    summary: 'Computes minimum-cost paths on grids with variable terrain weights.',
    concept: 'Edge relaxation and priority ordering by accumulated g(n)',
    explanation:
      'Dijkstra always pops the lowest-cost frontier node g(n) from MinPriorityQueue, routing around expensive weighted cells.',
    visualization_guide:
      'Cells painted with ×5 weight carry higher step costs; watch Dijkstra steer around them when a cheaper detour exists.',
  },
  'a-star': {
    summary: 'Informed search combining accumulated path cost g(n) and Manhattan heuristic h(n).',
    concept: 'Evaluation function f(n) = g(n) + h(n) with admissible heuristic',
    explanation:
      'By adding the admissible Manhattan estimate toward the goal, A* visits far fewer cells than Dijkstra while preserving optimality.',
    visualization_guide:
      'Compare visited cell counts against Dijkstra on the U-Trap and Weighted Swamp presets.',
  },
  'conways-game-of-life': {
    summary: 'Classic 2D cellular automaton governed by B3/S23 rules on a Moore neighborhood.',
    concept: 'Local discrete transitions and emergent oscillators, still lifes, and gliders',
    explanation:
      'Each cell checks its 8 neighbors (`live_neighbors`). Live cells survive with 2 or 3 neighbors; dead cells are born with exactly 3 neighbors.',
    visualization_guide:
      'Click cells to toggle seed states before running; watch bioluminescent blooms emerge generation by generation.',
  },
  'custom-life-rules': {
    summary:
      'Parameterized Life-like variant adding B6 birth (HighLife B36/S23) for self-replicators.',
    concept: 'Exploring the B/S rule space in 2D cellular automata',
    explanation:
      'Queries `rule_born(grid)` and `rule_survive(grid)` dynamically so you can test custom birth and survival rule digits live.',
    visualization_guide:
      'Modify B/S rule digits or starting patterns to compare population growth against standard Conway Life.',
  },
  'brians-brain': {
    summary:
      'Three-state cellular automaton (off → firing → refractory → off) rich in diagonal spaceships.',
    concept: 'Multi-state discrete dynamics and refractory cooldowns',
    explanation:
      'Dead cells with exactly 2 firing neighbors turn firing (1); firing cells become refractory (2); refractory cells reset to off (0).',
    visualization_guide:
      'Watch emerald firing cells leave orchid refractory trails as gliders propagate across the grid.',
  },
  'graph-bfs': {
    summary: 'Level-order traversal finding minimum-hop paths between start and target nodes.',
    concept: 'FIFO queue frontier expansion and shortest unweighted paths',
    explanation:
      'Expands vertices layer by layer using a FIFO queue, marking frontier, visited, and final path edges.',
    visualization_guide:
      'Follow the orchid frontier wave expanding outward until reaching the target bloom node.',
  },
  'graph-dfs': {
    summary: 'Recursive depth-first exploration diving along branches before backtracking.',
    concept: 'Depth-first search trees, backtracking, and reachability',
    explanation:
      'Traverses adjacent neighbors recursively as deep as possible before returning to unvisited branches.',
    visualization_guide:
      'Notice how DFS commits to a deep branch first instead of spreading uniformly like BFS.',
  },
  'kruskal-mst': {
    summary:
      'Greedy Minimum Spanning Tree algorithm sorting weighted edges with Union-Find cycle detection.',
    concept: 'Greedy choice property, disjoint-set union (DSU), and cycle prevention',
    explanation:
      'Sorts edges by increasing weight and accepts every edge linking two distinct connected components.',
    visualization_guide:
      'Rejected cycle edges flash red briefly while accepted MST edges stay highlighted in emerald.',
  },
  'connected-components': {
    summary:
      'Partitions a disconnected graph into maximally connected clusters using multi-source BFS.',
    concept: 'Equivalence classes of graph reachability and component labeling',
    explanation:
      'Iterates through every vertex, launching a BFS from each unvisited root and tagging reachable nodes via `mark_component!`.',
    visualization_guide:
      'Try the Two Islands preset to watch disjoint clusters receive distinct botanical colors.',
  },
  'mandelbrot-set': {
    summary: 'Quadratic escape iteration z ← z² + c sampled across the complex plane.',
    concept: 'Complex dynamics, escape radius |z| ≤ 2, and self-similarity',
    explanation:
      'For each complex coordinate `c = pixel_complex(plane, r, c_col)`, iterates `z = z^2 + c` from `z = 0` until escape or `max_iterations`.',
    visualization_guide:
      'Click anywhere inside the rendered fractal to zoom 2× deeper into boundary filaments.',
  },
  'julia-set': {
    summary:
      'Parametric Julia set iterating z₀ = pixel with a tunable complex constant c = julia_seed(plane).',
    concept: 'Mandelbrot/Julia duality and sensitivity to seed parameter c',
    explanation:
      'Holds constant `c = julia_seed(plane)` fixed across all pixels while initializing `z` at each pixel coordinate.',
    visualization_guide:
      'Tweak Re(c), Im(c), and iteration depth to morph connected spirals into Cantor dust.',
  },
  'recursive-tree': {
    summary: 'Symmetric recursive botanical branching emitting vector segments level by level.',
    concept: 'Geometric recursion, branching angles, and scale attenuation',
    explanation:
      'Splits each stem recursively into rotated scaled branches up to `recursion_depth(plane)`, grouping segments per depth.',
    visualization_guide:
      'Segments color-shift from earthy bark to spring leaves and cherry-blossom tips across recursion depths.',
  },
  'genetic-algorithm': {
    summary:
      'Tournament selection, single-point crossover, bit-flip mutation, and elitism over binary chromosomes.',
    concept: 'Evolutionary optimization and exploration–exploitation balance',
    explanation:
      'Maintains top elites while generating offspring through tournament selection, crossover, and bit mutation to match the target genome.',
    visualization_guide:
      'Track Best vs Average fitness curves alongside live chromosome alignment against the target bitstring.',
  },
  'mutation-hill-climber': {
    summary: 'Elitist stochastic search mutating copies of top individuals without crossover.',
    concept: 'Mutation-driven search vs recombination in genetic algorithms',
    explanation:
      'Clones elite genomes and applies per-locus mutations, illustrating fast local hill climbing and plateau risks.',
    visualization_guide:
      'Compare population diversity and convergence speed against the full Genetic Algorithm.',
  },
};

const EXERCISE_EN: Record<string, ExerciseCopy> = {
  'ex-insertion-sort-complete': {
    title: 'Complete the inner loop of Insertion Sort',
    instructions:
      'Complete `sort_algorithm!(arr)` by shifting each element left while smaller than its predecessor using `compare` and `swap!`.',
  },
  'ex-bubble-sort-early-exit': {
    title: 'Implement ascending Bubble Sort',
    instructions:
      'Sort `arr` in ascending order by comparing adjacent elements and calling `swap!(arr, j, j + 1)`.',
  },
  'ex-quicksort-partition': {
    title: 'Complete Quick Sort partitioning',
    instructions:
      'Perform the final pivot swap inside `partition!(arr, lo, hi)` and return its final index `i + 1`.',
  },
  'ex-mergesort-merge': {
    title: 'Complete the Merge step in Merge Sort',
    instructions:
      'Complete the comparison loop in `merge_ranges!(arr, lo, mid, hi)` to merge both sorted halves back into `arr`.',
  },
  'ex-bfs-shortest-path': {
    title: 'Find the shortest unweighted path with BFS',
    instructions:
      'Complete neighbor exploration inside `find_path(grid)` to return the minimum-hop path from `start_node(grid)` to `goal_node(grid)`.',
  },
  'ex-astar-heuristic': {
    title: 'Add the Manhattan heuristic in A*',
    instructions:
      'Compute `f_score = tentative + manhattan(nxt, g)` when enqueueing neighbors in `MinPriorityQueue`.',
  },
  'ex-dijkstra-weighted': {
    title: 'Relax weighted edges in Dijkstra',
    instructions:
      'Use `step_cost(grid, cur, nxt)` inside `find_path(grid)` to compute `alt = cur_cost + step_cost(grid, cur, nxt)` and relax only if it improves `dist[nxt]`.',
  },
  'ex-cellular-conway': {
    title: "Implement Conway's B3/S23 rules",
    instructions:
      'Complete the cellular transition in `evolve_cellular(grid)` using `live_neighbors(grid, r, c)` and `record_generation!`.',
  },
  'ex-cellular-highlife': {
    title: 'Dynamic HighLife rules (B36/S23)',
    instructions:
      'Query `rule_born(grid)` and `rule_survive(grid)` instead of hardcoded constants so 6-neighbor HighLife births work.',
  },
  'ex-graph-bfs-path': {
    title: 'Minimum-hop path with Graph BFS',
    instructions:
      'Complete the BFS queue loop reconstructing the shortest path from `start_vertex(graph)` to `target_vertex(graph)` and call `mark_graph_path!`.',
  },
  'ex-graph-kruskal': {
    title: "Minimum Spanning Tree with Kruskal's",
    instructions:
      'Sort `graph_edges(graph)` by weight and merge disjoint components while recording tree edges with `mark_tree_edge!(graph, u, v, w)`.',
  },
  'ex-fractal-mandelbrot': {
    title: 'Mandelbrot escape-time loop',
    instructions:
      'Complete `z = z * z + c0` while `abs2(z) <= 4.0` and emit each scanline via `emit_row!(plane, r, vals)`.',
  },
  'ex-evolution-ga': {
    title: 'Crossover and mutation in Genetic Algorithm',
    instructions:
      'Implement selection, single-point crossover, and `mutate_bit` inside `evolve_population(env)` to reach at least `0.90` fitness in 25 generations.',
  },
};

export function localizeGarden(g: GardenSummary, locale: Locale): GardenSummary {
  if (locale === 'es') {
    return g;
  }
  const en = GARDEN_EN[g.slug];
  return en ? { ...g, name: en.name, description: en.description } : g;
}

export function localizeAlgorithm<T extends AlgorithmSummary | AlgorithmDetail>(
  algo: T,
  locale: Locale,
): T {
  if (locale === 'es') {
    return algo;
  }
  const en = ALGO_EN[algo.slug];
  if (!en) {
    return algo;
  }
  if ('concept' in algo) {
    return {
      ...algo,
      summary: en.summary,
      concept: en.concept,
      explanation: en.explanation,
      visualization_guide: en.visualization_guide,
    };
  }
  return { ...algo, summary: en.summary };
}

export function localizeExercise(ex: ExerciseSummary, locale: Locale): ExerciseSummary {
  if (locale === 'es') {
    return ex;
  }
  const en = EXERCISE_EN[ex.id];
  return en ? { ...ex, title: en.title, instructions: en.instructions } : ex;
}
