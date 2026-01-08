<template>
  <div ref="rootContainer" class="monaco-json-editor" :style="containerStyle">
    <!-- Title Bar -->
    <div v-if="props.title" class="monaco-title-bar">
      <span class="title-text">{{ props.title }}</span>
      <span class="spacer"></span>
      <slot name="title-actions"></slot>
    </div>

    <!-- Toolbar -->
    <div v-if="props.showToolbar" class="monaco-toolbar">
      <!-- Undo/Redo -->
      <button
        class="toolbar-btn"
        title="Undo (Ctrl+Z)"
        :disabled="!canUndo"
        @click="undo"
      >&#x21B6;</button>
      <button
        class="toolbar-btn"
        title="Redo (Ctrl+Y)"
        :disabled="!canRedo"
        @click="redo"
      >&#x21B7;</button>
      <span class="separator"></span>

      <!-- Format/Compact -->
      <button
        class="toolbar-btn"
        title="Format JSON (pretty print)"
        @click="formatDocument"
      >{ }</button>
      <button
        class="toolbar-btn"
        title="Compact JSON (minify)"
        @click="compactJson"
      >&lt;&gt;</button>
      <span class="separator"></span>

      <!-- Sort -->
      <button
        class="toolbar-btn"
        title="Sort keys alphabetically"
        @click="sortKeys"
      >A-Z</button>
      <span class="separator"></span>

      <!-- Folding -->
      <button
        class="toolbar-btn"
        title="Expand All"
        @click="expandAll"
      >+</button>
      <button
        class="toolbar-btn"
        title="Collapse All"
        @click="collapseAll"
      >-</button>

      <!-- Snippets dropdown -->
      <template v-if="props.snippets && props.snippets.length > 0">
        <span class="separator"></span>
        <div class="snippet-dropdown">
          <button class="toolbar-btn" @click="showSnippetMenu = !showSnippetMenu">
            Snippets &#x25BC;
          </button>
          <div v-if="showSnippetMenu" class="snippet-menu">
            <div class="snippet-menu-header">{{ props.schemaName || "Code" }} Snippets</div>
            <div
              v-for="snippet in categorizedSnippets.templates"
              :key="snippet.label"
              class="snippet-item"
              @click="insertSnippet( snippet ); showSnippetMenu = false"
            >
              <div class="snippet-label">{{ snippet.detail || snippet.label }}</div>
              <div class="snippet-desc">{{ snippet.documentation }}</div>
            </div>
            <template v-if="categorizedSnippets.clauses.length > 0">
              <div class="snippet-menu-header snippet-menu-subheader">Individual Clauses</div>
              <div
                v-for="snippet in categorizedSnippets.clauses"
                :key="snippet.label"
                class="snippet-item"
                @click="insertSnippet( snippet ); showSnippetMenu = false"
              >
                <div class="snippet-label">{{ snippet.detail || snippet.label }}</div>
                <div class="snippet-desc">{{ snippet.documentation }}</div>
              </div>
            </template>
          </div>
        </div>
      </template>

      <span class="spacer"></span>

      <!-- Schema indicator -->
      <span v-if="props.schemaName" class="schema-badge">
        {{ props.schemaName }}
      </span>

      <!-- Validation Status -->
      <span
        v-if="hasErrors"
        class="validation-badge validation-error"
        @click="showErrorPanel = !showErrorPanel"
      >
        {{ errorCount }} {{ errorCount === 1 ? "error" : "errors" }}
      </span>
      <span
        v-else-if="isValidJson"
        class="validation-badge validation-valid"
      >
        Valid
      </span>
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

    <!-- Custom Pinnable Hover Tooltip -->
    <div
      v-if="hoverTooltip.visible"
      ref="hoverTooltipEl"
      class="custom-hover-tooltip"
      :class="{ 'is-pinned': hoverTooltip.pinned }"
      :style="hoverTooltipStyle"
      @mouseenter="onTooltipMouseEnter"
      @mouseleave="onTooltipMouseLeave"
    >
      <div class="hover-tooltip-header">
        <span class="hover-tooltip-title">{{ hoverTooltip.title }}</span>
        <span class="spacer"></span>
        <button
          class="tooltip-btn"
          :class="{ active: hoverTooltip.pinned }"
          title="Pin tooltip"
          @click="togglePinTooltip"
        >&#x1F4CC;</button>
        <button
          class="tooltip-btn"
          title="Close"
          @click="hideHoverTooltip"
        >&times;</button>
      </div>
      <div class="hover-tooltip-content" v-html="hoverTooltip.htmlContent"></div>
    </div>

    <!-- Footer Status Bar -->
    <div v-if="props.showFooter" class="monaco-footer">
      <span class="cursor-info">
        Ln {{ cursorLine }}, Col {{ cursorColumn }}
      </span>
      <span class="spacer"></span>
      <span class="char-count">
        {{ charCount }} chars
      </span>
      <span class="separator"></span>
      <span class="line-count">
        {{ lineCount }} lines
      </span>
    </div>
  </div>
</template>

<script setup>
/**
 * MonacoJsonEditor - A feature-rich JSON editor component based on Monaco Editor
 *
 * This component provides a powerful JSON editing experience with:
 * - JSON Schema validation and autocomplete
 * - Custom code snippets
 * - Toolbar with formatting, sorting, and folding controls
 * - Real-time validation with error panel
 * - Custom pinnable hover tooltips with rich documentation
 * - Dark mode support
 *
 * ## Basic Usage (Progressive Enhancement - No Schema)
 * ```vue
 * <MonacoJsonEditor
 *   v-model="myJsonData"
 *   title="Configuration"
 *   height="400px"
 * />
 * ```
 *
 * ## With JSON Schema (for validation, autocomplete, and hover docs)
 * ```vue
 * <MonacoJsonEditor
 *   v-model="queryData"
 *   :schema="qbmlSchema"
 *   schema-uri="https://qbml.ortusbooks.com/schemas/qbml.schema.json"
 *   schema-name="QBML"
 *   :snippets="qbmlSnippets"
 * />
 * ```
 *
 * ## Using with useJsonSchema composable
 * ```js
 * import { useJsonSchema } from "./useJsonSchema";
 * const { getEditorProps } = useJsonSchema();
 * const editorProps = getEditorProps("qbml");
 * // In template: v-bind="editorProps"
 * ```
 */
import { ref, watch, onMounted, onBeforeUnmount, computed, nextTick } from "vue";
import * as monaco from "monaco-editor";

// Global schema registry for Monaco - tracks all schemas across editor instances
const globalSchemaRegistry = new Map();
let schemaConfigured = false;

// Deep clone schema to ensure it's serializable for web worker
const cloneSchema = ( schema ) => {
  try {
    return JSON.parse( JSON.stringify( schema ) );
  } catch ( e ) {
    console.warn( "[MonacoJsonEditor] Failed to clone schema:", e );
    return null;
  }
};

// Update Monaco's global JSON diagnostics with all registered schemas
const updateGlobalSchemaConfig = () => {
  const schemas = Array.from( globalSchemaRegistry.values() )
    .map( entry => ( {
      uri: entry.uri,
      fileMatch: entry.fileMatch,
      schema: cloneSchema( entry.schema ),
    } ) )
    .filter( entry => entry.schema !== null );

  // Configure JSON language defaults for validation and hover
  monaco.languages.json.jsonDefaults.setDiagnosticsOptions( {
    validate: true,
    schemas: schemas,
    allowComments: false,
    trailingCommas: "error",
    schemaValidation: "error",
    enableSchemaRequest: false,
  } );

  // Disable built-in hovers since we provide our own custom rich tooltips
  monaco.languages.json.jsonDefaults.setModeConfiguration( {
    documentFormattingEdits: true,
    documentRangeFormattingEdits: true,
    completionItems: true,
    hovers: false,
    documentSymbols: true,
    tokens: true,
    colors: true,
    foldingRanges: true,
    diagnostics: true,
    selectionRanges: true,
  } );

  schemaConfigured = true;
};

const props = defineProps( {
  modelValue: {
    type: [ String, Object, Array ],
    default: "",
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
    default: "300px",
  },
  width: {
    type: String,
    default: "100%",
  },
  fillHeight: {
    type: Boolean,
    default: false,
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
    default: 13,
  },
} );

const emit = defineEmits( [ "update:modelValue", "validation", "ready" ] );

const editorContainer = ref( null );
const rootContainer = ref( null );
let editor = null;
let model = null;
let snippetDisposable = null;
let resizeObserver = null;

// UI state
const showSnippetMenu = ref( false );
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

// Custom hover tooltip state
const hoverTooltipEl = ref( null );
const hoverTooltip = ref( {
  visible: false,
  pinned: false,
  title: "",
  htmlContent: "",
  x: 0,
  y: 0,
} );
let hoverTimeoutId = null;
let hideTimeoutId = null;

const TITLE_HEIGHT = 28;
const TOOLBAR_HEIGHT = 32;
const FOOTER_HEIGHT = 24;
const ERROR_PANEL_MAX_HEIGHT = 80;

const containerStyle = computed( () => ( {
  height: props.fillHeight ? "100%" : props.height,
  width: props.width,
  flex: props.fillHeight ? "1 1 auto" : undefined,
  minHeight: props.fillHeight ? "200px" : undefined,
} ) );

const editorContainerStyle = computed( () => {
  let height = "100%";
  const offsets = [];
  if ( props.title ) offsets.push( `${TITLE_HEIGHT}px` );
  if ( props.showToolbar ) offsets.push( `${TOOLBAR_HEIGHT}px` );
  if ( props.showFooter ) offsets.push( `${FOOTER_HEIGHT}px` );
  if ( showErrorPanel.value && hasErrors.value ) offsets.push( `${ERROR_PANEL_MAX_HEIGHT}px` );
  if ( offsets.length > 0 ) {
    height = `calc(100% - ${offsets.join( " - " )})`;
  }
  return { height };
} );

// Categorize snippets into templates and clauses
const categorizedSnippets = computed( () => {
  const templates = [];
  const clauses = [];
  if ( !props.snippets ) return { templates, clauses };

  for ( const snippet of props.snippets ) {
    const isTemplate = snippet.label.startsWith( "qbml-" ) ||
      ( snippet.insertText && snippet.insertText.includes( "\\n" ) && snippet.insertText.length > 100 );
    if ( isTemplate ) {
      templates.push( snippet );
    } else {
      clauses.push( snippet );
    }
  }
  return { templates, clauses };
} );

const hoverTooltipStyle = computed( () => ( {
  left: `${hoverTooltip.value.x}px`,
  top: `${hoverTooltip.value.y}px`,
} ) );

// Convert markdown to HTML for tooltip display
const markdownToHtml = ( text ) => {
  if ( !text ) return "";

  const placeholders = [];
  let html = text;

  // Extract and protect code blocks
  html = html.replace( /```(\w*)\n([\s\S]*?)```/g, ( match, lang, code ) => {
    const escaped = code.trim()
      .replace( /&/g, "&amp;" )
      .replace( /</g, "&lt;" )
      .replace( />/g, "&gt;" );
    const placeholder = `__CODEBLOCK_${placeholders.length}__`;
    placeholders.push( `<pre class="code-block"><code>${escaped}</code></pre>` );
    return placeholder;
  } );

  // Extract and protect inline code
  html = html.replace( /`([^`]+)`/g, ( match, code ) => {
    const escaped = code
      .replace( /&/g, "&amp;" )
      .replace( /</g, "&lt;" )
      .replace( />/g, "&gt;" );
    const placeholder = `__INLINECODE_${placeholders.length}__`;
    placeholders.push( `<code class="inline-code">${escaped}</code>` );
    return placeholder;
  } );

  // Extract and protect markdown links [text](url)
  html = html.replace( /\[([^\]]+)\]\(([^)]+)\)/g, ( match, linkText, url ) => {
    const placeholder = `__LINK_${placeholders.length}__`;
    placeholders.push( `<a href="${url}" target="_blank" rel="noopener">${linkText}</a>` );
    return placeholder;
  } );

  // Extract and protect bare URLs
  html = html.replace( /(https?:\/\/[^\s<)\]]+)/g, ( match, url ) => {
    if ( url.includes( "__" ) ) return match;
    const placeholder = `__BAREURL_${placeholders.length}__`;
    placeholders.push( `<a href="${url}" target="_blank" rel="noopener">${url}</a>` );
    return placeholder;
  } );

  // Escape remaining HTML
  html = html
    .replace( /&/g, "&amp;" )
    .replace( /</g, "&lt;" )
    .replace( />/g, "&gt;" );

  // Bold and italic
  html = html.replace( /\*\*([^*]+)\*\*/g, "<strong>$1</strong>" );
  html = html.replace( /\*([^*]+)\*/g, "<em>$1</em>" );
  html = html.replace( /\n\n/g, "</p><p>" );
  html = html.replace( /\n/g, "<br>" );

  // Restore placeholders
  for ( let i = 0; i < placeholders.length; i++ ) {
    html = html.replace( new RegExp( `__(?:CODEBLOCK|INLINECODE|LINK|BAREURL)_${i}__`, "g" ), placeholders[ i ] );
  }

  return `<p>${html}</p>`;
};

const valueToString = ( value ) => {
  if ( typeof value === "string" ) return value;
  try {
    return JSON.stringify( value, null, props.tabSize );
  } catch ( e ) {
    return "";
  }
};

const stringToValue = ( str ) => {
  if ( !str || str.trim() === "" ) return {};
  try {
    return JSON.parse( str );
  } catch ( e ) {
    return str;
  }
};

const configureSchema = () => {
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
  if ( model ) {
    const modelUri = model.uri.toString();
    globalSchemaRegistry.delete( modelUri );
    updateGlobalSchemaConfig();
  }
};

const registerSnippets = () => {
  if ( props.snippets && props.snippets.length > 0 ) {
    snippetDisposable = monaco.languages.registerCompletionItemProvider( "json", {
      triggerCharacters: [ '"', '{', '[', ',' ],
      provideCompletionItems( targetModel, position ) {
        if ( !model || targetModel.uri.toString() !== model.uri.toString() ) {
          return { suggestions: [] };
        }
        const word = targetModel.getWordUntilPosition( position );
        const range = {
          startLineNumber: position.lineNumber,
          endLineNumber: position.lineNumber,
          startColumn: word.startColumn,
          endColumn: word.endColumn,
        };
        return {
          suggestions: props.snippets.map( ( snippet ) => ( {
            label: snippet.label,
            kind: monaco.languages.CompletionItemKind.Snippet,
            insertText: snippet.insertText,
            insertTextRules: monaco.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: { value: snippet.documentation || "", isTrusted: true },
            detail: snippet.detail || snippet.label,
            range,
            sortText: `0_${snippet.label}`,
          } ) ),
        };
      },
    } );
  }
};

// Schema description map for hover lookup
let schemaDescriptionMap = new Map();

const buildDescriptionMap = () => {
  schemaDescriptionMap.clear();
  if ( !props.schema ) return;

  const definitions = props.schema.definitions || {};

  const extractDescriptions = ( obj ) => {
    if ( !obj || typeof obj !== "object" ) return;

    if ( obj.definitions ) {
      for ( const [ defName, def ] of Object.entries( obj.definitions ) ) {
        if ( def.description ) {
          schemaDescriptionMap.set( defName, def.description );
        }
        if ( def.properties ) {
          for ( const [ propKey, propDef ] of Object.entries( def.properties ) ) {
            // For "when" and "else", use the referenced definition's description
            if ( propKey === "when" || propKey === "else" ) {
              if ( propDef.$ref && !schemaDescriptionMap.has( propKey ) ) {
                const refKey = propDef.$ref.split( "/" ).pop();
                const refDef = definitions[ refKey ];
                if ( refDef?.description ) {
                  schemaDescriptionMap.set( propKey, refDef.description );
                }
              }
              continue;
            }
            if ( propDef.description ) {
              schemaDescriptionMap.set( propKey, propDef.description );
            } else if ( propDef.$ref ) {
              const refKey = propDef.$ref.split( "/" ).pop();
              if ( refKey.endsWith( "Value" ) && def.description ) {
                schemaDescriptionMap.set( propKey, def.description );
              } else {
                const refDef = definitions[ refKey ];
                if ( refDef?.description ) {
                  schemaDescriptionMap.set( propKey, refDef.description );
                }
              }
            } else if ( !schemaDescriptionMap.has( propKey ) && def.description ) {
              schemaDescriptionMap.set( propKey, def.description );
            }
          }
        }
        if ( def.oneOf || def.anyOf ) {
          const options = def.oneOf || def.anyOf;
          for ( const option of options ) {
            if ( option.$ref ) {
              const refKey = option.$ref.split( "/" ).pop();
              const refDef = definitions[ refKey ];
              if ( refDef?.description && !schemaDescriptionMap.has( refKey ) ) {
                schemaDescriptionMap.set( refKey, refDef.description );
              }
            }
          }
        }
        extractDescriptions( def );
      }
    }

    if ( obj.properties ) {
      for ( const [ key, propDef ] of Object.entries( obj.properties ) ) {
        if ( propDef.description && !schemaDescriptionMap.has( key ) ) {
          schemaDescriptionMap.set( key, propDef.description );
        }
      }
    }
  };

  extractDescriptions( props.schema );
};

const updateValidationState = () => {
  if ( !model ) return;
  const markers = monaco.editor.getModelMarkers( { resource: model.uri } );
  const errors = markers.filter( ( m ) => m.severity === monaco.MarkerSeverity.Error );
  hasErrors.value = errors.length > 0;
  errorCount.value = errors.length;
  validationErrors.value = errors.map( ( m ) => ( {
    message: m.message,
    path: m.relatedInformation?.[0]?.message || "",
    line: m.startLineNumber,
    column: m.startColumn,
  } ) );

  try {
    JSON.parse( model.getValue() );
    isValidJson.value = !hasErrors.value;
  } catch ( e ) {
    isValidJson.value = false;
    if ( validationErrors.value.length === 0 ) {
      validationErrors.value = [ { message: e.message, path: "", line: 1, column: 1 } ];
      hasErrors.value = true;
      errorCount.value = 1;
    }
  }

  emit( "validation", { valid: isValidJson.value && !hasErrors.value, errors: validationErrors.value } );
};

const goToError = ( error ) => {
  if ( editor && error.line ) {
    editor.setPosition( { lineNumber: error.line, column: error.column || 1 } );
    editor.revealLineInCenter( error.line );
    editor.focus();
  }
};

const updateUndoRedoState = () => {
  if ( !model ) return;
  canUndo.value = model.getAlternativeVersionId() > 1;
  canRedo.value = false;
};

const updateCursorInfo = () => {
  if ( !editor ) return;
  const position = editor.getPosition();
  if ( position ) {
    cursorLine.value = position.lineNumber;
    cursorColumn.value = position.column;
  }
};

const updateContentInfo = () => {
  if ( !model ) return;
  const content = model.getValue();
  charCount.value = content.length;
  lineCount.value = model.getLineCount();
};

const undo = () => editor?.trigger( "toolbar", "undo", null );
const redo = () => editor?.trigger( "toolbar", "redo", null );
const formatDocument = () => editor?.getAction( "editor.action.formatDocument" ).run();

const compactJson = () => {
  if ( !editor || !model ) return;
  try {
    const content = editor.getValue();
    const parsed = JSON.parse( content );
    const compacted = JSON.stringify( parsed );
    const fullRange = model.getFullModelRange();
    editor.executeEdits( "compact", [ { range: fullRange, text: compacted, forceMoveMarkers: true } ] );
  } catch ( e ) {}
};

const sortKeys = () => {
  if ( !editor ) return;
  try {
    const content = editor.getValue();
    const parsed = JSON.parse( content );
    const sorted = sortObjectKeys( parsed );
    const formatted = JSON.stringify( sorted, null, props.tabSize );
    editor.setValue( formatted );
  } catch ( e ) {}
};

const sortObjectKeys = ( obj ) => {
  if ( Array.isArray( obj ) ) return obj.map( sortObjectKeys );
  if ( obj !== null && typeof obj === "object" ) {
    return Object.keys( obj ).sort().reduce( ( result, key ) => {
      result[ key ] = sortObjectKeys( obj[ key ] );
      return result;
    }, {} );
  }
  return obj;
};

const expandAll = () => editor?.getAction( "editor.unfoldAll" ).run();
const collapseAll = () => editor?.getAction( "editor.foldAll" ).run();

const insertSnippet = ( snippet ) => {
  if ( !editor || !model ) return;
  const position = editor.getPosition();
  let text = snippet.insertText || "";
  text = text.replace( /\$\{(\d+):([^}]+)\}/g, "$2" );
  text = text.replace( /\$\{\d+\}/g, "" );
  text = text.replace( /\\n/g, "\n" );
  text = text.replace( /\\\\/g, "\\" );
  const range = {
    startLineNumber: position.lineNumber,
    startColumn: position.column,
    endLineNumber: position.lineNumber,
    endColumn: position.column,
  };
  editor.executeEdits( "snippet", [ { range, text, forceMoveMarkers: true } ] );
  editor.focus();
  setTimeout( () => editor.getAction( "editor.action.formatDocument" )?.run(), 50 );
};

const showHoverTooltip = ( title, content, x, y ) => {
  if ( hideTimeoutId ) {
    clearTimeout( hideTimeoutId );
    hideTimeoutId = null;
  }
  hoverTooltip.value = {
    visible: true,
    pinned: false,
    title,
    htmlContent: markdownToHtml( content ),
    x,
    y,
  };
};

const hideHoverTooltip = ( immediate = true ) => {
  if ( hoverTooltip.value.pinned ) return;
  if ( immediate ) {
    hoverTooltip.value.visible = false;
    hoverTooltip.value.pinned = false;
  } else {
    hideTimeoutId = setTimeout( () => {
      if ( !hoverTooltip.value.pinned ) {
        hoverTooltip.value.visible = false;
      }
    }, 300 );
  }
};

const togglePinTooltip = () => {
  hoverTooltip.value.pinned = !hoverTooltip.value.pinned;
};

const onTooltipMouseEnter = () => {
  if ( hideTimeoutId ) {
    clearTimeout( hideTimeoutId );
    hideTimeoutId = null;
  }
};

const onTooltipMouseLeave = () => {
  hideHoverTooltip( false );
};

const initEditor = () => {
  if ( !editorContainer.value ) return;

  const initialValue = valueToString( props.modelValue );
  const modelUri = monaco.Uri.parse( `inmemory://model/${Date.now()}.json` );

  if ( props.schema ) {
    globalSchemaRegistry.set( modelUri.toString(), {
      uri: props.schemaUri,
      fileMatch: [ modelUri.toString() ],
      schema: props.schema,
    } );
    updateGlobalSchemaConfig();
  }

  model = monaco.editor.createModel( initialValue, "json", modelUri );

  registerSnippets();
  buildDescriptionMap();

  editor = monaco.editor.create( editorContainer.value, {
    model,
    theme: props.theme,
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
    acceptSuggestionOnEnter: "on",
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
    },
    hover: { enabled: true, delay: 300 },
  } );

  editor.addCommand( monaco.KeyMod.CtrlCmd | monaco.KeyCode.Space, () => {
    editor.trigger( "keyboard", "editor.action.triggerSuggest", {} );
  } );

  editor.onDidChangeModelContent( () => {
    const value = editor.getValue();
    const parsed = stringToValue( value );
    emit( "update:modelValue", parsed );
    updateContentInfo();
    updateUndoRedoState();
    setTimeout( updateValidationState, 100 );
  } );

  editor.onDidChangeCursorPosition( () => updateCursorInfo() );

  // Custom hover via mouse events
  let lastHoverWord = "";
  editor.onMouseMove( ( e ) => {
    if ( hoverTooltip.value.pinned ) return;
    if ( e.target.type !== monaco.editor.MouseTargetType.CONTENT_TEXT ) {
      if ( !hoverTooltip.value.pinned ) hideHoverTooltip( false );
      return;
    }
    const position = e.target.position;
    if ( !position ) return;
    const word = model.getWordAtPosition( position );
    if ( !word ) {
      hideHoverTooltip( false );
      return;
    }
    const key = word.word.replace( /^["']|["']$/g, "" );
    if ( key === lastHoverWord && hoverTooltip.value.visible ) return;
    const description = schemaDescriptionMap.get( key );
    if ( !description ) {
      hideHoverTooltip( false );
      return;
    }
    lastHoverWord = key;
    const rootRect = rootContainer.value?.getBoundingClientRect() || { left: 0, top: 0 };
    const x = e.event.posx - rootRect.left + 10;
    const y = e.event.posy - rootRect.top + 20;
    if ( hoverTimeoutId ) clearTimeout( hoverTimeoutId );
    hoverTimeoutId = setTimeout( () => showHoverTooltip( key, description, x, y ), 400 );
  } );

  editor.onMouseLeave( () => {
    if ( hoverTimeoutId ) {
      clearTimeout( hoverTimeoutId );
      hoverTimeoutId = null;
    }
    hideHoverTooltip( false );
  } );

  monaco.editor.onDidChangeMarkers( ( uris ) => {
    if ( model && uris.some( ( uri ) => uri.toString() === model.uri.toString() ) ) {
      updateValidationState();
    }
  } );

  updateContentInfo();
  updateCursorInfo();
  setTimeout( updateValidationState, 200 );

  emit( "ready", { editor, model } );
};

watch(
  () => props.modelValue,
  ( newValue ) => {
    if ( !editor ) return;
    const currentValue = editor.getValue();
    const newValueStr = valueToString( newValue );
    if ( currentValue !== newValueStr ) {
      const position = editor.getPosition();
      editor.setValue( newValueStr );
      if ( position ) editor.setPosition( position );
    }
  },
  { deep: true }
);

watch(
  () => props.schema,
  ( newSchema ) => {
    if ( newSchema && model ) {
      configureSchema();
      buildDescriptionMap();
      setTimeout( updateValidationState, 200 );
    }
  },
  { deep: true, immediate: false }
);

watch(
  () => props.snippets,
  () => {
    if ( snippetDisposable ) {
      snippetDisposable.dispose();
      snippetDisposable = null;
    }
    registerSnippets();
  },
  { deep: true }
);

watch( () => props.theme, ( newTheme ) => monaco.editor.setTheme( newTheme ) );
watch( () => props.readOnly, ( newValue ) => editor?.updateOptions( { readOnly: newValue } ) );

const setupResizeObserver = () => {
  if ( !rootContainer.value ) return;
  resizeObserver = new ResizeObserver( () => {
    requestAnimationFrame( () => editor?.layout() );
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
  if ( hoverTimeoutId ) clearTimeout( hoverTimeoutId );
  if ( hideTimeoutId ) clearTimeout( hideTimeoutId );
  if ( resizeObserver ) resizeObserver.disconnect();
  cleanupSchema();
  if ( snippetDisposable ) snippetDisposable.dispose();
  if ( editor ) editor.dispose();
  if ( model ) model.dispose();
} );

defineExpose( {
  undo,
  redo,
  formatDocument,
  compactJson,
  sortKeys,
  expandAll,
  collapseAll,
  goToError,
  getEditor: () => editor,
  getModel: () => model,
  getValue: () => editor?.getValue() || "",
  setValue: ( value ) => editor?.setValue( valueToString( value ) ),
  validate: updateValidationState,
} );
</script>

<style scoped>
.monaco-json-editor {
  display: flex;
  flex-direction: column;
  border: 1px solid #374151;
  border-radius: 4px;
  overflow: hidden;
  font-family: system-ui, -apple-system, sans-serif;
  position: relative;
}

.spacer {
  flex: 1;
}

.separator {
  width: 1px;
  height: 16px;
  background: #4b5563;
  margin: 0 4px;
}

.monaco-title-bar {
  display: flex;
  align-items: center;
  background: linear-gradient(to bottom, #374151, #1f2937);
  border-bottom: 1px solid #374151;
  height: 28px;
  padding: 0 8px;
  flex-shrink: 0;
}

.title-text {
  font-weight: 600;
  font-size: 12px;
  color: #d1d5db;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.monaco-toolbar {
  display: flex;
  align-items: center;
  background-color: #1f2937;
  border-bottom: 1px solid #374151;
  height: 32px;
  padding: 0 4px;
  flex-shrink: 0;
  gap: 2px;
}

.toolbar-btn {
  background: transparent;
  border: none;
  color: #9ca3af;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-family: monospace;
}

.toolbar-btn:hover:not(:disabled) {
  background: #374151;
  color: #f3f4f6;
}

.toolbar-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.schema-badge {
  background: #374151;
  color: #9ca3af;
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  margin-right: 8px;
}

.validation-badge {
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 11px;
  cursor: pointer;
}

.validation-error {
  background: #991b1b;
  color: #fecaca;
}

.validation-valid {
  background: #166534;
  color: #bbf7d0;
}

.snippet-dropdown {
  position: relative;
}

.snippet-menu {
  position: absolute;
  top: 100%;
  left: 0;
  background: #1f2937;
  border: 1px solid #374151;
  border-radius: 4px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  z-index: 100;
  min-width: 280px;
  max-height: 400px;
  overflow-y: auto;
}

.snippet-menu-header {
  padding: 8px 12px;
  background: #374151;
  color: #f3f4f6;
  font-weight: 600;
  font-size: 12px;
}

.snippet-menu-subheader {
  background: #2d3748;
  font-size: 11px;
  color: #9ca3af;
}

.snippet-item {
  padding: 8px 12px;
  cursor: pointer;
  border-bottom: 1px solid #374151;
}

.snippet-item:hover {
  background: #374151;
}

.snippet-item:last-child {
  border-bottom: none;
}

.snippet-label {
  color: #f3f4f6;
  font-size: 13px;
}

.snippet-desc {
  color: #9ca3af;
  font-size: 11px;
  margin-top: 2px;
}

.monaco-error-panel {
  max-height: 80px;
  overflow-y: auto;
  background-color: #1f1c1c;
  border-bottom: 1px solid #5c2020;
  flex-shrink: 0;
}

.error-item {
  display: flex;
  align-items: center;
  padding: 4px 8px;
  font-size: 11px;
  cursor: pointer;
  border-bottom: 1px solid #3d2020;
}

.error-item:hover {
  background-color: #2d1a1a;
}

.error-path {
  font-weight: 600;
  color: #f87171;
  margin-right: 4px;
}

.error-message {
  color: #fca5a5;
}

.editor-container {
  flex: 1;
  min-height: 0;
  position: relative;
}

/* Custom hover tooltip - golden rectangle proportions */
.custom-hover-tooltip {
  position: absolute;
  z-index: 1000;
  width: 420px;
  max-width: 90vw;
  min-width: 320px;
  max-height: 260px;
  background: #1f2937;
  border: 1px solid #374151;
  border-radius: 6px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  font-size: 13px;
  line-height: 1.5;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.custom-hover-tooltip.is-pinned {
  border-color: #3b82f6;
  box-shadow: 0 8px 24px rgba(59, 130, 246, 0.3);
}

.hover-tooltip-header {
  display: flex;
  align-items: center;
  padding: 6px 8px 6px 12px;
  background: #374151;
  border-bottom: 1px solid #4b5563;
  gap: 4px;
}

.hover-tooltip-title {
  font-weight: 600;
  color: #f3f4f6;
  font-family: ui-monospace, monospace;
}

.tooltip-btn {
  background: transparent;
  border: none;
  color: #9ca3af;
  cursor: pointer;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 14px;
}

.tooltip-btn:hover {
  background: #4b5563;
  color: #f3f4f6;
}

.tooltip-btn.active {
  color: #3b82f6;
}

.hover-tooltip-content {
  padding: 12px;
  flex: 1;
  overflow-y: auto;
  color: #e5e7eb;
}

.hover-tooltip-content :deep(p) {
  margin: 0 0 8px;
}

.hover-tooltip-content :deep(p:last-child) {
  margin-bottom: 0;
}

.hover-tooltip-content :deep(strong) {
  font-weight: 600;
}

.hover-tooltip-content :deep(a) {
  color: #60a5fa;
  text-decoration: none;
}

.hover-tooltip-content :deep(a:hover) {
  text-decoration: underline;
}

.hover-tooltip-content :deep(.code-block) {
  background: #111827;
  border: 1px solid #374151;
  border-radius: 4px;
  padding: 12px;
  margin: 8px 0;
  overflow-x: auto;
  font-family: ui-monospace, monospace;
  font-size: 12px;
  line-height: 1.4;
  white-space: pre;
}

.hover-tooltip-content :deep(.inline-code) {
  background: #374151;
  border: 1px solid #4b5563;
  border-radius: 4px;
  padding: 2px 6px;
  font-family: ui-monospace, monospace;
  font-size: 12px;
}

.monaco-footer {
  display: flex;
  align-items: center;
  background-color: #1f2937;
  border-top: 1px solid #374151;
  height: 24px;
  padding: 0 8px;
  flex-shrink: 0;
  font-size: 11px;
  color: #9ca3af;
}
</style>
