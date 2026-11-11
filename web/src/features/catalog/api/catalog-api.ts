import { apiRequest } from '@/shared/api/http-client';
import type {
  AlgorithmDetail,
  AlgorithmSummary,
  ExerciseSummary,
  GardenSummary,
} from '../types/catalog';

export const catalogApi = {
  listGardens(): Promise<GardenSummary[]> {
    return apiRequest<GardenSummary[]>('/api/v1/gardens');
  },

  listAlgorithms(garden?: string): Promise<AlgorithmSummary[]> {
    const query = garden ? `?garden=${encodeURIComponent(garden)}` : '';
    return apiRequest<AlgorithmSummary[]>(`/api/v1/algorithms${query}`);
  },

  getAlgorithm(
    slug: string,
    signal?: AbortSignal,
  ): Promise<{ algorithm: AlgorithmDetail; exercises: ExerciseSummary[] }> {
    const reqOptions = signal ? { signal } : {};
    return apiRequest<{ algorithm: AlgorithmDetail; exercises: ExerciseSummary[] }>(
      `/api/v1/algorithms/${encodeURIComponent(slug)}`,
      reqOptions,
    );
  },
};
