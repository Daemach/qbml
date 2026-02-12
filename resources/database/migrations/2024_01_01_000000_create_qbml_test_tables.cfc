/**
 * QBML Test Database Setup
 *
 * Without cfmigrations:
 *   new migrations.2024_01_01_000000_create_qbml_test_tables().runSQL( "qbmlTests" )
 */
component {

	function up( schema, qb ) {
		runSQL( arguments = { schema : schema, qb : qb } );
	}

	function down( schema, qb ) {
		runSQL( down = true, arguments = { schema : schema, qb : qb } );
	}

	function runSQL( string datasource = "", boolean down = false ) {
		var opts = len( arguments.datasource ) ? { datasource : arguments.datasource } : {};

		if ( arguments.down ) {
			queryExecute( getDropSQL(), [], opts );
			return;
		}

		queryExecute( getDropSQL(), [], opts );
		queryExecute( getCreateSQL(), [], opts );
		queryExecute( getSeedSQL(), [], opts );
	}

	string function getDatabaseSQL() {
		return "
			IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'qbml_test')
				CREATE DATABASE qbml_test;
		";
	}

	string function getDropSQL() {
		return "
			IF OBJECT_ID('qbml_order_items', 'U') IS NOT NULL DROP TABLE qbml_order_items;
			IF OBJECT_ID('qbml_orders', 'U') IS NOT NULL DROP TABLE qbml_orders;
			IF OBJECT_ID('qbml_products', 'U') IS NOT NULL DROP TABLE qbml_products;
			IF OBJECT_ID('qbml_categories', 'U') IS NOT NULL DROP TABLE qbml_categories;
			IF OBJECT_ID('qbml_user_profiles', 'U') IS NOT NULL DROP TABLE qbml_user_profiles;
			IF OBJECT_ID('qbml_users', 'U') IS NOT NULL DROP TABLE qbml_users;
			IF OBJECT_ID('qbml_departments', 'U') IS NOT NULL DROP TABLE qbml_departments;
		";
	}

	string function getCreateSQL() {
		return "
			CREATE TABLE qbml_departments (
				id INT IDENTITY(1,1) PRIMARY KEY,
				name NVARCHAR(100) NOT NULL,
				parent_id INT NULL,
				budget DECIMAL(12,2) DEFAULT 0,
				created_at DATETIME DEFAULT GETDATE(),
				CONSTRAINT fk_departments_parent FOREIGN KEY (parent_id) REFERENCES qbml_departments(id)
			);

			CREATE TABLE qbml_users (
				id INT IDENTITY(1,1) PRIMARY KEY,
				username NVARCHAR(50) NOT NULL UNIQUE,
				email NVARCHAR(100) NOT NULL,
				status NVARCHAR(20) DEFAULT 'active',
				role NVARCHAR(20) DEFAULT 'user',
				department_id INT NULL,
				salary DECIMAL(10,2) NULL,
				hire_date DATE NULL,
				last_login DATETIME NULL,
				created_at DATETIME DEFAULT GETDATE(),
				updated_at DATETIME DEFAULT GETDATE(),
				deleted_at DATETIME NULL,
				CONSTRAINT fk_users_department FOREIGN KEY (department_id) REFERENCES qbml_departments(id)
			);
			CREATE INDEX idx_users_status ON qbml_users(status);
			CREATE INDEX idx_users_role ON qbml_users(role);
			CREATE INDEX idx_users_department ON qbml_users(department_id);

			CREATE TABLE qbml_user_profiles (
				id INT IDENTITY(1,1) PRIMARY KEY,
				user_id INT NOT NULL UNIQUE,
				first_name NVARCHAR(50) NULL,
				last_name NVARCHAR(50) NULL,
				bio NVARCHAR(MAX) NULL,
				avatar_url NVARCHAR(255) NULL,
				phone NVARCHAR(20) NULL,
				birth_date DATE NULL,
				CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES qbml_users(id)
			);

			CREATE TABLE qbml_categories (
				id INT IDENTITY(1,1) PRIMARY KEY,
				name NVARCHAR(100) NOT NULL,
				slug NVARCHAR(100) NOT NULL UNIQUE,
				parent_id INT NULL,
				sort_order INT DEFAULT 0,
				is_active BIT DEFAULT 1,
				CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES qbml_categories(id)
			);

			CREATE TABLE qbml_products (
				id INT IDENTITY(1,1) PRIMARY KEY,
				sku NVARCHAR(50) NOT NULL UNIQUE,
				name NVARCHAR(200) NOT NULL,
				description NVARCHAR(MAX) NULL,
				category_id INT NULL,
				price DECIMAL(10,2) NOT NULL,
				cost DECIMAL(10,2) NULL,
				stock_qty INT DEFAULT 0,
				is_active BIT DEFAULT 1,
				created_at DATETIME DEFAULT GETDATE(),
				CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES qbml_categories(id)
			);
			CREATE INDEX idx_products_category ON qbml_products(category_id);

			CREATE TABLE qbml_orders (
				id INT IDENTITY(1,1) PRIMARY KEY,
				order_number NVARCHAR(20) NOT NULL UNIQUE,
				user_id INT NOT NULL,
				status NVARCHAR(20) DEFAULT 'pending',
				subtotal DECIMAL(12,2) DEFAULT 0,
				tax DECIMAL(12,2) DEFAULT 0,
				total DECIMAL(12,2) DEFAULT 0,
				notes NVARCHAR(MAX) NULL,
				order_date DATETIME DEFAULT GETDATE(),
				shipped_date DATETIME NULL,
				delivered_date DATETIME NULL,
				CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES qbml_users(id)
			);
			CREATE INDEX idx_orders_user ON qbml_orders(user_id);
			CREATE INDEX idx_orders_status ON qbml_orders(status);
			CREATE INDEX idx_orders_date ON qbml_orders(order_date);

			CREATE TABLE qbml_order_items (
				id INT IDENTITY(1,1) PRIMARY KEY,
				order_id INT NOT NULL,
				product_id INT NOT NULL,
				quantity INT DEFAULT 1,
				unit_price DECIMAL(10,2) NOT NULL,
				discount DECIMAL(10,2) DEFAULT 0,
				line_total DECIMAL(12,2) NOT NULL,
				CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES qbml_orders(id),
				CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES qbml_products(id)
			);
			CREATE INDEX idx_order_items_order ON qbml_order_items(order_id);
			CREATE INDEX idx_order_items_product ON qbml_order_items(product_id);
		";
	}

	string function getSeedSQL() {
		return "
			SET IDENTITY_INSERT qbml_departments ON;
			INSERT INTO qbml_departments (id, name, parent_id, budget) VALUES
			(1, 'Company', NULL, 1000000.00),
			(2, 'Engineering', 1, 500000.00),
			(3, 'Sales', 1, 300000.00),
			(4, 'Marketing', 1, 200000.00),
			(5, 'Frontend', 2, 150000.00),
			(6, 'Backend', 2, 200000.00),
			(7, 'DevOps', 2, 150000.00),
			(8, 'Enterprise Sales', 3, 200000.00),
			(9, 'SMB Sales', 3, 100000.00);
			SET IDENTITY_INSERT qbml_departments OFF;

			SET IDENTITY_INSERT qbml_users ON;
			INSERT INTO qbml_users (id, username, email, status, role, department_id, salary, hire_date, last_login, deleted_at) VALUES
			(1, 'admin', 'admin@example.com', 'active', 'admin', 1, 150000.00, '2020-01-15', '2024-12-01 09:00:00', NULL),
			(2, 'jsmith', 'john.smith@example.com', 'active', 'manager', 2, 120000.00, '2020-03-01', '2024-12-01 08:30:00', NULL),
			(3, 'mjones', 'mary.jones@example.com', 'active', 'user', 5, 95000.00, '2021-06-15', '2024-11-30 17:00:00', NULL),
			(4, 'bwilson', 'bob.wilson@example.com', 'active', 'user', 6, 105000.00, '2021-08-01', '2024-12-01 10:15:00', NULL),
			(5, 'agarcia', 'ana.garcia@example.com', 'inactive', 'user', 5, 90000.00, '2022-01-10', '2024-06-15 14:00:00', NULL),
			(6, 'clee', 'chris.lee@example.com', 'active', 'manager', 3, 110000.00, '2020-05-20', '2024-12-01 07:45:00', NULL),
			(7, 'dkim', 'david.kim@example.com', 'pending', 'user', 8, 85000.00, '2024-11-01', NULL, NULL),
			(8, 'ewang', 'emma.wang@example.com', 'active', 'user', 7, 100000.00, '2022-03-15', '2024-11-29 16:30:00', NULL),
			(9, 'fmiller', 'frank.miller@example.com', 'deleted', 'user', 4, 80000.00, '2021-09-01', '2024-01-15 11:00:00', '2024-02-01'),
			(10, 'gwhite', 'grace.white@example.com', 'active', 'user', 9, 75000.00, '2023-02-01', '2024-11-28 09:00:00', NULL),
			(11, 'hbrown', 'henry.brown@example.com', 'active', 'guest', NULL, NULL, NULL, '2024-11-20 12:00:00', NULL),
			(12, 'idavis', 'ivy.davis@example.com', 'inactive', 'user', 6, 98000.00, '2022-07-01', '2024-09-01 10:00:00', NULL);
			SET IDENTITY_INSERT qbml_users OFF;

			SET IDENTITY_INSERT qbml_user_profiles ON;
			INSERT INTO qbml_user_profiles (id, user_id, first_name, last_name, bio, phone, birth_date) VALUES
			(1, 1, 'System', 'Admin', 'System administrator', '555-0001', '1985-03-15'),
			(2, 2, 'John', 'Smith', 'Engineering manager with 10+ years experience', '555-0002', '1982-07-22'),
			(3, 3, 'Mary', 'Jones', 'Frontend developer specializing in React', '555-0003', '1990-11-08'),
			(4, 4, 'Bob', 'Wilson', 'Backend developer, database expert', '555-0004', '1988-04-30'),
			(5, 5, 'Ana', 'Garcia', 'UI/UX enthusiast', '555-0005', '1992-09-12'),
			(6, 6, 'Chris', 'Lee', 'Sales director', '555-0006', '1980-01-25'),
			(7, 7, 'David', 'Kim', 'New hire - enterprise sales', '555-0007', '1995-06-18'),
			(8, 8, 'Emma', 'Wang', 'DevOps engineer, cloud specialist', '555-0008', '1991-12-03'),
			(9, 10, 'Grace', 'White', 'SMB account manager', '555-0010', '1993-08-07');
			SET IDENTITY_INSERT qbml_user_profiles OFF;

			SET IDENTITY_INSERT qbml_categories ON;
			INSERT INTO qbml_categories (id, name, slug, parent_id, sort_order, is_active) VALUES
			(1, 'Electronics', 'electronics', NULL, 1, 1),
			(2, 'Clothing', 'clothing', NULL, 2, 1),
			(3, 'Books', 'books', NULL, 3, 1),
			(4, 'Computers', 'computers', 1, 1, 1),
			(5, 'Phones', 'phones', 1, 2, 1),
			(6, 'Audio', 'audio', 1, 3, 1),
			(7, 'Men', 'men', 2, 1, 1),
			(8, 'Women', 'women', 2, 2, 1),
			(9, 'Fiction', 'fiction', 3, 1, 1),
			(10, 'Non-Fiction', 'non-fiction', 3, 2, 1),
			(11, 'Discontinued', 'discontinued', NULL, 99, 0);
			SET IDENTITY_INSERT qbml_categories OFF;

			SET IDENTITY_INSERT qbml_products ON;
			INSERT INTO qbml_products (id, sku, name, category_id, price, cost, stock_qty, is_active) VALUES
			(1, 'LAPTOP-001', 'ProBook Laptop 15""', 4, 1299.99, 800.00, 50, 1),
			(2, 'LAPTOP-002', 'UltraBook Air 13""', 4, 999.99, 600.00, 30, 1),
			(3, 'PHONE-001', 'SmartPhone Pro', 5, 899.99, 500.00, 100, 1),
			(4, 'PHONE-002', 'SmartPhone Lite', 5, 499.99, 280.00, 150, 1),
			(5, 'AUDIO-001', 'Wireless Headphones', 6, 199.99, 80.00, 200, 1),
			(6, 'AUDIO-002', 'Bluetooth Speaker', 6, 79.99, 35.00, 300, 1),
			(7, 'SHIRT-001', 'Classic T-Shirt', 7, 29.99, 10.00, 500, 1),
			(8, 'SHIRT-002', 'Polo Shirt', 7, 49.99, 18.00, 250, 1),
			(9, 'DRESS-001', 'Summer Dress', 8, 89.99, 35.00, 100, 1),
			(10, 'BOOK-001', 'The Great Novel', 9, 24.99, 8.00, 75, 1),
			(11, 'BOOK-002', 'Mystery Thriller', 9, 19.99, 6.00, 120, 1),
			(12, 'BOOK-003', 'Business Strategy', 10, 34.99, 12.00, 60, 1),
			(13, 'OLD-001', 'Discontinued Item', 11, 9.99, 5.00, 5, 0);
			SET IDENTITY_INSERT qbml_products OFF;

			SET IDENTITY_INSERT qbml_orders ON;
			INSERT INTO qbml_orders (id, order_number, user_id, status, subtotal, tax, total, order_date, shipped_date, delivered_date) VALUES
			(1, 'ORD-2024-0001', 3, 'delivered', 1499.98, 120.00, 1619.98, '2024-01-15 10:30:00', '2024-01-17', '2024-01-20'),
			(2, 'ORD-2024-0002', 3, 'delivered', 199.99, 16.00, 215.99, '2024-02-20 14:15:00', '2024-02-22', '2024-02-25'),
			(3, 'ORD-2024-0003', 4, 'shipped', 929.98, 74.40, 1004.38, '2024-11-25 09:00:00', '2024-11-27', NULL),
			(4, 'ORD-2024-0004', 6, 'processing', 59.98, 4.80, 64.78, '2024-11-28 16:45:00', NULL, NULL),
			(5, 'ORD-2024-0005', 8, 'pending', 1299.99, 104.00, 1403.99, '2024-12-01 11:20:00', NULL, NULL),
			(6, 'ORD-2024-0006', 10, 'cancelled', 89.99, 7.20, 97.19, '2024-11-15 13:00:00', NULL, NULL),
			(7, 'ORD-2024-0007', 3, 'delivered', 79.98, 6.40, 86.38, '2024-03-10 08:30:00', '2024-03-12', '2024-03-15'),
			(8, 'ORD-2024-0008', 2, 'delivered', 2199.98, 176.00, 2375.98, '2024-06-01 10:00:00', '2024-06-03', '2024-06-07'),
			(9, 'ORD-2024-0009', 4, 'pending', 499.99, 40.00, 539.99, '2024-12-01 15:30:00', NULL, NULL),
			(10, 'ORD-2024-0010', 1, 'delivered', 54.98, 4.40, 59.38, '2024-10-20 12:00:00', '2024-10-22', '2024-10-25');
			SET IDENTITY_INSERT qbml_orders OFF;

			SET IDENTITY_INSERT qbml_order_items ON;
			INSERT INTO qbml_order_items (id, order_id, product_id, quantity, unit_price, discount, line_total) VALUES
			(1, 1, 1, 1, 1299.99, 0, 1299.99),
			(2, 1, 5, 1, 199.99, 0, 199.99),
			(3, 2, 5, 1, 199.99, 0, 199.99),
			(4, 3, 3, 1, 899.99, 0, 899.99),
			(5, 3, 7, 1, 29.99, 0, 29.99),
			(6, 4, 7, 2, 29.99, 0, 59.98),
			(7, 5, 1, 1, 1299.99, 0, 1299.99),
			(8, 6, 9, 1, 89.99, 0, 89.99),
			(9, 7, 10, 1, 24.99, 0, 24.99),
			(10, 7, 11, 1, 19.99, 0, 19.99),
			(11, 7, 12, 1, 34.99, 0, 34.99),
			(12, 8, 1, 1, 1299.99, 100.00, 1199.99),
			(13, 8, 2, 1, 999.99, 0, 999.99),
			(14, 9, 4, 1, 499.99, 0, 499.99),
			(15, 10, 10, 1, 24.99, 0, 24.99),
			(16, 10, 7, 1, 29.99, 0, 29.99);
			SET IDENTITY_INSERT qbml_order_items OFF;
		";
	}

}
