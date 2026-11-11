import { computed, ref, watchEffect } from 'vue';
import { readStorage, writeStorage } from '@/shared/storage/safe-storage';
import { type Locale, messages } from './messages';

const STORAGE_KEY = 'algorithm-garden-locale';

export function getStoredLocale(): Locale {
  const saved = readStorage(STORAGE_KEY);
  if (saved === 'es' || saved === 'en') {
    return saved;
  }
  if (typeof navigator !== 'undefined' && navigator.language?.toLowerCase().startsWith('en')) {
    return 'en';
  }
  return 'es';
}

const locale = ref<Locale>(getStoredLocale());

watchEffect(() => {
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('lang', locale.value);
  }
  writeStorage(STORAGE_KEY, locale.value);
});

export function useLocale() {
  const t = computed(() => messages[locale.value]);
  const sxnnysideUrl = computed(
    () => `https://www.sxnnysideproject.com/${locale.value}/realms/sxnnyside-scholarships/`,
  );

  function setLocale(next: Locale): void {
    locale.value = next;
  }

  function toggleLocale(): void {
    locale.value = locale.value === 'es' ? 'en' : 'es';
  }

  return {
    locale,
    t,
    sxnnysideUrl,
    setLocale,
    toggleLocale,
  };
}
