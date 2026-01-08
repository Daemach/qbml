/**
 * QBML Monaco Editor Configuration
 *
 * This file provides Monaco editor setup for QBML JSON editing with:
 * - JSON Schema validation
 * - Autocomplete with rich descriptions
 * - Hover documentation with qb links
 * - Custom error messages
 *
 * Usage:
 *   import { configureQBMLEditor, qbmlSchema } from './monaco-config';
 *   configureQBMLEditor(monaco);
 */

import type * as Monaco from 'monaco-editor';

// Import the schema (adjust path as needed)
import qbmlSchema from './qbml.schema.json';

/**
 * Configure Monaco editor for QBML JSON editing
 *
 * @param monaco - The monaco-editor module
 * @param options - Optional configuration overrides
 */
export function configureQBMLEditor(
  monaco: typeof Monaco,
  options: QBMLEditorOptions = {}
): void {
  const {
    schemaUri = 'https://qbml.ortusbooks.com/schemas/qbml.schema.json',
    fileMatch = ['*.qbml.json', '**/qbml/*.json', '**/*.qbml'],
    enableSchemaRequest = false,
  } = options;

  // Configure JSON language defaults
  monaco.languages.json.jsonDefaults.setDiagnosticsOptions({
    validate: true,
    allowComments: false,
    schemas: [
      {
        uri: schemaUri,
        fileMatch,
        schema: qbmlSchema as unknown as Record<string, unknown>,
      },
    ],
    enableSchemaRequest,
    schemaValidation: 'error',
  });
}

/**
 * Create a Monaco editor model for QBML content
 *
 * @param monaco - The monaco-editor module
 * @param content - Initial QBML JSON content
 * @param uri - Optional URI for the model
 */
export function createQBMLModel(
  monaco: typeof Monaco,
  content: string = '[\n  \n]',
  uri?: string
): Monaco.editor.ITextModel {
  const modelUri = uri
    ? monaco.Uri.parse(uri)
    : monaco.Uri.parse(`inmemory://qbml/${Date.now()}.qbml.json`);

  return monaco.editor.createModel(content, 'json', modelUri);
}

/**
 * QBML-specific editor options
 */
export interface QBMLEditorOptions {
  /** URI for the schema (default: https://qbml.ortusbooks.com/schemas/qbml.schema.json) */
  schemaUri?: string;
  /** File patterns to match (default: ['*.qbml.json', '**/qbml/*.json', '**/*.qbml']) */
  fileMatch?: string[];
  /** Allow fetching schemas from URLs (default: false) */
  enableSchemaRequest?: boolean;
}

/**
 * Recommended Monaco editor options for QBML editing
 */
export const qbmlEditorOptions: Monaco.editor.IStandaloneEditorConstructionOptions = {
  language: 'json',
  theme: 'vs-dark',
  minimap: { enabled: false },
  lineNumbers: 'on',
  tabSize: 2,
  insertSpaces: true,
  formatOnPaste: true,
  formatOnType: true,
  autoClosingBrackets: 'always',
  autoClosingQuotes: 'always',
  autoIndent: 'full',
  folding: true,
  foldingStrategy: 'indentation',
  showFoldingControls: 'always',
  bracketPairColorization: { enabled: true },
  guides: {
    bracketPairs: true,
    indentation: true,
  },
  suggest: {
    showKeywords: true,
    showSnippets: true,
    showProperties: true,
    showValues: true,
    insertMode: 'replace',
    filterGraceful: true,
    snippetsPreventQuickSuggestions: false,
  },
  quickSuggestions: {
    strings: true,
    other: true,
    comments: false,
  },
  wordBasedSuggestions: 'off',
  acceptSuggestionOnEnter: 'on',
  tabCompletion: 'on',
  parameterHints: { enabled: true },
  scrollBeyondLastLine: false,
  automaticLayout: true,
};

/**
 * QBML code snippets for Monaco editor
 *
 * Register these with monaco.languages.registerCompletionItemProvider
 */
export const qbmlSnippets: Monaco.languages.CompletionItem[] = [
  {
    label: 'qbml-basic',
    kind: 15, // Snippet
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": [\${2:"*"}] },
  { "get": true }
]`,
    insertTextRules: 4, // InsertAsSnippet
    documentation: 'Basic QBML query with from, select, and get',
    detail: 'QBML Basic Query',
  },
  {
    label: 'qbml-filtered',
    kind: 15,
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": [\${2:"*"}] },
  { "where": ["\${3:column}", "\${4:value}"] },
  { "orderBy": ["\${5:column}", "asc"] },
  { "get": true }
]`,
    insertTextRules: 4,
    documentation: 'QBML query with filtering and ordering',
    detail: 'QBML Filtered Query',
  },
  {
    label: 'qbml-paginated',
    kind: 15,
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": [\${2:"*"}] },
  { "orderBy": ["\${3:id}", "asc"] },
  { "paginate": { "page": \${4:1}, "maxRows": \${5:25} } }
]`,
    insertTextRules: 4,
    documentation: 'QBML query with pagination',
    detail: 'QBML Paginated Query',
  },
  {
    label: 'qbml-join',
    kind: 15,
    insertText: `[
  { "from": "\${1:users} u" },
  { "leftJoin": ["\${2:orders} o", "u.id", "=", "o.user_id"] },
  { "select": ["u.*", "o.total"] },
  { "get": true }
]`,
    insertTextRules: 4,
    documentation: 'QBML query with JOIN',
    detail: 'QBML Join Query',
  },
  {
    label: 'qbml-cte',
    kind: 15,
    insertText: `[
  {
    "with": "\${1:cte_name}",
    "query": [
      { "from": "\${2:tableName}" },
      { "where": ["\${3:column}", "\${4:value}"] }
    ]
  },
  { "from": "\${1:cte_name}" },
  { "select": ["*"] },
  { "get": true }
]`,
    insertTextRules: 4,
    documentation: 'QBML query with CTE (Common Table Expression)',
    detail: 'QBML CTE Query',
  },
  {
    label: 'qbml-param-filter',
    kind: 15,
    insertText: `{
  "when": { "param": "\${1:paramName}", "notEmpty": true },
  "whereIn": ["\${2:column}", { "\\$param": "\${1:paramName}" }]
}`,
    insertTextRules: 4,
    documentation: 'Conditional filter based on runtime parameter',
    detail: 'QBML Param Filter',
  },
  {
    label: 'qbml-raw-select',
    kind: 15,
    insertText: `{ "\\$raw": "\${1:COUNT(*) AS total}" }`,
    insertTextRules: 4,
    documentation: 'Raw SQL expression for SELECT',
    detail: 'QBML Raw Expression',
  },
  {
    label: 'qbml-nested-where',
    kind: 15,
    insertText: `{
  "where": [
    { "where": ["\${1:column1}", "\${2:value1}"] },
    { "orWhere": ["\${3:column2}", "\${4:value2}"] }
  ]
}`,
    insertTextRules: 4,
    documentation: 'Nested WHERE with parentheses grouping',
    detail: 'QBML Nested Where',
  },
  {
    label: 'qbml-dataviewer',
    kind: 15,
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": [\${2:"*"}] },
  {
    "when": { "param": "ids", "notEmpty": true },
    "whereIn": ["id", { "\\$param": "ids" }]
  },
  {
    "when": { "param": "search", "hasValue": true },
    "whereLike": ["name", { "\\$param": "search" }]
  },
  {
    "when": {
      "and": [
        { "param": "startDate", "hasValue": true },
        { "param": "endDate", "hasValue": true }
      ]
    },
    "whereBetween": ["created_at", { "\\$param": "startDate" }, { "\\$param": "endDate" }]
  },
  { "orderByDesc": "created_at" },
  { "paginate": { "page": 1, "maxRows": 100, "returnFormat": "tabular" } }
]`,
    insertTextRules: 4,
    documentation: 'Full dataviewer query with multiple optional filters',
    detail: 'QBML Dataviewer Template',
  },
];

/**
 * Register QBML snippets with Monaco
 */
export function registerQBMLSnippets(monaco: typeof Monaco): Monaco.IDisposable {
  return monaco.languages.registerCompletionItemProvider('json', {
    provideCompletionItems(model, position) {
      const word = model.getWordUntilPosition(position);
      const range = {
        startLineNumber: position.lineNumber,
        endLineNumber: position.lineNumber,
        startColumn: word.startColumn,
        endColumn: word.endColumn,
      };

      return {
        suggestions: qbmlSnippets.map((snippet) => ({
          ...snippet,
          range,
        })),
      };
    },
  });
}

/**
 * Custom error formatter for better QBML error messages
 *
 * Use with ajv-errors or custom validation
 */
export const qbmlErrorMessages: Record<string, string> = {
  // Top-level errors
  'must be array': 'QBML query must be an array of action objects',
  'must have required property': 'Action object is missing a required property',

  // Action errors
  'must match exactly one schema in oneOf':
    'Invalid action. Check the action name and value format.',

  // Source actions
  'from': 'The "from" action requires a table name (string)',
  'fromSub': 'fromSub requires an alias and a "query" array',
  'table': 'The "table" action requires a table name (string)',

  // Select actions
  'select': 'The "select" action requires columns (string or array)',
  'selectRaw': 'selectRaw requires a SQL string or [sql, bindings] array',
  'subSelect': 'subSelect requires an alias and a "query" array',

  // Where actions
  'where':
    'Invalid where format. Use [column, value] or [column, operator, value]',
  'whereIn': 'whereIn requires [column, valuesArray]',
  'whereBetween': 'whereBetween requires [column, start, end]',
  'whereLike': 'whereLike requires [column, pattern]',
  'whereNull': 'whereNull requires a column name',
  'whereColumn': 'whereColumn requires [first, operator, second]',
  'whereExists': 'whereExists requires a "query" array',
  'whereRaw': 'whereRaw requires a SQL string or [sql, bindings] array',

  // Join actions
  'join': 'join requires [table, first, operator, second] or table with "on" array',
  'joinSub': 'joinSub requires an alias, "query" array, and "on" conditions',
  'crossJoin': 'crossJoin requires a table name',

  // Grouping
  'groupBy': 'groupBy requires column(s) (string or array)',
  'having': 'having requires [column, operator, value]',
  'havingRaw': 'havingRaw requires a SQL string',

  // Ordering
  'orderBy': 'orderBy requires column or [column, direction]',
  'orderByRaw': 'orderByRaw requires a SQL string',

  // Limiting
  'limit': 'limit requires a positive integer',
  'offset': 'offset requires a non-negative integer',
  'forPage': 'forPage requires [page, perPage] (both positive integers)',

  // CTE
  'with': 'CTE requires a name and "query" array',
  'withRecursive': 'Recursive CTE requires a name and "query" array',

  // Union
  'union': 'union requires a "query" array',
  'unionAll': 'unionAll requires a "query" array',

  // Executors
  'get': 'get accepts true or { returnFormat: "array"|"tabular" }',
  'first': 'first accepts true',
  'find': 'find accepts id or [id, idColumn]',
  'paginate': 'paginate requires { page, maxRows }',
  'value': 'value requires a column name',
  'values': 'values requires a column name',

  // Special constructs
  '$param': '$param must reference a valid parameter name (string)',
  '$raw': '$raw must be a SQL string or { sql, bindings }',
  'when':
    'Invalid when condition. Use "hasValues", "notEmpty", or param-based condition',
};

/**
 * Format a JSON Schema validation error for display
 */
export function formatQBMLError(error: {
  message?: string;
  keyword?: string;
  dataPath?: string;
  instancePath?: string;
  params?: Record<string, unknown>;
}): string {
  const path = error.instancePath || error.dataPath || '';
  const keyword = error.keyword || '';
  const params = error.params || {};

  // Check for custom message
  if (params.missingProperty) {
    const prop = params.missingProperty as string;
    if (qbmlErrorMessages[prop]) {
      return `${path}: ${qbmlErrorMessages[prop]}`;
    }
  }

  // Check keyword-based message
  if (qbmlErrorMessages[keyword]) {
    return `${path}: ${qbmlErrorMessages[keyword]}`;
  }

  // Check message-based override
  const msg = error.message || '';
  for (const [pattern, replacement] of Object.entries(qbmlErrorMessages)) {
    if (msg.includes(pattern)) {
      return `${path}: ${replacement}`;
    }
  }

  // Default format
  return `${path}: ${msg}`;
}

// Re-export the schema for direct use
export { qbmlSchema };

export default {
  configureQBMLEditor,
  createQBMLModel,
  registerQBMLSnippets,
  qbmlEditorOptions,
  qbmlSnippets,
  qbmlErrorMessages,
  formatQBMLError,
  qbmlSchema,
};
