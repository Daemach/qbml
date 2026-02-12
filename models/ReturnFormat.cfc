/**
 * ReturnFormat
 * Unified return format transformer for QBML query results.
 * Handles all format conversions: array, query, tabular, and struct.
 *
 * Accepts both array-of-structs and native query inputs — automatically
 * chooses the optimal conversion path (e.g., fromQuery() for accurate
 * DB types vs fromArray() for heuristic detection).
 */
component singleton {

	// ==================== PUBLIC API ====================

	/**
	 * Parse a returnFormat value (string or tuple array) into a normalized struct.
	 * Handles: "array", ["array"], ["struct", "id"], ["struct", "id", ["name", "email"]]
	 *
	 * @returnFormat The raw returnFormat value (string or array)
	 * @return struct { format, columnKey, valueKeys }
	 */
	struct function parse( required any returnFormat ) {
		if ( isArray( arguments.returnFormat ) ) {
			return {
				format    : arguments.returnFormat[ 1 ],
				columnKey : arguments.returnFormat.len() >= 2 ? arguments.returnFormat[ 2 ] : "",
				valueKeys : arguments.returnFormat.len() >= 3 ? arguments.returnFormat[ 3 ] : []
			};
		}
		return { format : arguments.returnFormat, columnKey : "", valueKeys : [] };
	}

	/**
	 * Whether this format benefits from qb returning a native query object.
	 * When true, callers should set q.setReturnFormat("query") before executing
	 * to avoid the unnecessary query→array→target round-trip.
	 *
	 * @parsedFormat The normalized format struct from parse()
	 * @return boolean
	 */
	boolean function prefersQueryInput( required struct parsedFormat ) {
		return listFindNoCase( "query,tabular", arguments.parsedFormat.format ) > 0;
	}

	/**
	 * Transform query results to the target format.
	 * Accepts BOTH array-of-structs and native query inputs.
	 *
	 * @data The results (array of structs or query object)
	 * @parsedFormat The normalized format struct from parse()
	 * @return any The transformed results
	 */
	any function transform( required any data, required struct parsedFormat ) {
		switch ( arguments.parsedFormat.format ) {
			case "array":
				if ( isQuery( arguments.data ) ) {
					return queryToArray( arguments.data );
				}
				return arguments.data;

			case "query":
				if ( isQuery( arguments.data ) ) {
					return arguments.data;
				}
				return arrayToQuery( arguments.data );

			case "tabular":
				if ( isQuery( arguments.data ) ) {
					return fromQuery( arguments.data );
				}
				return fromArray( arguments.data );

			case "struct":
				var arr = isQuery( arguments.data ) ? queryToArray( arguments.data ) : arguments.data;
				return toKeyedStruct( arr, arguments.parsedFormat.columnKey, arguments.parsedFormat.valueKeys );

			default:
				return arguments.data;
		}
	}

	/**
	 * Transform a pagination result, converting the results key to the target format.
	 * Preserves all pagination metadata.
	 *
	 * @paginationResult The pagination struct (e.g., { results: [...], pagination: {...} })
	 * @parsedFormat The normalized format struct from parse()
	 * @dataKey The key containing the results (default: "results")
	 * @return struct The transformed pagination result
	 */
	struct function transformPaginated(
		required struct paginationResult,
		required struct parsedFormat,
		string dataKey = "results"
	) {
		var result = duplicate( arguments.paginationResult );

		if ( !result.keyExists( arguments.dataKey ) ) {
			return result;
		}

		// For tabular with nested data structures (e.g., { results: { main: [...], detail: {...} } })
		if (
			arguments.parsedFormat.format == "tabular"
			&& isStruct( result[ arguments.dataKey ] )
			&& !result[ arguments.dataKey ].keyExists( "columns" )
		) {
			for ( var subKey in result[ arguments.dataKey ] ) {
				if ( isArray( result[ arguments.dataKey ][ subKey ] ) ) {
					result[ arguments.dataKey ][ subKey ] = fromArray( result[ arguments.dataKey ][ subKey ] );
				}
			}
			return result;
		}

		// Transform the results key
		result[ arguments.dataKey ] = transform( result[ arguments.dataKey ], arguments.parsedFormat );

		return result;
	}

	// ==================== TABULAR METHODS ====================

	/**
	 * Convert an array of structs to tabular format with deep type detection.
	 * Uses 3-pass heuristic inspection for type inference.
	 * Prefer fromQuery() when a native query object is available.
	 *
	 * @data The array of structs to convert
	 * @return struct { columns: array, rows: array }
	 */
	struct function fromArray( required array data ) {
		var result = { columns : [], rows : [] };

		if ( !arguments.data.len() ) {
			return result;
		}

		if ( !isStruct( arguments.data[ 1 ] ) ) {
			return result;
		}

		// Get column names from first row (preserving order)
		var columnNames = arguments.data[ 1 ].keyArray();

		// Initialize column metadata
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
	 * Convert a query object to tabular format.
	 * Uses native query metadata for accurate types — no heuristic detection needed.
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
	 * Convert an array of structs to a keyed struct (like Lucee's returntype="struct").
	 * columnKey value becomes the struct key; last row wins for duplicates.
	 * columnKey IS included in value structs (matches Lucee behavior).
	 *
	 * @data The array of structs to convert
	 * @columnKey Column whose values become the struct keys
	 * @valueKeys Optional array of columns to include in values (omit for full row, single = scalar)
	 * @return struct Ordered struct keyed by columnKey values
	 */
	private struct function toKeyedStruct(
		required array data,
		required string columnKey,
		array valueKeys = []
	) {
		if ( !arguments.data.len() ) return {};

		// Fail fast: validate columnKey and valueKeys against actual result columns
		var availableColumns = arguments.data[ 1 ].keyArray();
		if ( !arguments.data[ 1 ].keyExists( arguments.columnKey ) ) {
			throw(
				type    = "QBML.InvalidColumnKey",
				message = "struct columnKey ""#arguments.columnKey#"" not found in result columns [#availableColumns.toList()#]. Check your select list."
			);
		}
		for ( var vk in arguments.valueKeys ) {
			if ( !arguments.data[ 1 ].keyExists( vk ) ) {
				throw(
					type    = "QBML.InvalidValueKey",
					message = "struct valueKey ""#vk#"" not found in result columns [#availableColumns.toList()#]. Check your select list."
				);
			}
		}

		var result = structNew( "ordered" );
		for ( var row in arguments.data ) {
			var key = toString( row[ arguments.columnKey ] );
			if ( !arguments.valueKeys.len() ) {
				result[ key ] = row;
			} else if ( arguments.valueKeys.len() == 1 ) {
				result[ key ] = row[ arguments.valueKeys[ 1 ] ];
			} else {
				var partial = structNew( "ordered" );
				for ( var vk in arguments.valueKeys ) {
					partial[ vk ] = row[ vk ];
				}
				result[ key ] = partial;
			}
		}
		return result;
	}

	/**
	 * Convert an array of structs to a native query object
	 */
	private query function arrayToQuery( required array data ) {
		if ( !arguments.data.len() ) {
			return queryNew( "" );
		}
		return queryNew( structKeyList( arguments.data[ 1 ] ), "", arguments.data );
	}

	/**
	 * Convert a query object to an array of ordered structs
	 */
	private array function queryToArray( required query q ) {
		if ( arguments.q.recordCount == 0 ) {
			return [];
		}

		var columnNames = getMetadata( arguments.q ).map( function( item ) {
			return item.name;
		} );

		var results = [];
		for ( var row in arguments.q ) {
			var rowData = structNew( "ordered" );
			for ( var column in columnNames ) {
				rowData[ column ] = row[ column ];
			}
			results.append( rowData );
		}
		return results;
	}

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
			if ( isValid( "integer", arguments.val ) && !find( ".", strVal ) ) {
				if ( abs( arguments.val ) > 2147483647 ) {
					return "bigint";
				}
				return "integer";
			}
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
