import { apiRequest } from '@/shared/api/http-client';
import type { Experiment } from '../types/experiment';

export const experimentsApi = {
  list(): Promise<Experiment[]> {
    return apiRequest<Experiment[]>('/api/v1/experiments');
  },

  get(id: string): Promise<{ experiment: Experiment }> {
    return apiRequest<{ experiment: Experiment }>(`/api/v1/experiments/${encodeURIComponent(id)}`);
  },

  create(payload: {
    algorithm_slug: string;
    title: string;
    code: string;
    params: Record<string, unknown>;
  }): Promise<{ experiment: Experiment }> {
    return apiRequest<{ experiment: Experiment }>('/api/v1/experiments', {
      method: 'POST',
      body: payload,
    });
  },

  update(
    id: string,
    payload: { title?: string; code?: string; params?: Record<string, unknown> },
  ): Promise<{ experiment: Experiment }> {
    return apiRequest<{ experiment: Experiment }>(`/api/v1/experiments/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: payload,
    });
  },

  remove(id: string): Promise<{ deleted: boolean }> {
    return apiRequest<{ deleted: boolean }>(`/api/v1/experiments/${encodeURIComponent(id)}`, {
      method: 'DELETE',
    });
  },
};
