component {

	this.name = "qbml-tests-" & hash( getCurrentTemplatePath() );

	// ============================================
	// DATASOURCE CONFIGURATION
	// ============================================
	// Initialize datasources struct
	this.datasources = {};

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
			class            : "com.mysql.cj.jdbc.Driver",
			bundleName       : "com.mysql.cj",
			bundleVersion    : "8.0.33",
			connectionString : "jdbc:mysql://127.0.0.1:3306/qbml_test?useUnicode=true&characterEncoding=UTF-8&useLegacyDatetimeCode=true",
			username         : "qbml",
			password         : "qbml_password"
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
