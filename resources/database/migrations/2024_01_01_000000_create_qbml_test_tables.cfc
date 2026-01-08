/**
 * Migration: Create QBML Test Tables
 *
 * Creates test tables for QBML integration testing:
 *   - qbml_departments (hierarchical)
 *   - qbml_users
 *   - qbml_user_profiles
 *   - qbml_categories (hierarchical)
 *   - qbml_products
 *   - qbml_orders
 *   - qbml_order_items
 */
component {

	function up( schema, qb ) {
		// ============================================
		// DEPARTMENTS (hierarchical, self-referencing)
		// ============================================
		schema.create( "qbml_departments", function( table ) {
			table.increments( "id" );
			table.string( "name", 100 );
			table.unsignedInteger( "parent_id" ).nullable();
			table.decimal( "budget", 12, 2 ).default( 0 );
			table.datetime( "created_at" ).withCurrent();

			table.foreign( "parent_id" ).references( "id" ).onTable( "qbml_departments" );
		} );

		// ============================================
		// USERS
		// ============================================
		schema.create( "qbml_users", function( table ) {
			table.increments( "id" );
			table.string( "username", 50 ).unique();
			table.string( "email", 100 );
			table.string( "status", 20 ).default( "active" );
			table.string( "role", 20 ).default( "user" );
			table.unsignedInteger( "department_id" ).nullable();
			table.decimal( "salary", 10, 2 ).nullable();
			table.date( "hire_date" ).nullable();
			table.datetime( "last_login" ).nullable();
			table.datetime( "created_at" ).withCurrent();
			table.datetime( "updated_at" ).withCurrent();
			table.datetime( "deleted_at" ).nullable();

			table.foreign( "department_id" ).references( "id" ).onTable( "qbml_departments" );
			table.index( "status", "idx_users_status" );
			table.index( "role", "idx_users_role" );
			table.index( "department_id", "idx_users_department" );
		} );

		// ============================================
		// USER PROFILES (1:1 with users)
		// ============================================
		schema.create( "qbml_user_profiles", function( table ) {
			table.increments( "id" );
			table.unsignedInteger( "user_id" ).unique();
			table.string( "first_name", 50 ).nullable();
			table.string( "last_name", 50 ).nullable();
			table.text( "bio" ).nullable();
			table.string( "avatar_url", 255 ).nullable();
			table.string( "phone", 20 ).nullable();
			table.date( "birth_date" ).nullable();

			table.foreign( "user_id" ).references( "id" ).onTable( "qbml_users" );
		} );

		// ============================================
		// CATEGORIES (hierarchical)
		// ============================================
		schema.create( "qbml_categories", function( table ) {
			table.increments( "id" );
			table.string( "name", 100 );
			table.string( "slug", 100 ).unique();
			table.unsignedInteger( "parent_id" ).nullable();
			table.integer( "sort_order" ).default( 0 );
			table.boolean( "is_active" ).default( true );

			table.foreign( "parent_id" ).references( "id" ).onTable( "qbml_categories" );
		} );

		// ============================================
		// PRODUCTS
		// ============================================
		schema.create( "qbml_products", function( table ) {
			table.increments( "id" );
			table.string( "sku", 50 ).unique();
			table.string( "name", 200 );
			table.text( "description" ).nullable();
			table.unsignedInteger( "category_id" ).nullable();
			table.decimal( "price", 10, 2 );
			table.decimal( "cost", 10, 2 ).nullable();
			table.integer( "stock_qty" ).default( 0 );
			table.boolean( "is_active" ).default( true );
			table.datetime( "created_at" ).withCurrent();

			table.foreign( "category_id" ).references( "id" ).onTable( "qbml_categories" );
			table.index( "category_id", "idx_products_category" );
		} );

		// ============================================
		// ORDERS
		// ============================================
		schema.create( "qbml_orders", function( table ) {
			table.increments( "id" );
			table.string( "order_number", 20 ).unique();
			table.unsignedInteger( "user_id" );
			table.string( "status", 20 ).default( "pending" );
			table.decimal( "subtotal", 12, 2 ).default( 0 );
			table.decimal( "tax", 12, 2 ).default( 0 );
			table.decimal( "total", 12, 2 ).default( 0 );
			table.text( "notes" ).nullable();
			table.datetime( "order_date" ).withCurrent();
			table.datetime( "shipped_date" ).nullable();
			table.datetime( "delivered_date" ).nullable();

			table.foreign( "user_id" ).references( "id" ).onTable( "qbml_users" );
			table.index( "user_id", "idx_orders_user" );
			table.index( "status", "idx_orders_status" );
			table.index( "order_date", "idx_orders_date" );
		} );

		// ============================================
		// ORDER ITEMS (many-to-many: orders <-> products)
		// ============================================
		schema.create( "qbml_order_items", function( table ) {
			table.increments( "id" );
			table.unsignedInteger( "order_id" );
			table.unsignedInteger( "product_id" );
			table.integer( "quantity" ).default( 1 );
			table.decimal( "unit_price", 10, 2 );
			table.decimal( "discount", 10, 2 ).default( 0 );
			table.decimal( "line_total", 12, 2 );

			table.foreign( "order_id" ).references( "id" ).onTable( "qbml_orders" );
			table.foreign( "product_id" ).references( "id" ).onTable( "qbml_products" );
			table.index( "order_id", "idx_order_items_order" );
			table.index( "product_id", "idx_order_items_product" );
		} );
	}

	function down( schema, qb ) {
		schema.dropIfExists( "qbml_order_items" );
		schema.dropIfExists( "qbml_orders" );
		schema.dropIfExists( "qbml_products" );
		schema.dropIfExists( "qbml_categories" );
		schema.dropIfExists( "qbml_user_profiles" );
		schema.dropIfExists( "qbml_users" );
		schema.dropIfExists( "qbml_departments" );
	}

}
