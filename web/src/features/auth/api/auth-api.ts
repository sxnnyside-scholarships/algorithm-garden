import { apiRequest } from '@/shared/api/http-client';
import type { AuthResponse, User } from '../types/auth';

export const authApi = {
  register(payload: { email: string; username: string; password: string }): Promise<AuthResponse> {
    return apiRequest<AuthResponse>('/api/v1/auth/register', {
      method: 'POST',
      body: payload,
      token: null,
    });
  },

  login(payload: { email: string; password: string }): Promise<AuthResponse> {
    return apiRequest<AuthResponse>('/api/v1/auth/login', {
      method: 'POST',
      body: payload,
      token: null,
    });
  },

  logout(): Promise<{ revoked: boolean }> {
    return apiRequest<{ revoked: boolean }>('/api/v1/auth/logout', { method: 'POST' });
  },

  me(): Promise<{ user: User }> {
    return apiRequest<{ user: User }>('/api/v1/auth/me');
  },
};
