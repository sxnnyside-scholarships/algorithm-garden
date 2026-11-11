import { defineStore } from 'pinia';
import { ref } from 'vue';
import { messages } from '@/shared/i18n/messages';
import { getStoredLocale } from '@/shared/i18n/use-locale';
import { experimentsApi } from '../api/experiments-api';
import type { Experiment } from '../types/experiment';

export const useExperimentsStore = defineStore('experiments', () => {
  const items = ref<Experiment[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchAll(): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      items.value = await experimentsApi.list();
    } catch (err) {
      error.value =
        err instanceof Error ? err.message : messages[getStoredLocale()].experiments.loadError;
    } finally {
      loading.value = false;
    }
  }

  async function saveNew(payload: {
    algorithm_slug: string;
    title: string;
    code: string;
    params: Record<string, unknown>;
  }): Promise<Experiment> {
    const res = await experimentsApi.create(payload);
    items.value = [res.experiment, ...items.value];
    return res.experiment;
  }

  async function updateExisting(
    id: string,
    payload: { title?: string; code?: string; params?: Record<string, unknown> },
  ): Promise<Experiment> {
    const res = await experimentsApi.update(id, payload);
    items.value = items.value.map((item) => (item.id === id ? res.experiment : item));
    return res.experiment;
  }

  async function deleteById(id: string): Promise<boolean> {
    error.value = null;
    try {
      await experimentsApi.remove(id);
      items.value = items.value.filter((item) => item.id !== id);
      return true;
    } catch (err) {
      error.value =
        err instanceof Error ? err.message : messages[getStoredLocale()].experiments.deleteError;
      return false;
    }
  }

  return {
    items,
    loading,
    error,
    fetchAll,
    saveNew,
    updateExisting,
    deleteById,
  };
});
