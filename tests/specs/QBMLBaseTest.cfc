/**
 * Base test class for QBML tests
 * Provides shared setup and QBML instance
 */
component extends="testbox.system.BaseSpec" {

	function getQBML() {
		// Test settings with all qbml_* tables allowed
		var testSettings = {
			tables  : { mode : "allow", list : [ "qbml_*" ] },
			aliases : {
				"users"       : "qbml_users",
				"profiles"    : "qbml_user_profiles",
				"departments" : "qbml_departments",
				"categories"  : "qbml_categories",
				"products"    : "qbml_products",
				"orders"      : "qbml_orders",
				"order_items" : "qbml_order_items"
			},
			defaults : { maxRows : 1000 }
		};

		// Create QB dependencies for standalone testing
		var utils   = new qb.models.Query.QueryUtils();
		var grammar = new qb.models.Grammars.SqlServerGrammar( utils );

		// Create a QB provider that returns new QueryBuilder instances
		var qbProvider = {
			grammar : grammar,
			utils   : utils,
			newQuery : function() {
				var builder = new qb.models.Query.QueryBuilder();
				builder.setGrammar( grammar );
				builder.setUtils( utils );
				builder.setReturnFormat( "array" );
				return builder;
			}
		};

		// Initialize QBML with test settings
		var qbml = new qbml.models.QBML( settings = testSettings );

		// Inject dependencies manually for standalone testing
		qbml.setQb( qbProvider );
		qbml.setSecurity( new qbml.models.QBMLSecurity( settings = testSettings ) );
		qbml.setConditions( new qbml.models.QBMLConditions() );
		qbml.setTabular( new qbml.models.Tabular() );

		return qbml;
	}

}
