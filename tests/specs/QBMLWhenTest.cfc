/**
 * QBML Conditional (when) Query Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Conditional (when) queries", function() {
			it( "applies whereIn when array has values", function() {
				var statuses = [ "active", "pending" ];
				var query    = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "status" ] },
					{
						"when"    : "hasValues",
						"whereIn" : [ "status", statuses ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 9 );
			} );

			it( "skips whereIn when array is empty", function() {
				var statuses = [];
				var query    = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{
						"when"    : "hasValues",
						"whereIn" : [ "status", statuses ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 12 );
			} );

			it( "uses else clause when condition is false", function() {
				var statuses = [];
				var query    = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{
						"when"    : "hasValues",
						"whereIn" : [ "status", statuses ],
						"else"    : { "where" : [ "status", "=", "active" ] }
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 8 );
			} );

			it( "evaluates comparison conditions", function() {
				var minSalary = 100000;
				var query     = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "salary" ] },
					{ "whereNotNull" : "salary" },
					{
						"when"  : { "gte" : [ 1, 100000 ] },
						"where" : [ "salary", ">=", minSalary ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 5 );
			} );

			it( "evaluates gt condition", function() {
				var threshold = 100000;
				var query     = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "salary" ] },
					{ "whereNotNull" : "salary" },
					{
						"when"  : { "gt" : [ 1, 50000 ] },
						"where" : [ "salary", ">", threshold ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 4 );
			} );

			it( "evaluates lt condition with params", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "salary" ] },
					{ "whereNotNull" : "salary" },
					{
						"when"  : { "param" : "maxSalary", "lt" : 100000 },
						"where" : [ "salary", "<", { "$param" : "maxSalary" } ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query, { params : { maxSalary : 85000 } } );
				expect( result.len() ).toBe( 2 );
			} );

			it( "evaluates lte condition with params", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "salary" ] },
					{ "whereNotNull" : "salary" },
					{
						"when"  : { "param" : "maxSalary", "lte" : 100000 },
						"where" : [ "salary", "<=", { "$param" : "maxSalary" } ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query, { params : { maxSalary : 85000 } } );
				// Users with salary <= 85000: gwhite(75000), fmiller(80000), dkim(85000)
				expect( result.len() ).toBe( 3 );
			} );

			it( "evaluates eq condition with params", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "role" ] },
					{
						"when"  : { "param" : "role", "eq" : "admin" },
						"where" : [ "role", { "$param" : "role" } ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query, { params : { role : "admin" } } );
				expect( result.len() ).toBe( 1 );
			} );

			it( "skips action when eq condition is false", function() {
				var role  = "nonexistent";
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{
						"when"  : { "eq" : [ 1, "admin" ] },
						"where" : [ "role", role ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 12 );
			} );

			it( "evaluates neq condition", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "status" ] },
					{
						"when"  : { "neq" : [ 1, "" ] },
						"where" : [ "status", "active" ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 8 );
			} );

			it( "evaluates notEmpty condition with struct syntax", function() {
				var statuses = [ "active" ];
				var query    = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{
						"when"    : { "notEmpty" : true },
						"whereIn" : [ "status", statuses ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 8 );
			} );

			it( "evaluates isEmpty condition with params", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{
						"when"  : { "param" : "statuses", "isEmpty" : true },
						"where" : [ "status", "active" ]
					},
					{ "get" : true }
				];

				// statuses is empty, so condition is true, filter is applied
				var result = qbml.execute( query, { params : { statuses : [] } } );
				expect( result.len() ).toBe( 8 );
			} );

			it( "evaluates and condition (all must be true)", function() {
				var minSalary = 90000;
				var query     = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "salary", "status" ] },
					{ "whereNotNull" : "salary" },
					{
						"when" : {
							"and" : [
								{ "gt" : [ 1, 50000 ] },
								{ "neq" : [ 2, "" ] }
							]
						},
						"where" : [ "salary", ">=", minSalary ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBeGTE( 5 );
			} );

			it( "evaluates or condition (any must be true)", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "role" ] },
					{
						"when" : {
							"or" : [
								{ "param" : "includeAdmins", "eq" : true },
								{ "param" : "includeManagers", "eq" : true }
							]
						},
						"whereIn" : [ "role", [ "admin", "manager" ] ]
					},
					{ "get" : true }
				];

				// At least one condition is true, so whereIn is applied
				var result = qbml.execute( query, { params : { includeAdmins : true, includeManagers : false } } );
				expect( result.len() ).toBe( 3 );
			} );

			it( "evaluates not condition", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{
						"when"  : { "not" : { "eq" : [ 1, "" ] } },
						"where" : [ "status", "active" ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 8 );
			} );

			it( "skips action when and condition has false component", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{
						"when" : {
							"and" : [
								{ "gt" : [ 1, 50000 ] },
								{ "eq" : [ 1, 0 ] }
							]
						},
						"where" : [ "status", "nonexistent" ]
					},
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result.len() ).toBe( 12 );
			} );
		} );
	}

}
