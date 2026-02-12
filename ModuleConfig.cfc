component {

	this.name         = "qbml";
	this.author       = "John Wilson";
	this.webUrl       = "https://github.com/user/qbml";
	this.version      = "1.0.0";
	this.cfmapping    = "qbml";
	this.dependencies = [ "qb" ];

	function configure() {
		settings = {
			// Path to config file (set empty to disable)
			// e.g., "config.qbml" resolves to config/qbml.cfc
			configPath : "config.qbml"
		};

		interceptors = [];
	}

	function onLoad() {
		// Load config and merge with moduleSettings
		var finalSettings = loadConfig();

		// Register services
		binder
			.map( "QBML@qbml" )
			.to( "#moduleMapping#.models.QBML" )
			.asSingleton()
			.initWith( settings = finalSettings );

		binder
			.map( "QBMLSecurity@qbml" )
			.to( "#moduleMapping#.models.QBMLSecurity" )
			.asSingleton()
			.initWith( settings = finalSettings );

		binder
			.map( "QBMLConditions@qbml" )
			.to( "#moduleMapping#.models.QBMLConditions" )
			.asSingleton();

		binder
			.map( "ReturnFormat@qbml" )
			.to( "#moduleMapping#.models.ReturnFormat" )
			.asSingleton();
	}

	/**
	 * Load and merge configuration
	 */
	private struct function loadConfig() {
		// Start with base defaults
		var base = new "#moduleMapping#.models.BaseConfig"();
		var config = base.configure();

		// Try to load external config file
		var configPath = settings.configPath ?: "config.qbml";
		if ( len( trim( configPath ) ) ) {
			try {
				var userConfig = variables.wirebox.getInstance( configPath );

				// Merge user's configure()
				if ( structKeyExists( userConfig, "configure" ) ) {
					var userSettings = userConfig.configure();
					config = deepMerge( config, userSettings );
				}

				// Merge environment-specific settings
				var environment = variables.controller.getSetting( "ENVIRONMENT" );
				if ( structKeyExists( userConfig, environment ) ) {
					var envSettings = invoke( userConfig, environment );
					config = deepMerge( config, envSettings );
				}
			} catch ( any e ) {
				// Config file not found - use defaults
			}
		}

		// Merge any moduleSettings overrides (highest priority)
		config = deepMerge( config, settings );

		return config;
	}

	/**
	 * Deep merge two structs (source into target)
	 */
	private struct function deepMerge( required struct target, required struct source ) {
		for ( var key in arguments.source ) {
			if ( isStruct( arguments.source[ key ] ) && arguments.target.keyExists( key ) && isStruct( arguments.target[ key ] ) ) {
				arguments.target[ key ] = deepMerge( arguments.target[ key ], arguments.source[ key ] );
			} else {
				arguments.target[ key ] = arguments.source[ key ];
			}
		}
		return arguments.target;
	}

	function onUnload() {
	}

}
