component {

	this.name = "qbml-tests-" & hash( getCurrentTemplatePath() );

	// ============================================
	// DATASOURCE CONFIGURATION
	// ============================================
	// Detect CI environment and BoxLang runtime safely
	variables.isBoxLang = structKeyExists( server, "boxlang" );
	variables.isCI      = false;
	if (
		structKeyExists( server, "system" ) &&
		structKeyExists( server.system, "environment" ) &&
		isStruct( server.system.environment )
	) {
		variables.isCI = (
			( structKeyExists( server.system.environment, "CI" ) && len( server.system.environment.CI ) ) ||
			( structKeyExists( server.system.environment, "GITHUB_ACTIONS" ) && len( server.system.environment.GITHUB_ACTIONS ) )
		);
	}

	if ( variables.isCI || variables.isBoxLang ) {
		// CI Environment or BoxLang: Use MySQL database
		// Database is pre-populated via mysql CLI in GitHub Actions workflow
		// Hard-coded values match the CI workflow configuration
		this.datasources[ "qbmlTests" ] = {
			driver   : "mysql",
			host     : "127.0.0.1",
			port     : "3306",
			database : "qbml_test",
			username : "qbml",
			password : "qbml_password"
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
