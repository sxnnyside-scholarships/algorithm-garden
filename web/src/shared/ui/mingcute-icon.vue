<script setup lang="ts">
import { Icon } from '@iconify/vue';
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    name: string;
    size?: number | string;
  }>(),
  {
    size: 18,
  },
);

const iconName = computed(() => (props.name.includes(':') ? props.name : `mingcute:${props.name}`));
const iconSize = computed(() => props.size ?? 18);
</script>

<template>
  <Icon :icon="iconName" :width="iconSize" :height="iconSize" aria-hidden="true" />
</template>
