component {

	this.name = "qbml-tests-" & hash( getCurrentTemplatePath() );

	// ============================================
	// DATASOURCE CONFIGURATION
	// ============================================
	// Detect CI environment and configure MySQL database (service container)
	variables.isCI = len( server.system.environment.CI ?: "" ) || len( server.system.environment.GITHUB_ACTIONS ?: "" );

	if ( variables.isCI ) {
		// CI Environment: Use MySQL service container
		// Database is pre-populated via mysql CLI in GitHub Actions workflow
		// Use driver-based config for BoxLang compatibility, with class fallback for Lucee
		this.datasources[ "qbmlTests" ] = {
			driver   : "mysql",
			class    : "com.mysql.cj.jdbc.Driver",
			host     : server.system.environment.DB_HOST ?: "127.0.0.1",
			port     : server.system.environment.DB_PORT ?: "3306",
			database : server.system.environment.DB_DATABASE ?: "qbml_test",
			username : server.system.environment.DB_USER ?: "qbml",
			password : server.system.environment.DB_PASSWORD ?: "qbml_password",
			custom   : { useSSL : false, allowPublicKeyRetrieval : true, serverTimezone : "UTC" }
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

	function onRequestStart() {
		// Clear application scope on reinit request
		if ( url.reinit ?: false ) {
			structClear( application );
		}
	}

}
