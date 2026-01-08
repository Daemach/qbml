/**
 * Tabular Formatter
 * Converts query results to tabular format: { columns: [...], rows: [[...], ...] }
 * Tabular is a compact format that preserves column metadata while reducing payload size
 * and providing richer type information through deep inspection.
 */
component singleton {

	/**
	 * Convert an array of structs to tabular format with deep type detection
	 * This is the primary method - uses deep inspection for accurate type inference
	 *
	 * @data The array of structs to convert
	 * @return struct { columns: array, rows: array }
	 */
	struct function fromArray( required array data ) {
		var result = { columns : [], rows : [] };

		if ( !arguments.data.len() ) {
			return result;
		}

		// First row must be a struct
		if ( !isStruct( arguments.data[ 1 ] ) ) {
			return result;
		}

		// Get column names from first row (preserving order)
		var columnNames = arguments.data[ 1 ].keyArray();

		// Initialize column metadata with null types (to be refined)
		result.columns = columnNames.map( function( colName ) {
			return { name : colName, type : "unknown" };
		} );

		// Deep seek: inspect ALL rows to determine most accurate type
		var columnTypes = {};
		for ( var colName in columnNames ) {
			columnTypes[ colName ] = { hasNull : false, types : {} };
		}

		// Pass 1: Collect type information from all rows
		for ( var row in arguments.data ) {
			for ( var colName in columnNames ) {
				var val = row[ colName ];

				if ( isNull( val ) || ( isSimpleValue( val ) && !len( trim( val ) ) ) ) {
					columnTypes[ colName ].hasNull = true;
					continue;
				}

				var detectedType = detectType( val );
				if ( !columnTypes[ colName ].types.keyExists( detectedType ) ) {
					columnTypes[ colName ].types[ detectedType ] = 0;
				}
				columnTypes[ colName ].types[ detectedType ]++;
			}
		}

		// Pass 2: Resolve final type for each column
		result.columns = result.columns.map( function( col ) {
			var typeInfo = columnTypes[ col.name ];
			col.type     = resolveColumnType( typeInfo );
			return col;
		} );

		// Pass 3: Convert rows to arrays
		for ( var row in arguments.data ) {
			var rowArray = [];
			for ( var col in result.columns ) {
				rowArray.append( row[ col.name ] );
			}
			result.rows.append( rowArray );
		}

		return result;
	}

	/**
	 * Convert a query object to tabular format
	 * Uses native query metadata for accurate types
	 *
	 * @query The query to convert
	 * @return struct { columns: array, rows: array }
	 */
	struct function fromQuery( required query query ) {
		var result = { columns : [], rows : [] };

		// Extract column metadata from query
		result.columns = getMetadata( arguments.query ).map( function( column ) {
			return {
				name : column.name,
				type : normalizeQueryType( column.typeName )
			};
		} );

		// Convert rows to arrays
		for ( var row in arguments.query ) {
			var rowArray = [];
			for ( var col in result.columns ) {
				rowArray.append( row[ col.name ] );
			}
			result.rows.append( rowArray );
		}

		return result;
	}

	/**
	 * Transform a pagination result to use tabular format for the data
	 * Preserves the pagination structure while converting data to tabular
	 *
	 * @paginationResult The pagination struct with data, pagination, error, messages
	 * @dataKey The key containing the data array (default: "data")
	 * @return struct The transformed pagination result
	 */
	struct function fromPagination(
		required struct paginationResult,
		string dataKey = "data"
	) {
		var result = duplicate( arguments.paginationResult );

		// Handle nested data structures (e.g., { data: { main: [...], detail: {...} } })
		if (
			result.keyExists( arguments.dataKey ) && isStruct( result[ arguments.dataKey ] ) && !result[ arguments.dataKey ].keyExists(
				"columns"
			)
		) {
			// It's a struct with sub-keys, transform each array sub-key
			for ( var subKey in result[ arguments.dataKey ] ) {
				if ( isArray( result[ arguments.dataKey ][ subKey ] ) ) {
					result[ arguments.dataKey ][ subKey ] = fromArray( result[ arguments.dataKey ][ subKey ] );
				}
			}
		} else if ( result.keyExists( arguments.dataKey ) && isArray( result[ arguments.dataKey ] ) ) {
			// Simple array data - transform directly
			result[ arguments.dataKey ] = fromArray( result[ arguments.dataKey ] );
		}

		return result;
	}

	/**
	 * Decompress tabular format back to array of structs
	 *
	 * @tabular The tabular data structure
	 * @return array of structs
	 */
	array function toArray( required struct tabular ) {
		if (
			!arguments.tabular.keyExists( "rows" ) || !arguments.tabular.rows.len() || !arguments.tabular.keyExists(
				"columns"
			) || !arguments.tabular.columns.len()
		) {
			return [];
		}

		var columnNames = arguments.tabular.columns.map( function( col ) {
			return col.name;
		} );

		return arguments.tabular.rows.map( function( row ) {
			var out = {};
			if ( isArray( row ) ) {
				for ( var i = 1; i <= row.len(); i++ ) {
					out[ columnNames[ i ] ] = row[ i ];
				}
			} else {
				out = row;
			}
			return out;
		} );
	}

	// ==================== PRIVATE HELPERS ====================

	/**
	 * Detect the type of a value with granular precision
	 */
	private string function detectType( required any val ) {
		if ( isNull( arguments.val ) ) {
			return "null";
		}

		// Check for complex types first
		if ( isArray( arguments.val ) ) {
			return "array";
		}
		if ( isStruct( arguments.val ) ) {
			return "object";
		}
		if ( isQuery( arguments.val ) ) {
			return "query";
		}

		// Simple values
		if ( !isSimpleValue( arguments.val ) ) {
			return "object";
		}

		var strVal = toString( arguments.val );

		// Boolean check (before numeric, since true/false can be numeric)
		if ( isBoolean( arguments.val ) && ( strVal == "true" || strVal == "false" || strVal == "yes" || strVal == "no" ) ) {
			return "boolean";
		}

		// Date check (before numeric, since dates can be numeric)
		if ( isDate( arguments.val ) && !isNumeric( strVal ) ) {
			return "datetime";
		}

		// Numeric checks
		if ( isNumeric( arguments.val ) ) {
			// Check if it's an integer
			if ( isValid( "integer", arguments.val ) && !find( ".", strVal ) ) {
				// Check magnitude for bigint
				if ( abs( arguments.val ) > 2147483647 ) {
					return "bigint";
				}
				return "integer";
			}
			// It's a decimal/float
			return "decimal";
		}

		// UUID check
		if ( isValid( "UUID", strVal ) ) {
			return "uuid";
		}

		// Default to varchar
		return "varchar";
	}

	/**
	 * Resolve the final column type from collected type information
	 */
	private string function resolveColumnType( required struct typeInfo ) {
		var types = arguments.typeInfo.types;

		// No non-null values found
		if ( types.isEmpty() ) {
			return "varchar";
		}

		// Single type detected
		if ( types.count() == 1 ) {
			return types.keyArray()[ 1 ];
		}

		// Multiple types - apply promotion rules
		var typeKeys = types.keyArray();

		// Integer + Decimal = Decimal
		if ( typeKeys.find( "integer" ) && typeKeys.find( "decimal" ) ) {
			return "decimal";
		}

		// Integer + Bigint = Bigint
		if ( typeKeys.find( "integer" ) && typeKeys.find( "bigint" ) ) {
			return "bigint";
		}

		// Any numeric + varchar = varchar (mixed data)
		if (
			typeKeys.find( "varchar" ) && ( typeKeys.find( "integer" ) || typeKeys.find( "decimal" ) || typeKeys.find(
				"bigint"
			) )
		) {
			return "varchar";
		}

		// Default: use the most common type
		var maxCount = 0;
		var maxType  = "varchar";
		for ( var t in types ) {
			if ( types[ t ] > maxCount ) {
				maxCount = types[ t ];
				maxType  = t;
			}
		}

		return maxType;
	}

	/**
	 * Normalize SQL type names from query metadata to consistent types
	 */
	private string function normalizeQueryType( required string typeName ) {
		var t = arguments.typeName.lCase();

		// Integer types
		if ( t contains "int" && !( t contains "interval" ) ) {
			if ( t contains "big" ) return "bigint";
			if ( t contains "small" || t contains "tiny" ) return "integer";
			return "integer";
		}

		// Decimal/numeric types
		if ( t contains "decimal" || t contains "numeric" || t contains "money" ) {
			return "decimal";
		}

		// Float types
		if ( t contains "float" || t contains "double" || t contains "real" ) {
			return "decimal";
		}

		// Date/time types
		if ( t contains "date" || t contains "time" ) {
			return "datetime";
		}

		// Boolean
		if ( t contains "bit" || t contains "bool" ) {
			return "boolean";
		}

		// UUID/GUID
		if ( t contains "uuid" || t contains "uniqueidentifier" ) {
			return "uuid";
		}

		// Text types
		if (
			t contains "char" || t contains "text" || t contains "clob" || t contains "varchar" || t contains "nvarchar"
		) {
			return "varchar";
		}

		// Binary
		if ( t contains "binary" || t contains "blob" || t contains "image" ) {
			return "binary";
		}

		// Default
		return "varchar";
	}

}
