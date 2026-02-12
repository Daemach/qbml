/**
 * QBML Complex Integration Tests
 *
 * Tests complex real-world QBML queries against actual database tables.
 * Requires test tables from tests/sql/setup.sql to be created first.
 *
 * For individual feature tests, see:
 *   - QBMLSelectTest.cfc - Basic SELECT queries
 *   - QBMLWhereTest.cfc - WHERE conditions
 *   - QBMLNestedWhereTest.cfc - Nested WHERE clauses
 *   - QBMLJoinTest.cfc - JOIN operations
 *   - QBMLGroupingTest.cfc - GROUP BY and HAVING
 *   - QBMLOrderingTest.cfc - ORDER BY
 *   - QBMLPaginationTest.cfc - LIMIT, OFFSET, pagination
 *   - QBMLCTETest.cfc - Common Table Expressions
 *   - QBMLSubqueryTest.cfc - Subqueries
 *   - QBMLUnionTest.cfc - UNION queries
 *   - QBMLWhenTest.cfc - Conditional (when) queries
 *   - QBMLExecutorTest.cfc - Executors (get, first, count, etc.)
 *   - QBMLObjectSyntaxTest.cfc - Object-form arguments
 *   - QBMLDynamicMethodTest.cfc - Dynamic method generation
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Complex real-world queries", function() {
			it( "generates user activity report", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{
						"select" : [
							"u.id",
							"u.username",
							"u.email",
							"u.status",
							"d.name as department"
						]
					},
					{ "leftJoin" : [ "qbml_departments d", "u.department_id", "=", "d.id" ] },
					{
						"subSelect" : "order_count",
						"query"     : [
							{ "from" : "qbml_orders o" },
							{ "selectRaw" : "COUNT(*)" },
							{ "whereColumn" : [ "o.user_id", "=", "u.id" ] }
						]
					},
					{
						"subSelect" : "total_spent",
						"query"     : [
							{ "from" : "qbml_orders o" },
							{ "selectRaw" : "COALESCE(SUM(total), 0)" },
							{ "whereColumn" : [ "o.user_id", "=", "u.id" ] }
						]
					},
					{ "where" : [ "u.status", "=", "active" ] },
					{ "orderByDesc" : "total_spent" },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result[ 1 ] ).toHaveKey( "order_count" );
				expect( result[ 1 ] ).toHaveKey( "total_spent" );
				expect( result[ 1 ] ).toHaveKey( "department" );
			} );

			it( "generates product sales report", function() {
				var query = [
					{ "from" : "qbml_products p" },
					{ "select" : [ "p.id", "p.name", "p.sku", "p.price", "c.name as category" ] },
					{ "leftJoin" : [ "qbml_categories c", "p.category_id", "=", "c.id" ] },
					{
						"subSelect" : "units_sold",
						"query"     : [
							{ "from" : "qbml_order_items oi" },
							{ "selectRaw" : "COALESCE(SUM(quantity), 0)" },
							{ "whereColumn" : [ "oi.product_id", "=", "p.id" ] }
						]
					},
					{
						"subSelect" : "revenue",
						"query"     : [
							{ "from" : "qbml_order_items oi" },
							{ "selectRaw" : "COALESCE(SUM(line_total), 0)" },
							{ "whereColumn" : [ "oi.product_id", "=", "p.id" ] }
						]
					},
					{ "where" : [ "p.is_active", "=", 1 ] },
					{ "orderByDesc" : "revenue" },
					{ "limit" : 10 },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result[ 1 ] ).toHaveKey( "units_sold" );
				expect( result[ 1 ] ).toHaveKey( "revenue" );
			} );

			it( "filters orders with multiple conditions", function() {
				var filters = {
					statuses    : [ "pending", "processing" ],
					minTotal    : 50,
					dateFrom    : "2024-11-01",
					includeUser : true
				};

				var query = [
					{ "from" : "qbml_orders o" },
					{ "select" : [ "o.id", "o.order_number", "o.status", "o.total", "o.order_date" ] },
					{
						"when"    : "hasValues",
						"whereIn" : [ "o.status", filters.statuses ]
					},
					{
						"when"  : { "gt" : [ 1, 0 ] },
						"where" : [ "o.total", ">=", filters.minTotal ]
					},
					{
						"when"  : { "neq" : [ 1, "" ] },
						"where" : [ "o.order_date", ">=", filters.dateFrom ]
					},
					{ "orderByDesc" : "o.order_date" },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();

				for ( var row in result ) {
					expect( [ "pending", "processing" ] ).toInclude( row.status );
					expect( row.total ).toBeGTE( 50 );
				}
			} );
		} );
	}

}
