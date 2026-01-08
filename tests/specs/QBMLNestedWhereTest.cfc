/**
 * QBML Nested WHERE Clauses Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Nested WHERE clauses", function() {
			it( "groups where conditions with legacy clauses syntax", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "status", "role" ] },
					{
						"where"   : true,
						"clauses" : [
							{ "where" : [ "status", "active" ] },
							{ "andWhere" : [ "role", "user" ] }
						]
					},
					{ "orWhere" : [ "role", "admin" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				// (active AND user) OR admin = 4 + 1 = 5
				expect( result.len() ).toBe( 5 );
			} );

			it( "groups where conditions with array of objects syntax", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "status", "role" ] },
					{
						"where" : [
							{ "where" : [ "status", "active" ] },
							{ "andWhere" : [ "role", "user" ] }
						]
					},
					{ "orWhere" : [ "role", "admin" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				// (active AND user) OR admin = 4 + 1 = 5
				expect( result.len() ).toBe( 5 );
			} );
		} );
	}

}
