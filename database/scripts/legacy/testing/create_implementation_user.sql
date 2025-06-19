-- ================================================================
-- CREATE IMPLEMENTATION USER FOR the_one_spa_oregon
-- ================================================================
-- Purpose: Create a dedicated implementation user for:
--   - Database schema modifications
--   - Function development and testing
--   - Data manipulation and corrections
--   - Implementation and deployment tasks
--   - Development work requiring write access
-- 
-- Security: Broader access for implementation but still controlled
-- Scope: Access to modify data and schema objects as needed
-- Last Updated: December 2024
-- ================================================================

-- ================================================================
-- STEP 1: CREATE THE IMPLEMENTATION USER (if not exists)
-- ================================================================

-- Create the implementation user with a secure password
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'onevault_implementation') THEN
        CREATE USER onevault_implementation WITH 
            PASSWORD 'Implement2024!Secure#'
            NOSUPERUSER 
            NOCREATEDB 
            NOCREATEROLE 
            INHERIT 
            LOGIN
            CONNECTION LIMIT 5;
        
        COMMENT ON ROLE onevault_implementation IS 'Implementation user for development, schema changes, and data manipulation. Created for OneVault Data Vault 2.0 system.';
        RAISE NOTICE 'Created user: onevault_implementation';
    ELSE
        RAISE NOTICE 'User onevault_implementation already exists';
    END IF;
END $$;

-- ================================================================
-- STEP 2: GRANT DATABASE CONNECTION
-- ================================================================

-- Grant connection to the correct database
GRANT CONNECT ON DATABASE the_one_spa_oregon TO onevault_implementation;

-- ================================================================
-- STEP 3: GRANT SCHEMA ACCESS AND CREATION
-- ================================================================

-- Grant usage and create on all relevant schemas
GRANT USAGE, CREATE ON SCHEMA public TO onevault_implementation;
GRANT USAGE, CREATE ON SCHEMA auth TO onevault_implementation;
GRANT USAGE, CREATE ON SCHEMA raw TO onevault_implementation;
GRANT USAGE, CREATE ON SCHEMA staging TO onevault_implementation;
GRANT USAGE, CREATE ON SCHEMA api TO onevault_implementation;
GRANT USAGE, CREATE ON SCHEMA util TO onevault_implementation;
GRANT USAGE, CREATE ON SCHEMA audit TO onevault_implementation;
GRANT USAGE ON SCHEMA information_schema TO onevault_implementation;
GRANT USAGE ON SCHEMA pg_catalog TO onevault_implementation;

-- ================================================================
-- STEP 4: GRANT FULL ACCESS TO ALL TABLES
-- ================================================================

-- Grant ALL privileges on existing tables in each schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA staging TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA api TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA util TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO onevault_implementation;

-- Grant SELECT on system catalogs for inspection
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO onevault_implementation;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO onevault_implementation;

-- ================================================================
-- STEP 5: GRANT FUNCTION AND PROCEDURE ACCESS
-- ================================================================

-- Grant execute and create on functions/procedures
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA api TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA auth TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA util TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA audit TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA raw TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA staging TO onevault_implementation;

-- ================================================================
-- STEP 6: GRANT SEQUENCE ACCESS
-- ================================================================

-- Grant all privileges on sequences for full control
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA raw TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA staging TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA util TO onevault_implementation;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA audit TO onevault_implementation;

-- ================================================================
-- STEP 7: SET DEFAULT PRIVILEGES FOR FUTURE OBJECTS
-- ================================================================

-- Ensure implementation user gets full access to future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON TABLES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON TABLES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON TABLES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL ON TABLES TO onevault_implementation;

-- Ensure implementation user gets full access to future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON FUNCTIONS TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON FUNCTIONS TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON FUNCTIONS TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL ON FUNCTIONS TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON FUNCTIONS TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON FUNCTIONS TO onevault_implementation;

-- Ensure implementation user gets full access to future sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON SEQUENCES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON SEQUENCES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON SEQUENCES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON SEQUENCES TO onevault_implementation;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL ON SEQUENCES TO onevault_implementation;

-- ================================================================
-- STEP 8: GRANT TEMP TABLE CREATION
-- ================================================================

-- Allow creation of temporary tables for testing and development
GRANT TEMP ON DATABASE the_one_spa_oregon TO onevault_implementation;

-- ================================================================
-- STEP 9: ADDITIONAL IMPLEMENTATION PRIVILEGES
-- ================================================================

-- Grant ability to create types (for custom data types)
GRANT CREATE ON SCHEMA auth TO onevault_implementation;
GRANT CREATE ON SCHEMA raw TO onevault_implementation;
GRANT CREATE ON SCHEMA staging TO onevault_implementation;
GRANT CREATE ON SCHEMA api TO onevault_implementation;
GRANT CREATE ON SCHEMA util TO onevault_implementation;
GRANT CREATE ON SCHEMA audit TO onevault_implementation;

-- Grant ability to create and manage indexes
-- Note: This is covered by table privileges, but explicitly mentioning for clarity

-- ================================================================
-- STEP 10: SECURITY BOUNDARIES (what NOT to grant)
-- ================================================================

-- Explicitly deny dangerous privileges that should remain with superuser
-- These are already denied by default, but documenting for clarity:

-- NO superuser privileges
-- NO database creation
-- NO role creation/management  
-- NO ability to modify system catalogs
-- NO ability to access other databases

-- ================================================================
-- VERIFICATION
-- ================================================================

-- Test the user creation
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'onevault_implementation') THEN
        RAISE NOTICE 'SUCCESS: onevault_implementation user created successfully';
        RAISE NOTICE 'User has full privileges on OneVault schemas for implementation work';
    ELSE
        RAISE NOTICE 'ERROR: Failed to create onevault_implementation user';
    END IF;
END $$;

-- Display user capabilities
SELECT 
    'onevault_implementation' as username,
    'Full read/write access to OneVault schemas' as access_level,
    'Can create/modify tables, functions, and data' as capabilities,
    'Can execute all API functions and procedures' as function_access,
    'CANNOT create databases or manage roles' as limitations;

-- ================================================================
-- CONNECTION INFORMATION
-- ================================================================

SELECT 
    'SUCCESS: onevault_implementation setup complete' as status,
    'Database: the_one_spa_oregon' as database_name,
    'Username: onevault_implementation' as username,
    'Password: Implement2024!Secure#' as password;

-- ================================================================
-- USAGE EXAMPLES AND CONNECTION
-- ================================================================

/*
-- WINDOWS CONNECTION EXAMPLES:
-- 
-- Method 1: Environment variable + psql
-- $env:PGPASSWORD = "Implement2024!Secure#"
-- psql -h localhost -U onevault_implementation -d the_one_spa_oregon
-- 
-- Method 2: PowerShell direct connection
-- $env:PGPASSWORD = "Implement2024!Secure#"; & "C:\Program Files\PostgreSQL\17\bin\psql.exe" -h localhost -U onevault_implementation -d the_one_spa_oregon
-- 
-- Method 3: Connection string
-- psql "postgresql://onevault_implementation:Implement2024!Secure#@localhost:5432/the_one_spa_oregon"

-- IMPLEMENTATION TASKS EXAMPLES:
-- 
-- 1. Schema modifications:
-- ALTER TABLE auth.user_h ADD COLUMN new_field VARCHAR(100);
-- 
-- 2. Function development:
-- CREATE OR REPLACE FUNCTION api.new_auth_function(jsonb) RETURNS jsonb AS $$ ... $$;
-- 
-- 3. Data corrections:
-- UPDATE auth.user_h SET field = 'corrected_value' WHERE condition;
-- 
-- 4. Testing setup:
-- CREATE TEMP TABLE test_data AS SELECT * FROM auth.user_h LIMIT 10;
-- 
-- 5. Index creation:
-- CREATE INDEX CONCURRENTLY idx_user_h_email ON auth.user_h(email);

-- SECURITY TESTING (with implementation privileges):
-- 
-- 1. Function testing:
-- SELECT api.auth_login('{"username":"test","password":"test","ip_address":"127.0.0.1","user_agent":"test"}');
-- 
-- 2. Data integrity tests:
-- INSERT INTO auth.test_table VALUES (...);
-- UPDATE auth.test_table SET ...;
-- DELETE FROM auth.test_table WHERE ...;
*/

-- ================================================================
-- SWITCHING BETWEEN USERS
-- ================================================================

/*
-- TO SWITCH TO READONLY USER:
-- \c the_one_spa_oregon onevault_readonly
-- Password: ReadOnly2024!Secure#

-- TO SWITCH TO IMPLEMENTATION USER:
-- \c the_one_spa_oregon onevault_implementation  
-- Password: Implement2024!Secure#

-- BEST PRACTICES:
-- 1. Use readonly user for: inspection, monitoring, most testing
-- 2. Use implementation user for: schema changes, data fixes, function development
-- 3. Always test with readonly user first to verify queries work
-- 4. Use implementation user only when write access is needed
*/

-- ================================================================
-- MAINTENANCE
-- ================================================================

/*
-- TO MODIFY PASSWORD:
-- ALTER USER onevault_implementation WITH PASSWORD 'NewPassword2024!';

-- TO REVOKE SPECIFIC PRIVILEGES (if needed):
-- REVOKE CREATE ON SCHEMA auth FROM onevault_implementation;

-- TO DROP USER (if needed):
-- REASSIGN OWNED BY onevault_implementation TO postgres;
-- DROP OWNED BY onevault_implementation;
-- DROP USER onevault_implementation;
*/ 