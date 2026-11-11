<script setup lang="ts">
import { computed } from 'vue';
import { useLocale } from '@/shared/i18n/use-locale';
import type { EvolutionFrame } from '../../types/execution';

const props = defineProps<{
  frame: EvolutionFrame;
  isPreview: boolean;
}>();

const { t } = useLocale();

const chartPoints = computed(() => {
  const hist = props.frame.history;
  if (hist.length === 0) {
    return { bestPath: '', avgPath: '', areaPath: '' };
  }
  const n = Math.max(1, hist.length - 1);
  const toX = (idx: number) => 10 + (idx / n) * 200;
  const toY = (val: number) => 82 - Math.max(0, Math.min(1, val)) * 68;

  const bestCoords = hist.map((pt, idx) => `${toX(idx).toFixed(1)},${toY(pt.best).toFixed(1)}`);
  const avgCoords = hist.map((pt, idx) => `${toX(idx).toFixed(1)},${toY(pt.avg).toFixed(1)}`);
  const firstX = toX(0).toFixed(1);
  const lastX = toX(hist.length - 1).toFixed(1);

  return {
    bestPath: bestCoords.join(' '),
    avgPath: avgCoords.join(' '),
    areaPath: `M ${firstX},82 L ${bestCoords.join(' L ')} L ${lastX},82 Z`,
  };
});

function matchesTarget(bit: number, idx: number): boolean {
  const target = props.frame.targetGene[idx];
  return target !== undefined && bit === target;
}
</script>

<template>
  <div class="evolution-stage">
    <div class="evo-metrics mono">
      <span class="stage-meta-pill">{{ t.stage.evoGen }} {{ frame.generation }}</span>
      <span class="stage-meta-pill is-best">
        {{ t.stage.evoBest }}: {{ Math.round(frame.bestFitness * 100) }}%
      </span>
      <span class="stage-meta-pill">
        {{ t.stage.evoAvg }}: {{ Math.round(frame.avgFitness * 100) }}%
      </span>
      <span class="stage-meta-pill">
        {{ t.stage.evoDiversity }}: {{ Math.round(frame.diversity * 100) }}%
      </span>
    </div>

    <svg viewBox="0 0 220 94" class="fitness-chart" role="img" :aria-label="t.stage.evoChartAria">
      <line x1="10" y1="14" x2="210" y2="14" class="grid-line" stroke-dasharray="2 2" />
      <line x1="10" y1="48" x2="210" y2="48" class="grid-line" stroke-dasharray="2 2" />
      <line x1="10" y1="82" x2="210" y2="82" class="grid-line" />

      <text x="12" y="12" class="axis-label mono">100%</text>
      <text x="12" y="46" class="axis-label mono">50%</text>
      <text x="12" y="91" class="axis-label mono">0%</text>

      <path v-if="chartPoints.areaPath" :d="chartPoints.areaPath" class="area-best" />
      <polyline v-if="chartPoints.avgPath" :points="chartPoints.avgPath" class="line-avg" />
      <polyline v-if="chartPoints.bestPath" :points="chartPoints.bestPath" class="line-best" />

      <text v-if="isPreview || frame.history.length === 0" x="110" y="52" text-anchor="middle" class="empty-note">
        {{ t.stage.evoWaiting }}
      </text>
    </svg>

    <div class="genome-panel">
      <div class="genome-row">
        <span class="genome-label mono">{{ t.stage.evoTarget }}</span>
        <div class="bit-strip">
          <span
            v-for="(bit, idx) in frame.targetGene"
            :key="idx"
            class="bit-cell mono"
            :class="bit === 1 ? 'bit--target-on' : 'bit--target-off'"
          >
            {{ bit }}
          </span>
        </div>
      </div>

      <div v-for="(genome, gIdx) in frame.topGenomes.slice(0, 4)" :key="gIdx" class="genome-row">
        <span class="genome-label mono">
          #{{ gIdx + 1 }} · {{ Math.round((frame.topFitnesses[gIdx] ?? 0) * 100) }}%
        </span>
        <div class="bit-strip">
          <span
            v-for="(bit, idx) in genome"
            :key="idx"
            class="bit-cell mono"
            :class="matchesTarget(bit, idx) ? 'bit--match' : 'bit--miss'"
          >
            {{ bit }}
          </span>
        </div>
      </div>
    </div>

    <div class="stage-legend">
      <span><i class="stage-swatch line-swatch--best" /> {{ t.stage.evoBest }}</span>
      <span><i class="stage-swatch line-swatch--avg" /> {{ t.stage.evoAvg }}</span>
      <span><i class="stage-swatch bit--match" /> {{ t.stage.legendGeneMatch }}</span>
    </div>
  </div>
</template>

<style scoped>
.evolution-stage {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.evo-metrics {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  font-size: 0.74rem;
}

.stage-meta-pill.is-best {
  border-color: var(--accent-primary);
  color: var(--accent-primary);
}

.fitness-chart {
  width: 100%;
  height: 120px;
  border-radius: var(--radius-md);
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
}

.grid-line {
  stroke: var(--border-subtle);
  stroke-width: 0.7;
}

.axis-label {
  font-size: 5.5px;
  fill: var(--text-muted);
}

.empty-note {
  font-size: 7px;
  fill: var(--text-muted);
}

.area-best {
  fill: var(--accent-primary);
  opacity: 0.14;
}

.line-best {
  fill: none;
  stroke: var(--accent-primary);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.line-avg {
  fill: none;
  stroke: var(--accent-sun);
  stroke-width: 1.5;
  stroke-dasharray: 3 2;
}

.genome-panel {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  padding: 0.55rem;
  border-radius: var(--radius-md);
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
}

.genome-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.45rem;
}

.genome-label {
  font-size: 0.71rem;
  color: var(--text-secondary);
  min-width: 64px;
}

.bit-strip {
  display: flex;
  flex-wrap: wrap;
  gap: 2px;
  flex: 1;
}

.bit-cell {
  width: 15px;
  height: 16px;
  border-radius: 3px;
  font-size: 0.65rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--border-subtle);
}

.bit--target-on {
  background: var(--accent-bloom);
  border-color: var(--accent-bloom);
  color: var(--text-on-accent);
}

.bit--target-off {
  background: var(--bg-surface);
  color: var(--text-muted);
}

.bit--match {
  background: var(--accent-primary);
  border-color: var(--accent-primary);
  color: var(--text-on-primary-btn);
  font-weight: 700;
}

.bit--miss {
  background: var(--bg-surface);
  color: var(--text-muted);
  opacity: 0.75;
}

.line-swatch--best {
  background: var(--accent-primary);
}

.line-swatch--avg {
  background: var(--accent-sun);
}
</style>

