/**
 * QBML UNION Query Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "UNION queries", function() {
			it( "unions two queries", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "username as name", "email" ] },
					{ "where" : [ "role", "=", "admin" ] },
					{
						"union" : true,
						"query" : [
							{ "from" : "qbml_users" },
							{ "select" : [ "username as name", "email" ] },
							{ "where" : [ "role", "=", "manager" ] }
						]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 3 );
			} );
		} );
	}

}
