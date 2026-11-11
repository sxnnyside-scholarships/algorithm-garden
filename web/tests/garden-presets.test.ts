import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import TraceStage from '@/features/workspace/components/trace-stage.vue';
import {
  buildGridPreset,
  buildMountainPreset,
  buildSortingPreviewValues,
  normalizeGridSpec,
} from '@/features/workspace/composables/garden-presets';

describe('garden-presets & TraceStage interactivity', () => {
  it('builds deterministic sorting preview and mountain preset', () => {
    const a = buildSortingPreviewValues({ size: 8, distribution: 'random', seed: 11 });
    const b = buildSortingPreviewValues({ size: 8, distribution: 'random', seed: 11 });
    expect(a).toEqual(b);
    expect(a.length).toBe(8);

    const mountain = buildMountainPreset(7);
    expect(mountain.length).toBe(7);
    expect(mountain[3]).toBeGreaterThan(mountain[0] ?? 0);
    expect(mountain[3]).toBeGreaterThan(mountain[6] ?? 0);
  });

  it('builds weighted swamp and u-trap grid presets cleanly without colliding start/goal', () => {
    const swamp = buildGridPreset('weighted_swamp', 10, 14, 17);
    expect(swamp.weights.length).toBeGreaterThan(0);

    const normalized = normalizeGridSpec({
      rows: 6,
      cols: 6,
      start: [1, 1],
      goal: [6, 6],
      walls: [
        [1, 1],
        [2, 2],
      ],
      weights: [[2, 2, 5.0]],
    });
    expect(normalized.walls).toEqual([[2, 2]]);
    expect(normalized.weights).toEqual([]);
  });

  it('emits editCell when clicking cells on an editable pathfinding grid', async () => {
    const wrapper = mount(TraceStage, {
      props: {
        garden: 'pathfinding',
        sortingFrame: null,
        pathfindingFrame: {
          rows: 4,
          cols: 4,
          start: [1, 1],
          goal: [4, 4],
          walls: [],
          weights: [[2, 2, 5]],
          frontier: [],
          visited: [],
          cellCosts: {},
          activeCell: null,
          activeEdge: null,
          path: [],
          totalCost: null,
          counters: { visited: 0, frontier: 0, relaxed: 0 },
          currentEvent: null,
        },
        isPreview: true,
        editableGrid: true,
      },
    });

    const cells = wrapper.findAll('.pf-cell');
    expect(cells.length).toBe(16);
    await cells[5]?.trigger('pointerdown');
    expect(wrapper.emitted('editCell')).toEqual([[2, 2]]);
  });
});
