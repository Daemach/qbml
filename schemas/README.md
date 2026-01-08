# QBML JSON Schema & Editor

JSON Schema, TypeScript definitions, and Vue components for QBML (Query Builder Markup Language).

## Features

- **JSON Schema** - Full validation with rich descriptions linking to qb docs
- **TypeScript Types** - Complete type definitions for type-safe queries
- **Monaco Integration** - Rich autocomplete, pinnable hover tooltips, and validation
- **Vue Components** - Feature-rich MonacoJsonEditor with toolbar and snippets
- **Progressive Enhancement** - Editor works without schema, enhanced with it
- **Quasar Ready** - Boot file and composables for Quasar projects

## Quick Start for Quasar

### 1. Install Dependencies

```bash
npm install monaco-editor
# or
yarn add monaco-editor
```

### 2. Copy Files to Your Project

```
src/
├── boot/
│   └── monaco.js           # Copy from schemas/vue/boot-monaco.js
├── composables/
│   └── useJsonSchema.js    # Copy from schemas/vue/useJsonSchema.js
├── components/
│   └── MonacoJsonEditor.vue # Copy from schemas/vue/MonacoJsonEditor.vue
└── schemas/
    └── qbml.schema.json    # Copy from schemas/qbml.schema.json
```

### 3. Configure Quasar Boot

Add to `quasar.conf.js`:

```js
boot: ['monaco']
```

### 4. Create Boot File

`src/boot/monaco.js`:

```js
import * as monaco from "monaco-editor";
import editorWorker from "monaco-editor/esm/vs/editor/editor.worker?worker";
import jsonWorker from "monaco-editor/esm/vs/language/json/json.worker?worker";
import { initQBMLSchema } from "src/composables/useJsonSchema";
import qbmlSchema from "src/schemas/qbml.schema.json";

self.MonacoEnvironment = {
  getWorker( _, label ) {
    if ( label === "json" ) return new jsonWorker();
    return new editorWorker();
  },
};

// Initialize QBML schema
initQBMLSchema( qbmlSchema );

export { monaco };
```

### 5. Use the Editor

```vue
<template>
  <MonacoJsonEditor
    v-model="query"
    title="QBML Query"
    v-bind="qbmlEditorProps"
    height="500px"
  />
</template>

<script setup>
import { ref } from "vue";
import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
import { useJsonSchema } from "src/composables/useJsonSchema";

const { getEditorProps } = useJsonSchema();
const qbmlEditorProps = getEditorProps( "qbml" );

const query = ref([
  { from: "users" },
  { select: ["*"] },
  { get: true }
]);
</script>
```

## Progressive Enhancement

The MonacoJsonEditor works in two modes:

### Basic Mode (No Schema)

Just a powerful JSON editor with formatting, folding, and validation:

```vue
<MonacoJsonEditor
  v-model="jsonData"
  title="Configuration"
  height="400px"
/>
```

### Enhanced Mode (With Schema)

Full QBML support with autocomplete, hover docs, and snippets:

```vue
<MonacoJsonEditor
  v-model="query"
  v-bind="getEditorProps('qbml')"
  title="QBML Query"
/>
```

## MonacoJsonEditor Features

### Toolbar
- **Undo/Redo** - Full history support
- **Format** - Pretty print JSON
- **Compact** - Minify JSON
- **Sort Keys** - Alphabetical sorting
- **Expand/Collapse** - Code folding controls
- **Snippets** - Dropdown with QBML templates and clauses

### Custom Hover Tooltips
- Rich markdown rendering with code blocks
- Clickable links to qb documentation
- **Pinnable** - Click the pin to keep tooltip open
- Golden rectangle proportions for optimal readability

### Validation
- Real-time schema validation
- Error count badge in toolbar
- Clickable error list to navigate to issues

### Footer Status
- Cursor position (line, column)
- Character and line counts

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `modelValue` | String/Object/Array | `""` | v-model value |
| `title` | String | `""` | Title bar text |
| `schema` | Object | `null` | JSON Schema for validation |
| `schemaUri` | String | `"http://json-schema.org/draft-07/schema#"` | Schema URI |
| `schemaName` | String | `""` | Schema name badge |
| `snippets` | Array | `[]` | Code snippets for dropdown |
| `height` | String | `"300px"` | Editor height |
| `width` | String | `"100%"` | Editor width |
| `fillHeight` | Boolean | `false` | Expand to fill parent |
| `readOnly` | Boolean | `false` | Read-only mode |
| `showToolbar` | Boolean | `true` | Show toolbar |
| `showFooter` | Boolean | `true` | Show footer |
| `theme` | String | `"vs-dark"` | Monaco theme |
| `minimap` | Boolean | `false` | Show minimap |
| `lineNumbers` | Boolean | `true` | Show line numbers |
| `tabSize` | Number | `2` | Tab size |
| `fontSize` | Number | `13` | Font size |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:modelValue` | `any` | v-model update |
| `validation` | `{ valid, errors }` | Validation state change |
| `ready` | `{ editor, model }` | Editor initialized |

## Exposed Methods

Access via template ref:

```js
const editorRef = ref(null);

// Methods
editorRef.value.formatDocument();
editorRef.value.compactJson();
editorRef.value.sortKeys();
editorRef.value.expandAll();
editorRef.value.collapseAll();
editorRef.value.undo();
editorRef.value.redo();
editorRef.value.validate();

// Getters
editorRef.value.getValue();
editorRef.value.getEditor();
editorRef.value.getModel();

// Setters
editorRef.value.setValue(newValue);
```

## Schema Registry (useJsonSchema)

Register and manage multiple schemas:

```js
import {
  useJsonSchema,
  registerSchema,
  initQBMLSchema,
  qbmlSnippets
} from "src/composables/useJsonSchema";

// Register QBML (built-in)
initQBMLSchema( qbmlSchema );

// Register custom schema
registerSchema( "mySchema", {
  schema: myJsonSchema,
  name: "My Schema",
  snippets: mySnippets,
  uri: "https://example.com/my.schema.json",
  docsUrl: "https://docs.example.com",
} );

// Use in component
const { getEditorProps, hasSchema, getSchemaIds } = useJsonSchema();

if ( hasSchema( "mySchema" ) ) {
  const props = getEditorProps( "mySchema" );
}
```

## Snippet Format

```js
const mySnippets = [
  {
    label: "my-template",           // Unique ID for autocomplete
    detail: "My Template",          // Display name in dropdown
    documentation: "Creates...",    // Description text
    insertText: `{
  "name": "\${1:defaultName}",
  "value": \${2:0}
}`
  }
];
```

Tab stop syntax:
- `${1:placeholder}` - First tab stop with default text
- `${2}` - Second tab stop, no default
- Numbers indicate tab order

## Schema Description Format

For rich hover tooltips, use markdown in schema descriptions:

```json
{
  "description": "**WHERE IN - Filter by Multiple Values**\n\nFilters results where column matches any value in array.\n\n```json\n{ \"whereIn\": [\"status\", [\"active\", \"pending\"]] }\n```\n\n[qb docs](https://qb.ortusbooks.com/query-builder/building-queries/wheres#wherein)"
}
```

Supported markdown:
- `**bold**` and `*italic*`
- `` `inline code` `` and triple-backtick code blocks
- `[text](url)` links
- Line breaks with `\n`

## Alternative Integrations

### TypeScript Types Only

```typescript
import type { QBMLQuery, QBMLAction, ParamRef } from './schemas/qbml.types';
import { isParamRef, isRawExpression } from './schemas/qbml.types';

const query: QBMLQuery = [
  { from: 'users' },
  { select: ['*'] },
  { get: true }
];
```

### JSON Schema Validation (AJV)

```js
import Ajv from 'ajv';
import qbmlSchema from './schemas/qbml.schema.json';

const ajv = new Ajv();
const validate = ajv.compile(qbmlSchema);

if (!validate(query)) {
  console.log(validate.errors);
}
```

### Monaco Direct Integration (TypeScript)

```typescript
import { configureQBMLEditor, registerQBMLSnippets } from './schemas/monaco-config';

configureQBMLEditor(monaco);
const disposable = registerQBMLSnippets(monaco);
```

## Files

```
schemas/
├── qbml.schema.json      # JSON Schema (draft-07) with rich descriptions
├── qbml.types.ts         # TypeScript type definitions
├── monaco-config.ts      # Monaco editor configuration (TypeScript)
├── index.ts              # Package exports
├── README.md             # This file
└── vue/
    ├── MonacoJsonEditor.vue  # Feature-rich Monaco component
    ├── useJsonSchema.js      # Schema registry composable
    ├── boot-monaco.js        # Quasar boot file example
    ├── QBMLEditor.vue        # Simpler QBML-specific component
    └── useQBMLEditor.ts      # TypeScript composable
```

## Browser Compatibility

- Modern browsers with ES2020+ support
- Monaco Editor 0.34+
- Vue 3.2+
- Quasar 2.x
- Vite 4+

## Documentation Links

Each schema definition includes clickable links to qb documentation:
- https://qb.ortusbooks.com/

## License

MIT
