/**
 * Monaco Editor Boot File for Quasar
 *
 * This boot file configures Monaco editor workers for proper operation in Vite/Quasar
 * and optionally initializes the QBML schema for the JSON editor.
 *
 * ## Installation
 *
 * 1. Copy this file to your Quasar project's `src/boot/` directory
 * 2. Add "monaco" to the boot array in quasar.conf.js:
 *    ```js
 *    boot: ['monaco']
 *    ```
 *
 * 3. Install monaco-editor:
 *    ```bash
 *    npm install monaco-editor
 *    # or
 *    yarn add monaco-editor
 *    ```
 *
 * ## Usage Options
 *
 * ### Option A: Basic Monaco (no QBML schema)
 * ```js
 * // boot/monaco.js
 * import * as monaco from "monaco-editor";
 * import editorWorker from "monaco-editor/esm/vs/editor/editor.worker?worker";
 * import jsonWorker from "monaco-editor/esm/vs/language/json/json.worker?worker";
 *
 * self.MonacoEnvironment = {
 *   getWorker( _, label ) {
 *     if ( label === "json" ) return new jsonWorker();
 *     return new editorWorker();
 *   },
 * };
 *
 * export { monaco };
 * ```
 *
 * ### Option B: With QBML Schema Support
 * ```js
 * // boot/monaco.js
 * import * as monaco from "monaco-editor";
 * import editorWorker from "monaco-editor/esm/vs/editor/editor.worker?worker";
 * import jsonWorker from "monaco-editor/esm/vs/language/json/json.worker?worker";
 * import { initQBMLSchema } from "src/composables/useJsonSchema";
 * import qbmlSchema from "src/schemas/qbml.schema.json";
 *
 * self.MonacoEnvironment = {
 *   getWorker( _, label ) {
 *     if ( label === "json" ) return new jsonWorker();
 *     return new editorWorker();
 *   },
 * };
 *
 * // Initialize QBML schema for rich editing experience
 * initQBMLSchema( qbmlSchema );
 *
 * export { monaco };
 * ```
 *
 * ## Component Usage
 *
 * ### Basic JSON Editor (Progressive Enhancement)
 * ```vue
 * <template>
 *   <MonacoJsonEditor
 *     v-model="jsonData"
 *     title="Configuration"
 *     height="400px"
 *   />
 * </template>
 *
 * <script setup>
 * import { ref } from "vue";
 * import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
 *
 * const jsonData = ref({ key: "value" });
 * </script>
 * ```
 *
 * ### With QBML Schema
 * ```vue
 * <template>
 *   <MonacoJsonEditor
 *     v-model="query"
 *     title="QBML Query"
 *     v-bind="qbmlEditorProps"
 *   />
 * </template>
 *
 * <script setup>
 * import { ref } from "vue";
 * import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
 * import { useJsonSchema } from "src/composables/useJsonSchema";
 *
 * const { getEditorProps } = useJsonSchema();
 * const qbmlEditorProps = getEditorProps( "qbml" );
 *
 * const query = ref([
 *   { from: "users" },
 *   { select: ["*"] },
 *   { get: true }
 * ]);
 * </script>
 * ```
 */

import * as monaco from "monaco-editor";
import editorWorker from "monaco-editor/esm/vs/editor/editor.worker?worker";
import jsonWorker from "monaco-editor/esm/vs/language/json/json.worker?worker";

// Configure Monaco environment to use web workers
// This is required for Vite-based builds (including Quasar)
self.MonacoEnvironment = {
  getWorker( _, label ) {
    if ( label === "json" ) {
      return new jsonWorker();
    }
    return new editorWorker();
  },
};

// Uncomment the following lines to auto-initialize QBML schema:
// import { initQBMLSchema } from "src/composables/useJsonSchema";
// import qbmlSchema from "src/schemas/qbml.schema.json";
// initQBMLSchema( qbmlSchema );

export { monaco };
