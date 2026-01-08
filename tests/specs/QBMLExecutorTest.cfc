/**
 * QBML Executor Tests
 */
component extends="tests.specs.QBMLBaseTest" {

	function beforeAll() {
		variables.qbml = getQBML();
	}

	function run() {
		describe( "Executors", function() {
			it( "returns first result", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "orderBy" : [ "id", "asc" ] },
					{ "first" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeStruct();
				expect( result.id ).toBe( 1 );
			} );

			it( "finds by ID", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "email" ] },
					{ "find" : [ 3, "id" ] }
				];

				var result = qbml.execute( query );
				expect( result ).toBeStruct();
				expect( result.username ).toBe( "mjones" );
			} );

			it( "returns single value", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "where" : [ "id", "=", 1 ] },
					{ "value" : "email" }
				];

				var result = qbml.execute( query );
				expect( result ).toBe( "admin@example.com" );
			} );

			it( "returns array of values", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "where" : [ "status", "=", "active" ] },
					{ "orderBy" : [ "username", "asc" ] },
					{ "values" : "username" }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result.len() ).toBe( 8 );
				expect( result[ 1 ] ).toBe( "admin" );
			} );

			it( "returns count", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "where" : [ "status", "=", "active" ] },
					{ "count" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBe( 8 );
			} );

			it( "returns sum", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "whereNotNull" : "salary" },
					{ "sum" : "salary" }
				];

				var result = qbml.execute( query );
				expect( result ).toBeGT( 0 );
			} );

			it( "returns average", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "whereNotNull" : "salary" },
					{ "avg" : "salary" }
				];

				var result = qbml.execute( query );
				expect( result ).toBeGT( 0 );
			} );

			it( "returns min value", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "whereNotNull" : "salary" },
					{ "min" : "salary" }
				];

				var result = qbml.execute( query );
				expect( result ).toBe( 75000 );
			} );

			it( "returns max value", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "whereNotNull" : "salary" },
					{ "max" : "salary" }
				];

				var result = qbml.execute( query );
				expect( result ).toBe( 150000 );
			} );

			it( "checks existence", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "where" : [ "role", "=", "superadmin" ] },
					{ "exists" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeFalse();

				query = [
					{ "from" : "qbml_users" },
					{ "where" : [ "role", "=", "admin" ] },
					{ "exists" : true }
				];

				result = qbml.execute( query );
				expect( result ).toBeTrue();
			} );

			it( "returns SQL string with toSQL", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "where" : [ "status", "=", "active" ] },
					{ "toSQL" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeString();
				expect( result ).toInclude( "SELECT" );
				expect( result ).toInclude( "qbml_users" );
			} );

			it( "paginates results", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "orderBy" : [ "id", "asc" ] },
					{ "paginate" : { "page" : 1, "maxRows" : 5 } }
				];

				var result = qbml.execute( query );
				expect( result ).toHaveKey( "results" );
				expect( result ).toHaveKey( "pagination" );
				expect( result.results.len() ).toBe( 5 );
				expect( result.pagination.totalRecords ).toBe( 12 );
				expect( result.pagination.totalPages ).toBe( 3 );
			} );
		} );

		describe( "Tabular return format", function() {
			it( "returns tabular format for get", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username", "email" ] },
					{ "where" : [ "status", "=", "active" ] },
					{ "orderBy" : [ "id", "asc" ] },
					{ "limit" : 3 },
					{ "get" : { "returnFormat" : "tabular" } }
				];

				var result = qbml.execute( query );

				expect( result ).toHaveKey( "columns" );
				expect( result ).toHaveKey( "rows" );
				expect( result.columns ).toBeArray();
				expect( result.rows ).toBeArray();
				expect( result.rows.len() ).toBe( 3 );
				expect( result.columns[ 1 ] ).toHaveKey( "name" );
				expect( result.columns[ 1 ] ).toHaveKey( "type" );
			} );

			it( "returns tabular format for paginate", function() {
				var query = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "orderBy" : [ "id", "asc" ] },
					{ "paginate" : { "page" : 1, "maxRows" : 5, "returnFormat" : "tabular" } }
				];

				var result = qbml.execute( query );

				expect( result ).toHaveKey( "pagination" );
				expect( result ).toHaveKey( "results" );
				expect( result.results ).toHaveKey( "columns" );
				expect( result.results ).toHaveKey( "rows" );
				expect( result.results.columns ).toBeArray();
				expect( result.results.rows ).toBeArray();
			} );
		} );

		describe( "Raw expressions", function() {
			it( "uses selectRaw", function() {
				var query = [
					{ "from" : "qbml_products" },
					{ "selectRaw" : "category_id, COUNT(*) as product_count, AVG(price) as avg_price" },
					{ "where" : [ "is_active", "=", 1 ] },
					{ "groupBy" : [ "category_id" ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result[ 1 ] ).toHaveKey( "product_count" );
				expect( result[ 1 ] ).toHaveKey( "avg_price" );
			} );

			it( "uses whereRaw with bindings", function() {
				var query = [
					{ "from" : "qbml_orders" },
					{ "select" : [ "id", "order_number", "total" ] },
					{ "whereRaw" : [ "YEAR(order_date) = ?", [ 2024 ] ] },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result.len() ).toBe( 10 );
			} );

			it( "uses orderByRaw", function() {
				var query = [
					{ "from" : "qbml_orders" },
					{ "select" : [ "id", "status" ] },
					{ "orderByRaw" : "CASE status WHEN 'pending' THEN 1 WHEN 'processing' THEN 2 WHEN 'shipped' THEN 3 WHEN 'delivered' THEN 4 ELSE 5 END" },
					{ "get" : true }
				];

				var result = qbml.execute( query );
				expect( result ).toBeArray();
				expect( result[ 1 ].status ).toBe( "pending" );
			} );
		} );

		describe( "Build method", function() {
			it( "builds query without executing", function() {
				var queryDef = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "where" : [ "status", "=", "active" ] }
				];

				var qbInstance = qbml.build( queryDef );

				expect( qbInstance ).toBeInstanceOf( "qb.models.Query.QueryBuilder" );

				var sql = qbInstance.toSQL();
				expect( sql ).toInclude( "SELECT" );
			} );
		} );

		describe( "toSQL method", function() {
			it( "returns SQL string directly", function() {
				var queryDef = [
					{ "from" : "qbml_users" },
					{ "select" : [ "id", "username" ] },
					{ "where" : [ "status", "=", "active" ] },
					{ "limit" : 10 }
				];

				var sql = qbml.toSQL( queryDef );

				expect( sql ).toBeString();
				expect( sql ).toInclude( "SELECT" );
				expect( sql ).toInclude( "qbml_users" );
				expect( sql ).toInclude( "status" );
			} );
		} );
	}

}
