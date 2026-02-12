/**
 * QBML - Query Builder Markup Language
 * Translates JSON query definitions into QB queries
 *
 * @author John Wilson
 */
component accessors="true" singleton {

	// Dependencies
	property name="qb"         inject="provider:QueryBuilder@qb";
	property name="security"   inject="QBMLSecurity@qbml";
	property name="conditions" inject="QBMLConditions@qbml";
	property name="formatter"  inject="ReturnFormat@qbml";

	// Settings
	property name="settings" type="struct";

	// Base QB actions (core methods without and/or/not variants)
	// The and/or prefixes are dynamically handled via normalizeAction()
	variables.baseActions = [
		// CTEs
		"with", "withRecursive",
		// Selection
		"select", "addSelect", "distinct", "selectRaw", "subSelect",
		// Source
		"from", "fromSub", "fromRaw", "table",
		// Joins
		"join", "innerJoin", "leftJoin", "rightJoin",
		"leftOuterJoin", "rightOuterJoin", "crossJoin",
		"joinSub", "leftJoinSub", "rightJoinSub",
		"joinRaw", "leftJoinRaw", "rightJoinRaw",
		// Join conditions (support and/or)
		"on",
		// Where conditions (support and/or/not)
		"where", "whereIn", "whereBetween", "whereLike", "whereNull",
		"whereColumn", "whereExists", "whereRaw",
		// Grouping (having supports and/or)
		"groupBy", "having", "havingRaw",
		// Ordering
		"orderBy", "orderByDesc", "orderByAsc", "orderByRaw", "reorder", "clearOrders",
		// Limiting
		"limit", "take", "offset", "skip", "forPage",
		// Locks
		"lock", "lockForUpdate", "sharedLock", "noLock", "clearLock",
		// Unions
		"union", "unionAll",
		// Aggregates (as select helpers)
		"selectCount", "selectSum", "selectAvg", "selectMin", "selectMax"
	];

	// Actions that support and/or combinator prefixes
	variables.combinatorActions = {
		"where"       : true,
		"whereIn"     : true,
		"whereBetween": true,
		"whereLike"   : true,
		"whereNull"   : true,
		"whereColumn" : true,
		"whereExists" : true,
		"whereRaw"    : true,
		"having"      : true,
		"on"          : true
	};

	// Actions that support not negation (whereNotIn, whereNotNull, etc.)
	variables.negatableActions = {
		"whereIn"     : true,
		"whereBetween": true,
		"whereLike"   : true,
		"whereNull"   : true,
		"whereExists" : true
	};

	// Executors (methods that terminate the query and return results)
	variables.executors = [
		"get", "first", "find", "value", "values",
		"count", "sum", "avg", "min", "max", "exists",
		"paginate", "simplePaginate",
		"toSQL", "dump"
	];

	/**
	 * Constructor
	 * @settings Module settings
	 */
	function init( struct settings = {} ) {
		variables.settings = arguments.settings;

		// Build O(1) lookup map from base actions + generated variants
		variables.actionsMap = {};

		// Add base actions
		for ( var action in variables.baseActions ) {
			variables.actionsMap[ lCase( action ) ] = true;
		}

		// Generate combinator variants (andWhere, orWhere, etc.)
		for ( var action in variables.combinatorActions.keyArray() ) {
			variables.actionsMap[ lCase( "and" & action ) ] = true;
			variables.actionsMap[ lCase( "or" & action ) ] = true;
		}

		// Generate negatable variants (whereNotIn, whereNotNull, etc.)
		for ( var action in variables.negatableActions.keyArray() ) {
			// Base negated form (whereNotIn)
			var negated = generateNegatedAction( action );
			variables.actionsMap[ lCase( negated ) ] = true;
			// Combinator + negated forms (andWhereNotIn, orWhereNotIn)
			variables.actionsMap[ lCase( "and" & negated ) ] = true;
			variables.actionsMap[ lCase( "or" & negated ) ] = true;
		}

		// Build base actions map for quick lookup during normalization
		variables.baseActionsMap = {};
		for ( var action in variables.baseActions ) {
			variables.baseActionsMap[ lCase( action ) ] = action;
		}

		// Build executors map
		variables.executorsMap = {};
		for ( var executor in variables.executors ) {
			variables.executorsMap[ lCase( executor ) ] = true;
		}

		return this;
	}

	/**
	 * Generate negated action name (whereIn -> whereNotIn)
	 * @action The base action name
	 * @return string The negated action name
	 */
	private string function generateNegatedAction( required string action ) {
		// Insert "Not" after "where" prefix
		if ( arguments.action.left( 5 ) == "where" ) {
			return "whereNot" & arguments.action.mid( 6, arguments.action.len() - 5 );
		}
		return arguments.action;
	}

	/**
	 * Check if a key is a valid action (O(1) lookup)
	 * @key The key to check
	 * @return boolean
	 */
	boolean function isValidAction( required string key ) {
		return variables.actionsMap.keyExists( lCase( arguments.key ) );
	}

	/**
	 * Check if a key is a valid executor (O(1) lookup)
	 * @key The key to check
	 * @return boolean
	 */
	boolean function isValidExecutor( required string key ) {
		return variables.executorsMap.keyExists( lCase( arguments.key ) );
	}

	/**
	 * Normalize an action to extract base action, combinator, and negation
	 *
	 * Examples:
	 *   "andWhereNotIn" -> { baseAction: "whereIn", combinator: "and", negated: true, qbMethod: "andWhereNotIn" }
	 *   "orWhere"       -> { baseAction: "where", combinator: "or", negated: false, qbMethod: "orWhere" }
	 *   "whereNull"     -> { baseAction: "whereNull", combinator: "", negated: false, qbMethod: "whereNull" }
	 *   "whereNotNull"  -> { baseAction: "whereNull", combinator: "", negated: true, qbMethod: "whereNotNull" }
	 *
	 * @action The action name to normalize
	 * @return struct { baseAction, combinator, negated, qbMethod }
	 */
	struct function normalizeAction( required string action ) {
		var result = {
			"baseAction": arguments.action,
			"combinator": "",
			"negated"   : false,
			"qbMethod"  : arguments.action
		};

		var actionLower = lCase( arguments.action );
		var workingAction = arguments.action;

		// Step 1: Extract and/or combinator prefix
		// Note: Be careful not to match "orderBy" as "or" + "derBy"
		// The combinator prefix must be followed by an uppercase letter (indicating camelCase)
		if ( actionLower.left( 3 ) == "and" && arguments.action.len() > 3 && reFind( "^[A-Z]", arguments.action.mid( 4, 1 ) ) ) {
			result.combinator = "and";
			workingAction = workingAction.mid( 4, workingAction.len() - 3 );
		} else if ( actionLower.left( 2 ) == "or" && arguments.action.len() > 2 && reFind( "^[A-Z]", arguments.action.mid( 3, 1 ) ) ) {
			result.combinator = "or";
			workingAction = workingAction.mid( 3, workingAction.len() - 2 );
		}

		// Step 2: Check for "Not" negation in where actions
		var workingLower = lCase( workingAction );
		if ( workingLower.left( 8 ) == "wherenot" && workingLower != "wherenull" ) {
			result.negated = true;
			// Reconstruct base action without "Not": whereNotIn -> whereIn
			var suffix = workingAction.mid( 9, workingAction.len() - 8 );
			workingAction = "where" & suffix;
		}

		// Step 3: Set the base action
		result.baseAction = workingAction;

		return result;
	}

	/**
	 * Execute a QBML query definition
	 * @queryDef The QBML query array
	 * @options Execution options:
	 *          - params: struct of parameter values for $param references and param-based when conditions
	 *          - returnFormat: "array" (default), "tabular", "query", or ["struct", columnKey, valueKeys?] - overrides config and query definition
	 *          - datasource: string - database datasource to use
	 *          - timeout: number - query timeout in seconds
	 * @return any Query results (format depends on executor and returnFormat option)
	 */
	any function execute( required array queryDef, struct options = {} ) {
		// Validate security
		var validation = variables.security.validateQuery( arguments.queryDef );
		if ( !validation.valid ) {
			throw( type = "QBML.SecurityViolation", message = validation.message );
		}

		// Parse executor from query definition
		var executor = parseExecutor( arguments.queryDef );

		// Validate executor against security rules
		var executorResult = variables.security.validateExecutor( executor.action );
		if ( !executorResult.valid ) {
			throw( type = "QBML.ExecutorNotAllowed", message = executorResult.message );
		}

		// Extract params from options
		var params = arguments.options.keyExists( "params" ) ? arguments.options.params : {};

		// Build the query with params
		var query = build( arguments.queryDef, params );

		// Execute with merged options
		return executeQuery( query, executor, arguments.options );
	}

	/**
	 * Build a QB query from QBML definition without executing
	 * Useful for inspection or further modification
	 * @queryDef The QBML query array
	 * @params Optional struct of parameter values for $param references and param-based when conditions
	 * @return QueryBuilder instance
	 */
	any function build( required array queryDef, struct params = {} ) {
		var q = variables.qb.newQuery();

		// Collect CTE aliases for table validation
		var cteAliases = collectCTEAliases( arguments.queryDef );

		// Process CTEs first
		q = processCTEs( q, arguments.queryDef, cteAliases, arguments.params );

		// Filter out CTEs and executor items for main processing
		var mainQuery = arguments.queryDef.filter( function( item ) {
			if ( !isStruct( item ) ) return false;

			// Exclude CTE definitions
			if ( item.keyExists( "with" ) || item.keyExists( "withRecursive" ) ) {
				return false;
			}

			// Exclude executor items
			for ( var key in item ) {
				if ( isValidExecutor( key ) ) {
					return false;
				}
			}

			return true;
		} );

		// Process the main query with params
		return processBlock( q, mainQuery, cteAliases, arguments.params );
	}

	/**
	 * Convert QBML to SQL string without executing
	 * @queryDef The QBML query array
	 * @params Optional struct of parameter values for $param references
	 * @return string SQL statement
	 */
	string function toSQL( required array queryDef, struct params = {} ) {
		return build( arguments.queryDef, arguments.params ).toSQL();
	}

	/**
	 * Process a block of QBML actions
	 * @q QueryBuilder instance
	 * @block Array of action items
	 * @cteAliases Array of defined CTE aliases
	 * @params Struct of parameter values for $param references and when conditions
	 * @return QueryBuilder
	 */
	private any function processBlock(
		required any q,
		required array block,
		array cteAliases = [],
		struct params = {}
	) {
		for ( var item in arguments.block ) {
			if ( !isStruct( item ) ) continue;

			var extracted = extractAction( item );
			if ( !extracted.hasAction ) continue;

			var action = extracted.action;

			// Resolve $param references in the value before converting to args
			var resolvedValue = resolveParamRefs( extracted.value, arguments.params );

			// Resolve $raw references (converts { "$raw": "sql" } to qb Expression objects)
			if ( containsRawRefs( resolvedValue ) ) {
				resolvedValue = resolveRawRefs( resolvedValue, arguments.q );
			}

			var args = toArgsArray( resolvedValue, action );

			// Handle "when" conditional wrapper
			if ( item.keyExists( "when" ) ) {
				var shouldApply = variables.conditions.evaluate( item.when, args, arguments.params );
				if ( !shouldApply ) {
					// Process else clause if present
					if ( item.keyExists( "else" ) ) {
						var elseItems = isArray( item.else ) ? item.else : [ item.else ];
						arguments.q   = processBlock( arguments.q, elseItems, arguments.cteAliases, arguments.params );
					}
					continue;
				}
			}

			// Process the action
			arguments.q = processAction( arguments.q, item, action, args, arguments.cteAliases, arguments.params );
		}

		return arguments.q;
	}

	/**
	 * Process a single action using normalized action dispatch
	 *
	 * Uses normalizeAction() to determine the base action type, then routes
	 * to the appropriate handler. The original action name (with combinator/negation)
	 * is passed to qb methods since qb handles these variants natively.
	 */
	private any function processAction(
		required any q,
		required struct item,
		required string action,
		required array args,
		array cteAliases = [],
		struct params = {}
	) {
		// Validate action against security rules
		var actionResult = variables.security.validateAction( arguments.action );
		if ( !actionResult.valid ) {
			throw( type = "QBML.ActionNotAllowed", message = actionResult.message );
		}

		// Normalize action to get base type for routing
		var normalized = normalizeAction( arguments.action );
		var baseAction = lCase( normalized.baseAction );

		switch ( baseAction ) {
			// === SOURCE ===
			case "from":
			case "table":
				var tableResult = variables.security.validateTable( arguments.args[ 1 ], arguments.cteAliases );
				if ( !tableResult.valid ) {
					throw( type = "QBML.InvalidTable", message = tableResult.message );
				}
				return arguments.q.from( tableResult.resolved );

			case "fromsub":
				return processFromSub( arguments.q, arguments.item, arguments.cteAliases, arguments.params );

			case "fromraw":
				var rawResult = variables.security.validateRawExpression( arguments.args[ 1 ] );
				if ( !rawResult.valid ) {
					throw( type = "QBML.InvalidRawExpression", message = rawResult.message );
				}
				return arguments.q.fromRaw( arguments.args[ 1 ] );

			// === SELECTION ===
			case "select":
				return arguments.q.select( arguments.args );

			case "addselect":
				return arguments.q.addSelect( arguments.args );

			case "distinct":
				return arguments.q.distinct();

			case "selectraw":
				var rawResult = variables.security.validateRawExpression( arguments.args[ 1 ] );
				if ( !rawResult.valid ) {
					throw( type = "QBML.InvalidRawExpression", message = rawResult.message );
				}
				if ( arguments.args.len() >= 2 && isArray( arguments.args[ 2 ] ) ) {
					return arguments.q.selectRaw( arguments.args[ 1 ], arguments.args[ 2 ] );
				}
				return arguments.q.selectRaw( arguments.args[ 1 ] );

			case "subselect":
				return processSubSelect( arguments.q, arguments.item, arguments.cteAliases, arguments.params );

			// === JOINS ===
			case "join":
			case "innerjoin":
				return processJoin( arguments.q, arguments.item, "join", arguments.cteAliases, arguments.params );

			case "leftjoin":
				return processJoin( arguments.q, arguments.item, "leftJoin", arguments.cteAliases, arguments.params );

			case "rightjoin":
				return processJoin( arguments.q, arguments.item, "rightJoin", arguments.cteAliases, arguments.params );

			case "leftouterjoin":
				return processJoin( arguments.q, arguments.item, "leftOuterJoin", arguments.cteAliases, arguments.params );

			case "rightouterjoin":
				return processJoin( arguments.q, arguments.item, "rightOuterJoin", arguments.cteAliases, arguments.params );

			case "crossjoin":
				var tableResult = variables.security.validateTable( arguments.args[ 1 ], arguments.cteAliases );
				if ( !tableResult.valid ) {
					throw( type = "QBML.InvalidTable", message = tableResult.message );
				}
				return arguments.q.crossJoin( tableResult.resolved );

			case "joinsub":
			case "leftjoinsub":
			case "rightjoinsub":
				return processJoinSub( arguments.q, arguments.item, arguments.action, arguments.cteAliases, arguments.params );

			case "joinraw":
			case "leftjoinraw":
			case "rightjoinraw":
				return processJoinRaw( arguments.q, arguments.action, arguments.args );

			// === WHERE CONDITIONS (dynamic via normalizeAction) ===
			case "where":
				// Legacy syntax: { "where": true, "clauses": [...] }
				if ( arguments.item.keyExists( "clauses" ) && isArray( arguments.item.clauses ) ) {
					return processNestedWhere( arguments.q, arguments.action, arguments.item.clauses, arguments.cteAliases, arguments.params );
				}
				// New syntax: { "where": [{ "where": [...] }, { "orWhere": [...] }] }
				// Detect nested clauses: array where first element is a struct
				if ( arguments.args.len() && isArray( arguments.args ) && arguments.args.len() > 0 && isStruct( arguments.args[ 1 ] ) ) {
					return processNestedWhere( arguments.q, arguments.action, arguments.args, arguments.cteAliases, arguments.params );
				}
				return applyWhere( arguments.q, arguments.action, arguments.args );

			// whereIn (handles whereIn, whereNotIn, andWhereIn, orWhereIn, etc.)
			case "wherein":
				return arguments.q[ arguments.action ]( arguments.args[ 1 ], arguments.args[ 2 ] );

			// whereBetween (handles whereBetween, whereNotBetween, andWhereBetween, etc.)
			case "wherebetween":
				return arguments.q[ arguments.action ]( arguments.args[ 1 ], arguments.args[ 2 ], arguments.args[ 3 ] );

			// whereLike (handles whereLike, whereNotLike, andWhereLike, etc.)
			case "wherelike":
				return arguments.q[ arguments.action ]( arguments.args[ 1 ], arguments.args[ 2 ] );

			// whereNull (handles whereNull, whereNotNull, andWhereNull, etc.)
			case "wherenull":
				return arguments.q[ arguments.action ]( arguments.args[ 1 ] );

			// whereColumn (handles whereColumn, andWhereColumn, orWhereColumn)
			case "wherecolumn":
				return arguments.q[ arguments.action ]( arguments.args[ 1 ], arguments.args[ 2 ], arguments.args[ 3 ] );

			// whereExists (handles whereExists, whereNotExists, andWhereExists, etc.)
			case "whereexists":
				return processWhereExists( arguments.q, arguments.item, arguments.action, arguments.cteAliases, arguments.params );

			// whereRaw (handles whereRaw, andWhereRaw, orWhereRaw)
			case "whereraw":
				return processRaw( arguments.q, arguments.action, arguments.args );

			// === GROUPING ===
			case "groupby":
				return arguments.q.groupBy( arguments.args );

			// having (handles having, andHaving, orHaving)
			case "having":
				return arguments.q[ arguments.action ]( arguments.args[ 1 ], arguments.args[ 2 ], arguments.args[ 3 ] );

			case "havingraw":
				return processRaw( arguments.q, "havingRaw", arguments.args );

			// === ORDERING ===
			case "orderby":
				if ( arguments.args.len() >= 2 ) {
					return arguments.q.orderBy( arguments.args[ 1 ], arguments.args[ 2 ] );
				}
				return arguments.q.orderBy( arguments.args[ 1 ] );

			case "orderbydesc":
				return arguments.q.orderByDesc( arguments.args[ 1 ] );

			case "orderbyasc":
				return arguments.q.orderByAsc( arguments.args[ 1 ] );

			case "orderbyraw":
				return processRaw( arguments.q, "orderByRaw", arguments.args );

			case "reorder":
				return arguments.q.reorder();

			case "clearorders":
				return arguments.q.clearOrders();

			// === LIMITING ===
			case "limit":
			case "take":
				return arguments.q.limit( arguments.args[ 1 ] );

			case "offset":
			case "skip":
				return arguments.q.offset( arguments.args[ 1 ] );

			case "forpage":
				return arguments.q.forPage( arguments.args[ 1 ], arguments.args[ 2 ] );

			// === LOCKS ===
			case "lock":
				// Custom lock directive
				return arguments.q.lock( arguments.args[ 1 ] );

			case "lockforupdate":
				// Optional skipLocked parameter (default false)
				if ( arguments.args.len() >= 1 && isBoolean( arguments.args[ 1 ] ) ) {
					return arguments.q.lockForUpdate( arguments.args[ 1 ] );
				}
				return arguments.q.lockForUpdate();

			case "sharedlock":
				return arguments.q.sharedLock();

			case "nolock":
				return arguments.q.noLock();

			case "clearlock":
				return arguments.q.clearLock();

			// === UNIONS ===
			case "union":
			case "unionall":
				return processUnion( arguments.q, arguments.item, arguments.action, arguments.cteAliases, arguments.params );

			// === AGGREGATE SELECTS ===
			case "selectcount":
			case "selectsum":
			case "selectavg":
			case "selectmin":
			case "selectmax":
				if ( arguments.args.len() >= 2 ) {
					return arguments.q[ arguments.action ]( arguments.args[ 1 ], arguments.args[ 2 ] );
				}
				return arguments.q[ arguments.action ]( arguments.args[ 1 ] );

			// === CTEs ===
			case "with":
			case "withrecursive":
				// CTEs are processed separately in processCTEs, skip here
				return arguments.q;

			// === ON clauses for joins ===
			case "on":
				// Join on clauses are handled within processJoin, skip here
				return arguments.q;

			default:
				// Unknown action - skip
				return arguments.q;
		}
	}

	// ==================== HELPER METHODS ====================

	/**
	 * Extract the action and value from a QBML item
	 */
	private struct function extractAction( required struct item ) {
		for ( var key in arguments.item ) {
			if ( isValidAction( key ) ) {
				return { hasAction : true, action : key, value : arguments.item[ key ] };
			}
		}
		return { hasAction : false, action : "", value : "" };
	}

	/**
	 * Convert a value to an args array
	 * Supports both positional arrays, object-form arguments, and qb Expression objects
	 *
	 * @value The action value (array, struct, qb Expression, or simple value)
	 * @action Optional action name for object-form conversion
	 * @return array
	 */
	private array function toArgsArray( required any value, string action = "" ) {
		if ( isArray( arguments.value ) ) {
			return arguments.value;
		}

		// Handle qb Expression objects (from $raw resolution)
		// Expression objects are component instances, not simple structs
		if ( isObject( arguments.value ) ) {
			return [ arguments.value ];
		}

		if ( isStruct( arguments.value ) && len( arguments.action ) ) {
			return convertObjectToArgs( arguments.value, arguments.action );
		}
		if ( isSimpleValue( arguments.value ) && len( arguments.value ) ) {
			return [ arguments.value ];
		}
		return [];
	}

	/**
	 * Convert object-form arguments to positional array based on action signature
	 *
	 * Supported object forms:
	 *   where: { column, operator?, value } -> [column, operator, value] or [column, value]
	 *   whereIn/whereNotIn: { column, values } -> [column, values]
	 *   whereBetween: { column, start, end } -> [column, start, end]
	 *   whereLike: { column, value } -> [column, value]
	 *   whereNull: { column } -> [column]
	 *   whereColumn: { first, operator, second } -> [first, operator, second]
	 *   join: { table, first, operator?, second } -> [table, first, operator, second]
	 *   orderBy: { column, direction? } -> [column, direction]
	 *   having: { column, operator, value } -> [column, operator, value]
	 *   forPage: { page, size } -> [page, size]
	 *   limit/offset: { value } -> [value]
	 *
	 * @objectArgs The struct containing named arguments
	 * @action The action name
	 * @return array Positional arguments
	 */
	private array function convertObjectToArgs( required struct objectArgs, required string action ) {
		var args       = arguments.objectArgs;
		var actionType = lCase( arguments.action );

		// Normalize action type (strip and/or prefixes for matching)
		var baseAction = actionType
			.reReplace( "^(and|or)", "" )
			.reReplace( "^(where|having)", "" );
		if ( actionType.findNoCase( "where" ) || actionType.findNoCase( "having" ) ) {
			baseAction = actionType.reReplace( "^(and|or)", "" );
		}

		// WHERE variants: { column, operator?, value }
		if ( listFindNoCase( "where,andWhere,orWhere", actionType ) ) {
			if ( args.keyExists( "column" ) && args.keyExists( "value" ) ) {
				if ( args.keyExists( "operator" ) ) {
					return [ args.column, args.operator, args.value ];
				}
				return [ args.column, args.value ];
			}
		}

		// WHERE IN variants: { column, values }
		// Matches: whereIn, whereNotIn, andWhereIn, orWhereIn, andWhereNotIn, orWhereNotIn
		if ( reFindNoCase( "where(not)?in$", actionType ) ) {
			if ( args.keyExists( "column" ) && args.keyExists( "values" ) ) {
				return [ args.column, args.values ];
			}
		}

		// WHERE BETWEEN variants: { column, start, end }
		if ( actionType contains "wherebetween" ) {
			if ( args.keyExists( "column" ) && args.keyExists( "start" ) && args.keyExists( "end" ) ) {
				return [ args.column, args.start, args.end ];
			}
		}

		// WHERE LIKE variants: { column, value }
		if ( actionType contains "wherelike" ) {
			if ( args.keyExists( "column" ) && args.keyExists( "value" ) ) {
				return [ args.column, args.value ];
			}
		}

		// WHERE NULL variants: { column }
		if ( actionType contains "wherenull" ) {
			if ( args.keyExists( "column" ) ) {
				return [ args.column ];
			}
		}

		// WHERE COLUMN variants: { first, operator, second }
		if ( actionType contains "wherecolumn" ) {
			if ( args.keyExists( "first" ) && args.keyExists( "second" ) ) {
				var op = args.keyExists( "operator" ) ? args.operator : "=";
				return [ args.first, op, args.second ];
			}
		}

		// JOIN variants: { table, first, operator?, second }
		if ( actionType contains "join" && !( actionType contains "sub" ) ) {
			if ( args.keyExists( "table" ) ) {
				if ( args.keyExists( "first" ) && args.keyExists( "second" ) ) {
					var op = args.keyExists( "operator" ) ? args.operator : "=";
					return [ args.table, args.first, op, args.second ];
				}
				return [ args.table ];
			}
		}

		// ORDER BY: { column, direction? }
		if ( actionType == "orderby" ) {
			if ( args.keyExists( "column" ) ) {
				if ( args.keyExists( "direction" ) ) {
					return [ args.column, args.direction ];
				}
				return [ args.column ];
			}
		}

		// HAVING variants: { column, operator, value }
		if ( actionType contains "having" && !( actionType contains "raw" ) ) {
			if ( args.keyExists( "column" ) && args.keyExists( "value" ) ) {
				var op = args.keyExists( "operator" ) ? args.operator : "=";
				return [ args.column, op, args.value ];
			}
		}

		// FOR PAGE: { page, size }
		if ( actionType == "forpage" ) {
			if ( args.keyExists( "page" ) && args.keyExists( "size" ) ) {
				return [ args.page, args.size ];
			}
		}

		// LIMIT/OFFSET: { value }
		if ( listFindNoCase( "limit,take,offset,skip", actionType ) ) {
			if ( args.keyExists( "value" ) ) {
				return [ args.value ];
			}
		}

		// SELECT: { columns } or { column }
		if ( actionType == "select" || actionType == "addselect" ) {
			if ( args.keyExists( "columns" ) ) {
				return isArray( args.columns ) ? args.columns : [ args.columns ];
			}
			if ( args.keyExists( "column" ) ) {
				return [ args.column ];
			}
		}

		// GROUP BY: { columns } or { column }
		if ( actionType == "groupby" ) {
			if ( args.keyExists( "columns" ) ) {
				return isArray( args.columns ) ? args.columns : [ args.columns ];
			}
			if ( args.keyExists( "column" ) ) {
				return [ args.column ];
			}
		}

		// FROM/TABLE: { table } or { name }
		if ( listFindNoCase( "from,table", actionType ) ) {
			if ( args.keyExists( "table" ) ) {
				return [ args.table ];
			}
			if ( args.keyExists( "name" ) ) {
				return [ args.name ];
			}
		}

		// Raw variants: { sql, bindings? }
		if ( actionType contains "raw" ) {
			if ( args.keyExists( "sql" ) ) {
				if ( args.keyExists( "bindings" ) && isArray( args.bindings ) ) {
					return [ args.sql, args.bindings ];
				}
				return [ args.sql ];
			}
		}

		// Fallback: return empty array (will use original struct handling if needed)
		return [];
	}

	/**
	 * Collect CTE aliases from query definition
	 */
	private array function collectCTEAliases( required array queryDef ) {
		var aliases = [];
		for ( var item in arguments.queryDef ) {
			if ( isStruct( item ) ) {
				if ( item.keyExists( "with" ) ) {
					aliases.append( item.with );
				}
				if ( item.keyExists( "withRecursive" ) ) {
					aliases.append( item.withRecursive );
				}
			}
		}
		return aliases;
	}

	/**
	 * Parse executor from query definition
	 */
	private struct function parseExecutor( required array queryDef ) {
		var result = { action : "get", args : [], options : {} };

		for ( var item in arguments.queryDef ) {
			if ( !isStruct( item ) ) continue;

			for ( var key in item ) {
				if ( isValidExecutor( key ) ) {
					var val       = item[ key ];
					result.action = key;

					if ( isStruct( val ) ) {
						// Pagination options
						if ( val.keyExists( "page" ) ) result.page = val.page;
						if ( val.keyExists( "maxRows" ) ) result.maxRows = val.maxRows;
						if ( val.keyExists( "size" ) ) result.size = val.size;
						// Return format options
						if ( val.keyExists( "returnFormat" ) ) result.returnFormat = val.returnFormat;
					} else if ( isArray( val ) ) {
						result.args = val;
					} else if ( isSimpleValue( val ) && val != true && val != "true" ) {
						result.args = [ val ];
					}

					// Extract execution options
					if ( item.keyExists( "datasource" ) ) result.options.datasource = item.datasource;
					if ( item.keyExists( "timeout" ) ) result.options.timeout = item.timeout;
					if ( item.keyExists( "username" ) ) result.options.username = item.username;
					if ( item.keyExists( "password" ) ) result.options.password = item.password;

					return result;
				}
			}
		}

		return result;
	}

	/**
	 * Execute the query with options
	 */
	private any function executeQuery( required any q, required struct executor, struct passedOptions = {} ) {
		// Build execution options
		var opts     = {};
		var defaults = variables.settings.defaults ?: {};
		var creds    = variables.settings.credentials ?: {};

		// Apply defaults
		if ( len( defaults.datasource ?: "" ) ) opts.datasource = defaults.datasource;
		if ( val( defaults.timeout ?: 0 ) ) opts.timeout = defaults.timeout;

		// Apply credentials if configured
		if ( len( creds.username ?: "" ) ) opts.username = creds.username;
		if ( len( creds.password ?: "" ) ) opts.password = creds.password;

		// Merge executor options (from QBML definition)
		if ( arguments.executor.keyExists( "options" ) ) {
			opts.append( arguments.executor.options, true );
		}

		// Merge passed options (from execute() call)
		opts.append( arguments.passedOptions, true );

		// Enforce max row limit for result-set executors (only if no limit already set)
		var maxRows            = val( defaults.maxRows ?: 10000 );
		var resultSetExecutors = { "get" : true, "first" : true, "find" : true };
		var currentLimit       = arguments.q.getLimitValue();
		if ( resultSetExecutors.keyExists( arguments.executor.action ) && maxRows > 0 && isNull( currentLimit ) ) {
			arguments.q = arguments.q.limit( maxRows );
		}

		// Determine return format with priority: passed options > executor definition > config defaults
		// 1. Start with config default
		var returnFormat = defaults.returnFormat ?: "array";

		// 2. Override with executor definition (from QBML query)
		if ( arguments.executor.keyExists( "returnFormat" ) ) {
			returnFormat = arguments.executor.returnFormat;
		}

		// 3. Override with passed options (from execute() call)
		if ( arguments.passedOptions.keyExists( "returnFormat" ) ) {
			returnFormat = arguments.passedOptions.returnFormat;
		}

		// Parse return format (handles both string "array" and tuple ["struct", "id", ["name"]])
		var rf = variables.formatter.parse( returnFormat );

		// Execute based on action
		var args = arguments.executor.args;

		switch ( arguments.executor.action ) {
			case "get":
				// Optimization: let qb return native query for formats that benefit from it
				if ( variables.formatter.prefersQueryInput( rf ) ) {
					arguments.q.setReturnFormat( "query" );
				}
				return variables.formatter.transform( arguments.q.get( options = opts ), rf );

			case "first":
				return arguments.q.first( options = opts );

			case "find":
				return arguments.q.find(
					id       = args[ 1 ],
					idColumn = args.len() > 1 ? args[ 2 ] : "id",
					options  = opts
				);

			case "value":
				return arguments.q.value( column = args[ 1 ], options = opts );

			case "values":
				return arguments.q.values( column = args[ 1 ], options = opts );

			case "count":
				return arguments.q.count( column = args.len() ? args[ 1 ] : "*", options = opts );

			case "sum":
				return arguments.q.sum( column = args[ 1 ], options = opts );

			case "avg":
				// QB doesn't have avg(), so we use selectRaw with AVG() and COALESCE
				var avgCol     = args[ 1 ];
				var avgDefault = args.len() > 1 ? args[ 2 ] : 0;
				var avgResult  = arguments.q
					.selectRaw( "COALESCE(AVG(#avgCol#), #avgDefault#) as avg_value" )
					.get( options = opts );
				return avgResult.len() ? ( avgResult[ 1 ][ "avg_value" ] ?: avgDefault ) : avgDefault;

			case "min":
				return arguments.q.min( column = args[ 1 ], options = opts );

			case "max":
				return arguments.q.max( column = args[ 1 ], options = opts );

			case "exists":
				return arguments.q.exists( options = opts );

			case "paginate":
				var page    = arguments.executor.page ?: 1;
				var perPage = arguments.executor.maxRows ?: arguments.executor.size ?: 25;
				// Optimization: let qb return native query for formats that benefit
				if ( variables.formatter.prefersQueryInput( rf ) ) {
					arguments.q.setReturnFormat( "query" );
				}
				return variables.formatter.transformPaginated(
					arguments.q.paginate( page = page, maxRows = perPage, options = opts ), rf
				);

			case "simplePaginate":
				var page    = arguments.executor.page ?: 1;
				var perPage = arguments.executor.maxRows ?: arguments.executor.size ?: 25;
				// Note: cbpaginator's generateSimpleWithResults types results as array,
				// so we can't set qb to query format. ReturnFormat handles post-conversion.
				return variables.formatter.transformPaginated(
					arguments.q.simplePaginate( page = page, maxRows = perPage, options = opts ), rf
				);

			case "toSQL":
				return arguments.q.toSQL();

			case "dump":
				return arguments.q.dump();

			default:
				return arguments.q.get( options = opts );
		}
	}

	// ==================== SUBQUERY PROCESSORS ====================

	/**
	 * Process CTEs
	 */
	private any function processCTEs(
		required any q,
		required array queryDef,
		array cteAliases = [],
		struct params = {}
	) {
		var self       = this;
		var paramsCopy = arguments.params;

		for ( var item in arguments.queryDef ) {
			if ( !isStruct( item ) ) continue;

			if ( item.keyExists( "with" ) && item.keyExists( "query" ) ) {
				var alias    = item.with;
				var subQuery = item.query;
				var ctes     = arguments.cteAliases;

				arguments.q = arguments.q.with( alias, function( subQ ) {
					return self.processBlock( subQ, subQuery, ctes, paramsCopy );
				} );
			}

			if ( item.keyExists( "withRecursive" ) && item.keyExists( "query" ) ) {
				var alias    = item.withRecursive;
				var subQuery = item.query;
				var ctes     = arguments.cteAliases;

				arguments.q = arguments.q.withRecursive( alias, function( subQ ) {
					return self.processBlock( subQ, subQuery, ctes, paramsCopy );
				} );
			}
		}

		return arguments.q;
	}

	/**
	 * Process nested where clauses
	 */
	private any function processNestedWhere(
		required any q,
		required string action,
		required array clauses,
		array cteAliases = [],
		struct params = {}
	) {
		var self       = this;
		var clauseData = arguments.clauses;
		var ctes       = arguments.cteAliases;
		var paramsCopy = arguments.params;

		return arguments.q[ arguments.action ]( function( subQ ) {
			return self.processBlock( subQ, clauseData, ctes, paramsCopy );
		} );
	}

	/**
	 * Process whereExists and variants
	 */
	private any function processWhereExists(
		required any q,
		required struct item,
		required string action,
		array cteAliases = [],
		struct params = {}
	) {
		if ( !arguments.item.keyExists( "query" ) || !isArray( arguments.item.query ) ) {
			throw( type = "QBML.InvalidWhereExists", message = "#arguments.action# requires a 'query' array" );
		}

		var self       = this;
		var subQuery   = arguments.item.query;
		var ctes       = arguments.cteAliases;
		var paramsCopy = arguments.params;

		return arguments.q[ arguments.action ]( function( subQ ) {
			return self.processBlock( subQ, subQuery, ctes, paramsCopy );
		} );
	}

	/**
	 * Process union queries
	 */
	private any function processUnion(
		required any q,
		required struct item,
		required string action,
		array cteAliases = [],
		struct params = {}
	) {
		if ( !arguments.item.keyExists( "query" ) || !isArray( arguments.item.query ) ) {
			throw( type = "QBML.InvalidUnion", message = "#arguments.action# requires a 'query' array" );
		}

		var self       = this;
		var subQuery   = arguments.item.query;
		var ctes       = arguments.cteAliases;
		var paramsCopy = arguments.params;

		return arguments.q[ arguments.action ]( function( unionQ ) {
			return self.processBlock( unionQ, subQuery, ctes, paramsCopy );
		} );
	}

	/**
	 * Process fromSub (derived table)
	 */
	private any function processFromSub(
		required any q,
		required struct item,
		array cteAliases = [],
		struct params = {}
	) {
		var alias = extractAlias( arguments.item, "fromSub" );

		if ( !len( alias ) ) {
			throw( type = "QBML.InvalidFromSub", message = "fromSub requires an 'alias'" );
		}

		if ( !arguments.item.keyExists( "query" ) || !isArray( arguments.item.query ) ) {
			throw( type = "QBML.InvalidFromSub", message = "fromSub requires a 'query' array" );
		}

		var self       = this;
		var subQuery   = arguments.item.query;
		var ctes       = arguments.cteAliases;
		var paramsCopy = arguments.params;

		return arguments.q.fromSub( alias, function( subQ ) {
			return self.processBlock( subQ, subQuery, ctes, paramsCopy );
		} );
	}

	/**
	 * Process subSelect (scalar subquery in SELECT)
	 */
	private any function processSubSelect(
		required any q,
		required struct item,
		array cteAliases = [],
		struct params = {}
	) {
		var alias = extractAlias( arguments.item, "subSelect" );

		if ( !len( alias ) ) {
			throw( type = "QBML.InvalidSubSelect", message = "subSelect requires an 'alias'" );
		}

		if ( !arguments.item.keyExists( "query" ) || !isArray( arguments.item.query ) ) {
			throw( type = "QBML.InvalidSubSelect", message = "subSelect requires a 'query' array" );
		}

		var self       = this;
		var subQuery   = arguments.item.query;
		var ctes       = arguments.cteAliases;
		var paramsCopy = arguments.params;

		return arguments.q.subSelect( alias, function( subQ ) {
			return self.processBlock( subQ, subQuery, ctes, paramsCopy );
		} );
	}

	/**
	 * Process join with optional closure for complex conditions
	 */
	private any function processJoin(
		required any q,
		required struct item,
		required string joinType,
		array cteAliases = [],
		struct params = {}
	) {
		var extracted   = extractAction( arguments.item );
		var joinArgs    = toArgsArray( extracted.value, extracted.action );
		var tableResult = variables.security.validateTable( joinArgs[ 1 ], arguments.cteAliases );

		if ( !tableResult.valid ) {
			throw( type = "QBML.InvalidTable", message = tableResult.message );
		}

		// Check for join with closure (on clauses)
		if ( arguments.item.keyExists( "on" ) && isArray( arguments.item.on ) ) {
			var self       = this;
			var onClauses  = arguments.item.on;
			var ctes       = arguments.cteAliases;
			var paramsCopy = arguments.params;

			return arguments.q[ arguments.joinType ]( tableResult.resolved, function( j ) {
				for ( var clause in onClauses ) {
					if ( isStruct( clause ) ) {
						var onExtracted = self.extractAction( clause );
						if ( onExtracted.hasAction ) {
							// Resolve param refs in on clause values
							var resolvedValue = self.resolveParamRefs( onExtracted.value, paramsCopy );
							var onArgs        = self.toArgsArray( resolvedValue, onExtracted.action );
							switch ( onExtracted.action ) {
								case "on":
									j.on( onArgs[ 1 ], onArgs[ 2 ], onArgs[ 3 ] );
									break;
								case "andOn":
									j.andOn( onArgs[ 1 ], onArgs[ 2 ], onArgs[ 3 ] );
									break;
								case "orOn":
									j.orOn( onArgs[ 1 ], onArgs[ 2 ], onArgs[ 3 ] );
									break;
							}
						}
					}
				}
			} );
		}

		// Simple join with column conditions
		if ( joinArgs.len() >= 4 ) {
			// 4 args: table, col1, operator, col2
			return arguments.q[ arguments.joinType ](
				tableResult.resolved,
				joinArgs[ 2 ],
				joinArgs[ 3 ],
				joinArgs[ 4 ]
			);
		} else if ( joinArgs.len() == 3 ) {
			// 3 args: table, col1, col2 (operator defaults to =)
			return arguments.q[ arguments.joinType ](
				tableResult.resolved,
				joinArgs[ 2 ],
				"=",
				joinArgs[ 3 ]
			);
		} else if ( joinArgs.len() == 2 ) {
			return arguments.q[ arguments.joinType ]( tableResult.resolved, joinArgs[ 2 ] );
		}

		return arguments.q[ arguments.joinType ]( tableResult.resolved );
	}

	/**
	 * Process join with subquery
	 */
	private any function processJoinSub(
		required any q,
		required struct item,
		required string joinType,
		array cteAliases = [],
		struct params = {}
	) {
		var alias = extractAlias( arguments.item, arguments.joinType );

		if ( !len( alias ) ) {
			throw( type = "QBML.InvalidJoinSub", message = "#arguments.joinType# requires an 'alias'" );
		}

		if ( !arguments.item.keyExists( "query" ) || !isArray( arguments.item.query ) ) {
			throw( type = "QBML.InvalidJoinSub", message = "#arguments.joinType# requires a 'query' array" );
		}

		var self       = this;
		var subQuery   = arguments.item.query;
		var ctes       = arguments.cteAliases;
		var paramsCopy = arguments.params;

		// Check for on clauses
		if ( arguments.item.keyExists( "on" ) && isArray( arguments.item.on ) ) {
			var onClauses = arguments.item.on;

			return arguments.q[ arguments.joinType ](
				alias,
				function( subQ ) {
					return self.processBlock( subQ, subQuery, ctes, paramsCopy );
				},
				function( j ) {
					for ( var clause in onClauses ) {
						if ( isStruct( clause ) ) {
							var onExtracted = self.extractAction( clause );
							if ( onExtracted.hasAction ) {
								// Resolve param refs in on clause values
								var resolvedValue = self.resolveParamRefs( onExtracted.value, paramsCopy );
								var onArgs        = self.toArgsArray( resolvedValue, onExtracted.action );
								j[ onExtracted.action ]( onArgs[ 1 ], onArgs[ 2 ], onArgs[ 3 ] );
							}
						}
					}
				}
			);
		}

		return arguments.q[ arguments.joinType ]( alias, function( subQ ) {
			return self.processBlock( subQ, subQuery, ctes, paramsCopy );
		} );
	}

	/**
	 * Extract alias from various item formats
	 */
	private string function extractAlias( required struct item, required string actionKey ) {
		var val = arguments.item[ arguments.actionKey ];

		if ( isStruct( val ) && val.keyExists( "alias" ) ) {
			return val.alias;
		}
		if ( isSimpleValue( val ) && len( val ) && val != true && val != "true" ) {
			return val;
		}
		if ( arguments.item.keyExists( "alias" ) ) {
			return arguments.item.alias;
		}

		return "";
	}

	/**
	 * Apply where clause with correct number of arguments
	 */
	private any function applyWhere( required any q, required string action, required array args ) {
		if ( arguments.args.len() == 2 ) {
			return arguments.q[ arguments.action ]( arguments.args[ 1 ], arguments.args[ 2 ] );
		}
		if ( arguments.args.len() >= 3 ) {
			return arguments.q[ arguments.action ](
				arguments.args[ 1 ],
				arguments.args[ 2 ],
				arguments.args[ 3 ]
			);
		}
		return arguments.q;
	}

	/**
	 * Process raw SQL expressions with validation
	 */
	private any function processRaw( required any q, required string method, required array args ) {
		if ( !arguments.args.len() ) {
			return arguments.q;
		}

		var rawResult = variables.security.validateRawExpression( arguments.args[ 1 ] );
		if ( !rawResult.valid ) {
			throw( type = "QBML.InvalidRawExpression", message = rawResult.message );
		}

		if ( arguments.args.len() >= 2 && isArray( arguments.args[ 2 ] ) ) {
			return arguments.q[ arguments.method ]( arguments.args[ 1 ], arguments.args[ 2 ] );
		}

		return arguments.q[ arguments.method ]( arguments.args[ 1 ] );
	}

	/**
	 * Process joinRaw/leftJoinRaw/rightJoinRaw
	 * joinRaw(table, first?, operator?, second?)
	 */
	private any function processJoinRaw( required any q, required string method, required array args ) {
		if ( !arguments.args.len() ) {
			return arguments.q;
		}

		// First arg is raw table expression - validate it
		var rawResult = variables.security.validateRawExpression( arguments.args[ 1 ] );
		if ( !rawResult.valid ) {
			throw( type = "QBML.InvalidRawExpression", message = rawResult.message );
		}

		// Call based on number of args
		if ( arguments.args.len() >= 4 ) {
			return arguments.q[ arguments.method ](
				arguments.args[ 1 ],
				arguments.args[ 2 ],
				arguments.args[ 3 ],
				arguments.args[ 4 ]
			);
		} else if ( arguments.args.len() == 3 ) {
			return arguments.q[ arguments.method ](
				arguments.args[ 1 ],
				arguments.args[ 2 ],
				"=",
				arguments.args[ 3 ]
			);
		} else if ( arguments.args.len() == 2 ) {
			return arguments.q[ arguments.method ]( arguments.args[ 1 ], arguments.args[ 2 ] );
		}

		return arguments.q[ arguments.method ]( arguments.args[ 1 ] );
	}

	/**
	 * Resolve $param references in a value
	 *
	 * Supports:
	 *   { "$param": "paramName" } - replaced with params.paramName value
	 *   "$paramName$" in strings - inline template interpolation (e.g., "%$filter$%" for LIKE patterns)
	 *   Arrays containing $param refs - each element resolved
	 *   Structs containing $param refs - each value resolved (except $param key itself)
	 *
	 * @value The value to resolve
	 * @params The params struct
	 * @return any The resolved value
	 */
	any function resolveParamRefs( required any value, struct params = {} ) {
		// Direct $param reference: { "$param": "name" }
		if ( isStruct( arguments.value ) && arguments.value.keyExists( "$param" ) ) {
			var paramName = arguments.value[ "$param" ];
			if ( arguments.params.keyExists( paramName ) ) {
				return arguments.params[ paramName ];
			}
			// Param not found - return null/empty or throw?
			// For flexibility, return null so actions can handle missing params
			return javacast( "null", "" );
		}

		// Array: resolve each element
		if ( isArray( arguments.value ) ) {
			var resolved = [];
			for ( var item in arguments.value ) {
				resolved.append( resolveParamRefs( item, arguments.params ) );
			}
			return resolved;
		}

		// Struct: resolve values (but not the struct keys)
		if ( isStruct( arguments.value ) ) {
			var resolved = {};
			for ( var key in arguments.value ) {
				resolved[ key ] = resolveParamRefs( arguments.value[ key ], arguments.params );
			}
			return resolved;
		}

		// String template interpolation: "$paramName$" pattern
		// Allows inline param substitution like "%$filter$%" for LIKE patterns
		if ( isSimpleValue( arguments.value ) && arguments.value contains "$" ) {
			var result  = arguments.value;
			var pattern = "\$([a-zA-Z_][a-zA-Z0-9_]*)\$";
			var matcher = createObject( "java", "java.util.regex.Pattern" )
				.compile( pattern )
				.matcher( result );

			while ( matcher.find() ) {
				var fullMatch = matcher.group( 0 );
				var paramName = matcher.group( 1 );
				if ( arguments.params.keyExists( paramName ) ) {
					var paramValue = arguments.params[ paramName ];
					// Only interpolate simple values into strings
					if ( isSimpleValue( paramValue ) ) {
						result = replace( result, fullMatch, paramValue, "all" );
					}
				}
			}
			return result;
		}

		// Simple value - return as-is
		return arguments.value;
	}

	/**
	 * Resolve $raw references in a value, converting them to qb Expression objects
	 *
	 * Supports:
	 *   { "$raw": "SQL expression" } - converted to qb.raw( "SQL expression" )
	 *   { "$raw": { "sql": "SQL", "bindings": [...] } } - with bindings support
	 *   Arrays containing $raw refs - each element resolved
	 *
	 * This allows embedding raw SQL expressions inline within other methods:
	 *   { "select": [{ "$raw": "COUNT(*)" }, "name"] }
	 *   { "whereIn": ["status", { "$raw": "(SELECT status FROM statuses)" }] }
	 *   { "orderBy": { "$raw": "FIELD(status, 'pending', 'active', 'done')" } }
	 *
	 * @value The value to resolve
	 * @q The QueryBuilder instance (used to create raw expressions)
	 * @return any The resolved value (with $raw converted to Expression objects)
	 */
	any function resolveRawRefs( required any value, required any q ) {
		// Handle null values (can occur from unresolved params)
		if ( isNull( arguments.value ) ) {
			return javacast( "null", "" );
		}
		// Direct $raw reference: { "$raw": "sql" } or { "$raw": { "sql": "...", "bindings": [...] } }
		if ( isStruct( arguments.value ) && arguments.value.keyExists( "$raw" ) ) {
			var rawDef = arguments.value[ "$raw" ];
			var sql    = "";
			var bindings = [];

			// Support both string and object form
			if ( isSimpleValue( rawDef ) ) {
				sql = rawDef;
			} else if ( isStruct( rawDef ) && rawDef.keyExists( "sql" ) ) {
				sql = rawDef.sql;
				bindings = rawDef.keyExists( "bindings" ) ? rawDef.bindings : [];
			} else {
				throw( type = "QBML.InvalidRaw", message = "$raw must be a string or an object with 'sql' key" );
			}

			// Validate the raw expression for security
			var rawResult = variables.security.validateRawExpression( sql );
			if ( !rawResult.valid ) {
				throw( type = "QBML.InvalidRawExpression", message = rawResult.message );
			}

			// Create and return the qb Expression
			if ( bindings.len() ) {
				return arguments.q.raw( sql, bindings );
			}
			return arguments.q.raw( sql );
		}

		// Array: resolve each element
		if ( isArray( arguments.value ) ) {
			var resolved = [];
			for ( var item in arguments.value ) {
				resolved.append( resolveRawRefs( item, arguments.q ) );
			}
			return resolved;
		}

		// Struct without $raw: resolve values recursively
		if ( isStruct( arguments.value ) ) {
			var resolved = {};
			for ( var key in arguments.value ) {
				resolved[ key ] = resolveRawRefs( arguments.value[ key ], arguments.q );
			}
			return resolved;
		}

		// Simple value - return as-is
		return arguments.value;
	}

	/**
	 * Check if a value contains any $raw references
	 * Used for optimization to skip raw resolution when not needed
	 *
	 * @value The value to check
	 * @return boolean True if $raw references exist
	 */
	boolean function containsRawRefs( required any value ) {
		// Handle null values (can occur from unresolved params)
		if ( isNull( arguments.value ) ) {
			return false;
		}
		if ( isStruct( arguments.value ) ) {
			if ( arguments.value.keyExists( "$raw" ) ) {
				return true;
			}
			for ( var key in arguments.value ) {
				var structValue = arguments.value[ key ];
				if ( !isNull( structValue ) && containsRawRefs( structValue ) ) {
					return true;
				}
			}
		}
		if ( isArray( arguments.value ) ) {
			// Use index-based loop to safely handle null values
			for ( var i = 1; i <= arrayLen( arguments.value ); i++ ) {
				if ( !isNull( arguments.value[ i ] ) && containsRawRefs( arguments.value[ i ] ) ) {
					return true;
				}
			}
		}
		return false;
	}
	// ==================== RETURN FORMAT HELPERS ====================

	// "I am the way, and the truth, and the life; no one comes to the Father, but by me (JESUS)" Jn 14:1-12
}
