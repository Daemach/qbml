/**
 * QBML WHERE Conditions Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "WHERE conditions", function() {
			it( "filters with simple where", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "where" : [ "status", "=", "active" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 8 );
			} );

			it( "uses shorthand where (column, value)", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "where" : [ "role", "admin" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 1 );
				expect( result[ 1 ].username ).toBe( "admin" );
			} );

			it( "combines multiple where conditions", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "where" : [ "status", "=", "active" ] },
					{ "andWhere" : [ "role", "=", "user" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 4 );
			} );

			it( "uses orWhere condition", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "where" : [ "role", "=", "admin" ] },
					{ "orWhere" : [ "role", "=", "manager" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 3 );
			} );

			it( "filters with whereIn", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "whereIn" : [ "status", [ "active", "pending" ] ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 9 );
			} );

			it( "filters with whereNotIn", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "whereNotIn" : [ "status", [ "deleted", "inactive" ] ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 9 );
			} );

			it( "filters with whereBetween", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "salary" ] },
					{ "whereBetween" : [ "salary", 90000, 100000 ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 4 );
			} );

			it( "filters with whereLike", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "email" ] },
					{ "whereLike" : [ "email", "%smith%" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 1 );
				expect( result[ 1 ].email ).toBe( "john.smith@example.com" );
			} );

			it( "filters with whereNull", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "whereNull" : "deleted_at" },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 11 );
			} );

			it( "filters with whereNotNull", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "whereNotNull" : "department_id" },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 11 );
			} );

			it( "filters with whereColumn comparing two columns", function() {
				var query = [
					{ "from" : "qbml_orders" },
					{ "select" : [ "id", "order_number", "subtotal", "total" ] },
					{ "whereColumn" : [ "total", ">", "subtotal" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result.len() ).toBeGT( 0 );
			} );
		} );
	}

}
