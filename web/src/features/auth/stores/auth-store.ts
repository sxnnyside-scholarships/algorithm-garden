import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import { getStoredToken, setStoredToken } from '@/shared/api/http-client';
import { authApi } from '../api/auth-api';
import type { User } from '../types/auth';

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null);
  const token = ref<string | null>(getStoredToken());
  const initialized = ref(false);

  const isAuthenticated = computed(() => user.value !== null && token.value !== null);

  async function hydrate(): Promise<void> {
    if (initialized.value) {
      return;
    }
    initialized.value = true;
    if (!token.value) {
      return;
    }
    try {
      const res = await authApi.me();
      user.value = res.user;
    } catch {
      user.value = null;
      token.value = null;
      setStoredToken(null);
    }
  }

  async function login(email: string, password: string): Promise<void> {
    const res = await authApi.login({ email, password });
    user.value = res.user;
    token.value = res.token;
    setStoredToken(res.token);
  }

  async function register(email: string, username: string, password: string): Promise<void> {
    const res = await authApi.register({ email, username, password });
    user.value = res.user;
    token.value = res.token;
    setStoredToken(res.token);
  }

  async function logout(): Promise<void> {
    try {
      if (token.value) {
        await authApi.logout();
      }
    } finally {
      user.value = null;
      token.value = null;
      setStoredToken(null);
    }
  }

  return {
    user,
    token,
    initialized,
    isAuthenticated,
    hydrate,
    login,
    register,
    logout,
  };
});
