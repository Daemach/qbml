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
    version: config.version || "",
    githubRepo: config.githubRepo || "",
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
      version: config.version,
      githubRepo: config.githubRepo,
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

// QBML Snippets — toolbar dropdown items
// Grouped by qb docs sections. Focus on patterns that need help — not trivial one-liners.
export const qbmlSnippets = [
  // ── Query Templates ───────────────────────────────────────────────
  {
    label: "Basic SELECT",
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": ["\${2:*}"] },
  { "get": true }
]`,
    documentation: "from → select → get",
    detail: "Query Templates",
  },
  {
    label: "Filtered + Paginated",
    insertText: `[
  { "from": "\${1:tableName}" },
  { "select": ["\${2:*}"] },
  {
    "when": { "param": "\${3:search}", "notEmpty": true },
    "whereLike": ["\${4:name}", { "\\$param": "\${3:search}" }]
  },
  { "orderByDesc": "\${5:created_at}" },
  { "paginate": { "page": 1, "maxRows": 25 } }
]`,
    documentation: "Searchable paginated query with conditional filter",
    detail: "Query Templates",
  },
  {
    label: "Join Query",
    insertText: `[
  { "from": "\${1:users} u" },
  { "leftJoin": ["\${2:orders} o", "u.id", "=", "o.\${3:user_id}"] },
  { "select": ["u.*", "o.\${4:total}"] },
  { "get": true }
]`,
    documentation: "LEFT JOIN with aliased tables",
    detail: "Query Templates",
  },
  {
    label: "Multi-Join Query",
    insertText: `[
  { "from": "\${1:users} u" },
  { "leftJoin": ["\${2:orders} o", "u.id", "=", "o.user_id"] },
  { "leftJoin": ["\${3:order_items} oi", "o.id", "=", "oi.order_id"] },
  { "select": ["u.name", "o.id AS order_id", "oi.product_name", "oi.quantity"] },
  { "get": true }
]`,
    documentation: "Multiple LEFT JOINs across 3 tables",
    detail: "Query Templates",
  },
  {
    label: "CTE Query",
    insertText: `[
  {
    "with": "\${1:filtered}",
    "query": [
      { "from": "\${2:tableName}" },
      { "where": ["\${3:status}", "\${4:active}"] }
    ]
  },
  { "from": "\${1:filtered}" },
  { "select": ["*"] },
  { "orderByDesc": "\${5:created_at}" },
  { "paginate": { "page": 1, "maxRows": 25 } }
]`,
    documentation: "CTE: filter in WITH, paginate from result",
    detail: "Query Templates",
  },
  {
    label: "CTE + Join + Aggregation",
    insertText: `[
  {
    "with": "order_totals",
    "query": [
      { "from": "orders" },
      { "select": ["user_id"] },
      { "selectRaw": "SUM(total) AS total_spent" },
      { "selectRaw": "COUNT(*) AS order_count" },
      { "groupBy": "user_id" }
    ]
  },
  { "from": "users u" },
  { "leftJoin": ["order_totals ot", "u.id", "=", "ot.user_id"] },
  { "select": ["u.name", "u.email", "ot.total_spent", "ot.order_count"] },
  { "orderByDesc": "ot.total_spent" },
  { "get": true }
]`,
    documentation: "CTE with aggregation joined to main table",
    detail: "Query Templates",
  },
  {
    label: "Subquery in WHERE",
    insertText: `[
  { "from": "\${1:users}" },
  { "select": ["*"] },
  {
    "whereExists": true,
    "query": [
      { "from": "\${2:orders}" },
      { "whereColumn": ["\${2:orders}.user_id", "=", "\${1:users}.id"] }
    ]
  },
  { "get": true }
]`,
    documentation: "WHERE EXISTS with correlated subquery",
    detail: "Query Templates",
  },
  {
    label: "Union Query",
    insertText: `[
  { "from": "\${1:active_users}" },
  { "select": ["\${2:id}", "\${3:name}", "\${4:email}"] },
  {
    "union": true,
    "query": [
      { "from": "\${5:archived_users}" },
      { "select": ["\${2:id}", "\${3:name}", "\${4:email}"] }
    ]
  },
  { "orderBy": ["\${3:name}", "asc"] },
  { "get": true }
]`,
    documentation: "Combine two tables with UNION",
    detail: "Query Templates",
  },
  {
    label: "Dataviewer",
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
    documentation: "Multi-select, search, tabular pagination",
    detail: "Query Templates",
  },

  // ── Inserts, Updates & Deletes ────────────────────────────────────
  {
    label: "Insert Row",
    insertText: `[
  { "table": "\${1:tableName}" },
  { "insert": {
    "\${2:name}": { "\\$param": "\${2:name}" },
    "\${3:email}": { "\\$param": "\${3:email}" }
  } }
]`,
    documentation: "Insert single row with $param values",
    detail: "Inserts, Updates & Deletes",
  },
  {
    label: "Batch Insert",
    insertText: `[
  { "table": "\${1:tableName}" },
  { "insert": [
    { "\${2:name}": "John", "\${3:email}": "john@test.com" },
    { "\${2:name}": "Jane", "\${3:email}": "jane@test.com" }
  ] }
]`,
    documentation: "Insert multiple rows in one SQL call",
    detail: "Inserts, Updates & Deletes",
  },
  {
    label: "Update with WHERE",
    insertText: `[
  { "table": "\${1:tableName}" },
  { "where": ["\${2:id}", { "\\$param": "\${2:id}" }] },
  { "update": {
    "\${3:name}": { "\\$param": "\${3:name}" },
    "\${4:email}": { "\\$param": "\${4:email}" }
  } }
]`,
    documentation: "Update matching rows by parameter",
    detail: "Inserts, Updates & Deletes",
  },
  {
    label: "Update with Join",
    insertText: `[
  { "table": "\${1:orders} o" },
  { "join": ["\${2:users} u", "o.user_id", "=", "u.id"] },
  { "where": ["u.\${3:status}", "\${4:inactive}"] },
  { "update": {
    "o.\${5:archived}": true
  } }
]`,
    documentation: "Update rows via joined table condition",
    detail: "Inserts, Updates & Deletes",
  },
  {
    label: "Conditional Update (addUpdate)",
    insertText: `[
  { "table": "\${1:tableName}" },
  { "where": ["id", { "\\$param": "id" }] },
  { "addUpdate": { "\${2:name}": { "\\$param": "\${2:name}" } } },
  {
    "when": { "param": "\${3:email}", "notEmpty": true },
    "addUpdate": { "\${3:email}": { "\\$param": "\${3:email}" } }
  },
  { "update": {} }
]`,
    documentation: "Conditionally include update columns with when + addUpdate",
    detail: "Inserts, Updates & Deletes",
  },
  {
    label: "Delete with WHERE",
    insertText: `[
  { "table": "\${1:tableName}" },
  { "where": ["\${2:status}", "\${3:inactive}"] },
  { "delete": true }
]`,
    documentation: "Delete matching rows",
    detail: "Inserts, Updates & Deletes",
  },
  {
    label: "Upsert",
    insertText: `[
  { "table": "\${1:tableName}" },
  { "upsert": {
    "values": [
      { "\${2:username}": "johndoe", "\${3:active}": 1, "modifiedDate": { "\\$raw": "NOW()" } },
      { "\${2:username}": "janedoe", "\${3:active}": 1, "modifiedDate": { "\\$raw": "NOW()" } }
    ],
    "target": ["\${2:username}"],
    "update": ["\${3:active}", "modifiedDate"]
  } }
]`,
    documentation: "Insert or update on conflict (requires unique/PK target)",
    detail: "Inserts, Updates & Deletes",
  },
  {
    label: "Insert from Subquery",
    insertText: `[
  { "table": "\${1:archive_users}" },
  {
    "insertUsing": { "columns": ["\${2:id}", "\${3:name}", "\${4:email}"] },
    "query": [
      { "from": "\${5:users}" },
      { "select": ["\${2:id}", "\${3:name}", "\${4:email}"] },
      { "where": ["\${6:active}", false] }
    ]
  }
]`,
    documentation: "Insert rows from a subquery (INSERT INTO ... SELECT)",
    detail: "Inserts, Updates & Deletes",
  },

  // ── Wheres ────────────────────────────────────────────────────────
  {
    label: "where ($param)",
    insertText: `{ "where": ["\${1:column}", { "\\$param": "\${2:paramName}" }] }`,
    documentation: "WHERE column = runtime parameter",
    detail: "Wheres",
  },
  {
    label: "where (operator)",
    insertText: `{ "where": ["\${1:column}", "\${2:>}", \${3:0}] }`,
    documentation: "WHERE column > value (any operator)",
    detail: "Wheres",
  },
  {
    label: "whereIn ($param)",
    insertText: `{ "whereIn": ["\${1:column}", { "\\$param": "\${2:paramName}" }] }`,
    documentation: "WHERE column IN (runtime parameter array)",
    detail: "Wheres",
  },
  {
    label: "whereBetween",
    insertText: `{ "whereBetween": ["\${1:column}", "\${2:start}", "\${3:end}"] }`,
    documentation: "WHERE column BETWEEN start AND end",
    detail: "Wheres",
  },
  {
    label: "whereExists + query",
    insertText: `{
  "whereExists": true,
  "query": [
    { "from": "\${1:tableName}" },
    { "whereColumn": ["\${2:inner.id}", "=", "\${3:outer.id}"] }
  ]
}`,
    documentation: "WHERE EXISTS (correlated subquery)",
    detail: "Wheres",
  },
  {
    label: "whereRaw",
    insertText: `{ "whereRaw": "\${1:SQL expression}" }`,
    documentation: "WHERE with raw SQL",
    detail: "Wheres",
  },
  {
    label: "where (group)",
    insertText: `{
  "where": [
    { "where": ["\${1:status}", "\${2:active}"] },
    { "orWhere": ["\${3:role}", "\${4:admin}"] }
  ]
}`,
    documentation: "Grouped WHERE — (a = ? OR b = ?)",
    detail: "Wheres",
  },

  // ── Joins ─────────────────────────────────────────────────────────
  {
    label: "leftJoin",
    insertText: `{ "leftJoin": ["\${1:table} \${2:t}", "\${3:a.id}", "=", "\${2:t}.\${4:a_id}"] }`,
    documentation: "LEFT JOIN table ON condition",
    detail: "Joins",
  },
  {
    label: "join (inner)",
    insertText: `{ "join": ["\${1:table} \${2:t}", "\${3:a.id}", "=", "\${2:t}.\${4:a_id}"] }`,
    documentation: "INNER JOIN table ON condition",
    detail: "Joins",
  },
  {
    label: "leftJoin + on",
    insertText: `{
  "leftJoin": "\${1:orders}",
  "on": [
    { "on": ["\${2:users}.id", "=", "\${1:orders}.\${3:user_id}"] },
    { "andOn": ["\${1:orders}.\${4:status}", "=", "\${5:active}"] }
  ]
}`,
    documentation: "LEFT JOIN with multiple ON conditions",
    detail: "Joins",
  },
  {
    label: "joinSub + query",
    insertText: `{
  "joinSub": "\${1:subAlias}",
  "query": [
    { "from": "\${2:tableName}" },
    { "select": ["\${3:*}"] },
    { "where": ["\${4:column}", "\${5:value}"] }
  ]
}`,
    documentation: "JOIN against a subquery (derived table)",
    detail: "Joins",
  },

  // ── Ordering, Grouping & Limit ────────────────────────────────────
  {
    label: "orderByRaw",
    insertText: `{ "orderByRaw": "\${1:FIELD(status, 'active', 'pending', 'closed')}" }`,
    documentation: "ORDER BY with raw SQL expression",
    detail: "Ordering, Grouping & Limit",
  },
  {
    label: "groupBy + having",
    insertText: `{ "groupBy": "\${1:column}" },
{ "having": ["\${2:total}", "\${3:>}", \${4:0}] }`,
    documentation: "GROUP BY with HAVING filter",
    detail: "Ordering, Grouping & Limit",
  },
  {
    label: "paginate (tabular)",
    insertText: `{ "paginate": { "page": \${1:1}, "maxRows": \${2:25}, "returnFormat": "tabular" } }`,
    documentation: "Paginate with tabular format (columns + data arrays)",
    detail: "Ordering, Grouping & Limit",
  },

  // ── Common Table Expressions ──────────────────────────────────────
  {
    label: "with (CTE)",
    insertText: `{
  "with": "\${1:cteName}",
  "query": [
    { "from": "\${2:tableName}" },
    { "where": ["\${3:column}", "\${4:value}"] }
  ]
}`,
    documentation: "Common Table Expression (WITH clause)",
    detail: "Common Table Expressions",
  },
  {
    label: "withRecursive",
    insertText: `{
  "withRecursive": "\${1:hierarchy}",
  "query": [
    { "from": "\${2:categories}" },
    { "where": ["\${3:parent_id}", null] }
  ]
}`,
    documentation: "Recursive CTE (e.g. tree structures)",
    detail: "Common Table Expressions",
  },

  // ── Unions ────────────────────────────────────────────────────────
  {
    label: "union + query",
    insertText: `{
  "union": true,
  "query": [
    { "from": "\${1:tableName}" },
    { "select": ["\${2:*}"] }
  ]
}`,
    documentation: "UNION result sets (removes duplicates)",
    detail: "Unions",
  },

  // ── When (Conditional) ────────────────────────────────────────────
  {
    label: "when + where",
    insertText: `{
  "when": { "param": "\${1:paramName}", "notEmpty": true },
  "where": ["\${2:column}", { "\\$param": "\${1:paramName}" }]
}`,
    documentation: "Conditional WHERE when parameter has value",
    detail: "When (Conditional)",
  },
  {
    label: "when + whereLike",
    insertText: `{
  "when": { "param": "\${1:search}", "notEmpty": true },
  "whereLike": ["\${2:name}", { "\\$param": "\${1:search}" }]
}`,
    documentation: "Conditional LIKE search",
    detail: "When (Conditional)",
  },
  {
    label: "when + whereIn",
    insertText: `{
  "when": { "param": "\${1:paramName}", "notEmpty": true },
  "whereIn": ["\${2:column}", { "\\$param": "\${1:paramName}" }]
}`,
    documentation: "Conditional WHERE IN",
    detail: "When (Conditional)",
  },
  {
    label: "when + orderByDesc",
    insertText: `{
  "when": { "param": "\${1:sortDesc}", "hasValue": true },
  "orderByDesc": "\${2:created_at}"
}`,
    documentation: "Conditional descending sort when parameter is present",
    detail: "When (Conditional)",
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
    version: "1.1.5",
    githubRepo: "Daemach/qbml",
  } );
}

export default useJsonSchema;
