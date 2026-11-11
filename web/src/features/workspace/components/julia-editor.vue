<script setup lang="ts">
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
import {
  bracketMatching,
  HighlightStyle,
  indentOnInput,
  StreamLanguage,
  syntaxHighlighting,
} from '@codemirror/language';
import { julia } from '@codemirror/legacy-modes/mode/julia';
import { type Diagnostic, setDiagnostics } from '@codemirror/lint';
import { Compartment, EditorState } from '@codemirror/state';
import {
  EditorView,
  highlightActiveLine,
  highlightActiveLineGutter,
  keymap,
  lineNumbers,
} from '@codemirror/view';
import { tags } from '@lezer/highlight';
import { onMounted, onUnmounted, ref, watch } from 'vue';
import type { ExecutionError } from '../types/execution';

const props = defineProps<{
  modelValue: string;
  theme: 'light' | 'dark';
  error: ExecutionError | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const hostEl = ref<HTMLElement | null>(null);
let view: EditorView | null = null;
const themeCompartment = new Compartment();

function buildThemeExtension(mode: 'light' | 'dark') {
  const isDark = mode === 'dark';
  const uiTheme = EditorView.theme(
    {
      '&': {
        height: '100%',
        fontSize: '13.5px',
        fontFamily: 'var(--font-mono)',
        backgroundColor: isDark ? '#0e1915' : '#fcfbf6',
        color: isDark ? '#e6f2eb' : '#182b22',
      },
      '.cm-scroller': {
        overflow: 'auto',
        fontFamily: 'var(--font-mono)',
        lineHeight: '1.6',
      },
      '.cm-gutters': {
        backgroundColor: isDark ? '#0a1310' : '#f3f0e5',
        color: isDark ? '#5f7e6e' : '#7b9084',
        borderRight: isDark
          ? '1px solid rgba(226, 248, 235, 0.08)'
          : '1px solid rgba(24, 43, 34, 0.09)',
      },
      '.cm-activeLine': {
        backgroundColor: isDark ? 'rgba(57, 211, 153, 0.08)' : 'rgba(27, 122, 87, 0.07)',
      },
      '.cm-activeLineGutter': {
        backgroundColor: isDark ? 'rgba(57, 211, 153, 0.14)' : 'rgba(27, 122, 87, 0.12)',
        color: isDark ? '#39d399' : '#1b7a57',
      },
      '.cm-cursor': {
        borderLeftColor: isDark ? '#39d399' : '#1b7a57',
      },
    },
    { dark: isDark },
  );

  const highlightStyle = HighlightStyle.define([
    { tag: tags.keyword, color: isDark ? '#ff8270' : '#c04f38', fontWeight: '600' },
    { tag: tags.function(tags.variableName), color: isDark ? '#39d399' : '#15704e' },
    { tag: tags.number, color: isDark ? '#f3b848' : '#b3720d' },
    { tag: tags.string, color: isDark ? '#8be0a4' : '#2d7a46' },
    { tag: tags.comment, color: isDark ? '#668474' : '#7c9084', fontStyle: 'italic' },
    { tag: tags.typeName, color: isDark ? '#b794f4' : '#6c47b0' },
    { tag: tags.operator, color: isDark ? '#9ec9b4' : '#3d5a4b' },
  ]);

  return [uiTheme, syntaxHighlighting(highlightStyle)];
}

function applyDiagnostics(err: ExecutionError | null): void {
  if (!view) {
    return;
  }
  const diagnostics: Diagnostic[] = [];
  if (err && err.line !== null && err.line >= 1) {
    const lineNum = Math.min(err.line, view.state.doc.lines);
    const line = view.state.doc.line(lineNum);
    diagnostics.push({
      from: line.from,
      to: line.to,
      severity: 'error',
      message: `${err.message}${err.hint ? ` (${err.hint})` : ''}`,
    });
  }
  view.dispatch(setDiagnostics(view.state, diagnostics));
}

onMounted(() => {
  if (!hostEl.value) {
    return;
  }
  const state = EditorState.create({
    doc: props.modelValue,
    extensions: [
      lineNumbers(),
      highlightActiveLineGutter(),
      highlightActiveLine(),
      history(),
      indentOnInput(),
      bracketMatching(),
      StreamLanguage.define(julia),
      keymap.of([indentWithTab, ...defaultKeymap, ...historyKeymap]),
      themeCompartment.of(buildThemeExtension(props.theme)),
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          emit('update:modelValue', update.state.doc.toString());
        }
      }),
    ],
  });

  view = new EditorView({ state, parent: hostEl.value });
  applyDiagnostics(props.error);
});

watch(
  () => props.modelValue,
  (next) => {
    if (!view) {
      return;
    }
    const current = view.state.doc.toString();
    if (next !== current) {
      view.dispatch({
        changes: { from: 0, to: current.length, insert: next },
      });
    }
  },
);

watch(
  () => props.theme,
  (next) => {
    if (!view) {
      return;
    }
    view.dispatch({
      effects: themeCompartment.reconfigure(buildThemeExtension(next)),
    });
  },
);

watch(
  () => props.error,
  (next) => {
    applyDiagnostics(next);
  },
);

onUnmounted(() => {
  view?.destroy();
  view = null;
});
</script>

<template>
  <div ref="hostEl" class="julia-editor-host" />
</template>

<style scoped>
.julia-editor-host {
  width: 100%;
  height: 100%;
  min-height: 320px;
  border-radius: var(--radius-md);
  overflow: hidden;
  border: 1px solid var(--border-subtle);
}
</style>
