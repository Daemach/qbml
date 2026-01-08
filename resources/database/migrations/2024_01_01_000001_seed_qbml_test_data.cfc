/**
 * Migration: Seed QBML Test Data
 *
 * Populates test tables with sample data for integration testing.
 */
component {

	function up( schema, qb ) {
		// ============================================
		// DEPARTMENTS (9 rows)
		// ============================================
		qb.table( "qbml_departments" ).insert( [
			{ id : 1, name : "Company", parent_id : javacast( "null", "" ), budget : 1000000.00 },
			{ id : 2, name : "Engineering", parent_id : 1, budget : 500000.00 },
			{ id : 3, name : "Sales", parent_id : 1, budget : 300000.00 },
			{ id : 4, name : "Marketing", parent_id : 1, budget : 200000.00 },
			{ id : 5, name : "Frontend", parent_id : 2, budget : 150000.00 },
			{ id : 6, name : "Backend", parent_id : 2, budget : 200000.00 },
			{ id : 7, name : "DevOps", parent_id : 2, budget : 150000.00 },
			{ id : 8, name : "Enterprise Sales", parent_id : 3, budget : 200000.00 },
			{ id : 9, name : "SMB Sales", parent_id : 3, budget : 100000.00 }
		] );

		// ============================================
		// USERS (12 rows)
		// ============================================
		qb.table( "qbml_users" ).insert( [
			{ id : 1, username : "admin", email : "admin@example.com", status : "active", role : "admin", department_id : 1, salary : 150000.00, hire_date : "2020-01-15", last_login : "2024-12-01 09:00:00", deleted_at : javacast( "null", "" ) },
			{ id : 2, username : "jsmith", email : "john.smith@example.com", status : "active", role : "manager", department_id : 2, salary : 120000.00, hire_date : "2020-03-01", last_login : "2024-12-01 08:30:00", deleted_at : javacast( "null", "" ) },
			{ id : 3, username : "mjones", email : "mary.jones@example.com", status : "active", role : "user", department_id : 5, salary : 95000.00, hire_date : "2021-06-15", last_login : "2024-11-30 17:00:00", deleted_at : javacast( "null", "" ) },
			{ id : 4, username : "bwilson", email : "bob.wilson@example.com", status : "active", role : "user", department_id : 6, salary : 105000.00, hire_date : "2021-08-01", last_login : "2024-12-01 10:15:00", deleted_at : javacast( "null", "" ) },
			{ id : 5, username : "agarcia", email : "ana.garcia@example.com", status : "inactive", role : "user", department_id : 5, salary : 90000.00, hire_date : "2022-01-10", last_login : "2024-06-15 14:00:00", deleted_at : javacast( "null", "" ) },
			{ id : 6, username : "clee", email : "chris.lee@example.com", status : "active", role : "manager", department_id : 3, salary : 110000.00, hire_date : "2020-05-20", last_login : "2024-12-01 07:45:00", deleted_at : javacast( "null", "" ) },
			{ id : 7, username : "dkim", email : "david.kim@example.com", status : "pending", role : "user", department_id : 8, salary : 85000.00, hire_date : "2024-11-01", last_login : javacast( "null", "" ), deleted_at : javacast( "null", "" ) },
			{ id : 8, username : "ewang", email : "emma.wang@example.com", status : "active", role : "user", department_id : 7, salary : 100000.00, hire_date : "2022-03-15", last_login : "2024-11-29 16:30:00", deleted_at : javacast( "null", "" ) },
			{ id : 9, username : "fmiller", email : "frank.miller@example.com", status : "deleted", role : "user", department_id : 4, salary : 80000.00, hire_date : "2021-09-01", last_login : "2024-01-15 11:00:00", deleted_at : "2024-02-01" },
			{ id : 10, username : "gwhite", email : "grace.white@example.com", status : "active", role : "user", department_id : 9, salary : 75000.00, hire_date : "2023-02-01", last_login : "2024-11-28 09:00:00", deleted_at : javacast( "null", "" ) },
			{ id : 11, username : "hbrown", email : "henry.brown@example.com", status : "active", role : "guest", department_id : javacast( "null", "" ), salary : javacast( "null", "" ), hire_date : javacast( "null", "" ), last_login : "2024-11-20 12:00:00", deleted_at : javacast( "null", "" ) },
			{ id : 12, username : "idavis", email : "ivy.davis@example.com", status : "inactive", role : "user", department_id : 6, salary : 98000.00, hire_date : "2022-07-01", last_login : "2024-09-01 10:00:00", deleted_at : javacast( "null", "" ) }
		] );

		// ============================================
		// USER PROFILES (9 rows)
		// ============================================
		qb.table( "qbml_user_profiles" ).insert( [
			{ id : 1, user_id : 1, first_name : "System", last_name : "Admin", bio : "System administrator", phone : "555-0001", birth_date : "1985-03-15" },
			{ id : 2, user_id : 2, first_name : "John", last_name : "Smith", bio : "Engineering manager with 10+ years experience", phone : "555-0002", birth_date : "1982-07-22" },
			{ id : 3, user_id : 3, first_name : "Mary", last_name : "Jones", bio : "Frontend developer specializing in React", phone : "555-0003", birth_date : "1990-11-08" },
			{ id : 4, user_id : 4, first_name : "Bob", last_name : "Wilson", bio : "Backend developer, database expert", phone : "555-0004", birth_date : "1988-04-30" },
			{ id : 5, user_id : 5, first_name : "Ana", last_name : "Garcia", bio : "UI/UX enthusiast", phone : "555-0005", birth_date : "1992-09-12" },
			{ id : 6, user_id : 6, first_name : "Chris", last_name : "Lee", bio : "Sales director", phone : "555-0006", birth_date : "1980-01-25" },
			{ id : 7, user_id : 7, first_name : "David", last_name : "Kim", bio : "New hire - enterprise sales", phone : "555-0007", birth_date : "1995-06-18" },
			{ id : 8, user_id : 8, first_name : "Emma", last_name : "Wang", bio : "DevOps engineer, cloud specialist", phone : "555-0008", birth_date : "1991-12-03" },
			{ id : 9, user_id : 10, first_name : "Grace", last_name : "White", bio : "SMB account manager", phone : "555-0010", birth_date : "1993-08-07" }
		] );

		// ============================================
		// CATEGORIES (11 rows)
		// ============================================
		qb.table( "qbml_categories" ).insert( [
			{ id : 1, name : "Electronics", slug : "electronics", parent_id : javacast( "null", "" ), sort_order : 1, is_active : true },
			{ id : 2, name : "Clothing", slug : "clothing", parent_id : javacast( "null", "" ), sort_order : 2, is_active : true },
			{ id : 3, name : "Books", slug : "books", parent_id : javacast( "null", "" ), sort_order : 3, is_active : true },
			{ id : 4, name : "Computers", slug : "computers", parent_id : 1, sort_order : 1, is_active : true },
			{ id : 5, name : "Phones", slug : "phones", parent_id : 1, sort_order : 2, is_active : true },
			{ id : 6, name : "Audio", slug : "audio", parent_id : 1, sort_order : 3, is_active : true },
			{ id : 7, name : "Men", slug : "men", parent_id : 2, sort_order : 1, is_active : true },
			{ id : 8, name : "Women", slug : "women", parent_id : 2, sort_order : 2, is_active : true },
			{ id : 9, name : "Fiction", slug : "fiction", parent_id : 3, sort_order : 1, is_active : true },
			{ id : 10, name : "Non-Fiction", slug : "non-fiction", parent_id : 3, sort_order : 2, is_active : true },
			{ id : 11, name : "Discontinued", slug : "discontinued", parent_id : javacast( "null", "" ), sort_order : 99, is_active : false }
		] );

		// ============================================
		// PRODUCTS (13 rows)
		// ============================================
		qb.table( "qbml_products" ).insert( [
			{ id : 1, sku : "LAPTOP-001", name : "ProBook Laptop 15""", category_id : 4, price : 1299.99, cost : 800.00, stock_qty : 50, is_active : true },
			{ id : 2, sku : "LAPTOP-002", name : "UltraBook Air 13""", category_id : 4, price : 999.99, cost : 600.00, stock_qty : 30, is_active : true },
			{ id : 3, sku : "PHONE-001", name : "SmartPhone Pro", category_id : 5, price : 899.99, cost : 500.00, stock_qty : 100, is_active : true },
			{ id : 4, sku : "PHONE-002", name : "SmartPhone Lite", category_id : 5, price : 499.99, cost : 280.00, stock_qty : 150, is_active : true },
			{ id : 5, sku : "AUDIO-001", name : "Wireless Headphones", category_id : 6, price : 199.99, cost : 80.00, stock_qty : 200, is_active : true },
			{ id : 6, sku : "AUDIO-002", name : "Bluetooth Speaker", category_id : 6, price : 79.99, cost : 35.00, stock_qty : 300, is_active : true },
			{ id : 7, sku : "SHIRT-001", name : "Classic T-Shirt", category_id : 7, price : 29.99, cost : 10.00, stock_qty : 500, is_active : true },
			{ id : 8, sku : "SHIRT-002", name : "Polo Shirt", category_id : 7, price : 49.99, cost : 18.00, stock_qty : 250, is_active : true },
			{ id : 9, sku : "DRESS-001", name : "Summer Dress", category_id : 8, price : 89.99, cost : 35.00, stock_qty : 100, is_active : true },
			{ id : 10, sku : "BOOK-001", name : "The Great Novel", category_id : 9, price : 24.99, cost : 8.00, stock_qty : 75, is_active : true },
			{ id : 11, sku : "BOOK-002", name : "Mystery Thriller", category_id : 9, price : 19.99, cost : 6.00, stock_qty : 120, is_active : true },
			{ id : 12, sku : "BOOK-003", name : "Business Strategy", category_id : 10, price : 34.99, cost : 12.00, stock_qty : 60, is_active : true },
			{ id : 13, sku : "OLD-001", name : "Discontinued Item", category_id : 11, price : 9.99, cost : 5.00, stock_qty : 5, is_active : false }
		] );

		// ============================================
		// ORDERS (10 rows)
		// ============================================
		qb.table( "qbml_orders" ).insert( [
			{ id : 1, order_number : "ORD-2024-0001", user_id : 3, status : "delivered", subtotal : 1499.98, tax : 120.00, total : 1619.98, order_date : "2024-01-15 10:30:00", shipped_date : "2024-01-17", delivered_date : "2024-01-20" },
			{ id : 2, order_number : "ORD-2024-0002", user_id : 3, status : "delivered", subtotal : 199.99, tax : 16.00, total : 215.99, order_date : "2024-02-20 14:15:00", shipped_date : "2024-02-22", delivered_date : "2024-02-25" },
			{ id : 3, order_number : "ORD-2024-0003", user_id : 4, status : "shipped", subtotal : 929.98, tax : 74.40, total : 1004.38, order_date : "2024-11-25 09:00:00", shipped_date : "2024-11-27", delivered_date : javacast( "null", "" ) },
			{ id : 4, order_number : "ORD-2024-0004", user_id : 6, status : "processing", subtotal : 59.98, tax : 4.80, total : 64.78, order_date : "2024-11-28 16:45:00", shipped_date : javacast( "null", "" ), delivered_date : javacast( "null", "" ) },
			{ id : 5, order_number : "ORD-2024-0005", user_id : 8, status : "pending", subtotal : 1299.99, tax : 104.00, total : 1403.99, order_date : "2024-12-01 11:20:00", shipped_date : javacast( "null", "" ), delivered_date : javacast( "null", "" ) },
			{ id : 6, order_number : "ORD-2024-0006", user_id : 10, status : "cancelled", subtotal : 89.99, tax : 7.20, total : 97.19, order_date : "2024-11-15 13:00:00", shipped_date : javacast( "null", "" ), delivered_date : javacast( "null", "" ) },
			{ id : 7, order_number : "ORD-2024-0007", user_id : 3, status : "delivered", subtotal : 79.98, tax : 6.40, total : 86.38, order_date : "2024-03-10 08:30:00", shipped_date : "2024-03-12", delivered_date : "2024-03-15" },
			{ id : 8, order_number : "ORD-2024-0008", user_id : 2, status : "delivered", subtotal : 2199.98, tax : 176.00, total : 2375.98, order_date : "2024-06-01 10:00:00", shipped_date : "2024-06-03", delivered_date : "2024-06-07" },
			{ id : 9, order_number : "ORD-2024-0009", user_id : 4, status : "pending", subtotal : 499.99, tax : 40.00, total : 539.99, order_date : "2024-12-01 15:30:00", shipped_date : javacast( "null", "" ), delivered_date : javacast( "null", "" ) },
			{ id : 10, order_number : "ORD-2024-0010", user_id : 1, status : "delivered", subtotal : 54.98, tax : 4.40, total : 59.38, order_date : "2024-10-20 12:00:00", shipped_date : "2024-10-22", delivered_date : "2024-10-25" }
		] );

		// ============================================
		// ORDER ITEMS (16 rows)
		// ============================================
		qb.table( "qbml_order_items" ).insert( [
			// Order 1: Laptop + Headphones
			{ id : 1, order_id : 1, product_id : 1, quantity : 1, unit_price : 1299.99, discount : 0, line_total : 1299.99 },
			{ id : 2, order_id : 1, product_id : 5, quantity : 1, unit_price : 199.99, discount : 0, line_total : 199.99 },
			// Order 2: Headphones only
			{ id : 3, order_id : 2, product_id : 5, quantity : 1, unit_price : 199.99, discount : 0, line_total : 199.99 },
			// Order 3: Phone Pro + T-Shirt
			{ id : 4, order_id : 3, product_id : 3, quantity : 1, unit_price : 899.99, discount : 0, line_total : 899.99 },
			{ id : 5, order_id : 3, product_id : 7, quantity : 1, unit_price : 29.99, discount : 0, line_total : 29.99 },
			// Order 4: 2x T-Shirts
			{ id : 6, order_id : 4, product_id : 7, quantity : 2, unit_price : 29.99, discount : 0, line_total : 59.98 },
			// Order 5: Laptop
			{ id : 7, order_id : 5, product_id : 1, quantity : 1, unit_price : 1299.99, discount : 0, line_total : 1299.99 },
			// Order 6: Dress (cancelled)
			{ id : 8, order_id : 6, product_id : 9, quantity : 1, unit_price : 89.99, discount : 0, line_total : 89.99 },
			// Order 7: 3x Books
			{ id : 9, order_id : 7, product_id : 10, quantity : 1, unit_price : 24.99, discount : 0, line_total : 24.99 },
			{ id : 10, order_id : 7, product_id : 11, quantity : 1, unit_price : 19.99, discount : 0, line_total : 19.99 },
			{ id : 11, order_id : 7, product_id : 12, quantity : 1, unit_price : 34.99, discount : 0, line_total : 34.99 },
			// Order 8: 2 Laptops (with discount)
			{ id : 12, order_id : 8, product_id : 1, quantity : 1, unit_price : 1299.99, discount : 100.00, line_total : 1199.99 },
			{ id : 13, order_id : 8, product_id : 2, quantity : 1, unit_price : 999.99, discount : 0, line_total : 999.99 },
			// Order 9: Phone Lite
			{ id : 14, order_id : 9, product_id : 4, quantity : 1, unit_price : 499.99, discount : 0, line_total : 499.99 },
			// Order 10: Book + T-Shirt
			{ id : 15, order_id : 10, product_id : 10, quantity : 1, unit_price : 24.99, discount : 0, line_total : 24.99 },
			{ id : 16, order_id : 10, product_id : 7, quantity : 1, unit_price : 29.99, discount : 0, line_total : 29.99 }
		] );
	}

	function down( schema, qb ) {
		qb.table( "qbml_order_items" ).delete();
		qb.table( "qbml_orders" ).delete();
		qb.table( "qbml_products" ).delete();
		qb.table( "qbml_categories" ).delete();
		qb.table( "qbml_user_profiles" ).delete();
		qb.table( "qbml_users" ).delete();
		qb.table( "qbml_departments" ).delete();
	}

}
