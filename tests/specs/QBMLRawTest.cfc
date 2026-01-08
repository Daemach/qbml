/**
 * Tests for QBML $raw inline support
 * Tests $raw value resolution and security validation
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
			grammar  : grammar,
			utils    : utils,
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
		variables.qbml.setTabular( new qbml.models.Tabular() );
	}

	function run() {
		describe( "QBML $raw Inline Support", function() {
			// ============================================
			// $raw IN SELECT
			// ============================================
			describe( "$raw in SELECT", function() {
				it( "embeds raw expression in select array", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : "COUNT(*)" }, "name" ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "COUNT(*)" );
					expect( sql ).toInclude( "[name]" );
				} );

				it( "uses $raw as alias with AS", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : "COUNT(*) AS total_count" } ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "COUNT(*) AS total_count" );
				} );

				it( "mixes multiple $raw with regular columns", function() {
					var query = [
						{ from : "orders" },
						{
							select : [
								"id",
								{ "$raw" : "SUM(total) AS order_total" },
								"status",
								{ "$raw" : "COUNT(*) AS order_count" }
							]
						},
						{ groupBy : [ "id", "status" ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "[id]" );
					expect( sql ).toInclude( "SUM(total) AS order_total" );
					expect( sql ).toInclude( "[status]" );
					expect( sql ).toInclude( "COUNT(*) AS order_count" );
				} );

				it( "supports $raw with object form (sql + bindings)", function() {
					var query = [
						{ from : "users" },
						{
							select : [
								{
									"$raw" : {
										sql      : "COALESCE(name, ?) AS display_name",
										bindings : [ "Unknown" ]
									}
								}
							]
						}
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "COALESCE(name, ?) AS display_name" );
				} );

				it( "uses $raw for complex expressions", function() {
					var query = [
						{ from : "products" },
						{
							select : [
								"name",
								{
									"$raw" : "CASE WHEN price > 100 THEN 'expensive' ELSE 'affordable' END AS price_category"
								}
							]
						}
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "CASE WHEN price > 100 THEN" );
				} );
			} );

			// ============================================
			// $raw IN WHERE CONDITIONS
			// ============================================
			describe( "$raw in WHERE conditions", function() {
				it( "embeds $raw in whereIn values", function() {
					var query = [
						{ from : "users" },
						{ select : "*" },
						{ whereIn : [ "status", { "$raw" : "(SELECT DISTINCT status FROM active_statuses)" } ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "(SELECT DISTINCT status FROM active_statuses)" );
				} );

				it( "uses $raw in where value position", function() {
					var query = [
						{ from : "orders" },
						{ select : "*" },
						{ where : [ "total", ">", { "$raw" : "(SELECT AVG(total) FROM orders)" } ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "(SELECT AVG(total) FROM orders)" );
				} );

				it( "uses whereRaw for complex column expressions", function() {
					// Note: For $raw in the column position, use whereRaw instead
					var query = [
						{ from : "products" },
						{ select : "*" },
						{ whereRaw : "DATEDIFF(day, created_at, GETDATE()) < 30" }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "DATEDIFF(day, created_at, GETDATE())" );
				} );
			} );

			// ============================================
			// NOTE: For ORDER BY with raw SQL, use orderByRaw action
			// $raw inline is not supported in orderBy value position
			// since orderBy expects column/direction, not expressions
			// ============================================

			// ============================================
			// $raw IN JOINS - joinRaw uses raw table with normal columns
			// ============================================
			describe( "$raw in JOINs", function() {
				it( "uses joinRaw for raw table with column conditions", function() {
					// joinRaw takes raw table string, then normal column args
					var query = [
						{ from : "users u" },
						{ select : [ "u.id", "u.name" ] },
						{ joinRaw : [ "profiles (nolock) p", "u.id", "=", "p.user_id" ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "JOIN" );
					expect( sql ).toInclude( "profiles (nolock) p" );
				} );
			} );

			// ============================================
			// $raw WITH $param COMBINATION
			// ============================================
			describe( "$raw combined with $param", function() {
				it( "resolves $param and uses $raw in select", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : "LEN(name) AS name_length" } ] },
						{ whereIn : [ "status", { "$param" : "statuses" } ] }
					];
					var params = { statuses : [ "active", "pending" ] };
					var sql    = qbml.toSQL( query, params );
					expect( sql ).toInclude( "IN" );
					expect( sql ).toInclude( "LEN(name) AS name_length" );
				} );

				it( "uses $param in whereIn and $raw in select together", function() {
					var query = [
						{ from : "orders" },
						{
							select : [
								"id",
								{ "$raw" : "DATEDIFF(day, created_at, GETDATE()) AS days_old" }
							]
						},
						{ whereIn : [ "user_id", { "$param" : "userIDs" } ] }
					];
					var params = { userIDs : [ 1, 2, 3 ] };
					var sql    = qbml.toSQL( query, params );
					expect( sql ).toInclude( "DATEDIFF(day, created_at, GETDATE()) AS days_old" );
					expect( sql ).toInclude( "IN" );
				} );
			} );

			// ============================================
			// SECURITY VALIDATION
			// ============================================
			describe( "$raw security validation", function() {
				it( "blocks dangerous SQL injection in $raw", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : "1; DROP TABLE users--" } ] }
					];
					expect( function() {
						qbml.toSQL( query );
					} ).toThrow( "QBML.InvalidRawExpression" );
				} );

				it( "blocks xp_cmdshell in $raw", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : "xp_cmdshell('dir')" } ] }
					];
					expect( function() {
						qbml.toSQL( query );
					} ).toThrow( "QBML.InvalidRawExpression" );
				} );

				it( "blocks UNION injection in $raw", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : "1 UNION SELECT password FROM admins" } ] }
					];
					expect( function() {
						qbml.toSQL( query );
					} ).toThrow( "QBML.InvalidRawExpression" );
				} );

				it( "allows safe aggregate functions in $raw", function() {
					var query = [
						{ from : "users" },
						{
							select : [
								{ "$raw" : "COUNT(*)" },
								{ "$raw" : "SUM(total)" },
								{ "$raw" : "AVG(price)" },
								{ "$raw" : "MIN(created_at)" },
								{ "$raw" : "MAX(updated_at)" }
							]
						}
					];
					// Should not throw
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "COUNT(*)" );
				} );

				it( "allows safe CASE expressions in $raw", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : "CASE WHEN status = 'active' THEN 1 ELSE 0 END" } ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "CASE" );
				} );

				it( "validates $raw in nested structures", function() {
					var query = [
						{ from : "users" },
						{ select : "*" },
						{
							whereIn : [
								"id",
								{ "$raw" : "(SELECT user_id FROM hacked; DROP TABLE users--)" }
							]
						}
					];
					expect( function() {
						qbml.toSQL( query );
					} ).toThrow( "QBML.InvalidRawExpression" );
				} );
			} );

			// ============================================
			// ERROR HANDLING
			// ============================================
			describe( "$raw error handling", function() {
				it( "throws for invalid $raw format", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : [ "invalid", "array" ] } ] }
					];
					expect( function() {
						qbml.toSQL( query );
					} ).toThrow( "QBML.InvalidRaw" );
				} );

				it( "throws for $raw object without sql key", function() {
					var query = [
						{ from : "users" },
						{ select : [ { "$raw" : { "query" : "SELECT 1" } } ] }
					];
					expect( function() {
						qbml.toSQL( query );
					} ).toThrow( "QBML.InvalidRaw" );
				} );
			} );

			// ============================================
			// HELPER FUNCTION TESTS
			// ============================================
			describe( "containsRawRefs helper", function() {
				it( "detects $raw in simple struct", function() {
					var value  = { "$raw" : "COUNT(*)" };
					var result = qbml.containsRawRefs( value );
					expect( result ).toBeTrue();
				} );

				it( "detects $raw in array", function() {
					var value  = [ "id", { "$raw" : "COUNT(*)" }, "name" ];
					var result = qbml.containsRawRefs( value );
					expect( result ).toBeTrue();
				} );

				it( "detects $raw in nested struct", function() {
					var value = {
						column : "id",
						values : { "$raw" : "(SELECT id FROM other)" }
					};
					var result = qbml.containsRawRefs( value );
					expect( result ).toBeTrue();
				} );

				it( "returns false when no $raw present", function() {
					var value  = [ "id", "name", "email" ];
					var result = qbml.containsRawRefs( value );
					expect( result ).toBeFalse();
				} );
			} );

			// ============================================
			// REAL-WORLD USE CASES
			// ============================================
			describe( "Real-world use cases", function() {
				it( "dashboard metrics query with multiple raw aggregates", function() {
					var query = [
						{ from : "orders" },
						{
							select : [
								{ "$raw" : "COUNT(*) AS total_orders" },
								{ "$raw" : "SUM(total) AS revenue" },
								{ "$raw" : "AVG(total) AS avg_order_value" },
								{ "$raw" : "COUNT(DISTINCT user_id) AS unique_customers" }
							]
						},
						{ where : [ "status", "=", "completed" ] }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "COUNT(*) AS total_orders" );
					expect( sql ).toInclude( "SUM(total) AS revenue" );
					expect( sql ).toInclude( "AVG(total) AS avg_order_value" );
					expect( sql ).toInclude( "COUNT(DISTINCT user_id) AS unique_customers" );
				} );

				it( "conditional aggregation with CASE", function() {
					var query = [
						{ from : "users" },
						{
							select : [
								{ "$raw" : "COUNT(CASE WHEN status = 'active' THEN 1 END) AS active_count" },
								{ "$raw" : "COUNT(CASE WHEN status = 'inactive' THEN 1 END) AS inactive_count" }
							]
						}
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "CASE WHEN status = 'active'" );
					expect( sql ).toInclude( "CASE WHEN status = 'inactive'" );
				} );

				it( "date-based filtering with whereRaw", function() {
					// Note: For complex where conditions with raw on both sides, use whereRaw
					var query = [
						{ from : "events" },
						{ select : "*" },
						{ whereRaw : "CAST(event_date AS DATE) = CAST(GETDATE() AS DATE)" }
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "CAST(event_date AS DATE)" );
					expect( sql ).toInclude( "CAST(GETDATE() AS DATE)" );
				} );

				it( "subquery in select with $raw", function() {
					var query = [
						{ from : "users u" },
						{
							select : [
								"u.id",
								"u.name",
								{ "$raw" : "(SELECT COUNT(*) FROM orders WHERE orders.user_id = u.id) AS order_count" }
							]
						}
					];
					var sql = qbml.toSQL( query );
					expect( sql ).toInclude( "(SELECT COUNT(*) FROM orders WHERE orders.user_id = u.id)" );
				} );
			} );
		} );
	}

}
