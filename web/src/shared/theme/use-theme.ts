import { ref, watchEffect } from 'vue';
import { readStorage, writeStorage } from '@/shared/storage/safe-storage';

export type ThemeMode = 'light' | 'dark';

const STORAGE_KEY = 'algorithm-garden-theme';

function readInitialTheme(): ThemeMode {
  const saved = readStorage(STORAGE_KEY);
  if (saved === 'light' || saved === 'dark') {
    return saved;
  }
  if (typeof window !== 'undefined') {
    return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  return 'light';
}

const theme = ref<ThemeMode>(readInitialTheme());

watchEffect(() => {
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', theme.value);
  }
  writeStorage(STORAGE_KEY, theme.value);
});

export function useTheme() {
  function toggleTheme(): void {
    theme.value = theme.value === 'light' ? 'dark' : 'light';
  }

  function setTheme(next: ThemeMode): void {
    theme.value = next;
  }

  return {
    theme,
    toggleTheme,
    setTheme,
  };
}
