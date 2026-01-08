/**
 * QBML Object-form Arguments Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Object-form arguments", function() {
			describe( "WHERE clauses with object syntax", function() {
				it( "supports where with column, operator, value object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : { "column" : "status", "operator" : "=", "value" : "active" } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					expect( result.len() ).toBe( 8 );
				} );

				it( "supports where with column, value object (implicit = operator)", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : { "column" : "role", "value" : "admin" } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 1 );
					expect( result[ 1 ].username ).toBe( "admin" );
				} );

				it( "supports andWhere with object syntax", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : { "column" : "status", "value" : "active" } },
						{ "andWhere" : { "column" : "role", "value" : "user" } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 4 );
				} );

				it( "supports orWhere with object syntax", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : { "column" : "role", "value" : "admin" } },
						{ "orWhere" : { "column" : "role", "value" : "manager" } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 3 );
				} );

				it( "supports whereIn with column, values object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "status" ] },
						{ "whereIn" : { "column" : "status", "values" : [ "active", "pending" ] } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBeGTE( 8 );
				} );

				it( "supports whereNotIn with object syntax", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "status" ] },
						{ "whereNotIn" : { "column" : "status", "values" : [ "inactive", "deleted" ] } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBeGTE( 8 );
				} );

				it( "supports whereBetween with column, start, end object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "whereBetween" : { "column" : "id", "start" : 1, "end" : 5 } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 5 );
				} );

				it( "supports whereLike with object syntax", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "whereLike" : { "column" : "email", "value" : "%@example.com" } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBeGT( 0 );
				} );

				it( "supports whereNull with object syntax", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "whereNull" : { "column" : "deleted_at" } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
				} );

				it( "supports whereColumn with first, operator, second object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "created_at", "updated_at" ] },
						{ "whereColumn" : { "first" : "updated_at", "operator" : ">", "second" : "created_at" } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
				} );
			} );

			describe( "SELECT and FROM with object syntax", function() {
				it( "supports select with columns object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : { "columns" : [ "id", "username", "email" ] } },
						{ "first" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toHaveKey( "id" );
					expect( result ).toHaveKey( "username" );
					expect( result ).toHaveKey( "email" );
				} );

				it( "supports select with single column object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : { "column" : "username" } },
						{ "first" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toHaveKey( "username" );
				} );

				it( "supports from with string value", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					expect( result.len() ).toBe( 12 );
				} );
			} );

			describe( "ORDER BY, LIMIT, OFFSET with object syntax", function() {
				it( "supports orderBy with column, direction object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "orderBy" : { "column" : "username", "direction" : "desc" } },
						{ "first" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
				} );

				it( "supports orderBy with column only (implicit asc)", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "orderBy" : { "column" : "username" } },
						{ "first" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
				} );

				it( "supports limit with value object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "limit" : { "value" : 3 } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 3 );
				} );

				it( "supports offset with value object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "orderBy" : [ "id", "asc" ] },
						{ "limit" : 3 },
						{ "offset" : { "value" : 2 } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 3 );
					expect( result[ 1 ].id ).toBe( 3 );
				} );

				it( "supports forPage with page, size object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "orderBy" : [ "id", "asc" ] },
						{ "forPage" : { "page" : 2, "size" : 3 } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 3 );
					expect( result[ 1 ].id ).toBe( 4 );
				} );
			} );

			describe( "GROUP BY and HAVING with object syntax", function() {
				it( "supports groupBy with columns object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "status" ] },
						{ "selectRaw" : "COUNT(*) as user_count" },
						{ "groupBy" : { "columns" : [ "status" ] } },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 4 );
				} );

				it( "supports having with column, operator, value object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "role" ] },
						{ "selectRaw" : "COUNT(*) as role_count" },
						{ "groupBy" : [ "role" ] },
						{ "havingRaw" : "COUNT(*) > 1" },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					expect( result.len() ).toBeGTE( 2 );
				} );
			} );

			describe( "JOIN with object syntax", function() {
				it( "supports join with table, first, operator, second object", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "qbml_users.id", "qbml_users.username", "qbml_user_profiles.bio" ] },
						{
							"join" : {
								"table"    : "qbml_user_profiles",
								"first"    : "qbml_users.id",
								"operator" : "=",
								"second"   : "qbml_user_profiles.user_id"
							}
						},
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					expect( result.len() ).toBe( 9 );
				} );

				it( "supports leftJoin with object syntax (implicit = operator)", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "qbml_users.id", "qbml_users.username", "qbml_user_profiles.bio" ] },
						{
							"leftJoin" : {
								"table"  : "qbml_user_profiles",
								"first"  : "qbml_users.id",
								"second" : "qbml_user_profiles.user_id"
							}
						},
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					expect( result.len() ).toBe( 12 );
				} );
			} );

			describe( "RAW expressions with array syntax", function() {
				it( "supports selectRaw with array", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "selectRaw" : "COUNT(*) as total" },
						{ "first" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toHaveKey( "total" );
					expect( result.total ).toBe( 12 );
				} );

				it( "supports whereRaw with bindings array", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "whereRaw" : [ "status = ?", [ "active" ] ] },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result.len() ).toBe( 8 );
				} );
			} );

			describe( "Mixed array and object syntax", function() {
				it( "allows mixing array and object forms in same query", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "status" ] },
						{ "where" : { "column" : "status", "value" : "active" } },
						{ "andWhere" : [ "role", "=", "user" ] },
						{ "orderBy" : { "column" : "username", "direction" : "asc" } },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
					expect( result.len() ).toBeLTE( 5 );
				} );
			} );
		} );
	}

}
