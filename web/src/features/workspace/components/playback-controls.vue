<script setup lang="ts">
import { useLocale } from '@/shared/i18n/use-locale';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';

defineProps<{
  status: string;
  currentStep: number;
  totalSteps: number;
  speedMultiplier: number;
}>();

const emit = defineEmits<{
  stepBackward: [];
  play: [];
  pause: [];
  resume: [];
  stepForward: [];
  reset: [];
  seek: [step: number];
  setSpeed: [speed: number];
}>();

const { t } = useLocale();
</script>

<template>
  <div class="controls-bar garden-card">
    <div class="controls-bar__buttons">
      <button
        type="button"
        class="garden-btn"
        :title="t.workspace.stepBackTitle"
        :aria-label="t.workspace.stepBackTitle"
        :disabled="currentStep <= 0"
        @click="emit('stepBackward')"
      >
        <MingcuteIcon name="skip-previous-fill" :size="16" />
      </button>

      <button
        v-if="status === 'playing'"
        type="button"
        class="garden-btn garden-btn--primary"
        :title="t.workspace.pauseBtn"
        :aria-label="t.workspace.pauseBtn"
        @click="emit('pause')"
      >
        <MingcuteIcon name="pause-fill" :size="16" />
        <span>{{ t.workspace.pauseBtn }}</span>
      </button>
      <button
        v-else
        type="button"
        class="garden-btn garden-btn--primary"
        :title="status === 'paused' ? t.workspace.resumeBtn : t.workspace.playBtn"
        :aria-label="status === 'paused' ? t.workspace.resumeBtn : t.workspace.playBtn"
        :disabled="totalSteps === 0"
        @click="status === 'paused' ? emit('resume') : emit('play')"
      >
        <MingcuteIcon name="play-fill" :size="16" />
        <span>{{ status === 'paused' ? t.workspace.resumeBtn : t.workspace.playBtn }}</span>
      </button>

      <button
        type="button"
        class="garden-btn"
        :title="t.workspace.stepForwardTitle"
        :aria-label="t.workspace.stepForwardTitle"
        :disabled="currentStep >= totalSteps"
        @click="emit('stepForward')"
      >
        <MingcuteIcon name="skip-forward-fill" :size="16" />
      </button>

      <button
        type="button"
        class="garden-btn"
        :title="t.workspace.resetTraceTitle"
        :aria-label="t.workspace.resetTraceTitle"
        :disabled="totalSteps === 0"
        @click="emit('reset')"
      >
        <MingcuteIcon name="refresh-2-line" :size="16" />
      </button>
    </div>

    <div class="controls-bar__scrub">
      <input
        type="range"
        min="0"
        :max="totalSteps"
        :value="currentStep"
        :disabled="totalSteps === 0"
        :aria-label="t.workspace.progressAria"
        @input="emit('seek', Number(($event.target as HTMLInputElement).value))"
      />
      <select
        class="garden-input speed-select"
        :value="speedMultiplier"
        :aria-label="t.workspace.speedAria"
        @change="emit('setSpeed', Number(($event.target as HTMLSelectElement).value))"
      >
        <option :value="0.5">0.5x</option>
        <option :value="1">1x</option>
        <option :value="2">2x</option>
        <option :value="4">4x</option>
      </select>
    </div>
  </div>
</template>

<style scoped>
.controls-bar {
  padding: 0.75rem 0.95rem;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.controls-bar__buttons {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.45rem;
}

.controls-bar__scrub {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.controls-bar__scrub input[type='range'] {
  flex: 1;
}

.speed-select {
  width: 82px;
  padding: 0.32rem 0.5rem;
}
</style>

