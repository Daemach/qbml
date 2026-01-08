component {

	this.name = "qbml-tests-" & hash( getCurrentTemplatePath() );

	// ============================================
	// DATASOURCE CONFIGURATION
	// ============================================
	// Option 1: Use environment variable
	// Option 2: Set default datasource name (must be configured in Lucee/ACF admin)
	// Option 3: Define inline datasource (shown below)

	// Default datasource for tests - configure as needed
	this.defaultDatasource = "qbmlTests";

	// Inline datasource definition (uncomment and configure for your environment)
	/*
	this.datasources[ "qbmlTests" ] = {
		class            : "com.microsoft.sqlserver.jdbc.SQLServerDriver",
		connectionString : "jdbc:sqlserver://localhost:1433;databaseName=qbml_test;trustServerCertificate=true",
		username         : "sa",
		password         : "yourPassword"
	};
	*/

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
		// Clear the application scope for testing
		structClear( application );
	}

}
