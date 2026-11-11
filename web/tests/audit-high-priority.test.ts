import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createMemoryHistory, createRouter } from 'vue-router';
import { useAuthStore } from '@/features/auth/stores/auth-store';
import { catalogApi } from '@/features/catalog/api/catalog-api';
import { useCatalogStore } from '@/features/catalog/stores/catalog-store';
import type { AlgorithmDetail } from '@/features/catalog/types/catalog';
import { experimentsApi } from '@/features/experiments/api/experiments-api';
import ExperimentsPage from '@/features/experiments/pages/experiments-page.vue';
import CellularStage from '@/features/workspace/components/stages/cellular-stage.vue';
import FractalStage from '@/features/workspace/components/stages/fractal-stage.vue';
import { MINGCUTE_ICON_NAMES, registerMingcuteIcons } from '@/shared/ui/mingcute-registry';

registerMingcuteIcons();

function makeAlgorithmDetail(slug: string): AlgorithmDetail {
  return {
    slug,
    name: slug,
    garden: 'sorting',
    summary: 'summary',
    concept: 'concept',
    explanation: 'explanation',
    visualization_guide: 'guide',
    difficulty: 'beginner',
    reference_code: 'steps = Any[]',
    default_params: { size: 8 },
  };
}

function makeTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', redirect: '/catalog' },
      { path: '/login', component: { template: '<div>login</div>' } },
      { path: '/catalog', component: { template: '<div>catalog</div>' } },
      { path: '/experiments', component: ExperimentsPage },
      { path: '/workspace/:slug', component: { template: '<div>workspace</div>' } },
    ],
  });
}

describe('High-priority frontend audit fixes', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  it('cancels stale catalog fetchAlgorithm requests on rapid route switches', async () => {
    const store = useCatalogStore();
    const signals: AbortSignal[] = [];

    let resolveSlow!: (v: { algorithm: AlgorithmDetail; exercises: [] }) => void;
    let resolveFast!: (v: { algorithm: AlgorithmDetail; exercises: [] }) => void;

    vi.spyOn(catalogApi, 'getAlgorithm').mockImplementation((slug, signal) => {
      if (signal) {
        signals.push(signal);
      }
      return new Promise((resolve) => {
        if (slug === 'slow-algo') {
          resolveSlow = resolve;
        } else {
          resolveFast = resolve;
        }
      });
    });

    const slowPromise = store.fetchAlgorithm('slow-algo');
    const fastPromise = store.fetchAlgorithm('fast-algo');

    expect(signals).toHaveLength(2);
    expect(signals[0]?.aborted).toBe(true);
    expect(signals[1]?.aborted).toBe(false);

    resolveFast({ algorithm: makeAlgorithmDetail('fast-algo'), exercises: [] });
    const fastOk = await fastPromise;
    expect(fastOk).toBe(true);
    expect(store.activeAlgorithm?.slug).toBe('fast-algo');

    resolveSlow({ algorithm: makeAlgorithmDetail('slow-algo'), exercises: [] });
    const slowOk = await slowPromise;
    expect(slowOk).toBe(false);
    expect(store.activeAlgorithm?.slug).toBe('fast-algo');
  });

  it('surfaces load and delete errors in ExperimentsPage with accessible alerts', async () => {
    const auth = useAuthStore();
    auth.user = {
      id: 'u1',
      email: 'ada@garden.edu',
      username: 'ada',
      role: 'student',
      created_at: '2026-11-11',
    };
    auth.token = 'tok';

    vi.spyOn(experimentsApi, 'list').mockRejectedValueOnce(new Error('Network offline'));

    const router = makeTestRouter();
    await router.push('/experiments');
    await router.isReady();

    const wrapper = mount(ExperimentsPage, {
      global: { plugins: [router] },
    });
    await vi.waitFor(() => {
      expect(wrapper.find('[role="alert"]').text()).toContain('Network offline');
    });
    wrapper.unmount();

    vi.spyOn(experimentsApi, 'list').mockResolvedValueOnce([
      {
        id: 'exp-1',
        user_id: 'u1',
        algorithm_slug: 'bubble-sort',
        title: 'Mi Bubble Sort',
        code: 'steps = Any[]',
        params: { size: 10 },
        created_at: '2026-11-11',
        updated_at: '2026-11-11',
      },
    ]);
    vi.spyOn(experimentsApi, 'remove').mockRejectedValueOnce(new Error('Delete denied'));

    const wrapper2 = mount(ExperimentsPage, {
      global: { plugins: [router] },
    });
    await vi.waitFor(() => {
      expect(wrapper2.text()).toContain('Mi Bubble Sort');
    });

    const delBtn = wrapper2.find('button[aria-label*="Mi Bubble Sort"]');
    expect(delBtn.exists()).toBe(true);
    await delBtn.trigger('click');

    await vi.waitFor(() => {
      expect(wrapper2.find('[role="alert"]').text()).toContain('Delete denied');
    });
    expect(wrapper2.text()).toContain('Mi Bubble Sort');
    wrapper2.unmount();
  });

  it('supports keyboard cell activation and aria-labels on CellularStage', async () => {
    const wrapper = mount(CellularStage, {
      props: {
        editable: true,
        frame: {
          rows: 2,
          cols: 2,
          cells: [
            [0, 1],
            [0, 0],
          ],
          generation: 0,
          aliveCount: 1,
          bornCount: 0,
          diedCount: 0,
          born: [3],
          survive: [2, 3],
          currentEvent: null,
        },
      },
    });

    const firstCell = wrapper.find('.ca-cell');
    expect(firstCell.attributes('aria-label')).toBeTruthy();

    await firstCell.trigger('keydown.enter');
    expect(wrapper.emitted('toggleCell')).toEqual([[1, 1]]);
    wrapper.unmount();
  });

  it('provides accessible canvas attributes and keyboard zoom controls on FractalStage', async () => {
    const wrapper = mount(FractalStage, {
      props: {
        isPreview: false,
        frame: {
          mode: 'raster',
          width: 4,
          height: 4,
          computedRows: 4,
          rows: [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
          ],
          segments: [],
          currentDepth: 0,
          maxIter: 40,
          xMin: -2.0,
          xMax: 1.0,
          yMin: -1.5,
          yMax: 1.5,
          currentEvent: null,
        },
      },
    });

    const canvas = wrapper.find('canvas.fractal-canvas');
    expect(canvas.attributes('role')).toBe('img');
    expect(canvas.attributes('tabindex')).toBe('0');
    expect(canvas.attributes('aria-label')).toBeTruthy();

    const controls = wrapper.findAll('.fractal-controls button');
    expect(controls.length).toBe(3);
    for (const btn of controls) {
      expect(btn.attributes('aria-label')).toBeTruthy();
    }

    await controls[0]?.trigger('click');
    expect(wrapper.emitted('zoomAt')).toEqual([[-0.5, 0]]);

    await controls[1]?.trigger('click');
    expect(wrapper.emitted('zoomOut')).toEqual([[]]);

    await controls[2]?.trigger('click');
    expect(wrapper.emitted('resetZoom')).toEqual([[]]);
    wrapper.unmount();
  });

  it('registers every mingcute icon referenced across components', () => {
    expect(MINGCUTE_ICON_NAMES).toContain('alert-line');
    expect(MINGCUTE_ICON_NAMES).toContain('zoom-in-line');
    expect(MINGCUTE_ICON_NAMES).toContain('zoom-out-line');
    expect(MINGCUTE_ICON_NAMES.length).toBe(56);
  });
});
