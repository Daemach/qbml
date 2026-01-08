/**
 * JSON Schema Registry Composable
 *
 * Provides a centralized registry for JSON schemas with Monaco editor integration.
 * Supports autocomplete, validation, hover documentation, and snippets.
 *
 * ## Quick Start
 * ```js
 * import { useJsonSchema, registerSchema, initQBMLSchema } from "./useJsonSchema";
 * import qbmlSchema from "../qbml.schema.json";
 *
 * // Initialize QBML schema (do this once in boot/setup)
 * initQBMLSchema( qbmlSchema );
 *
 * // Use in component
 * const { getEditorProps } = useJsonSchema();
 * const editorProps = getEditorProps( "qbml" );
 *
 * // In template:
 * // <MonacoJsonEditor v-model="data" v-bind="editorProps" />
 * ```
 *
 * ## Progressive Enhancement
 * The MonacoJsonEditor works without any schema - use getEditorProps() only
 * when you want schema validation, autocomplete, and rich hover docs.
 *
 * ## Schema Format (JSON Schema Draft-07)
 * ```json
 * {
 *   "$schema": "http://json-schema.org/draft-07/schema#",
 *   "title": "My Schema",
 *   "type": "object",
 *   "properties": {
 *     "name": {
 *       "type": "string",
 *       "description": "This text appears in hover docs"
 *     }
 *   }
 * }
 * ```
 *
 * ## Snippet Format
 * ```js
 * const mySnippets = [
 *   {
 *     label: "my-template",           // Unique ID, shown in autocomplete
 *     detail: "My Template",          // Display name in dropdown
 *     documentation: "Description",   // Shown in dropdown & autocomplete
 *     insertText: `{
 *   "name": "\${1:myName}",
 *   "value": \${2:0}
 * }`
 *   }
 * ];
 * ```
 *
 * @see MonacoJsonEditor component for full editor documentation
 */

import { reactive, readonly } from "vue";

/**
 * Schema configuration object
 * @typedef {Object} SchemaConfig
 * @property {Object} schema - JSON Schema object
 * @property {string} [name] - Display name for the schema
 * @property {string} [uri] - Schema URI (auto-generated if not provided)
 * @property {Array} [snippets] - Code snippets for this schema type
 * @property {string} [description] - Schema description
 * @property {string} [docsUrl] - Documentation URL
 */

// Global schema registry
const schemaRegistry = reactive( new Map() );

/**
 * Register a JSON schema for use with Monaco editor
 *
 * @param {string} id - Unique identifier for the schema (e.g., "qbml", "config")
 * @param {SchemaConfig} config - Schema configuration
 */
export function registerSchema( id, config ) {
  const uri = config.uri || `https://veriti.com/schemas/${id}.schema.json`;

  schemaRegistry.set( id, {
    id,
    uri,
    name: config.name || id.toUpperCase(),
    schema: config.schema,
    snippets: config.snippets || [],
    description: config.description || "",
    docsUrl: config.docsUrl || "",
  } );
}

/**
 * Unregister a schema
 *
 * @param {string} id - Schema identifier
 */
export function unregisterSchema( id ) {
  schemaRegistry.delete( id );
}

/**
 * Check if a schema is registered
 *
 * @param {string} id - Schema identifier
 * @returns {boolean}
 */
export function hasSchema( id ) {
  return schemaRegistry.has( id );
}

/**
 * Get all registered schema IDs
 *
 * @returns {string[]}
 */
export function getSchemaIds() {
  return Array.from( schemaRegistry.keys() );
}

/**
 * Composable for accessing JSON schemas
 */
export function useJsonSchema() {
  /**
   * Get schema configuration by ID
   *
   * @param {string} id - Schema identifier
   * @returns {SchemaConfig|null}
   */
  function getSchemaConfig( id ) {
    const config = schemaRegistry.get( id );
    if ( !config ) {
      console.warn( `[useJsonSchema] Schema "${id}" not found in registry` );
      return null;
    }
    return config;
  }

  /**
   * Get props to pass to MonacoJsonEditor for a specific schema
   *
   * @param {string} id - Schema identifier
   * @returns {Object} Props object for MonacoJsonEditor
   */
  function getEditorProps( id ) {
    const config = getSchemaConfig( id );
    if ( !config ) {
      return {};
    }

    return {
      schema: config.schema,
      schemaUri: config.uri,
      schemaName: config.name,
      snippets: config.snippets,
    };
  }

  /**
   * Get all registered schemas
   *
   * @returns {Map<string, SchemaConfig>}
   */
  function getAllSchemas() {
    return readonly( schemaRegistry );
  }

  return {
    getSchemaConfig,
    getEditorProps,
    getAllSchemas,
    registerSchema,
    unregisterSchema,
    hasSchema,
    getSchemaIds,
  };
}

// ============================================================================
// QBML Schema Configuration
// ============================================================================

/**
 * QBML code snippets for Monaco editor
 */
export const qbmlSnippets = [
  {
    label: "qbml-basic",
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": ["\${2:*}"] },
  { "get": true }
]`,
    documentation: "Basic QBML query with from, select, and get",
    detail: "QBML Basic Query",
  },
  {
    label: "qbml-filtered",
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": ["\${2:*}"] },
  { "where": ["\${3:column}", "\${4:value}"] },
  { "orderBy": ["\${5:column}", "asc"] },
  { "get": true }
]`,
    documentation: "QBML query with filtering and ordering",
    detail: "QBML Filtered Query",
  },
  {
    label: "qbml-paginated",
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": ["\${2:*}"] },
  { "orderBy": ["\${3:id}", "asc"] },
  { "paginate": { "page": \${4:1}, "maxRows": \${5:25} } }
]`,
    documentation: "QBML query with pagination",
    detail: "QBML Paginated Query",
  },
  {
    label: "qbml-join",
    insertText: `[
  { "from": "\${1:users} u" },
  { "leftJoin": ["\${2:orders} o", "u.id", "=", "o.user_id"] },
  { "select": ["u.*", "o.total"] },
  { "get": true }
]`,
    documentation: "QBML query with JOIN",
    detail: "QBML Join Query",
  },
  {
    label: "qbml-cte",
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
    documentation: "QBML query with CTE (Common Table Expression)",
    detail: "QBML CTE Query",
  },
  {
    label: "qbml-param-filter",
    insertText: `{
  "when": { "param": "\${1:paramName}", "notEmpty": true },
  "whereIn": ["\${2:column}", { "$param": "\${1:paramName}" }]
}`,
    documentation: "Conditional filter based on runtime parameter",
    detail: "QBML Param Filter",
  },
  {
    label: "qbml-raw-select",
    insertText: `{ "$raw": "\${1:COUNT(*) AS total}" }`,
    documentation: "Raw SQL expression for SELECT",
    detail: "QBML Raw Expression",
  },
  {
    label: "qbml-nested-where",
    insertText: `{
  "where": [
    { "where": ["\${1:column1}", "\${2:value1}"] },
    { "orWhere": ["\${3:column2}", "\${4:value2}"] }
  ]
}`,
    documentation: "Nested WHERE with parentheses grouping",
    detail: "QBML Nested Where",
  },
  {
    label: "qbml-dataviewer",
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": ["\${2:*}"] },
  {
    "when": { "param": "ids", "notEmpty": true },
    "whereIn": ["id", { "$param": "ids" }]
  },
  {
    "when": { "param": "search", "hasValue": true },
    "whereLike": ["name", { "$param": "search" }]
  },
  { "orderByDesc": "created_at" },
  { "paginate": { "page": 1, "maxRows": 100, "returnFormat": "tabular" } }
]`,
    documentation: "Full dataviewer query with multiple optional filters",
    detail: "QBML Dataviewer Template",
  },
  {
    label: "from",
    insertText: `{ "from": "\${1:tableName}" }`,
    documentation: "Specify the table to query from",
    detail: "FROM clause",
  },
  {
    label: "select",
    insertText: `{ "select": ["\${1:*}"] }`,
    documentation: "Select columns to retrieve",
    detail: "SELECT clause",
  },
  {
    label: "where",
    insertText: `{ "where": ["\${1:column}", "\${2:value}"] }`,
    documentation: "Basic WHERE comparison",
    detail: "WHERE clause",
  },
  {
    label: "whereIn",
    insertText: `{ "whereIn": ["\${1:column}", [\${2:values}]] }`,
    documentation: "WHERE column IN (values)",
    detail: "WHERE IN clause",
  },
  {
    label: "whereBetween",
    insertText: `{ "whereBetween": ["\${1:column}", "\${2:start}", "\${3:end}"] }`,
    documentation: "WHERE column BETWEEN start AND end",
    detail: "WHERE BETWEEN clause",
  },
  {
    label: "orderBy",
    insertText: `{ "orderBy": ["\${1:column}", "\${2:asc}"] }`,
    documentation: "Order results by column",
    detail: "ORDER BY clause",
  },
  {
    label: "groupBy",
    insertText: `{ "groupBy": "\${1:column}" }`,
    documentation: "Group results by column",
    detail: "GROUP BY clause",
  },
  {
    label: "limit",
    insertText: `{ "limit": \${1:10} }`,
    documentation: "Limit number of results",
    detail: "LIMIT clause",
  },
  {
    label: "get",
    insertText: `{ "get": true }`,
    documentation: "Execute query and return all results",
    detail: "GET executor",
  },
  {
    label: "first",
    insertText: `{ "first": true }`,
    documentation: "Execute query and return first result",
    detail: "FIRST executor",
  },
  {
    label: "paginate",
    insertText: `{ "paginate": { "page": \${1:1}, "maxRows": \${2:25} } }`,
    documentation: "Execute query with pagination metadata",
    detail: "PAGINATE executor",
  },
  {
    label: "$param",
    insertText: `{ "$param": "\${1:paramName}" }`,
    documentation: "Reference a runtime parameter",
    detail: "Parameter Reference",
  },
  {
    label: "$raw",
    insertText: `{ "$raw": "\${1:SQL expression}" }`,
    documentation: "Embed raw SQL inline",
    detail: "Raw SQL Expression",
  },
  {
    label: "when",
    insertText: `{
  "when": { "param": "\${1:paramName}", "\${2:notEmpty}": true },
  "\${3:where}": ["\${4:column}", "\${5:value}"]
}`,
    documentation: "Conditional action wrapper",
    detail: "WHEN condition",
  },
];

/**
 * Initialize QBML schema in the registry
 * Call this function with the schema object to register QBML support
 *
 * @param {Object} qbmlSchema - The QBML JSON schema object
 */
export function initQBMLSchema( qbmlSchema ) {
  registerSchema( "qbml", {
    schema: qbmlSchema,
    name: "QBML",
    uri: "https://qbml.ortusbooks.com/schemas/qbml.schema.json",
    snippets: qbmlSnippets,
    description: "Query Builder Markup Language - JSON-based query definitions for qb",
    docsUrl: "https://qb.ortusbooks.com/",
  } );
}

export default useJsonSchema;
