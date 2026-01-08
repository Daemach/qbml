/**
 * QBML Tabular Utilities
 * Browser-side utilities for working with QBML tabular format
 *
 * Tabular format: { columns: [{ name, type }], rows: [[...], ...] }
 * Array format: [{ col1: val1, col2: val2 }, ...]
 *
 * @example
 * import { detabulate, detabulatePagination } from './tabular.js';
 *
 * // Convert tabular to array
 * const array = detabulate(tabularData);
 *
 * // Convert pagination result
 * const result = detabulatePagination(tabularPaginationResult);
 */

// =============================================================================
// DETABULATE FUNCTIONS
// =============================================================================

/**
 * Convert tabular format to array of objects
 *
 * @param {Object} tabular - Tabular data { columns: [{ name, type }], rows: [[...]] }
 * @returns {Array} Array of objects
 *
 * @example
 * const tabular = {
 *   columns: [{ name: "id", type: "integer" }, { name: "name", type: "varchar" }],
 *   rows: [[1, "Alice"], [2, "Bob"]]
 * };
 * const array = detabulate(tabular);
 * // [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }]
 */
export function detabulate( tabular ) {
	if ( !tabular?.columns?.length || !tabular?.rows?.length ) {
		return [];
	}

	const columnNames = tabular.columns.map( ( col ) => col.name );

	return tabular.rows.map( ( row ) => {
		const obj = {};
		columnNames.forEach( ( name, index ) => {
			obj[ name ] = row[ index ];
		} );
		return obj;
	} );
}

/**
 * Convert tabular pagination result to array pagination result
 *
 * @param {Object} tabularResult - Pagination result with tabular data
 * @returns {Object} Pagination result with array data
 *
 * @example
 * const tabularResult = {
 *   pagination: { page: 1, maxRows: 25, totalRecords: 100, totalPages: 4 },
 *   results: { columns: [...], rows: [...] }
 * };
 * const arrayResult = detabulatePagination(tabularResult);
 * // { pagination: {...}, results: [{ id: 1, name: "Alice" }, ...] }
 */
export function detabulatePagination( tabularResult ) {
	return {
		pagination: tabularResult.pagination,
		results: detabulate( tabularResult.results )
	};
}

// =============================================================================
// TABULATE FUNCTIONS (for symmetry - convert array back to tabular)
// =============================================================================

/**
 * Detect the type of a value for tabular format
 * @private
 */
function detectType( val ) {
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
 * @param {Array} data - Array of objects
 * @returns {Object} Tabular data { columns: [...], rows: [...] }
 *
 * @example
 * const array = [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }];
 * const tabular = tabulate(array);
 * // { columns: [{ name: "id", type: "integer" }, ...], rows: [[1, "Alice"], ...] }
 */
export function tabulate( data ) {
	if ( !data?.length ) {
		return { columns: [], rows: [] };
	}

	// Get column names from first row
	const columnNames = Object.keys( data[ 0 ] );

	// Detect types by sampling all rows
	const columnTypes = {};
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
	const columns = columnNames.map( ( name ) => {
		const types = columnTypes[ name ];
		const typeKeys = Object.keys( types );

		if ( typeKeys.length === 0 ) {
			return { name, type: "varchar" };
		}

		if ( typeKeys.length === 1 ) {
			return { name, type: typeKeys[ 0 ] };
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
		let maxType = "varchar";
		for ( const [ type, count ] of Object.entries( types ) ) {
			if ( count > maxCount ) {
				maxCount = count;
				maxType = type;
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
 *
 * @param {Object} arrayResult - Pagination result with array data
 * @returns {Object} Pagination result with tabular data
 */
export function tabulatePagination( arrayResult ) {
	return {
		pagination: arrayResult.pagination,
		results: tabulate( arrayResult.results )
	};
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Check if a data structure is in tabular format
 *
 * @param {*} data - Data to check
 * @returns {boolean} True if tabular format
 */
export function isTabular( data ) {
	return (
		typeof data === "object" &&
		data !== null &&
		"columns" in data &&
		"rows" in data &&
		Array.isArray( data.columns ) &&
		Array.isArray( data.rows )
	);
}

/**
 * Check if a pagination result contains tabular data
 *
 * @param {*} data - Data to check
 * @returns {boolean} True if pagination with tabular results
 */
export function isTabularPagination( data ) {
	return (
		typeof data === "object" &&
		data !== null &&
		"pagination" in data &&
		"results" in data &&
		isTabular( data.results )
	);
}

/**
 * Get column names from tabular data
 *
 * @param {Object} tabular - Tabular data
 * @returns {string[]} Array of column names
 */
export function getColumnNames( tabular ) {
	return tabular.columns.map( ( col ) => col.name );
}

/**
 * Get column types as a map
 *
 * @param {Object} tabular - Tabular data
 * @returns {Object} Map of column name to type
 */
export function getColumnTypes( tabular ) {
	return tabular.columns.reduce( ( acc, col ) => {
		acc[ col.name ] = col.type;
		return acc;
	}, {} );
}

/**
 * Get a single row as an object
 *
 * @param {Object} tabular - Tabular data
 * @param {number} index - Row index (0-based)
 * @returns {Object|undefined} Row as object, or undefined if out of bounds
 */
export function getRow( tabular, index ) {
	if ( index < 0 || index >= tabular.rows.length ) {
		return undefined;
	}

	const columnNames = tabular.columns.map( ( col ) => col.name );
	const row = tabular.rows[ index ];
	const obj = {};

	columnNames.forEach( ( name, i ) => {
		obj[ name ] = row[ i ];
	} );

	return obj;
}

/**
 * Get a column's values as an array
 *
 * @param {Object} tabular - Tabular data
 * @param {string} columnName - Name of the column
 * @returns {Array} Array of column values
 */
export function getColumn( tabular, columnName ) {
	const colIndex = tabular.columns.findIndex( ( col ) => col.name === columnName );
	if ( colIndex === -1 ) {
		return [];
	}
	return tabular.rows.map( ( row ) => row[ colIndex ] );
}

// =============================================================================
// QUASAR Q-TABLE INTEGRATION
// =============================================================================

/**
 * Convert column name to human-readable label
 * Handles snake_case, camelCase, and PascalCase
 * @private
 */
function defaultLabelGenerator( name ) {
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
 * @private
 */
function getAlignmentForType( type ) {
	switch ( type ) {
		case "integer":
		case "bigint":
		case "decimal":
		case "datetime":
			return "right";
		case "boolean":
			return "center";
		default:
			return "left";
	}
}

/**
 * Create a date formatter function
 * @private
 */
function createDateFormatter( format, locale ) {
	const loc = locale || ( typeof navigator !== "undefined" ? navigator.language : "en-US" );

	if ( typeof format === "function" ) {
		return ( val ) => {
			if ( val === null || val === undefined || val === "" ) return "";
			const date = val instanceof Date ? val : new Date( val );
			if ( isNaN( date.getTime() ) ) return String( val );
			return format( date );
		};
	}

	const options = ( () => {
		switch ( format ) {
			case "short":
				return { dateStyle: "short" };
			case "long":
				return { dateStyle: "long", timeStyle: "medium" };
			case "iso":
				return {};
			case "medium":
			default:
				return { dateStyle: "medium", timeStyle: "short" };
		}
	} )();

	return ( val ) => {
		if ( val === null || val === undefined || val === "" ) return "";
		const date = val instanceof Date ? val : new Date( val );
		if ( isNaN( date.getTime() ) ) return String( val );

		if ( format === "iso" ) {
			return date.toISOString();
		}

		return new Intl.DateTimeFormat( loc, options ).format( date );
	};
}

/**
 * Create a number formatter function
 * @private
 */
function createNumberFormatter( type, options ) {
	const locale = options.locale || ( typeof navigator !== "undefined" ? navigator.language : "en-US" );
	const useGrouping = options.useThousandSeparator !== false;

	const formatOptions = {
		useGrouping,
		minimumFractionDigits: type === "decimal" ? ( options.decimalPlaces ?? 2 ) : 0,
		maximumFractionDigits: type === "decimal" ? ( options.decimalPlaces ?? 2 ) : 0
	};

	const formatter = new Intl.NumberFormat( locale, formatOptions );

	return ( val ) => {
		if ( val === null || val === undefined || val === "" ) return "";
		const num = typeof val === "number" ? val : parseFloat( String( val ) );
		if ( isNaN( num ) ) return String( val );
		return formatter.format( num );
	};
}

/**
 * Create sort function for a column type
 * @private
 */
function createSortFunction( type ) {
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
				const dateA = a === null || a === undefined ? 0 : new Date( a ).getTime();
				const dateB = b === null || b === undefined ? 0 : new Date( b ).getTime();
				return dateA - dateB;
			};
		case "boolean":
			return ( a, b ) => {
				const boolA = a === true || a === "true" || a === 1 ? 1 : 0;
				const boolB = b === true || b === "true" || b === 1 ? 1 : 0;
				return boolA - boolB;
			};
		default:
			return undefined;
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
 * @param {Object} tabular - Tabular data { columns: [...], rows: [...] }
 * @param {Object} options - Configuration options
 * @param {string|Function} options.dateFormat - 'short', 'medium', 'long', 'iso', or custom function
 * @param {string} options.locale - Locale for date/number formatting
 * @param {number} options.decimalPlaces - Decimal places for decimal types (default: 2)
 * @param {boolean} options.useThousandSeparator - Use thousand separators (default: true)
 * @param {Function} options.labelGenerator - Custom label generator function
 * @param {boolean} options.sortable - Make columns sortable (default: true)
 * @param {Object} options.columnOverrides - Per-column overrides
 * @returns {Array} Array of QTable column definitions
 *
 * @example
 * const tabular = await fetchData();
 * const columns = toQTableColumns(tabular);
 * const rows = detabulate(tabular);
 *
 * <q-table :columns="columns" :rows="rows" />
 */
export function toQTableColumns( tabular, options = {} ) {
	const {
		dateFormat = "medium",
		sortable = true,
		columnOverrides = {}
	} = options;

	const labelGenerator = options.labelGenerator || defaultLabelGenerator;

	return tabular.columns.map( ( col ) => {
		const baseColumn = {
			name: col.name,
			label: labelGenerator( col.name ),
			field: col.name,
			align: getAlignmentForType( col.type ),
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
				baseColumn.format = ( val ) => {
					if ( val === null || val === undefined ) return "";
					return val === true || val === "true" || val === 1 ? "Yes" : "No";
				};
				baseColumn.sort = createSortFunction( col.type );
				break;

			case "uuid":
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
 * @param {Object} tabular - Tabular data { columns: [...], rows: [...] }
 * @param {Object} options - Configuration options (see toQTableColumns)
 * @returns {Object} { columns: [...], rows: [...] }
 *
 * @example
 * const tabular = await fetchData();
 * const { columns, rows } = toQTable(tabular);
 *
 * <q-table :columns="columns" :rows="rows" row-key="id" />
 */
export function toQTable( tabular, options = {} ) {
	return {
		columns: toQTableColumns( tabular, options ),
		rows: detabulate( tabular )
	};
}

/**
 * Generate QTable-ready structure from pagination result
 *
 * @param {Object} tabularResult - Pagination result with tabular data
 * @param {Object} options - Configuration options (see toQTableColumns)
 * @returns {Object} { columns, rows, pagination }
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
export function toQTablePagination( tabularResult, options = {} ) {
	return {
		columns: toQTableColumns( tabularResult.results, options ),
		rows: detabulate( tabularResult.results ),
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
