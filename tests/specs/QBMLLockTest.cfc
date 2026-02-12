/**
 * QBML Lock Tests
 *
 * Tests QBML lock functionality (lockForUpdate, sharedLock, noLock, etc.).
 * Verifies SQL generation for various lock types.
 */
component extends="testbox.system.BaseSpec" {

	function beforeAll() {
		// Test settings
		var testSettings = {
			tables  : { mode : "allow", list : [ "qbml_*" ] },
			aliases : { "users" : "qbml_users", "orders" : "qbml_orders" },
			defaults : { maxRows : 1000 }
		};

		// Create QB dependencies for standalone testing
		var utils   = new qb.models.Query.QueryUtils();
		var grammar = new qb.models.Grammars.SqlServerGrammar( utils );

		// Create a QB provider that returns new QueryBuilder instances
		var qbProvider = {
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

		// Initialize QBML with test settings
		variables.qbml = new qbml.models.QBML( settings = testSettings );

		// Inject dependencies manually for standalone testing
		variables.qbml.setQb( qbProvider );
		variables.qbml.setSecurity( new qbml.models.QBMLSecurity( settings = testSettings ) );
		variables.qbml.setConditions( new qbml.models.QBMLConditions() );
		variables.qbml.setFormatter( new qbml.models.ReturnFormat() );
	}

	function run() {
		describe( "QBML Lock Tests", function() {
			// ============================================
			// lockForUpdate
			// ============================================
			describe( "lockForUpdate", function() {
				it( "adds FOR UPDATE lock with boolean true", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : [ "id", "=", 1 ] },
						{ "lockForUpdate" : true },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					// SQL Server default lockForUpdate uses READPAST for skip locked behavior
					expect( result ).toInclude( "WITH (ROWLOCK,UPDLOCK,READPAST)" );
				} );

				it( "adds FOR UPDATE with HOLDLOCK when skipLocked is false", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "lockForUpdate" : { "skipLocked" : false } },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					// SQL Server uses HOLDLOCK when skipLocked is false
					expect( result ).toInclude( "HOLDLOCK" );
				} );
			} );

			// ============================================
			// sharedLock
			// ============================================
			describe( "sharedLock", function() {
				it( "adds shared lock with boolean true", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "sharedLock" : true },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					// SQL Server uses WITH (ROWLOCK,HOLDLOCK) for shared lock
					expect( result ).toInclude( "HOLDLOCK" );
				} );
			} );

			// ============================================
			// noLock
			// ============================================
			describe( "noLock", function() {
				it( "adds NOLOCK hint for SQL Server", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "noLock" : true },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					expect( result ).toInclude( "NOLOCK" );
				} );
			} );

			// ============================================
			// lock (custom)
			// ============================================
			describe( "lock (custom)", function() {
				it( "adds custom lock directive", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "lock" : "WITH (TABLOCKX)" },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					expect( result ).toInclude( "TABLOCKX" );
				} );
			} );

			// ============================================
			// clearLock
			// ============================================
			describe( "clearLock", function() {
				it( "clears previously set lock", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{ "lockForUpdate" : true },
						{ "clearLock" : true },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					// After clearLock, there should be no lock hints
					expect( result ).notToInclude( "UPDLOCK" );
					expect( result ).notToInclude( "HOLDLOCK" );
				} );
			} );

			// ============================================
			// Locks with JOINs
			// ============================================
			describe( "Locks with JOINs", function() {
				it( "applies lock to query with joins", function() {
					var query = [
						{ "from" : "qbml_users u" },
						{ "select" : [ "u.id", "u.username" ] },
						{ "join" : [ "qbml_orders o", "u.id", "=", "o.user_id" ] },
						{ "lockForUpdate" : true },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					expect( result ).toInclude( "JOIN" );
					expect( result ).toInclude( "UPDLOCK" );
				} );
			} );

			// ============================================
			// Locks with WHERE conditions
			// ============================================
			describe( "Locks with WHERE conditions", function() {
				it( "applies lock with where conditions", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id", "username" ] },
						{ "where" : [ "status", "=", "active" ] },
						{ "whereIn" : [ "role", [ "admin", "manager" ] ] },
						{ "sharedLock" : true },
						{ "toSQL" : true }
					];

					var result = qbml.execute( query );
					expect( result ).toBeString();
					expect( result ).toInclude( "WHERE" );
					expect( result ).toInclude( "HOLDLOCK" );
				} );
			} );

			// ============================================
			// Locks with conditional (when)
			// ============================================
			describe( "Locks with conditional (when)", function() {
				it( "applies lock conditionally when condition is true", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{
							"when" : { "param" : "useLock", "eq" : true },
							"lockForUpdate" : true
						},
						{ "toSQL" : true }
					];

					var result = qbml.execute( query, { params : { useLock : true } } );
					expect( result ).toBeString();
					expect( result ).toInclude( "UPDLOCK" );
				} );

				it( "does not apply lock when condition is false", function() {
					var query = [
						{ "from" : "qbml_users" },
						{ "select" : [ "id" ] },
						{
							"when" : { "param" : "useLock", "eq" : true },
							"lockForUpdate" : true
						},
						{ "toSQL" : true }
					];

					var result = qbml.execute( query, { params : { useLock : false } } );
					expect( result ).toBeString();
					expect( result ).notToInclude( "UPDLOCK" );
				} );
			} );

			// ============================================
			// Action validation
			// ============================================
			describe( "Action validation", function() {
				it( "recognizes lockForUpdate as valid action", function() {
					expect( qbml.isValidAction( "lockForUpdate" ) ).toBeTrue();
				} );

				it( "recognizes sharedLock as valid action", function() {
					expect( qbml.isValidAction( "sharedLock" ) ).toBeTrue();
				} );

				it( "recognizes noLock as valid action", function() {
					expect( qbml.isValidAction( "noLock" ) ).toBeTrue();
				} );

				it( "recognizes lock as valid action", function() {
					expect( qbml.isValidAction( "lock" ) ).toBeTrue();
				} );

				it( "recognizes clearLock as valid action", function() {
					expect( qbml.isValidAction( "clearLock" ) ).toBeTrue();
				} );
			} );
		} );
	}

}
