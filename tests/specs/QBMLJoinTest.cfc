/**
 * QBML JOIN Operations Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "JOIN operations", function() {
			it( "performs inner join", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.id", "u.username", "p.first_name", "p.last_name" ] },
					{ "join" : [ "qbml_user_profiles p", "u.id", "=", "p.user_id" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 9 );
			} );

			it( "performs left join", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.id", "u.username", "p.first_name" ] },
					{ "leftJoin" : [ "qbml_user_profiles p", "u.id", "=", "p.user_id" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 12 );
			} );

			it( "performs join with closure for complex conditions", function() {
				var query = [
					{ "from" : "qbml_orders o" },
					{ "select" : [ "o.id", "o.order_number", "u.username" ] },
					{
						"leftJoin" : "qbml_users u",
						"on"       : [
							{ "on" : [ "o.user_id", "=", "u.id" ] }
						]
					},
					{ "where" : [ "o.status", "=", "delivered" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 5 );
			} );

			it( "joins multiple tables", function() {
				var query = [
					{ "from" : "qbml_order_items oi" },
					{ "select" : [ "o.order_number", "p.name as product_name", "oi.quantity", "oi.line_total" ] },
					{ "join" : [ "qbml_orders o", "oi.order_id", "=", "o.id" ] },
					{ "join" : [ "qbml_products p", "oi.product_id", "=", "p.id" ] },
					{ "where" : [ "o.id", "=", 1 ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 2 );
			} );

			it( "performs join with 3-argument shorthand (operator defaults to =)", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.id", "u.username", "p.first_name", "p.last_name" ] },
					{ "join" : [ "qbml_user_profiles p", "u.id", "p.user_id" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 9 );
			} );

			it( "performs left join with 3-argument shorthand", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.id", "u.username", "p.first_name" ] },
					{ "leftJoin" : [ "qbml_user_profiles p", "u.id", "p.user_id" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 12 );
			} );

			it( "performs right join with 3-argument shorthand", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.id", "u.username", "d.name as dept_name" ] },
					{ "rightJoin" : [ "qbml_departments d", "u.department_id", "d.id" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
			} );
		} );

		describe( "JOIN with subquery", function() {
			it( "joins with a subquery", function() {
				var query = [
					{ "from" : "qbml_users u" },
					{ "select" : [ "u.username", "recent.order_count" ] },
					{
						"joinSub" : "recent",
						"query"   : [
							{ "from" : "qbml_orders" },
							{ "selectRaw" : "user_id, COUNT(*) as order_count" },
							{ "where" : [ "status", "=", "delivered" ] },
							{ "groupBy" : [ "user_id" ] }
						],
						"on" : [ { "on" : [ "u.id", "=", "recent.user_id" ] } ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result.len() ).toBeGT( 0 );
			} );
		} );
	}

}
