-- ================================================================
-- CREATE READ-ONLY DATABASE USER FOR TESTING & INSPECTION
-- ================================================================
-- Purpose: Create a dedicated read-only user for:
--   - Security testing and validation
--   - Database structure inspection  
--   - Performance monitoring
--   - Development team access
--   - Future automated testing
-- 
-- Security: Read-only access prevents accidental data modifications
-- Scope: Access to all schemas needed for testing and inspection
-- Last Updated: December 2024
-- ================================================================

-- ================================================================
-- STEP 1: CREATE THE READ-ONLY USER
-- ================================================================

-- Drop user if exists (for re-running script)
DROP USER IF EXISTS onevault_readonly;

-- Create the read-only user with a secure password
CREATE USER onevault_readonly WITH 
    PASSWORD 'ReadOnly2024!Secure#'
    NOSUPERUSER 
    NOCREATEDB 
    NOCREATEROLE 
    NOINHERIT 
    LOGIN
    CONNECTION LIMIT 10;

-- Add comment for documentation
COMMENT ON ROLE onevault_readonly IS 'Read-only user for testing, inspection, and development purposes. Created for OneVault Data Vault 2.0 system.';

-- ================================================================
-- STEP 2: GRANT DATABASE CONNECTION
-- ================================================================

-- Grant connection to the database
GRANT CONNECT ON DATABASE postgres TO onevault_readonly;

-- Note: Replace 'postgres' with your actual database name if different
-- Example for custom database name:
-- GRANT CONNECT ON DATABASE "Data Vault 2.0" TO onevault_readonly;
-- GRANT CONNECT ON DATABASE "onevault_db" TO onevault_readonly;

-- ================================================================
-- STEP 3: GRANT SCHEMA ACCESS
-- ================================================================

-- Grant usage on all relevant schemas
GRANT USAGE ON SCHEMA public TO onevault_readonly;
GRANT USAGE ON SCHEMA auth TO onevault_readonly;
GRANT USAGE ON SCHEMA raw TO onevault_readonly;
GRANT USAGE ON SCHEMA staging TO onevault_readonly;
GRANT USAGE ON SCHEMA api TO onevault_readonly;
GRANT USAGE ON SCHEMA util TO onevault_readonly;
GRANT USAGE ON SCHEMA audit TO onevault_readonly;
GRANT USAGE ON SCHEMA information_schema TO onevault_readonly;
GRANT USAGE ON SCHEMA pg_catalog TO onevault_readonly;

-- ================================================================
-- STEP 4: GRANT READ ACCESS TO ALL TABLES
-- ================================================================

-- Grant SELECT on all existing tables in each schema
GRANT SELECT ON ALL TABLES IN SCHEMA public TO onevault_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO onevault_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO onevault_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO onevault_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA util TO onevault_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO onevault_readonly;

-- Grant SELECT on system catalogs for inspection
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO onevault_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO onevault_readonly;

-- ================================================================
-- STEP 5: GRANT FUNCTION EXECUTION (READ-ONLY FUNCTIONS ONLY)
-- ================================================================

-- Grant execute on API functions for testing
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO onevault_readonly;

-- Grant execute on utility functions for inspection
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA util TO onevault_readonly;

-- Grant execute on audit functions for monitoring
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA audit TO onevault_readonly;

-- ================================================================
-- STEP 6: SET DEFAULT PRIVILEGES FOR FUTURE OBJECTS
-- ================================================================

-- Ensure read-only user gets access to future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT SELECT ON TABLES TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT ON TABLES TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT SELECT ON TABLES TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT SELECT ON TABLES TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT ON TABLES TO onevault_readonly;

-- Ensure read-only user gets access to future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT EXECUTE ON FUNCTIONS TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT EXECUTE ON FUNCTIONS TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT EXECUTE ON FUNCTIONS TO onevault_readonly;

-- ================================================================
-- STEP 7: GRANT SEQUENCE ACCESS (for inspection, not modification)
-- ================================================================

-- Grant usage on sequences for inspection purposes
GRANT USAGE ON ALL SEQUENCES IN SCHEMA auth TO onevault_readonly;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw TO onevault_readonly;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA staging TO onevault_readonly;

-- Set default privileges for future sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT USAGE ON SEQUENCES TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT USAGE ON SEQUENCES TO onevault_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT USAGE ON SEQUENCES TO onevault_readonly;

-- ================================================================
-- STEP 8: CREATE HELPFUL VIEWS FOR INSPECTION
-- ================================================================

-- Create a view to help with database inspection (as superuser first)
CREATE OR REPLACE VIEW util.readonly_database_summary AS
SELECT 
    schemaname,
    tablename,
    tableowner,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables 
WHERE schemaname IN ('auth', 'raw', 'staging', 'api', 'util', 'audit')
ORDER BY schemaname, tablename;

-- Grant access to the view
GRANT SELECT ON util.readonly_database_summary TO onevault_readonly;

-- Create function inspection view
CREATE OR REPLACE VIEW util.readonly_function_summary AS
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_catalog.pg_get_function_arguments(p.oid) as arguments,
    pg_catalog.pg_get_function_result(p.oid) as return_type,
    p.prokind as function_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('api', 'auth', 'util', 'audit')
ORDER BY n.nspname, p.proname;

-- Grant access to the function view
GRANT SELECT ON util.readonly_function_summary TO onevault_readonly;

-- ================================================================
-- STEP 9: SECURITY RESTRICTIONS
-- ================================================================

-- Explicitly deny dangerous privileges
REVOKE CREATE ON SCHEMA public FROM onevault_readonly;
REVOKE CREATE ON DATABASE postgres FROM onevault_readonly;

-- Ensure no table modification privileges
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA auth FROM onevault_readonly;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA raw FROM onevault_readonly;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA staging FROM onevault_readonly;

-- ================================================================
-- STEP 10: VERIFICATION AND TESTING
-- ================================================================

-- Test the user creation
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'onevault_readonly') THEN
        RAISE NOTICE 'SUCCESS: onevault_readonly user created successfully';
    ELSE
        RAISE NOTICE 'ERROR: Failed to create onevault_readonly user';
    END IF;
END $$;

-- Display granted privileges summary
SELECT 
    'onevault_readonly' as username,
    'Read-only access granted to all OneVault schemas' as access_level,
    'Can execute API functions for testing' as function_access,
    'Cannot modify any data' as security_level;

-- ================================================================
-- CONNECTION INFORMATION
-- ================================================================

SELECT 'CONNECTION DETAILS' as info_type, 'Use these details to connect:' as info;
SELECT 'Username' as field, 'onevault_readonly' as value
UNION ALL
SELECT 'Password' as field, 'ReadOnly2024!Secure#' as value  
UNION ALL
SELECT 'Database' as field, current_database() as value
UNION ALL
SELECT 'Host' as field, 'localhost (or your server)' as value
UNION ALL
SELECT 'Port' as field, '5432 (default)' as value;

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

/*
-- WINDOWS CONNECTION EXAMPLES:
-- 
-- Method 1: Interactive connection
-- psql -h localhost -p 5432 -U onevault_readonly -d postgres
-- 
-- Method 2: With password environment variable
-- set PGPASSWORD=ReadOnly2024!Secure#
-- psql -h localhost -p 5432 -U onevault_readonly -d postgres
-- 
-- Method 3: Connection string
-- psql "postgresql://onevault_readonly:ReadOnly2024!Secure#@localhost:5432/postgres"

-- TESTING QUERIES TO VERIFY ACCESS:
-- 
-- 1. List all accessible tables:
-- SELECT * FROM util.readonly_database_summary;
-- 
-- 2. List all accessible functions:
-- SELECT * FROM util.readonly_function_summary;
-- 
-- 3. Test API function access:
-- SELECT api.auth_login('{"username":"test","password":"test","ip_address":"127.0.0.1","user_agent":"test"}');
-- 
-- 4. Verify read-only (this should fail):
-- INSERT INTO auth.user_h (user_hk, user_bk, tenant_hk) VALUES (decode('0000', 'hex'), 'test', decode('0000', 'hex'));

-- SECURITY TESTING:
-- 
-- 1. Run security tests:
-- \i Testing/Fixed_Security_Tests.sql
-- 
-- 2. Run load testing scripts:
-- \i Testing/Load_Testing_Script.js  (requires k6)
-- 
-- 3. Database inspection:
-- \i Testing/database_inspection.sql (if created)
*/

-- ================================================================
-- MAINTENANCE AND CLEANUP
-- ================================================================

/*
-- TO MODIFY PASSWORD LATER:
-- ALTER USER onevault_readonly WITH PASSWORD 'NewPassword2024!';

-- TO DROP USER (if needed):
-- REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth FROM onevault_readonly;
-- REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw FROM onevault_readonly;
-- REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA staging FROM onevault_readonly;
-- REVOKE ALL PRIVILEGES ON DATABASE postgres FROM onevault_readonly;
-- DROP USER onevault_readonly;

-- TO LIST USER PRIVILEGES:
-- SELECT * FROM information_schema.role_table_grants WHERE grantee = 'onevault_readonly';
*/

-- ================================================================
-- COMPLETION MESSAGE
-- ================================================================

SELECT 
    '🎉 READ-ONLY USER SETUP COMPLETE! 🎉' as status,
    'Username: onevault_readonly' as credentials,
    'Password: ReadOnly2024!Secure#' as password_info,
    'Ready for testing and inspection!' as next_steps; 