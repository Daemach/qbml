/**
 * Tests for QBML Params functionality
 * Tests $param value resolution and param-based when conditions
 */
component extends="testbox.system.BaseSpec" {

	function beforeAll() {
		// Test settings - allow all tables for SQL generation tests
		var testSettings = {
			tables : { mode : "none", list : [] }
		};

		// Create QB dependencies for standalone testing
		var utils   = new qb.models.Query.QueryUtils();
		var grammar = new qb.models.Grammars.SqlServerGrammar( utils );

		// Create a QB provider that returns new QueryBuilder instances
		var qbProvider = {
			grammar : grammar,
			utils   : utils,
			newQuery : function() {
				var builder = new qb.models.Query.QueryBuilder();
				builder.setGrammar( grammar );
				builder.setUtils( utils );
				builder.setReturnFormat( "array" );
				return builder;
			}
		};

		// Initialize QBML with test settings
		variables.qbml = new qbml.models.QBML( settings = testSettings );

		// Inject dependencies manually for standalone testing
		variables.qbml.setQb( qbProvider );
		variables.qbml.setSecurity( new qbml.models.QBMLSecurity( settings = testSettings ) );
		variables.qbml.setConditions( new qbml.models.QBMLConditions() );
	}

	function run() {
		describe( "QBML Params", function() {
			describe( "$param value resolution", function() {
				it( "resolves simple $param reference in whereIn", function() {
					var query = [
						{ from : "users" },
						{ select : [ "id", "name" ] },
						{ whereIn : [ "accountID", { "$param" : "accountIDs" } ] }
					];
					var params = { accountIDs : [ 1, 2, 3 ] };
					var sql    = qbml.toSQL( query, params );
					expect( sql ).toInclude( "WHERE" );
					expect( sql ).toInclude( "IN" );
				} );

				it( "resolves $param reference in where clause", function() {
					var query = [
						{ from : "users" },
						{ select : [ "id", "name" ] },
						{ where : [ "status", { "$param" : "status" } ] }
					];
					var params = { status : "active" };
					var sql    = qbml.toSQL( query, params );
					expect( sql ).toInclude( "WHERE" );
				} );

				it( "resolves $param in whereBetween", function() {
					var query = [
						{ from : "orders" },
						{ select : "*" },
						{ whereBetween : [ "id", { "$param" : "startID" }, { "$param" : "endID" } ] }
					];
					var params = { startID : 1, endID : 100 };
					var sql    = qbml.toSQL( query, params );
					expect( sql ).toInclude( "BETWEEN" );
				} );

				it( "resolves nested $param in object form", function() {
					var query = [
						{ from : "users" },
						{ select : "*" },
						{
							whereIn : {
								column : "accountID",
								values : { "$param" : "accountIDs" }
							}
						}
					];
					var params = { accountIDs : [ 1, 2, 3 ] };
					var sql    = qbml.toSQL( query, params );
					expect( sql ).toInclude( "IN" );
				} );

				it( "handles resolveParamRefs directly", function() {
					// Test the helper function directly
					var value  = { "$param" : "myValue" };
					var params = { myValue : "resolved!" };
					var result = qbml.resolveParamRefs( value, params );
					expect( result ).toBe( "resolved!" );
				} );

				it( "resolves arrays containing $param refs", function() {
					var value  = [ "column", { "$param" : "values" } ];
					var params = { values : [ 1, 2, 3 ] };
					var result = qbml.resolveParamRefs( value, params );
					expect( result[ 1 ] ).toBe( "column" );
					expect( result[ 2 ] ).toBeArray();
					expect( result[ 2 ] ).toBe( [ 1, 2, 3 ] );
				} );

				it( "resolves structs containing $param refs", function() {
					var value = {
						column : "status",
						values : { "$param" : "statuses" }
					};
					var params = { statuses : [ "active", "pending" ] };
					var result = qbml.resolveParamRefs( value, params );
					expect( result.column ).toBe( "status" );
					expect( result.values ).toBeArray();
				} );

				it( "returns null for missing param", function() {
					var value  = { "$param" : "missingParam" };
					var result = qbml.resolveParamRefs( value, {} );
					expect( isNull( result ) ).toBeTrue();
				} );

				it( "passes through simple values unchanged", function() {
					expect( qbml.resolveParamRefs( "hello", {} ) ).toBe( "hello" );
					expect( qbml.resolveParamRefs( 123, {} ) ).toBe( 123 );
					expect( qbml.resolveParamRefs( true, {} ) ).toBe( true );
				} );
			} );

			describe( "String template interpolation ($paramName$)", function() {
				it( "interpolates single param in string", function() {
					var result = qbml.resolveParamRefs( "%$filter$%", { filter : "john" } );
					expect( result ).toBe( "%john%" );
				} );

				it( "interpolates param at start of string", function() {
					var result = qbml.resolveParamRefs( "$domain$%", { domain : "example.com" } );
					expect( result ).toBe( "example.com%" );
				} );

				it( "interpolates param at end of string", function() {
					var result = qbml.resolveParamRefs( "%$extension$", { extension : ".pdf" } );
					expect( result ).toBe( "%.pdf" );
				} );

				it( "interpolates multiple params in string", function() {
					var result = qbml.resolveParamRefs(
						"$prefix$-$code$-$suffix$",
						{ prefix : "PRE", code : "123", suffix : "SUF" }
					);
					expect( result ).toBe( "PRE-123-SUF" );
				} );

				it( "leaves unmatched params unchanged", function() {
					var result = qbml.resolveParamRefs( "%$filter$%", {} );
					expect( result ).toBe( "%$filter$%" );
				} );

				it( "handles mixed matched and unmatched params", function() {
					var result = qbml.resolveParamRefs(
						"$found$-$missing$",
						{ found : "HERE" }
					);
					expect( result ).toBe( "HERE-$missing$" );
				} );

				it( "only interpolates simple values", function() {
					// Arrays should not be interpolated into strings
					var result = qbml.resolveParamRefs( "%$filter$%", { filter : [ 1, 2, 3 ] } );
					expect( result ).toBe( "%$filter$%" );
				} );

				it( "works with whereLike in query", function() {
					var query = [
						{ from : "users" },
						{ select : [ "id", "name" ] },
						{ whereLike : [ "name", "%$filter$%" ] }
					];
					var sql = qbml.toSQL( query, { filter : "john" } );
					expect( sql ).toInclude( "LIKE" );
				} );

				it( "works with whereNotLike in query", function() {
					var query = [
						{ from : "users" },
						{ select : [ "id", "email" ] },
						{ whereNotLike : [ "email", "%$domain$" ] }
					];
					var sql = qbml.toSQL( query, { domain : "@spam.com" } );
					expect( sql ).toInclude( "NOT LIKE" );
				} );

				it( "works in where clause for pattern matching", function() {
					var query = [
						{ from : "products" },
						{ select : "*" },
						{ where : [ "sku", "like", "$prefix$%" ] }
					];
					var sql = qbml.toSQL( query, { prefix : "PROD" } );
					expect( sql ).toInclude( "LIKE" );
				} );

				it( "interpolates within arrays", function() {
					var result = qbml.resolveParamRefs(
						[ "column", "%$search$%" ],
						{ search : "test" }
					);
					expect( result[ 1 ] ).toBe( "column" );
					expect( result[ 2 ] ).toBe( "%test%" );
				} );

				it( "supports underscores in param names", function() {
					var result = qbml.resolveParamRefs(
						"%$search_term$%",
						{ search_term : "hello" }
					);
					expect( result ).toBe( "%hello%" );
				} );

				it( "supports numbers in param names (not at start)", function() {
					var result = qbml.resolveParamRefs(
						"$param1$-$param2$",
						{ param1 : "one", param2 : "two" }
					);
					expect( result ).toBe( "one-two" );
				} );
			} );

			describe( "Param-based when conditions", function() {
				it( "skips whereIn when param is empty array", function() {
					var query = [
						{ from : "users" },
						{ select : [ "id", "name" ] },
						{
							when      : { param : "accountIDs", notEmpty : true },
							whereIn   : [ "accountID", { "$param" : "accountIDs" } ]
						}
					];

					// With values - should include WHERE
					var sqlWithValues = qbml.toSQL( query, { accountIDs : [ 1, 2, 3 ] } );
					expect( sqlWithValues ).toInclude( "WHERE" );
					expect( sqlWithValues ).toInclude( "IN" );

					// Without values - should NOT include WHERE
					var sqlNoValues = qbml.toSQL( query, { accountIDs : [] } );
					expect( sqlNoValues ).notToInclude( "WHERE" );
				} );

				it( "includes clause when param has value", function() {
					var query = [
						{ from : "users" },
						{ select : "*" },
						{
							when  : { param : "status", hasValue : true },
							where : [ "status", { "$param" : "status" } ]
						}
					];

					var sqlWithStatus = qbml.toSQL( query, { status : "active" } );
					expect( sqlWithStatus ).toInclude( "WHERE" );

					var sqlNoStatus = qbml.toSQL( query, {} );
					expect( sqlNoStatus ).notToInclude( "WHERE" );
				} );

				it( "supports else clause with params", function() {
					var query = [
						{ from : "users" },
						{ select : "*" },
						{
							when      : { param : "accountIDs", notEmpty : true },
							whereIn   : [ "accountID", { "$param" : "accountIDs" } ],
							else      : { where : [ "accountID", ">", 0 ] }
						}
					];

					// With accountIDs - use whereIn
					var sqlWithIDs = qbml.toSQL( query, { accountIDs : [ 1, 2 ] } );
					expect( sqlWithIDs ).toInclude( "IN" );

					// Without accountIDs - use else clause
					var sqlNoIDs = qbml.toSQL( query, { accountIDs : [] } );
					expect( sqlNoIDs ).toInclude( ">" );
					expect( sqlNoIDs ).notToInclude( "IN" );
				} );

				it( "supports comparison conditions on params", function() {
					var query = [
						{ from : "products" },
						{ select : "*" },
						{
							when  : { param : "minPrice", gt : 0 },
							where : [ "price", ">=", { "$param" : "minPrice" } ]
						}
					];

					var sqlWithPrice = qbml.toSQL( query, { minPrice : 50 } );
					expect( sqlWithPrice ).toInclude( "WHERE" );
					expect( sqlWithPrice ).toInclude( ">=" );

					var sqlNoPrice = qbml.toSQL( query, { minPrice : 0 } );
					expect( sqlNoPrice ).notToInclude( "WHERE" );
				} );

				it( "combines multiple param conditions with and", function() {
					var query = [
						{ from : "orders" },
						{ select : "*" },
						{
							when : {
								"and" : [
									{ param : "startDate", hasValue : true },
									{ param : "endDate", hasValue : true }
								]
							},
							whereBetween : [ "orderDate", { "$param" : "startDate" }, { "$param" : "endDate" } ]
						}
					];

					var sqlBoth = qbml.toSQL( query, { startDate : "2024-01-01", endDate : "2024-12-31" } );
					expect( sqlBoth ).toInclude( "BETWEEN" );

					var sqlOnlyStart = qbml.toSQL( query, { startDate : "2024-01-01" } );
					expect( sqlOnlyStart ).notToInclude( "BETWEEN" );
				} );

				it( "supports or conditions on params", function() {
					var query = [
						{ from : "users" },
						{ select : "*" },
						{
							when : {
								"or" : [
									{ param : "isAdmin", eq : true },
									{ param : "userIDs", notEmpty : true }
								]
							},
							where : [ "isActive", true ]
						}
					];

					expect( qbml.toSQL( query, { isAdmin : true } ) ).toInclude( "WHERE" );
					expect( qbml.toSQL( query, { userIDs : [ 1, 2 ] } ) ).toInclude( "WHERE" );
					expect( qbml.toSQL( query, { isAdmin : false, userIDs : [] } ) ).notToInclude( "WHERE" );
				} );
			} );

			describe( "execute() with params", function() {
				it( "passes params through execute options", function() {
					// This tests that the params are properly extracted from options
					// We can't test actual execution without a database, but we can test toSQL
					var query = [
						{ from : "users" },
						{ select : "*" },
						{
							when    : { param : "accountIDs", notEmpty : true },
							whereIn : [ "accountID", { "$param" : "accountIDs" } ]
						},
						{ toSQL : true }
					];

					// The build() method should resolve params
					var q = qbml.build( query, { accountIDs : [ 1, 2, 3 ] } );
					expect( q.toSQL() ).toInclude( "IN" );
				} );
			} );

			describe( "Dataviewer use case", function() {
				it( "handles the accountIDs filtering scenario", function() {
					// This is the main use case from the user's dataviewer
					var query = [
						{ from : "accounts" },
						{ select : [ "id", "name", "status" ] },
						{
							when    : { param : "accountIDs", notEmpty : true },
							whereIn : [ "id", { "$param" : "accountIDs" } ]
						},
						{
							when  : { param : "status", hasValue : true },
							where : [ "status", { "$param" : "status" } ]
						},
						{ orderBy : [ "name", "asc" ] }
					];

					// With both params
					var sql1 = qbml.toSQL( query, { accountIDs : [ 1, 2, 3 ], status : "active" } );
					expect( sql1 ).toInclude( "IN" );
					expect( sql1 ).toInclude( "status" );

					// With only accountIDs
					var sql2 = qbml.toSQL( query, { accountIDs : [ 1, 2, 3 ] } );
					expect( sql2 ).toInclude( "IN" );
					expect( sql2 ).notToInclude( "status =" );

					// With only status
					var sql3 = qbml.toSQL( query, { status : "active" } );
					expect( sql3 ).notToInclude( "IN" );
					expect( sql3 ).toInclude( "status" );

					// With no params - no WHERE clause at all
					var sql4 = qbml.toSQL( query, {} );
					expect( sql4 ).notToInclude( "WHERE" );
				} );

				it( "handles complex filtering with multiple conditions", function() {
					var query = [
						{ from : "transactions" },
						{ select : "*" },
						{
							when    : { param : "accountIDs", notEmpty : true },
							whereIn : [ "accountID", { "$param" : "accountIDs" } ]
						},
						{
							when : {
								"and" : [
									{ param : "startDate", hasValue : true },
									{ param : "endDate", hasValue : true }
								]
							},
							whereBetween : [ "transactionDate", { "$param" : "startDate" }, { "$param" : "endDate" } ]
						},
						{
							when  : { param : "minAmount", gt : 0 },
							where : [ "amount", ">=", { "$param" : "minAmount" } ]
						},
						{
							when    : { param : "types", notEmpty : true },
							whereIn : [ "type", { "$param" : "types" } ]
						}
					];

					var params = {
						accountIDs : [ 1, 2 ],
						startDate  : "2024-01-01",
						endDate    : "2024-12-31",
						minAmount  : 100,
						types      : [ "credit", "debit" ]
					};

					var sql = qbml.toSQL( query, params );
					expect( sql ).toInclude( "accountID" );
					expect( sql ).toInclude( "BETWEEN" );
					expect( sql ).toInclude( ">=" );
					expect( sql ).toInclude( "type" );
				} );
			} );
		} );
	}

}
