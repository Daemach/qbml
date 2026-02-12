<template>
  <div ref="rootContainer" class="monaco-json-editor" :class="{ dark: isDark }" :style="containerStyle">
    <!-- Title Bar -->
    <div v-if="props.title" class="monaco-title-bar">
      <span class="title-text">{{ props.title }}</span>
      <span class="spacer"></span>
      <slot name="title-actions"></slot>
    </div>

    <!-- Toolbar -->
    <div v-if="props.showToolbar" class="monaco-toolbar">
      <!-- Undo/Redo -->
      <q-btn
        flat
        dense
        icon="undo"
        title="Undo (Ctrl+Z)"
        :disable="!canUndo"
        @click="undo"
      />
      <q-btn
        flat
        dense
        icon="redo"
        title="Redo (Ctrl+Y)"
        :disable="!canRedo"
        @click="redo"
      />
      <q-separator vertical class="q-mx-xs" />

      <!-- Format/Compact -->
      <q-btn
        flat
        dense
        icon="format_align_left"
        title="Format JSON (pretty print)"
        @click="formatDocument"
      />
      <q-btn
        flat
        dense
        icon="compress"
        title="Compact JSON (minify)"
        @click="compactJson"
      />
      <q-separator vertical class="q-mx-xs" />

      <!-- Sort -->
      <q-btn
        flat
        dense
        icon="sort_by_alpha"
        title="Sort keys (SQL clause order)"
        @click="sortKeys"
      />
      <q-separator vertical class="q-mx-xs" />

      <!-- Folding -->
      <q-btn
        flat
        dense
        icon="unfold_more"
        title="Expand All"
        @click="expandAll"
      />
      <q-btn
        flat
        dense
        icon="unfold_less"
        title="Collapse All"
        @click="collapseAll"
      />

      <q-space />

      <!-- Per-group snippet buttons (right-aligned) -->
      <template v-if="props.snippets && props.snippets.length > 0">
        <q-btn-dropdown
          v-for="[ group, items ] in groupedSnippets"
          :key="group"
          flat
          dense
          no-icon-animation
          :label="groupLabels[ group ] || group"
          dropdown-icon="expand_more"
          anchor="bottom end"
          self="top end"
        >
          <q-list style="max-height: 400px; overflow-y: auto; min-width: 320px">
            <q-item
              v-for="snippet in items"
              :key="snippet.label"
              clickable
              v-close-popup
              @click="insertSnippet( snippet )"
            >
              <q-item-section>
                <q-item-label>{{ snippet.label }}</q-item-label>
                <q-item-label caption>{{ snippet.documentation }}</q-item-label>
                <q-item-label
                  :style="snippetPreviewStyle"
                >{{ snippetPreview( snippet ) }}</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </q-btn-dropdown>
        <q-separator vertical class="q-mx-xs" />
      </template>

      <!-- Schema indicator -->
      <q-badge v-if="props.schemaName" color="grey-7" class="q-mr-sm">
        {{ props.schemaName }}
      </q-badge>

      <!-- Validation Status -->
      <q-badge
        v-if="hasErrors"
        color="negative"
        class="cursor-pointer"
        @click="showErrorPanel = !showErrorPanel"
      >
        {{ errorCount }} {{ errorCount === 1 ? "error" : "errors" }}
      </q-badge>
      <q-badge
        v-else-if="isValidJson"
        color="positive"
      >
        Valid
      </q-badge>
    </div>

    <!-- Error Panel -->
    <div v-if="showErrorPanel && hasErrors" class="monaco-error-panel">
      <div
        v-for="( error, idx ) in validationErrors"
        :key="idx"
        class="error-item"
        @click="goToError( error )"
      >
        <span class="error-path">{{ error.path || "root" }}:</span>
        <span class="error-message">{{ error.message }}</span>
      </div>
    </div>

    <!-- Editor -->
    <div
      ref="editorContainer"
      class="editor-container"
      :style="editorContainerStyle"
    ></div>

    <!-- Footer Status Bar -->
    <div v-if="props.showFooter" class="monaco-footer">
      <span class="cursor-info">
        Ln {{ cursorLine }}, Col {{ cursorColumn }}
      </span>
      <q-space />
      <span class="char-count">
        {{ charCount }} chars
      </span>
      <q-separator vertical class="q-mx-sm" />
      <span class="line-count">
        {{ lineCount }} lines
      </span>
    </div>
  </div>
</template>

<script setup>
/**
 * MonacoJsonEditor - A reusable JSON editor with schema validation, snippets, and toolbar.
 *
 * v-model is STRING ONLY. The parent owns serialization.
 * Uses executeEdits + pushUndoStop for all content mutations to preserve undo/cursor.
 */
import { ref, shallowRef, watch, onMounted, onBeforeUnmount, computed, nextTick, markRaw } from "vue";
import { useQuasar } from "quasar";
import * as monaco from "monaco-editor";
import stringify from "json-stringify-pretty-compact";

// ---------------------------------------------------------------------------
// Global schema registry shared across all MonacoJsonEditor instances
// ---------------------------------------------------------------------------
const globalSchemaRegistry = new Map();

const cloneSchema = ( schema ) => {
  try {
    return JSON.parse( JSON.stringify( schema ) );
  } catch {
    return null;
  }
};

const updateGlobalSchemaConfig = () => {
  const schemas = Array.from( globalSchemaRegistry.values() )
    .map( entry => ( {
      uri: entry.uri,
      fileMatch: entry.fileMatch,
      schema: cloneSchema( entry.schema ),
    } ) )
    .filter( entry => entry.schema !== null );

  monaco.languages.json.jsonDefaults.setDiagnosticsOptions( {
    validate: true,
    schemas,
    allowComments: false,
    trailingCommas: "error",
    schemaValidation: "error",
    enableSchemaRequest: false,
  } );

  monaco.languages.json.jsonDefaults.setModeConfiguration( {
    documentFormattingEdits: true,
    documentRangeFormattingEdits: true,
    completionItems: true,
    hovers: true,
    documentSymbols: true,
    tokens: true,
    colors: true,
    foldingRanges: true,
    diagnostics: true,
    selectionRanges: true,
  } );
};

// ---------------------------------------------------------------------------
// Props & emits
// ---------------------------------------------------------------------------
const props = defineProps( {
  modelValue: {
    type: String,
    default: "[\n\n]",
  },
  title: {
    type: String,
    default: "",
  },
  schema: {
    type: Object,
    default: null,
  },
  schemaUri: {
    type: String,
    default: "http://json-schema.org/draft-07/schema#",
  },
  schemaName: {
    type: String,
    default: "",
  },
  snippets: {
    type: Array,
    default: () => [],
  },
  height: {
    type: String,
    default: "100%",
  },
  width: {
    type: String,
    default: "100%",
  },
  fillHeight: {
    type: Boolean,
    default: true,
  },
  readOnly: {
    type: Boolean,
    default: false,
  },
  showToolbar: {
    type: Boolean,
    default: true,
  },
  showFooter: {
    type: Boolean,
    default: true,
  },
  theme: {
    type: String,
    default: "vs-dark",
  },
  minimap: {
    type: Boolean,
    default: false,
  },
  lineNumbers: {
    type: Boolean,
    default: true,
  },
  wordWrap: {
    type: String,
    default: "on",
  },
  tabSize: {
    type: Number,
    default: 2,
  },
  fontSize: {
    type: Number,
    default: 14,
  },
} );

const emit = defineEmits( [ "update:modelValue", "validation", "ready" ] );

const $q = useQuasar();
const isDark = computed( () => $q.dark.isActive );

// ---------------------------------------------------------------------------
// Refs
// ---------------------------------------------------------------------------
const editorContainer = ref( null );
const rootContainer = ref( null );
const editorRef = shallowRef( null );
const modelRef = shallowRef( null );
let resizeObserver = null;

// Synchronous flag to prevent v-model feedback loop.
// onDidChangeModelContent fires synchronously during executeEdits,
// so this MUST use try/finally, NOT nextTick.
let isApplyingExternalChange = false;

// UI state
const hasErrors = ref( false );
const errorCount = ref( 0 );
const isValidJson = ref( true );
const validationErrors = ref( [] );
const showErrorPanel = ref( false );
const canUndo = ref( false );
const canRedo = ref( false );
const cursorLine = ref( 1 );
const cursorColumn = ref( 1 );
const charCount = ref( 0 );
const lineCount = ref( 1 );

// ---------------------------------------------------------------------------
// Layout calculations
// ---------------------------------------------------------------------------
const TITLE_HEIGHT = 40;
const TOOLBAR_HEIGHT = 40;
const FOOTER_HEIGHT = 28;
const ERROR_PANEL_MAX_HEIGHT = 80;

const containerStyle = computed( () => ( {
  height: props.fillHeight ? "100%" : props.height,
  width: props.width,
  flex: props.fillHeight ? "1 1 auto" : undefined,
  minHeight: props.fillHeight ? "200px" : undefined,
} ) );

const editorContainerStyle = computed( () => {
  const offsets = [];
  if ( props.title ) offsets.push( `${TITLE_HEIGHT}px` );
  if ( props.showToolbar ) offsets.push( `${TOOLBAR_HEIGHT}px` );
  if ( props.showFooter ) offsets.push( `${FOOTER_HEIGHT}px` );
  if ( showErrorPanel.value && hasErrors.value ) offsets.push( `${ERROR_PANEL_MAX_HEIGHT}px` );
  const height = offsets.length > 0
    ? `calc(100% - ${offsets.join( " - " )})`
    : "100%";
  return { height };
} );

// ---------------------------------------------------------------------------
// Snippet categorization
// ---------------------------------------------------------------------------
const groupLabels = {
  "Query Templates": "Templates",
  "Inserts, Updates & Deletes": "DML",
  "Wheres": "Where",
  "Joins": "Join",
  "Ordering, Grouping & Limit": "Order",
  "Common Table Expressions": "CTE",
  "Unions": "Union",
  "When (Conditional)": "When",
};

const groupedSnippets = computed( () => {
  const groups = new Map();
  for ( const snippet of props.snippets || [] ) {
    const group = snippet.detail || "Other";
    if ( !groups.has( group ) ) groups.set( group, [] );
    groups.get( group ).push( snippet );
  }
  return groups;
} );

/** Inline styles for snippet preview (portaled by Quasar, can't use scoped CSS) */
const snippetPreviewStyle = computed( () => ( {
  fontFamily: "'Cascadia Code', 'Fira Code', Consolas, monospace",
  fontSize: "11px",
  lineHeight: "1.3",
  color: isDark.value ? "#9ca3af" : "#64748b",
  background: isDark.value ? "#1a1a2e" : "#f1f5f9",
  borderRadius: "4px",
  padding: "6px 8px",
  marginTop: "4px",
  whiteSpace: "pre",
  overflowX: "auto",
  maxHeight: "120px",
} ) );

/** Strip snippet placeholders to show actual JSON preview */
const snippetPreview = ( snippet ) => {
  let text = snippet.insertText || "";
  text = text.replace( /\$\{(\d+):([^}]+)\}/g, "$2" );
  text = text.replace( /\$\{\d+\}/g, "" );
  text = text.replace( /\\n/g, "\n" );
  text = text.replace( /\\(.)/g, "$1" );
  const lines = text.split( "\n" );
  if ( lines.length > 6 ) {
    return lines.slice( 0, 6 ).join( "\n" ) + "\n  ...";
  }
  return text;
};

// ---------------------------------------------------------------------------
// Schema management
// ---------------------------------------------------------------------------
const configureSchema = () => {
  const model = modelRef.value;
  if ( !props.schema || !model ) return;
  const modelUri = model.uri.toString();
  globalSchemaRegistry.set( modelUri, {
    uri: props.schemaUri,
    fileMatch: [ modelUri ],
    schema: props.schema,
  } );
  updateGlobalSchemaConfig();
};

const cleanupSchema = () => {
  const model = modelRef.value;
  if ( model ) {
    globalSchemaRegistry.delete( model.uri.toString() );
    updateGlobalSchemaConfig();
  }
};

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------
const updateValidationState = () => {
  const model = modelRef.value;
  if ( !model ) return;

  const markers = monaco.editor.getModelMarkers( { resource: model.uri } );
  const errors = markers.filter( m => m.severity === monaco.MarkerSeverity.Error );

  validationErrors.value = errors.map( m => ( {
    message: m.message,
    path: m.relatedInformation?.[ 0 ]?.message || "",
    line: m.startLineNumber,
    column: m.startColumn,
  } ) );

  hasErrors.value = errors.length > 0;
  errorCount.value = errors.length;

  try {
    JSON.parse( model.getValue() );
    isValidJson.value = !hasErrors.value;
  } catch {
    isValidJson.value = false;
    if ( validationErrors.value.length === 0 ) {
      validationErrors.value = [ { message: "Invalid JSON", path: "", line: 1, column: 1 } ];
      hasErrors.value = true;
      errorCount.value = 1;
    }
  }

  emit( "validation", { valid: isValidJson.value && !hasErrors.value, errors: validationErrors.value } );
};

const goToError = ( error ) => {
  const editor = editorRef.value;
  if ( editor && error.line ) {
    editor.setPosition( { lineNumber: error.line, column: error.column || 1 } );
    editor.revealLineInCenter( error.line );
    editor.focus();
  }
};

// ---------------------------------------------------------------------------
// Status bar helpers
// ---------------------------------------------------------------------------
const updateUndoRedoState = () => {
  const model = modelRef.value;
  if ( !model ) return;
  canUndo.value = model.getAlternativeVersionId() > 1;
  canRedo.value = false;
};

const updateCursorInfo = () => {
  const editor = editorRef.value;
  if ( !editor ) return;
  const position = editor.getPosition();
  if ( position ) {
    cursorLine.value = position.lineNumber;
    cursorColumn.value = position.column;
  }
};

const updateContentInfo = () => {
  const model = modelRef.value;
  if ( !model ) return;
  const content = model.getValue();
  charCount.value = content.length;
  lineCount.value = model.getLineCount();
};

// ---------------------------------------------------------------------------
// Toolbar actions
// ---------------------------------------------------------------------------
const undo = () => editorRef.value?.trigger( "toolbar", "undo", null );
const redo = () => editorRef.value?.trigger( "toolbar", "redo", null );
const formatDocument = () => {
  const editor = editorRef.value;
  const model = modelRef.value;
  if ( !editor || !model ) return;
  try {
    const parsed = JSON.parse( editor.getValue() );
    const formatted = stringify( parsed, { indent: props.tabSize, maxLength: 80 } );
    editor.pushUndoStop();
    editor.executeEdits( "format", [ {
      range: model.getFullModelRange(),
      text: formatted,
      forceMoveMarkers: true,
    } ] );
    editor.pushUndoStop();
  } catch { /* ignore invalid JSON */ }
};

const compactJson = () => {
  const editor = editorRef.value;
  const model = modelRef.value;
  if ( !editor || !model ) return;
  try {
    const parsed = JSON.parse( editor.getValue() );
    const compacted = JSON.stringify( parsed );
    editor.pushUndoStop();
    editor.executeEdits( "compact", [ {
      range: model.getFullModelRange(),
      text: compacted,
      forceMoveMarkers: true,
    } ] );
    editor.pushUndoStop();
  } catch { /* ignore invalid JSON */ }
};

const sortKeys = () => {
  const editor = editorRef.value;
  const model = modelRef.value;
  if ( !editor || !model ) return;
  try {
    const parsed = JSON.parse( editor.getValue() );
    const sorted = sortObjectKeys( parsed );
    const formatted = stringify( sorted, { indent: props.tabSize, maxLength: 80 } );
    editor.pushUndoStop();
    editor.executeEdits( "sort-keys", [ {
      range: model.getFullModelRange(),
      text: formatted,
      forceMoveMarkers: true,
    } ] );
    editor.pushUndoStop();
  } catch { /* ignore invalid JSON */ }
};

// QBML-aware key priority — follows natural SQL clause order
const qbmlKeyOrder = [
  "with", "withRecursive",
  "from", "table", "fromRaw", "fromSub",
  "query", "alias",
  "join", "innerJoin", "leftJoin", "rightJoin", "leftOuterJoin", "rightOuterJoin",
  "crossJoin", "joinRaw", "leftJoinRaw", "rightJoinRaw", "crossJoinRaw",
  "joinSub", "leftJoinSub", "rightJoinSub", "on",
  "select", "addSelect", "selectRaw", "subSelect", "distinct",
  "selectCount", "selectSum", "selectAvg", "selectMin", "selectMax",
  "when", "else",
  "insert", "update", "addUpdate", "delete", "upsert", "insertUsing",
  "where", "andWhere", "orWhere",
  "whereIn", "whereNotIn", "andWhereIn", "orWhereIn", "andWhereNotIn", "orWhereNotIn",
  "whereBetween", "whereNotBetween", "andWhereBetween", "orWhereBetween",
  "whereLike", "whereNotLike", "andWhereLike", "orWhereLike",
  "whereNull", "whereNotNull", "andWhereNull", "orWhereNull",
  "whereColumn", "andWhereColumn", "orWhereColumn",
  "whereExists", "whereNotExists",
  "whereRaw", "andWhereRaw", "orWhereRaw",
  "groupBy", "having", "andHaving", "orHaving", "havingRaw",
  "orderBy", "orderByAsc", "orderByDesc", "orderByRaw", "reorder", "clearOrders",
  "union", "unionAll",
  "limit", "take", "offset", "skip", "forPage",
  "lock", "lockForUpdate", "sharedLock", "noLock", "clearLock",
  "get", "first", "find", "value", "values",
  "count", "sum", "avg", "min", "max", "exists",
  "paginate", "simplePaginate", "toSQL", "dump",
  "datasource", "timeout",
];
const qbmlKeyPriority = Object.fromEntries( qbmlKeyOrder.map( ( k, i ) => [ k, i ] ) );

const sortObjectKeys = ( obj ) => {
  if ( Array.isArray( obj ) ) return obj.map( sortObjectKeys );
  if ( obj !== null && typeof obj === "object" ) {
    return Object.keys( obj ).sort( ( a, b ) => {
      const pa = qbmlKeyPriority[ a ] ?? 999;
      const pb = qbmlKeyPriority[ b ] ?? 999;
      if ( pa !== pb ) return pa - pb;
      return a.localeCompare( b );
    } ).reduce( ( result, key ) => {
      result[ key ] = sortObjectKeys( obj[ key ] );
      return result;
    }, {} );
  }
  return obj;
};

const expandAll = () => editorRef.value?.getAction( "editor.unfoldAll" ).run();
const collapseAll = () => editorRef.value?.getAction( "editor.foldAll" ).run();

// Count how many top-level array elements are fully closed above/on the cursor line.
const getArrayInsertIndex = ( content, cursorLine ) => {
  let depth = 0;
  let index = 0;
  let inString = false;
  let escaped = false;
  let line = 1;
  for ( const ch of content ) {
    if ( line > cursorLine ) break;
    if ( ch === "\n" ) { line++; continue; }
    if ( escaped ) { escaped = false; continue; }
    if ( ch === "\\" && inString ) { escaped = true; continue; }
    if ( ch === "\"" ) { inString = !inString; continue; }
    if ( inString ) continue;
    if ( ch === "{" || ch === "[" ) depth++;
    if ( ch === "}" || ch === "]" ) {
      depth--;
      if ( depth === 1 ) index++;
    }
  }
  return index;
};

const insertSnippet = ( snippet ) => {
  const editor = editorRef.value;
  const model = modelRef.value;
  if ( !editor || !model ) return;

  let text = snippet.insertText || "";
  // Process snippet placeholders: ${1:default} -> default, ${1} -> ""
  text = text.replace( /\$\{(\d+):([^}]+)\}/g, "$2" );
  text = text.replace( /\$\{\d+\}/g, "" );
  // Convert escaped newlines to actual newlines
  text = text.replace( /\\n/g, "\n" );
  // Remove escape backslashes (\\$ -> $) for JSON keys like $param
  text = text.replace( /\\(.)/g, "$1" );

  try {
    const isTemplate = text.trimStart().startsWith( "[" );
    let items;

    if ( isTemplate ) {
      items = JSON.parse( text );
    } else {
      // Single object or multiple objects separated by commas
      try {
        items = [ JSON.parse( text ) ];
      } catch {
        items = JSON.parse( `[${text}]` );
      }
    }

    if ( isTemplate ) {
      // Full query template — replace entire editor content
      const formatted = stringify( items, { indent: props.tabSize, maxLength: 80 } );
      editor.pushUndoStop();
      editor.executeEdits( "snippet", [ {
        range: model.getFullModelRange(),
        text: formatted,
        forceMoveMarkers: true,
      } ] );
      editor.pushUndoStop();
    } else {
      // Clause snippet — splice into existing array at cursor position
      const currentContent = editor.getValue();
      const parsed = JSON.parse( currentContent );
      if ( Array.isArray( parsed ) ) {
        const position = editor.getPosition();
        const insertIdx = getArrayInsertIndex( currentContent, position.lineNumber );
        parsed.splice( insertIdx, 0, ...items );
        const formatted = stringify( parsed, { indent: props.tabSize, maxLength: 80 } );
        editor.pushUndoStop();
        editor.executeEdits( "snippet", [ {
          range: model.getFullModelRange(),
          text: formatted,
          forceMoveMarkers: true,
        } ] );
        editor.pushUndoStop();
      }
    }
    editor.focus();
  } catch {
    // Fallback: raw text insertion at cursor
    const position = editor.getPosition();
    const range = {
      startLineNumber: position.lineNumber,
      startColumn: position.column,
      endLineNumber: position.lineNumber,
      endColumn: position.column,
    };
    editor.pushUndoStop();
    editor.executeEdits( "snippet", [ { range, text, forceMoveMarkers: true } ] );
    editor.pushUndoStop();
    editor.focus();
  }
};

// ---------------------------------------------------------------------------
// Editor initialization
// ---------------------------------------------------------------------------
const initEditor = () => {
  if ( !editorContainer.value ) return;

  const modelUri = monaco.Uri.parse( `inmemory://model/${Date.now()}.json` );

  if ( props.schema ) {
    globalSchemaRegistry.set( modelUri.toString(), {
      uri: props.schemaUri,
      fileMatch: [ modelUri.toString() ],
      schema: props.schema,
    } );
    updateGlobalSchemaConfig();
  }

  const model = markRaw( monaco.editor.createModel( props.modelValue, "json", modelUri ) );
  modelRef.value = model;

  const editor = markRaw( monaco.editor.create( editorContainer.value, {
    model,
    theme: isDark.value ? "vs-dark" : "vs",
    readOnly: props.readOnly,
    minimap: { enabled: props.minimap },
    lineNumbers: props.lineNumbers ? "on" : "off",
    wordWrap: props.wordWrap,
    tabSize: props.tabSize,
    fontSize: props.fontSize,
    automaticLayout: true,
    scrollBeyondLastLine: false,
    folding: true,
    foldingStrategy: "indentation",
    formatOnPaste: true,
    quickSuggestions: { strings: true, other: true, comments: false },
    suggestOnTriggerCharacters: true,
    acceptSuggestionOnEnter: "off",
    acceptSuggestionOnCommitCharacter: false,
    autoClosingBrackets: "always",
    autoClosingQuotes: "always",
    bracketPairColorization: { enabled: true },
    guides: { bracketPairs: true, indentation: true },
    suggest: {
      showKeywords: true,
      showSnippets: true,
      showProperties: true,
      showValues: true,
      insertMode: "replace",
      filterGraceful: true,
      snippetsPreventQuickSuggestions: false,
      selectionMode: "always",
      shareSuggestSelections: false,
    },
    hover: { enabled: true, delay: 300 },
  } ) );
  editorRef.value = editor;

  // Ctrl+Space → trigger suggest
  editor.addCommand( monaco.KeyMod.CtrlCmd | monaco.KeyCode.Space, () => {
    editor.trigger( "keyboard", "editor.action.triggerSuggest", {} );
  } );

  // OUTBOUND: editor content → parent (string v-model)
  editor.onDidChangeModelContent( () => {
    if ( isApplyingExternalChange ) return;
    emit( "update:modelValue", editor.getValue() );
    updateContentInfo();
    updateUndoRedoState();
    setTimeout( updateValidationState, 100 );
  } );

  editor.onDidChangeCursorPosition( () => updateCursorInfo() );

  // Validation from Monaco's JSON worker
  monaco.editor.onDidChangeMarkers( ( uris ) => {
    if ( model && uris.some( uri => uri.toString() === model.uri.toString() ) ) {
      updateValidationState();
    }
  } );

  updateContentInfo();
  updateCursorInfo();
  setTimeout( updateValidationState, 200 );

  emit( "ready", { editor, model } );
};

// ---------------------------------------------------------------------------
// Watchers
// ---------------------------------------------------------------------------

// INBOUND: parent string → editor (preserves cursor + undo)
watch( () => props.modelValue, ( newValue ) => {
  const editor = editorRef.value;
  const model = modelRef.value;
  if ( !editor || !model ) return;
  if ( editor.getValue() === newValue ) return;
  isApplyingExternalChange = true;
  try {
    editor.pushUndoStop();
    editor.executeEdits( "external-sync", [ {
      range: model.getFullModelRange(),
      text: newValue,
      forceMoveMarkers: true,
    } ] );
    editor.pushUndoStop();
  } finally {
    isApplyingExternalChange = false;
  }
} );

watch( () => props.schema, ( newSchema ) => {
  if ( newSchema && modelRef.value ) {
    configureSchema();
    setTimeout( updateValidationState, 200 );
  }
}, { deep: true } );

watch( isDark, ( dark ) => monaco.editor.setTheme( dark ? "vs-dark" : "vs" ) );
watch( () => props.readOnly, ( newValue ) => editorRef.value?.updateOptions( { readOnly: newValue } ) );

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------
const setupResizeObserver = () => {
  if ( !rootContainer.value ) return;
  resizeObserver = new ResizeObserver( () => {
    requestAnimationFrame( () => editorRef.value?.layout() );
  } );
  resizeObserver.observe( rootContainer.value );
};

onMounted( () => {
  nextTick( () => {
    initEditor();
    setupResizeObserver();
  } );
} );

onBeforeUnmount( () => {
  if ( resizeObserver ) resizeObserver.disconnect();
  cleanupSchema();
  const editor = editorRef.value;
  const model = modelRef.value;
  if ( editor ) editor.dispose();
  if ( model ) model.dispose();
  editorRef.value = null;
  modelRef.value = null;
} );

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
defineExpose( {
  undo,
  redo,
  formatDocument,
  compactJson,
  sortKeys,
  expandAll,
  collapseAll,
  goToError,
  getEditor: () => editorRef.value,
  getModel: () => modelRef.value,
  getValue: () => editorRef.value?.getValue() || "",
  validate: updateValidationState,
} );
</script>

<style scoped>
/* ── Light mode (default) ────────────────────────────────────────────── */
.monaco-json-editor {
  --mje-bg: #ffffff;
  --mje-border: #d1d5db;
  --mje-title-from: #f3f4f6;
  --mje-title-to: #e5e7eb;
  --mje-title-text: #374151;
  --mje-toolbar-bg: #f3f4f6;
  --mje-footer-bg: #f3f4f6;
  --mje-footer-text: #6b7280;
  --mje-error-bg: #fef2f2;
  --mje-error-border: #fecaca;
  --mje-error-item-border: #fecaca;
  --mje-error-item-hover: #fee2e2;
  --mje-error-path: #dc2626;
  --mje-error-message: #b91c1c;
  --mje-snippet-bg: #f1f5f9;
  --mje-snippet-text: #64748b;

  display: flex;
  flex-direction: column;
  border: 1px solid var(--mje-border);
  border-radius: 4px;
  overflow: hidden;
  font-family: system-ui, -apple-system, sans-serif;
  position: relative;
  background: var(--mje-bg);
}

/* ── Dark mode overrides ─────────────────────────────────────────────── */
.monaco-json-editor.dark {
  --mje-bg: #1e1e1e;
  --mje-border: #374151;
  --mje-title-from: #374151;
  --mje-title-to: #1f2937;
  --mje-title-text: #d1d5db;
  --mje-toolbar-bg: #1f2937;
  --mje-footer-bg: #1f2937;
  --mje-footer-text: #9ca3af;
  --mje-error-bg: #1f1c1c;
  --mje-error-border: #5c2020;
  --mje-error-item-border: #3d2020;
  --mje-error-item-hover: #2d1a1a;
  --mje-error-path: #f87171;
  --mje-error-message: #fca5a5;
  --mje-snippet-bg: #1a1a2e;
  --mje-snippet-text: #9ca3af;
}

.monaco-title-bar {
  display: flex;
  align-items: center;
  background: linear-gradient(to bottom, var(--mje-title-from), var(--mje-title-to));
  border-bottom: 1px solid var(--mje-border);
  height: 40px;
  padding: 0 12px;
  flex-shrink: 0;
}

.title-text {
  font-weight: 600;
  font-size: 14px;
  color: var(--mje-title-text);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.spacer {
  flex: 1;
}

.monaco-toolbar {
  display: flex;
  align-items: center;
  background-color: var(--mje-toolbar-bg);
  border-bottom: 1px solid var(--mje-border);
  height: 40px;
  padding: 0 8px;
  flex-shrink: 0;
  gap: 4px;
}

.monaco-error-panel {
  max-height: 80px;
  overflow-y: auto;
  background-color: var(--mje-error-bg);
  border-bottom: 1px solid var(--mje-error-border);
  flex-shrink: 0;
}

.error-item {
  display: flex;
  align-items: center;
  padding: 4px 8px;
  font-size: 12px;
  cursor: pointer;
  border-bottom: 1px solid var(--mje-error-item-border);
}

.error-item:hover {
  background-color: var(--mje-error-item-hover);
}

.error-path {
  font-weight: 600;
  color: var(--mje-error-path);
  margin-right: 4px;
}

.error-message {
  color: var(--mje-error-message);
}

.editor-container {
  flex: 1;
  min-height: 0;
  position: relative;
}

.monaco-footer {
  display: flex;
  align-items: center;
  background-color: var(--mje-footer-bg);
  border-top: 1px solid var(--mje-border);
  height: 28px;
  padding: 0 12px;
  flex-shrink: 0;
  font-size: 12px;
  color: var(--mje-footer-text);
}

</style>
