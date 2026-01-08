# QBML Editor

A Monaco-based JSON editor component for editing QBML (Query Builder Markup Language) queries. Built with Vue 3 and Quasar Framework.

## Quick Start (Dev Mode)

```bash
# Install dependencies
npm install

# Start dev server
npm run dev
```

The editor will be available at `http://localhost:9000`

## Integration into Your Application

The main component is designed to be copied into your own Vue/Quasar application.

### Required Files

Copy these files to your project:

1. **Component**: `src/components/MonacoJsonEditor.vue`
2. **Composable**: `src/composables/useJsonSchema.js`
3. **Boot file**: `src/boot/monaco.js`
4. **Schema**: `public/qbml.schema.json`

### Dependencies

Add to your `package.json`:

```json
{
  "dependencies": {
    "monaco-editor": "^0.52.2"
  }
}
```

### Quasar Configuration

Register the boot file in `quasar.config.js`:

```js
boot: [
  'monaco'
],
```

### Basic Usage

```vue
<template>
  <MonacoJsonEditor
    v-model="queryData"
    title="QBML Query Editor"
    :schema="editorProps.schema"
    :schema-uri="editorProps.schemaUri"
    :schema-name="editorProps.schemaName"
    :snippets="editorProps.snippets"
    @validation="onValidation"
  />
</template>

<script setup>
import { ref, onMounted } from "vue";
import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
import { useJsonSchema } from "src/composables/useJsonSchema";
import { schemaReady } from "src/boot/monaco";

const { getEditorProps } = useJsonSchema();
const editorProps = ref({});

onMounted(async () => {
  await schemaReady;
  editorProps.value = getEditorProps("qbml");
});

const queryData = ref([
  { "from": "users" },
  { "select": ["*"] },
  { "get": true }
]);

const onValidation = (result) => {
  console.log("Valid:", result.valid, "Errors:", result.errors);
};
</script>
```

### Component Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` | String/Object/Array | `""` | The JSON data (v-model) |
| `title` | String | `""` | Title bar text |
| `schema` | Object | `null` | JSON Schema for validation |
| `schemaUri` | String | `"http://json-schema.org/draft-07/schema#"` | Schema URI |
| `schemaName` | String | `""` | Display name for schema badge |
| `snippets` | Array | `[]` | Code snippets for dropdown |
| `height` | String | `"100%"` | Container height |
| `width` | String | `"100%"` | Container width |
| `fillHeight` | Boolean | `true` | Fill parent height |
| `readOnly` | Boolean | `false` | Disable editing |
| `showToolbar` | Boolean | `true` | Show toolbar |
| `showFooter` | Boolean | `true` | Show status bar |
| `theme` | String | `"vs-dark"` | Monaco theme |
| `minimap` | Boolean | `false` | Show minimap |
| `lineNumbers` | Boolean | `true` | Show line numbers |
| `wordWrap` | String | `"on"` | Word wrap mode |
| `tabSize` | Number | `2` | Tab size |
| `fontSize` | Number | `14` | Font size |

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:modelValue` | Parsed JSON | Emitted on content change |
| `validation` | `{ valid, errors }` | Emitted on validation change |
| `ready` | `{ editor, model }` | Emitted when editor is ready |

### Exposed Methods

```js
const editorRef = ref(null);

// Access methods via ref
editorRef.value.undo();
editorRef.value.redo();
editorRef.value.formatDocument();
editorRef.value.compactJson();
editorRef.value.sortKeys();
editorRef.value.expandAll();
editorRef.value.collapseAll();
editorRef.value.getValue();
editorRef.value.setValue(data);
editorRef.value.validate();
editorRef.value.getEditor(); // Monaco editor instance
editorRef.value.getModel();  // Monaco model instance
```

### Title Bar Actions Slot

Add custom buttons to the title bar:

```vue
<MonacoJsonEditor v-model="data">
  <template #title-actions>
    <q-btn flat dense icon="save" @click="save" />
  </template>
</MonacoJsonEditor>
```

## Building for Production

```bash
npm run build
```

Output will be in `dist/spa/`.

## Features

- JSON Schema validation with inline error highlighting
- QBML-specific code snippets
- Hover tooltips with schema documentation
- Format/compact/sort tools
- Undo/redo support
- Code folding
- Dark theme
- Responsive design
