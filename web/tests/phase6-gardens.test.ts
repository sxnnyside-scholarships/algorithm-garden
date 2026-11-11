import { describe, expect, it } from 'vitest';
import {
  computeCellularFrame,
  computeEvolutionFrame,
  computeFractalFrame,
  computeGraphFrame,
} from '@/features/workspace/composables/execution-player';
import {
  buildCellularPreview,
  buildEvolutionPreview,
  buildFractalPreview,
  buildGraphPreview,
} from '@/features/workspace/composables/garden-presets';
import type { ExecutionResult } from '@/features/workspace/types/execution';

describe('Phase 6 Gardens frame reconstruction & presets', () => {
  it('reconstructs cellular generations across steps', () => {
    const exec: ExecutionResult = {
      status: 'completed',
      garden: 'cellular',
      algorithm: 'conways-game-of-life',
      initial_state: {
        rows: 3,
        cols: 3,
        cells: [
          [0, 0, 0],
          [1, 1, 1],
          [0, 0, 0],
        ],
        born: [3],
        survive: [2, 3],
      },
      events: [
        {
          seq: 1,
          type: 'generation',
          gen: 1,
          cells: [
            [0, 1, 0],
            [0, 1, 0],
            [0, 1, 0],
          ],
          alive_count: 3,
          born_count: 2,
          died_count: 2,
        },
      ],
      final_state: null,
      metrics: null,
      tests: null,
      error: null,
    };

    const f0 = computeCellularFrame(exec, 0);
    expect(f0.generation).toBe(0);
    expect(f0.cells[1]).toEqual([1, 1, 1]);

    const f1 = computeCellularFrame(exec, 1);
    expect(f1.generation).toBe(1);
    expect(f1.aliveCount).toBe(3);
    expect(f1.bornCount).toBe(2);
    expect(f1.cells[0]?.[1]).toBe(1);
  });

  it('reconstructs graph visits, MST edges, components, and paths', () => {
    const exec: ExecutionResult = {
      status: 'completed',
      garden: 'graph',
      algorithm: 'kruskal-mst',
      initial_state: {
        nodes: [
          { id: 1, label: 'A', x: 10, y: 50 },
          { id: 2, label: 'B', x: 50, y: 20 },
          { id: 3, label: 'C', x: 90, y: 50 },
        ],
        edges: [
          [1, 2, 2],
          [2, 3, 3],
          [1, 3, 9],
        ],
        directed: false,
        start_node: 1,
        target_node: 3,
      },
      events: [
        { seq: 1, type: 'graph_frontier', node: 1 },
        { seq: 2, type: 'graph_visit', node: 1 },
        { seq: 3, type: 'graph_mst_edge', from_node: 1, to_node: 2, weight: 2 },
        { seq: 4, type: 'graph_mst_edge', from_node: 2, to_node: 3, weight: 3 },
        { seq: 5, type: 'graph_component', node: 1, component: 1 },
        { seq: 6, type: 'graph_path', path: [1, 2, 3], total_cost: 5 },
      ],
      final_state: null,
      metrics: null,
      tests: null,
      error: null,
    };

    const frame = computeGraphFrame(exec, 6);
    expect(frame.visitedNodes).toEqual([1]);
    expect(frame.mstEdges).toHaveLength(2);
    expect(frame.counters.mstWeight).toBe(5);
    expect(frame.components[1]).toBe(1);
    expect(frame.path).toEqual([1, 2, 3]);
  });

  it('reconstructs raster and vector fractals progressively', () => {
    const rasterExec: ExecutionResult = {
      status: 'completed',
      garden: 'fractal',
      algorithm: 'mandelbrot-set',
      initial_state: { width: 4, height: 2, max_iter: 20, mode: 'raster' },
      events: [
        { seq: 1, type: 'fractal_row', row: 1, values: [1, 2, 20, 3] },
        { seq: 2, type: 'fractal_row', row: 2, values: [2, 20, 20, 4] },
      ],
      final_state: null,
      metrics: null,
      tests: null,
      error: null,
    };
    const r1 = computeFractalFrame(rasterExec, 1);
    expect(r1.mode).toBe('raster');
    expect(r1.computedRows).toBe(1);
    expect(r1.rows[0]).toEqual([1, 2, 20, 3]);

    const vectorExec: ExecutionResult = {
      status: 'completed',
      garden: 'fractal',
      algorithm: 'recursive-tree',
      initial_state: { width: 4, height: 2, mode: 'vector' },
      events: [
        { seq: 1, type: 'fractal_segments', depth: 1, segments: [[0, -1, 0, 0, 1]] },
        {
          seq: 2,
          type: 'fractal_segments',
          depth: 2,
          segments: [
            [0, 0, -0.5, 0.5, 2],
            [0, 0, 0.5, 0.5, 2],
          ],
        },
      ],
      final_state: null,
      metrics: null,
      tests: null,
      error: null,
    };
    const v2 = computeFractalFrame(vectorExec, 2);
    expect(v2.mode).toBe('vector');
    expect(v2.currentDepth).toBe(2);
    expect(v2.segments).toHaveLength(3);
  });

  it('reconstructs evolutionary convergence history and counters', () => {
    const exec: ExecutionResult = {
      status: 'completed',
      garden: 'evolution',
      algorithm: 'genetic-algorithm',
      initial_state: { population_size: 12, chromosome_length: 4, target_gene: [1, 0, 1, 0] },
      events: [
        {
          seq: 1,
          type: 'evolution_gen',
          gen: 1,
          best_fitness: 0.75,
          avg_fitness: 0.5,
          diversity: 0.4,
          best_genome: [1, 0, 1, 1],
          top_genomes: [[1, 0, 1, 1]],
          top_fitnesses: [0.75],
          mutations: 2,
          crossovers: 4,
        },
        {
          seq: 2,
          type: 'evolution_gen',
          gen: 2,
          best_fitness: 1.0,
          avg_fitness: 0.85,
          diversity: 0.2,
          best_genome: [1, 0, 1, 0],
          top_genomes: [[1, 0, 1, 0]],
          top_fitnesses: [1.0],
          mutations: 1,
          crossovers: 3,
        },
      ],
      final_state: null,
      metrics: null,
      tests: null,
      error: null,
    };

    const frame = computeEvolutionFrame(exec, 2);
    expect(frame.generation).toBe(2);
    expect(frame.bestFitness).toBe(1.0);
    expect(frame.history).toHaveLength(2);
    expect(frame.counters.mutations).toBe(3);
    expect(frame.counters.crossovers).toBe(7);
  });

  it('builds consistent default previews for all Phase 6 gardens', () => {
    expect(buildCellularPreview({ rows: 10, cols: 12, preset: 'blinker' }).aliveCount).toBe(3);
    expect(buildGraphPreview({ preset: 'two_islands' }).nodes).toHaveLength(8);
    expect(buildFractalPreview({}, 'recursive-tree').mode).toBe('vector');
    expect(buildEvolutionPreview({ chromosome_length: 10 }).targetGene).toHaveLength(10);
  });
});
