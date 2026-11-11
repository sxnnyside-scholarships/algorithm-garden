<script setup lang="ts">
import { computed } from 'vue';
import { useLocale } from '@/shared/i18n/use-locale';
import type { GraphFrame, GraphNodeSpec } from '../../types/execution';

const props = defineProps<{
  frame: GraphFrame;
}>();

const { t } = useLocale();

const COMPONENT_PALETTE = [
  'var(--palette-1)',
  'var(--palette-2)',
  'var(--palette-3)',
  'var(--palette-4)',
  'var(--palette-5)',
  'var(--palette-6)',
];

const nodeMap = computed(() => {
  const m = new Map<number, GraphNodeSpec>();
  for (const n of props.frame.nodes) {
    m.set(n.id, n);
  }
  return m;
});

const visitedSet = computed(() => new Set(props.frame.visitedNodes));
const frontierSet = computed(() => new Set(props.frame.frontierNodes));

const mstKeySet = computed(() => {
  const s = new Set<string>();
  for (const [u, v] of props.frame.mstEdges) {
    s.add(`${Math.min(u, v)}-${Math.max(u, v)}`);
  }
  return s;
});

const pathEdgeSet = computed(() => {
  const s = new Set<string>();
  const p = props.frame.path;
  for (let i = 0; i + 1 < p.length; i++) {
    const a = p[i];
    const b = p[i + 1];
    if (a !== undefined && b !== undefined) {
      s.add(`${a}-${b}`);
      if (!props.frame.directed) {
        s.add(`${b}-${a}`);
      }
    }
  }
  return s;
});

const renderedEdges = computed(() =>
  props.frame.edges
    .map(([u, v, w], idx) => {
      const nu = nodeMap.value.get(u);
      const nv = nodeMap.value.get(v);
      if (!nu || !nv) {
        return null;
      }
      const pairKey = `${Math.min(u, v)}-${Math.max(u, v)}`;
      const isMst = mstKeySet.value.has(pairKey);
      const isPath = pathEdgeSet.value.has(`${u}-${v}`);
      const act = props.frame.activeEdge;
      const isActive =
        act !== null &&
        ((act.from === u && act.to === v) ||
          (!props.frame.directed && act.from === v && act.to === u));

      return {
        key: `${idx}-${u}-${v}`,
        x1: nu.x,
        y1: nu.y,
        x2: nv.x,
        y2: nv.y,
        mx: (nu.x + nv.x) / 2,
        my: (nu.y + nv.y) / 2,
        weight: w,
        isMst,
        isPath,
        isActive,
        activeAccepted: isActive ? (act?.accepted ?? true) : false,
      };
    })
    .filter((item): item is NonNullable<typeof item> => item !== null),
);

function edgeStroke(e: (typeof renderedEdges.value)[number]): string {
  if (e.isActive) {
    return e.activeAccepted ? 'var(--accent-sun)' : 'var(--status-danger)';
  }
  if (e.isPath) {
    return 'var(--accent-bloom)';
  }
  if (e.isMst) {
    return 'var(--accent-primary)';
  }
  return 'var(--border-strong)';
}

function nodeFill(nodeId: number): string {
  const compId = props.frame.components[nodeId];
  if (compId !== undefined) {
    return COMPONENT_PALETTE[(compId - 1) % COMPONENT_PALETTE.length] ?? 'var(--accent-primary)';
  }
  if (props.frame.path.includes(nodeId)) {
    return 'var(--accent-bloom)';
  }
  if (props.frame.activeNode === nodeId) {
    return 'var(--accent-sun)';
  }
  if (visitedSet.value.has(nodeId)) {
    return 'var(--accent-primary)';
  }
  if (frontierSet.value.has(nodeId)) {
    return 'var(--accent-orchid)';
  }
  return 'var(--bg-surface)';
}

function nodeStroke(nodeId: number): string {
  if (nodeId === props.frame.startNode) {
    return 'var(--accent-primary)';
  }
  if (nodeId === props.frame.targetNode) {
    return 'var(--accent-bloom)';
  }
  return 'var(--border-strong)';
}

function isFilledNode(nodeId: number): boolean {
  return (
    props.frame.components[nodeId] !== undefined ||
    props.frame.path.includes(nodeId) ||
    props.frame.activeNode === nodeId ||
    visitedSet.value.has(nodeId) ||
    frontierSet.value.has(nodeId)
  );
}
</script>

<template>
  <div class="graph-stage">
    <svg viewBox="0 0 100 100" class="graph-svg" role="img" :aria-label="t.stage.graphAria">
      <defs>
        <marker
          id="garden-arrow"
          viewBox="0 0 10 10"
          refX="14"
          refY="5"
          markerWidth="4.5"
          markerHeight="4.5"
          orient="auto-start-reverse"
        >
          <path d="M 0 1.5 L 10 5 L 0 8.5 z" fill="var(--text-muted)" />
        </marker>
      </defs>

      <g v-for="e in renderedEdges" :key="e.key">
        <line
          :x1="e.x1"
          :y1="e.y1"
          :x2="e.x2"
          :y2="e.y2"
          :stroke="edgeStroke(e)"
          :stroke-width="e.isPath || e.isMst || e.isActive ? 1.85 : 0.9"
          :stroke-dasharray="e.isActive && !e.activeAccepted ? '2 1.5' : undefined"
          :marker-end="frame.directed ? 'url(#garden-arrow)' : undefined"
          stroke-linecap="round"
        />
        <circle
          :cx="e.mx"
          :cy="e.my"
          r="3.2"
          fill="var(--bg-elevated)"
          stroke="var(--border-subtle)"
          stroke-width="0.4"
        />
        <text :x="e.mx" :y="e.my + 0.9" text-anchor="middle" class="edge-weight mono">
          {{ Number.isInteger(e.weight) ? e.weight : e.weight.toFixed(1) }}
        </text>
      </g>

      <g v-for="node in frame.nodes" :key="node.id">
        <circle
          v-if="node.id === frame.startNode || node.id === frame.targetNode"
          :cx="node.x"
          :cy="node.y"
          r="7.4"
          fill="none"
          :stroke="nodeStroke(node.id)"
          stroke-width="0.8"
          stroke-dasharray="1.8 1.2"
        />
        <circle
          :cx="node.x"
          :cy="node.y"
          r="5.6"
          :fill="nodeFill(node.id)"
          :stroke="nodeStroke(node.id)"
          stroke-width="0.95"
        />
        <text
          :x="node.x"
          :y="node.y + 1.2"
          text-anchor="middle"
          class="node-label mono"
          :class="{ 'is-filled': isFilledNode(node.id) }"
        >
          {{ node.label }}
        </text>
      </g>
    </svg>

    <div class="stage-legend">
      <span><i class="stage-swatch stage-swatch--round dot--frontier" /> {{ t.stage.legendFrontier }}</span>
      <span><i class="stage-swatch stage-swatch--round dot--visited" /> {{ t.stage.legendVisited }}</span>
      <span><i class="stage-swatch stage-swatch--round dot--mst" /> {{ t.stage.legendMstPath }}</span>
      <span><i class="stage-swatch stage-swatch--round dot--active" /> {{ t.stage.legendActiveEdge }}</span>
    </div>
  </div>
</template>

<style scoped>
.graph-stage {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.graph-svg {
  width: 100%;
  max-height: 295px;
  border-radius: var(--radius-md);
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
}

.edge-weight {
  font-size: 2.7px;
  fill: var(--text-secondary);
}

.node-label {
  font-size: 3.1px;
  font-weight: 700;
  fill: var(--text-primary);
}

.node-label.is-filled {
  fill: var(--text-on-accent);
}

.dot--frontier {
  background: var(--accent-orchid);
}

.dot--visited {
  background: var(--accent-primary);
}

.dot--mst {
  background: var(--accent-bloom);
}

.dot--active {
  background: var(--accent-sun);
}
</style>
