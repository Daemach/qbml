/**
 * QBML Common Table Expressions (CTEs) Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "CTEs (WITH clause)", function() {
			it( "uses a simple CTE", function() {
				var query = [
					{
						"with"  : "active_users",
						"query" : [
							{ "from" : "qbml_users" },
							{ "select" : [ "id", "username", "email" ] },
							{ "where" : [ "status", "=", "active" ] }
						]
					},
					{ "from" : "active_users" },
					{ "select" : [ "*" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 8 );
			} );

			it( "uses multiple CTEs", function() {
				var query = [
					{
						"with"  : "managers",
						"query" : [
							{ "from" : "qbml_users" },
							{ "select" : [ "id", "username" ] },
							{ "whereIn" : [ "role", [ "admin", "manager" ] ] }
						]
					},
					{
						"with"  : "active_managers",
						"query" : [
							{ "from" : "managers" },
							{ "join" : [ "qbml_users u", "managers.id", "=", "u.id" ] },
							{ "select" : [ "managers.id", "managers.username" ] },
							{ "where" : [ "u.status", "=", "active" ] }
						]
					},
					{ "from" : "active_managers" },
					{ "select" : [ "*" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 3 );
			} );
		} );
	}

}
