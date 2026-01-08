/**
 * JSON Schema Registry Composable
 *
 * Provides a centralized registry for JSON schemas with Monaco editor integration.
 */

import { reactive, readonly } from "vue";

// Global schema registry
const schemaRegistry = reactive( new Map() );

/**
 * Register a JSON schema for use with Monaco editor
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
 */
export function unregisterSchema( id ) {
  schemaRegistry.delete( id );
}

/**
 * Check if a schema is registered
 */
export function hasSchema( id ) {
  return schemaRegistry.has( id );
}

/**
 * Get all registered schema IDs
 */
export function getSchemaIds() {
  return Array.from( schemaRegistry.keys() );
}

/**
 * Composable for accessing JSON schemas
 */
export function useJsonSchema() {
  function getSchemaConfig( id ) {
    const config = schemaRegistry.get( id );
    if ( !config ) {
      console.warn( `[useJsonSchema] Schema "${id}" not found in registry` );
      return null;
    }
    return config;
  }

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

// QBML Snippets
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
  "whereIn": ["\${2:column}", { "\\$param": "\${1:paramName}" }]
}`,
    documentation: "Conditional filter based on runtime parameter",
    detail: "QBML Param Filter",
  },
  {
    label: "qbml-dataviewer",
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": ["\${2:*}"] },
  {
    "when": { "param": "ids", "notEmpty": true },
    "whereIn": ["id", { "\\$param": "ids" }]
  },
  {
    "when": { "param": "search", "hasValue": true },
    "whereLike": ["name", { "\\$param": "search" }]
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
    insertText: `{ "\\$param": "\${1:paramName}" }`,
    documentation: "Reference a runtime parameter",
    detail: "Parameter Reference",
  },
  {
    label: "$raw",
    insertText: `{ "\\$raw": "\${1:SQL expression}" }`,
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
