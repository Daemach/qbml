/**
 * QBML ORDER BY Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "ORDER BY", function() {
			it( "orders by single column ascending", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "orderBy" : [ "username", "asc" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result[ 1 ].username ).toBe( "admin" );
				expect( result[ 2 ].username ).toBe( "agarcia" );
			} );

			it( "orders by column descending", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "salary" ] },
					{ "whereNotNull" : "salary" },
					{ "orderByDesc" : "salary" },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result[ 1 ].salary ).toBe( 150000 );
			} );

			it( "orders by multiple columns", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "status", "username" ] },
					{ "orderBy" : [ "status", "asc" ] },
					{ "orderBy" : [ "username", "asc" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result[ 1 ].status ).toBe( "active" );
			} );
		} );
	}

}
