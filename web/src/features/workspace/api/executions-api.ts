import { apiRequest } from '@/shared/api/http-client';
import type { ExecutionResult, ExerciseTestResult } from '../types/execution';

export const executionsApi = {
  run(payload: {
    algorithm_slug: string;
    code: string;
    params: Record<string, unknown>;
  }): Promise<{ execution: ExecutionResult }> {
    return apiRequest<{ execution: ExecutionResult }>('/api/v1/executions', {
      method: 'POST',
      body: payload,
    });
  },

  verifyExercise(
    exerciseId: string,
    payload: { code: string },
  ): Promise<{ passed: boolean; results: ExerciseTestResult[]; execution: ExecutionResult }> {
    return apiRequest<{
      passed: boolean;
      results: ExerciseTestResult[];
      execution: ExecutionResult;
    }>(`/api/v1/exercises/${encodeURIComponent(exerciseId)}/verify`, {
      method: 'POST',
      body: payload,
    });
  },
};
