<script setup lang="ts">
/**
 * QBML Monaco Editor Vue Component
 *
 * A ready-to-use QBML JSON editor with:
 * - Schema validation and autocomplete
 * - Rich hover documentation with qb links
 * - Code snippets for common patterns
 * - Error highlighting and messages
 *
 * Usage:
 *   <QBMLEditor
 *     v-model="query"
 *     :height="400"
 *     @validate="handleValidation"
 *   />
 */

import { ref, watch, onMounted, onBeforeUnmount, computed } from 'vue';
import type { PropType } from 'vue';
import * as monaco from 'monaco-editor';
import type { QBMLQuery } from '../qbml.types';
import { useQBMLEditor } from './useQBMLEditor';

const props = defineProps({
  /** v-model value - QBML query as JSON string or array */
  modelValue: {
    type: [String, Array] as PropType<string | QBMLQuery>,
    default: '[\n  \n]',
  },
  /** Editor height in pixels or CSS value */
  height: {
    type: [Number, String] as PropType<number | string>,
    default: 400,
  },
  /** Editor width */
  width: {
    type: [Number, String] as PropType<number | string>,
    default: '100%',
  },
  /** Monaco theme */
  theme: {
    type: String as PropType<'vs' | 'vs-dark' | 'hc-black'>,
    default: 'vs-dark',
  },
  /** Read-only mode */
  readonly: {
    type: Boolean,
    default: false,
  },
  /** Show validation errors panel */
  showErrors: {
    type: Boolean,
    default: true,
  },
  /** Validate on content change */
  validateOnChange: {
    type: Boolean,
    default: true,
  },
  /** Debounce validation (ms) */
  validateDebounce: {
    type: Number,
    default: 300,
  },
});

const emit = defineEmits<{
  'update:modelValue': [value: string];
  'validate': [result: { valid: boolean; errors: unknown[]; query: QBMLQuery | null }];
  'change': [value: string];
}>();

// Refs
const editorContainer = ref<HTMLElement | null>(null);

// Use QBML editor composable
const {
  content,
  errors,
  isValid,
  parsedQuery,
  editor,
  setContent,
  validate,
  format,
  getQuery,
  initEditor,
  dispose,
} = useQBMLEditor({
  initialContent: typeof props.modelValue === 'string'
    ? props.modelValue
    : JSON.stringify(props.modelValue, null, 2),
  validateOnChange: props.validateOnChange,
  validateDebounce: props.validateDebounce,
  theme: props.theme,
});

// Computed styles
const containerStyle = computed(() => ({
  height: typeof props.height === 'number' ? `${props.height}px` : props.height,
  width: typeof props.width === 'number' ? `${props.width}px` : props.width,
}));

const editorStyle = computed(() => ({
  height: props.showErrors && errors.value.length > 0
    ? 'calc(100% - 100px)'
    : '100%',
}));

// Watch for external changes
watch(
  () => props.modelValue,
  (newValue) => {
    const newContent = typeof newValue === 'string'
      ? newValue
      : JSON.stringify(newValue, null, 2);

    if (newContent !== content.value) {
      setContent(newContent);
    }
  }
);

// Watch for internal changes
watch(content, (newContent) => {
  emit('update:modelValue', newContent);
  emit('change', newContent);
});

// Watch validation changes
watch([isValid, errors], () => {
  emit('validate', {
    valid: isValid.value,
    errors: errors.value,
    query: parsedQuery.value,
  });
});

// Watch theme changes
watch(
  () => props.theme,
  (newTheme) => {
    if (editor.value) {
      monaco.editor.setTheme(newTheme);
    }
  }
);

// Watch readonly changes
watch(
  () => props.readonly,
  (readonly) => {
    if (editor.value) {
      editor.value.updateOptions({ readOnly: readonly });
    }
  }
);

// Lifecycle
onMounted(() => {
  if (editorContainer.value) {
    initEditor(editorContainer.value, monaco);

    if (editor.value) {
      editor.value.updateOptions({ readOnly: props.readonly });
    }
  }
});

onBeforeUnmount(() => {
  dispose();
});

// Expose methods
defineExpose({
  validate,
  format,
  getQuery,
  setContent,
  getEditor: () => editor.value,
});
</script>

<template>
  <div class="qbml-editor" :style="containerStyle">
    <div
      ref="editorContainer"
      class="qbml-editor__monaco"
      :style="editorStyle"
    />

    <div
      v-if="showErrors && errors.length > 0"
      class="qbml-editor__errors"
    >
      <div class="qbml-editor__errors-header">
        <span class="qbml-editor__errors-icon">⚠</span>
        <span>{{ errors.length }} validation error{{ errors.length > 1 ? 's' : '' }}</span>
      </div>
      <ul class="qbml-editor__errors-list">
        <li
          v-for="(error, index) in errors"
          :key="index"
          class="qbml-editor__error"
        >
          <span v-if="error.path" class="qbml-editor__error-path">{{ error.path }}</span>
          <span class="qbml-editor__error-message">{{ error.message }}</span>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.qbml-editor {
  display: flex;
  flex-direction: column;
  border: 1px solid #374151;
  border-radius: 4px;
  overflow: hidden;
}

.qbml-editor__monaco {
  flex: 1;
  min-height: 200px;
}

.qbml-editor__errors {
  max-height: 100px;
  overflow-y: auto;
  background: #1f1f1f;
  border-top: 1px solid #374151;
  font-family: monospace;
  font-size: 12px;
}

.qbml-editor__errors-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: #2d2d2d;
  color: #f59e0b;
  font-weight: 500;
}

.qbml-editor__errors-icon {
  font-size: 14px;
}

.qbml-editor__errors-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.qbml-editor__error {
  padding: 6px 12px;
  border-bottom: 1px solid #374151;
  color: #f87171;
}

.qbml-editor__error:last-child {
  border-bottom: none;
}

.qbml-editor__error-path {
  color: #9ca3af;
  margin-right: 8px;
}

.qbml-editor__error-path::after {
  content: ':';
}

.qbml-editor__error-message {
  color: #fca5a5;
}
</style>
