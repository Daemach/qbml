/**
 * QBML Condition Evaluator
 * Evaluates "when" conditions for conditional query building
 */
component singleton {

	/**
	 * Evaluate a "when" condition
	 *
	 * Supported conditions:
	 *   "hasValues" / "notEmpty" - true if any array arg is not empty
	 *   "isEmpty" - true if any array arg IS empty
	 *   { "notEmpty": true } - same as "hasValues"
	 *   { "notEmpty": 2 } - check specific arg index (1-based)
	 *   { "isEmpty": true } - true if array arg IS empty
	 *   { "gt": [index, value] } - args[index] > value
	 *   { "gte": [index, value] } - args[index] >= value
	 *   { "lt": [index, value] } - args[index] < value
	 *   { "lte": [index, value] } - args[index] <= value
	 *   { "eq": [index, value] } - args[index] == value
	 *   { "neq": [index, value] } - args[index] != value
	 *   { "and": [...conditions] } - all conditions must be true
	 *   { "or": [...conditions] } - any condition must be true
	 *   { "not": condition } - negate the condition
	 *
	 * Param-based conditions (when params struct provided):
	 *   { "param": "name", "notEmpty": true } - true if params.name is not empty
	 *   { "param": "name", "isEmpty": true } - true if params.name is empty
	 *   { "param": "name", "gt": value } - params.name > value
	 *   { "param": "name", "gte": value } - params.name >= value
	 *   { "param": "name", "lt": value } - params.name < value
	 *   { "param": "name", "lte": value } - params.name <= value
	 *   { "param": "name", "eq": value } - params.name == value
	 *   { "param": "name", "neq": value } - params.name != value
	 *
	 * @condition The condition to evaluate
	 * @args The arguments array to check against
	 * @params Optional struct of parameter values for param-based conditions
	 * @return boolean
	 */
	boolean function evaluate( required any condition, required array args, struct params = {} ) {
		// Simple string conditions
		if ( isSimpleValue( arguments.condition ) ) {
			return evaluateSimple( arguments.condition, arguments.args );
		}

		// Struct-based conditions
		if ( isStruct( arguments.condition ) ) {
			return evaluateStruct( arguments.condition, arguments.args, arguments.params );
		}

		// Default: apply the action
		return true;
	}

	/**
	 * Evaluate simple string conditions
	 */
	private boolean function evaluateSimple( required any condition, required array args ) {
		// Check for array values
		if ( arguments.condition == "hasValues" || arguments.condition == "notEmpty" ) {
			for ( var arg in arguments.args ) {
				if ( isArray( arg ) ) {
					return arrayLen( arg ) > 0;
				}
			}
			return true; // No array found, apply by default
		}

		if ( arguments.condition == "isEmpty" ) {
			for ( var arg in arguments.args ) {
				if ( isArray( arg ) ) {
					return arrayLen( arg ) == 0;
				}
			}
			return false;
		}

		// Boolean values
		if ( arguments.condition == true || arguments.condition == "true" ) {
			return true;
		}
		if ( arguments.condition == false || arguments.condition == "false" ) {
			return false;
		}

		// Default: apply
		return true;
	}

	/**
	 * Evaluate struct-based conditions
	 */
	private boolean function evaluateStruct( required struct condition, required array args, struct params = {} ) {
		// Param-based conditions: { "param": "name", "notEmpty": true }
		if ( arguments.condition.keyExists( "param" ) ) {
			return evaluateParamCondition( arguments.condition, arguments.params );
		}

		// notEmpty check
		if ( arguments.condition.keyExists( "notEmpty" ) ) {
			return evaluateNotEmpty( arguments.condition.notEmpty, arguments.args );
		}

		// isEmpty check
		if ( arguments.condition.keyExists( "isEmpty" ) ) {
			return evaluateIsEmpty( arguments.condition.isEmpty, arguments.args );
		}

		// Comparison operators
		if ( arguments.condition.keyExists( "gt" ) ) {
			return evaluateComparison( arguments.condition.gt, arguments.args, "gt" );
		}
		if ( arguments.condition.keyExists( "gte" ) ) {
			return evaluateComparison( arguments.condition.gte, arguments.args, "gte" );
		}
		if ( arguments.condition.keyExists( "lt" ) ) {
			return evaluateComparison( arguments.condition.lt, arguments.args, "lt" );
		}
		if ( arguments.condition.keyExists( "lte" ) ) {
			return evaluateComparison( arguments.condition.lte, arguments.args, "lte" );
		}
		if ( arguments.condition.keyExists( "eq" ) ) {
			return evaluateComparison( arguments.condition.eq, arguments.args, "eq" );
		}
		if ( arguments.condition.keyExists( "neq" ) ) {
			return evaluateComparison( arguments.condition.neq, arguments.args, "neq" );
		}

		// Logical operators (use this.evaluate to avoid conflict with CFML's evaluate())
		if ( arguments.condition.keyExists( "and" ) && isArray( arguments.condition.and ) ) {
			for ( var subCond in arguments.condition.and ) {
				if ( !this.evaluate( subCond, arguments.args, arguments.params ) ) {
					return false;
				}
			}
			return true;
		}

		if ( arguments.condition.keyExists( "or" ) && isArray( arguments.condition.or ) ) {
			for ( var subCond in arguments.condition.or ) {
				if ( this.evaluate( subCond, arguments.args, arguments.params ) ) {
					return true;
				}
			}
			return false;
		}

		if ( arguments.condition.keyExists( "not" ) ) {
			return !this.evaluate( arguments.condition.not, arguments.args, arguments.params );
		}

		// Default: apply
		return true;
	}

	/**
	 * Evaluate notEmpty condition
	 */
	private boolean function evaluateNotEmpty( required any value, required array args ) {
		// { "notEmpty": true } - check any array
		if ( isBoolean( arguments.value ) && arguments.value ) {
			for ( var arg in arguments.args ) {
				if ( isArray( arg ) ) {
					return arrayLen( arg ) > 0;
				}
			}
			return true;
		}

		// { "notEmpty": 2 } - check specific index
		if ( isNumeric( arguments.value ) ) {
			var idx = arguments.value;
			if ( arrayLen( arguments.args ) >= idx && isArray( arguments.args[ idx ] ) ) {
				return arrayLen( arguments.args[ idx ] ) > 0;
			}
		}

		return true;
	}

	/**
	 * Evaluate isEmpty condition
	 */
	private boolean function evaluateIsEmpty( required any value, required array args ) {
		if ( isBoolean( arguments.value ) && arguments.value ) {
			for ( var arg in arguments.args ) {
				if ( isArray( arg ) ) {
					return arrayLen( arg ) == 0;
				}
			}
			return false;
		}

		// { "isEmpty": 2 } - check specific index
		if ( isNumeric( arguments.value ) ) {
			var idx = arguments.value;
			if ( arrayLen( arguments.args ) >= idx && isArray( arguments.args[ idx ] ) ) {
				return arrayLen( arguments.args[ idx ] ) == 0;
			}
		}

		return false;
	}

	/**
	 * Evaluate comparison conditions
	 * @spec Array of [index, value] to compare
	 * @args The arguments array
	 * @operator The comparison operator (gt, gte, lt, lte, eq, neq)
	 */
	private boolean function evaluateComparison(
		required array spec,
		required array args,
		required string operator
	) {
		if ( arrayLen( arguments.spec ) < 2 ) {
			return false;
		}

		var idx        = arguments.spec[ 1 ];
		var compareVal = arguments.spec[ 2 ];

		if ( arrayLen( arguments.args ) < idx ) {
			return false;
		}

		var actualVal = arguments.args[ idx ];

		switch ( arguments.operator ) {
			case "gt":
				return actualVal > compareVal;
			case "gte":
				return actualVal >= compareVal;
			case "lt":
				return actualVal < compareVal;
			case "lte":
				return actualVal <= compareVal;
			case "eq":
				return actualVal == compareVal;
			case "neq":
				return actualVal != compareVal;
			default:
				return false;
		}
	}

	/**
	 * Evaluate param-based condition
	 *
	 * Supports:
	 *   { "param": "name", "notEmpty": true } - true if params.name is not empty array/string
	 *   { "param": "name", "isEmpty": true } - true if params.name is empty array/string
	 *   { "param": "name", "hasValue": true } - true if params.name exists and has a non-null value
	 *   { "param": "name", "gt": value } - params.name > value
	 *   { "param": "name", "gte": value } - params.name >= value
	 *   { "param": "name", "lt": value } - params.name < value
	 *   { "param": "name", "lte": value } - params.name <= value
	 *   { "param": "name", "eq": value } - params.name == value
	 *   { "param": "name", "neq": value } - params.name != value
	 *
	 * @condition The condition struct containing "param" key and condition type
	 * @params The params struct to check against
	 * @return boolean
	 */
	private boolean function evaluateParamCondition( required struct condition, required struct params ) {
		var paramName = arguments.condition.param;

		// Check if param exists
		if ( !arguments.params.keyExists( paramName ) ) {
			// Param not found - return false for all conditions except isEmpty
			if ( arguments.condition.keyExists( "isEmpty" ) && arguments.condition.isEmpty == true ) {
				return true;
			}
			return false;
		}

		var paramValue = arguments.params[ paramName ];

		// notEmpty check
		if ( arguments.condition.keyExists( "notEmpty" ) && arguments.condition.notEmpty == true ) {
			if ( isArray( paramValue ) ) {
				return arrayLen( paramValue ) > 0;
			}
			if ( isSimpleValue( paramValue ) ) {
				return len( trim( paramValue ) ) > 0;
			}
			if ( isStruct( paramValue ) ) {
				return !structIsEmpty( paramValue );
			}
			return !isNull( paramValue );
		}

		// isEmpty check
		if ( arguments.condition.keyExists( "isEmpty" ) && arguments.condition.isEmpty == true ) {
			if ( isArray( paramValue ) ) {
				return arrayLen( paramValue ) == 0;
			}
			if ( isSimpleValue( paramValue ) ) {
				return len( trim( paramValue ) ) == 0;
			}
			if ( isStruct( paramValue ) ) {
				return structIsEmpty( paramValue );
			}
			return isNull( paramValue );
		}

		// hasValue check - just checks existence and non-null (already passed above)
		if ( arguments.condition.keyExists( "hasValue" ) && arguments.condition.hasValue == true ) {
			return !isNull( paramValue );
		}

		// Comparison operators
		if ( arguments.condition.keyExists( "gt" ) ) {
			return paramValue > arguments.condition.gt;
		}
		if ( arguments.condition.keyExists( "gte" ) ) {
			return paramValue >= arguments.condition.gte;
		}
		if ( arguments.condition.keyExists( "lt" ) ) {
			return paramValue < arguments.condition.lt;
		}
		if ( arguments.condition.keyExists( "lte" ) ) {
			return paramValue <= arguments.condition.lte;
		}
		if ( arguments.condition.keyExists( "eq" ) ) {
			return paramValue == arguments.condition.eq;
		}
		if ( arguments.condition.keyExists( "neq" ) ) {
			return paramValue != arguments.condition.neq;
		}

		// Default: param exists, so apply
		return true;
	}

}
