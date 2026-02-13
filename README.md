# QBML - Query Builder Markup Language

Turn JSON into secure, multi-platform SQL. Store queries in databases, hydrate them with parameterized data, and execute with table and action allowlists and injection protection. Perfect for report builders, dynamic dashboards, and user-defined data views.

[![ForgeBox](https://forgebox.io/api/v1/entry/qbml/badges/version)](https://forgebox.io/view/qbml)
[![CI](https://github.com/Daemach/qbml/actions/workflows/ci.yml/badge.svg)](https://github.com/Daemach/qbml/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Built on [QueryBuilder (qb)](https://qb.ortusbooks.com/) | [Editor Demo](qbml-editor-quasar/) | [Schema & Types](schemas/)

## Contents

- [30-Second Install](#30-second-install)
- [Features at a Glance](#features-at-a-glance)
- [Configuration](#configuration)
- [Return Formats](#return-formats) — Array, Tabular, Query, Struct
- [QBML Schema Reference](#qbml-schema-reference) — Selects, Wheres, Joins, CTEs, Unions, Subqueries
- [Lock Methods](#lock-methods)
- [Object-Form Arguments](#object-form-arguments)
- [Parameters & Dynamic Queries](#parameters--dynamic-queries)
- [Conditional Actions](#conditional-actions)
- [Executors](#executors)
- [Security](#security)
- [QBML Editor](#qbml-editor) — Monaco + Vue component
- [API Reference](#api-reference)
- [Examples](#examples)
- [Testing & Contributing](#testing--contributing)
- [Credits](#credits)

## 30-Second Install

**Requirements:** Lucee 5.3+ or Adobe ColdFusion 2021+, ColdBox 6+, qb 13+

```bash
box install qbml
```

Point to a config file in `config/ColdBox.cfc` (or pass `{}` for zero-config defaults):

```cfml
moduleSettings = {
    qbml : { configPath : "config.qbml" }
};
```

Inject and run your first query:

```cfml
property name="qbml" inject="QBML@qbml";

var users = qbml.execute([
    { "from": "users" },
    { "select": ["id", "name", "email"] },
    { "where": ["status", "active"] },
    { "orderBy": ["name", "asc"] },
    { "get": true }
]);
```

That's it. QBML defaults to no restrictions and `"array"` return format. See [Configuration](#configuration) for security controls and [Return Formats](#return-formats) for output options.

[Back to top](#qbml---query-builder-markup-language)

## Features at a Glance

| Category | Capabilities |
|----------|-------------|
| **Query Language** | 49 base actions covering all QB select methods, plus object-form arguments |
| **Return Formats** | **Array** (default), **Tabular** (compact + types), **Query** (native CFML), **Struct** (keyed lookups) |
| **Parameters** | `$param` references, string template interpolation (`$name$`), conditional clauses |
| **Security** | Table/action/executor allowlist & blocklist, SQL injection protection, input validation |
| **Advanced SQL** | CTEs, recursive CTEs, subqueries, unions, 7 join types, lock methods |
| **Configuration** | Config file with environment overrides, table aliases, query defaults |
| **Editor** | Monaco-powered Vue component — autocomplete, 50+ snippets, validation, hover docs |
| **Frontend** | Browser detabulator (JS/TS), Quasar QTable integration, TypeScript types |

[Back to top](#qbml---query-builder-markup-language)

## Configuration

QBML supports a dedicated config file (recommended) or inline `moduleSettings` using the same keys.

### Config File (Recommended)

Create `config/qbml.cfc` in your application:

```cfml
component {

    function configure() {
        return {
            // Access control: mode + list. Wildcards supported.
            // mode: "none" (all allowed), "allow" (only list), "block" (all except list)
            tables    : { mode : "none", list : [] },
            // tables : { mode : "allow", list : [ "users", "orders", "reporting.*" ] },
            // tables : { mode : "block", list : [ "sys.*", "*.passwords" ] },

            actions   : { mode : "none", list : [] },
            // actions : { mode : "block", list : [ "*Raw" ] },

            executors : { mode : "none", list : [] },
            // executors : { mode : "allow", list : [ "get", "first", "count", "exists", "paginate" ] },

            // Friendly table aliases
            aliases : {
                // accts : "dbo.tbl_accounts",
                // txns  : "finance.transactions"
            },

            // Query defaults
            defaults : {
                timeout      : 30,
                maxRows      : 10000,
                datasource   : "",
                returnFormat : "array"  // "array", "tabular", "query", or ["struct", "columnKey"]
            },

            // Read-only credentials (optional)
            credentials : {
                username : "",
                password : ""
            },

            debug : false
        };
    }

    // Environment-specific overrides (optional)
    function development() {
        return { debug : true };
    }

    function production() {
        return {
            // tables : { mode : "allow", list : [ "users", "orders", "products" ] }
        };
    }

    function testing() {
        return {
            tables    : { mode : "none", list : [] },
            actions   : { mode : "none", list : [] },
            executors : { mode : "none", list : [] },
            debug     : false
        };
    }

}
```

Then reference it in `config/ColdBox.cfc`:

```cfml
moduleSettings = {
    qbml : { configPath : "config.qbml" }
};
```

### Access Control Modes

Each access control setting (tables, actions, executors) uses a `{ mode, list }` structure:

| Mode | Behavior |
|------|----------|
| `none` | All allowed (empty list ignored) |
| `allow` | Only items matching list patterns allowed |
| `block` | All allowed except items matching list patterns |

Wildcards are supported: `reporting.*`, `*.audit_log`, `*Raw`

### Minimal Configuration (No Restrictions)

For development or trusted environments with no restrictions:

```cfml
moduleSettings = {
    qbml : {}
};
```

[Back to top](#qbml---query-builder-markup-language)

## Return Formats

QBML supports four return formats for `get`, `paginate`, and `simplePaginate`:

| Format | Syntax | Returns | Best For |
|--------|--------|---------|----------|
| **Array** | `"array"` (default) | `[{ id: 1, name: "Alice" }, ...]` | General use |
| **Tabular** | `"tabular"` | `{ columns, rows }` with type metadata | API bandwidth, QTable |
| **Query** | `"query"` | Native CFML query object | Legacy integration |
| **Struct** | `["struct", key]` | `{ "1": { ... }, "2": { ... } }` | Lookups, translation maps |

> All formats accept tuple syntax: `["array"]` is equivalent to `"array"`.
> Struct **requires** tuple syntax since it needs a columnKey parameter.

**Priority Order:** Execute options > Query definition > Config defaults

**Set the default in config:**

```cfml
defaults : {
    returnFormat : "tabular"           // All queries return tabular by default
    // returnFormat : ["struct", "id"] // All queries return struct keyed by id
}
```

**Override per-query:**

```json
{ "get": { "returnFormat": "tabular" } }
{ "get": { "returnFormat": ["struct", "id"] } }
{ "paginate": { "page": 1, "maxRows": 25, "returnFormat": ["struct", "orderId"] } }
```

**Override at runtime:**

```cfml
qbml.execute( query, { returnFormat : "query" } );
qbml.execute( query, { returnFormat : [ "struct", "id" ] } );
```

### Struct Format

Returns results as a struct keyed by a column value — ideal for translation maps,
lookup tables, and master-detail relationships where you need fast key-based access.

**Full rows keyed by id:**

```json
{ "get": { "returnFormat": ["struct", "id"] } }
```

```json
{
  "1": { "id": 1, "username": "alice", "email": "alice@example.com" },
  "2": { "id": 2, "username": "bob", "email": "bob@example.com" }
}
```

**Translation map** — single valueKey returns scalar values:

```json
{ "get": { "returnFormat": ["struct", "code", ["label"]] } }
```

```json
{ "US": "United States", "CA": "Canada", "MX": "Mexico" }
```

**Partial rows** — multiple valueKeys return a subset of columns:

```json
{ "get": { "returnFormat": ["struct", "id", ["username", "email"]] } }
```

```json
{
  "1": { "username": "alice", "email": "alice@example.com" },
  "2": { "username": "bob", "email": "bob@example.com" }
}
```

**With pagination** — `results` is a struct, pagination metadata unchanged:

```json
{ "paginate": { "page": 1, "maxRows": 25, "returnFormat": ["struct", "orderId"] } }
```

```json
{
  "pagination": { "page": 1, "maxRows": 25, "totalRecords": 150, "totalPages": 6 },
  "results": {
    "1001": { "orderId": 1001, "total": 59.99, "status": "shipped" },
    "1002": { "orderId": 1002, "total": 124.50, "status": "pending" }
  }
}
```

> **Duplicate keys:** If multiple rows share the same columnKey value, the last row wins.
> Use a unique column (primary key, code, etc.) for predictable results.
>
> **Validation:** If `columnKey` or any `valueKeys` entry doesn't match a column in the
> result set, a `QBML.InvalidColumnKey` or `QBML.InvalidValueKey` error is thrown with
> a message listing the available columns.

### Tabular Format

Compact columnar format with type metadata — ideal for bandwidth-sensitive APIs and Quasar QTable integration:

```json
{
    "columns": [
        { "name": "id", "type": "integer" },
        { "name": "name", "type": "varchar" },
        { "name": "created_at", "type": "datetime" }
    ],
    "rows": [
        [1, "Alice", "2024-01-15T10:30:00Z"],
        [2, "Bob", "2024-01-16T14:22:00Z"]
    ]
}
```

With pagination:

```json
{
    "pagination": { "page": 1, "maxRows": 25, "totalRecords": 150, "totalPages": 6 },
    "results": { "columns": [...], "rows": [...] }
}
```

**Detected Types:** `integer`, `bigint`, `decimal`, `varchar`, `boolean`, `datetime`, `uuid`, `object`, `array`

For browser-side tabular conversion (detabulate, QTable helpers, TypeScript types), see [schemas/README.md](schemas/README.md).

[Back to top](#qbml---query-builder-markup-language)

## QBML Schema Reference

QBML queries are JSON arrays where each element is an action object:

```json
[
    { "from": "users" },
    { "select": ["id", "name", "email"] },
    { "where": ["status", "active"] },
    { "orderBy": ["name", "asc"] },
    { "limit": 100 },
    { "get": true }
]
```

### Source Actions

```json
{ "from": "tableName" }
{ "from": "tableName alias" }
{ "fromSub": "alias", "query": [...] }
{ "fromRaw": "custom_table_expression" }
```

### Selection Actions

```json
{ "select": ["col1", "col2"] }
{ "select": "*" }
{ "addSelect": ["col3", "col4"] }
{ "distinct": true }
{ "selectRaw": "COUNT(*) as total, SUM(amount) as sum_amount" }
{ "subSelect": "orderCount", "query": [...] }
```

### Where Conditions

```json
// Basic comparisons
{ "where": ["column", "value"] }
{ "where": ["column", "<>", "value"] }
{ "andWhere": ["column", ">", 10] }
{ "orWhere": ["column", "like", "%test%"] }

// IN clauses
{ "whereIn": ["status", ["active", "pending"]] }
{ "whereNotIn": ["status", ["deleted"]] }
{ "orWhereIn": ["type", [1, 2, 3]] }

// BETWEEN
{ "whereBetween": ["amount", 100, 500] }
{ "whereNotBetween": ["date", "2024-01-01", "2024-12-31"] }

// LIKE
{ "whereLike": ["name", "%john%"] }
{ "whereNotLike": ["email", "%spam%"] }

// NULL checks
{ "whereNull": "deleted_at" }
{ "whereNotNull": "verified_at" }

// Column comparisons
{ "whereColumn": ["created_at", "updated_at"] }
{ "whereColumn": ["total", ">", "subtotal"] }

// Raw expressions with bindings
{ "whereRaw": ["YEAR(created_at) = ?", [2024]] }
```

### Nested Where Clauses

Group conditions with parentheses by passing an array of clause objects:

```json
{
    "where": [
        { "where": ["status", "active"] },
        { "orWhere": ["role", "admin"] }
    ]
}
```

Generates: `WHERE (status = 'active' OR role = 'admin')`

### Joins

```json
// Simple joins
{ "join": ["orders", "users.id", "=", "orders.user_id"] }
{ "leftJoin": ["profiles", "users.id", "=", "profiles.user_id"] }
{ "rightJoin": ["departments", "users.dept_id", "=", "departments.id"] }
{ "crossJoin": "statuses" }

// Complex join conditions
{
    "leftJoin": "orders",
    "on": [
        { "on": ["users.id", "=", "orders.user_id"] },
        { "andOn": ["orders.status", "=", "active"] }
    ]
}

// Join with subquery
{
    "joinSub": "recent_orders",
    "query": [
        { "from": "orders" },
        { "where": ["created_at", ">", "2024-01-01"] }
    ],
    "on": [
        { "on": ["users.id", "=", "recent_orders.user_id"] }
    ]
}
```

### Grouping & Having

```json
{ "groupBy": ["status", "type"] }
{ "having": ["count", ">", 5] }
{ "havingRaw": ["SUM(amount) > ?", [1000]] }
```

### Ordering

```json
{ "orderBy": ["name", "asc"] }
{ "orderBy": "name" }                         // Defaults to "asc"
{ "orderByDesc": "created_at" }
{ "orderByAsc": "id" }
{ "orderByRaw": "FIELD(status, 'pending', 'active', 'closed')" }
{ "reorder": true }                           // Clear previous orders
```

### Limiting & Pagination

```json
{ "limit": 100 }
{ "offset": 50 }
{ "forPage": [2, 25] }                        // Page 2, 25 per page
```

### CTEs (Common Table Expressions)

```json
[
    {
        "with": "active_users",
        "query": [
            { "from": "users" },
            { "where": ["status", "active"] }
        ]
    },
    { "from": "active_users" },
    { "select": ["*"] },
    { "get": true }
]
```

Chain multiple CTEs by adding more `with` actions — each can reference previously defined CTEs.

### Unions

```json
[
    { "from": "customers" },
    { "select": ["name", "email"] },
    {
        "union": true,
        "query": [
            { "from": "suppliers" },
            { "select": ["name", "email"] }
        ]
    },
    { "get": true }
]
```

### Subqueries

```json
// EXISTS
{
    "whereExists": true,
    "query": [
        { "from": "orders" },
        { "whereColumn": ["orders.user_id", "users.id"] }
    ]
}

// Scalar subquery in SELECT
{
    "subSelect": "order_count",
    "query": [
        { "from": "orders" },
        { "selectRaw": "COUNT(*)" },
        { "whereColumn": ["orders.user_id", "users.id"] }
    ]
}

// Derived table (FROM subquery)
{
    "fromSub": "recent_orders",
    "query": [
        { "from": "orders" },
        { "where": ["created_at", ">", "2024-01-01"] }
    ]
}
```

[Back to top](#qbml---query-builder-markup-language)

## Lock Methods

Control row-level locking for transactional queries:

```json
{ "lockForUpdate": true }
{ "sharedLock": true }
{ "noLock": true }
{ "clearLock": true }
{ "lock": "custom_lock_expression" }
```

`lockForUpdate` accepts an optional boolean for `skipLocked`:

```json
{ "lockForUpdate": true }                     // Default (no skip)
{ "lockForUpdate": false }                    // skipLocked = false
```

[Back to top](#qbml---query-builder-markup-language)

## Object-Form Arguments

As an alternative to positional arrays, use named keys for readability:

```json
// Array form
{ "where": ["status", "=", "active"] }

// Object form (equivalent)
{ "where": { "column": "status", "operator": "=", "value": "active" } }
```

Object form works with all combinator prefixes (`and`/`or`) and negation (`not`) variants.

| Action | Object Keys |
|--------|------------|
| `where` | `{ column, operator?, value }` |
| `whereIn` | `{ column, values }` |
| `whereBetween` | `{ column, start, end }` |
| `whereLike` | `{ column, value }` |
| `whereNull` | `{ column }` |
| `whereColumn` | `{ first, operator?, second }` |
| `join` | `{ table, first, operator?, second }` |
| `orderBy` | `{ column, direction? }` |
| `having` | `{ column, operator?, value }` |
| `forPage` | `{ page, size }` |
| `limit` / `offset` | `{ value }` |
| `select` / `groupBy` | `{ columns }` or `{ column }` |
| `from` | `{ table }` or `{ name }` |
| `*Raw` | `{ sql, bindings? }` |

Example with joins and ordering:

```json
[
    { "from": { "table": "users" } },
    { "leftJoin": { "table": "orders", "first": "users.id", "operator": "=", "second": "orders.user_id" } },
    { "where": { "column": "status", "value": "active" } },
    { "orderBy": { "column": "name", "direction": "asc" } },
    { "get": true }
]
```

[Back to top](#qbml---query-builder-markup-language)

## Parameters & Dynamic Queries

QBML supports runtime parameters that enable dynamic query building without string interpolation. This is especially useful for dataviewer-style applications where queries are stored in a database and parameters are injected at execution time.

### $param Reference

Use `{ "$param": "paramName" }` to reference a parameter value anywhere in your query:

```cfml
var query = [
    { "from": "users" },
    { "select": ["id", "name", "email"] },
    { "whereIn": ["accountID", { "$param": "accountIDs" }] },
    { "get": true }
];

var results = qbml.execute( query, { params: { accountIDs: [1, 2, 3] } } );
```

Works in any value position:

```json
{ "whereIn": ["status", { "$param": "statuses" }] }
{ "where": ["accountID", { "$param": "accountID" }] }
{ "whereBetween": ["orderDate", { "$param": "startDate" }, { "$param": "endDate" }] }
```

### String Template Interpolation

For LIKE patterns and string composition, use `$paramName$` syntax to embed values directly in strings:

```json
{ "whereLike": ["name", "%$filter$%"] }
{ "whereLike": ["email", "$domain$%"] }
{ "where": ["sku", "like", "$category$-$year$-%"] }
```

```cfml
qbml.execute( query, { params: { filter: "john" } } );
// Generates: WHERE name LIKE '%john%'

qbml.execute( query, { params: { category: "ELEC", year: "2024" } } );
// Generates: WHERE sku LIKE 'ELEC-2024-%'
```

**Note:** Only simple values (strings, numbers) are interpolated. Arrays and structs are left unchanged. Missing params leave the `$paramName$` placeholder in place.

### Param-Based Conditions

The real power comes from combining `$param` with `when` conditions. Skip clauses entirely when parameters are empty:

```json
{
    "when": { "param": "accountIDs", "notEmpty": true },
    "whereIn": ["accountID", { "$param": "accountIDs" }]
}
```

If `accountIDs` is empty, the entire `whereIn` clause is skipped — no `WHERE 0 = 1`!

### Param Condition Types

| Condition | Description |
|-----------|-------------|
| `{ "param": "name", "notEmpty": true }` | True if param is not empty array/string |
| `{ "param": "name", "isEmpty": true }` | True if param is empty or missing |
| `{ "param": "name", "hasValue": true }` | True if param exists with any value |
| `{ "param": "name", "gt": value }` | param > value |
| `{ "param": "name", "gte": value }` | param >= value |
| `{ "param": "name", "lt": value }` | param < value |
| `{ "param": "name", "lte": value }` | param <= value |
| `{ "param": "name", "eq": value }` | param == value |
| `{ "param": "name", "neq": value }` | param != value |

### Complex Dataviewer Example

Store this query in your database and execute with any combination of filters:

```json
[
    { "from": "transactions" },
    { "select": ["id", "amount", "type", "accountID", "transactionDate"] },
    {
        "when": { "param": "accountIDs", "notEmpty": true },
        "whereIn": ["accountID", { "$param": "accountIDs" }]
    },
    {
        "when": {
            "and": [
                { "param": "startDate", "hasValue": true },
                { "param": "endDate", "hasValue": true }
            ]
        },
        "whereBetween": ["transactionDate", { "$param": "startDate" }, { "$param": "endDate" }]
    },
    {
        "when": { "param": "minAmount", "gt": 0 },
        "where": ["amount", ">=", { "$param": "minAmount" }]
    },
    {
        "when": { "param": "types", "notEmpty": true },
        "whereIn": ["type", { "$param": "types" }]
    },
    { "orderByDesc": "transactionDate" },
    { "paginate": { "page": 1, "maxRows": 100 } }
]
```

```cfml
// All filters
var results = qbml.execute( storedQuery, {
    params: {
        accountIDs: [1, 2, 3],
        startDate: "2024-01-01",
        endDate: "2024-12-31",
        minAmount: 100,
        types: ["credit", "debit"]
    }
});

// No filters — returns all transactions
var results = qbml.execute( storedQuery, { params: {} });
```

[Back to top](#qbml---query-builder-markup-language)

## Conditional Actions

Apply actions conditionally based on runtime data:

```json
{
    "when": "hasValues",
    "whereIn": ["status", ["active", "pending"]]
}
```

If the array is empty, the `whereIn` is skipped entirely (no `WHERE 0 = 1`).

### Condition Types

| Condition | Description |
|-----------|-------------|
| `"hasValues"` / `"notEmpty"` | True if any array argument is not empty |
| `"isEmpty"` | True if any array argument IS empty |
| `{ "notEmpty": 2 }` | Check specific arg index (1-based) |
| `{ "gt": [1, 5] }` | args[1] > 5 |
| `{ "gte": [1, 5] }` | args[1] >= 5 |
| `{ "lt": [1, 5] }` | args[1] < 5 |
| `{ "lte": [1, 5] }` | args[1] <= 5 |
| `{ "eq": [1, "value"] }` | args[1] == "value" |
| `{ "neq": [1, "value"] }` | args[1] != "value" |
| `{ "and": [...] }` | All conditions must be true |
| `{ "or": [...] }` | Any condition must be true |
| `{ "not": condition }` | Negate the condition |

### Else Clause

```json
{
    "when": "hasValues",
    "whereIn": ["accountID", []],
    "else": { "where": ["status", "active"] }
}
```

[Back to top](#qbml---query-builder-markup-language)

## Executors

Executors determine how the query runs and what it returns:

```json
{ "get": true }                               // Array of structs
{ "first": true }                             // Single struct or null
{ "find": [123] }                             // Find by ID
{ "find": [123, "user_id"] }                  // Find by custom column
{ "value": "name" }                           // Single column value
{ "values": "id" }                            // Array of single column values
{ "count": true }                             // Count of rows
{ "count": "id" }                             // Count of specific column
{ "sum": "amount" }                           // Sum of column
{ "avg": "price" }                            // Average of column
{ "min": "created_at" }                       // Minimum value
{ "max": "updated_at" }                       // Maximum value
{ "exists": true }                            // Boolean exists check
{ "paginate": { "page": 1, "maxRows": 25 } }  // Paginated results
{ "simplePaginate": { "page": 1, "maxRows": 25 } }  // Simple pagination (no count)
{ "toSQL": true }                             // SQL string (no execution)
```

### Executor Options

Pass execution options with the executor:

```json
{
    "get": true,
    "datasource": "reporting",
    "timeout": 60
}
```

Return format can also be set per-executor — see [Return Formats](#return-formats).

[Back to top](#qbml---query-builder-markup-language)

## Security

QBML includes multiple security layers:

### Table Access Control

- **Allowlist mode**: Only explicitly listed tables are accessible
- **Blocklist mode**: All tables except those listed are accessible
- Wildcard patterns: `"reporting.*"`, `"*.audit_log"`
- Table aliases automatically resolved and validated

### SQL Injection Protection

- Raw expressions validated against dangerous patterns
- Blocks: `DROP`, `DELETE`, `TRUNCATE`, `INSERT`, `UPDATE`, `EXEC`, `--`, `/*`, `xp_`, `WAITFOR`, etc.
- All values parameterized through QB

### Input Validation

- Table and column names validated
- CTE aliases automatically allowed in their query scope
- Subqueries recursively validated

[Back to top](#qbml---query-builder-markup-language)

## QBML Editor

QBML includes a production-ready Monaco-powered JSON editor component for Vue 3 / Quasar. Schema-driven autocomplete, 50+ snippets, real-time validation, and pinnable hover tooltips with qb documentation links.

- **Autocomplete** — schema-driven suggestions for all QBML actions and their arguments
- **50+ Snippets** — full query templates and individual clauses, organized by category in a toolbar dropdown
- **Real-time Validation** — JSON Schema validation with clickable error navigation
- **Pinnable Hover Tooltips** — rich markdown with code examples and links to qb docs
- **Toolbar** — undo/redo, format, compact, sort keys, expand/collapse all
- **Progressive Enhancement** — works as a generic JSON editor, enhanced with QBML schema
- **v-model + Events** — string v-model, `validation` and `ready` events, exposed methods

### Minimal Integration

```vue
<template>
  <MonacoJsonEditor
    v-model="query"
    v-bind="getEditorProps('qbml')"
    title="QBML Query"
    height="500px"
  />
</template>

<script setup>
import { ref } from "vue";
import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
import { useJsonSchema } from "src/composables/useJsonSchema";

const { getEditorProps } = useJsonSchema();
const query = ref('[\n  { "from": "users" },\n  { "select": ["*"] },\n  { "get": true }\n]');
</script>
```

Full documentation: [schemas/README.md](schemas/README.md) | Demo app: [qbml-editor-quasar/](qbml-editor-quasar/)

[Back to top](#qbml---query-builder-markup-language)

## API Reference

### QBML Service

```cfml
// Inject
property name="qbml" inject="QBML@qbml";

// Execute a query
var results = qbml.execute( queryArray, options );

// Execute with parameters
var results = qbml.execute( queryArray, {
    params: { accountIDs: [1, 2, 3], status: "active" }
});

// Build without executing (returns QB instance)
var qbInstance = qbml.build( queryArray );

// Build with parameters
var qbInstance = qbml.build( queryArray, { accountIDs: [1, 2, 3] } );

// Get SQL string
var sql = qbml.toSQL( queryArray );

// Get SQL string with parameters resolved
var sql = qbml.toSQL( queryArray, { accountIDs: [1, 2, 3] } );

// Resolve $param references in a value (utility method)
var resolved = qbml.resolveParamRefs( value, params );
```

For the ReturnFormat service API, browser-side detabulator functions, and QTable helpers, see [schemas/README.md](schemas/README.md).

[Back to top](#qbml---query-builder-markup-language)

## Examples

### Dynamic Report Builder

```cfml
function buildReport( required struct filters ) {
    var query = [
        { "from": "orders o" },
        { "leftJoin": ["customers c", "o.customer_id", "=", "c.id"] },
        { "select": ["o.id", "o.total", "c.name as customer_name", "o.created_at"] }
    ];

    // Add filters conditionally
    if ( len( filters.status ?: "" ) ) {
        query.append( { "where": ["o.status", filters.status] } );
    }

    if ( len( filters.startDate ?: "" ) ) {
        query.append( { "where": ["o.created_at", ">=", filters.startDate] } );
    }

    if ( len( filters.endDate ?: "" ) ) {
        query.append( { "where": ["o.created_at", "<=", filters.endDate] } );
    }

    query.append( { "orderByDesc": "o.created_at" } );
    query.append( { "paginate": { "page": filters.page ?: 1, "maxRows": 50 } } );

    return qbml.execute( query );
}
```

### Stored Query Execution

```cfml
// Query stored in database
var storedQuery = deserializeJSON( queryRecord.definition );

// Execute with runtime parameters merged
storedQuery.append( { "where": ["tenant_id", currentTenantID] } );

return qbml.execute( storedQuery );
```

### API Endpoint with Tabular Response

```cfml
function list( event, rc, prc ) {
    var query = [
        { "from": "products" },
        { "select": ["id", "name", "price", "stock"] },
        { "where": ["is_active", 1] },
        { "orderBy": ["name", "asc"] },
        { "paginate": {
            "page": rc.page ?: 1,
            "maxRows": 100,
            "returnFormat": "tabular"
        } }
    ];

    return qbml.execute( query );
}
```

### Pagination with Parameters

```cfml
var paged = qbml.execute([
    { "from": "orders" },
    { "select": ["id", "total", "created_at"] },
    { "paginate": { "page": 1, "maxRows": 25 } }
]);

// Get SQL without executing
var sql = qbml.toSQL([
    { "from": "users" },
    { "where": ["role", "admin"] }
]);
```

[Back to top](#qbml---query-builder-markup-language)

## Testing & Contributing

```bash
# Install dependencies
box install

# Run tests
box testbox run
```

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

### Powered by Ortus Solutions

<a href="https://www.ortussolutions.com">
    <img src="https://www.ortussolutions.com/__media/ortus-logo-full-color.svg" alt="Ortus Solutions" width="200">
</a>

QBML is built on top of the excellent [QueryBuilder (qb)](https://qb.ortusbooks.com/) module created by [Eric Peterson](https://github.com/elpete) at [Ortus Solutions](https://www.ortussolutions.com).

**Key Ortus Tools Used:**

- [qb](https://qb.ortusbooks.com/) - Fluent query builder for CFML (by Eric Peterson)
- [TestBox](https://testbox.ortusbooks.com/) - BDD/TDD testing framework
- [CommandBox](https://commandbox.ortusbooks.com/) - CLI and package manager

Created by John Wilson

---

*Soli Deo Gloria*
