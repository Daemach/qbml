<cfsetting showDebugOutput="false">
<!--- Executes all tests in the 'specs' folder with simple reporter by default --->
<cfparam name="url.reporter" default="simple">
<cfparam name="url.directory" default="tests.specs">
<cfparam name="url.recurse" default="true" type="boolean">
<cfparam name="url.bundles" default="">
<cfparam name="url.labels" default="">
<cfparam name="url.excludes" default="">

<!--- Instantiate TestBox --->
<cfset testbox = new testbox.system.TestBox()>

<!--- Run the tests --->
<cfoutput>#testbox.run(
	directory = url.directory,
	recurse = url.recurse,
	reporter = url.reporter,
	bundles = url.bundles,
	labels = url.labels,
	excludes = url.excludes
)#</cfoutput>
