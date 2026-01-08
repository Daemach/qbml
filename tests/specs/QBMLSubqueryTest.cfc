/**
 * QBML Subquery Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Subqueries", function() {
			it( "uses whereExists", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.id", "u.username" ] },
					{
						"whereExists" : true,
						"query"       : [
							{ "from" : "qbml_orders o" },
							{ "selectRaw" : "1" },
							{ "whereColumn" : [ "o.user_id", "=", "u.id" ] },
							{ "where" : [ "o.status", "=", "delivered" ] }
						]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBeGTE( 3 );
			} );

			it( "uses subSelect for scalar subquery", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.id", "u.username" ] },
					{
						"subSelect" : "order_count",
						"query"     : [
							{ "from" : "qbml_orders o" },
							{ "selectRaw" : "COUNT(*)" },
							{ "whereColumn" : [ "o.user_id", "=", "u.id" ] }
						]
					},
					{ "where" : [ "u.status", "=", "active" ] },
					{ "orderByDesc" : "order_count" },
					{ "limit" : 5 },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result[ 1 ] ).toHaveKey( "order_count" );
			} );

			it( "uses fromSub (derived table)", function() {
				var query = [
					{
						"fromSub" : "user_orders",
						"query"   : [
							{ "from" : "qbml_orders" },
							{ "selectRaw" : "user_id, COUNT(*) as order_count, SUM(total) as total_spent" },
							{ "groupBy" : [ "user_id" ] }
						]
					},
					{ "select" : [ "*" ] },
					{ "where" : [ "order_count", ">", 1 ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 2 );
			} );
		} );
	}

}
