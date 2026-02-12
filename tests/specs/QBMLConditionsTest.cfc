component extends="testbox.system.BaseSpec" {

	function beforeAll() {
		variables.conditions = new qbml.models.QBMLConditions();
	}

	function run() {
		describe( "QBMLConditions", function() {
			describe( "Simple conditions", function() {
				it( "returns true for 'hasValues' when array has elements", function() {
					var result = conditions.evaluate( "hasValues", [ "col", [ 1, 2, 3 ] ] );
					expect( result ).toBeTrue();
				} );

				it( "returns false for 'hasValues' when array is empty", function() {
					var result = conditions.evaluate( "hasValues", [ "col", [] ] );
					expect( result ).toBeFalse();
				} );

				it( "returns true for 'notEmpty' when array has elements", function() {
					var result = conditions.evaluate( "notEmpty", [ "col", [ 1, 2 ] ] );
					expect( result ).toBeTrue();
				} );

				it( "returns true for 'isEmpty' when array is empty", function() {
					var result = conditions.evaluate( "isEmpty", [ "col", [] ] );
					expect( result ).toBeTrue();
				} );

				it( "returns false for 'isEmpty' when array has elements", function() {
					var result = conditions.evaluate( "isEmpty", [ "col", [ 1 ] ] );
					expect( result ).toBeFalse();
				} );

				it( "handles boolean true", function() {
					expect( conditions.evaluate( true, [] ) ).toBeTrue();
					expect( conditions.evaluate( "true", [] ) ).toBeTrue();
				} );

				it( "handles boolean false", function() {
					expect( conditions.evaluate( false, [] ) ).toBeFalse();
					expect( conditions.evaluate( "false", [] ) ).toBeFalse();
				} );
			} );

			describe( "Struct-based notEmpty conditions", function() {
				it( "checks specific index with numeric value", function() {
					var result = conditions.evaluate( { notEmpty : 2 }, [ "col", [ 1, 2, 3 ] ] );
					expect( result ).toBeTrue();

					result = conditions.evaluate( { notEmpty : 2 }, [ "col", [] ] );
					expect( result ).toBeFalse();
				} );

				it( "checks any array with boolean true", function() {
					var result = conditions.evaluate( { notEmpty : true }, [ "x", [ 1 ] ] );
					expect( result ).toBeTrue();
				} );
			} );

			describe( "Comparison conditions", function() {
				it( "evaluates gt (greater than)", function() {
					expect( conditions.evaluate( { gt : [ 1, 5 ] }, [ 10 ] ) ).toBeTrue();
					expect( conditions.evaluate( { gt : [ 1, 5 ] }, [ 3 ] ) ).toBeFalse();
				} );

				it( "evaluates gte (greater than or equal)", function() {
					expect( conditions.evaluate( { gte : [ 1, 5 ] }, [ 5 ] ) ).toBeTrue();
					expect( conditions.evaluate( { gte : [ 1, 5 ] }, [ 4 ] ) ).toBeFalse();
				} );

				it( "evaluates lt (less than)", function() {
					expect( conditions.evaluate( { lt : [ 1, 5 ] }, [ 3 ] ) ).toBeTrue();
					expect( conditions.evaluate( { lt : [ 1, 5 ] }, [ 7 ] ) ).toBeFalse();
				} );

				it( "evaluates lte (less than or equal)", function() {
					expect( conditions.evaluate( { lte : [ 1, 5 ] }, [ 5 ] ) ).toBeTrue();
					expect( conditions.evaluate( { lte : [ 1, 5 ] }, [ 6 ] ) ).toBeFalse();
				} );

				it( "evaluates eq (equal)", function() {
					expect( conditions.evaluate( { eq : [ 1, "active" ] }, [ "active" ] ) ).toBeTrue();
					expect( conditions.evaluate( { eq : [ 1, "active" ] }, [ "inactive" ] ) ).toBeFalse();
				} );

				it( "evaluates neq (not equal)", function() {
					expect( conditions.evaluate( { neq : [ 1, "deleted" ] }, [ "active" ] ) ).toBeTrue();
					expect( conditions.evaluate( { neq : [ 1, "deleted" ] }, [ "deleted" ] ) ).toBeFalse();
				} );
			} );

			describe( "Logical operators", function() {
				it( "evaluates 'and' - all must be true", function() {
					var cond = {
						"and" : [ { gt : [ 1, 5 ] }, { lt : [ 1, 20 ] } ]
					};
					expect( conditions.evaluate( cond, [ 10 ] ) ).toBeTrue();
					expect( conditions.evaluate( cond, [ 25 ] ) ).toBeFalse();
				} );

				it( "evaluates 'or' - any must be true", function() {
					var cond = {
						"or" : [ { eq : [ 1, "admin" ] }, { eq : [ 1, "superuser" ] } ]
					};
					expect( conditions.evaluate( cond, [ "admin" ] ) ).toBeTrue();
					expect( conditions.evaluate( cond, [ "superuser" ] ) ).toBeTrue();
					expect( conditions.evaluate( cond, [ "guest" ] ) ).toBeFalse();
				} );

				it( "evaluates 'not' - negation", function() {
					var cond = { "not" : { eq : [ 1, "deleted" ] } };
					expect( conditions.evaluate( cond, [ "active" ] ) ).toBeTrue();
					expect( conditions.evaluate( cond, [ "deleted" ] ) ).toBeFalse();
				} );

				it( "handles nested logical operators", function() {
					var cond = {
						"and" : [
							{ gt : [ 1, 0 ] },
							{
								"or" : [ { eq : [ 2, "active" ] }, { eq : [ 2, "pending" ] } ]
							}
						]
					};
					expect( conditions.evaluate( cond, [ 5, "active" ] ) ).toBeTrue();
					expect( conditions.evaluate( cond, [ 5, "pending" ] ) ).toBeTrue();
					expect( conditions.evaluate( cond, [ 5, "deleted" ] ) ).toBeFalse();
					expect( conditions.evaluate( cond, [ 0, "active" ] ) ).toBeFalse();
				} );

				it( "handles deeply nested not with and/or", function() {
					// NOT (eq[1,"admin"] OR eq[1,"superuser"])
					var cond = {
						"not" : {
							"or" : [ { eq : [ 1, "admin" ] }, { eq : [ 1, "superuser" ] } ]
						}
					};
					expect( conditions.evaluate( cond, [ "user" ] ) ).toBeTrue();
					expect( conditions.evaluate( cond, [ "admin" ] ) ).toBeFalse();
					expect( conditions.evaluate( cond, [ "superuser" ] ) ).toBeFalse();
				} );
			} );

			describe( "Edge cases", function() {
				it( "returns true for empty struct condition", function() {
					expect( conditions.evaluate( {}, [] ) ).toBeTrue();
				} );

				it( "returns true for unknown simple condition", function() {
					expect( conditions.evaluate( "unknownCondition", [] ) ).toBeTrue();
				} );

				it( "handles hasValues with no array in args", function() {
					// When no array found, defaults to true
					expect( conditions.evaluate( "hasValues", [ "string", 123 ] ) ).toBeTrue();
				} );

				it( "handles isEmpty with no array in args", function() {
					// When no array found, returns false
					expect( conditions.evaluate( "isEmpty", [ "string", 123 ] ) ).toBeFalse();
				} );

				it( "returns false when comparison index exceeds args length", function() {
					expect( conditions.evaluate( { gt : [ 5, 50 ] }, [ 100 ] ) ).toBeFalse();
				} );

				it( "returns false when comparison spec has fewer than 2 elements", function() {
					expect( conditions.evaluate( { gt : [ 1 ] }, [ 100 ] ) ).toBeFalse();
				} );

				it( "handles isEmpty with specific index", function() {
					expect( conditions.evaluate( { isEmpty : 2 }, [ "first", [] ] ) ).toBeTrue();
					expect( conditions.evaluate( { isEmpty : 2 }, [ "first", [ "a" ] ] ) ).toBeFalse();
				} );

				it( "handles comparison with string values", function() {
					expect( conditions.evaluate( { eq : [ 1, "test" ] }, [ "test" ] ) ).toBeTrue();
					expect( conditions.evaluate( { neq : [ 1, "test" ] }, [ "other" ] ) ).toBeTrue();
				} );
			} );

			describe( "Param-based conditions", function() {
				it( "evaluates notEmpty for array params", function() {
					var cond   = { param : "accountIDs", notEmpty : true };
					var params = { accountIDs : [ 1, 2, 3 ] };
					expect( conditions.evaluate( cond, [], params ) ).toBeTrue();

					params = { accountIDs : [] };
					expect( conditions.evaluate( cond, [], params ) ).toBeFalse();
				} );

				it( "evaluates notEmpty for string params", function() {
					var cond = { param : "filter", notEmpty : true };
					expect( conditions.evaluate( cond, [], { filter : "active" } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { filter : "" } ) ).toBeFalse();
					expect( conditions.evaluate( cond, [], { filter : "   " } ) ).toBeFalse();
				} );

				it( "evaluates isEmpty for array params", function() {
					var cond = { param : "accountIDs", isEmpty : true };
					expect( conditions.evaluate( cond, [], { accountIDs : [] } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { accountIDs : [ 1 ] } ) ).toBeFalse();
				} );

				it( "evaluates isEmpty for missing params", function() {
					var cond = { param : "missingParam", isEmpty : true };
					expect( conditions.evaluate( cond, [], {} ) ).toBeTrue();
				} );

				it( "returns false for notEmpty with missing param", function() {
					var cond = { param : "missingParam", notEmpty : true };
					expect( conditions.evaluate( cond, [], {} ) ).toBeFalse();
				} );

				it( "evaluates hasValue condition", function() {
					var cond = { param : "status", hasValue : true };
					expect( conditions.evaluate( cond, [], { status : "active" } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { status : 0 } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], {} ) ).toBeFalse();
				} );

				it( "evaluates gt comparison", function() {
					var cond = { param : "limit", gt : 100 };
					expect( conditions.evaluate( cond, [], { limit : 200 } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { limit : 50 } ) ).toBeFalse();
				} );

				it( "evaluates gte comparison", function() {
					var cond = { param : "limit", gte : 100 };
					expect( conditions.evaluate( cond, [], { limit : 100 } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { limit : 99 } ) ).toBeFalse();
				} );

				it( "evaluates lt comparison", function() {
					var cond = { param : "page", lt : 10 };
					expect( conditions.evaluate( cond, [], { page : 5 } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { page : 15 } ) ).toBeFalse();
				} );

				it( "evaluates lte comparison", function() {
					var cond = { param : "page", lte : 10 };
					expect( conditions.evaluate( cond, [], { page : 10 } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { page : 11 } ) ).toBeFalse();
				} );

				it( "evaluates eq comparison", function() {
					var cond = { param : "status", eq : "active" };
					expect( conditions.evaluate( cond, [], { status : "active" } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { status : "inactive" } ) ).toBeFalse();
				} );

				it( "evaluates neq comparison", function() {
					var cond = { param : "status", neq : "deleted" };
					expect( conditions.evaluate( cond, [], { status : "active" } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { status : "deleted" } ) ).toBeFalse();
				} );

				it( "works with logical operators and params", function() {
					var cond = {
						"and" : [
							{ param : "accountIDs", notEmpty : true },
							{ param : "status", eq : "active" }
						]
					};
					var params = { accountIDs : [ 1, 2 ], status : "active" };
					expect( conditions.evaluate( cond, [], params ) ).toBeTrue();

					params = { accountIDs : [ 1, 2 ], status : "inactive" };
					expect( conditions.evaluate( cond, [], params ) ).toBeFalse();

					params = { accountIDs : [], status : "active" };
					expect( conditions.evaluate( cond, [], params ) ).toBeFalse();
				} );

				it( "works with or operator and params", function() {
					var cond = {
						"or" : [
							{ param : "isAdmin", eq : true },
							{ param : "accountIDs", notEmpty : true }
						]
					};
					expect( conditions.evaluate( cond, [], { isAdmin : true } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { accountIDs : [ 1 ] } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { isAdmin : false, accountIDs : [] } ) ).toBeFalse();
				} );

				it( "works with not operator and params", function() {
					var cond = {
						"not" : { param : "status", eq : "deleted" }
					};
					expect( conditions.evaluate( cond, [], { status : "active" } ) ).toBeTrue();
					expect( conditions.evaluate( cond, [], { status : "deleted" } ) ).toBeFalse();
				} );
			} );
		} );
	}

}
