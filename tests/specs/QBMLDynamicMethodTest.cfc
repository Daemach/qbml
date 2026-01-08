/**
 * QBML Dynamic Method Generation Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Action and executor lookup", function() {
			it( "validates actions correctly with isValidAction", function() {
				expect( qbml.isValidAction( "where" ) ).toBeTrue();
				expect( qbml.isValidAction( "WHERE" ) ).toBeTrue();
				expect( qbml.isValidAction( "WhErE" ) ).toBeTrue();
				expect( qbml.isValidAction( "select" ) ).toBeTrue();
				expect( qbml.isValidAction( "join" ) ).toBeTrue();
				expect( qbml.isValidAction( "invalidAction" ) ).toBeFalse();
				expect( qbml.isValidAction( "" ) ).toBeFalse();
			} );

			it( "validates executors correctly with isValidExecutor", function() {
				expect( qbml.isValidExecutor( "get" ) ).toBeTrue();
				expect( qbml.isValidExecutor( "GET" ) ).toBeTrue();
				expect( qbml.isValidExecutor( "first" ) ).toBeTrue();
				expect( qbml.isValidExecutor( "paginate" ) ).toBeTrue();
				expect( qbml.isValidExecutor( "count" ) ).toBeTrue();
				expect( qbml.isValidExecutor( "invalidExecutor" ) ).toBeFalse();
				expect( qbml.isValidExecutor( "" ) ).toBeFalse();
			} );

			it( "handles all registered actions", function() {
				var sampleActions = [
					"with", "withRecursive",
					"select", "addSelect", "distinct", "selectRaw",
					"from", "fromSub", "table",
					"join", "innerJoin", "leftJoin", "rightJoin",
					"where", "andWhere", "orWhere",
					"whereIn", "whereNotIn", "whereBetween",
					"whereLike", "whereNull", "whereColumn",
					"whereExists", "whereRaw",
					"groupBy", "having", "havingRaw",
					"orderBy", "orderByDesc", "orderByRaw",
					"limit", "offset", "forPage",
					"union", "unionAll"
				];

				for ( var action in sampleActions ) {
					expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
				}
			} );

			it( "handles all registered executors", function() {
				var allExecutors = [
					"get", "first", "find", "value", "values",
					"count", "sum", "avg", "min", "max", "exists",
					"paginate", "simplePaginate",
					"toSQL", "dump"
				];

				for ( var executor in allExecutors ) {
					expect( qbml.isValidExecutor( executor ) ).toBeTrue( "Expected '#executor#' to be valid" );
				}
			} );
		} );

		describe( "Dynamic method generation", function() {
			describe( "normalizeAction extracts components correctly", function() {
				it( "normalizes base actions without prefix", function() {
					var result = qbml.normalizeAction( "where" );
					expect( result.baseAction ).toBe( "where" );
					expect( result.combinator ).toBe( "" );
					expect( result.negated ).toBeFalse();
				} );

				it( "normalizes andWhere with combinator", function() {
					var result = qbml.normalizeAction( "andWhere" );
					expect( result.baseAction ).toBe( "Where" );
					expect( result.combinator ).toBe( "and" );
					expect( result.negated ).toBeFalse();
				} );

				it( "normalizes orWhere with combinator", function() {
					var result = qbml.normalizeAction( "orWhere" );
					expect( result.baseAction ).toBe( "Where" );
					expect( result.combinator ).toBe( "or" );
					expect( result.negated ).toBeFalse();
				} );

				it( "normalizes whereNotIn with negation", function() {
					var result = qbml.normalizeAction( "whereNotIn" );
					expect( result.baseAction ).toBe( "whereIn" );
					expect( result.combinator ).toBe( "" );
					expect( result.negated ).toBeTrue();
				} );

				it( "normalizes andWhereNotIn with combinator and negation", function() {
					var result = qbml.normalizeAction( "andWhereNotIn" );
					expect( result.baseAction ).toBe( "whereIn" );
					expect( result.combinator ).toBe( "and" );
					expect( result.negated ).toBeTrue();
				} );

				it( "normalizes orWhereNotNull with combinator and negation", function() {
					var result = qbml.normalizeAction( "orWhereNotNull" );
					expect( result.baseAction ).toBe( "whereNull" );
					expect( result.combinator ).toBe( "or" );
					expect( result.negated ).toBeTrue();
				} );

				it( "normalizes whereNull (not confused with whereNot*)", function() {
					var result = qbml.normalizeAction( "whereNull" );
					expect( result.baseAction ).toBe( "whereNull" );
					expect( result.combinator ).toBe( "" );
					expect( result.negated ).toBeFalse();
				} );

				it( "normalizes having variants", function() {
					var andHaving = qbml.normalizeAction( "andHaving" );
					expect( andHaving.baseAction ).toBe( "Having" );
					expect( andHaving.combinator ).toBe( "and" );

					var orHaving = qbml.normalizeAction( "orHaving" );
					expect( orHaving.baseAction ).toBe( "Having" );
					expect( orHaving.combinator ).toBe( "or" );
				} );

				it( "normalizes on clause variants", function() {
					var andOn = qbml.normalizeAction( "andOn" );
					expect( andOn.baseAction ).toBe( "On" );
					expect( andOn.combinator ).toBe( "and" );

					var orOn = qbml.normalizeAction( "orOn" );
					expect( orOn.baseAction ).toBe( "On" );
					expect( orOn.combinator ).toBe( "or" );
				} );
			} );

			describe( "dynamically generated action variants are valid", function() {
				it( "validates all whereIn variants", function() {
					var whereInVariants = [
						"whereIn", "whereNotIn",
						"andWhereIn", "orWhereIn",
						"andWhereNotIn", "orWhereNotIn"
					];
					for ( var action in whereInVariants ) {
						expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
					}
				} );

				it( "validates all whereBetween variants", function() {
					var whereBetweenVariants = [
						"whereBetween", "whereNotBetween",
						"andWhereBetween", "orWhereBetween",
						"andWhereNotBetween", "orWhereNotBetween"
					];
					for ( var action in whereBetweenVariants ) {
						expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
					}
				} );

				it( "validates all whereLike variants", function() {
					var whereLikeVariants = [
						"whereLike", "whereNotLike",
						"andWhereLike", "orWhereLike",
						"andWhereNotLike", "orWhereNotLike"
					];
					for ( var action in whereLikeVariants ) {
						expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
					}
				} );

				it( "validates all whereNull variants", function() {
					var whereNullVariants = [
						"whereNull", "whereNotNull",
						"andWhereNull", "orWhereNull",
						"andWhereNotNull", "orWhereNotNull"
					];
					for ( var action in whereNullVariants ) {
						expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
					}
				} );

				it( "validates all whereExists variants", function() {
					var whereExistsVariants = [
						"whereExists", "whereNotExists",
						"andWhereExists", "orWhereExists",
						"andWhereNotExists", "orWhereNotExists"
					];
					for ( var action in whereExistsVariants ) {
						expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
					}
				} );

				it( "validates all having variants", function() {
					var havingVariants = [ "having", "andHaving", "orHaving" ];
					for ( var action in havingVariants ) {
						expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
					}
				} );

				it( "validates all on clause variants", function() {
					var onVariants = [ "on", "andOn", "orOn" ];
					for ( var action in onVariants ) {
						expect( qbml.isValidAction( action ) ).toBeTrue( "Expected '#action#' to be valid" );
					}
				} );
			} );

			describe( "dynamically generated actions execute correctly", function() {
				it( "executes andWhereIn correctly", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "status" ] },
						{ "where" : [ "status", "=", "active" ] },
						{ "andWhereIn" : [ "id", [ 1, 2, 3, 4, 5 ] ] },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					for ( var row in result ) {
						expect( row.status ).toBe( "active" );
						expect( [ 1, 2, 3, 4, 5 ] ).toInclude( row.id );
					}
				} );

				it( "executes orWhereNotNull correctly", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : [ "status", "=", "active" ] },
						{ "orWhereNotNull" : "created_at" },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
				} );

				it( "executes andWhereBetween correctly", function() {
					var query = [
						{ "from" : "qbml_products" },
						{ "select" : [ "id", "name", "price" ] },
						{ "where" : [ "price", ">", 0 ] },
						{ "andWhereBetween" : [ "price", 10, 100 ] },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					for ( var row in result ) {
						expect( row.price ).toBeGTE( 10 );
						expect( row.price ).toBeLTE( 100 );
					}
				} );

				it( "executes orWhereLike correctly", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "email" ] },
						{ "whereLike" : [ "username", "admin%" ] },
						{ "orWhereLike" : [ "email", "%test%" ] },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
				} );

				it( "executes andHaving correctly", function() {
					var query = [
						{ "from" : "qbml_products" },
						{ "select" : [ "category_id" ] },
						{ "selectRaw" : "COUNT(*) as product_count" },
						{ "groupBy" : "category_id" },
						{ "havingRaw" : "COUNT(*) >= 1" },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					for ( var row in result ) {
						expect( row.product_count ).toBeGTE( 1 );
					}
				} );
			} );
		} );
	}

}
