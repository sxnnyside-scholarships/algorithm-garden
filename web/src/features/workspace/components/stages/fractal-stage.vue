<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { useLocale } from '@/shared/i18n/use-locale';
import MingcuteIcon from '@/shared/ui/mingcute-icon.vue';
import type { FractalFrame } from '../../types/execution';

const props = defineProps<{
  frame: FractalFrame;
  isPreview: boolean;
}>();

const emit = defineEmits<{
  zoomAt: [re: number, im: number];
  zoomOut: [];
  resetZoom: [];
}>();

const { t } = useLocale();
const canvasRef = ref<HTMLCanvasElement | null>(null);
let isMounted = false;

function escapeColor(iter: number, maxIter: number): [number, number, number] {
  if (iter >= maxIter) {
    return [14, 24, 20];
  }
  const u = Math.max(0, Math.min(1, iter / Math.max(1, maxIter)));
  const r = Math.round(28 + 215 * u ** 0.85 + 25 * Math.sin(u * Math.PI * 3));
  const g = Math.round(58 + 165 * Math.sin(u * Math.PI * 0.92));
  const b = Math.round(72 + 160 * u ** 1.3);
  return [
    Math.min(255, Math.max(0, r)),
    Math.min(255, Math.max(0, g)),
    Math.min(255, Math.max(0, b)),
  ];
}

function paintCanvas(): void {
  const canvas = canvasRef.value;
  if (!canvas || props.frame.mode !== 'raster') {
    return;
  }
  const w = Math.max(1, props.frame.width);
  const h = Math.max(1, props.frame.height);
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width = w;
    canvas.height = h;
  }
  const ctx = canvas.getContext('2d');
  if (!ctx) {
    return;
  }

  const img = ctx.createImageData(w, h);
  const maxIter = props.frame.maxIter;

  for (let r = 0; r < h; r++) {
    const rowData = props.frame.rows[r];
    for (let c = 0; c < w; c++) {
      const idx = (r * w + c) * 4;
      if (!rowData || props.frame.computedRows === 0) {
        // Botanical preview gradient grid before first run
        const wave = Math.sin((r / h) * Math.PI) * Math.sin((c / w) * Math.PI);
        img.data[idx] = Math.round(22 + wave * 34);
        img.data[idx + 1] = Math.round(44 + wave * 82);
        img.data[idx + 2] = Math.round(36 + wave * 54);
        img.data[idx + 3] = 255;
      } else {
        const it = rowData[c] ?? 0;
        const [cr, cg, cb] = escapeColor(it, maxIter);
        img.data[idx] = cr;
        img.data[idx + 1] = cg;
        img.data[idx + 2] = cb;
        img.data[idx + 3] = 255;
      }
    }
  }
  ctx.putImageData(img, 0, 0);
}

onMounted(() => {
  isMounted = true;
  paintCanvas();
});

onUnmounted(() => {
  isMounted = false;
});

watch(
  () => [props.frame.computedRows, props.frame.width, props.frame.height, props.frame.mode],
  async () => {
    await nextTick();
    if (isMounted) {
      paintCanvas();
    }
  },
);

const canZoomIn = computed(() => !props.isPreview && props.frame.computedRows > 0);

function zoomInFromCenter(): void {
  const re = (props.frame.xMin + props.frame.xMax) / 2;
  const im = (props.frame.yMin + props.frame.yMax) / 2;
  emit('zoomAt', re, im);
}

function handleCanvasClick(event: MouseEvent): void {
  if (!canZoomIn.value) {
    return;
  }
  const canvas = canvasRef.value;
  if (!canvas) {
    return;
  }
  const rect = canvas.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) {
    return;
  }
  const nx = (event.clientX - rect.left) / rect.width;
  const ny = (event.clientY - rect.top) / rect.height;
  const re = props.frame.xMin + nx * (props.frame.xMax - props.frame.xMin);
  const im = props.frame.yMax - ny * (props.frame.yMax - props.frame.yMin);
  emit('zoomAt', re, im);
}

const vectorBounds = computed(() => {
  const segs = props.frame.segments;
  if (segs.length === 0) {
    return { viewBox: '-2 -2 4 4', strokeBase: 0.08 };
  }
  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;
  for (const seg of segs) {
    const x1 = seg[0] ?? 0;
    const y1 = -(seg[1] ?? 0);
    const x2 = seg[2] ?? 0;
    const y2 = -(seg[3] ?? 0);
    minX = Math.min(minX, x1, x2);
    maxX = Math.max(maxX, x1, x2);
    minY = Math.min(minY, y1, y2);
    maxY = Math.max(maxY, y1, y2);
  }
  const spanX = Math.max(0.5, maxX - minX);
  const spanY = Math.max(0.5, maxY - minY);
  const pad = Math.max(spanX, spanY) * 0.12;
  return {
    viewBox: `${minX - pad} ${minY - pad} ${spanX + pad * 2} ${spanY + pad * 2}`,
    strokeBase: Math.max(spanX, spanY) * 0.022,
  };
});

function branchColor(depth: number): string {
  if (depth <= 1) {
    return 'var(--tree-bark)';
  }
  if (depth === 2) {
    return 'var(--tree-shoot)';
  }
  if (depth === 3) {
    return 'var(--tree-leaf)';
  }
  if (depth === 4) {
    return 'var(--tree-fern)';
  }
  if (depth === 5) {
    return 'var(--tree-petal)';
  }
  return 'var(--tree-tip)';
}
</script>

<template>
  <div class="fractal-stage">
    <div v-if="frame.mode === 'raster'" class="raster-wrap">
      <canvas
        ref="canvasRef"
        class="fractal-canvas"
        :class="{ 'is-zoomable': canZoomIn }"
        role="img"
        :aria-label="t.stage.fractalCanvasAria"
        tabindex="0"
        @click="handleCanvasClick"
        @keydown.enter.space.prevent="zoomInFromCenter"
      />
      <div class="fractal-hud mono">
        <span>
          Re [{{ frame.xMin.toFixed(3) }}, {{ frame.xMax.toFixed(3) }}] · Im [{{
            frame.yMin.toFixed(3)
          }}, {{ frame.yMax.toFixed(3) }}]
        </span>
        <div class="fractal-controls">
          <button
            type="button"
            class="mini-reset"
            :aria-label="t.stage.fractalZoomInBtn"
            @click="zoomInFromCenter"
          >
            <MingcuteIcon name="zoom-in-line" :size="12" />
            <span>{{ t.stage.fractalZoomInBtn }}</span>
          </button>
          <button
            type="button"
            class="mini-reset"
            :aria-label="t.stage.fractalZoomOutBtn"
            @click="emit('zoomOut')"
          >
            <MingcuteIcon name="zoom-out-line" :size="12" />
            <span>{{ t.stage.fractalZoomOutBtn }}</span>
          </button>
          <button
            type="button"
            class="mini-reset"
            :aria-label="t.stage.fractalResetZoom"
            @click="emit('resetZoom')"
          >
            <MingcuteIcon name="refresh-2-line" :size="12" />
            <span>{{ t.stage.fractalResetZoom }}</span>
          </button>
        </div>
      </div>
      <p v-if="canZoomIn" class="zoom-tip">
        {{ t.stage.fractalZoomHint }}
      </p>
    </div>

    <div v-else class="vector-wrap">
      <svg
        :viewBox="vectorBounds.viewBox"
        class="vector-svg"
        role="img"
        :aria-label="t.stage.fractalAria"
      >
        <line
          v-for="(seg, idx) in frame.segments"
          :key="idx"
          :x1="seg[0]"
          :y1="-(seg[1] ?? 0)"
          :x2="seg[2]"
          :y2="-(seg[3] ?? 0)"
          :stroke="branchColor(seg[4] ?? 1)"
          :stroke-width="Math.max(vectorBounds.strokeBase * 0.25, vectorBounds.strokeBase / (seg[4] ?? 1))"
          stroke-linecap="round"
        />
      </svg>
      <div class="fractal-hud mono">
        <span>{{ t.stage.fractalDepth }}: {{ frame.currentDepth }}</span>
        <span>{{ t.stage.fractalSegments }}: {{ frame.segments.length }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fractal-stage,
.raster-wrap,
.vector-wrap {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.fractal-canvas,
.vector-svg {
  width: 100%;
  aspect-ratio: 4 / 3;
  max-height: 295px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-subtle);
  background: var(--bg-elevated);
}

.fractal-canvas {
  image-rendering: pixelated;
}

.fractal-canvas.is-zoomable {
  cursor: zoom-in;
}

.fractal-hud {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.45rem;
  font-size: 0.72rem;
  color: var(--text-secondary);
}

.fractal-controls {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.35rem;
}

.mini-reset {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  border: 1px solid var(--border-subtle);
  background: var(--bg-elevated);
  color: var(--text-secondary);
  border-radius: var(--radius-pill);
  padding: 0.16rem 0.5rem;
  font-size: 0.72rem;
  cursor: pointer;
}

.mini-reset:hover {
  border-color: var(--accent-primary);
  color: var(--accent-primary);
}

.zoom-tip {
  margin: 0;
  font-size: 0.74rem;
  color: var(--text-muted);
}
</style>
