-- ================================================================
-- CREATE READ-ONLY DATABASE USER FOR the_one_spa_oregon
-- ================================================================
-- Purpose: Create a dedicated read-only user for testing and inspection
-- Database: the_one_spa_oregon
-- Last Updated: December 2024
-- ================================================================

-- ================================================================
-- STEP 1: CREATE THE READ-ONLY USER (if not exists)
-- ================================================================

-- Create the read-only user with a secure password
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'onevault_readonly') THEN
        CREATE USER onevault_readonly WITH 
            PASSWORD 'ReadOnly2024!Secure#'
            NOSUPERUSER 
            NOCREATEDB 
            NOCREATEROLE 
            NOINHERIT 
            LOGIN
            CONNECTION LIMIT 10;
        
        COMMENT ON ROLE onevault_readonly IS 'Read-only user for testing, inspection, and development purposes. Created for OneVault Data Vault 2.0 system.';
        RAISE NOTICE 'Created user: onevault_readonly';
    ELSE
        RAISE NOTICE 'User onevault_readonly already exists';
    END IF;
END $$;

-- ================================================================
-- STEP 2: GRANT DATABASE CONNECTION
-- ================================================================

-- Grant connection to the correct database
GRANT CONNECT ON DATABASE the_one_spa_oregon TO onevault_readonly;

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

-- ================================================================
-- STEP 5: GRANT FUNCTION EXECUTION
-- ================================================================

-- Grant execute on API functions for testing
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO onevault_readonly;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA util TO onevault_readonly;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA audit TO onevault_readonly;

-- ================================================================
-- VERIFICATION
-- ================================================================

SELECT 
    'SUCCESS: onevault_readonly setup complete' as status,
    'Database: the_one_spa_oregon' as database_name,
    'Username: onevault_readonly' as username,
    'Password: ReadOnly2024!Secure#' as password; 