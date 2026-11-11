import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { router } from '@/app/router';
import ExecutionInspector from '@/features/workspace/components/execution-inspector.vue';
import GraphStage from '@/features/workspace/components/stages/graph-stage.vue';
import { getStoredToken, setStoredToken } from '@/shared/api/http-client';
import { getStoredLocale } from '@/shared/i18n/use-locale';
import { readStorage, removeStorage, writeStorage } from '@/shared/storage/safe-storage';
import { registerMingcuteIcons } from '@/shared/ui/mingcute-registry';

registerMingcuteIcons();

describe('Medium-priority frontend audit fixes', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it('guards localStorage reads/writes when storage throws SecurityError or QuotaExceededError', () => {
    const originalStorage = window.localStorage;
    Object.defineProperty(window, 'localStorage', {
      configurable: true,
      value: {
        getItem() {
          throw new Error('SecurityError: blocked');
        },
        setItem() {
          throw new Error('QuotaExceededError: full');
        },
        removeItem() {
          throw new Error('SecurityError: blocked');
        },
      },
    });

    try {
      expect(readStorage('k')).toBeNull();
      expect(() => writeStorage('k', 'v')).not.toThrow();
      expect(() => removeStorage('k')).not.toThrow();
      expect(() => getStoredLocale()).not.toThrow();
      expect(getStoredToken()).toBeNull();
      expect(() => setStoredToken('abc')).not.toThrow();
    } finally {
      Object.defineProperty(window, 'localStorage', {
        configurable: true,
        value: originalStorage,
      });
    }
  });

  it('exposes complete WAI-ARIA tablist/tab/tabpanel semantics in ExecutionInspector', async () => {
    const wrapper = mount(ExecutionInspector, {
      props: {
        execution: {
          status: 'completed',
          garden: 'sorting',
          algorithm: 'bubble-sort',
          initial_state: { values: [3, 1, 2] },
          events: [{ seq: 1, type: 'compare', indices: [1, 2] }],
          final_state: { values: [1, 2, 3] },
          metrics: {
            comparisons: 1,
            swaps: 0,
            reads: 2,
            writes: 0,
            nodes_visited: 0,
            frontier_enqueued: 0,
            edges_relaxed: 0,
            total_events: 1,
            elapsed_ms: 1.5,
          },
          tests: null,
          error: null,
        },
        currentStep: 1,
        totalSteps: 1,
        sortingFrame: null,
        pathfindingFrame: null,
        exerciseResults: [{ name: 'sorted', passed: true, message: 'OK' }],
        exercisePassed: true,
      },
    });

    const tablist = wrapper.find('[role="tablist"]');
    expect(tablist.exists()).toBe(true);
    expect(tablist.attributes('aria-label')).toBeTruthy();

    const tabs = wrapper.findAll('[role="tab"]');
    expect(tabs).toHaveLength(3);
    expect(tabs[0]?.attributes('aria-selected')).toBe('true');
    expect(tabs[1]?.attributes('aria-selected')).toBe('false');

    const panel = wrapper.find('[role="tabpanel"]');
    expect(panel.attributes('id')).toBe('inspector-panel-overview');
    expect(panel.attributes('aria-labelledby')).toBe('inspector-tab-overview');

    await tabs[1]?.trigger('click');
    expect(tabs[1]?.attributes('aria-selected')).toBe('true');
    const eventsPanel = wrapper.find('[role="tabpanel"]');
    expect(eventsPanel.attributes('id')).toBe('inspector-panel-events');
    expect(eventsPanel.attributes('aria-labelledby')).toBe('inspector-tab-events');
  });

  it('uses tokenized CSS custom properties for connected components in GraphStage', () => {
    const wrapper = mount(GraphStage, {
      props: {
        frame: {
          nodes: [
            { id: 1, label: 'A', x: 20, y: 20 },
            { id: 2, label: 'B', x: 80, y: 80 },
          ],
          edges: [[1, 2, 3]],
          directed: false,
          startNode: 1,
          targetNode: 2,
          visitedNodes: [1],
          frontierNodes: [],
          activeNode: null,
          activeEdge: null,
          mstEdges: [],
          components: { 1: 1, 2: 2 },
          path: [],
          counters: { visited: 1, frontier: 0, inspected: 1, mstWeight: 0 },
          currentEvent: null,
        },
      },
    });

    const circles = wrapper.findAll('circle');
    const fills = circles.map((c) => c.attributes('fill'));
    expect(fills).toContain('var(--palette-1)');
    expect(fills).toContain('var(--palette-2)');
    expect(wrapper.find('.stage-legend').exists()).toBe(true);
  });

  it('configures route title metadata and catch-all fallback redirect', () => {
    const unknownResolved = router.resolve('/unknown/path');
    expect(unknownResolved.matched[0]?.redirect).toBe('/catalog');

    expect(router.resolve('/login').meta.titleKey).toBe('login');
    expect(router.resolve('/catalog').meta.titleKey).toBe('catalog');
    expect(router.resolve('/experiments').meta.titleKey).toBe('experiments');
    expect(router.resolve('/workspace/bubble-sort').meta.titleKey).toBe('workspace');
  });
});
