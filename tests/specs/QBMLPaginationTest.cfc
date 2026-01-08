/**
 * QBML LIMIT, OFFSET, and Pagination Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "LIMIT and OFFSET", function() {
			it( "limits results", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "orderBy" : [ "id", "asc" ] },
					{ "limit" : 5 },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 5 );
				expect( result[ 1 ].id ).toBe( 1 );
			} );

			it( "uses offset", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "orderBy" : [ "id", "asc" ] },
					{ "limit" : 5 },
					{ "offset" : 5 },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 5 );
				expect( result[ 1 ].id ).toBe( 6 );
			} );

			it( "uses forPage pagination", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "orderBy" : [ "id", "asc" ] },
					{ "forPage" : [ 2, 5 ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 5 );
				expect( result[ 1 ].id ).toBe( 6 );
			} );
		} );
	}

}
