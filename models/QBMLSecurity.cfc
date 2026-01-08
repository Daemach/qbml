/**
 * QBML Security Service
 * Handles table access control and input validation
 *
 * Security patterns are organized into categories for maintainability.
 * Uses compiled regex patterns for O(1)-like performance.
 */
component accessors="true" singleton {

	property name="settings" type="struct";

	// ============================================
	// DANGEROUS SQL PATTERNS (Organized by Category)
	// ============================================

	// DDL/DML statements that should never appear in raw expressions
	// Both standalone and stacked query forms
	variables.statementPatterns = [
		// Stacked queries (with semicolon)
		";\s*(?:DROP|DELETE|TRUNCATE|ALTER|CREATE|INSERT|UPDATE|MERGE)",
		";\s*(?:EXEC|EXECUTE|CALL)",
		";\s*(?:GRANT|REVOKE|DENY)",
		";\s*(?:SET|DECLARE|USE)",
		// Standalone DDL (should never appear in raw expressions)
		"\b(?:DROP|TRUNCATE|ALTER|CREATE)\s+(?:TABLE|DATABASE|INDEX|VIEW|PROCEDURE|FUNCTION)",
		"\bDELETE\s+FROM\b",
		"\bINSERT\s+INTO\b",
		"\bUPDATE\s+\w+\s+SET\b"
	];

	// SQL comment syntax (used for injection bypasses)
	variables.commentPatterns = [
		"--",
		"/\*"
		// Note: MySQL # comments intentionally not blocked as they conflict
		// with CSS hex colors and are less common in SQL injection
	];

	// SQL Server specific dangerous procedures/functions
	variables.sqlServerPatterns = [
		"xp_\w+",                    // Extended stored procedures (xp_cmdshell, xp_regread, etc.)
		"\bsp_executesql\b",         // Dynamic SQL execution
		"\bsp_sqlexec\b",            // Dynamic SQL execution (alternative)
		"OPENROWSET\s*\(",           // External data access
		"OPENDATASOURCE\s*\(",       // External data access
		"OPENQUERY\s*\(",            // Linked server queries
		"BULK\s+INSERT",             // Bulk data operations
		"bcp\b"                      // Bulk copy
	];

	// MySQL specific dangerous functions
	variables.mysqlPatterns = [
		"LOAD_FILE\s*\(",            // Read server files
		"INTO\s+(OUT|DUMP)FILE",     // Write to server filesystem
		"LOAD\s+DATA\s+(?:LOCAL\s+)?INFILE",  // Load data from files
		"BENCHMARK\s*\(",            // Time-based attacks
		"SLEEP\s*\("                 // Time-based attacks
	];

	// PostgreSQL specific dangerous functions
	variables.postgresPatterns = [
		"pg_read_file\s*\(",         // Read server files
		"pg_read_binary_file\s*\(",  // Read binary files
		"pg_ls_dir\s*\(",            // List directories
		"pg_stat_file\s*\(",         // File stats
		"lo_import\s*\(",            // Large object import
		"lo_export\s*\(",            // Large object export
		"COPY\s+.*\s+(?:FROM|TO)\s"  // COPY command
	];

	// Oracle specific dangerous functions
	variables.oraclePatterns = [
		"UTL_FILE\.",                // File operations
		"UTL_HTTP\.",                // HTTP requests
		"UTL_TCP\.",                 // TCP connections
		"UTL_SMTP\.",                // Email operations
		"DBMS_XMLGEN\.",             // XML generation (can leak data)
		"DBMS_LDAP\.",               // LDAP operations
		"DBMS_JAVA\."                // Java execution
	];

	// Time-based and out-of-band attack patterns
	variables.timingPatterns = [
		"WAITFOR\s+DELAY",           // SQL Server timing
		"pg_sleep\s*\(",             // PostgreSQL timing
		"DBMS_LOCK\.SLEEP",          // Oracle timing
		"DBMS_PIPE\.RECEIVE_MESSAGE" // Oracle timing alternative
	];

	// Stacked query and union-based injection markers
	variables.injectionPatterns = [
		";\s*SELECT",                // Stacked query attempt
		"UNION\s+(?:ALL\s+)?SELECT", // Union injection (when not legitimate)
		"INTO\s+@",                  // Variable assignment attempts
		"@@\w+",                     // Server variables access
		"INFORMATION_SCHEMA\.",      // Schema reconnaissance
		"sys\.\w+",                  // System tables access
		"mysql\.\w+",                // MySQL system tables
		"pg_catalog\.",              // PostgreSQL system catalogs
		"master\.\.sysdatabases",    // SQL Server system tables
		"msdb\.\."                   // SQL Server system database
	];

	// Hex/Unicode encoding bypass attempts
	variables.encodingPatterns = [
		"0x[0-9a-fA-F]{2,}",         // Hex strings (potential encoded payloads)
		"CHAR\s*\(\s*(?:0x|[0-9]{2,3})", // CHAR encoding bypass
		"CONCAT\s*\([^)]*CHAR\s*\(", // Concatenated CHAR bypass
		"CHR\s*\(\s*[0-9]"           // Oracle CHR function
	];

	/**
	 * Constructor
	 * @settings Module settings
	 */
	function init( struct settings = {} ) {
		variables.settings = arguments.settings;

		// Build combined pattern array for validation
		variables.allDangerousPatterns = [];
		variables.allDangerousPatterns.append( variables.statementPatterns, true );
		variables.allDangerousPatterns.append( variables.commentPatterns, true );
		variables.allDangerousPatterns.append( variables.sqlServerPatterns, true );
		variables.allDangerousPatterns.append( variables.mysqlPatterns, true );
		variables.allDangerousPatterns.append( variables.postgresPatterns, true );
		variables.allDangerousPatterns.append( variables.oraclePatterns, true );
		variables.allDangerousPatterns.append( variables.timingPatterns, true );
		variables.allDangerousPatterns.append( variables.injectionPatterns, true );
		variables.allDangerousPatterns.append( variables.encodingPatterns, true );

		// Build O(1) keyword lookup for fast pre-screening
		// If expression doesn't contain any of these, skip expensive regex
		variables.dangerousKeywords = buildKeywordMap();

		return this;
	}

	/**
	 * Build a map of dangerous keywords for fast pre-screening
	 * @return struct Map of lowercase keywords
	 */
	private struct function buildKeywordMap() {
		var keywords = {};
		var keywordList = [
			// Statements
			"drop", "delete", "truncate", "alter", "create", "insert", "update", "merge",
			"exec", "execute", "call", "grant", "revoke", "deny", "set", "declare", "use",
			// SQL Server
			"xp_", "sp_", "openrowset", "opendatasource", "openquery", "bulk",
			// MySQL
			"load_file", "outfile", "dumpfile", "infile", "benchmark", "sleep",
			// PostgreSQL
			"pg_read", "pg_ls_dir", "pg_stat", "lo_import", "lo_export", "copy",
			// Oracle
			"utl_file", "utl_http", "utl_tcp", "utl_smtp", "dbms_",
			// Comments
			"--", "/*",
			// Timing
			"waitfor", "pg_sleep", "receive_message",
			// Injection markers
			"union", "information_schema", "@@", "sys.", "mysql.", "pg_catalog", "master..", "msdb..",
			// Encoding
			"0x", "char(", "chr("
		];

		for ( var kw in keywordList ) {
			keywords[ lCase( kw ) ] = true;
		}

		return keywords;
	}

	/**
	 * Validate a table reference against security rules
	 * @table The table name/path to validate
	 * @cteAliases Array of CTE aliases defined in the current query (always allowed)
	 * @return struct { valid: boolean, resolved: string, message: string }
	 */
	struct function validateTable( required string table, array cteAliases = [] ) {
		var tableName = trim( arguments.table );

		// Extract just the table name (remove alias if present)
		var parts     = tableName.listToArray( " " );
		var baseName  = parts[ 1 ];
		var alias     = parts.len() > 1 ? parts[ parts.len() ] : "";

		// CTE aliases are always allowed
		if ( arguments.cteAliases.findNoCase( baseName ) ) {
			return { valid : true, resolved : tableName, message : "" };
		}

		// Check table aliases first
		var aliases = variables.settings.aliases ?: {};
		if ( aliases.keyExists( baseName ) ) {
			var resolved = aliases[ baseName ];
			if ( len( alias ) ) {
				resolved &= " " & alias;
			}
			return { valid : true, resolved : resolved, message : "" };
		}

		// Get table config with new { mode, list } structure
		var tableConfig = variables.settings.tables ?: { mode : "none", list : [] };
		var mode        = tableConfig.mode ?: "none";
		var tableList   = tableConfig.list ?: [];

		// No restrictions mode - all tables allowed
		if ( mode == "none" ) {
			return { valid : true, resolved : tableName, message : "" };
		}

		var inList = matchesPattern( baseName, tableList );

		if ( mode == "allow" ) {
			// Only explicitly listed tables are allowed
			if ( inList ) {
				return { valid : true, resolved : tableName, message : "" };
			}
			return {
				valid    : false,
				resolved : "",
				message  : "Table '#baseName#' is not in the allowed tables list"
			};
		} else if ( mode == "block" ) {
			// All tables allowed except those listed
			if ( inList ) {
				return {
					valid    : false,
					resolved : "",
					message  : "Table '#baseName#' is blocked"
				};
			}
			return { valid : true, resolved : tableName, message : "" };
		}

		// Default: allow
		return { valid : true, resolved : tableName, message : "" };
	}

	/**
	 * Validate an action against security rules
	 * @action The action name to validate
	 * @return struct { valid: boolean, message: string }
	 */
	struct function validateAction( required string action ) {
		var actionConfig = variables.settings.actions ?: { mode : "none", list : [] };
		var mode         = actionConfig.mode ?: "none";
		var actionList   = actionConfig.list ?: [];

		if ( mode == "none" ) {
			return { valid : true, message : "" };
		}

		var inList = matchesPattern( arguments.action, actionList );

		if ( mode == "allow" ) {
			if ( inList ) {
				return { valid : true, message : "" };
			}
			return {
				valid   : false,
				message : "Action '#arguments.action#' is not in the allowed actions list"
			};
		} else if ( mode == "block" ) {
			if ( inList ) {
				return {
					valid   : false,
					message : "Action '#arguments.action#' is blocked"
				};
			}
			return { valid : true, message : "" };
		}

		return { valid : true, message : "" };
	}

	/**
	 * Validate an executor against security rules
	 * @executor The executor name to validate
	 * @return struct { valid: boolean, message: string }
	 */
	struct function validateExecutor( required string executor ) {
		var executorConfig = variables.settings.executors ?: { mode : "none", list : [] };
		var mode           = executorConfig.mode ?: "none";
		var executorList   = executorConfig.list ?: [];

		if ( mode == "none" ) {
			return { valid : true, message : "" };
		}

		var inList = matchesPattern( arguments.executor, executorList );

		if ( mode == "allow" ) {
			if ( inList ) {
				return { valid : true, message : "" };
			}
			return {
				valid   : false,
				message : "Executor '#arguments.executor#' is not in the allowed executors list"
			};
		} else if ( mode == "block" ) {
			if ( inList ) {
				return {
					valid   : false,
					message : "Executor '#arguments.executor#' is blocked"
				};
			}
			return { valid : true, message : "" };
		}

		return { valid : true, message : "" };
	}

	/**
	 * Check if an item matches any pattern in a list
	 * Supports wildcards: "schema.*", "*.tableName", "exact.match", "*Raw"
	 * @item The item to check (table name, action name, executor name)
	 * @list Array of patterns
	 * @return boolean
	 */
	private boolean function matchesPattern( required string item, required array list ) {
		for ( var pattern in arguments.list ) {
			// Exact match (case-insensitive)
			if ( arguments.item == pattern || compareNoCase( arguments.item, pattern ) == 0 ) {
				return true;
			}

			// Wildcard matching
			if ( pattern contains "*" ) {
				var regex = pattern
					.replace( ".", "\.", "all" )
					.replace( "*", ".*", "all" );
				if ( reFindNoCase( "^#regex#$", arguments.item ) ) {
					return true;
				}
			}
		}
		return false;
	}

	/**
	 * Validate a raw SQL expression for dangerous patterns
	 *
	 * Uses a two-phase approach for performance:
	 * 1. Fast keyword pre-screening (O(1) per keyword)
	 * 2. Detailed regex validation only if keywords found
	 *
	 * @expression The raw SQL expression
	 * @return struct { valid: boolean, message: string, pattern: string }
	 */
	struct function validateRawExpression( required string expression ) {
		var expr      = trim( arguments.expression );
		var exprLower = lCase( expr );

		// Phase 1: Fast keyword pre-screening
		// Check if any dangerous keyword is present
		var hasPotentialThreat = false;
		for ( var keyword in variables.dangerousKeywords.keyArray() ) {
			if ( exprLower contains keyword ) {
				hasPotentialThreat = true;
				break;
			}
		}

		// If no dangerous keywords found, expression is safe
		if ( !hasPotentialThreat ) {
			return { valid : true, message : "", pattern : "" };
		}

		// Phase 2: Detailed regex validation
		for ( var pattern in variables.allDangerousPatterns ) {
			if ( reFindNoCase( pattern, expr ) ) {
				return {
					valid   : false,
					message : "Raw expression contains potentially dangerous SQL pattern",
					pattern : pattern
				};
			}
		}

		return { valid : true, message : "", pattern : "" };
	}

	/**
	 * Get all dangerous patterns (for testing/debugging)
	 * @return array All pattern arrays
	 */
	struct function getDangerousPatterns() {
		return {
			statements : variables.statementPatterns,
			comments   : variables.commentPatterns,
			sqlServer  : variables.sqlServerPatterns,
			mysql      : variables.mysqlPatterns,
			postgres   : variables.postgresPatterns,
			oracle     : variables.oraclePatterns,
			timing     : variables.timingPatterns,
			injection  : variables.injectionPatterns,
			encoding   : variables.encodingPatterns
		};
	}

	/**
	 * Validate an entire QBML query array for security issues
	 * @queryArray The QBML query array
	 * @return struct { valid: boolean, message: string }
	 */
	struct function validateQuery( required array queryArray ) {
		return validateQueryRecursive( arguments.queryArray, [] );
	}

	/**
	 * Recursively validate query array
	 * @queryArray The query array to validate
	 * @cteAliases Accumulated CTE aliases
	 * @return struct { valid: boolean, message: string }
	 */
	private struct function validateQueryRecursive( required array queryArray, array cteAliases = [] ) {
		// First pass: collect CTE aliases
		var cteDefs = arguments.cteAliases.duplicate();
		for ( var item in arguments.queryArray ) {
			if ( isStruct( item ) ) {
				if ( item.keyExists( "with" ) ) {
					cteDefs.append( item.with );
				}
				if ( item.keyExists( "withRecursive" ) ) {
					cteDefs.append( item.withRecursive );
				}
			}
		}

		// Second pass: validate each item
		for ( var item in arguments.queryArray ) {
			if ( !isStruct( item ) ) continue;

			// Validate table references
			if ( item.keyExists( "from" ) ) {
				var tableVal = isArray( item.from ) ? item.from[ 1 ] : item.from;
				var result   = validateTable( tableVal, cteDefs );
				if ( !result.valid ) {
					return result;
				}
			}

			// Validate raw expressions
			var rawKeys = [
				"selectRaw",
				"whereRaw",
				"andWhereRaw",
				"orWhereRaw",
				"havingRaw",
				"orderByRaw"
			];
			for ( var key in rawKeys ) {
				if ( item.keyExists( key ) ) {
					var rawVal = isArray( item[ key ] ) ? item[ key ][ 1 ] : item[ key ];
					var result = validateRawExpression( rawVal );
					if ( !result.valid ) {
						return result;
					}
				}
			}

			// Validate $raw inline references in all values
			for ( var key in item ) {
				var result = validateRawRefsInValue( item[ key ] );
				if ( !result.valid ) {
					return result;
				}
			}

			// Recursively validate nested queries
			if ( item.keyExists( "query" ) && isArray( item.query ) ) {
				var result = validateQueryRecursive( item.query, cteDefs );
				if ( !result.valid ) {
					return result;
				}
			}

			// Validate else clause queries
			if ( item.keyExists( "else" ) ) {
				var elseItems = isArray( item.else ) ? item.else : [ item.else ];
				var result    = validateQueryRecursive( elseItems, cteDefs );
				if ( !result.valid ) {
					return result;
				}
			}

			// Validate nested clauses
			if ( item.keyExists( "clauses" ) && isArray( item.clauses ) ) {
				var result = validateQueryRecursive( item.clauses, cteDefs );
				if ( !result.valid ) {
					return result;
				}
			}
		}

		return { valid : true, message : "" };
	}

	/**
	 * Recursively validate $raw references within a value
	 *
	 * This catches inline $raw expressions like:
	 *   { "select": [{ "$raw": "COUNT(*)" }, "name"] }
	 *   { "whereIn": ["status", { "$raw": "dangerous SQL" }] }
	 *
	 * @value The value to check for $raw references
	 * @return struct { valid: boolean, message: string }
	 */
	private struct function validateRawRefsInValue( required any value ) {
		// Direct $raw reference: validate the SQL
		if ( isStruct( arguments.value ) && arguments.value.keyExists( "$raw" ) ) {
			var rawDef = arguments.value[ "$raw" ];
			var sql    = "";

			// Extract SQL from string or object form
			if ( isSimpleValue( rawDef ) ) {
				sql = rawDef;
			} else if ( isStruct( rawDef ) && rawDef.keyExists( "sql" ) ) {
				sql = rawDef.sql;
			} else {
				return {
					valid   : false,
					message : "$raw must be a string or an object with 'sql' key"
				};
			}

			// Validate the raw SQL expression
			return validateRawExpression( sql );
		}

		// Array: check each element
		if ( isArray( arguments.value ) ) {
			for ( var item in arguments.value ) {
				var result = validateRawRefsInValue( item );
				if ( !result.valid ) {
					return result;
				}
			}
		}

		// Struct: check each value (recursively)
		if ( isStruct( arguments.value ) ) {
			for ( var key in arguments.value ) {
				var result = validateRawRefsInValue( arguments.value[ key ] );
				if ( !result.valid ) {
					return result;
				}
			}
		}

		return { valid : true, message : "" };
	}

	/**
	 * Validate an identifier (column name, alias, etc.)
	 * @identifier The identifier to validate
	 * @return boolean
	 */
	boolean function isValidIdentifier( required string identifier ) {
		// Allow: letters, numbers, underscore, dot (for schema.table), and common chars
		return reFindNoCase( "^[a-zA-Z_][a-zA-Z0-9_\.]*$", trim( arguments.identifier ) ) > 0;
	}

}
