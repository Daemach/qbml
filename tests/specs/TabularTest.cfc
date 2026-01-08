component extends="testbox.system.BaseSpec" {

	function beforeAll() {
		variables.tabular = new qbml.models.Tabular();
	}

	function run() {
		describe( "Tabular", function() {
			describe( "fromArray", function() {
				it( "converts array of structs to tabular format", function() {
					var data = [
						{ id : 1, name : "Alice", status : "active" },
						{ id : 2, name : "Bob", status : "inactive" }
					];

					var result = tabular.fromArray( data );

					expect( result ).toHaveKey( "columns" );
					expect( result ).toHaveKey( "rows" );
					expect( result.columns ).toBeArray();
					expect( result.rows ).toBeArray();
					expect( result.rows.len() ).toBe( 2 );
				} );

				it( "detects column types with deep seeking", function() {
					var data = [
						{ count : 100, amount : 99.99, active : true, created : now() }
					];

					var result = tabular.fromArray( data );

					// Check that columns have type info
					for ( var col in result.columns ) {
						expect( col ).toHaveKey( "name" );
						expect( col ).toHaveKey( "type" );
					}
				} );

				it( "returns empty tabular for empty array", function() {
					var result = tabular.fromArray( [] );
					expect( result.columns ).toBeEmpty();
					expect( result.rows ).toBeEmpty();
				} );

				it( "returns empty tabular if first element is not a struct", function() {
					var data   = [ 1, 2, 3 ];
					var result = tabular.fromArray( data );
					expect( result.columns ).toBeEmpty();
					expect( result.rows ).toBeEmpty();
				} );

				it( "promotes integer to decimal when mixed", function() {
					var data = [
						{ value : 100 },
						{ value : 50.5 },
						{ value : 75 }
					];

					var result = tabular.fromArray( data );

					var valueCol = result.columns.filter( function( c ) {
						return c.name == "value";
					} );
					expect( valueCol[ 1 ].type ).toBe( "decimal" );
				} );

				it( "detects integers correctly", function() {
					var data = [
						{ id : 1 },
						{ id : 2 },
						{ id : 3 }
					];

					var result = tabular.fromArray( data );

					var idCol = result.columns.filter( function( c ) {
						return c.name == "id";
					} );
					expect( idCol[ 1 ].type ).toBe( "integer" );
				} );
			} );

			describe( "toArray (decompress)", function() {
				it( "converts tabular back to array of structs", function() {
					var tabularData = {
						columns : [
							{ name : "id", type : "integer" },
							{ name : "name", type : "varchar" }
						],
						rows : [
							[ 1, "Alice" ],
							[ 2, "Bob" ]
						]
					};

					var result = tabular.toArray( tabularData );

					expect( result ).toBeArray();
					expect( result.len() ).toBe( 2 );
					expect( result[ 1 ] ).toHaveKey( "id" );
					expect( result[ 1 ] ).toHaveKey( "name" );
					expect( result[ 1 ].id ).toBe( 1 );
					expect( result[ 1 ].name ).toBe( "Alice" );
				} );

				it( "returns empty array for empty tabular", function() {
					var result = tabular.toArray( { columns : [], rows : [] } );
					expect( result ).toBeArray();
					expect( result ).toBeEmpty();
				} );

				it( "handles missing keys gracefully", function() {
					var result = tabular.toArray( {} );
					expect( result ).toBeArray();
					expect( result ).toBeEmpty();
				} );
			} );

			describe( "fromPagination", function() {
				it( "transforms pagination results to tabular format", function() {
					var paginationResult = {
						results : [
							{ id : 1, name : "Alice" },
							{ id : 2, name : "Bob" }
						],
						pagination : {
							page         : 1,
							maxRows      : 25,
							totalRecords : 2,
							totalPages   : 1
						}
					};

					var result = tabular.fromPagination( paginationResult, "results" );

					// Pagination should be preserved
					expect( result ).toHaveKey( "pagination" );
					expect( result.pagination.page ).toBe( 1 );

					// Results should be in tabular format
					expect( result.results ).toHaveKey( "columns" );
					expect( result.results ).toHaveKey( "rows" );
					expect( result.results.rows.len() ).toBe( 2 );
				} );

				it( "handles nested data structures", function() {
					var paginationResult = {
						data : {
							main   : [ { id : 1 }, { id : 2 } ],
							detail : { some : "value" }
						},
						pagination : { page : 1 }
					};

					var result = tabular.fromPagination( paginationResult, "data" );

					// Main should be tabular
					expect( result.data.main ).toHaveKey( "columns" );
					expect( result.data.main ).toHaveKey( "rows" );

					// Detail should be unchanged (not an array)
					expect( result.data.detail.some ).toBe( "value" );
				} );
			} );

		} );
	}

}
