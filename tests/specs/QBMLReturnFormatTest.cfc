/**
 * QBML Return Format Tests
 *
 * Tests for the returnFormat configuration and override behavior.
 * Priority: execute() options > query definition > config defaults
 */
component extends="testbox.system.BaseSpec" {

	function isCI() {
		if (
			structKeyExists( server, "system" ) &&
			structKeyExists( server.system, "environment" ) &&
			isStruct( server.system.environment )
		) {
			return (
				( structKeyExists( server.system.environment, "CI" ) && len( server.system.environment.CI ) ) ||
				( structKeyExists( server.system.environment, "GITHUB_ACTIONS" ) && len( server.system.environment.GITHUB_ACTIONS ) )
			);
		}
		return false;
	}

	function isBoxLang() {
		return structKeyExists( server, "boxlang" );
	}

	function usesMySQLGrammar() {
		if ( structKeyExists( server, "qbmlTestGrammar" ) ) {
			return server.qbmlTestGrammar == "MySQLGrammar";
		}
		return isCI() || isBoxLang();
	}

	function beforeAll() {
		// Create QB dependencies for standalone testing
		var utils = new qb.models.Query.QueryUtils();

		// Use MySQL grammar in CI or BoxLang, SqlServer for local development
		var grammar = usesMySQLGrammar()
			? new qb.models.Grammars.MySQLGrammar( utils )
			: new qb.models.Grammars.SqlServerGrammar( utils );

		// Create a QB provider
		variables.qbProvider = {
			grammar  : grammar,
			utils    : utils,
			newQuery : function() {
				var builder = new qb.models.Query.QueryBuilder();
				builder.setGrammar( grammar );
				builder.setUtils( utils );
				builder.setReturnFormat( "array" );
				return builder;
			}
		};
	}

	/**
	 * Helper to create a QBML instance with specific settings
	 */
	private function createQBML( struct settingsOverride = {} ) {
		var baseSettings = {
			tables   : { mode : "allow", list : [ "qbml_*" ] },
			aliases  : { "users" : "qbml_users" },
			defaults : {
				maxRows      : 1000,
				returnFormat : "array"
			}
		};

		// Merge overrides
		if ( structKeyExists( settingsOverride, "defaults" ) ) {
			structAppend( baseSettings.defaults, settingsOverride.defaults, true );
		}

		var qbml = new qbml.models.QBML( settings = baseSettings );
		qbml.setQb( variables.qbProvider );
		qbml.setSecurity( new qbml.models.QBMLSecurity( settings = baseSettings ) );
		qbml.setConditions( new qbml.models.QBMLConditions() );
		qbml.setFormatter( new qbml.models.ReturnFormat() );

		return qbml;
	}

	function run() {
		describe( "QBML Return Format Configuration", function() {
			// ============================================
			// Config defaults
			// ============================================
			describe( "Config defaults", function() {
				it( "returns array format by default (no config override)", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
				} );

				it( "returns tabular format when config defaults to tabular", function() {
					var qbml = createQBML( {
						defaults : { returnFormat : "tabular" }
					} );
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "columns" );
					expect( result ).toHaveKey( "rows" );
				} );

			} );

			// ============================================
			// Query definition override
			// ============================================
			describe( "Query definition override", function() {
				it( "query definition overrides config default (array -> tabular)", function() {
					var qbml  = createQBML(); // defaults to array
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : "tabular" } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "columns" );
					expect( result ).toHaveKey( "rows" );
				} );

				it( "query definition overrides config default (tabular -> array)", function() {
					var qbml = createQBML( {
						defaults : { returnFormat : "tabular" }
					} );
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : "array" } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
				} );
			} );

			// ============================================
			// Execute options override
			// ============================================
			describe( "Execute options override", function() {
				it( "execute() options override config default", function() {
					var qbml  = createQBML(); // defaults to array
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query, { returnFormat : "tabular" } );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "columns" );
					expect( result ).toHaveKey( "rows" );
				} );

				it( "execute() options override query definition", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : "tabular" } } // query says tabular
					];

					// execute() says array - this should win
					var result = qbml.execute( query, { returnFormat : "array" } );
					expect( result ).toBeArray();
				} );

			} );

			// ============================================
			// Pagination with return format
			// ============================================
			describe( "Pagination with return format", function() {
				it( "paginate respects config default returnFormat", function() {
					var qbml = createQBML( {
						defaults : { returnFormat : "tabular" }
					} );
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "paginate" : { "page" : 1, "maxRows" : 5 } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "pagination" );
					expect( result ).toHaveKey( "results" );
					expect( result.results ).toHaveKey( "columns" );
					expect( result.results ).toHaveKey( "rows" );
				} );

				it( "paginate respects execute() options override", function() {
					var qbml  = createQBML(); // defaults to array
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "paginate" : { "page" : 1, "maxRows" : 5 } }
					];

					var result = qbml.execute( query, { returnFormat : "tabular" } );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "pagination" );
					expect( result.results ).toHaveKey( "columns" );
				} );

				it( "simplePaginate respects returnFormat", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "simplePaginate" : { "page" : 1, "maxRows" : 5 } }
					];

					var result = qbml.execute( query, { returnFormat : "tabular" } );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "pagination" );
					expect( result.results ).toHaveKey( "columns" );
				} );
			} );

			// ============================================
			// Combined with params
			// ============================================
			describe( "Combined with params", function() {
				it( "returnFormat works alongside params in execute() options", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{
							"when" : { "param" : "statuses", "notEmpty" : true },
							"whereIn" : [ "status", { "$param" : "statuses" } ]
						},
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query, {
						params       : { statuses : [ "active" ] },
						returnFormat : "tabular"
					} );

					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "columns" );
					expect( result ).toHaveKey( "rows" );
				} );
			} );

			// ============================================
			// Query return format
			// ============================================
			describe( "Query return format", function() {
				it( "returns query format when config defaults to query", function() {
					var qbml = createQBML( {
						defaults : { returnFormat : "query" }
					} );
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( isQuery( result ) ).toBeTrue();
				} );

				it( "query definition overrides config default (array -> query)", function() {
					var qbml  = createQBML(); // defaults to array
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : "query" } }
					];

					var result = qbml.execute( query );
					expect( isQuery( result ) ).toBeTrue();
				} );

				it( "query definition overrides config default (query -> array)", function() {
					var qbml = createQBML( {
						defaults : { returnFormat : "query" }
					} );
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : "array" } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeArray();
				} );

				it( "execute() options override to query format", function() {
					var qbml  = createQBML(); // defaults to array
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query, { returnFormat : "query" } );
					expect( isQuery( result ) ).toBeTrue();
				} );

				it( "execute() options override query definition from query to array", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : "query" } }
					];

					var result = qbml.execute( query, { returnFormat : "array" } );
					expect( result ).toBeArray();
				} );

				it( "paginate respects query returnFormat", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "paginate" : { "page" : 1, "maxRows" : 5, "returnFormat" : "query" } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "pagination" );
					expect( result ).toHaveKey( "results" );
					expect( isQuery( result.results ) ).toBeTrue();
				} );

				it( "simplePaginate respects query returnFormat", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "simplePaginate" : { "page" : 1, "maxRows" : 5 } }
					];

					var result = qbml.execute( query, { returnFormat : "query" } );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "pagination" );
					expect( result ).toHaveKey( "results" );
					expect( isQuery( result.results ) ).toBeTrue();
				} );
			} );

			// ============================================
			// Priority chain verification
			// ============================================
			describe( "Priority chain", function() {
				it( "verifies full priority chain: execute > query > config", function() {
					// Config says tabular
					var qbml = createQBML( {
						defaults : { returnFormat : "tabular" }
					} );

					var queryWithArray = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "limit" : 1 },
						{ "get" : { "returnFormat" : "array" } } // query says array
					];

					// 1. Config=tabular, Query=array -> should be array
					var result1 = qbml.execute( queryWithArray );
					expect( result1 ).toBeArray( "Query should override config" );

					// 2. Config=tabular, Query=array, Execute=tabular -> should be tabular
					var result2 = qbml.execute( queryWithArray, { returnFormat : "tabular" } );
					expect( result2 ).toBeStruct( "Execute should override query" );
					expect( result2 ).toHaveKey( "columns" );
				} );

				it( "verifies priority chain with query format: execute > query > config", function() {
					// Config says query
					var qbml = createQBML( {
						defaults : { returnFormat : "query" }
					} );

					var queryWithArray = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "limit" : 1 },
						{ "get" : { "returnFormat" : "array" } } // query says array
					];

					// 1. Config=query, Query=array -> should be array
					var result1 = qbml.execute( queryWithArray );
					expect( result1 ).toBeArray( "Query definition should override config" );

					// 2. Config=query, Query=array, Execute=query -> should be query
					var result2 = qbml.execute( queryWithArray, { returnFormat : "query" } );
					expect( isQuery( result2 ) ).toBeTrue( "Execute should override query definition" );
				} );
			} );

			// ============================================
			// Struct return format
			// ============================================
			describe( "Struct return format", function() {
				it( "returns struct keyed by column when using tuple format", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "email" ] },
						{ "orderBy" : "id" },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : [ "struct", "id" ] } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					expect( structCount( result ) ).toBeGTE( 1 );
					// Each value should be a full row struct
					var firstKey = structKeyArray( result )[ 1 ];
					expect( result[ firstKey ] ).toBeStruct();
					expect( result[ firstKey ] ).toHaveKey( "id" );
					expect( result[ firstKey ] ).toHaveKey( "username" );
					expect( result[ firstKey ] ).toHaveKey( "email" );
				} );

				it( "returns scalar values with single valueKey (translation map)", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "orderBy" : "id" },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : [ "struct", "id", [ "username" ] ] } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					// Each value should be a scalar (the username string)
					var firstKey = structKeyArray( result )[ 1 ];
					expect( isSimpleValue( result[ firstKey ] ) ).toBeTrue( "Single valueKey should produce scalar values" );
				} );

				it( "returns partial row structs with multiple valueKeys", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username", "email", "status" ] },
						{ "orderBy" : "id" },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : [ "struct", "id", [ "username", "email" ] ] } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					var firstKey = structKeyArray( result )[ 1 ];
					expect( result[ firstKey ] ).toBeStruct();
					expect( result[ firstKey ] ).toHaveKey( "username" );
					expect( result[ firstKey ] ).toHaveKey( "email" );
					// Should NOT have id or status (only valueKeys are included)
					expect( structKeyArray( result[ firstKey ] ).len() ).toBe( 2 );
				} );

				it( "duplicate keys use last-row-wins semantics", function() {
					var qbml  = createQBML();
					// Query by status which has duplicates (multiple users per status)
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "status", "username" ] },
						{ "orderBy" : "id" },
						{ "get" : { "returnFormat" : [ "struct", "status" ] } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					// Fewer keys than total rows since duplicates are overwritten
					expect( structCount( result ) ).toBeLTE( 12 );
				} );

				it( "returns empty struct for empty result set", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : [ "id", "=", -999 ] },
						{ "get" : { "returnFormat" : [ "struct", "id" ] } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					expect( structCount( result ) ).toBe( 0 );
				} );

				it( "config default supports struct tuple format", function() {
					var qbml = createQBML( {
						defaults : { returnFormat : [ "struct", "id" ] }
					} );
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					var firstKey = structKeyArray( result )[ 1 ];
					expect( result[ firstKey ] ).toHaveKey( "id" );
				} );

				it( "execute() options override to struct format", function() {
					var qbml  = createQBML(); // defaults to array
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query, { returnFormat : [ "struct", "id" ] } );
					expect( result ).toBeStruct();
					var firstKey = structKeyArray( result )[ 1 ];
					expect( result[ firstKey ] ).toHaveKey( "username" );
				} );

				it( "priority chain works with struct: execute > query > config", function() {
					var qbml = createQBML( {
						defaults : { returnFormat : "array" }
					} );
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : [ "struct", "id" ] } } // query says struct
					];

					// Query says struct, no execute override -> struct
					var result1 = qbml.execute( query );
					expect( result1 ).toBeStruct( "Query def struct should override config array" );

					// Execute says tabular -> tabular wins
					var result2 = qbml.execute( query, { returnFormat : "tabular" } );
					expect( result2 ).toHaveKey( "columns", "Execute tabular should override query struct" );
				} );

				it( "paginate with struct format returns keyed results", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "paginate" : { "page" : 1, "maxRows" : 5, "returnFormat" : [ "struct", "id" ] } }
					];

					var result = qbml.execute( query );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "pagination" );
					expect( result ).toHaveKey( "results" );
					expect( result.results ).toBeStruct();
					expect( structCount( result.results ) ).toBeGTE( 1 );
				} );

				it( "simplePaginate with struct format returns keyed results", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "simplePaginate" : { "page" : 1, "maxRows" : 5 } }
					];

					var result = qbml.execute( query, { returnFormat : [ "struct", "id" ] } );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "pagination" );
					expect( result ).toHaveKey( "results" );
					expect( result.results ).toBeStruct();
					expect( structCount( result.results ) ).toBeGTE( 1 );
				} );

				it( "throws QBML.InvalidColumnKey when columnKey is not in result columns", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : [ "struct", "nonexistent_column" ] } }
					];

					expect( function() {
						qbml.execute( query );
					} ).toThrow( type = "QBML.InvalidColumnKey" );
				} );

				it( "throws QBML.InvalidValueKey when valueKey is not in result columns", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : { "returnFormat" : [ "struct", "id", [ "nonexistent" ] ] } }
					];

					expect( function() {
						qbml.execute( query );
					} ).toThrow( type = "QBML.InvalidValueKey" );
				} );
			} );

			// ============================================
			// Tuple syntax for existing formats
			// ============================================
			describe( "Tuple syntax for existing formats", function() {
				it( "tuple ['array'] is equivalent to string 'array'", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query, { returnFormat : [ "array" ] } );
					expect( result ).toBeArray();
				} );

				it( "tuple ['tabular'] is equivalent to string 'tabular'", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query, { returnFormat : [ "tabular" ] } );
					expect( result ).toBeStruct();
					expect( result ).toHaveKey( "columns" );
					expect( result ).toHaveKey( "rows" );
				} );

				it( "tuple ['query'] is equivalent to string 'query'", function() {
					var qbml  = createQBML();
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "limit" : 5 },
						{ "get" : true }
					];

					var result = qbml.execute( query, { returnFormat : [ "query" ] } );
					expect( isQuery( result ) ).toBeTrue();
				} );
			} );
		} );
	}

}
