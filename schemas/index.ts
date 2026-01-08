/**
 * QBML Schema Package
 *
 * Provides JSON Schema validation, TypeScript types, and Monaco editor
 * integration for QBML (Query Builder Markup Language).
 */

// JSON Schema
export { default as qbmlSchema } from './qbml.schema.json';

// TypeScript types
export * from './qbml.types';

// Monaco editor configuration
export {
  configureQBMLEditor,
  createQBMLModel,
  registerQBMLSnippets,
  qbmlEditorOptions,
  qbmlSnippets,
  qbmlErrorMessages,
  formatQBMLError,
} from './monaco-config';
export type { QBMLEditorOptions } from './monaco-config';

// Vue composables (tree-shakeable)
export { useQBMLEditor, useQBMLValidation } from './vue/useQBMLEditor';
export type {
  UseQBMLEditorReturn,
  QBMLValidationError,
} from './vue/useQBMLEditor';
