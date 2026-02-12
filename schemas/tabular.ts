/**
 * QBML Tabular Utilities
 * Browser-side utilities for working with QBML tabular format
 *
 * Tabular format: { columns: [{ name, type }], rows: [[...], ...] }
 * Array format: [{ col1: val1, col2: val2 }, ...]
 */

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Column metadata in tabular format
 */
export interface TabularColumn {
	name: string;
	type:
		| "integer"
		| "bigint"
		| "decimal"
		| "varchar"
		| "boolean"
		| "datetime"
		| "uuid"
		| "object"
		| "array"
		| "binary"
		| "unknown";
}

/**
 * Tabular data structure - compact format with column metadata
 */
export interface TabularData<T extends Record<string, unknown> = Record<string, unknown>> {
	columns: TabularColumn[];
	rows: unknown[][];
}

/**
 * Pagination result with tabular data
 */
export interface TabularPaginationResult<T extends Record<string, unknown> = Record<string, unknown>> {
	pagination: {
		page: number;
		maxRows: number;
		totalRecords: number;
		totalPages: number;
	};
	results: TabularData<T>;
}

/**
 * Pagination result with array data
 */
export interface ArrayPaginationResult<T extends Record<string, unknown> = Record<string, unknown>> {
	pagination: {
		page: number;
		maxRows: number;
		totalRecords: number;
		totalPages: number;
	};
	results: T[];
}

// =============================================================================
// DETABULATE FUNCTIONS
// =============================================================================

/**
 * Convert tabular format to array of objects
 *
 * @example
 * const tabular = {
 *   columns: [{ name: "id", type: "integer" }, { name: "name", type: "varchar" }],
 *   rows: [[1, "Alice"], [2, "Bob"]]
 * };
 * const array = detabulate(tabular);
 * // [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }]
 */
export function detabulate<T extends Record<string, unknown> = Record<string, unknown>>(
	tabular: TabularData<T>
): T[] {
	if ( !tabular?.columns?.length || !tabular?.rows?.length ) {
		return [];
	}

	const columnNames = tabular.columns.map( ( col ) => col.name );

	return tabular.rows.map( ( row ) => {
		const obj = {} as T;
		columnNames.forEach( ( name, index ) => {
			( obj as Record<string, unknown> )[ name ] = row[ index ];
		} );
		return obj;
	} );
}

/**
 * Convert tabular pagination result to array pagination result
 *
 * @example
 * const tabularResult = {
 *   pagination: { page: 1, maxRows: 25, totalRecords: 100, totalPages: 4 },
 *   results: { columns: [...], rows: [...] }
 * };
 * const arrayResult = detabulatePagination(tabularResult);
 * // { pagination: {...}, results: [{ id: 1, name: "Alice" }, ...] }
 */
export function detabulatePagination<T extends Record<string, unknown> = Record<string, unknown>>(
	tabularResult: TabularPaginationResult<T>
): ArrayPaginationResult<T> {
	return {
		pagination: tabularResult.pagination,
		results: detabulate<T>( tabularResult.results )
	};
}

// =============================================================================
// TABULATE FUNCTIONS (for symmetry - convert array back to tabular)
// =============================================================================

/**
 * Detect the type of a value for tabular format
 */
function detectType( val: unknown ): TabularColumn["type"] {
	if ( val === null || val === undefined ) {
		return "unknown";
	}

	if ( Array.isArray( val ) ) {
		return "array";
	}

	if ( typeof val === "object" ) {
		return "object";
	}

	if ( typeof val === "boolean" ) {
		return "boolean";
	}

	if ( typeof val === "number" ) {
		if ( Number.isInteger( val ) ) {
			return Math.abs( val ) > 2147483647 ? "bigint" : "integer";
		}
		return "decimal";
	}

	if ( typeof val === "string" ) {
		// UUID pattern
		if ( /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test( val ) ) {
			return "uuid";
		}
		// ISO date pattern
		if ( /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2})?/.test( val ) && !isNaN( Date.parse( val ) ) ) {
			return "datetime";
		}
	}

	return "varchar";
}

/**
 * Convert array of objects to tabular format
 *
 * @example
 * const array = [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }];
 * const tabular = tabulate(array);
 * // { columns: [{ name: "id", type: "integer" }, ...], rows: [[1, "Alice"], ...] }
 */
export function tabulate<T extends Record<string, unknown>>(
	data: T[]
): TabularData<T> {
	if ( !data?.length ) {
		return { columns: [], rows: [] };
	}

	// Get column names from first row
	const columnNames = Object.keys( data[ 0 ] );

	// Detect types by sampling all rows
	const columnTypes: Record<string, Record<string, number>> = {};
	columnNames.forEach( ( name ) => {
		columnTypes[ name ] = {};
	} );

	for ( const row of data ) {
		for ( const name of columnNames ) {
			const val = row[ name ];
			if ( val !== null && val !== undefined && val !== "" ) {
				const type = detectType( val );
				columnTypes[ name ][ type ] = ( columnTypes[ name ][ type ] || 0 ) + 1;
			}
		}
	}

	// Resolve final type for each column
	const columns: TabularColumn[] = columnNames.map( ( name ) => {
		const types = columnTypes[ name ];
		const typeKeys = Object.keys( types );

		if ( typeKeys.length === 0 ) {
			return { name, type: "varchar" };
		}

		if ( typeKeys.length === 1 ) {
			return { name, type: typeKeys[ 0 ] as TabularColumn["type"] };
		}

		// Type promotion rules
		if ( typeKeys.includes( "integer" ) && typeKeys.includes( "decimal" ) ) {
			return { name, type: "decimal" };
		}
		if ( typeKeys.includes( "integer" ) && typeKeys.includes( "bigint" ) ) {
			return { name, type: "bigint" };
		}

		// Use most common type
		let maxCount = 0;
		let maxType: TabularColumn["type"] = "varchar";
		for ( const [ type, count ] of Object.entries( types ) ) {
			if ( count > maxCount ) {
				maxCount = count;
				maxType = type as TabularColumn["type"];
			}
		}
		return { name, type: maxType };
	} );

	// Convert rows to arrays
	const rows = data.map( ( row ) => columnNames.map( ( name ) => row[ name ] ) );

	return { columns, rows };
}

/**
 * Convert array pagination result to tabular pagination result
 */
export function tabulatePagination<T extends Record<string, unknown>>(
	arrayResult: ArrayPaginationResult<T>
): TabularPaginationResult<T> {
	return {
		pagination: arrayResult.pagination,
		results: tabulate<T>( arrayResult.results )
	};
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Check if a data structure is in tabular format
 */
export function isTabular( data: unknown ): data is TabularData {
	return (
		typeof data === "object" &&
		data !== null &&
		"columns" in data &&
		"rows" in data &&
		Array.isArray( ( data as TabularData ).columns ) &&
		Array.isArray( ( data as TabularData ).rows )
	);
}

/**
 * Check if a pagination result contains tabular data
 */
export function isTabularPagination( data: unknown ): data is TabularPaginationResult {
	return (
		typeof data === "object" &&
		data !== null &&
		"pagination" in data &&
		"results" in data &&
		isTabular( ( data as TabularPaginationResult ).results )
	);
}

/**
 * Get column names from tabular data
 */
export function getColumnNames( tabular: TabularData ): string[] {
	return tabular.columns.map( ( col ) => col.name );
}

/**
 * Get column types as a map
 */
export function getColumnTypes( tabular: TabularData ): Record<string, TabularColumn["type"]> {
	return tabular.columns.reduce(
		( acc, col ) => {
			acc[ col.name ] = col.type;
			return acc;
		},
		{} as Record<string, TabularColumn["type"]>
	);
}

/**
 * Get a single row as an object
 */
export function getRow<T extends Record<string, unknown> = Record<string, unknown>>(
	tabular: TabularData<T>,
	index: number
): T | undefined {
	if ( index < 0 || index >= tabular.rows.length ) {
		return undefined;
	}

	const columnNames = tabular.columns.map( ( col ) => col.name );
	const row = tabular.rows[ index ];
	const obj = {} as T;

	columnNames.forEach( ( name, i ) => {
		( obj as Record<string, unknown> )[ name ] = row[ i ];
	} );

	return obj;
}

/**
 * Get a column's values as an array
 */
export function getColumn<V = unknown>( tabular: TabularData, columnName: string ): V[] {
	const colIndex = tabular.columns.findIndex( ( col ) => col.name === columnName );
	if ( colIndex === -1 ) {
		return [];
	}
	return tabular.rows.map( ( row ) => row[ colIndex ] as V );
}

// =============================================================================
// QUASAR Q-TABLE INTEGRATION
// =============================================================================

/**
 * Quasar QTable column definition
 */
export interface QTableColumn {
	name: string;
	label: string;
	field: string | ( ( row: Record<string, unknown> ) => unknown );
	align?: "left" | "center" | "right";
	sortable?: boolean;
	sort?: ( a: unknown, b: unknown, rowA: Record<string, unknown>, rowB: Record<string, unknown> ) => number;
	format?: ( val: unknown, row: Record<string, unknown> ) => string;
	style?: string;
	classes?: string;
	headerStyle?: string;
	headerClasses?: string;
}

/**
 * Options for generating QTable columns
 */
export interface QTableColumnOptions {
	/** Date format style: 'short', 'medium', 'long', 'iso', or custom format function */
	dateFormat?: "short" | "medium" | "long" | "iso" | ( ( date: Date ) => string );
	/** Locale for date/number formatting (default: browser locale) */
	locale?: string;
	/** Number of decimal places for decimal types (default: 2) */
	decimalPlaces?: number;
	/** Whether to use thousand separators for numbers (default: true) */
	useThousandSeparator?: boolean;
	/** Custom label generator (default: converts snake_case/camelCase to Title Case) */
	labelGenerator?: ( columnName: string ) => string;
	/** Make all columns sortable (default: true) */
	sortable?: boolean;
	/** Column overrides - merge with generated column config */
	columnOverrides?: Record<string, Partial<QTableColumn>>;
}

/**
 * Convert column name to human-readable label
 * Handles snake_case, camelCase, and PascalCase
 */
function defaultLabelGenerator( name: string ): string {
	return name
		// Insert space before uppercase letters (camelCase/PascalCase)
		.replace( /([a-z])([A-Z])/g, "$1 $2" )
		// Replace underscores and hyphens with spaces
		.replace( /[_-]/g, " " )
		// Capitalize first letter of each word
		.replace( /\b\w/g, ( char ) => char.toUpperCase() )
		// Handle common abbreviations
		.replace( /\bId\b/g, "ID" )
		.replace( /\bUuid\b/g, "UUID" )
		.replace( /\bUrl\b/g, "URL" )
		.replace( /\bApi\b/g, "API" );
}

/**
 * Determine alignment based on data type
 * - Numerics and dates with year-last format: right
 * - Strings and other: left
 */
function getAlignmentForType( type: TabularColumn["type"] ): "left" | "right" {
	switch ( type ) {
		case "integer":
		case "bigint":
		case "decimal":
			return "right";
		case "datetime":
			return "right";
		case "boolean":
			return "center" as "left"; // Cast to satisfy return type, will be overridden
		default:
			return "left";
	}
}

/**
 * Create a date formatter function
 */
function createDateFormatter(
	format: QTableColumnOptions["dateFormat"],
	locale?: string
): ( val: unknown ) => string {
	const loc = locale || ( typeof navigator !== "undefined" ? navigator.language : "en-US" );

	if ( typeof format === "function" ) {
		return ( val: unknown ) => {
			if ( val === null || val === undefined || val === "" ) return "";
			const date = val instanceof Date ? val : new Date( val as string | number );
			if ( isNaN( date.getTime() ) ) return String( val );
			return format( date );
		};
	}

	const options: Intl.DateTimeFormatOptions = ( () => {
		switch ( format ) {
			case "short":
				return { dateStyle: "short" } as Intl.DateTimeFormatOptions;
			case "long":
				return { dateStyle: "long", timeStyle: "medium" } as Intl.DateTimeFormatOptions;
			case "iso":
				return {}; // Will use toISOString
			case "medium":
			default:
				return { dateStyle: "medium", timeStyle: "short" } as Intl.DateTimeFormatOptions;
		}
	} )();

	return ( val: unknown ) => {
		if ( val === null || val === undefined || val === "" ) return "";
		const date = val instanceof Date ? val : new Date( val as string | number );
		if ( isNaN( date.getTime() ) ) return String( val );

		if ( format === "iso" ) {
			return date.toISOString();
		}

		return new Intl.DateTimeFormat( loc, options ).format( date );
	};
}

/**
 * Create a number formatter function
 */
function createNumberFormatter(
	type: "integer" | "bigint" | "decimal",
	options: QTableColumnOptions
): ( val: unknown ) => string {
	const locale = options.locale || ( typeof navigator !== "undefined" ? navigator.language : "en-US" );
	const useGrouping = options.useThousandSeparator !== false;

	const formatOptions: Intl.NumberFormatOptions = {
		useGrouping,
		minimumFractionDigits: type === "decimal" ? ( options.decimalPlaces ?? 2 ) : 0,
		maximumFractionDigits: type === "decimal" ? ( options.decimalPlaces ?? 2 ) : 0
	};

	const formatter = new Intl.NumberFormat( locale, formatOptions );

	return ( val: unknown ) => {
		if ( val === null || val === undefined || val === "" ) return "";
		const num = typeof val === "number" ? val : parseFloat( String( val ) );
		if ( isNaN( num ) ) return String( val );
		return formatter.format( num );
	};
}

/**
 * Create sort function for a column type
 */
function createSortFunction(
	type: TabularColumn["type"]
): ( ( a: unknown, b: unknown ) => number ) | undefined {
	switch ( type ) {
		case "integer":
		case "bigint":
		case "decimal":
			return ( a, b ) => {
				const numA = a === null || a === undefined ? -Infinity : Number( a );
				const numB = b === null || b === undefined ? -Infinity : Number( b );
				return numA - numB;
			};
		case "datetime":
			return ( a, b ) => {
				const dateA = a === null || a === undefined ? 0 : new Date( a as string | number ).getTime();
				const dateB = b === null || b === undefined ? 0 : new Date( b as string | number ).getTime();
				return dateA - dateB;
			};
		case "boolean":
			return ( a, b ) => {
				const boolA = a === true || a === "true" || a === 1 ? 1 : 0;
				const boolB = b === true || b === "true" || b === 1 ? 1 : 0;
				return boolA - boolB;
			};
		default:
			return undefined; // Use default string sort
	}
}

/**
 * Generate Quasar QTable column definitions from tabular data
 *
 * Creates column configs with:
 * - Intelligent alignment (right for numbers/dates, left for strings)
 * - Type-appropriate formatters (dates, numbers with separators)
 * - Proper sort functions for each type
 * - Human-readable labels from column names
 *
 * @example
 * const tabular = await fetchData(); // { columns: [...], rows: [...] }
 * const columns = toQTableColumns(tabular);
 * const rows = detabulate(tabular);
 *
 * <q-table :columns="columns" :rows="rows" />
 */
export function toQTableColumns(
	tabular: TabularData,
	options: QTableColumnOptions = {}
): QTableColumn[] {
	const {
		dateFormat = "medium",
		sortable = true,
		columnOverrides = {}
	} = options;

	const labelGenerator = options.labelGenerator || defaultLabelGenerator;

	return tabular.columns.map( ( col ) => {
		const baseColumn: QTableColumn = {
			name: col.name,
			label: labelGenerator( col.name ),
			field: col.name,
			align: getAlignmentForType( col.type ) as "left" | "center" | "right",
			sortable
		};

		// Add type-specific formatting and sorting
		switch ( col.type ) {
			case "integer":
			case "bigint":
				baseColumn.format = createNumberFormatter( col.type, { ...options, decimalPlaces: 0 } );
				baseColumn.sort = createSortFunction( col.type );
				break;

			case "decimal":
				baseColumn.format = createNumberFormatter( "decimal", options );
				baseColumn.sort = createSortFunction( col.type );
				break;

			case "datetime":
				baseColumn.format = createDateFormatter( dateFormat, options.locale );
				baseColumn.sort = createSortFunction( col.type );
				break;

			case "boolean":
				baseColumn.align = "center";
				baseColumn.format = ( val ) => {
					if ( val === null || val === undefined ) return "";
					return val === true || val === "true" || val === 1 ? "Yes" : "No";
				};
				baseColumn.sort = createSortFunction( col.type );
				break;

			case "uuid":
				// UUIDs are typically displayed as-is, left-aligned
				baseColumn.classes = "text-mono";
				break;

			case "object":
			case "array":
				baseColumn.format = ( val ) => {
					if ( val === null || val === undefined ) return "";
					return JSON.stringify( val );
				};
				break;
		}

		// Apply column overrides
		if ( columnOverrides[ col.name ] ) {
			return { ...baseColumn, ...columnOverrides[ col.name ] };
		}

		return baseColumn;
	} );
}

/**
 * Generate QTable-ready structure from tabular data
 * Returns both columns and rows in the format QTable expects
 *
 * @example
 * const tabular = await fetchData();
 * const { columns, rows } = toQTable(tabular);
 *
 * <q-table :columns="columns" :rows="rows" row-key="id" />
 */
export function toQTable<T extends Record<string, unknown> = Record<string, unknown>>(
	tabular: TabularData<T>,
	options: QTableColumnOptions = {}
): { columns: QTableColumn[]; rows: T[] } {
	return {
		columns: toQTableColumns( tabular, options ),
		rows: detabulate<T>( tabular )
	};
}

/**
 * Generate QTable-ready structure from pagination result
 *
 * @example
 * const result = await fetchPaginatedData();
 * const { columns, rows, pagination } = toQTablePagination(result);
 *
 * <q-table
 *   :columns="columns"
 *   :rows="rows"
 *   :pagination="pagination"
 *   row-key="id"
 * />
 */
export function toQTablePagination<T extends Record<string, unknown> = Record<string, unknown>>(
	tabularResult: TabularPaginationResult<T>,
	options: QTableColumnOptions = {}
): {
	columns: QTableColumn[];
	rows: T[];
	pagination: {
		page: number;
		rowsPerPage: number;
		rowsNumber: number;
	};
} {
	return {
		columns: toQTableColumns( tabularResult.results, options ),
		rows: detabulate<T>( tabularResult.results ),
		pagination: {
			page: tabularResult.pagination.page,
			rowsPerPage: tabularResult.pagination.maxRows,
			rowsNumber: tabularResult.pagination.totalRecords
		}
	};
}

// =============================================================================
// DEFAULT EXPORT
// =============================================================================

export default {
	detabulate,
	detabulatePagination,
	tabulate,
	tabulatePagination,
	isTabular,
	isTabularPagination,
	getColumnNames,
	getColumnTypes,
	getRow,
	getColumn,
	toQTableColumns,
	toQTable,
	toQTablePagination
};
