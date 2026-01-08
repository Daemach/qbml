/**
 * QBML Return Format Tests
 *
 * Tests for the returnFormat configuration and override behavior.
 * Priority: execute() options > query definition > config defaults
 */
component extends="testbox.system.BaseSpec" {

	function isCI() {
		return len( server.system.environment.CI ?: "" ) || len( server.system.environment.GITHUB_ACTIONS ?: "" );
	}

	function isBoxLang() {
		return structKeyExists( server, "boxlang" );
	}

	function usesMySQLGrammar() {
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
		qbml.setTabular( new qbml.models.Tabular() );

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
			} );
		} );
	}

}
