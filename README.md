# QBML - Query Builder Markup Language

A ColdBox module that translates JSON query definitions into [qb](https://qb.ortusbooks.com/) queries. Store queries in databases, build them dynamically from client data, and execute with security controls.

[![ForgeBox](https://forgebox.io/api/v1/entry/qbml/badges/version)](https://forgebox.io/view/qbml)
[![CI](https://github.com/Daemach/qbml/actions/workflows/ci.yml/badge.svg)](https://github.com/Daemach/qbml/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **JSON-based Query Language** - Define queries as portable JSON structures
- **Full QB Support** - All QB query builder methods available
- **Security First** - Table allowlist/blocklist, SQL injection protection
- **Conditional Logic** - Apply query parts based on runtime conditions
- **Tabular Format** - Compact result format with type metadata
- **CTEs & Subqueries** - Full support for complex query patterns

## Requirements

- Lucee 5.3+ or Adobe ColdFusion 2021+
- ColdBox 6+
- qb 13+

## Installation

### ForgeBox (Recommended)

```bash
box install qbml
```

### Manual Installation

1. Download or clone this repository
2. Place in your `modules` directory
3. Run `box install` to install dependencies

## Quick Start

```cfml
// Inject the service
property name="qbml" inject="QBML@qbml";

// Execute a simple query
var users = qbml.execute([
    { "from": "users" },
    { "select": ["id", "name", "email"] },
    { "where": ["status", "active"] },
    { "orderBy": ["name", "asc"] },
    { "get": true }
]);

// With pagination
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

## Configuration

QBML supports two configuration methods: a dedicated config file (recommended) or inline moduleSettings.

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
                returnFormat : "array"  // "array" or "tabular"
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

### Inline Configuration

Alternatively, configure directly in `config/ColdBox.cfc`:

```cfml
moduleSettings = {
    qbml : {
        tables    : { mode : "none", list : [] },
        actions   : { mode : "none", list : [] },
        executors : { mode : "none", list : [] },
        aliases   : {},
        defaults  : { timeout : 30, maxRows : 10000, datasource : "", returnFormat : "array" },
        credentials : { username : "", password : "" },
        debug     : false
    }
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
    qbml : { configPath : "config.qbml" }
};

// Or inline (defaults to mode: "none" for all)
moduleSettings = {
    qbml : {}
};
```

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

Multiple CTEs:

```json
[
    {
        "with": "managers",
        "query": [
            { "from": "users" },
            { "whereIn": ["role", ["admin", "manager"]] }
        ]
    },
    {
        "with": "active_managers",
        "query": [
            { "from": "managers" },
            { "where": ["status", "active"] }
        ]
    },
    { "from": "active_managers" },
    { "get": true }
]
```

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

## Parameters

QBML supports runtime parameters that enable dynamic query building without string interpolation. This is especially useful for dataviewer-style applications where queries are stored in a database and parameters are injected at execution time.

### Basic Usage

Pass parameters via the `options.params` argument:

```cfml
var query = [
    { "from": "users" },
    { "select": ["id", "name", "email"] },
    { "whereIn": ["accountID", { "$param": "accountIDs" }] },
    { "get": true }
];

var results = qbml.execute( query, { params: { accountIDs: [1, 2, 3] } } );
```

### $param Reference

Use `{ "$param": "paramName" }` to reference a parameter value anywhere in your query:

```json
{ "whereIn": ["status", { "$param": "statuses" }] }
{ "where": ["accountID", { "$param": "accountID" }] }
{ "whereBetween": ["orderDate", { "$param": "startDate" }, { "$param": "endDate" }] }
```

### Param-Based Conditions

The real power comes from combining `$param` with `when` conditions. This lets you skip clauses entirely when parameters are empty:

```json
{
    "when": { "param": "accountIDs", "notEmpty": true },
    "whereIn": ["accountID", { "$param": "accountIDs" }]
}
```

If `accountIDs` is empty, the entire `whereIn` clause is skipped—no `WHERE 0 = 1`!

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

Store this query in your database:

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

Execute with parameters:

```cfml
var results = qbml.execute( storedQuery, {
    params: {
        accountIDs: [1, 2, 3],
        startDate: "2024-01-01",
        endDate: "2024-12-31",
        minAmount: 100,
        types: ["credit", "debit"]
    }
});
```

Only the clauses whose conditions pass will be included. Pass empty params to skip filters entirely:

```cfml
// No filters - returns all transactions
var results = qbml.execute( storedQuery, { params: {} });
```

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

### Tabular Return Format

For `get` and `paginate`, you can request tabular format - a compact structure with column metadata.

**Setting the Default Format:**

Configure globally in your `config/qbml.cfc`:

```cfml
defaults : {
    returnFormat : "tabular"  // All queries return tabular by default
}
```

**Priority Order:** Execute options > Query definition > Config defaults

**Per-Query Override:**

```json
{ "get": { "returnFormat": "tabular" } }
{ "paginate": { "page": 1, "maxRows": 25, "returnFormat": "tabular" } }
```

**Runtime Override:**

```cfml
// Override config default at execution time
qbml.execute( query, { returnFormat : "array" } );
```

Tabular format returns:

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

For pagination with tabular format:

```json
{
    "pagination": {
        "page": 1,
        "maxRows": 25,
        "totalRecords": 150,
        "totalPages": 6
    },
    "results": {
        "columns": [...],
        "rows": [...]
    }
}
```

**Detected Types**: `integer`, `bigint`, `decimal`, `varchar`, `boolean`, `datetime`, `uuid`, `object`, `array`

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

### Tabular Service

```cfml
// Inject
property name="tabular" inject="Tabular@qbml";

// Convert array of structs to tabular format
var result = tabular.fromArray( data );

// Convert query object to tabular format
var result = tabular.fromQuery( queryObject );

// Transform pagination result to tabular format
var result = tabular.fromPagination( paginationResult, "results" );

// Decompress tabular back to array of structs
var data = tabular.toArray( tabularData );
```

### Browser-Side Detabulator (JavaScript/TypeScript)

For frontend applications, QBML provides browser-side utilities to convert tabular format back to arrays. This is useful when your API returns tabular format for bandwidth efficiency, but your UI components expect arrays of objects.

**Installation:**

Copy `schemas/tabular.js` or `schemas/tabular.ts` to your frontend project.

**TypeScript Usage:**

```typescript
import { detabulate, detabulatePagination, isTabular } from './tabular';

// API returns tabular format
const response = await fetch('/api/users');
const data = await response.json();

// Check format and convert if needed
if (isTabular(data)) {
    const users = detabulate(data);
    // users = [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }]
}

// For pagination results
const paginatedResponse = await fetch('/api/users?page=1');
const paginatedData = await paginatedResponse.json();

if (isTabularPagination(paginatedData)) {
    const result = detabulatePagination(paginatedData);
    // result.pagination = { page: 1, maxRows: 25, totalRecords: 100, totalPages: 4 }
    // result.results = [{ id: 1, name: "Alice" }, ...]
}
```

**JavaScript Usage:**

```javascript
import { detabulate, detabulatePagination } from './tabular.js';

// Convert tabular to array
const tabular = {
    columns: [
        { name: "id", type: "integer" },
        { name: "name", type: "varchar" }
    ],
    rows: [[1, "Alice"], [2, "Bob"]]
};

const array = detabulate(tabular);
// [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }]
```

**Available Functions:**

| Function | Description |
|----------|-------------|
| `detabulate(tabular)` | Convert tabular format to array of objects |
| `detabulatePagination(result)` | Convert pagination result with tabular data |
| `tabulate(array)` | Convert array of objects to tabular format |
| `tabulatePagination(result)` | Convert pagination result to tabular format |
| `isTabular(data)` | Check if data is in tabular format |
| `isTabularPagination(data)` | Check if pagination result has tabular data |
| `getColumnNames(tabular)` | Get array of column names |
| `getColumnTypes(tabular)` | Get map of column names to types |
| `getRow(tabular, index)` | Get single row as object |
| `getColumn(tabular, name)` | Get column values as array |
| `toQTableColumns(tabular, options)` | Generate Quasar QTable column definitions |
| `toQTable(tabular, options)` | Generate QTable-ready { columns, rows } |
| `toQTablePagination(result, options)` | Generate QTable structure with pagination |

**Quasar QTable Integration:**

The `toQTable*` functions generate column definitions with intelligent formatting:
- **Alignment**: Numbers and dates align right, strings align left, booleans center
- **Formatting**: Numbers get thousand separators, dates use locale-aware formatting
- **Sorting**: Type-appropriate sort functions for proper numeric/date sorting
- **Labels**: Column names converted from `snake_case`/`camelCase` to "Title Case"

```javascript
import { toQTable, toQTablePagination } from './tabular.js';

// Simple usage - generates columns and rows
const tabular = await fetchData(); // { columns: [...], rows: [...] }
const { columns, rows } = toQTable(tabular);

// With options
const { columns, rows } = toQTable(tabular, {
    dateFormat: 'short',           // 'short', 'medium', 'long', 'iso', or custom function
    locale: 'en-US',               // Locale for formatting
    decimalPlaces: 2,              // Decimal precision
    useThousandSeparator: true,    // 1000 -> "1,000"
    sortable: true,                // Enable column sorting
    columnOverrides: {             // Per-column customization
        status: { align: 'center', label: 'Status' }
    }
});

// For paginated results
const result = await fetchPaginatedData();
const { columns, rows, pagination } = toQTablePagination(result);
```

```html
<q-table
    :columns="columns"
    :rows="rows"
    :pagination="pagination"
    row-key="id"
/>
```

**Type Definitions (TypeScript):**

```typescript
interface TabularColumn {
    name: string;
    type: 'integer' | 'bigint' | 'decimal' | 'varchar' | 'boolean' |
          'datetime' | 'uuid' | 'object' | 'array' | 'binary' | 'unknown';
}

interface TabularData<T = Record<string, unknown>> {
    columns: TabularColumn[];
    rows: unknown[][];
}

interface TabularPaginationResult<T = Record<string, unknown>> {
    pagination: {
        page: number;
        maxRows: number;
        totalRecords: number;
        totalPages: number;
    };
    results: TabularData<T>;
}
```

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

## Testing

```bash
# Install dependencies
box install

# Run tests
box testbox run
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

- Powered by [QueryBuilder](https://qb.ortusbooks.com/) by Ortus Solutions
- Inspired by the need for portable, secure query definitions