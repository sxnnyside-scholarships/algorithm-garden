<script setup lang="ts">
import { onMounted, watchEffect } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '@/features/auth/stores/auth-store';
import { useLocale } from '@/shared/i18n/use-locale';
import '@/shared/theme/use-theme';
import type { PageTitleKey } from './router';

const authStore = useAuthStore();
const route = useRoute();
const { t } = useLocale();

watchEffect(() => {
  if (typeof document === 'undefined') {
    return;
  }
  const titleKey = route.meta?.titleKey as PageTitleKey | undefined;
  document.title = titleKey ? t.value.common.pageTitles[titleKey] : t.value.common.brandName;
});

onMounted(() => {
  void authStore.hydrate();
});
</script>

<template>
  <RouterView />
</template>
