<script setup lang="ts">
withDefaults(
  defineProps<{
    position?: 'top-right' | 'bottom-left';
    variant?: 'vine' | 'blossom';
  }>(),
  {
    position: 'top-right',
    variant: 'vine',
  },
);
</script>

<template>
  <svg
    class="floral-filigree"
    :class="[`is-${position}`, `is-${variant}`]"
    viewBox="0 0 220 150"
    fill="none"
    aria-hidden="true"
  >
    <!-- Primary curving botanical stem -->
    <path
      d="M208 10C170 22 146 52 118 82C94 108 66 128 24 138"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      opacity="0.34"
    />
    <!-- Secondary tendril curl -->
    <path
      d="M174 34C152 38 142 54 150 68C156 78 142 88 128 84"
      stroke="currentColor"
      stroke-width="1.15"
      stroke-linecap="round"
      stroke-dasharray="2 3"
      opacity="0.28"
    />
    <!-- Paired leaves along stem -->
    <path
      d="M168 24C154 24 148 38 160 44C172 48 180 34 168 24Z"
      fill="var(--accent-primary)"
      opacity="0.16"
    />
    <path
      d="M126 56C108 50 102 68 118 72C130 74 136 60 126 56Z"
      fill="var(--accent-primary)"
      opacity="0.18"
    />
    <path
      d="M84 96C68 86 56 100 68 112C78 120 92 106 84 96Z"
      fill="var(--accent-sun)"
      opacity="0.22"
    />

    <!-- Multi-petal lotus/cherry blossom cluster -->
    <g v-if="variant === 'blossom'" transform="translate(178 36)">
      <ellipse cx="0" cy="-12" rx="6" ry="11" fill="var(--accent-bloom)" opacity="0.24" />
      <ellipse cx="11" cy="-3" rx="6" ry="11" transform="rotate(68 11 -3)" fill="var(--accent-orchid)" opacity="0.22" />
      <ellipse cx="7" cy="10" rx="6" ry="11" transform="rotate(140 7 10)" fill="var(--accent-bloom)" opacity="0.22" />
      <ellipse cx="-8" cy="9" rx="6" ry="11" transform="rotate(-140 -8 9)" fill="var(--accent-orchid)" opacity="0.2" />
      <ellipse cx="-11" cy="-4" rx="6" ry="11" transform="rotate(-68 -11 -4)" fill="var(--accent-bloom)" opacity="0.24" />
      <circle cx="0" cy="0" r="4.2" fill="var(--accent-sun)" opacity="0.46" />
      <circle cx="0" cy="0" r="1.8" fill="var(--accent-primary)" opacity="0.55" />
    </g>

    <!-- Secondary bud / wildflower -->
    <g transform="translate(114 86)">
      <ellipse cx="0" cy="-7" rx="3.8" ry="7" fill="var(--accent-orchid)" opacity="0.22" />
      <ellipse cx="6.5" cy="-1.5" rx="3.8" ry="7" transform="rotate(72 6.5 -1.5)" fill="var(--accent-bloom)" opacity="0.22" />
      <ellipse cx="-6.5" cy="-1.5" rx="3.8" ry="7" transform="rotate(-72 -6.5 -1.5)" fill="var(--accent-bloom)" opacity="0.22" />
      <circle cx="0" cy="0" r="2.6" fill="var(--accent-sun)" opacity="0.52" />
    </g>

    <!-- Golden pollen & dew sparkles -->
    <circle cx="192" cy="18" r="2.4" fill="var(--accent-orchid)" opacity="0.45" />
    <circle cx="146" cy="46" r="2" fill="var(--accent-sun)" opacity="0.52" />
    <circle cx="92" cy="76" r="2.2" fill="var(--accent-bloom)" opacity="0.46" />
    <circle cx="54" cy="120" r="2" fill="var(--accent-primary)" opacity="0.46" />
    <circle cx="32" cy="134" r="1.6" fill="var(--accent-sun)" opacity="0.5" />
  </svg>
</template>

<style scoped>
.floral-filigree {
  position: absolute;
  width: 210px;
  height: 142px;
  color: var(--accent-primary);
  pointer-events: none;
  user-select: none;
  z-index: 0;
}

.floral-filigree.is-top-right {
  top: 0;
  right: 0;
}

.floral-filigree.is-bottom-left {
  bottom: 0;
  left: 0;
  transform: rotate(180deg);
}
</style>
