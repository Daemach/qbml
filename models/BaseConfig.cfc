/**
 * QBML Base Configuration
 * Returns default settings struct. User configs extend and override.
 */
component singleton {

	function configure() {
		return {
			// Access control: mode + list. Wildcards supported.
			// mode: "none" (all allowed), "allow" (only list), "block" (all except list)
			tables    : { mode : "none", list : [] },
			actions   : { mode : "none", list : [] },
			executors : { mode : "none", list : [] },

			// Table aliases: friendly name -> actual path
			aliases : {},

			// Query defaults
			defaults : {
				timeout      : 30,
				maxRows      : 10000,
				datasource   : "",
				returnFormat : "array"  // "array" or "tabular"
			},

			// Read-only credentials
			credentials : {
				username : "",
				password : ""
			},

			debug : false
		};
	}

	function development() {
		return {};
	}

	function staging() {
		return {};
	}

	function production() {
		return {};
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
