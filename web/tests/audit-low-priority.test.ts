import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { router } from '@/app/router';
import LoginPage from '@/features/auth/pages/login-page.vue';
import { useAuthStore } from '@/features/auth/stores/auth-store';
import { catalogApi } from '@/features/catalog/api/catalog-api';
import CatalogPage from '@/features/catalog/pages/catalog-page.vue';
import { experimentsApi } from '@/features/experiments/api/experiments-api';
import ExperimentsPage from '@/features/experiments/pages/experiments-page.vue';
import { useExecutionPlayer } from '@/features/workspace/composables/execution-player';
import type { ExecutionResult } from '@/features/workspace/types/execution';
import { registerMingcuteIcons } from '@/shared/ui/mingcute-registry';

registerMingcuteIcons();

describe('Low-priority frontend audit & sorting playback fixes', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders localized <time datetime> labels in ExperimentsPage', async () => {
    const auth = useAuthStore();
    auth.user = {
      id: 'u1',
      email: 'ada@garden.edu',
      username: 'ada',
      role: 'student',
      created_at: '2026-11-11',
    };
    auth.token = 'tok';

    vi.spyOn(experimentsApi, 'list').mockResolvedValueOnce([
      {
        id: 'exp-time-1',
        user_id: 'u1',
        algorithm_slug: 'bubble-sort',
        title: 'Cronos Sort',
        code: 'function sort_algorithm!(arr); end',
        params: { size: 12 },
        created_at: '2026-11-11T15:30:00Z',
        updated_at: '2026-11-11T15:30:00Z',
      },
    ]);

    const wrapper = mount(ExperimentsPage, {
      global: { plugins: [router] },
    });

    await vi.waitFor(() => {
      expect(wrapper.find('time').exists()).toBe(true);
    });

    const timeEl = wrapper.find('time');
    expect(timeEl.attributes('datetime')).toBe('2026-11-11T15:30:00Z');
    expect(timeEl.text().trim()).not.toBe('2026-11-11T15:30:00Z');
    wrapper.unmount();
  });

  it('offers reset filter button with allGardens label when filtering CatalogPage', async () => {
    vi.spyOn(catalogApi, 'listGardens').mockResolvedValueOnce([
      {
        slug: 'sorting',
        name: 'Jardín de Ordenamiento',
        description: 'Sorting algorithms',
        algorithms_count: 1,
      },
      {
        slug: 'pathfinding',
        name: 'Jardín de Caminos',
        description: 'Pathfinding algorithms',
        algorithms_count: 0,
      },
    ]);
    vi.spyOn(catalogApi, 'listAlgorithms').mockResolvedValueOnce([
      {
        slug: 'bubble-sort',
        garden: 'sorting',
        name: 'Bubble Sort',
        summary: 'Swaps adjacent items',
        difficulty: 'beginner',
      },
    ]);

    const wrapper = mount(CatalogPage, {
      global: { plugins: [router] },
    });

    await vi.waitFor(() => {
      expect(wrapper.findAll('.algo-card').length).toBe(1);
    });

    const filterButtons = wrapper.findAll('.garden-filter-card');
    expect(filterButtons.length).toBe(2);
    const pathBtn = filterButtons[1];
    await pathBtn?.trigger('click');

    expect(wrapper.findAll('.algo-card').length).toBe(0);
    const resetBtn = wrapper.find('.catalog-filter-status button');
    expect(resetBtn.exists()).toBe(true);
    await resetBtn.trigger('click');

    expect(wrapper.findAll('.algo-card').length).toBe(1);
    wrapper.unmount();
  });

  it('sets decoding="async" and fetchpriority="high" on LoginPage hero illustration', () => {
    const wrapper = mount(LoginPage, {
      global: { plugins: [router] },
    });
    const img = wrapper.find('img.login-hero__image');
    expect(img.exists()).toBe(true);
    expect(img.attributes('decoding')).toBe('async');
    expect(img.attributes('fetchpriority')).toBe('high');
    wrapper.unmount();
  });

  it('completes dense sorting traces within ~12s at 1x speed using adaptive frame catchup', () => {
    const callbacks: Array<(ts: number) => void> = [];
    vi.stubGlobal('requestAnimationFrame', (cb: (ts: number) => void) => {
      callbacks.push(cb);
      return callbacks.length;
    });
    vi.stubGlobal('cancelAnimationFrame', vi.fn());

    const denseEvents = Array.from({ length: 2500 }, (_, i) => ({
      seq: i + 1,
      type: 'compare' as const,
      indices: [1, 2] as [number, number],
    }));

    const denseSorting: ExecutionResult = {
      status: 'completed',
      garden: 'sorting',
      algorithm: 'bubble-sort',
      initial_state: { values: [5, 3, 1] },
      events: denseEvents,
      final_state: { values: [1, 3, 5] },
      metrics: null,
      tests: null,
      error: null,
    };

    const player = useExecutionPlayer();
    player.load(denseSorting, true);

    expect(player.status.value).toBe('playing');
    expect(callbacks.length).toBe(1);

    // Simulate 16.67ms ticks up to 12.5 seconds; must finish cleanly instead of >3 minutes.
    let now = 0;
    for (let frame = 0; frame < 800 && player.status.value === 'playing'; frame++) {
      const cb = callbacks.shift();
      if (!cb) {
        break;
      }
      now += 16.67;
      cb(now);
    }

    expect(player.status.value).toBe('completed');
    expect(player.currentStep.value).toBe(2500);
    expect(now).toBeLessThan(13_000);
    player.clear();
  });
});
