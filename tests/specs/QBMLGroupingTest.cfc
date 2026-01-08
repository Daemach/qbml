/**
 * QBML GROUP BY and HAVING Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "GROUP BY and HAVING", function() {
			it( "groups by column", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "selectRaw" : "status, COUNT(*) as cnt" },
					{ "groupBy" : [ "status" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 4 ); // active, inactive, pending, deleted
			} );

			it( "filters with havingRaw", function() {
				var query = [
					{ "from" : "qbml_orders" },
					{ "selectRaw" : "user_id, COUNT(*) as order_count" },
					{ "groupBy" : [ "user_id" ] },
					{ "havingRaw" : [ "COUNT(*) > ?", [ 1 ] ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 2 );
			} );

			it( "uses havingRaw with SUM", function() {
				var query = [
					{ "from" : "qbml_order_items" },
					{ "selectRaw" : "product_id, SUM(quantity) as total_qty" },
					{ "groupBy" : [ "product_id" ] },
					{ "havingRaw" : [ "SUM(quantity) >= ?", [ 2 ] ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result.len() ).toBeGT( 0 );
			} );
		} );
	}

}
