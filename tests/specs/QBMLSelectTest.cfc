/**
 * QBML Basic SELECT Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Basic SELECT queries", function() {
			it( "selects all columns from a table", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "*" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result.len() ).toBe( 12 );
			} );

			it( "selects specific columns", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "email" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result[ 1 ] ).toHaveKey( "id" );
				expect( result[ 1 ] ).toHaveKey( "username" );
				expect( result[ 1 ] ).toHaveKey( "email" );
			} );

			it( "uses table aliases from settings", function() {
				var query = [
					{ "from" : "users" },  // alias for qbml_users
					{ "select" : [ "id", "username" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result.len() ).toBe( 12 );
			} );

			it( "selects distinct values", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "status" ] },
					{ "distinct" : true },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				// Should get: active, inactive, pending, deleted
				expect( result.len() ).toBe( 4 );
			} );

			it( "uses addSelect to add columns", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id" ] },
					{ "addSelect" : [ "username", "email" ] },
					{ "first" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toHaveKey( "id" );
				expect( result ).toHaveKey( "username" );
				expect( result ).toHaveKey( "email" );
			} );
		} );
	}

}
