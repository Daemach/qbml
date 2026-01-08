/**
 * QBML Vue Composable for Monaco Editor Integration
 *
 * Provides reactive QBML editing with validation and autocomplete.
 *
 * Usage:
 *   import { useQBMLEditor } from './useQBMLEditor';
 *
 *   const {
 *     content,
 *     errors,
 *     isValid,
 *     parsedQuery,
 *     setContent,
 *     validate,
 *     format,
 *   } = useQBMLEditor();
 */

import { ref, computed, watch, shallowRef, onMounted, onUnmounted } from 'vue';
import type { Ref, ComputedRef, ShallowRef } from 'vue';
import type * as Monaco from 'monaco-editor';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import type { QBMLQuery, QBMLAction } from '../qbml.types';
import qbmlSchema from '../qbml.schema.json';
import {
  configureQBMLEditor,
  qbmlEditorOptions,
  registerQBMLSnippets,
  formatQBMLError,
} from '../monaco-config';

export interface QBMLEditorOptions {
  /** Initial content */
  initialContent?: string;
  /** Validate on every change (default: true) */
  validateOnChange?: boolean;
  /** Debounce validation (ms, default: 300) */
  validateDebounce?: number;
  /** Custom schema URI */
  schemaUri?: string;
  /** Editor theme */
  theme?: string;
}

export interface QBMLValidationError {
  message: string;
  path: string;
  line?: number;
  column?: number;
  keyword?: string;
}

export interface UseQBMLEditorReturn {
  /** Raw JSON content */
  content: Ref<string>;
  /** Validation errors */
  errors: Ref<QBMLValidationError[]>;
  /** Whether content is valid QBML */
  isValid: ComputedRef<boolean>;
  /** Parsed QBML query (null if invalid) */
  parsedQuery: ComputedRef<QBMLQuery | null>;
  /** Monaco editor instance */
  editor: ShallowRef<Monaco.editor.IStandaloneCodeEditor | null>;
  /** Set content programmatically */
  setContent: (content: string | QBMLQuery) => void;
  /** Validate current content */
  validate: () => boolean;
  /** Format/prettify content */
  format: () => void;
  /** Get content as query object */
  getQuery: () => QBMLQuery | null;
  /** Initialize Monaco editor on element */
  initEditor: (container: HTMLElement, monaco: typeof Monaco) => void;
  /** Dispose editor resources */
  dispose: () => void;
}

/**
 * Vue composable for QBML Monaco editor integration
 */
export function useQBMLEditor(
  options: QBMLEditorOptions = {}
): UseQBMLEditorReturn {
  const {
    initialContent = '[\n  \n]',
    validateOnChange = true,
    validateDebounce = 300,
    schemaUri,
    theme = 'vs-dark',
  } = options;

  // State
  const content = ref<string>(initialContent);
  const errors = ref<QBMLValidationError[]>([]);
  const editor = shallowRef<Monaco.editor.IStandaloneCodeEditor | null>(null);
  const snippetDisposable = shallowRef<Monaco.IDisposable | null>(null);

  // Setup JSON Schema validator
  const ajv = new Ajv({
    allErrors: true,
    verbose: true,
    strict: false,
  });
  addFormats(ajv);

  const validateSchema = ajv.compile(qbmlSchema);

  // Computed
  const isValid = computed(() => errors.value.length === 0);

  const parsedQuery = computed<QBMLQuery | null>(() => {
    try {
      const parsed = JSON.parse(content.value);
      if (Array.isArray(parsed)) {
        return parsed as QBMLQuery;
      }
      return null;
    } catch {
      return null;
    }
  });

  // Methods
  function validate(): boolean {
    errors.value = [];

    // First check JSON syntax
    let parsed: unknown;
    try {
      parsed = JSON.parse(content.value);
    } catch (e) {
      const error = e as SyntaxError;
      errors.value = [
        {
          message: `JSON syntax error: ${error.message}`,
          path: '',
          keyword: 'syntax',
        },
      ];
      return false;
    }

    // Then validate against schema
    const valid = validateSchema(parsed);

    if (!valid && validateSchema.errors) {
      errors.value = validateSchema.errors.map((err) => ({
        message: formatQBMLError({
          message: err.message,
          keyword: err.keyword,
          instancePath: err.instancePath,
          params: err.params as Record<string, unknown>,
        }),
        path: err.instancePath || '',
        keyword: err.keyword,
      }));
    }

    return isValid.value;
  }

  function setContent(newContent: string | QBMLQuery): void {
    if (typeof newContent === 'string') {
      content.value = newContent;
    } else {
      content.value = JSON.stringify(newContent, null, 2);
    }

    if (editor.value) {
      const model = editor.value.getModel();
      if (model) {
        model.setValue(content.value);
      }
    }

    if (validateOnChange) {
      validate();
    }
  }

  function format(): void {
    try {
      const parsed = JSON.parse(content.value);
      const formatted = JSON.stringify(parsed, null, 2);
      setContent(formatted);
    } catch {
      // Can't format invalid JSON
    }
  }

  function getQuery(): QBMLQuery | null {
    if (!validate()) {
      return null;
    }
    return parsedQuery.value;
  }

  function initEditor(
    container: HTMLElement,
    monaco: typeof Monaco
  ): void {
    // Configure Monaco for QBML
    configureQBMLEditor(monaco, { schemaUri });

    // Register snippets
    snippetDisposable.value = registerQBMLSnippets(monaco);

    // Create editor
    editor.value = monaco.editor.create(container, {
      ...qbmlEditorOptions,
      value: content.value,
      theme,
    });

    // Sync content on change
    let debounceTimer: ReturnType<typeof setTimeout> | null = null;

    editor.value.onDidChangeModelContent(() => {
      const model = editor.value?.getModel();
      if (model) {
        content.value = model.getValue();
      }

      if (validateOnChange) {
        if (debounceTimer) {
          clearTimeout(debounceTimer);
        }
        debounceTimer = setTimeout(() => {
          validate();
        }, validateDebounce);
      }
    });

    // Initial validation
    if (validateOnChange) {
      validate();
    }
  }

  function dispose(): void {
    if (snippetDisposable.value) {
      snippetDisposable.value.dispose();
      snippetDisposable.value = null;
    }
    if (editor.value) {
      editor.value.dispose();
      editor.value = null;
    }
  }

  // Cleanup on unmount
  onUnmounted(() => {
    dispose();
  });

  return {
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
  };
}

/**
 * Vue composable for QBML validation only (no editor)
 */
export function useQBMLValidation() {
  const ajv = new Ajv({
    allErrors: true,
    verbose: true,
    strict: false,
  });
  addFormats(ajv);

  const validateSchema = ajv.compile(qbmlSchema);

  function validateQuery(
    query: unknown
  ): { valid: boolean; errors: QBMLValidationError[] } {
    const valid = validateSchema(query);

    if (!valid && validateSchema.errors) {
      return {
        valid: false,
        errors: validateSchema.errors.map((err) => ({
          message: formatQBMLError({
            message: err.message,
            keyword: err.keyword,
            instancePath: err.instancePath,
            params: err.params as Record<string, unknown>,
          }),
          path: err.instancePath || '',
          keyword: err.keyword,
        })),
      };
    }

    return { valid: true, errors: [] };
  }

  function validateJSON(
    json: string
  ): { valid: boolean; errors: QBMLValidationError[]; query: QBMLQuery | null } {
    try {
      const parsed = JSON.parse(json);
      const result = validateQuery(parsed);
      return {
        ...result,
        query: result.valid ? (parsed as QBMLQuery) : null,
      };
    } catch (e) {
      return {
        valid: false,
        errors: [
          {
            message: `JSON syntax error: ${(e as Error).message}`,
            path: '',
            keyword: 'syntax',
          },
        ],
        query: null,
      };
    }
  }

  return {
    validateQuery,
    validateJSON,
  };
}

export default useQBMLEditor;
