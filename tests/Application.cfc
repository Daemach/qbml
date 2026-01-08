component {

	this.name = "qbml-tests-" & hash( getCurrentTemplatePath() );

	// ============================================
	// DATASOURCE CONFIGURATION
	// ============================================
	// Detect CI environment and configure H2 in-memory database
	variables.isCI = len( server.system.environment.CI ?: "" ) || len( server.system.environment.GITHUB_ACTIONS ?: "" );

	if ( variables.isCI ) {
		// CI Environment: Use H2 in-memory database
		this.datasources[ "qbmlTests" ] = {
			class            : "org.h2.Driver",
			connectionString : "jdbc:h2:mem:qbmlTests;MODE=MySQL;DATABASE_TO_LOWER=TRUE;IGNORECASE=TRUE",
			username         : "sa",
			password         : ""
		};
	}
	// For local development, configure your datasource in Lucee admin or uncomment below:
	/*
	else {
		this.datasources[ "qbmlTests" ] = {
			class            : "com.microsoft.sqlserver.jdbc.SQLServerDriver",
			connectionString : "jdbc:sqlserver://localhost:1433;databaseName=qbml_test;trustServerCertificate=true",
			username         : "sa",
			password         : "yourPassword"
		};
	}
	*/

	this.defaultDatasource = "qbmlTests";

	// ============================================
	// MAPPINGS
	// ============================================
	this.mappings[ "/qbml" ]    = expandPath( "../" );
	this.mappings[ "/tests" ]   = expandPath( "./" );
	this.mappings[ "/testbox" ] = expandPath( "../testbox" );

	// Map qb module for standalone testing (qb components use "qb." prefix internally)
	this.mappings[ "/qb" ]          = expandPath( "../modules/qb" );
	this.mappings[ "/cbpaginator" ] = expandPath( "../modules/qb/modules/cbpaginator" );

	function onApplicationStart() {
		// Initialize database tables for CI
		if ( variables.isCI ) {
			setupTestDatabase();
		}
		return true;
	}

	function onRequestStart() {
		// Re-initialize database on each request if needed (for test isolation)
		if ( url.reinitDb ?: false ) {
			setupTestDatabase();
		}
	}

	private function setupTestDatabase() {
		var sqlFile = expandPath( "./sql/setup-h2.sql" );
		if ( fileExists( sqlFile ) ) {
			var sql = fileRead( sqlFile );
			// Split by semicolons and execute each statement
			var statements = sql.listToArray( ";" );
			for ( var stmt in statements ) {
				stmt = stmt.trim();
				// Skip empty statements and comments
				if ( len( stmt ) && !stmt.startsWith( "--" ) ) {
					try {
						queryExecute( stmt, {}, { datasource : "qbmlTests" } );
					} catch ( any e ) {
						// Log but continue - some statements may fail on re-run
						if ( !e.message contains "already exists" && !e.message contains "Duplicate" ) {
							writeLog( text = "SQL Setup Error: #e.message# - Statement: #left( stmt, 100 )#", type = "warning" );
						}
					}
				}
			}
		}
	}

}
