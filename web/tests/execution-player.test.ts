import { describe, expect, it } from 'vitest';
import {
  computePathfindingFrame,
  computeSortingFrame,
  useExecutionPlayer,
} from '@/features/workspace/composables/execution-player';
import type { ExecutionResult } from '@/features/workspace/types/execution';

const sampleSorting: ExecutionResult = {
  status: 'completed',
  garden: 'sorting',
  algorithm: 'bubble-sort',
  initial_state: { values: [9, 3, 5] },
  events: [
    { seq: 1, type: 'compare', indices: [1, 2] },
    { seq: 2, type: 'swap', indices: [1, 2], values: [3, 9] },
    { seq: 3, type: 'mark_sorted', index: 3 },
  ],
  final_state: { values: [3, 9, 5] },
  metrics: {
    comparisons: 1,
    swaps: 1,
    reads: 4,
    writes: 2,
    nodes_visited: 0,
    frontier_enqueued: 0,
    edges_relaxed: 0,
    total_events: 3,
    elapsed_ms: 1.2,
  },
  tests: null,
  error: null,
};

const samplePathfinding: ExecutionResult = {
  status: 'completed',
  garden: 'pathfinding',
  algorithm: 'bfs',
  initial_state: {
    rows: 3,
    cols: 3,
    start: [1, 1],
    goal: [3, 3],
    walls: [[1, 2]],
    weights: [],
  },
  events: [
    { seq: 1, type: 'frontier', pos: [1, 1] },
    { seq: 2, type: 'visit', pos: [1, 1] },
    { seq: 3, type: 'frontier', pos: [2, 1] },
    {
      seq: 4,
      type: 'path_found',
      path: [
        [1, 1],
        [2, 1],
        [3, 1],
        [3, 2],
        [3, 3],
      ],
      total_cost: 4,
    },
  ],
  final_state: { found: true, total_cost: 4 },
  metrics: null,
  tests: null,
  error: null,
};

describe('ExecutionPlayer deterministic frame reconstruction', () => {
  it('reconstructs sorting state step by step and supports backward stepping', () => {
    const f0 = computeSortingFrame(sampleSorting, 0);
    expect(f0.values).toEqual([9, 3, 5]);
    expect(f0.counters.comparisons).toBe(0);

    const f1 = computeSortingFrame(sampleSorting, 1);
    expect(f1.activeCompare).toEqual([1, 2]);
    expect(f1.counters.comparisons).toBe(1);

    const f2 = computeSortingFrame(sampleSorting, 2);
    expect(f2.values).toEqual([3, 9, 5]);
    expect(f2.counters.swaps).toBe(1);

    const f3 = computeSortingFrame(sampleSorting, 3);
    expect(f3.sortedIndices).toEqual([3]);
  });

  it('reconstructs pathfinding frontier, visited, and final path', () => {
    const f2 = computePathfindingFrame(samplePathfinding, 2);
    expect(f2.visited).toEqual([[1, 1]]);
    expect(f2.frontier).toEqual([]);

    const f4 = computePathfindingFrame(samplePathfinding, 4);
    expect(f4.path).toHaveLength(5);
    expect(f4.totalCost).toBe(4);
  });

  it('steps forward, backward, seeks, and resets cleanly', () => {
    const player = useExecutionPlayer();
    player.load(sampleSorting, false);
    expect(player.currentStep.value).toBe(0);
    expect(player.status.value).toBe('paused');

    player.stepForward();
    expect(player.currentStep.value).toBe(1);
    player.stepForward();
    expect(player.sortingFrame.value?.values).toEqual([3, 9, 5]);

    player.stepBackward();
    expect(player.currentStep.value).toBe(1);
    expect(player.sortingFrame.value?.values).toEqual([9, 3, 5]);

    player.seek(3);
    expect(player.status.value).toBe('completed');

    player.reset();
    expect(player.currentStep.value).toBe(0);
    expect(player.status.value).toBe('paused');
  });
});
