import { defineStore } from 'pinia';
import { ref } from 'vue';
import { messages } from '@/shared/i18n/messages';
import { getStoredLocale } from '@/shared/i18n/use-locale';
import { catalogApi } from '../api/catalog-api';
import type {
  AlgorithmDetail,
  AlgorithmSummary,
  ExerciseSummary,
  GardenSummary,
} from '../types/catalog';

export const useCatalogStore = defineStore('catalog', () => {
  const gardens = ref<GardenSummary[]>([]);
  const algorithms = ref<AlgorithmSummary[]>([]);
  const activeAlgorithm = ref<AlgorithmDetail | null>(null);
  const activeExercises = ref<ExerciseSummary[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  let activeAlgoAbort: AbortController | null = null;
  let activeAlgoReqId = 0;

  async function fetchCatalog(): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const [g, a] = await Promise.all([catalogApi.listGardens(), catalogApi.listAlgorithms()]);
      gardens.value = g;
      algorithms.value = a;
    } catch (err) {
      error.value =
        err instanceof Error ? err.message : messages[getStoredLocale()].catalog.loadError;
    } finally {
      loading.value = false;
    }
  }

  async function fetchAlgorithm(slug: string): Promise<boolean> {
    activeAlgoAbort?.abort();
    const controller = new AbortController();
    activeAlgoAbort = controller;
    const reqId = ++activeAlgoReqId;

    loading.value = true;
    error.value = null;
    try {
      const res = await catalogApi.getAlgorithm(slug, controller.signal);
      if (reqId !== activeAlgoReqId) {
        return false;
      }
      activeAlgorithm.value = res.algorithm;
      activeExercises.value = res.exercises;
      return true;
    } catch (err) {
      if (controller.signal.aborted || reqId !== activeAlgoReqId) {
        return false;
      }
      error.value =
        err instanceof Error ? err.message : messages[getStoredLocale()].catalog.algoLoadError;
      activeAlgorithm.value = null;
      activeExercises.value = [];
      return false;
    } finally {
      if (reqId === activeAlgoReqId) {
        loading.value = false;
      }
    }
  }

  return {
    gardens,
    algorithms,
    activeAlgorithm,
    activeExercises,
    loading,
    error,
    fetchCatalog,
    fetchAlgorithm,
  };
});
