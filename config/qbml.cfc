/**
 * QBML Configuration
 * Copy to your app's config folder. Uncomment/modify as needed.
 * mode: "none" (all), "allow" (only list), "block" (all except list)
 * Wildcards: "reporting.*", "*.audit_log"
 */
component {

	function configure() {
		return {
			tables : { mode : "none", list : [] },
			// tables : { mode : "allow", list : [ "users", "orders", "reporting.*" ] },
			// tables : { mode : "block", list : [ "sys.*", "*.passwords" ] },

			actions : { mode : "none", list : [] },
			// actions : { mode : "block", list : [ "*Raw" ] },

			executors : { mode : "none", list : [] },
			// executors : { mode : "allow", list : [ "get", "first", "count", "exists", "paginate" ] },

			aliases : {
				// accounts : "dbo.tbl_accounts",
				// users    : "auth.users"
			},

			defaults : {
				timeout      : 30,
				maxRows      : 10000,
				datasource   : "",
				returnFormat : "array"  // "array", "tabular", "query", or ["struct", "columnKey", ["valueKeys"]]
			},

			credentials : {
				username : "",
				password : ""
			},

			debug : false
		};
	}

	function development() {
		return {
			// debug : true,
			// defaults : { timeout : 120 }
		};
	}

	function staging() {
		return {};
	}

	function production() {
		return {
			// tables : { mode : "allow", list : [ "users", "orders", "products" ] },
			// credentials : {
			//     username : getSystemSetting( "QBML_DB_USER", "" ),
			//     password : getSystemSetting( "QBML_DB_PASS", "" )
			// },
			// defaults : { maxRows : 5000 }
		};
	}

	function testing() {
		return {
			tables    : { mode : "none", list : [] },
			actions   : { mode : "none", list : [] },
			executors : { mode : "none", list : [] },
			debug     : false
		};
	}

}
