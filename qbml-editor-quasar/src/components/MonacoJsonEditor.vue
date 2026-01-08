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
        title="Sort keys alphabetically"
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

      <!-- Snippets dropdown -->
      <template v-if="props.snippets && props.snippets.length > 0">
        <q-separator vertical class="q-mx-xs" />
        <q-btn-dropdown
          flat
          dense
          label="Snippets"
          dropdown-icon="expand_more"
        >
          <q-list>
            <q-item-label header>{{ props.schemaName || "Code" }} Snippets</q-item-label>
            <q-item
              v-for="snippet in categorizedSnippets.templates"
              :key="snippet.label"
              clickable
              v-close-popup
              @click="insertSnippet( snippet )"
            >
              <q-item-section>
                <q-item-label>{{ snippet.detail || snippet.label }}</q-item-label>
                <q-item-label caption>{{ snippet.documentation }}</q-item-label>
              </q-item-section>
            </q-item>
            <template v-if="categorizedSnippets.clauses.length > 0">
              <q-separator />
              <q-item-label header>Individual Clauses</q-item-label>
              <q-item
                v-for="snippet in categorizedSnippets.clauses"
                :key="snippet.label"
                clickable
                v-close-popup
                @click="insertSnippet( snippet )"
              >
                <q-item-section>
                  <q-item-label>{{ snippet.detail || snippet.label }}</q-item-label>
                  <q-item-label caption>{{ snippet.documentation }}</q-item-label>
                </q-item-section>
              </q-item>
            </template>
          </q-list>
        </q-btn-dropdown>
      </template>

      <q-space />

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
        <q-space />
        <q-btn
          flat
          dense
          round
          size="sm"
          :icon="hoverTooltip.pinned ? 'push_pin' : 'push_pin'"
          :color="hoverTooltip.pinned ? 'primary' : 'grey'"
          title="Pin tooltip"
          @click="togglePinTooltip"
        />
        <q-btn
          flat
          dense
          round
          size="sm"
          icon="close"
          title="Close"
          @click="hideHoverTooltip"
        />
      </div>
      <div class="hover-tooltip-content" v-html="hoverTooltip.htmlContent"></div>
    </div>

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
 * MonacoJsonEditor - A feature-rich JSON editor component based on Monaco Editor
 */
import { ref, watch, onMounted, onBeforeUnmount, computed, nextTick } from "vue";
import * as monaco from "monaco-editor";

// Global schema registry for Monaco
const globalSchemaRegistry = new Map();

// Deep clone schema to ensure it's serializable
const cloneSchema = ( schema ) => {
  try {
    return JSON.parse( JSON.stringify( schema ) );
  } catch ( e ) {
    console.warn( "[MonacoJsonEditor] Failed to clone schema:", e );
    return null;
  }
};

// Update Monaco's global JSON diagnostics
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
    schemas: schemas,
    allowComments: false,
    trailingCommas: "error",
    schemaValidation: "error",
    enableSchemaRequest: false,
  } );

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

const editorContainer = ref( null );
const rootContainer = ref( null );
let editor = null;
let model = null;
let snippetDisposable = null;
let resizeObserver = null;

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
let isMouseOverTooltip = false;

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

// Categorize snippets
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

// Markdown to HTML converter
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

  // Extract and protect markdown links
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
  } catch {
    return "";
  }
};

const stringToValue = ( str ) => {
  if ( !str || str.trim() === "" ) return {};
  try {
    return JSON.parse( str );
  } catch {
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

// Analyze JSON context at cursor position
const getJsonContext = ( text, offset ) => {
  // Parse to find what context we're in
  let depth = 0;
  let inString = false;
  let inKey = false;
  let currentKey = "";
  let parentKeys = [];
  let isValue = false;
  let bracketStack = []; // Track [ vs {
  let lastKey = ""; // Track the most recent completed key

  for ( let i = 0; i < offset; i++ ) {
    const char = text[ i ];
    const prevChar = i > 0 ? text[ i - 1 ] : "";

    if ( inString ) {
      if ( char === '"' && prevChar !== "\\" ) {
        inString = false;
        if ( inKey ) {
          // Finished reading a key
          inKey = false;
          lastKey = currentKey;
        }
      } else if ( inKey ) {
        currentKey += char;
      }
    } else {
      if ( char === '"' ) {
        inString = true;
        // Check if this starts a key (after { or ,) or a value (after :)
        const beforeQuote = text.substring( 0, i ).replace( /\s+/g, "" );
        if ( beforeQuote.endsWith( ":" ) ) {
          isValue = true;
          inKey = false;
        } else {
          isValue = false;
          inKey = true;
          currentKey = "";
        }
      } else if ( char === "{" ) {
        bracketStack.push( { type: "{", key: lastKey } );
        depth++;
        if ( lastKey ) {
          parentKeys.push( lastKey );
        }
        lastKey = "";
        currentKey = "";
        isValue = false;
      } else if ( char === "}" ) {
        bracketStack.pop();
        depth--;
        if ( parentKeys.length > 0 ) parentKeys.pop();
        currentKey = "";
        lastKey = "";
      } else if ( char === "[" ) {
        bracketStack.push( { type: "[", key: lastKey } );
        if ( lastKey ) {
          parentKeys.push( lastKey );
        }
        lastKey = "";
        currentKey = "";
      } else if ( char === "]" ) {
        bracketStack.pop();
        if ( parentKeys.length > 0 ) parentKeys.pop();
        currentKey = "";
        lastKey = "";
      } else if ( char === ":" ) {
        isValue = true;
      } else if ( char === "," ) {
        currentKey = "";
        lastKey = "";
        isValue = false;
      }
    }
  }

  const lastBracket = bracketStack.length > 0 ? bracketStack[ bracketStack.length - 1 ] : null;

  // Determine if we're typing inside quotes (for a key)
  const textBeforeCursor = text.substring( 0, offset );
  const lastQuoteIndex = textBeforeCursor.lastIndexOf( '"' );
  let isTypingKey = false;
  if ( lastQuoteIndex >= 0 ) {
    // Check what's before the quote
    const beforeLastQuote = textBeforeCursor.substring( 0, lastQuoteIndex ).replace( /\s+$/g, "" );
    const afterLastQuote = textBeforeCursor.substring( lastQuoteIndex + 1 );
    // If no closing quote and not after a colon, we're typing a key
    // But make sure we're actually inside an unclosed quote (inString should be true from main parsing)
    if ( !afterLastQuote.includes( '"' ) && !beforeLastQuote.endsWith( ":" ) && inString ) {
      isTypingKey = true;
    }
  }

  return {
    depth,
    parentKeys,
    currentKey: inKey ? currentKey : lastKey,
    isValue,
    inArray: lastBracket?.type === "[",
    inObject: lastBracket?.type === "{",
    isTypingKey,
    inString,
    lastKey
  };
};

// All QBML action keys organized by category
const qbmlActionKeys = {
  // Source/FROM actions
  source: [ "from", "table", "fromSub", "fromRaw" ],
  // SELECT actions
  select: [ "select", "selectRaw", "distinct", "addSelect" ],
  // WHERE clauses
  where: [
    "where", "andWhere", "orWhere",
    "whereIn", "whereNotIn", "andWhereIn", "andWhereNotIn", "orWhereIn", "orWhereNotIn",
    "whereBetween", "whereNotBetween", "andWhereBetween", "andWhereNotBetween", "orWhereBetween", "orWhereNotBetween",
    "whereLike", "whereNotLike", "andWhereLike", "andWhereNotLike", "orWhereLike", "orWhereNotLike",
    "whereNull", "whereNotNull", "andWhereNull", "andWhereNotNull", "orWhereNull", "orWhereNotNull",
    "whereColumn", "andWhereColumn", "orWhereColumn",
    "whereRaw", "andWhereRaw", "orWhereRaw",
    "whereExists", "whereNotExists", "orWhereExists", "orWhereNotExists"
  ],
  // JOIN actions
  join: [ "join", "leftJoin", "rightJoin", "innerJoin", "crossJoin", "joinSub", "joinRaw", "leftJoinSub", "rightJoinSub" ],
  // GROUP BY / HAVING
  group: [ "groupBy", "groupByRaw", "having", "havingRaw" ],
  // ORDER BY
  order: [ "orderBy", "orderByRaw", "orderByDesc", "reorder", "clearOrders" ],
  // LIMIT / OFFSET
  limit: [ "limit", "offset", "take", "skip" ],
  // Locking
  lock: [ "lock", "sharedLock", "lockForUpdate", "noLock", "skipLocked" ],
  // CTEs
  cte: [ "with", "withRecursive" ],
  // Unions
  union: [ "union", "unionAll" ],
  // Executors
  executor: [ "get", "first", "find", "value", "values", "count", "max", "min", "sum", "avg", "exists", "paginate" ],
  // Mutations
  mutation: [ "insert", "update", "delete" ],
  // Conditional
  conditional: [ "when" ],
  // Param condition keys (inside "when" value object)
  paramCondition: [ "param", "notEmpty", "isEmpty", "hasValue", "gt", "gte", "lt", "lte", "eq", "neq" ],
  // Logical condition keys
  logicalCondition: [ "and", "or", "not" ],
  // Special references
  special: [ "$param", "$raw" ]
};

// Get valid keys from schema based on context
const getContextualCompletions = ( context ) => {
  let suggestions = [];

  // Helper to add a key suggestion with optional value snippet
  const addKey = ( key, detail = "", doc = "", valueSnippet = "" ) => {
    if ( suggestions.find( s => s.label === key ) ) return;
    // If we have a value snippet and we're typing a key, include key + colon + value
    let insertText;
    if ( valueSnippet && context.isTypingKey ) {
      insertText = `${key}": ${valueSnippet}`;
    } else if ( context.isTypingKey ) {
      insertText = key;
    } else {
      insertText = `"${key}"`;
    }
    suggestions.push( {
      label: key,
      kind: monaco.languages.CompletionItemKind.Property,
      insertText,
      documentation: doc,
      detail,
      filterText: key
    } );
  };

  // Helper to add action object snippets (for when inside array at root level)
  const addActionSnippet = ( key, detail, doc, valueSnippet ) => {
    if ( suggestions.find( s => s.label === key ) ) return;
    suggestions.push( {
      label: key,
      kind: monaco.languages.CompletionItemKind.Snippet,
      insertText: `{ "${key}": ${valueSnippet} }`,
      documentation: doc,
      detail,
      filterText: key
    } );
  };

  // Check if we're inside a "when" block's condition object
  const inWhenCondition = context.parentKeys.includes( "when" );
  const isDirectlyInWhenValue = context.lastKey === "when" && context.isValue;

  // Inside a param condition (the value of "when")
  if ( isDirectlyInWhenValue || ( inWhenCondition && context.inObject ) ) {
    // Offer param condition keys
    for ( const key of qbmlActionKeys.paramCondition ) {
      addKey( key, "Param condition", `Check parameter with ${key}` );
    }
    for ( const key of qbmlActionKeys.logicalCondition ) {
      addKey( key, "Logical", `Combine conditions with ${key}` );
    }
    return suggestions;
  }

  // Inside the root array (not in an object) - show action snippets
  if ( context.inArray && !context.inObject && context.parentKeys.length === 0 ) {
    // Source actions
    addActionSnippet( "from", "Source", "Specify table to query", '"$1"' );
    addActionSnippet( "table", "Source", "Specify table (alias for from)", '"$1"' );

    // Select
    addActionSnippet( "select", "Select", "Select columns", '["$1"]' );

    // Where clauses
    addActionSnippet( "where", "Where", "Filter rows", '["$1", "$2"]' );
    addActionSnippet( "whereIn", "Where", "Filter by multiple values", '["$1", [$2]]' );
    addActionSnippet( "whereLike", "Where", "Pattern matching", '["$1", "%$2%"]' );
    addActionSnippet( "whereNull", "Where", "Check for NULL", '"$1"' );
    addActionSnippet( "whereBetween", "Where", "Range filter", '["$1", $2, $3]' );

    // Joins
    addActionSnippet( "join", "Join", "Inner join", '["$1", "$2", "=", "$3"]' );
    addActionSnippet( "leftJoin", "Join", "Left join", '["$1", "$2", "=", "$3"]' );
    addActionSnippet( "rightJoin", "Join", "Right join", '["$1", "$2", "=", "$3"]' );
    addActionSnippet( "innerJoin", "Join", "Inner join", '["$1", "$2", "=", "$3"]' );
    addActionSnippet( "crossJoin", "Join", "Cross join", '"$1"' );

    // Group/Order
    addActionSnippet( "groupBy", "Group", "Group results", '"$1"' );
    addActionSnippet( "orderBy", "Order", "Sort ascending", '["$1", "asc"]' );
    addActionSnippet( "orderByDesc", "Order", "Sort descending", '"$1"' );

    // Limit
    addActionSnippet( "limit", "Limit", "Limit results", "$1" );
    addActionSnippet( "offset", "Limit", "Skip rows", "$1" );

    // Executors
    addActionSnippet( "get", "Executor", "Get all results", "true" );
    addActionSnippet( "first", "Executor", "Get first result", "true" );
    addActionSnippet( "paginate", "Executor", "Paginated results", '{ "page": 1, "maxRows": $1 }' );
    addActionSnippet( "count", "Executor", "Count rows", "true" );

    // Conditional
    addActionSnippet( "when", "Conditional", "Conditional action", '{ "param": "$1", "notEmpty": true }, "$2": $3' );

    // CTE
    addActionSnippet( "with", "CTE", "Common Table Expression", '"$1", "query": [$2]' );

    return suggestions;
  }

  // At action level (inside an object at depth 1-2)
  if ( context.inObject && !inWhenCondition ) {
    // Add keys with their typical value patterns
    addKey( "from", "Source", "Specify table to query", '"$1"' );
    addKey( "table", "Source", "Specify table (alias for from)", '"$1"' );
    addKey( "fromSub", "Source", "Subquery as source", "[$1]" );
    addKey( "fromRaw", "Source", "Raw SQL source", '"$1"' );

    addKey( "select", "Select", "Select columns", '["$1"]' );
    addKey( "selectRaw", "Select", "Raw select expression", '"$1"' );
    addKey( "distinct", "Select", "Select distinct", "true" );
    addKey( "addSelect", "Select", "Add to select", '["$1"]' );

    addKey( "where", "Where", "Filter rows", '["$1", "$2"]' );
    addKey( "whereIn", "Where", "Filter by values", '["$1", [$2]]' );
    addKey( "whereLike", "Where", "Pattern match", '["$1", "%$2%"]' );
    addKey( "whereNull", "Where", "Check NULL", '"$1"' );
    addKey( "whereBetween", "Where", "Range filter", '["$1", $2, $3]' );
    addKey( "whereColumn", "Where", "Compare columns", '["$1", "$2"]' );
    addKey( "whereRaw", "Where", "Raw WHERE", '"$1"' );
    addKey( "andWhere", "Where", "AND filter", '["$1", "$2"]' );
    addKey( "orWhere", "Where", "OR filter", '["$1", "$2"]' );

    addKey( "join", "Join", "Inner join", '["$1", "$2", "=", "$3"]' );
    addKey( "leftJoin", "Join", "Left join", '["$1", "$2", "=", "$3"]' );
    addKey( "rightJoin", "Join", "Right join", '["$1", "$2", "=", "$3"]' );
    addKey( "innerJoin", "Join", "Inner join", '["$1", "$2", "=", "$3"]' );
    addKey( "crossJoin", "Join", "Cross join", '"$1"' );

    addKey( "groupBy", "Group", "Group results", '"$1"' );
    addKey( "having", "Group", "Having clause", '["$1", "$2"]' );

    addKey( "orderBy", "Order", "Sort asc", '["$1", "asc"]' );
    addKey( "orderByDesc", "Order", "Sort desc", '"$1"' );
    addKey( "orderByRaw", "Order", "Raw order", '"$1"' );

    addKey( "limit", "Limit", "Limit rows", "$1" );
    addKey( "offset", "Limit", "Skip rows", "$1" );

    addKey( "get", "Executor", "Get all", "true" );
    addKey( "first", "Executor", "Get first", "true" );
    addKey( "paginate", "Executor", "Paginate", '{ "page": 1, "maxRows": $1 }' );
    addKey( "count", "Executor", "Count rows", "true" );

    addKey( "when", "Conditional", "Conditional", '{ "param": "$1", "notEmpty": true }' );

    addKey( "with", "CTE", "CTE name", '"$1"' );
    addKey( "query", "CTE", "CTE query", "[$1]" );
  }

  // When in value position, offer $param and $raw
  if ( context.isValue && !context.isTypingKey ) {
    suggestions.push(
      {
        label: "$param",
        kind: monaco.languages.CompletionItemKind.Reference,
        insertText: '{ "$param": "$1" }',
        documentation: "Reference a runtime parameter",
        detail: "Parameter"
      },
      {
        label: "$raw",
        kind: monaco.languages.CompletionItemKind.Reference,
        insertText: '{ "$raw": "$1" }',
        documentation: "Embed raw SQL",
        detail: "Raw SQL"
      }
    );
  }

  return suggestions;
};

const registerSnippets = () => {
  snippetDisposable = monaco.languages.registerCompletionItemProvider( "json", {
    triggerCharacters: [ '"', ":" ],
    provideCompletionItems( targetModel, position ) {
      if ( !model || targetModel.uri.toString() !== model.uri.toString() ) {
        return { suggestions: [] };
      }

      const text = targetModel.getValue();
      const offset = targetModel.getOffsetAt( position );
      const context = getJsonContext( text, offset );

      // Determine the range for replacement
      const word = targetModel.getWordUntilPosition( position );
      const lineText = targetModel.getLineContent( position.lineNumber );

      let range = {
        startLineNumber: position.lineNumber,
        endLineNumber: position.lineNumber,
        startColumn: word.startColumn,
        endColumn: position.column,
      };

      // If typing inside quotes for a key, adjust range to replace just the typed text
      if ( context.isTypingKey ) {
        const beforeCursor = lineText.substring( 0, position.column - 1 );
        const lastQuote = beforeCursor.lastIndexOf( '"' );
        if ( lastQuote >= 0 ) {
          const afterCursor = lineText.substring( position.column - 1 );
          const nextQuote = afterCursor.indexOf( '"' );
          range = {
            startLineNumber: position.lineNumber,
            endLineNumber: position.lineNumber,
            startColumn: lastQuote + 2,
            endColumn: nextQuote >= 0 ? position.column + nextQuote : position.column,
          };
        }
      }

      // Get contextual completions
      const contextSuggestions = getContextualCompletions( context );

      // Filter snippets based on context
      let snippetSuggestions = [];
      if ( !context.isTypingKey && !context.isValue ) {
        snippetSuggestions = ( props.snippets || [] )
          .filter( s => s.label.startsWith( "qbml-" ) )
          .map( ( snippet ) => ( {
            label: snippet.label,
            kind: monaco.languages.CompletionItemKind.Snippet,
            insertText: snippet.insertText,
            insertTextRules: monaco.languages.CompletionItemInsertTextRule.InsertAsSnippet,
            documentation: { value: snippet.documentation || "", isTrusted: true },
            detail: snippet.detail || snippet.label,
            sortText: `2_${snippet.label}`,
          } ) );
      }

      // Merge suggestions
      const allSuggestions = [
        ...contextSuggestions.map( s => ( {
          ...s,
          range,
          insertTextRules: s.insertText?.includes( "$" ) ? monaco.languages.CompletionItemInsertTextRule.InsertAsSnippet : undefined,
          sortText: `0_${s.label}`,
        } ) ),
        ...snippetSuggestions.map( s => ( { ...s, range } ) )
      ];

      return { suggestions: allSuggestions };
    },
  } );
};

// Schema description map
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
            // Handle when/else by looking up their referenced definition
            if ( propKey === "when" || propKey === "else" ) {
              if ( propDef.$ref ) {
                const refKey = propDef.$ref.split( "/" ).pop();
                const refDef = definitions[ refKey ];
                if ( refDef?.description && !schemaDescriptionMap.has( propKey ) ) {
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

// Get all action keys as flat array for error message suggestions
const getAllActionKeys = () => {
  return [
    ...qbmlActionKeys.source,
    ...qbmlActionKeys.select,
    ...qbmlActionKeys.where,
    ...qbmlActionKeys.join,
    ...qbmlActionKeys.group,
    ...qbmlActionKeys.order,
    ...qbmlActionKeys.limit,
    ...qbmlActionKeys.lock,
    ...qbmlActionKeys.cte,
    ...qbmlActionKeys.union,
    ...qbmlActionKeys.executor,
    ...qbmlActionKeys.mutation,
    ...qbmlActionKeys.conditional
  ];
};

const detectContext = ( line ) => {
  if ( !model ) return "action";
  // Look at content around the error line to determine context
  const startLine = Math.max( 1, line - 10 );
  const content = model.getValueInRange( {
    startLineNumber: startLine,
    startColumn: 1,
    endLineNumber: line,
    endColumn: model.getLineMaxColumn( line )
  } );

  // Check if we're inside a "when" block by looking for unclosed when
  const whenMatches = ( content.match( /"when"\s*:/g ) || [] ).length;

  // If we find "param" nearby, we're likely in a param condition
  if ( content.includes( '"param"' ) && !content.includes( '"where' ) ) {
    return "paramCondition";
  }

  // If we find "and", "or", "not" as keys (not values), likely logical condition
  if ( /"(and|or|not)"\s*:/.test( content ) ) {
    return "logicalCondition";
  }

  // If we're in a when block (has when but action isn't closed)
  if ( whenMatches > 0 ) {
    return "conditional";
  }

  return "action";
};

const friendlyErrorMessage = ( message, line ) => {
  // Extract property name from "Property X is not allowed" style messages
  const propMatch = message.match( /Property (.+?) is not allowed/i );
  if ( propMatch ) {
    const badProp = propMatch[ 1 ];
    const context = detectContext( line );

    // Get valid keys based on detected context
    let validKeys;
    let contextHint = "";
    if ( context === "conditional" ) {
      validKeys = [ ...qbmlActionKeys.where, "when", "else" ];
      contextHint = " In a 'when' block, use WHERE clauses like: where, whereIn, whereLike, etc.";
    } else if ( context === "paramCondition" ) {
      validKeys = qbmlActionKeys.paramCondition;
      contextHint = " In a param condition, valid keys are: param, notEmpty, isEmpty, hasValue, gt, gte, lt, lte, eq, neq.";
    } else if ( context === "logicalCondition" ) {
      validKeys = qbmlActionKeys.logicalCondition;
      contextHint = " In a logical condition, valid keys are: and, or, not.";
    } else {
      validKeys = getAllActionKeys();
    }

    // Find similar valid keys in this context
    const similar = validKeys.filter( k =>
      k.toLowerCase().includes( badProp.toLowerCase().substring( 0, 3 ) ) ||
      badProp.toLowerCase().includes( k.toLowerCase().substring( 0, 3 ) )
    ).slice( 0, 5 );

    const suggestion = similar.length > 0
      ? ` Did you mean: ${similar.join( ", " )}?`
      : contextHint || " Valid keys include: from, select, where, join, orderBy, limit, get, etc.";

    return `Unknown property "${badProp}".${suggestion}`;
  }
  return message;
};

// Guard to prevent infinite loop from setModelMarkers triggering onDidChangeMarkers
let isUpdatingMarkers = false;

const updateValidationState = () => {
  if ( !model || isUpdatingMarkers ) return;

  const markers = monaco.editor.getModelMarkers( { resource: model.uri } );
  const errors = markers.filter( ( m ) => m.severity === monaco.MarkerSeverity.Error );

  // Check if we need to update markers with friendly messages
  // Only do this if the messages aren't already friendly (to avoid re-processing)
  const needsFriendlyUpdate = markers.some( m => m.message.includes( "Property" ) && m.message.includes( "is not allowed" ) );

  if ( needsFriendlyUpdate ) {
    // Replace Monaco's markers with friendlier messages
    const friendlyMarkers = markers.map( m => ( {
      ...m,
      message: friendlyErrorMessage( m.message, m.startLineNumber ),
    } ) );

    isUpdatingMarkers = true;
    monaco.editor.setModelMarkers( model, "json", friendlyMarkers );
    isUpdatingMarkers = false;

    validationErrors.value = friendlyMarkers
      .filter( m => m.severity === monaco.MarkerSeverity.Error )
      .map( ( m ) => ( {
        message: m.message,
        path: m.relatedInformation?.[0]?.message || "",
        line: m.startLineNumber,
        column: m.startColumn,
      } ) );
  } else {
    validationErrors.value = errors.map( ( m ) => ( {
      message: m.message,
      path: m.relatedInformation?.[0]?.message || "",
      line: m.startLineNumber,
      column: m.startColumn,
    } ) );
  }

  hasErrors.value = errors.length > 0;
  errorCount.value = errors.length;

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
  console.log( "[MonacoJsonEditor] compactJson called, editor:", !!editor, "model:", !!model );
  if ( !editor || !model ) {
    console.warn( "[MonacoJsonEditor] compactJson: editor or model not ready" );
    return;
  }
  try {
    const content = editor.getValue();
    console.log( "[MonacoJsonEditor] compactJson: content length:", content.length );
    const parsed = JSON.parse( content );
    const compacted = JSON.stringify( parsed );
    console.log( "[MonacoJsonEditor] compactJson: compacted length:", compacted.length );
    const fullRange = model.getFullModelRange();
    console.log( "[MonacoJsonEditor] compactJson: fullRange:", fullRange );
    editor.executeEdits( "compact", [ { range: fullRange, text: compacted, forceMoveMarkers: true } ] );
    console.log( "[MonacoJsonEditor] compactJson: edit executed" );
  } catch ( err ) {
    console.warn( "[MonacoJsonEditor] compactJson error:", err );
  }
};

const sortKeys = () => {
  if ( !editor ) return;
  try {
    const content = editor.getValue();
    const parsed = JSON.parse( content );
    const sorted = sortObjectKeys( parsed );
    const formatted = JSON.stringify( sorted, null, props.tabSize );
    editor.setValue( formatted );
  } catch { /* ignore invalid JSON */ }
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
  // Process snippet placeholders: ${1:default} -> default, ${1} -> ""
  text = text.replace( /\$\{(\d+):([^}]+)\}/g, "$2" );
  text = text.replace( /\$\{\d+\}/g, "" );
  // Convert escaped newlines to actual newlines
  text = text.replace( /\\n/g, "\n" );
  // Remove escape backslashes (\\$ -> $) for JSON keys like $param
  text = text.replace( /\\(.)/g, "$1" );
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

const hideHoverTooltip = ( immediate = true, force = false ) => {
  if ( hoverTooltip.value.pinned && !force ) return;
  if ( isMouseOverTooltip && !force ) return; // Don't hide while mouse is over tooltip
  if ( immediate ) {
    hoverTooltip.value.visible = false;
    hoverTooltip.value.pinned = false;
    isMouseOverTooltip = false;
  } else {
    // Delay to allow user to move mouse to tooltip for scrolling
    hideTimeoutId = setTimeout( () => {
      if ( !hoverTooltip.value.pinned && !isMouseOverTooltip ) {
        hoverTooltip.value.visible = false;
      }
    }, 400 );
  }
};

const togglePinTooltip = () => {
  hoverTooltip.value.pinned = !hoverTooltip.value.pinned;
};

const onTooltipMouseEnter = () => {
  isMouseOverTooltip = true;
  if ( hideTimeoutId ) {
    clearTimeout( hideTimeoutId );
    hideTimeoutId = null;
  }
};

const onTooltipMouseLeave = () => {
  isMouseOverTooltip = false;
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
    acceptSuggestionOnEnter: "off", // Use Tab to accept, Enter always inserts newline
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

  // Custom hover
  let lastHoverWord = "";
  editor.onMouseMove( ( e ) => {
    if ( hoverTooltip.value.pinned ) return;
    if ( e.target.type !== monaco.editor.MouseTargetType.CONTENT_TEXT ) {
      // When moving off text, start delayed hide (gives user time to reach tooltip)
      if ( hoverTooltip.value.visible ) {
        hideHoverTooltip( false );
      }
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
    // Position tooltip close to cursor to minimize gap
    const x = e.event.posx - rootRect.left + 5;
    const y = e.event.posy - rootRect.top + 10;
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
    console.log( "[MonacoJsonEditor] schema watcher fired, has schema:", !!newSchema, "has model:", !!model );
    if ( newSchema && model ) {
      configureSchema();
      buildDescriptionMap();
      console.log( "[MonacoJsonEditor] Description map built, size:", schemaDescriptionMap.size );
      setTimeout( updateValidationState, 200 );
    }
  },
  { deep: true }
);

watch(
  () => props.snippets,
  ( newSnippets ) => {
    console.log( "[MonacoJsonEditor] snippets watcher fired, new count:", newSnippets?.length || 0 );
    if ( snippetDisposable ) {
      snippetDisposable.dispose();
      snippetDisposable = null;
    }
    registerSnippets();

    // Also rebuild schema/descriptions when snippets load (they come together from schema registry)
    if ( props.schema && model && schemaDescriptionMap.size === 0 ) {
      console.log( "[MonacoJsonEditor] Rebuilding schema config from snippets watcher" );
      configureSchema();
      buildDescriptionMap();
      console.log( "[MonacoJsonEditor] Description map built, size:", schemaDescriptionMap.size );
    }
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
  isMouseOverTooltip = false;
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
  background: #1e1e1e;
}

.monaco-title-bar {
  display: flex;
  align-items: center;
  background: linear-gradient(to bottom, #374151, #1f2937);
  border-bottom: 1px solid #374151;
  height: 40px;
  padding: 0 12px;
  flex-shrink: 0;
}

.title-text {
  font-weight: 600;
  font-size: 14px;
  color: #d1d5db;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.spacer {
  flex: 1;
}

.monaco-toolbar {
  display: flex;
  align-items: center;
  background-color: #1f2937;
  border-bottom: 1px solid #374151;
  height: 40px;
  padding: 0 8px;
  flex-shrink: 0;
  gap: 4px;
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
  font-size: 12px;
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

/* Custom hover tooltip */
.custom-hover-tooltip {
  position: absolute;
  z-index: 1000;
  width: 500px;
  max-width: 90vw;
  min-width: 380px;
  max-height: 310px;
  background: #1f2937;
  border: 1px solid #374151;
  border-radius: 6px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  font-size: 13px;
  line-height: 1.5;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  pointer-events: auto;
}

/* Invisible padding area to make tooltip easier to reach */
.custom-hover-tooltip::before {
  content: "";
  position: absolute;
  top: -15px;
  left: -15px;
  right: -15px;
  bottom: -15px;
  z-index: -1;
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
  height: 28px;
  padding: 0 12px;
  flex-shrink: 0;
  font-size: 12px;
  color: #9ca3af;
}
</style>
