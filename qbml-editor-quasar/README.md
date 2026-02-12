# MonacoJsonEditor

A feature-rich JSON editor component for Vue 3 + Quasar, powered by Monaco Editor.
Schema validation, autocomplete, snippets, and rich hover tooltips.

## Setup

### 1. Install dependencies

```bash
npm install monaco-editor json-stringify-pretty-compact
```

### 2. Copy files into your Quasar project

```text
your-project/
  src/boot/monaco.js                  # Worker config + schema init
  src/composables/useJsonSchema.js    # Schema registry composable
  src/components/MonacoJsonEditor.vue
  public/qbml.schema.json            # Or your own JSON Schema
```

### 3. Register the boot file

In `quasar.config.js`:

```js
boot: ['monaco']
```

## Usage

```vue
<template>
  <MonacoJsonEditor
    v-model="queryString"
    v-bind="editorProps"
    title="QBML Query"
    @validation="({ valid, errors }) => console.log(valid, errors)"
  />
</template>

<script setup>
import { ref, onMounted } from "vue";
import stringify from "json-stringify-pretty-compact";
import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
import { useJsonSchema } from "src/composables/useJsonSchema";
import { schemaReady } from "src/boot/monaco";

const { getEditorProps } = useJsonSchema();
const editorProps = ref({});

onMounted(async () => {
  await schemaReady;
  editorProps.value = getEditorProps("qbml");
});

const queryString = ref(stringify([
  { from: "users" },
  { select: ["*"] },
  { get: true }
], { indent: 2 }));
</script>
```

## API

### Props

| Prop | Type | Default | Description |
| ---- | ---- | ------- | ----------- |
| `modelValue` | `String` | `"[\n\n]"` | JSON string (v-model) |
| `title` | `String` | `""` | Title bar text |
| `schema` | `Object` | `null` | JSON Schema for validation/autocomplete |
| `schemaUri` | `String` | draft-07 URI | Schema identifier URI |
| `schemaName` | `String` | `""` | Badge label in toolbar |
| `snippets` | `Array` | `[]` | Code snippets for toolbar dropdowns |
| `height` | `String` | `"100%"` | Container height |
| `width` | `String` | `"100%"` | Container width |
| `fillHeight` | `Boolean` | `true` | Fill parent height |
| `readOnly` | `Boolean` | `false` | Disable editing |
| `showToolbar` | `Boolean` | `true` | Show/hide toolbar |
| `showFooter` | `Boolean` | `true` | Show/hide status bar |
| `theme` | `String` | `"vs-dark"` | Monaco theme name |
| `minimap` | `Boolean` | `false` | Show code minimap |
| `lineNumbers` | `Boolean` | `true` | Show line numbers |
| `wordWrap` | `String` | `"on"` | Word wrap mode |
| `tabSize` | `Number` | `2` | Indentation size |
| `fontSize` | `Number` | `14` | Editor font size |

### Events

| Event | Payload | Description |
| ----- | ------- | ----------- |
| `update:modelValue` | `String` | Raw editor content string |
| `validation` | `{ valid, errors }` | Fires on validation state change |
| `ready` | `{ editor, model }` | Fires when Monaco is initialized |

### Exposed Methods

Access via template ref: `<MonacoJsonEditor ref="editorRef" />`

| Method | Description |
| ------ | ----------- |
| `undo()` / `redo()` | History navigation |
| `formatDocument()` | Pretty-print JSON |
| `compactJson()` | Minify JSON |
| `sortKeys()` | Sort object keys alphabetically |
| `expandAll()` / `collapseAll()` | Code folding |
| `goToError(error)` | Jump to a validation error |
| `getValue()` | Get current editor content string |
| `validate()` | Trigger validation manually |
| `getEditor()` / `getModel()` | Access Monaco instances |

### Slots

| Slot              | Description                                                |
| ----------------- | ---------------------------------------------------------- |
| `#title-actions`  | Inject buttons into the title bar (requires `title` prop)  |
